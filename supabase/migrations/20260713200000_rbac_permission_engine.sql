-- Volume 3 Part 12 — Role-Based Access Control (RBAC) & Permission Engine
-- Status: APPLIED remotely as rbac_permission_engine + rbac_permission_engine_rls (approved 2026-07-13).
-- Extends existing roles / permissions / role_permissions / user_roles / user_permissions.

-- ---------------------------------------------------------------------------
-- Expand permissions catalog (additive; keep legacy snake_case slugs)
-- ---------------------------------------------------------------------------

INSERT INTO public.permissions (name, slug, module, description) VALUES
  ('Archive Property', 'archive_property', 'properties', 'Archive property listings'),
  ('View Users', 'view_users', 'users', 'Browse user accounts'),
  ('Create Users', 'create_users', 'users', 'Create user accounts'),
  ('Delete Users', 'delete_users', 'users', 'Delete or permanently deactivate users'),
  ('Export Users', 'export_users', 'users', 'Export user directories'),
  ('Configure Permissions', 'configure_permissions', 'roles', 'Edit permission matrix and groups'),
  ('Export Finance', 'export_finance', 'finance', 'Export financial reports'),
  ('Manage Refunds', 'manage_refunds', 'finance', 'Process refunds'),
  ('View Investments', 'view_investments', 'investments', 'View investment records'),
  ('Approve Investments', 'approve_investments', 'investments', 'Approve investment applications'),
  ('Manage Tickets', 'manage_tickets', 'support', 'View and manage support tickets'),
  ('Break Glass', 'break_glass', 'security', 'Request temporary elevated access')
ON CONFLICT (slug) DO NOTHING;

ALTER TABLE public.roles
  ADD COLUMN IF NOT EXISTS lifecycle TEXT NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS parent_role_id UUID REFERENCES public.roles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;

-- ---------------------------------------------------------------------------
-- Permission groups (Smart Permission Builder™)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.permission_groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.permission_group_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.permission_groups(id) ON DELETE CASCADE,
  permission_id UUID NOT NULL REFERENCES public.permissions(id) ON DELETE CASCADE,
  UNIQUE (group_id, permission_id)
);

INSERT INTO public.permission_groups (name, slug, description) VALUES
  ('Sales Management', 'sales_management', 'Lead management, property editing, bookings, reports'),
  ('Finance Management', 'finance_management', 'Transactions, revenue reports, refunds'),
  ('Support Management', 'support_management', 'Tickets, chat, escalations')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.permission_group_items (group_id, permission_id)
SELECT g.id, p.id
FROM public.permission_groups g
JOIN public.permissions p ON (
  (g.slug = 'sales_management' AND p.slug IN ('view_properties', 'edit_property', 'manage_crm', 'manage_reports'))
  OR (g.slug = 'finance_management' AND p.slug IN ('manage_payments', 'manage_reports', 'manage_refunds'))
  OR (g.slug = 'support_management' AND p.slug IN ('manage_tickets'))
)
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Approval policies + policy rules
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.approval_policies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  action_type TEXT NOT NULL,
  approver_role_slug TEXT NOT NULL,
  enabled BOOLEAN NOT NULL DEFAULT true,
  threshold_amount NUMERIC,
  description TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.approval_policies (name, action_type, approver_role_slug, threshold_amount, description)
SELECT * FROM (VALUES
  ('Delete Property', 'delete_property', 'admin', NULL::NUMERIC, 'Manager approval required to delete properties'),
  ('Large Refund', 'large_refund', 'finance', 500000::NUMERIC, 'Finance approval for refunds ≥ ₦500,000'),
  ('Role Change', 'role_change', 'super_admin', NULL::NUMERIC, 'Super Admin approval for role changes')
) AS v(name, action_type, approver_role_slug, threshold_amount, description)
WHERE NOT EXISTS (
  SELECT 1 FROM public.approval_policies ap WHERE ap.action_type = v.action_type
);

CREATE TABLE IF NOT EXISTS public.policy_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  rule_type TEXT NOT NULL,
  permission_slug TEXT,
  config JSONB NOT NULL DEFAULT '{}'::jsonb,
  enabled BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.policy_rules (name, rule_type, permission_slug, config)
SELECT * FROM (VALUES
  ('Assigned property edit', 'ownership', 'edit_property', '{"scope":"assigned_only"}'::jsonb),
  ('Branch data scope', 'branch', NULL, '{"scope":"same_branch"}'::jsonb),
  ('Refund threshold', 'amount', 'manage_refunds', '{"max_without_approval":500000}'::jsonb)
) AS v(name, rule_type, permission_slug, config)
WHERE NOT EXISTS (
  SELECT 1 FROM public.policy_rules pr WHERE pr.name = v.name
);

-- ---------------------------------------------------------------------------
-- Resource permissions, delegated admins, access requests, break-glass
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.resource_permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  permission_slug TEXT NOT NULL,
  resource_type TEXT NOT NULL,
  resource_id TEXT NOT NULL,
  granted BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, permission_slug, resource_type, resource_id)
);

CREATE TABLE IF NOT EXISTS public.delegated_admins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  scope_type TEXT NOT NULL,
  scope_id TEXT,
  permission_group_id UUID REFERENCES public.permission_groups(id) ON DELETE SET NULL,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.access_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  permission_slug TEXT,
  role_slug TEXT,
  reason TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  reviewed_by UUID REFERENCES public.profiles(id),
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.break_glass_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  approved_by UUID REFERENCES public.profiles(id),
  starts_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS public.access_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  department_slug TEXT,
  reviewer_id UUID REFERENCES public.profiles(id),
  status TEXT NOT NULL DEFAULT 'scheduled',
  due_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.permission_audit (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  target_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  role_slug TEXT,
  permission_slug TEXT,
  old_values JSONB,
  new_values JSONB,
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_permission_audit_created
  ON public.permission_audit(created_at DESC);

-- ---------------------------------------------------------------------------
-- RPC: toggle role permission (matrix edits)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.set_role_permission(
  p_role_id UUID,
  p_permission_slug TEXT,
  p_granted BOOLEAN,
  p_actor_id UUID DEFAULT auth.uid()
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_perm_id UUID;
  v_role_slug TEXT;
BEGIN
  IF NOT (
    public.has_permission('manage_roles')
    OR public.has_permission('configure_permissions')
    OR public.has_role('super_admin')
  ) THEN
    RAISE EXCEPTION 'not authorized to modify role permissions';
  END IF;

  SELECT id INTO v_perm_id FROM public.permissions WHERE slug = p_permission_slug;
  IF v_perm_id IS NULL THEN
    RAISE EXCEPTION 'unknown permission %', p_permission_slug;
  END IF;

  SELECT slug INTO v_role_slug FROM public.roles WHERE id = p_role_id;
  IF v_role_slug = 'super_admin' AND NOT public.has_role('super_admin') THEN
    RAISE EXCEPTION 'cannot modify super_admin permissions';
  END IF;

  IF p_granted THEN
    INSERT INTO public.role_permissions (role_id, permission_id)
    VALUES (p_role_id, v_perm_id)
    ON CONFLICT (role_id, permission_id) DO NOTHING;
  ELSE
    DELETE FROM public.role_permissions
    WHERE role_id = p_role_id AND permission_id = v_perm_id;
  END IF;

  INSERT INTO public.permission_audit (
    actor_id, action, role_slug, permission_slug, new_values
  ) VALUES (
    p_actor_id,
    CASE WHEN p_granted THEN 'permission_assigned' ELSE 'permission_removed' END,
    v_role_slug,
    p_permission_slug,
    jsonb_build_object('granted', p_granted)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_role_permission TO authenticated;

-- Grant new permissions to super_admin / admin where appropriate
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE r.slug = 'super_admin'
ON CONFLICT DO NOTHING;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
JOIN public.permissions p ON p.slug IN (
  'archive_property', 'view_users', 'create_users', 'export_users',
  'configure_permissions', 'export_finance', 'manage_refunds',
  'view_investments', 'approve_investments', 'manage_tickets'
)
WHERE r.slug = 'admin'
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

ALTER TABLE public.permission_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permission_group_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.approval_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.policy_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.resource_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delegated_admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.access_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.break_glass_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.access_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permission_audit ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS permission_groups_read ON public.permission_groups;
CREATE POLICY permission_groups_read ON public.permission_groups
  FOR SELECT USING (
    public.has_permission('manage_roles')
    OR public.has_permission('configure_permissions')
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS permission_groups_manage ON public.permission_groups;
CREATE POLICY permission_groups_manage ON public.permission_groups
  FOR ALL USING (
    public.has_permission('manage_roles')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS approval_policies_staff ON public.approval_policies;
CREATE POLICY approval_policies_staff ON public.approval_policies
  FOR SELECT USING (
    public.has_permission('manage_roles')
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS permission_audit_staff ON public.permission_audit;
CREATE POLICY permission_audit_staff ON public.permission_audit
  FOR SELECT USING (
    public.has_permission('view_audit_logs')
    OR public.has_permission('manage_roles')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS access_requests_own ON public.access_requests;
CREATE POLICY access_requests_own ON public.access_requests
  FOR SELECT USING (
    requester_id = auth.uid()
    OR public.has_permission('manage_roles')
    OR public.has_role('admin')
  );

DROP POLICY IF EXISTS break_glass_staff ON public.break_glass_sessions;
CREATE POLICY break_glass_staff ON public.break_glass_sessions
  FOR SELECT USING (
    user_id = auth.uid()
    OR public.has_role('super_admin')
  );

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.roles;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.role_permissions;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.permission_groups;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
