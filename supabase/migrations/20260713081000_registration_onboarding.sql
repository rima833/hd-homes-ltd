-- Volume 3 Part 2 — Registration & onboarding tables + signup trigger updates
-- Status: APPLIED remotely as registration_onboarding (approved 2026-07-13).

-- ---------------------------------------------------------------------------
-- Legal acceptances (auditable consent)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.legal_acceptances (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  document_type TEXT NOT NULL,
  document_version TEXT NOT NULL,
  accepted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ip_address INET,
  user_agent TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_legal_acceptances_user_id ON public.legal_acceptances(user_id);

-- ---------------------------------------------------------------------------
-- Referral system
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.referral_links (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  owner_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  label TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE IF NOT EXISTS public.user_referrals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referred_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  referrer_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  referral_code TEXT NOT NULL,
  reward_status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (referred_user_id)
);

-- ---------------------------------------------------------------------------
-- Registration analytics events
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.registration_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_key TEXT,
  user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  event_type TEXT NOT NULL,
  step TEXT,
  account_type TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_registration_events_created_at
  ON public.registration_events(created_at DESC);

-- ---------------------------------------------------------------------------
-- Security settings per user
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.security_settings (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  mfa_enabled BOOLEAN NOT NULL DEFAULT false,
  login_alerts BOOLEAN NOT NULL DEFAULT true,
  require_reauth_for_sensitive BOOLEAN NOT NULL DEFAULT true,
  extras JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Ensure preference tables exist (also in Part 1 draft)
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
-- Update signup trigger: role from account_type + profile fields + prefs
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  default_role_id UUID;
  role_slug TEXT;
  account_type TEXT;
BEGIN
  account_type := COALESCE(NEW.raw_user_meta_data ->> 'account_type', 'client');
  role_slug := CASE
    WHEN account_type = 'investor' THEN 'investor'
    ELSE 'client'
  END;

  INSERT INTO public.profiles (
    id, email, first_name, last_name, phone, country, state, city, account_status
  )
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data ->> 'first_name',
    NEW.raw_user_meta_data ->> 'last_name',
    NEW.raw_user_meta_data ->> 'phone',
    COALESCE(NEW.raw_user_meta_data ->> 'country', 'Nigeria'),
    NEW.raw_user_meta_data ->> 'state',
    NEW.raw_user_meta_data ->> 'city',
    CASE WHEN NEW.email_confirmed_at IS NOT NULL
      THEN 'active'::public.account_status
      ELSE 'pending_verification'::public.account_status
    END
  );

  SELECT id INTO default_role_id
  FROM public.roles
  WHERE slug = role_slug AND is_deleted = false
  LIMIT 1;

  -- Fallback to client if investor role not seeded yet
  IF default_role_id IS NULL THEN
    SELECT id INTO default_role_id
    FROM public.roles
    WHERE slug = 'client' AND is_deleted = false
    LIMIT 1;
  END IF;

  IF default_role_id IS NOT NULL THEN
    INSERT INTO public.user_roles (user_id, role_id, is_primary)
    VALUES (NEW.id, default_role_id, true);
  END IF;

  INSERT INTO public.user_preferences (
    user_id, marketing_opt_in, product_updates_opt_in
  ) VALUES (
    NEW.id,
    COALESCE((NEW.raw_user_meta_data ->> 'marketing_opt_in')::boolean, false),
    COALESCE((NEW.raw_user_meta_data ->> 'product_updates_opt_in')::boolean, true)
  )
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO public.notification_preferences (
    user_id, marketing_email
  ) VALUES (
    NEW.id,
    COALESCE((NEW.raw_user_meta_data ->> 'newsletter_opt_in')::boolean, false)
  )
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO public.security_settings (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;

  -- Legal acceptances from metadata versions
  IF NEW.raw_user_meta_data ? 'terms_version' THEN
    INSERT INTO public.legal_acceptances (user_id, document_type, document_version)
    VALUES
      (NEW.id, 'terms', NEW.raw_user_meta_data ->> 'terms_version'),
      (NEW.id, 'privacy', COALESCE(NEW.raw_user_meta_data ->> 'privacy_version', 'privacy-v1.0')),
      (NEW.id, 'cookies', COALESCE(NEW.raw_user_meta_data ->> 'cookies_version', 'cookies-v1.0'));
  END IF;

  -- Referral association (no rewards yet)
  IF COALESCE(NEW.raw_user_meta_data ->> 'referral_code', '') <> '' THEN
    INSERT INTO public.user_referrals (referred_user_id, referral_code, referrer_user_id)
    SELECT
      NEW.id,
      UPPER(NEW.raw_user_meta_data ->> 'referral_code'),
      rl.owner_user_id
    FROM public.referral_links rl
    WHERE UPPER(rl.code) = UPPER(NEW.raw_user_meta_data ->> 'referral_code')
      AND rl.is_active = true
      AND rl.is_deleted = false
    ON CONFLICT (referred_user_id) DO NOTHING;

    -- Store even if code unknown (pending validation)
    INSERT INTO public.user_referrals (referred_user_id, referral_code)
    VALUES (NEW.id, UPPER(NEW.raw_user_meta_data ->> 'referral_code'))
    ON CONFLICT (referred_user_id) DO NOTHING;
  END IF;

  INSERT INTO public.registration_events (user_id, event_type, account_type, metadata)
  VALUES (
    NEW.id,
    'succeeded',
    account_type,
    jsonb_build_object('source', 'handle_new_user')
  );

  RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

ALTER TABLE public.legal_acceptances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referral_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.registration_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.security_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS legal_acceptances_own ON public.legal_acceptances;
CREATE POLICY legal_acceptances_own ON public.legal_acceptances
  FOR SELECT USING (user_id = auth.uid() OR public.has_role('admin') OR public.has_role('super_admin'));

DROP POLICY IF EXISTS referral_links_read ON public.referral_links;
CREATE POLICY referral_links_read ON public.referral_links
  FOR SELECT USING (is_active = true OR owner_user_id = auth.uid() OR public.has_role('admin'));

DROP POLICY IF EXISTS user_referrals_own ON public.user_referrals;
CREATE POLICY user_referrals_own ON public.user_referrals
  FOR SELECT USING (
    referred_user_id = auth.uid()
    OR referrer_user_id = auth.uid()
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS registration_events_staff ON public.registration_events;
CREATE POLICY registration_events_staff ON public.registration_events
  FOR SELECT USING (public.has_role('admin') OR public.has_role('super_admin'));

-- Allow anonymous funnel analytics before the user exists / is signed in.
DROP POLICY IF EXISTS registration_events_insert ON public.registration_events;
CREATE POLICY registration_events_insert ON public.registration_events
  FOR INSERT
  WITH CHECK (user_id IS NULL OR user_id = auth.uid());

DROP POLICY IF EXISTS security_settings_own ON public.security_settings;
CREATE POLICY security_settings_own ON public.security_settings
  FOR ALL USING (user_id = auth.uid());

GRANT SELECT ON public.legal_acceptances TO authenticated;
GRANT SELECT ON public.referral_links TO authenticated, anon;
GRANT SELECT ON public.user_referrals TO authenticated;
GRANT SELECT ON public.security_settings TO authenticated;
GRANT INSERT, UPDATE ON public.security_settings TO authenticated;
GRANT INSERT ON public.registration_events TO anon, authenticated;
