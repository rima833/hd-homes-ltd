-- Volume 3 Part 1 — Identity Platform: sessions, devices, login history, security events
-- Status: APPLIED to remote project wbonjdqsifwsawhhxygl (2026-07-13).
-- Extends existing profiles / RBAC from migration 002.

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------

DO $$ BEGIN
  CREATE TYPE public.security_event_severity AS ENUM ('info', 'warning', 'critical');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- Application-tracked sessions (complements auth.sessions)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.user_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  auth_session_id UUID,
  device_id UUID,
  refresh_token_hash TEXT,
  user_agent TEXT,
  ip_address INET,
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ,
  revoke_reason TEXT,
  is_current BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

-- ---------------------------------------------------------------------------
-- Trusted / known devices
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.trusted_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  device_fingerprint TEXT NOT NULL,
  device_name TEXT,
  browser TEXT,
  operating_system TEXT,
  last_activity_at TIMESTAMPTZ,
  last_location TEXT,
  is_trusted BOOLEAN NOT NULL DEFAULT false,
  revoked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  UNIQUE (user_id, device_fingerprint)
);

ALTER TABLE public.user_sessions
  DROP CONSTRAINT IF EXISTS user_sessions_device_id_fkey;
ALTER TABLE public.user_sessions
  ADD CONSTRAINT user_sessions_device_id_fkey
  FOREIGN KEY (device_id) REFERENCES public.trusted_devices(id) ON DELETE SET NULL;

-- ---------------------------------------------------------------------------
-- Login history
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.login_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  email TEXT,
  success BOOLEAN NOT NULL,
  failure_reason TEXT,
  user_agent TEXT,
  ip_address INET,
  device_fingerprint TEXT,
  location_approx TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb
);

-- ---------------------------------------------------------------------------
-- Security events (Admin Security Center feed)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.security_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  event_type TEXT NOT NULL,
  severity public.security_event_severity NOT NULL DEFAULT 'info',
  description TEXT,
  user_agent TEXT,
  ip_address INET,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  reviewed_at TIMESTAMPTZ,
  reviewed_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Alias table for authentication_logs (spec naming)
CREATE TABLE IF NOT EXISTS public.authentication_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  success BOOLEAN NOT NULL DEFAULT true,
  user_agent TEXT,
  ip_address INET,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- User preferences (beyond notification_preferences JSON on profiles)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.user_preferences (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  theme TEXT DEFAULT 'system',
  locale TEXT DEFAULT 'en',
  timezone TEXT DEFAULT 'Africa/Lagos',
  marketing_opt_in BOOLEAN NOT NULL DEFAULT false,
  product_updates_opt_in BOOLEAN NOT NULL DEFAULT true,
  extras JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.notification_preferences (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  email_enabled BOOLEAN NOT NULL DEFAULT true,
  sms_enabled BOOLEAN NOT NULL DEFAULT false,
  push_enabled BOOLEAN NOT NULL DEFAULT true,
  marketing_email BOOLEAN NOT NULL DEFAULT false,
  security_alerts BOOLEAN NOT NULL DEFAULT true,
  extras JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Investor role (distinct from client) — additive, system role
-- ---------------------------------------------------------------------------

INSERT INTO public.roles (name, slug, description, is_system)
VALUES ('Investor', 'investor', 'Investment portfolio access', true)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE r.slug = 'investor'
  AND p.slug IN ('view_properties', 'manage_reports')
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Helper: list permission slugs for a user
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_user_permission_slugs(target_user_id UUID DEFAULT auth.uid())
RETURNS TEXT[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH denied AS (
    SELECT p.slug
    FROM public.user_permissions up
    JOIN public.permissions p ON p.id = up.permission_id
    WHERE up.user_id = target_user_id
      AND up.granted = false
      AND up.is_deleted = false
  ),
  granted AS (
    SELECT p.slug
    FROM public.user_permissions up
    JOIN public.permissions p ON p.id = up.permission_id
    WHERE up.user_id = target_user_id
      AND up.granted = true
      AND up.is_deleted = false
      AND up.status = 'active'
    UNION
    SELECT p.slug
    FROM public.user_roles ur
    JOIN public.role_permissions rp ON rp.role_id = ur.role_id
    JOIN public.permissions p ON p.id = rp.permission_id
    WHERE ur.user_id = target_user_id
      AND ur.is_deleted = false
      AND ur.status = 'active'
      AND rp.is_deleted = false
      AND rp.status = 'active'
      AND p.is_deleted = false
  )
  SELECT COALESCE(array_agg(DISTINCT g.slug ORDER BY g.slug), ARRAY[]::TEXT[])
  FROM granted g
  WHERE g.slug NOT IN (SELECT d.slug FROM denied d);
$$;

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON public.user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_trusted_devices_user_id ON public.trusted_devices(user_id);
CREATE INDEX IF NOT EXISTS idx_login_history_user_id ON public.login_history(user_id);
CREATE INDEX IF NOT EXISTS idx_login_history_created_at ON public.login_history(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_security_events_user_id ON public.security_events(user_id);
CREATE INDEX IF NOT EXISTS idx_security_events_created_at ON public.security_events(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_authentication_logs_user_id ON public.authentication_logs(user_id);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

ALTER TABLE public.user_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trusted_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.login_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.security_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.authentication_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_sessions_own ON public.user_sessions
  FOR SELECT USING (user_id = auth.uid() OR public.has_role('admin') OR public.has_role('super_admin'));

CREATE POLICY user_sessions_own_update ON public.user_sessions
  FOR UPDATE USING (user_id = auth.uid() OR public.has_role('admin') OR public.has_role('super_admin'));

CREATE POLICY trusted_devices_own ON public.trusted_devices
  FOR ALL USING (user_id = auth.uid() OR public.has_role('admin') OR public.has_role('super_admin'));

CREATE POLICY login_history_own ON public.login_history
  FOR SELECT USING (user_id = auth.uid() OR public.has_role('admin') OR public.has_role('super_admin'));

CREATE POLICY security_events_staff ON public.security_events
  FOR SELECT USING (public.has_role('admin') OR public.has_role('super_admin') OR user_id = auth.uid());

CREATE POLICY authentication_logs_own ON public.authentication_logs
  FOR SELECT USING (user_id = auth.uid() OR public.has_role('admin') OR public.has_role('super_admin'));

CREATE POLICY user_preferences_own ON public.user_preferences
  FOR ALL USING (user_id = auth.uid());

CREATE POLICY notification_preferences_own ON public.notification_preferences
  FOR ALL USING (user_id = auth.uid());

-- Inserts for login/security typically via SECURITY DEFINER edge functions later.
GRANT SELECT, UPDATE ON public.user_sessions TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.trusted_devices TO authenticated;
GRANT SELECT ON public.login_history TO authenticated;
GRANT SELECT ON public.security_events TO authenticated;
GRANT SELECT ON public.authentication_logs TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.user_preferences TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.notification_preferences TO authenticated;
