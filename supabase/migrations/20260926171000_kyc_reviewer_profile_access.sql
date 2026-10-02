-- Compliance officers must read submitter profile fields for the KYC review queue.
-- Without this, profiles!inner joins drop queue rows for admin/finance reviewers.

DROP POLICY IF EXISTS profiles_select_kyc_reviewers ON public.profiles;
CREATE POLICY profiles_select_kyc_reviewers ON public.profiles
  FOR SELECT
  USING (
    public.has_role('admin')
    OR public.has_role('super_admin')
    OR public.has_role('finance')
  );

-- Ensure KYC tables are in the realtime publication for live queue/profile updates.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'kyc_profiles'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.kyc_profiles;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'kyc_documents'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.kyc_documents;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'media'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.media;
  END IF;
END $$;
