-- Staff publish / status controls for public website investment cards (IMP Capital Raise).
CREATE OR REPLACE FUNCTION public.admin_set_website_investment_opportunity_status(
  p_website_opportunity_id uuid,
  p_status text DEFAULT NULL,
  p_opportunity_status text DEFAULT NULL,
  p_is_featured boolean DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_can boolean;
BEGIN
  IF p_website_opportunity_id IS NULL THEN
    RAISE EXCEPTION 'website opportunity id required';
  END IF;

  v_can := public.has_permission('investors.opportunities', auth.uid())
    OR public.has_permission('investors.write', auth.uid())
    OR public.has_permission('manage_marketing', auth.uid())
    OR public.has_role('super_admin', auth.uid());
  IF NOT v_can THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  IF p_status IS NOT NULL AND p_status NOT IN ('active', 'draft', 'archived') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;

  IF p_opportunity_status IS NOT NULL AND p_opportunity_status NOT IN (
    'open', 'limited', 'closing_soon', 'coming_soon', 'closed', 'sold_out'
  ) THEN
    RAISE EXCEPTION 'invalid opportunity status';
  END IF;

  UPDATE public.website_investment_opportunities
  SET
    status = coalesce(p_status, status),
    opportunity_status = coalesce(p_opportunity_status, opportunity_status),
    is_featured = coalesce(p_is_featured, is_featured),
    updated_at = now()
  WHERE id = p_website_opportunity_id
    AND coalesce(is_deleted, false) = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'website opportunity not found';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_set_website_investment_opportunity_status(
  uuid, text, text, boolean
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_set_website_investment_opportunity_status(
  uuid, text, text, boolean
) FROM anon;
GRANT EXECUTE ON FUNCTION public.admin_set_website_investment_opportunity_status(
  uuid, text, text, boolean
) TO authenticated;
