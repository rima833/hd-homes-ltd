-- Volume 3 Part 4 — Email & Phone Verification
-- Status: APPLIED remotely as email_phone_verification (approved 2026-07-13).

-- ---------------------------------------------------------------------------
-- verification_events (audit + Verification Health Dashboard feed)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.verification_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  channel TEXT NOT NULL CHECK (channel IN ('email', 'phone')),
  event_type TEXT NOT NULL,
  success BOOLEAN NOT NULL DEFAULT true,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_verification_events_user_id
  ON public.verification_events(user_id);
CREATE INDEX IF NOT EXISTS idx_verification_events_created_at
  ON public.verification_events(created_at DESC);

-- ---------------------------------------------------------------------------
-- email / phone change requests
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.email_change_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  new_email TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  expires_at TIMESTAMPTZ DEFAULT (now() + interval '24 hours'),
  confirmed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_email_change_requests_user_id
  ON public.email_change_requests(user_id);

CREATE TABLE IF NOT EXISTS public.phone_change_requests (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  new_phone TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  verified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- otp_requests (server-side metadata; codes never stored in plaintext here)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.otp_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  phone TEXT NOT NULL,
  purpose TEXT NOT NULL DEFAULT 'phone_verify',
  provider TEXT,
  external_request_id TEXT,
  expires_at TIMESTAMPTZ NOT NULL,
  consumed_at TIMESTAMPTZ,
  attempt_count INT NOT NULL DEFAULT 0,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_otp_requests_user_id ON public.otp_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_otp_requests_phone ON public.otp_requests(phone);

-- ---------------------------------------------------------------------------
-- profiles: phone verification flag + trust score foundation
-- ---------------------------------------------------------------------------

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS phone_verified BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS trust_score INT NOT NULL DEFAULT 0;

-- ---------------------------------------------------------------------------
-- Role verification policies (admin-editable without code changes)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.verification_policies (
  role_slug TEXT PRIMARY KEY,
  email_required BOOLEAN NOT NULL DEFAULT true,
  phone_requirement TEXT NOT NULL DEFAULT 'optional'
    CHECK (phone_requirement IN ('disabled', 'optional', 'required')),
  mfa_recommended BOOLEAN NOT NULL DEFAULT false,
  block_protected_until_email_verified BOOLEAN NOT NULL DEFAULT true,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.verification_policies (role_slug, email_required, phone_requirement, mfa_recommended)
VALUES
  ('client', true, 'optional', false),
  ('investor', true, 'required', false),
  ('sales_team', true, 'required', false),
  ('finance', true, 'required', false),
  ('marketing', true, 'required', false),
  ('construction_manager', true, 'required', false),
  ('admin', true, 'required', true),
  ('super_admin', true, 'required', true)
ON CONFLICT (role_slug) DO NOTHING;

-- ---------------------------------------------------------------------------
-- RPCs
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.record_verification_event(
  p_user_id UUID DEFAULT NULL,
  p_channel TEXT DEFAULT 'email',
  p_event_type TEXT DEFAULT 'unknown',
  p_success BOOLEAN DEFAULT true,
  p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID;
BEGIN
  INSERT INTO public.verification_events (
    user_id, channel, event_type, success, metadata
  ) VALUES (
    p_user_id, p_channel, p_event_type, p_success, COALESCE(p_metadata, '{}'::jsonb)
  )
  RETURNING id INTO v_id;

  -- Trust score bumps on successful verifications
  IF p_success AND p_user_id IS NOT NULL THEN
    IF p_event_type IN ('email_verified', 'otp_verified', 'phone_verified') THEN
      UPDATE public.profiles
      SET
        phone_verified = CASE
          WHEN p_channel = 'phone' THEN true
          ELSE phone_verified
        END,
        trust_score = LEAST(
          50,
          trust_score + CASE WHEN p_channel = 'phone' THEN 25 ELSE 25 END
        ),
        account_status = CASE
          WHEN p_channel = 'email' AND account_status = 'pending_verification'
            THEN 'active'::public.account_status
          ELSE account_status
        END,
        updated_at = now()
      WHERE id = p_user_id;
    END IF;
  END IF;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.record_verification_event(UUID, TEXT, TEXT, BOOLEAN, JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_verification_event(UUID, TEXT, TEXT, BOOLEAN, JSONB)
  TO anon, authenticated;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

ALTER TABLE public.verification_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_change_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.phone_change_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.otp_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.verification_policies ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS verification_events_own ON public.verification_events;
CREATE POLICY verification_events_own ON public.verification_events
  FOR SELECT USING (
    user_id = auth.uid()
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS verification_events_insert ON public.verification_events;
CREATE POLICY verification_events_insert ON public.verification_events
  FOR INSERT WITH CHECK (user_id IS NULL OR user_id = auth.uid());

DROP POLICY IF EXISTS email_change_own ON public.email_change_requests;
CREATE POLICY email_change_own ON public.email_change_requests
  FOR ALL USING (user_id = auth.uid());

DROP POLICY IF EXISTS phone_change_own ON public.phone_change_requests;
CREATE POLICY phone_change_own ON public.phone_change_requests
  FOR ALL USING (user_id = auth.uid());

DROP POLICY IF EXISTS otp_requests_own ON public.otp_requests;
CREATE POLICY otp_requests_own ON public.otp_requests
  FOR SELECT USING (user_id = auth.uid() OR public.has_role('admin'));

DROP POLICY IF EXISTS otp_requests_insert ON public.otp_requests;
CREATE POLICY otp_requests_insert ON public.otp_requests
  FOR INSERT WITH CHECK (user_id IS NULL OR user_id = auth.uid());

DROP POLICY IF EXISTS verification_policies_read ON public.verification_policies;
CREATE POLICY verification_policies_read ON public.verification_policies
  FOR SELECT USING (true);

GRANT SELECT, INSERT ON public.verification_events TO authenticated, anon;
GRANT SELECT, INSERT, UPDATE ON public.email_change_requests TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.phone_change_requests TO authenticated;
GRANT SELECT, INSERT ON public.otp_requests TO authenticated, anon;
GRANT SELECT ON public.verification_policies TO authenticated, anon;
