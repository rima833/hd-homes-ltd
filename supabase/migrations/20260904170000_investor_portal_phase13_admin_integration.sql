-- Phase 13 — IMP admin integration write paths
-- 1) Assign holding (+ optional commitment) to investor portfolio
-- 2) Staff message investor conversation
-- 3) Staff-friendly write policies on portfolio tables
-- 4) Document publish already exists — notify is handled in app after RPC

-- ---------------------------------------------------------------------------
-- Portfolio write policies — include is_staff()
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS investor_portfolios_write ON public.investor_portfolios;
CREATE POLICY investor_portfolios_write ON public.investor_portfolios
  FOR ALL TO authenticated
  USING (
    public.is_staff()
    OR public.has_permission('investors.portfolio', auth.uid())
    OR public.has_permission('investors.write', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.is_staff()
    OR public.has_permission('investors.portfolio', auth.uid())
    OR public.has_permission('investors.write', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

DROP POLICY IF EXISTS portfolio_holdings_write ON public.portfolio_holdings;
CREATE POLICY portfolio_holdings_write ON public.portfolio_holdings
  FOR ALL TO authenticated
  USING (
    public.is_staff()
    OR public.has_permission('investors.portfolio', auth.uid())
    OR public.has_permission('investors.write', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.is_staff()
    OR public.has_permission('investors.portfolio', auth.uid())
    OR public.has_permission('investors.write', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

DROP POLICY IF EXISTS investment_commitments_write ON public.investment_commitments;
CREATE POLICY investment_commitments_write ON public.investment_commitments
  FOR ALL TO authenticated
  USING (
    public.is_staff()
    OR public.has_permission('investors.write', auth.uid())
    OR public.has_permission('investors.portfolio', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.is_staff()
    OR public.has_permission('investors.write', auth.uid())
    OR public.has_permission('investors.portfolio', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

-- ---------------------------------------------------------------------------
-- Assign investment holding
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_assign_investor_holding(
  p_investor_id uuid,
  p_label text,
  p_cost_basis numeric,
  p_current_value numeric DEFAULT NULL,
  p_units numeric DEFAULT 1,
  p_currency text DEFAULT 'NGN',
  p_opportunity_id uuid DEFAULT NULL,
  p_property_id uuid DEFAULT NULL,
  p_create_commitment boolean DEFAULT true,
  p_notify boolean DEFAULT true
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_holding_id uuid;
  v_portfolio_id uuid;
  v_label text := NULLIF(trim(COALESCE(p_label, '')), '');
  v_cost numeric := COALESCE(p_cost_basis, 0);
  v_value numeric := COALESCE(p_current_value, p_cost_basis, 0);
  v_units numeric := COALESCE(NULLIF(p_units, 0), 1);
  v_currency text := COALESCE(NULLIF(trim(p_currency), ''), 'NGN');
  v_property_id uuid := p_property_id;
  v_opp_title text;
BEGIN
  IF NOT (
    public.is_staff()
    OR public.has_permission('investors.portfolio', auth.uid())
    OR public.has_permission('investors.write', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  IF v_label IS NULL THEN
    RAISE EXCEPTION 'label_required';
  END IF;

  IF v_cost < 0 OR v_value < 0 THEN
    RAISE EXCEPTION 'invalid_amount';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.investors i
    WHERE i.id = p_investor_id AND COALESCE(i.is_deleted, false) = false
  ) THEN
    RAISE EXCEPTION 'investor_not_found';
  END IF;

  IF p_opportunity_id IS NOT NULL THEN
    SELECT o.title, COALESCE(v_property_id, o.property_id)
      INTO v_opp_title, v_property_id
    FROM public.investment_opportunities o
    WHERE o.id = p_opportunity_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'opportunity_not_found';
    END IF;
  END IF;

  SELECT ip.id INTO v_portfolio_id
  FROM public.investor_portfolios ip
  WHERE ip.investor_id = p_investor_id
  ORDER BY ip.created_at
  LIMIT 1;

  IF v_portfolio_id IS NULL THEN
    INSERT INTO public.investor_portfolios (
      investor_id, name, currency, total_value, total_cost
    ) VALUES (
      p_investor_id, 'Primary Portfolio', v_currency, 0, 0
    )
    RETURNING id INTO v_portfolio_id;
  END IF;

  INSERT INTO public.portfolio_holdings (
    portfolio_id, opportunity_id, property_id, label, units,
    cost_basis, current_value, currency, acquired_at, metadata
  ) VALUES (
    v_portfolio_id,
    p_opportunity_id,
    v_property_id,
    v_label,
    v_units,
    v_cost,
    v_value,
    v_currency,
    now(),
    jsonb_build_object(
      'assigned_by', auth.uid(),
      'assigned_at', now(),
      'source', 'imp_phase13'
    )
  )
  RETURNING id INTO v_holding_id;

  UPDATE public.investor_portfolios ip
  SET
    total_cost = COALESCE((
      SELECT SUM(h.cost_basis) FROM public.portfolio_holdings h
      WHERE h.portfolio_id = v_portfolio_id
    ), 0),
    total_value = COALESCE((
      SELECT SUM(h.current_value) FROM public.portfolio_holdings h
      WHERE h.portfolio_id = v_portfolio_id
    ), 0),
    unrealized_gain = COALESCE((
      SELECT SUM(h.current_value - h.cost_basis) FROM public.portfolio_holdings h
      WHERE h.portfolio_id = v_portfolio_id
    ), 0),
    updated_at = now()
  WHERE ip.id = v_portfolio_id;

  UPDATE public.investors i
  SET
    aum = COALESCE((
      SELECT SUM(ip.total_value) FROM public.investor_portfolios ip
      WHERE ip.investor_id = p_investor_id
    ), 0),
    total_committed = COALESCE(i.total_committed, 0) +
      CASE WHEN COALESCE(p_create_commitment, true) THEN v_cost ELSE 0 END,
    lifecycle_status = CASE
      WHEN i.lifecycle_status IN ('prospect', 'onboarding') THEN 'active'
      ELSE i.lifecycle_status
    END,
    updated_at = now()
  WHERE i.id = p_investor_id;

  IF COALESCE(p_create_commitment, true) AND p_opportunity_id IS NOT NULL THEN
    INSERT INTO public.investment_commitments (
      investor_id, opportunity_id, amount, currency, status,
      committed_at, funded_at, notes, metadata
    ) VALUES (
      p_investor_id,
      p_opportunity_id,
      v_cost,
      v_currency,
      'funded',
      now(),
      now(),
      'Assigned via IMP',
      jsonb_build_object(
        'holding_id', v_holding_id,
        'assigned_by', auth.uid(),
        'source', 'imp_phase13'
      )
    );
  END IF;

  BEGIN
    INSERT INTO public.investor_activity_logs (
      investor_id, event_type, title, description, payload, actor_id, occurred_at
    ) VALUES (
      p_investor_id,
      'holding_assigned',
      'Investment assigned',
      COALESCE(v_opp_title, v_label),
      jsonb_build_object(
        'holding_id', v_holding_id,
        'opportunity_id', p_opportunity_id,
        'cost_basis', v_cost,
        'current_value', v_value
      ),
      auth.uid(),
      now()
    );
  EXCEPTION WHEN others THEN NULL;
  END;

  IF COALESCE(p_notify, true) THEN
    INSERT INTO public.investor_notifications (
      investor_id, channel, title, body, is_read, sent_at, metadata
    ) VALUES (
      p_investor_id,
      'in_app',
      'New investment assigned',
      'A new holding was added to your portfolio: ' || v_label,
      false,
      now(),
      jsonb_build_object(
        'category', 'portfolio',
        'route', '/investor/portfolio/' || v_holding_id::text,
        'holding_id', v_holding_id
      )
    );
  END IF;

  RETURN v_holding_id;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_assign_investor_holding(
  uuid, text, numeric, numeric, numeric, text, uuid, uuid, boolean, boolean
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_assign_investor_holding(
  uuid, text, numeric, numeric, numeric, text, uuid, uuid, boolean, boolean
) TO authenticated;

COMMENT ON FUNCTION public.admin_assign_investor_holding(
  uuid, text, numeric, numeric, numeric, text, uuid, uuid, boolean, boolean
) IS
  'Staff assign a portfolio holding to an investor (Phase 13 IMP).';

-- ---------------------------------------------------------------------------
-- Staff message investor
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_message_investor(
  p_investor_id uuid,
  p_body text,
  p_subject text DEFAULT 'Message from HD Homes',
  p_category text DEFAULT 'support',
  p_conversation_id uuid DEFAULT NULL,
  p_notify boolean DEFAULT true
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_conversation_id uuid := p_conversation_id;
  v_body text := NULLIF(trim(COALESCE(p_body, '')), '');
  v_subject text := COALESCE(NULLIF(trim(p_subject), ''), 'Message from HD Homes');
  v_category text := COALESCE(NULLIF(trim(p_category), ''), 'support');
BEGIN
  IF NOT (
    public.is_staff()
    OR public.has_permission('investors.write', auth.uid())
    OR public.has_permission('investors.communicate', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  IF v_body IS NULL THEN
    RAISE EXCEPTION 'body_required';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.investors i
    WHERE i.id = p_investor_id AND COALESCE(i.is_deleted, false) = false
  ) THEN
    RAISE EXCEPTION 'investor_not_found';
  END IF;

  IF v_conversation_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.investor_conversations c
      WHERE c.id = v_conversation_id
        AND c.investor_id = p_investor_id
        AND COALESCE(c.is_deleted, false) = false
    ) THEN
      RAISE EXCEPTION 'conversation_not_found';
    END IF;
  ELSE
    SELECT c.id INTO v_conversation_id
    FROM public.investor_conversations c
    WHERE c.investor_id = p_investor_id
      AND COALESCE(c.is_deleted, false) = false
      AND c.status = 'open'
      AND c.category = v_category
    ORDER BY c.last_message_at DESC NULLS LAST
    LIMIT 1;

    IF v_conversation_id IS NULL THEN
      INSERT INTO public.investor_conversations (
        investor_id, subject, category, assigned_staff_id, status,
        last_message_at, created_by, updated_by
      ) VALUES (
        p_investor_id,
        v_subject,
        v_category,
        auth.uid(),
        'open',
        now(),
        auth.uid(),
        auth.uid()
      )
      RETURNING id INTO v_conversation_id;
    END IF;
  END IF;

  INSERT INTO public.investor_conversation_messages (
    conversation_id, sender_id, body, created_by, updated_by
  ) VALUES (
    v_conversation_id, auth.uid(), v_body, auth.uid(), auth.uid()
  );

  UPDATE public.investor_conversations
  SET
    last_message_at = now(),
    updated_at = now(),
    updated_by = auth.uid(),
    assigned_staff_id = COALESCE(assigned_staff_id, auth.uid())
  WHERE id = v_conversation_id;

  IF COALESCE(p_notify, true) THEN
    INSERT INTO public.investor_notifications (
      investor_id, channel, title, body, is_read, sent_at, metadata
    ) VALUES (
      p_investor_id,
      'in_app',
      'New message from HD Homes',
      left(v_body, 160),
      false,
      now(),
      jsonb_build_object(
        'category', 'messages',
        'route', '/investor/messages',
        'conversation_id', v_conversation_id
      )
    );
  END IF;

  RETURN v_conversation_id;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_message_investor(
  uuid, text, text, text, uuid, boolean
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_message_investor(
  uuid, text, text, text, uuid, boolean
) TO authenticated;

COMMENT ON FUNCTION public.admin_message_investor(
  uuid, text, text, text, uuid, boolean
) IS
  'Staff start/reply investor portal conversation (Phase 13 IMP).';
