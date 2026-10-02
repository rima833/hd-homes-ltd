-- Investor portal: own capital commitments, and a staff-set referral code.
-- The portal must not invent a shareable code from the investor id.

ALTER TABLE public.investment_commitments REPLICA IDENTITY FULL;

CREATE OR REPLACE FUNCTION public.investor_portal_commitments()
RETURNS TABLE (
  id uuid,
  amount numeric,
  currency text,
  status text,
  committed_at timestamptz,
  funded_at timestamptz,
  notes text,
  opportunity_title text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    c.id,
    c.amount,
    c.currency,
    c.status,
    c.committed_at,
    c.funded_at,
    c.notes,
    COALESCE(NULLIF(trim(o.title), ''), 'Investment') AS opportunity_title
  FROM public.investment_commitments c
  LEFT JOIN public.investment_opportunities o ON o.id = c.opportunity_id
  WHERE c.investor_id = public.investor_id_for_user(auth.uid())
    AND COALESCE(c.metadata->>'demo', '') <> 'true'
  ORDER BY c.committed_at DESC;
$$;

REVOKE ALL ON FUNCTION public.investor_portal_commitments() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.investor_portal_commitments() FROM anon;
GRANT EXECUTE ON FUNCTION public.investor_portal_commitments() TO authenticated;

COMMENT ON FUNCTION public.investor_portal_commitments() IS
  'Commitments recorded by admin for the signed-in investor, with opportunity title.';

CREATE OR REPLACE FUNCTION public.admin_set_investor_referral_code(
  p_investor_id uuid,
  p_code text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_code text := NULLIF(trim(COALESCE(p_code, '')), '');
BEGIN
  IF NOT (
    public.has_permission('investors.referrals', auth.uid())
    OR public.has_permission('investors.write', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.investors
    WHERE id = p_investor_id AND COALESCE(is_deleted, false) = false
  ) THEN
    RAISE EXCEPTION 'investor_not_found';
  END IF;

  UPDATE public.investors
  SET
    metadata = CASE
      WHEN v_code IS NULL THEN COALESCE(metadata, '{}'::jsonb) - 'referral_code'
      ELSE jsonb_set(
        COALESCE(metadata, '{}'::jsonb),
        '{referral_code}',
        to_jsonb(v_code),
        true
      )
    END,
    updated_at = now(),
    updated_by = auth.uid()
  WHERE id = p_investor_id;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_set_investor_referral_code(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_set_investor_referral_code(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.admin_set_investor_referral_code(uuid, text) TO authenticated;

COMMENT ON FUNCTION public.admin_set_investor_referral_code(uuid, text) IS
  'Stores the shareable referral code on the investor. Empty clears it.';
