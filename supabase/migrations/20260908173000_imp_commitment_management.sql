-- Create and edit capital-raise commitments with aggregate synchronization.

CREATE OR REPLACE FUNCTION public.admin_save_investment_commitment(
  p_commitment_id uuid DEFAULT NULL,
  p_investor_id uuid DEFAULT NULL,
  p_opportunity_id uuid DEFAULT NULL,
  p_amount numeric DEFAULT 0,
  p_currency text DEFAULT 'NGN',
  p_status text DEFAULT 'pending',
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_id uuid := p_commitment_id;
  v_previous_investor_id uuid;
  v_previous_opportunity_id uuid;
BEGIN
  IF NOT (
    public.has_permission('investors.portfolio', auth.uid())
    OR public.has_permission('investors.write', auth.uid())
    OR public.has_permission('investors.opportunities', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;
  IF p_investor_id IS NULL THEN RAISE EXCEPTION 'investor_required'; END IF;
  IF p_opportunity_id IS NULL THEN RAISE EXCEPTION 'opportunity_required'; END IF;
  IF COALESCE(p_amount, 0) <= 0 THEN RAISE EXCEPTION 'invalid_amount'; END IF;
  IF p_status NOT IN (
    'pending','reserved','confirmed','funded','cancelled','refunded'
  ) THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.investors
    WHERE id = p_investor_id AND COALESCE(is_deleted, false) = false
  ) THEN
    RAISE EXCEPTION 'investor_not_found';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.investment_opportunities
    WHERE id = p_opportunity_id
  ) THEN
    RAISE EXCEPTION 'opportunity_not_found';
  END IF;

  IF v_id IS NULL THEN
    INSERT INTO public.investment_commitments (
      investor_id, opportunity_id, amount, currency, status,
      committed_at, funded_at, notes, metadata
    ) VALUES (
      p_investor_id, p_opportunity_id, p_amount,
      upper(COALESCE(NULLIF(trim(p_currency), ''), 'NGN')), p_status,
      now(), CASE WHEN p_status = 'funded' THEN now() ELSE NULL END,
      NULLIF(trim(COALESCE(p_notes, '')), ''),
      jsonb_build_object('source', 'admin_command_center')
    )
    RETURNING id INTO v_id;
  ELSE
    SELECT investor_id, opportunity_id
      INTO v_previous_investor_id, v_previous_opportunity_id
    FROM public.investment_commitments
    WHERE id = v_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'commitment_not_found'; END IF;

    UPDATE public.investment_commitments
    SET investor_id = p_investor_id,
        opportunity_id = p_opportunity_id,
        amount = p_amount,
        currency = upper(COALESCE(NULLIF(trim(p_currency), ''), 'NGN')),
        status = p_status,
        funded_at = CASE
          WHEN p_status = 'funded' THEN COALESCE(funded_at, now())
          WHEN p_status IN ('pending','reserved','confirmed') THEN NULL
          ELSE funded_at
        END,
        notes = NULLIF(trim(COALESCE(p_notes, '')), ''),
        metadata = COALESCE(metadata, '{}'::jsonb) - 'demo',
        updated_at = now()
    WHERE id = v_id;
  END IF;

  UPDATE public.investment_opportunities o
  SET amount_raised = COALESCE((
        SELECT sum(c.amount)
        FROM public.investment_commitments c
        WHERE c.opportunity_id = o.id AND c.status = 'funded'
      ), 0),
      updated_at = now()
  WHERE o.id IN (p_opportunity_id, v_previous_opportunity_id);

  UPDATE public.investors i
  SET total_committed = COALESCE((
        SELECT sum(c.amount)
        FROM public.investment_commitments c
        WHERE c.investor_id = i.id
          AND c.status NOT IN ('cancelled','refunded')
      ), 0),
      updated_at = now()
  WHERE i.id IN (p_investor_id, v_previous_investor_id);

  INSERT INTO public.investor_activity_logs (
    investor_id, event_type, title, description, payload, actor_id, occurred_at
  ) VALUES (
    p_investor_id, 'commitment_saved', 'Investment commitment updated',
    p_status,
    jsonb_build_object(
      'commitment_id', v_id,
      'opportunity_id', p_opportunity_id,
      'amount', p_amount,
      'status', p_status
    ),
    auth.uid(), now()
  );
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_save_investment_commitment(
  uuid, uuid, uuid, numeric, text, text, text
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_save_investment_commitment(
  uuid, uuid, uuid, numeric, text, text, text
) TO authenticated;
