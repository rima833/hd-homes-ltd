-- Investor Command Center production management workflows.
-- Removes explicitly tagged demo records, adds audited RPC write paths,
-- and completes Realtime publication for every command-center dependency.

CREATE OR REPLACE FUNCTION public.admin_save_investor(
  p_investor_id uuid DEFAULT NULL,
  p_full_name text DEFAULT NULL,
  p_email text DEFAULT NULL,
  p_phone text DEFAULT NULL,
  p_company text DEFAULT NULL,
  p_investor_type text DEFAULT 'individual',
  p_lifecycle_status text DEFAULT 'prospect',
  p_risk_level text DEFAULT 'moderate',
  p_nationality text DEFAULT NULL,
  p_preferred_currency text DEFAULT 'NGN'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_id uuid := p_investor_id;
  v_name text := NULLIF(trim(COALESCE(p_full_name, '')), '');
  v_email text := NULLIF(lower(trim(COALESCE(p_email, ''))), '');
  v_created boolean := false;
BEGIN
  IF NOT (
    public.has_permission('investors.write', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;
  IF v_name IS NULL THEN RAISE EXCEPTION 'full_name_required'; END IF;
  IF v_email IS NOT NULL AND v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' THEN
    RAISE EXCEPTION 'invalid_email';
  END IF;
  IF p_investor_type NOT IN (
    'individual','hnwi','corporate','institutional','family_office','first_time','fund'
  ) THEN RAISE EXCEPTION 'invalid_investor_type'; END IF;
  IF p_lifecycle_status NOT IN (
    'prospect','onboarding','active','vip','dormant','exited','suspended'
  ) THEN RAISE EXCEPTION 'invalid_lifecycle_status'; END IF;
  IF p_risk_level NOT IN ('conservative','moderate','aggressive','speculative') THEN
    RAISE EXCEPTION 'invalid_risk_level';
  END IF;

  IF v_id IS NULL THEN
    v_created := true;
    INSERT INTO public.investors (
      investor_code, full_name, email, phone, company, investor_type,
      lifecycle_status, kyc_status, risk_level, nationality,
      preferred_currency, aum, total_committed, status, is_deleted,
      metadata, created_by, updated_by
    ) VALUES (
      'INV-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
      v_name, v_email, NULLIF(trim(COALESCE(p_phone, '')), ''),
      NULLIF(trim(COALESCE(p_company, '')), ''), p_investor_type,
      p_lifecycle_status, 'pending', p_risk_level,
      NULLIF(trim(COALESCE(p_nationality, '')), ''),
      upper(COALESCE(NULLIF(trim(p_preferred_currency), ''), 'NGN')),
      0, 0, 'active', false,
      jsonb_build_object('source', 'admin_command_center'),
      auth.uid(), auth.uid()
    )
    RETURNING id INTO v_id;

    INSERT INTO public.investor_portfolios (
      investor_id, name, currency, total_value, total_cost,
      unrealized_gain, realized_gain, metadata
    ) VALUES (
      v_id, 'Primary Portfolio',
      upper(COALESCE(NULLIF(trim(p_preferred_currency), ''), 'NGN')),
      0, 0, 0, 0, jsonb_build_object('source', 'admin_command_center')
    );

    INSERT INTO public.investor_wallets (
      investor_id, currency, available_balance, pending_balance,
      reserved_balance, metadata
    ) VALUES (
      v_id, upper(COALESCE(NULLIF(trim(p_preferred_currency), ''), 'NGN')),
      0, 0, 0, jsonb_build_object('source', 'admin_command_center')
    );
  ELSE
    UPDATE public.investors
    SET full_name = v_name,
        email = v_email,
        phone = NULLIF(trim(COALESCE(p_phone, '')), ''),
        company = NULLIF(trim(COALESCE(p_company, '')), ''),
        investor_type = p_investor_type,
        lifecycle_status = p_lifecycle_status,
        risk_level = p_risk_level,
        nationality = NULLIF(trim(COALESCE(p_nationality, '')), ''),
        preferred_currency = upper(COALESCE(NULLIF(trim(p_preferred_currency), ''), 'NGN')),
        metadata = COALESCE(metadata, '{}'::jsonb) - 'demo',
        updated_by = auth.uid(),
        updated_at = now()
    WHERE id = v_id AND COALESCE(is_deleted, false) = false;
    IF NOT FOUND THEN RAISE EXCEPTION 'investor_not_found'; END IF;
  END IF;

  INSERT INTO public.investor_activity_logs (
    investor_id, event_type, title, description, payload, actor_id, occurred_at
  ) VALUES (
    v_id,
    CASE WHEN v_created THEN 'investor_created' ELSE 'investor_updated' END,
    CASE WHEN v_created THEN 'Investor created' ELSE 'Investor profile updated' END,
    v_name,
    jsonb_build_object('source', 'admin_command_center'),
    auth.uid(), now()
  );
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_archive_investor(p_investor_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF NOT (
    public.has_permission('investors.write', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN RAISE EXCEPTION 'not authorized'; END IF;

  INSERT INTO public.investor_activity_logs (
    investor_id, event_type, title, payload, actor_id, occurred_at
  )
  SELECT id, 'investor_archived', 'Investor archived',
         jsonb_build_object('source', 'admin_command_center'), auth.uid(), now()
  FROM public.investors
  WHERE id = p_investor_id AND COALESCE(is_deleted, false) = false;

  UPDATE public.investors
  SET is_deleted = true, lifecycle_status = 'suspended',
      updated_by = auth.uid(), updated_at = now()
  WHERE id = p_investor_id AND COALESCE(is_deleted, false) = false;
  IF NOT FOUND THEN RAISE EXCEPTION 'investor_not_found'; END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_save_investment_opportunity(
  p_opportunity_id uuid DEFAULT NULL,
  p_title text DEFAULT NULL,
  p_description text DEFAULT NULL,
  p_status text DEFAULT 'open',
  p_target_raise numeric DEFAULT 0,
  p_amount_raised numeric DEFAULT 0,
  p_min_ticket numeric DEFAULT NULL,
  p_max_ticket numeric DEFAULT NULL,
  p_currency text DEFAULT 'NGN',
  p_projected_return_pct numeric DEFAULT NULL,
  p_risk_level text DEFAULT 'moderate'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_id uuid := p_opportunity_id;
  v_title text := NULLIF(trim(COALESCE(p_title, '')), '');
BEGIN
  IF NOT (
    public.has_permission('investors.opportunities', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN RAISE EXCEPTION 'not authorized'; END IF;
  IF v_title IS NULL THEN RAISE EXCEPTION 'title_required'; END IF;
  IF p_status NOT IN ('open','closed','fully_funded','suspended','completed') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;
  IF p_risk_level NOT IN ('conservative','moderate','aggressive','speculative') THEN
    RAISE EXCEPTION 'invalid_risk_level';
  END IF;
  IF COALESCE(p_target_raise, 0) < 0 OR COALESCE(p_amount_raised, 0) < 0
     OR COALESCE(p_min_ticket, 0) < 0 OR COALESCE(p_max_ticket, 0) < 0 THEN
    RAISE EXCEPTION 'invalid_amount';
  END IF;
  IF p_min_ticket IS NOT NULL AND p_max_ticket IS NOT NULL
     AND p_min_ticket > p_max_ticket THEN
    RAISE EXCEPTION 'invalid_ticket_range';
  END IF;

  IF v_id IS NULL THEN
    INSERT INTO public.investment_opportunities (
      code, title, description, status, target_raise, amount_raised,
      min_ticket, max_ticket, currency, projected_return_pct,
      return_disclaimer, risk_level, open_at, metadata
    ) VALUES (
      'OPP-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
      v_title, NULLIF(trim(COALESCE(p_description, '')), ''), p_status,
      COALESCE(p_target_raise, 0), COALESCE(p_amount_raised, 0),
      p_min_ticket, p_max_ticket,
      upper(COALESCE(NULLIF(trim(p_currency), ''), 'NGN')),
      p_projected_return_pct,
      'Projected returns are estimates only and are not guaranteed. Past performance does not predict future results.',
      p_risk_level, CASE WHEN p_status = 'open' THEN now() ELSE NULL END,
      jsonb_build_object('source', 'admin_command_center')
    )
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.investment_opportunities
    SET title = v_title,
        description = NULLIF(trim(COALESCE(p_description, '')), ''),
        status = p_status,
        target_raise = COALESCE(p_target_raise, 0),
        amount_raised = COALESCE(p_amount_raised, 0),
        min_ticket = p_min_ticket,
        max_ticket = p_max_ticket,
        currency = upper(COALESCE(NULLIF(trim(p_currency), ''), 'NGN')),
        projected_return_pct = p_projected_return_pct,
        risk_level = p_risk_level,
        metadata = COALESCE(metadata, '{}'::jsonb) - 'demo',
        updated_at = now()
    WHERE id = v_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'opportunity_not_found'; END IF;
  END IF;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_investment_commitment_status(
  p_commitment_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_investor_id uuid;
  v_opportunity_id uuid;
BEGIN
  IF NOT (
    public.has_permission('investors.portfolio', auth.uid())
    OR public.has_permission('investors.write', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN RAISE EXCEPTION 'not authorized'; END IF;
  IF p_status NOT IN ('pending','reserved','confirmed','funded','cancelled','refunded') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;

  UPDATE public.investment_commitments
  SET status = p_status,
      funded_at = CASE WHEN p_status = 'funded' THEN COALESCE(funded_at, now()) ELSE funded_at END,
      updated_at = now()
  WHERE id = p_commitment_id
  RETURNING investor_id, opportunity_id INTO v_investor_id, v_opportunity_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'commitment_not_found'; END IF;

  UPDATE public.investment_opportunities o
  SET amount_raised = COALESCE((
        SELECT sum(c.amount) FROM public.investment_commitments c
        WHERE c.opportunity_id = v_opportunity_id AND c.status = 'funded'
      ), 0),
      updated_at = now()
  WHERE o.id = v_opportunity_id;

  UPDATE public.investors i
  SET total_committed = COALESCE((
        SELECT sum(c.amount) FROM public.investment_commitments c
        WHERE c.investor_id = v_investor_id
          AND c.status NOT IN ('cancelled','refunded')
      ), 0),
      updated_at = now()
  WHERE i.id = v_investor_id;

  INSERT INTO public.investor_activity_logs (
    investor_id, event_type, title, description, payload, actor_id, occurred_at
  ) VALUES (
    v_investor_id, 'commitment_status_changed', 'Commitment status changed',
    p_status, jsonb_build_object('commitment_id', p_commitment_id, 'status', p_status),
    auth.uid(), now()
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_save_investment_distribution(
  p_distribution_id uuid DEFAULT NULL,
  p_investor_id uuid DEFAULT NULL,
  p_opportunity_id uuid DEFAULT NULL,
  p_amount numeric DEFAULT 0,
  p_status text DEFAULT 'scheduled',
  p_distribution_type text DEFAULT 'dividend',
  p_currency text DEFAULT 'NGN',
  p_scheduled_at timestamptz DEFAULT NULL,
  p_reference text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_id uuid := p_distribution_id;
BEGIN
  IF NOT (
    public.has_permission('investors.distributions', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN RAISE EXCEPTION 'not authorized'; END IF;
  IF p_investor_id IS NULL THEN RAISE EXCEPTION 'investor_required'; END IF;
  IF COALESCE(p_amount, 0) <= 0 THEN RAISE EXCEPTION 'invalid_amount'; END IF;
  IF p_status NOT IN ('scheduled','processing','paid','failed','cancelled') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;
  IF p_distribution_type NOT IN ('dividend','interest','capital_return','bonus','other') THEN
    RAISE EXCEPTION 'invalid_distribution_type';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.investors
    WHERE id = p_investor_id AND COALESCE(is_deleted, false) = false
  ) THEN RAISE EXCEPTION 'investor_not_found'; END IF;

  IF v_id IS NULL THEN
    INSERT INTO public.investment_distributions (
      investor_id, opportunity_id, amount, currency, status,
      distribution_type, scheduled_at, paid_at, reference, metadata
    ) VALUES (
      p_investor_id, p_opportunity_id, p_amount,
      upper(COALESCE(NULLIF(trim(p_currency), ''), 'NGN')), p_status,
      p_distribution_type, p_scheduled_at,
      CASE WHEN p_status = 'paid' THEN now() ELSE NULL END,
      NULLIF(trim(COALESCE(p_reference, '')), ''),
      jsonb_build_object('source', 'admin_command_center')
    )
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.investment_distributions
    SET investor_id = p_investor_id,
        opportunity_id = p_opportunity_id,
        amount = p_amount,
        currency = upper(COALESCE(NULLIF(trim(p_currency), ''), 'NGN')),
        status = p_status,
        distribution_type = p_distribution_type,
        scheduled_at = p_scheduled_at,
        paid_at = CASE
          WHEN p_status = 'paid' THEN COALESCE(paid_at, now())
          WHEN p_status IN ('scheduled','processing') THEN NULL
          ELSE paid_at
        END,
        reference = NULLIF(trim(COALESCE(p_reference, '')), ''),
        metadata = COALESCE(metadata, '{}'::jsonb) - 'demo',
        updated_at = now()
    WHERE id = v_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'distribution_not_found'; END IF;
  END IF;

  INSERT INTO public.investor_activity_logs (
    investor_id, event_type, title, description, payload, actor_id, occurred_at
  ) VALUES (
    p_investor_id, 'distribution_saved', 'Distribution updated',
    p_status, jsonb_build_object('distribution_id', v_id, 'amount', p_amount),
    auth.uid(), now()
  );
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_investment_distribution_status(
  p_distribution_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_investor_id uuid;
  v_amount numeric;
BEGIN
  IF NOT (
    public.has_permission('investors.distributions', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN RAISE EXCEPTION 'not authorized'; END IF;
  IF p_status NOT IN ('scheduled','processing','paid','failed','cancelled') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;
  UPDATE public.investment_distributions
  SET status = p_status,
      paid_at = CASE
        WHEN p_status = 'paid' THEN COALESCE(paid_at, now())
        WHEN p_status IN ('scheduled','processing') THEN NULL
        ELSE paid_at
      END,
      updated_at = now()
  WHERE id = p_distribution_id
  RETURNING investor_id, amount INTO v_investor_id, v_amount;
  IF NOT FOUND THEN RAISE EXCEPTION 'distribution_not_found'; END IF;

  INSERT INTO public.investor_activity_logs (
    investor_id, event_type, title, description, payload, actor_id, occurred_at
  ) VALUES (
    v_investor_id, 'distribution_status_changed', 'Distribution status changed',
    p_status,
    jsonb_build_object('distribution_id', p_distribution_id, 'amount', v_amount),
    auth.uid(), now()
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_investor_alert_status(
  p_alert_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF NOT (
    public.has_permission('investors.write', auth.uid())
    OR public.has_permission('investors.analytics', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN RAISE EXCEPTION 'not authorized'; END IF;
  IF p_status NOT IN ('open','acknowledged','resolved','dismissed') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;
  UPDATE public.investor_alerts
  SET status = p_status,
      metadata = COALESCE(metadata, '{}'::jsonb) ||
        jsonb_build_object('handled_by', auth.uid(), 'handled_at', now()),
      updated_at = now()
  WHERE id = p_alert_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'alert_not_found'; END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_adjust_investor_holding_value(
  p_holding_id uuid,
  p_current_value numeric
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_portfolio_id uuid;
  v_investor_id uuid;
BEGIN
  IF NOT (
    public.has_permission('investors.portfolio', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN RAISE EXCEPTION 'not authorized'; END IF;
  IF COALESCE(p_current_value, -1) < 0 THEN RAISE EXCEPTION 'invalid_amount'; END IF;

  UPDATE public.portfolio_holdings
  SET current_value = p_current_value, updated_at = now()
  WHERE id = p_holding_id
  RETURNING portfolio_id INTO v_portfolio_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'holding_not_found'; END IF;

  UPDATE public.investor_portfolios p
  SET total_cost = COALESCE((
        SELECT sum(h.cost_basis) FROM public.portfolio_holdings h
        WHERE h.portfolio_id = v_portfolio_id
      ), 0),
      total_value = COALESCE((
        SELECT sum(h.current_value) FROM public.portfolio_holdings h
        WHERE h.portfolio_id = v_portfolio_id
      ), 0),
      unrealized_gain = COALESCE((
        SELECT sum(h.current_value - h.cost_basis) FROM public.portfolio_holdings h
        WHERE h.portfolio_id = v_portfolio_id
      ), 0),
      updated_at = now()
  WHERE p.id = v_portfolio_id
  RETURNING investor_id INTO v_investor_id;

  UPDATE public.investors i
  SET aum = COALESCE((
        SELECT sum(p.total_value) FROM public.investor_portfolios p
        WHERE p.investor_id = v_investor_id
      ), 0),
      updated_at = now()
  WHERE i.id = v_investor_id;

  INSERT INTO public.investor_activity_logs (
    investor_id, event_type, title, description, payload, actor_id, occurred_at
  ) VALUES (
    v_investor_id, 'holding_value_adjusted', 'Holding valuation updated',
    p_current_value::text,
    jsonb_build_object('holding_id', p_holding_id, 'current_value', p_current_value),
    auth.uid(), now()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_save_investor(
  uuid,text,text,text,text,text,text,text,text,text
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_save_investor(
  uuid,text,text,text,text,text,text,text,text,text
) TO authenticated;
REVOKE ALL ON FUNCTION public.admin_archive_investor(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_archive_investor(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.admin_save_investment_opportunity(
  uuid,text,text,text,numeric,numeric,numeric,numeric,text,numeric,text
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_save_investment_opportunity(
  uuid,text,text,text,numeric,numeric,numeric,numeric,text,numeric,text
) TO authenticated;
REVOKE ALL ON FUNCTION public.admin_set_investment_commitment_status(uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_set_investment_commitment_status(uuid,text) TO authenticated;
REVOKE ALL ON FUNCTION public.admin_save_investment_distribution(
  uuid,uuid,uuid,numeric,text,text,text,timestamptz,text
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_save_investment_distribution(
  uuid,uuid,uuid,numeric,text,text,text,timestamptz,text
) TO authenticated;
REVOKE ALL ON FUNCTION public.admin_set_investment_distribution_status(uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_set_investment_distribution_status(uuid,text) TO authenticated;
REVOKE ALL ON FUNCTION public.admin_set_investor_alert_status(uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_set_investor_alert_status(uuid,text) TO authenticated;
REVOKE ALL ON FUNCTION public.admin_adjust_investor_holding_value(uuid,numeric) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_adjust_investor_holding_value(uuid,numeric) TO authenticated;

-- Explicitly tagged sample records must never exist in production. Cascading
-- constraints remove only their dependent sample graph.
DELETE FROM public.investors
WHERE COALESCE(metadata->>'demo', 'false') = 'true';
DELETE FROM public.investment_opportunities
WHERE COALESCE(metadata->>'demo', 'false') = 'true';

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'investors',
    'investor_preferences',
    'investor_tags',
    'investor_tag_assignments',
    'investment_opportunities',
    'investment_commitments',
    'investor_portfolios',
    'portfolio_holdings',
    'investment_distributions',
    'investor_wallets',
    'investor_activity_logs',
    'investor_alerts'
  ]
  LOOP
    IF to_regclass('public.' || t) IS NOT NULL
       AND NOT EXISTS (
         SELECT 1
         FROM pg_publication_tables
         WHERE pubname = 'supabase_realtime'
           AND schemaname = 'public'
           AND tablename = t
       ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    END IF;
  END LOOP;
END $$;
