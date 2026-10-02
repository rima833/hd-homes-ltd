-- Phase 2 — People / Roles / Permissions security + schema hardening
-- Additive only. Reuses staff_invitations, admin_invite_staff, set_role_permission.
-- Does not alter CRM / Finance / Construction portal schemas.

-- ---------------------------------------------------------------------------
-- 0) Helpers
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.can_manage_people()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.has_permission('manage_staff')
      OR public.has_permission('manage_organization')
      OR public.has_permission('manage_users')
      OR public.has_permission('hr.employees');
$$;

CREATE OR REPLACE FUNCTION public.can_view_people_directory()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.can_manage_people()
      OR public.has_permission('view_staff_directory')
      OR public.has_permission('view_organization')
      OR public.has_permission('hr.read');
$$;

CREATE OR REPLACE FUNCTION public.can_manage_rbac()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.has_permission('manage_roles')
      OR public.has_permission('configure_permissions')
      OR public.has_role('super_admin');
$$;

REVOKE ALL ON FUNCTION public.can_manage_people() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.can_view_people_directory() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.can_manage_rbac() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_manage_people() TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_view_people_directory() TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_manage_rbac() TO authenticated;

-- ---------------------------------------------------------------------------
-- 1) Schema gaps (additive)
-- ---------------------------------------------------------------------------
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS employee_id uuid;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'profiles_employee_id_fkey'
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT profiles_employee_id_fkey
      FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE SET NULL;
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS profiles_employee_id_uidx
  ON public.profiles (employee_id)
  WHERE employee_id IS NOT NULL;

UPDATE public.profiles p
SET employee_id = e.id
FROM public.employees e
WHERE e.user_id = p.id
  AND coalesce(e.is_deleted, false) = false
  AND (p.employee_id IS DISTINCT FROM e.id);

ALTER TABLE public.staff_invitations
  ADD COLUMN IF NOT EXISTS revoked_at timestamptz;

ALTER TABLE public.staff_invitations
  ADD COLUMN IF NOT EXISTS revoked_by uuid REFERENCES auth.users(id) ON DELETE SET NULL;

-- Allow clearing plaintext token after create/reveal cycle
ALTER TABLE public.staff_invitations
  ALTER COLUMN token DROP NOT NULL;

COMMENT ON COLUMN public.staff_invitations.token IS
  'Transient plaintext invite token. Cleared after create RPC returns; use reveal RPC to mint a new one. Prefer token_hash for lookup.';

COMMENT ON COLUMN public.staff_invitations.token_hash IS
  'SHA-256 hex of invite token. Primary acceptance lookup key.';

-- Backfill missing hashes from legacy plaintext tokens
UPDATE public.staff_invitations
SET token_hash = public.staff_invite_token_hash(token)
WHERE token_hash IS NULL
  AND token IS NOT NULL
  AND length(trim(token)) > 0;

-- Clear stored plaintext for existing rows that already have a hash
UPDATE public.staff_invitations
SET token = NULL
WHERE token_hash IS NOT NULL
  AND token IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 2) Indexes
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_employees_team_id
  ON public.employees (team_id)
  WHERE team_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_employees_status_dept
  ON public.employees (employment_status, department_id)
  WHERE coalesce(is_deleted, false) = false;

CREATE INDEX IF NOT EXISTS idx_employees_name_search
  ON public.employees USING gin (
    (coalesce(first_name, '') || ' ' || coalesce(last_name, '')) gin_trgm_ops
  );

CREATE INDEX IF NOT EXISTS idx_staff_invitations_status_expires
  ON public.staff_invitations (status, expires_at);

CREATE INDEX IF NOT EXISTS idx_staff_invitations_email_lower
  ON public.staff_invitations (lower(email));

CREATE INDEX IF NOT EXISTS idx_staff_invitations_token_hash
  ON public.staff_invitations (token_hash)
  WHERE token_hash IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 3) Permission coverage (idempotent)
-- ---------------------------------------------------------------------------
INSERT INTO public.permissions (slug, name, description, module)
VALUES
  ('manage_staff', 'Manage Staff', 'Create and manage employee records and staff invites', 'organization'),
  ('view_staff_directory', 'View Staff Directory', 'Read staff directory', 'organization'),
  ('view_organization', 'View Organization', 'View departments, teams, and org structure', 'organization'),
  ('manage_organization', 'Manage Organization', 'Create and edit departments and teams', 'organization'),
  ('manage_users', 'Manage Users', 'Manage platform user accounts and staff portal access', 'admin'),
  ('manage_roles', 'Manage Roles', 'Create roles and assign permissions', 'admin'),
  ('configure_permissions', 'Configure Permissions', 'Define and mutate permission catalog grants', 'admin'),
  ('view_audit_logs', 'View Audit Logs', 'Read security and admin audit events', 'admin'),
  ('hr.read', 'HR Read', 'Read HR module data', 'hr'),
  ('hr.write', 'HR Write', 'Write HR module data', 'hr'),
  ('hr.employees', 'HR Employees', 'Manage employee HR records', 'hr'),
  ('hr.attendance', 'HR Attendance', 'Manage attendance records', 'hr'),
  ('hr.approvals', 'HR Approvals', 'Approve HR workflows', 'hr')
ON CONFLICT (slug) DO NOTHING;

-- Grant people + RBAC bundle to super_admin + admin
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE r.slug IN ('super_admin', 'admin')
  AND coalesce(r.is_deleted, false) = false
  AND coalesce(p.is_deleted, false) = false
  AND p.slug IN (
    'manage_staff',
    'view_staff_directory',
    'view_organization',
    'manage_organization',
    'manage_users',
    'manage_roles',
    'view_audit_logs',
    'hr.read',
    'hr.write',
    'hr.employees',
    'hr.attendance',
    'hr.approvals'
  )
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- super_admin only: configure_permissions
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE r.slug = 'super_admin'
  AND p.slug = 'configure_permissions'
  AND coalesce(r.is_deleted, false) = false
  AND coalesce(p.is_deleted, false) = false
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 4) RLS: profiles directory enrichment + RBAC write path for manage_roles
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS profiles_select_own ON public.profiles;
CREATE POLICY profiles_select_own ON public.profiles
  FOR SELECT TO authenticated
  USING (
    id = auth.uid()
    OR public.can_view_people_directory()
    OR public.has_permission('manage_users')
  );

DROP POLICY IF EXISTS profiles_update_own ON public.profiles;
CREATE POLICY profiles_update_own ON public.profiles
  FOR UPDATE TO authenticated
  USING (
    id = auth.uid()
    OR public.has_permission('manage_users')
    OR public.can_manage_people()
  )
  WITH CHECK (
    id = auth.uid()
    OR public.has_permission('manage_users')
    OR public.can_manage_people()
  );

-- Keep website public employee read; expand authenticated staff read via helper
DROP POLICY IF EXISTS employees_read ON public.employees;
CREATE POLICY employees_read ON public.employees
  FOR SELECT TO public
  USING (
    user_id = auth.uid()
    OR public.can_view_people_directory()
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS employees_manage ON public.employees;
CREATE POLICY employees_manage ON public.employees
  FOR ALL TO public
  USING (public.can_manage_people() OR public.has_role('admin') OR public.has_role('super_admin'))
  WITH CHECK (public.can_manage_people() OR public.has_role('admin') OR public.has_role('super_admin'));

DROP POLICY IF EXISTS departments_read ON public.departments;
CREATE POLICY departments_read ON public.departments
  FOR SELECT TO public
  USING (
    public.can_view_people_directory()
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS departments_manage ON public.departments;
CREATE POLICY departments_manage ON public.departments
  FOR ALL TO public
  USING (
    public.has_permission('manage_organization')
    OR public.can_manage_people()
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  )
  WITH CHECK (
    public.has_permission('manage_organization')
    OR public.can_manage_people()
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS teams_read ON public.teams;
CREATE POLICY teams_read ON public.teams
  FOR SELECT TO public
  USING (
    public.can_view_people_directory()
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS teams_manage ON public.teams;
CREATE POLICY teams_manage ON public.teams
  FOR ALL TO public
  USING (
    public.has_permission('manage_organization')
    OR public.can_manage_people()
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  )
  WITH CHECK (
    public.has_permission('manage_organization')
    OR public.can_manage_people()
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS staff_invitations_select ON public.staff_invitations;
CREATE POLICY staff_invitations_select ON public.staff_invitations
  FOR SELECT TO public
  USING (
    public.can_manage_people()
    OR invited_by = auth.uid()
    OR lower(email) = lower(coalesce((auth.jwt() ->> 'email'), ''))
  );

DROP POLICY IF EXISTS staff_invitations_manage ON public.staff_invitations;
CREATE POLICY staff_invitations_manage ON public.staff_invitations
  FOR ALL TO public
  USING (public.can_manage_people())
  WITH CHECK (public.can_manage_people());

-- user_roles: people managers can read assignments; mutations stay gated
DROP POLICY IF EXISTS user_roles_select ON public.user_roles;
CREATE POLICY user_roles_select ON public.user_roles
  FOR SELECT TO public
  USING (
    user_id = auth.uid()
    OR public.has_permission('manage_users')
    OR public.can_manage_people()
    OR public.can_manage_rbac()
  );

DROP POLICY IF EXISTS user_roles_manage ON public.user_roles;
CREATE POLICY user_roles_manage ON public.user_roles
  FOR ALL TO public
  USING (
    public.has_permission('manage_users')
    OR public.can_manage_rbac()
  )
  WITH CHECK (
    public.has_permission('manage_users')
    OR public.can_manage_rbac()
  );

-- roles / role_permissions writes: permission-based (not super_admin-only)
DROP POLICY IF EXISTS roles_manage ON public.roles;
CREATE POLICY roles_manage ON public.roles
  FOR ALL TO public
  USING (public.can_manage_rbac())
  WITH CHECK (public.can_manage_rbac());

DROP POLICY IF EXISTS role_permissions_manage ON public.role_permissions;
CREATE POLICY role_permissions_manage ON public.role_permissions
  FOR ALL TO public
  USING (public.can_manage_rbac())
  WITH CHECK (public.can_manage_rbac());

DROP POLICY IF EXISTS permissions_manage ON public.permissions;
CREATE POLICY permissions_manage ON public.permissions
  FOR ALL TO public
  USING (
    public.has_permission('configure_permissions')
    OR public.has_role('super_admin')
  )
  WITH CHECK (
    public.has_permission('configure_permissions')
    OR public.has_role('super_admin')
  );

-- ---------------------------------------------------------------------------
-- 5) Deactivate / reactivate employee RPCs
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.deactivate_employee(
  p_employee_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS public.employees
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.employees;
  v_actor uuid := auth.uid();
BEGIN
  IF v_actor IS NULL OR NOT public.can_manage_people() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.employees e
  SET
    employment_status = 'inactive',
    deactivated_at = now(),
    deactivated_by = v_actor,
    deactivation_reason = nullif(trim(coalesce(p_reason, '')), ''),
    left_at = coalesce(e.left_at, now()),
    updated_at = now(),
    updated_by = v_actor
  WHERE e.id = p_employee_id
    AND coalesce(e.is_deleted, false) = false
  RETURNING * INTO v_row;

  IF v_row.id IS NULL THEN
    RAISE EXCEPTION 'employee_not_found';
  END IF;

  IF v_row.user_id IS NOT NULL THEN
    UPDATE public.user_roles
    SET
      status = 'revoked',
      is_deleted = true,
      updated_at = now(),
      updated_by = v_actor
    WHERE user_id = v_row.user_id
      AND coalesce(is_deleted, false) = false
      AND coalesce(status, 'active') = 'active';
  END IF;

  INSERT INTO public.audit_logs (user_id, action, module, entity_type, entity_id, metadata)
  VALUES (
    v_actor,
    'employee.deactivate',
    'people',
    'employee',
    v_row.id::text,
    jsonb_build_object(
      'reason', p_reason,
      'user_id', v_row.user_id,
      'email', v_row.email
    )
  );

  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.reactivate_employee(p_employee_id uuid)
RETURNS public.employees
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.employees;
  v_actor uuid := auth.uid();
BEGIN
  IF v_actor IS NULL OR NOT public.can_manage_people() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.employees e
  SET
    employment_status = 'active',
    deactivated_at = NULL,
    deactivated_by = NULL,
    deactivation_reason = NULL,
    left_at = NULL,
    updated_at = now(),
    updated_by = v_actor
  WHERE e.id = p_employee_id
    AND coalesce(e.is_deleted, false) = false
  RETURNING * INTO v_row;

  IF v_row.id IS NULL THEN
    RAISE EXCEPTION 'employee_not_found';
  END IF;

  INSERT INTO public.audit_logs (user_id, action, module, entity_type, entity_id, metadata)
  VALUES (
    v_actor,
    'employee.reactivate',
    'people',
    'employee',
    v_row.id::text,
    jsonb_build_object('user_id', v_row.user_id, 'email', v_row.email)
  );

  RETURN v_row;
END;
$$;

REVOKE ALL ON FUNCTION public.deactivate_employee(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.reactivate_employee(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.deactivate_employee(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reactivate_employee(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 6) Invite token hygiene + revoke audit (preserve RPC names)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_invite_staff(
  p_email text,
  p_role_slug text,
  p_first_name text DEFAULT NULL,
  p_last_name text DEFAULT NULL,
  p_phone text DEFAULT NULL,
  p_department_id uuid DEFAULT NULL,
  p_team_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_email text := lower(trim(p_email));
  v_role text := lower(trim(p_role_slug));
  v_token text;
  v_hash text;
  v_employee_id uuid;
  v_code text;
  v_existing uuid;
  v_invite public.staff_invitations%ROWTYPE;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF v_email IS NULL OR position('@' in v_email) = 0 THEN RAISE EXCEPTION 'invalid_email'; END IF;
  IF NOT public.staff_invite_can_assign(v_role, v_actor) THEN
    RAISE EXCEPTION 'forbidden_role_assignment:%', v_role;
  END IF;

  UPDATE public.staff_invitations
  SET status = 'revoked', revoked_at = now(), revoked_by = v_actor, updated_at = now(), token = NULL
  WHERE lower(email) = v_email AND status = 'pending';

  v_token := encode(gen_random_bytes(24), 'hex');
  v_hash := public.staff_invite_token_hash(v_token);

  SELECT id INTO v_employee_id FROM public.employees
  WHERE lower(coalesce(email, work_email, '')) = v_email
    AND coalesce(is_deleted, false) = false
  LIMIT 1;

  IF v_employee_id IS NULL THEN
    SELECT 'HDH-EMP-' || lpad((coalesce(max(NULLIF(regexp_replace(employee_code, '\D', '', 'g'), '')::int), 0) + 1)::text, 4, '0')
    INTO v_code FROM public.employees;

    INSERT INTO public.employees (
      employee_code, first_name, last_name, email, work_email, phone,
      department_id, team_id, role_slug, employment_status, created_by
    ) VALUES (
      coalesce(v_code, 'HDH-EMP-0001'),
      coalesce(nullif(trim(p_first_name), ''), split_part(v_email, '@', 1)),
      coalesce(nullif(trim(p_last_name), ''), 'Staff'),
      v_email, v_email, nullif(trim(p_phone), ''),
      p_department_id, p_team_id, v_role, 'probation', v_actor
    ) RETURNING id INTO v_employee_id;
  ELSE
    UPDATE public.employees SET
      role_slug = v_role,
      department_id = coalesce(p_department_id, department_id),
      team_id = coalesce(p_team_id, team_id),
      first_name = coalesce(nullif(trim(p_first_name), ''), first_name),
      last_name = coalesce(nullif(trim(p_last_name), ''), last_name),
      phone = coalesce(nullif(trim(p_phone), ''), phone),
      updated_at = now(), updated_by = v_actor
    WHERE id = v_employee_id;
  END IF;

  -- Persist hash only; return plaintext once via RPC payload
  INSERT INTO public.staff_invitations (
    email, role_slug, first_name, last_name, phone,
    department_id, team_id, employee_id, invited_by, token, token_hash, status
  ) VALUES (
    v_email, v_role, nullif(trim(p_first_name), ''), nullif(trim(p_last_name), ''),
    nullif(trim(p_phone), ''), p_department_id, p_team_id, v_employee_id, v_actor,
    NULL, v_hash, 'pending'
  ) RETURNING * INTO v_invite;

  SELECT id INTO v_existing FROM auth.users WHERE lower(email) = v_email LIMIT 1;
  IF v_existing IS NOT NULL THEN
    PERFORM public._apply_staff_role_to_user(v_existing, v_role, v_actor);
    UPDATE public.employees SET user_id = v_existing, employment_status = 'active',
      updated_at = now(), updated_by = v_actor WHERE id = v_employee_id;
    UPDATE public.profiles SET employee_id = v_employee_id WHERE id = v_existing;
    UPDATE public.staff_invitations SET status = 'accepted', accepted_at = now(),
      accepted_user_id = v_existing, updated_at = now()
    WHERE id = v_invite.id RETURNING * INTO v_invite;
  END IF;

  INSERT INTO public.audit_logs (user_id, action, module, entity_type, entity_id, metadata)
  VALUES (v_actor, 'staff.invite', 'people', 'staff_invitation', v_invite.id::text,
    jsonb_build_object('email', v_email, 'role_slug', v_role, 'employee_id', v_employee_id, 'status', v_invite.status));

  RETURN jsonb_build_object(
    'id', v_invite.id, 'email', v_invite.email, 'role_slug', v_invite.role_slug,
    'token', CASE WHEN v_invite.status = 'pending' THEN v_token ELSE NULL END,
    'status', v_invite.status, 'employee_id', v_invite.employee_id,
    'expires_at', v_invite.expires_at, 'accepted_user_id', v_invite.accepted_user_id,
    'already_had_account', v_existing IS NOT NULL
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_reveal_staff_invite_token(p_invite_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v public.staff_invitations%ROWTYPE;
  v_token text;
  v_hash text;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;
  IF NOT public.can_manage_people() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT * INTO v FROM public.staff_invitations WHERE id = p_invite_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'invite_not_found';
  END IF;
  IF v.status <> 'pending' OR v.expires_at < now() THEN
    RAISE EXCEPTION 'invite_not_pending';
  END IF;

  -- Mint a fresh token; store hash only
  v_token := encode(gen_random_bytes(24), 'hex');
  v_hash := public.staff_invite_token_hash(v_token);

  UPDATE public.staff_invitations
  SET token = NULL, token_hash = v_hash, updated_at = now()
  WHERE id = v.id;

  INSERT INTO public.audit_logs (user_id, action, module, entity_type, entity_id, metadata)
  VALUES (
    v_actor,
    'staff.invite_token_reveal',
    'people',
    'staff_invitation',
    v.id::text,
    jsonb_build_object('email', v.email)
  );

  RETURN jsonb_build_object(
    'id', v.id,
    'email', v.email,
    'token', v_token,
    'expires_at', v.expires_at
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_revoke_staff_invite(p_invite_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_id uuid;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF NOT public.can_manage_people() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE public.staff_invitations
  SET
    status = 'revoked',
    revoked_at = now(),
    revoked_by = v_actor,
    token = NULL,
    updated_at = now()
  WHERE id = p_invite_id
    AND status = 'pending'
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'invite_not_pending';
  END IF;

  INSERT INTO public.audit_logs (user_id, action, module, entity_type, entity_id, metadata)
  VALUES (v_actor, 'staff.invite_revoke', 'people', 'staff_invitation', v_id::text, '{}'::jsonb);
END;
$$;

-- Lookup prefers hash (plaintext column may be null)
CREATE OR REPLACE FUNCTION public.staff_invite_lookup(p_token text)
RETURNS staff_invitations
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v public.staff_invitations%ROWTYPE;
  v_hash text := public.staff_invite_token_hash(p_token);
BEGIN
  SELECT * INTO v
  FROM public.staff_invitations
  WHERE token_hash = v_hash
     OR (token IS NOT NULL AND token = trim(p_token))
  ORDER BY created_at DESC
  LIMIT 1;
  RETURN v;
END;
$$;

-- ---------------------------------------------------------------------------
-- 7) Guard: do not strip critical super_admin grants
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enforce_role_permission_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role_slug text;
  v_perm_slug text;
BEGIN
  IF TG_OP = 'DELETE' THEN
    SELECT slug INTO v_role_slug FROM public.roles WHERE id = OLD.role_id;
    SELECT slug INTO v_perm_slug FROM public.permissions WHERE id = OLD.permission_id;

    IF v_role_slug = 'super_admin'
       AND v_perm_slug IN ('manage_roles', 'configure_permissions', 'manage_users') THEN
      RAISE EXCEPTION 'Cannot revoke % from super_admin', v_perm_slug;
    END IF;
    RETURN OLD;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_role_permissions_guard ON public.role_permissions;
CREATE TRIGGER trg_role_permissions_guard
  BEFORE DELETE ON public.role_permissions
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_role_permission_guard();

-- Harden set_role_permission against stripping super_admin critical grants
CREATE OR REPLACE FUNCTION public.set_role_permission(
  p_role_id uuid,
  p_permission_slug text,
  p_granted boolean,
  p_actor_id uuid DEFAULT auth.uid()
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_perm_id uuid;
  v_role_slug text;
BEGIN
  IF NOT public.can_manage_rbac() THEN
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

  IF NOT p_granted
     AND v_role_slug = 'super_admin'
     AND p_permission_slug IN ('manage_roles', 'configure_permissions', 'manage_users') THEN
    RAISE EXCEPTION 'Cannot revoke % from super_admin', p_permission_slug;
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

-- ---------------------------------------------------------------------------
-- 8) Realtime publication (idempotent)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.employees;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.departments;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.teams;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.staff_invitations;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.user_roles;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.roles;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.permissions;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.role_permissions;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
END $$;
