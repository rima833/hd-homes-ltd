-- Volume 3 Part 8 — KYC & Identity Verification
-- Status: APPLIED remotely as kyc_identity_verification (approved 2026-07-13).

-- ---------------------------------------------------------------------------
-- KYC profile (per user)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.kyc_profiles (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending',
  current_level INT NOT NULL DEFAULT 0 CHECK (current_level BETWEEN 0 AND 4),
  target_level INT NOT NULL DEFAULT 1 CHECK (target_level BETWEEN 0 AND 4),
  priority INT NOT NULL DEFAULT 0,
  reviewer_notes TEXT,
  reviewed_by UUID REFERENCES auth.users(id),
  reviewed_at TIMESTAMPTZ,
  submitted_at TIMESTAMPTZ,
  verified_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  trust_score INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Documents (storage path in private bucket; no public URLs)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.kyc_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  document_type TEXT NOT NULL,
  storage_path TEXT NOT NULL,
  file_name TEXT,
  mime_type TEXT,
  file_size_bytes INT,
  status TEXT NOT NULL DEFAULT 'uploaded',
  expires_at TIMESTAMPTZ,
  review_notes TEXT,
  reviewed_by UUID REFERENCES auth.users(id),
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_kyc_documents_user_id
  ON public.kyc_documents(user_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- Review decisions & verification requests
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.document_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  document_id UUID REFERENCES public.kyc_documents(id) ON DELETE SET NULL,
  reviewer_id UUID REFERENCES auth.users(id),
  decision TEXT NOT NULL,
  notes TEXT,
  approved_level INT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.verification_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  target_level INT NOT NULL DEFAULT 2,
  status TEXT NOT NULL DEFAULT 'under_review',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  closed_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.investor_compliance (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  investment_source TEXT,
  source_of_funds TEXT,
  investment_objectives TEXT,
  estimated_amount TEXT,
  risk_profile TEXT,
  declarations_accepted BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.kyc_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  actor_id UUID REFERENCES auth.users(id),
  event_type TEXT NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  user_agent TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_kyc_events_user_id
  ON public.kyc_events(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.fraud_flags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  flag_type TEXT NOT NULL,
  severity TEXT NOT NULL DEFAULT 'medium',
  notes TEXT,
  resolved BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Optional catalog (seed common types for Admin Panel)
CREATE TABLE IF NOT EXISTS public.kyc_document_types (
  slug TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'identity',
  is_active BOOLEAN NOT NULL DEFAULT true,
  max_file_mb INT NOT NULL DEFAULT 10
);

INSERT INTO public.kyc_document_types (slug, label, category) VALUES
  ('national_id', 'National ID', 'identity'),
  ('passport', 'International Passport', 'identity'),
  ('drivers_license', 'Driver''s License', 'identity'),
  ('voter_card', 'Voter Card', 'identity'),
  ('proof_of_address', 'Proof of Address', 'address'),
  ('utility_bill', 'Utility Bill', 'address'),
  ('bank_statement', 'Bank Statement', 'address'),
  ('selfie', 'Selfie / Liveness', 'biometric'),
  ('business_registration', 'Business Registration', 'corporate'),
  ('certificate_of_incorporation', 'Certificate of Incorporation', 'corporate')
ON CONFLICT (slug) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Private KYC storage bucket
-- ---------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'kyc-documents',
  'kyc-documents',
  false,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS storage_kyc_own ON storage.objects;
CREATE POLICY storage_kyc_own ON storage.objects
  FOR ALL TO authenticated
  USING (
    bucket_id = 'kyc-documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'kyc-documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS storage_kyc_staff_read ON storage.objects;
CREATE POLICY storage_kyc_staff_read ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'kyc-documents'
    AND (
      public.has_role('admin')
      OR public.has_role('super_admin')
      OR public.has_role('finance')
    )
  );

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.kyc_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kyc_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.verification_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_compliance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kyc_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fraud_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kyc_document_types ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS kyc_profiles_own ON public.kyc_profiles;
CREATE POLICY kyc_profiles_own ON public.kyc_profiles
  FOR SELECT USING (
    user_id = auth.uid()
    OR public.has_role('admin')
    OR public.has_role('super_admin')
    OR public.has_role('finance')
  );

DROP POLICY IF EXISTS kyc_profiles_upsert ON public.kyc_profiles;
CREATE POLICY kyc_profiles_upsert ON public.kyc_profiles
  FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS kyc_profiles_update_own ON public.kyc_profiles;
CREATE POLICY kyc_profiles_update_own ON public.kyc_profiles
  FOR UPDATE USING (
    user_id = auth.uid()
    OR public.has_role('admin')
    OR public.has_role('super_admin')
    OR public.has_role('finance')
  );

DROP POLICY IF EXISTS kyc_documents_own ON public.kyc_documents;
CREATE POLICY kyc_documents_own ON public.kyc_documents
  FOR ALL USING (
    user_id = auth.uid()
    OR public.has_role('admin')
    OR public.has_role('super_admin')
    OR public.has_role('finance')
  )
  WITH CHECK (user_id = auth.uid() OR public.has_role('admin') OR public.has_role('super_admin') OR public.has_role('finance'));

DROP POLICY IF EXISTS document_reviews_staff ON public.document_reviews;
CREATE POLICY document_reviews_staff ON public.document_reviews
  FOR ALL USING (
    public.has_role('admin')
    OR public.has_role('super_admin')
    OR public.has_role('finance')
    OR user_id = auth.uid()
  )
  WITH CHECK (
    public.has_role('admin')
    OR public.has_role('super_admin')
    OR public.has_role('finance')
  );

DROP POLICY IF EXISTS verification_requests_own ON public.verification_requests;
CREATE POLICY verification_requests_own ON public.verification_requests
  FOR ALL USING (
    user_id = auth.uid()
    OR public.has_role('admin')
    OR public.has_role('super_admin')
    OR public.has_role('finance')
  )
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS investor_compliance_own ON public.investor_compliance;
CREATE POLICY investor_compliance_own ON public.investor_compliance
  FOR ALL USING (
    user_id = auth.uid()
    OR public.has_role('admin')
    OR public.has_role('super_admin')
    OR public.has_role('finance')
  )
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS kyc_events_access ON public.kyc_events;
CREATE POLICY kyc_events_access ON public.kyc_events
  FOR SELECT USING (
    user_id = auth.uid()
    OR public.has_role('admin')
    OR public.has_role('super_admin')
    OR public.has_role('finance')
  );

DROP POLICY IF EXISTS kyc_events_insert ON public.kyc_events;
CREATE POLICY kyc_events_insert ON public.kyc_events
  FOR INSERT WITH CHECK (user_id = auth.uid() OR actor_id = auth.uid());

DROP POLICY IF EXISTS fraud_flags_staff ON public.fraud_flags;
CREATE POLICY fraud_flags_staff ON public.fraud_flags
  FOR ALL USING (
    public.has_role('admin') OR public.has_role('super_admin') OR public.has_role('finance')
  );

DROP POLICY IF EXISTS kyc_document_types_read ON public.kyc_document_types;
CREATE POLICY kyc_document_types_read ON public.kyc_document_types
  FOR SELECT USING (true);

GRANT SELECT, INSERT, UPDATE ON public.kyc_profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.kyc_documents TO authenticated;
GRANT SELECT, INSERT ON public.document_reviews TO authenticated;
GRANT SELECT, INSERT ON public.verification_requests TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.investor_compliance TO authenticated;
GRANT SELECT, INSERT ON public.kyc_events TO authenticated;
GRANT SELECT ON public.kyc_document_types TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.fraud_flags TO authenticated;
