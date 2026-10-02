-- Phase 11 — Investor referrals & KYC
-- 1) Owner SELECT on KYC reviews
-- 2) Staff write on referral commissions (rewards)
-- 3) Admin KYC verification RPC
-- 4) Realtime for KYC reviews

-- ---------------------------------------------------------------------------
-- KYC reviews — investor can read own review history
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS investor_kyc_reviews_portal_owner ON public.investor_kyc_reviews;
CREATE POLICY investor_kyc_reviews_portal_owner ON public.investor_kyc_reviews
  FOR SELECT TO authenticated
  USING (
    investor_id = public.investor_id_for_user(auth.uid())
    OR public.is_staff()
  );

-- ---------------------------------------------------------------------------
-- Referral commissions — staff can create/update rewards
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS investor_referral_commissions_staff
  ON public.investor_referral_commissions;
CREATE POLICY investor_referral_commissions_staff
  ON public.investor_referral_commissions
  FOR ALL TO authenticated
  USING (
    public.is_staff()
    OR public.has_permission('investors.write', auth.uid())
    OR public.has_permission('investors.referrals', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.is_staff()
    OR public.has_permission('investors.write', auth.uid())
    OR public.has_permission('investors.referrals', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

-- ---------------------------------------------------------------------------
-- Admin verification — update investors.kyc_status + insert review row
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_verify_investor_kyc(
  p_investor_id uuid,
  p_status text,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_id uuid;
  v_status text := lower(trim(COALESCE(p_status, '')));
BEGIN
  IF NOT (
    public.has_permission('investors.kyc', auth.uid())
    OR public.has_permission('investors.write', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR public.is_staff()
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  IF v_status NOT IN (
    'pending','in_progress','awaiting_documents','under_review','approved',
    'partially_approved','rejected','expired','suspended','needs_resubmission'
  ) THEN
    RAISE EXCEPTION 'invalid_kyc_status';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.investors i
    WHERE i.id = p_investor_id AND COALESCE(i.is_deleted, false) = false
  ) THEN
    RAISE EXCEPTION 'investor_not_found';
  END IF;

  UPDATE public.investors
  SET
    kyc_status = v_status,
    updated_at = now()
  WHERE id = p_investor_id;

  INSERT INTO public.investor_kyc_reviews (
    investor_id, status, reviewer_id, notes, reviewed_at
  ) VALUES (
    p_investor_id,
    v_status,
    auth.uid(),
    NULLIF(trim(COALESCE(p_notes, '')), ''),
    CASE
      WHEN v_status IN ('approved','partially_approved','rejected','suspended','expired')
        THEN now()
      ELSE NULL
    END
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_verify_investor_kyc(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_verify_investor_kyc(uuid, text, text) TO authenticated;

COMMENT ON FUNCTION public.admin_verify_investor_kyc(uuid, text, text) IS
  'Staff KYC verification: syncs investors.kyc_status and appends investor_kyc_reviews (Phase 11).';

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = 'investor_kyc_reviews'
      AND c.relkind IN ('r', 'p')
  ) AND NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'investor_kyc_reviews'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.investor_kyc_reviews;
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = 'investor_kyc_reviews'
  ) THEN
    EXECUTE 'ALTER TABLE public.investor_kyc_reviews REPLICA IDENTITY FULL';
  END IF;
END $$;
