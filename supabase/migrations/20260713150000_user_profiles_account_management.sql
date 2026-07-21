-- Volume 3 Part 7 — User Profiles & Account Management
-- Status: APPLIED remotely as user_profiles_account_management (approved 2026-07-13).

-- ---------------------------------------------------------------------------
-- Extend profiles with enterprise identity fields
-- ---------------------------------------------------------------------------
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS middle_name TEXT,
  ADD COLUMN IF NOT EXISTS preferred_name TEXT,
  ADD COLUMN IF NOT EXISTS gender TEXT,
  ADD COLUMN IF NOT EXISTS date_of_birth DATE,
  ADD COLUMN IF NOT EXISTS nationality TEXT,
  ADD COLUMN IF NOT EXISTS occupation TEXT,
  ADD COLUMN IF NOT EXISTS biography TEXT,
  ADD COLUMN IF NOT EXISTS secondary_phone TEXT,
  ADD COLUMN IF NOT EXISTS whatsapp TEXT,
  ADD COLUMN IF NOT EXISTS postal_code TEXT;

-- ---------------------------------------------------------------------------
-- Company profiles (investors, staff, corporate partners)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.company_profiles (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  company_name TEXT,
  business_type TEXT,
  registration_number TEXT,
  tax_id TEXT,
  position TEXT,
  company_address TEXT,
  company_website TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Digital Identity Timeline / profile audit
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profile_activity (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  user_agent TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_profile_activity_user_id
  ON public.profile_activity(user_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- Cached completion snapshot (optional; engine also computes client-side)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profile_completion (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  percent INT NOT NULL DEFAULT 0 CHECK (percent >= 0 AND percent <= 100),
  missing_items JSONB NOT NULL DEFAULT '[]'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.company_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profile_activity ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profile_completion ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS company_profiles_own ON public.company_profiles;
CREATE POLICY company_profiles_own ON public.company_profiles
  FOR ALL USING (
    user_id = auth.uid()
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  )
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS profile_activity_select ON public.profile_activity;
CREATE POLICY profile_activity_select ON public.profile_activity
  FOR SELECT USING (
    user_id = auth.uid()
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS profile_activity_insert ON public.profile_activity;
CREATE POLICY profile_activity_insert ON public.profile_activity
  FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS profile_completion_own ON public.profile_completion;
CREATE POLICY profile_completion_own ON public.profile_completion
  FOR ALL USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

GRANT SELECT, INSERT, UPDATE ON public.company_profiles TO authenticated;
GRANT SELECT, INSERT ON public.profile_activity TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.profile_completion TO authenticated;

-- Staff may update other users' profile fields via admin tools later;
-- profiles RLS already scopes own-row updates for authenticated users.
