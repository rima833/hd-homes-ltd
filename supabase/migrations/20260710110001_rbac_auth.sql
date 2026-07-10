-- Migration 002: Authentication, RBAC, profiles, audit logs, settings, notifications

-- ---------------------------------------------------------------------------
-- Roles & Permissions (database-driven, no hardcoded permissions in app)
-- ---------------------------------------------------------------------------

CREATE TABLE public.roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  description TEXT,
  is_system BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  module TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.role_permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  role_id UUID NOT NULL REFERENCES public.roles(id) ON DELETE CASCADE,
  permission_id UUID NOT NULL REFERENCES public.permissions(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  UNIQUE (role_id, permission_id)
);

-- ---------------------------------------------------------------------------
-- User profiles (extends auth.users)
-- ---------------------------------------------------------------------------

CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  first_name TEXT,
  last_name TEXT,
  email TEXT NOT NULL,
  phone TEXT,
  avatar_url TEXT,
  address TEXT,
  country TEXT DEFAULT 'Nigeria',
  state TEXT,
  city TEXT,
  preferred_language TEXT DEFAULT 'en',
  notification_preferences JSONB NOT NULL DEFAULT '{}'::jsonb,
  account_status public.account_status NOT NULL DEFAULT 'pending_verification',
  last_login_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  role_id UUID NOT NULL REFERENCES public.roles(id) ON DELETE CASCADE,
  is_primary BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  UNIQUE (user_id, role_id)
);

CREATE TABLE public.user_permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  permission_id UUID NOT NULL REFERENCES public.permissions(id) ON DELETE CASCADE,
  granted BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  UNIQUE (user_id, permission_id)
);

-- ---------------------------------------------------------------------------
-- Audit logs
-- ---------------------------------------------------------------------------

CREATE TABLE public.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.profiles(id),
  action TEXT NOT NULL,
  module TEXT NOT NULL,
  entity_type TEXT,
  entity_id UUID,
  ip_address INET,
  user_agent TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

-- ---------------------------------------------------------------------------
-- App settings (company info, theme, SEO, etc.)
-- ---------------------------------------------------------------------------

CREATE TABLE public.app_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT NOT NULL UNIQUE,
  value JSONB NOT NULL DEFAULT '{}'::jsonb,
  category TEXT NOT NULL DEFAULT 'general',
  is_public BOOLEAN NOT NULL DEFAULT false,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

-- ---------------------------------------------------------------------------
-- Notifications (database-driven)
-- ---------------------------------------------------------------------------

CREATE TABLE public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT,
  channel TEXT NOT NULL DEFAULT 'in_app',
  is_read BOOLEAN NOT NULL DEFAULT false,
  read_at TIMESTAMPTZ,
  action_url TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------

CREATE INDEX idx_profiles_email ON public.profiles(email);
CREATE INDEX idx_profiles_account_status ON public.profiles(account_status);
CREATE INDEX idx_user_roles_user_id ON public.user_roles(user_id);
CREATE INDEX idx_user_roles_role_id ON public.user_roles(role_id);
CREATE INDEX idx_role_permissions_role_id ON public.role_permissions(role_id);
CREATE INDEX idx_audit_logs_user_id ON public.audit_logs(user_id);
CREATE INDEX idx_audit_logs_created_at ON public.audit_logs(created_at DESC);
CREATE INDEX idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX idx_notifications_is_read ON public.notifications(user_id, is_read);

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------

CREATE TRIGGER trg_roles_audit BEFORE INSERT OR UPDATE ON public.roles
  FOR EACH ROW EXECUTE FUNCTION public.set_audit_fields();
CREATE TRIGGER trg_permissions_audit BEFORE INSERT OR UPDATE ON public.permissions
  FOR EACH ROW EXECUTE FUNCTION public.set_audit_fields();
CREATE TRIGGER trg_profiles_audit BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_audit_fields();
CREATE TRIGGER trg_user_roles_audit BEFORE INSERT OR UPDATE ON public.user_roles
  FOR EACH ROW EXECUTE FUNCTION public.set_audit_fields();
CREATE TRIGGER trg_audit_logs_audit BEFORE INSERT OR UPDATE ON public.audit_logs
  FOR EACH ROW EXECUTE FUNCTION public.set_audit_fields();
CREATE TRIGGER trg_app_settings_audit BEFORE INSERT OR UPDATE ON public.app_settings
  FOR EACH ROW EXECUTE FUNCTION public.set_audit_fields();
CREATE TRIGGER trg_notifications_audit BEFORE INSERT OR UPDATE ON public.notifications
  FOR EACH ROW EXECUTE FUNCTION public.set_audit_fields();

-- ---------------------------------------------------------------------------
-- Permission helpers (SECURITY DEFINER – used by RLS policies)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_user_role_slugs(target_user_id UUID DEFAULT auth.uid())
RETURNS TEXT[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(array_agg(r.slug ORDER BY r.slug), ARRAY[]::TEXT[])
  FROM public.user_roles ur
  JOIN public.roles r ON r.id = ur.role_id
  WHERE ur.user_id = target_user_id
    AND ur.is_deleted = false
    AND ur.status = 'active'
    AND r.is_deleted = false
    AND r.status = 'active';
$$;

CREATE OR REPLACE FUNCTION public.has_role(role_slug TEXT, target_user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role_slug = ANY(public.get_user_role_slugs(target_user_id));
$$;

CREATE OR REPLACE FUNCTION public.has_permission(
  permission_slug TEXT,
  target_user_id UUID DEFAULT auth.uid()
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.user_permissions up
    JOIN public.permissions p ON p.id = up.permission_id
    WHERE up.user_id = target_user_id
      AND p.slug = permission_slug
      AND up.granted = false
      AND up.is_deleted = false
  ) THEN
    RETURN false;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.user_permissions up
    JOIN public.permissions p ON p.id = up.permission_id
    WHERE up.user_id = target_user_id
      AND p.slug = permission_slug
      AND up.granted = true
      AND up.is_deleted = false
      AND up.status = 'active'
  ) THEN
    RETURN true;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM public.user_roles ur
    JOIN public.role_permissions rp ON rp.role_id = ur.role_id
    JOIN public.permissions p ON p.id = rp.permission_id
    WHERE ur.user_id = target_user_id
      AND p.slug = permission_slug
      AND ur.is_deleted = false
      AND ur.status = 'active'
      AND rp.is_deleted = false
      AND rp.status = 'active'
      AND p.is_deleted = false
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.is_staff(target_user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.has_role('super_admin', target_user_id)
    OR public.has_role('admin', target_user_id)
    OR public.has_role('sales_team', target_user_id)
    OR public.has_role('finance', target_user_id)
    OR public.has_role('marketing', target_user_id)
    OR public.has_role('construction_manager', target_user_id);
$$;

-- ---------------------------------------------------------------------------
-- Auto-create profile + default role on signup
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  default_role_id UUID;
BEGIN
  INSERT INTO public.profiles (id, email, first_name, last_name, account_status)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data ->> 'first_name',
    NEW.raw_user_meta_data ->> 'last_name',
    CASE WHEN NEW.email_confirmed_at IS NOT NULL
      THEN 'active'::public.account_status
      ELSE 'pending_verification'::public.account_status
    END
  );

  SELECT id INTO default_role_id
  FROM public.roles
  WHERE slug = 'client' AND is_deleted = false
  LIMIT 1;

  IF default_role_id IS NOT NULL THEN
    INSERT INTO public.user_roles (user_id, role_id, is_primary)
    VALUES (NEW.id, default_role_id, true);
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Profiles: users see own; staff with manage_users can see all
CREATE POLICY profiles_select_own ON public.profiles
  FOR SELECT USING (
    id = auth.uid()
    OR public.has_permission('manage_users')
  );

CREATE POLICY profiles_update_own ON public.profiles
  FOR UPDATE USING (
    id = auth.uid()
    OR public.has_permission('manage_users')
  );

CREATE POLICY profiles_insert_self ON public.profiles
  FOR INSERT WITH CHECK (id = auth.uid());

-- Roles & permissions: readable by authenticated users; writable by super_admin
CREATE POLICY roles_select ON public.roles
  FOR SELECT TO authenticated USING (is_deleted = false);

CREATE POLICY roles_manage ON public.roles
  FOR ALL USING (public.has_role('super_admin'));

CREATE POLICY permissions_select ON public.permissions
  FOR SELECT TO authenticated USING (is_deleted = false);

CREATE POLICY permissions_manage ON public.permissions
  FOR ALL USING (public.has_role('super_admin'));

CREATE POLICY role_permissions_select ON public.role_permissions
  FOR SELECT TO authenticated USING (is_deleted = false);

CREATE POLICY role_permissions_manage ON public.role_permissions
  FOR ALL USING (public.has_role('super_admin'));

-- User roles: own roles visible; managed by admins
CREATE POLICY user_roles_select ON public.user_roles
  FOR SELECT USING (
    user_id = auth.uid()
    OR public.has_permission('manage_users')
  );

CREATE POLICY user_roles_manage ON public.user_roles
  FOR ALL USING (public.has_permission('manage_users'));

CREATE POLICY user_permissions_select ON public.user_permissions
  FOR SELECT USING (
    user_id = auth.uid()
    OR public.has_permission('manage_users')
  );

CREATE POLICY user_permissions_manage ON public.user_permissions
  FOR ALL USING (public.has_permission('manage_users'));

-- Audit logs: staff only
CREATE POLICY audit_logs_select ON public.audit_logs
  FOR SELECT USING (public.has_permission('manage_reports') OR public.has_role('super_admin'));

CREATE POLICY audit_logs_insert ON public.audit_logs
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- App settings: public settings readable by anyone; private by staff
CREATE POLICY app_settings_select_public ON public.app_settings
  FOR SELECT USING (is_public = true AND is_deleted = false);

CREATE POLICY app_settings_select_staff ON public.app_settings
  FOR SELECT USING (public.has_permission('manage_settings'));

CREATE POLICY app_settings_manage ON public.app_settings
  FOR ALL USING (public.has_permission('manage_settings'));

-- Notifications: own only
CREATE POLICY notifications_select_own ON public.notifications
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY notifications_update_own ON public.notifications
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY notifications_insert_staff ON public.notifications
  FOR INSERT WITH CHECK (public.is_staff());
