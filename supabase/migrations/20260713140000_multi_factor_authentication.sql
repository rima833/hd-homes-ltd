-- Volume 3 Part 6 — Multi-Factor Authentication (MFA)
-- Status: APPLIED remotely as multi_factor_authentication (approved 2026-07-13).

-- ---------------------------------------------------------------------------
-- MFA settings (business metadata; TOTP secrets live in Supabase Auth)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.mfa_settings (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  mfa_enabled BOOLEAN NOT NULL DEFAULT false,
  preferred_method TEXT,
  last_verified_at TIMESTAMPTZ,
  recovery_email_allowed BOOLEAN NOT NULL DEFAULT true,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Backup recovery codes (hashed; plaintext shown once in app)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.backup_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  code_hash TEXT NOT NULL,
  consumed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, code_hash)
);

CREATE INDEX IF NOT EXISTS idx_backup_codes_user_id
  ON public.backup_codes(user_id)
  WHERE consumed_at IS NULL;

-- ---------------------------------------------------------------------------
-- MFA audit events
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.mfa_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  event_type TEXT NOT NULL,
  success BOOLEAN NOT NULL DEFAULT true,
  method TEXT,
  user_agent TEXT,
  ip_address INET,
  device_fingerprint TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mfa_events_user_id
  ON public.mfa_events(user_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- Role-based MFA policies (Admin Panel editable)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.mfa_policies (
  role_slug TEXT PRIMARY KEY,
  requirement TEXT NOT NULL DEFAULT 'optional'
    CHECK (requirement IN ('optional', 'recommended', 'required', 'mandatory')),
  allow_email_fallback BOOLEAN NOT NULL DEFAULT true,
  allow_sms BOOLEAN NOT NULL DEFAULT false,
  trust_duration_days INT NOT NULL DEFAULT 30,
  max_trusted_devices INT NOT NULL DEFAULT 5,
  step_up_sensitive_actions BOOLEAN NOT NULL DEFAULT true,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.mfa_policies (
  role_slug, requirement, allow_email_fallback, allow_sms,
  trust_duration_days, max_trusted_devices
) VALUES
  ('client', 'optional', true, false, 30, 5),
  ('investor', 'recommended', true, false, 30, 5),
  ('sales_team', 'required', false, false, 30, 5),
  ('finance', 'required', false, false, 30, 5),
  ('marketing', 'required', false, false, 30, 5),
  ('construction_manager', 'required', false, false, 30, 5),
  ('admin', 'required', false, false, 21, 4),
  ('super_admin', 'mandatory', false, false, 14, 3)
ON CONFLICT (role_slug) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Trusted device MFA window
-- ---------------------------------------------------------------------------
ALTER TABLE public.trusted_devices
  ADD COLUMN IF NOT EXISTS mfa_trusted_until TIMESTAMPTZ;

ALTER TABLE public.trusted_devices
  ADD COLUMN IF NOT EXISTS first_trusted_at TIMESTAMPTZ;

-- ---------------------------------------------------------------------------
-- Optional session MFA metadata (future Adaptive Security Engine)
-- ---------------------------------------------------------------------------
ALTER TABLE public.user_sessions
  ADD COLUMN IF NOT EXISTS mfa_verified BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE public.user_sessions
  ADD COLUMN IF NOT EXISTS mfa_method TEXT;

ALTER TABLE public.user_sessions
  ADD COLUMN IF NOT EXISTS mfa_verified_at TIMESTAMPTZ;

ALTER TABLE public.user_sessions
  ADD COLUMN IF NOT EXISTS session_risk_score INT NOT NULL DEFAULT 0;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.mfa_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.backup_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mfa_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mfa_policies ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS mfa_settings_own ON public.mfa_settings;
CREATE POLICY mfa_settings_own ON public.mfa_settings
  FOR ALL USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS backup_codes_own ON public.backup_codes;
CREATE POLICY backup_codes_own ON public.backup_codes
  FOR ALL USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS mfa_events_insert ON public.mfa_events;
CREATE POLICY mfa_events_insert ON public.mfa_events
  FOR INSERT WITH CHECK (user_id IS NULL OR user_id = auth.uid());

DROP POLICY IF EXISTS mfa_events_select ON public.mfa_events;
CREATE POLICY mfa_events_select ON public.mfa_events
  FOR SELECT USING (
    user_id = auth.uid()
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS mfa_policies_read ON public.mfa_policies;
CREATE POLICY mfa_policies_read ON public.mfa_policies
  FOR SELECT USING (true);

DROP POLICY IF EXISTS mfa_policies_admin ON public.mfa_policies;
CREATE POLICY mfa_policies_admin ON public.mfa_policies
  FOR ALL USING (
    public.has_role('admin') OR public.has_role('super_admin')
  );

GRANT SELECT, INSERT, UPDATE ON public.mfa_settings TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.backup_codes TO authenticated;
GRANT SELECT, INSERT ON public.mfa_events TO authenticated;
GRANT SELECT ON public.mfa_policies TO anon, authenticated;
