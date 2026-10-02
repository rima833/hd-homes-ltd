-- Require explicit investor capabilities for privileged IMP commands.
-- Adds mandatory activity records for every successful command.

BEGIN;

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
  v_previous text;
  v_status text := lower(trim(COALESCE(p_status, '')));
BEGIN
  IF NOT (
    public.has_permission('investors.kyc', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  IF v_status NOT IN (
    'pending','in_progress','awaiting_documents','under_review','approved',
    'partially_approved','rejected','expired','suspended','needs_resubmission'
  ) THEN
    RAISE EXCEPTION 'invalid_kyc_status';
  END IF;

  SELECT i.kyc_status INTO v_previous
  FROM public.investors i
  WHERE i.id = p_investor_id
    AND COALESCE(i.is_deleted, false) = false
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'investor_not_found'; END IF;

  IF v_status IS DISTINCT FROM v_previous AND NOT (
    (COALESCE(v_previous, 'pending') = 'pending'
      AND v_status IN (
        'in_progress','awaiting_documents','under_review','rejected',
        'needs_resubmission'
      ))
    OR (v_previous IN (
        'in_progress','awaiting_documents','under_review','needs_resubmission'
      ) AND v_status IN (
        'in_progress','awaiting_documents','under_review','approved',
        'partially_approved','rejected','needs_resubmission'
      ))
    OR (v_previous = 'partially_approved'
      AND v_status IN ('approved','expired','suspended','needs_resubmission'))
    OR (v_previous = 'approved'
      AND v_status IN ('expired','suspended'))
    OR (v_previous IN ('rejected','expired','suspended')
      AND v_status IN ('under_review','needs_resubmission'))
  ) THEN
    RAISE EXCEPTION 'invalid_kyc_transition:%->%', v_previous, v_status;
  END IF;

  UPDATE public.investors
  SET kyc_status = v_status, updated_at = now(), updated_by = auth.uid()
  WHERE id = p_investor_id;

  INSERT INTO public.investor_kyc_reviews (
    investor_id, status, reviewer_id, notes, reviewed_at
  ) VALUES (
    p_investor_id,
    v_status,
    auth.uid(),
    NULLIF(trim(COALESCE(p_notes, '')), ''),
    CASE
      WHEN v_status IN (
        'approved','partially_approved','rejected','suspended','expired'
      ) THEN now()
      ELSE NULL
    END
  )
  RETURNING id INTO v_id;

  INSERT INTO public.investor_activity_logs (
    investor_id, event_type, title, description, payload, actor_id, occurred_at
  ) VALUES (
    p_investor_id,
    'kyc_status_changed',
    'KYC status changed',
    NULLIF(trim(COALESCE(p_notes, '')), ''),
    jsonb_build_object(
      'review_id', v_id, 'from', v_previous, 'to', v_status
    ),
    auth.uid(),
    now()
  );

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_publish_investor_notification(
  p_investor_id uuid,
  p_title text,
  p_body text DEFAULT NULL,
  p_route text DEFAULT NULL,
  p_category text DEFAULT 'general',
  p_channel text DEFAULT 'in_app',
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_id uuid;
  v_title text := NULLIF(trim(COALESCE(p_title, '')), '');
  v_channel text := lower(trim(COALESCE(p_channel, 'in_app')));
  v_category text := lower(trim(COALESCE(p_category, 'general')));
  v_route text := NULLIF(trim(COALESCE(p_route, '')), '');
  v_meta jsonb;
BEGIN
  IF NOT (
    public.has_permission('investors.communicate', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;
  IF v_title IS NULL THEN RAISE EXCEPTION 'title_required'; END IF;
  IF v_channel NOT IN ('email','sms','whatsapp','in_app','push') THEN
    RAISE EXCEPTION 'invalid_channel';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.investors i
    WHERE i.id = p_investor_id AND COALESCE(i.is_deleted, false) = false
  ) THEN
    RAISE EXCEPTION 'investor_not_found';
  END IF;
  IF v_route IS NOT NULL AND v_route NOT LIKE '/investor%' THEN
    RAISE EXCEPTION 'invalid_route';
  END IF;

  v_meta := COALESCE(p_metadata, '{}'::jsonb)
    || jsonb_build_object('category', v_category);
  IF v_route IS NOT NULL THEN
    v_meta := v_meta || jsonb_build_object('route', v_route);
  END IF;

  INSERT INTO public.investor_notifications (
    investor_id, channel, title, body, is_read, sent_at, metadata
  ) VALUES (
    p_investor_id, v_channel, v_title,
    NULLIF(trim(COALESCE(p_body, '')), ''),
    false, now(), v_meta
  )
  RETURNING id INTO v_id;

  INSERT INTO public.investor_activity_logs (
    investor_id, event_type, title, description, payload, actor_id, occurred_at
  ) VALUES (
    p_investor_id,
    'notification_published',
    'Investor notification published',
    v_title,
    jsonb_build_object(
      'notification_id', v_id, 'channel', v_channel, 'route', v_route
    ),
    auth.uid(),
    now()
  );

  RETURN v_id;
END;
$$;

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
  v_message_id uuid;
  v_body text := NULLIF(trim(COALESCE(p_body, '')), '');
  v_subject text := COALESCE(
    NULLIF(trim(p_subject), ''), 'Message from HD Homes'
  );
  v_category text := COALESCE(NULLIF(trim(p_category), ''), 'support');
BEGIN
  IF NOT (
    public.has_permission('investors.communicate', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;
  IF v_body IS NULL THEN RAISE EXCEPTION 'body_required'; END IF;
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
        p_investor_id, v_subject, v_category, auth.uid(), 'open',
        now(), auth.uid(), auth.uid()
      )
      RETURNING id INTO v_conversation_id;
    END IF;
  END IF;

  INSERT INTO public.investor_conversation_messages (
    conversation_id, sender_id, body, created_by, updated_by
  ) VALUES (
    v_conversation_id, auth.uid(), v_body, auth.uid(), auth.uid()
  )
  RETURNING id INTO v_message_id;

  UPDATE public.investor_conversations
  SET last_message_at = now(),
      updated_at = now(),
      updated_by = auth.uid(),
      assigned_staff_id = COALESCE(assigned_staff_id, auth.uid())
  WHERE id = v_conversation_id;

  IF COALESCE(p_notify, true) THEN
    INSERT INTO public.investor_notifications (
      investor_id, channel, title, body, is_read, sent_at, metadata
    ) VALUES (
      p_investor_id, 'in_app', 'New message from HD Homes',
      left(v_body, 160), false, now(),
      jsonb_build_object(
        'category', 'messages',
        'route', '/investor/messages',
        'conversation_id', v_conversation_id
      )
    );
  END IF;

  INSERT INTO public.investor_activity_logs (
    investor_id, event_type, title, description, payload, actor_id, occurred_at
  ) VALUES (
    p_investor_id,
    'message_sent',
    'Message sent to investor',
    v_subject,
    jsonb_build_object(
      'conversation_id', v_conversation_id, 'message_id', v_message_id
    ),
    auth.uid(),
    now()
  );

  RETURN v_conversation_id;
END;
$$;

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
  v_currency text := upper(
    COALESCE(NULLIF(trim(p_currency), ''), 'NGN')
  );
  v_property_id uuid := p_property_id;
  v_opp_title text;
BEGIN
  IF NOT (
    public.has_permission('investors.assign', auth.uid())
    OR public.has_permission('investors.portfolio', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;
  IF v_label IS NULL THEN RAISE EXCEPTION 'label_required'; END IF;
  IF v_cost <= 0 OR v_value < 0 OR v_units <= 0 THEN
    RAISE EXCEPTION 'invalid_amount';
  END IF;
  IF v_currency !~ '^[A-Z]{3}$' THEN RAISE EXCEPTION 'invalid_currency'; END IF;
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
    WHERE o.id = p_opportunity_id
      AND o.status IN ('open','fully_funded');
    IF NOT FOUND THEN RAISE EXCEPTION 'opportunity_not_assignable'; END IF;
  END IF;

  SELECT ip.id INTO v_portfolio_id
  FROM public.investor_portfolios ip
  WHERE ip.investor_id = p_investor_id
  ORDER BY ip.created_at
  LIMIT 1
  FOR UPDATE;

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
    v_portfolio_id, p_opportunity_id, v_property_id, v_label, v_units,
    v_cost, v_value, v_currency, now(),
    jsonb_build_object(
      'assigned_by', auth.uid(),
      'assigned_at', now(),
      'source', 'admin_command_center'
    )
  )
  RETURNING id INTO v_holding_id;

  IF COALESCE(p_create_commitment, true) AND p_opportunity_id IS NOT NULL THEN
    INSERT INTO public.investment_commitments (
      investor_id, opportunity_id, amount, currency, status,
      committed_at, funded_at, notes, metadata
    ) VALUES (
      p_investor_id, p_opportunity_id, v_cost, v_currency, 'funded',
      now(), now(), 'Assigned via Investor Command Center',
      jsonb_build_object(
        'holding_id', v_holding_id,
        'assigned_by', auth.uid(),
        'source', 'admin_command_center'
      )
    );
  END IF;

  UPDATE public.investor_portfolios ip
  SET total_cost = COALESCE((
        SELECT SUM(h.cost_basis) FROM public.portfolio_holdings h
        WHERE h.portfolio_id = v_portfolio_id
      ), 0),
      total_value = COALESCE((
        SELECT SUM(h.current_value) FROM public.portfolio_holdings h
        WHERE h.portfolio_id = v_portfolio_id
      ), 0),
      unrealized_gain = COALESCE((
        SELECT SUM(h.current_value - h.cost_basis)
        FROM public.portfolio_holdings h
        WHERE h.portfolio_id = v_portfolio_id
      ), 0),
      updated_at = now()
  WHERE ip.id = v_portfolio_id;

  UPDATE public.investors i
  SET aum = COALESCE((
        SELECT SUM(ip.total_value) FROM public.investor_portfolios ip
        WHERE ip.investor_id = p_investor_id
      ), 0),
      total_committed = COALESCE((
        SELECT SUM(c.amount) FROM public.investment_commitments c
        WHERE c.investor_id = p_investor_id
          AND c.status NOT IN ('cancelled','refunded')
      ), 0),
      lifecycle_status = CASE
        WHEN i.lifecycle_status IN ('prospect','onboarding') THEN 'active'
        ELSE i.lifecycle_status
      END,
      updated_at = now(),
      updated_by = auth.uid()
  WHERE i.id = p_investor_id;

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

  IF COALESCE(p_notify, true) THEN
    INSERT INTO public.investor_notifications (
      investor_id, channel, title, body, is_read, sent_at, metadata
    ) VALUES (
      p_investor_id, 'in_app', 'New investment assigned',
      'A new holding was added to your portfolio: ' || v_label,
      false, now(),
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

REVOKE ALL ON FUNCTION public.admin_verify_investor_kyc(uuid,text,text)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_publish_investor_notification(
  uuid,text,text,text,text,text,jsonb
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_message_investor(
  uuid,text,text,text,uuid,boolean
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_assign_investor_holding(
  uuid,text,numeric,numeric,numeric,text,uuid,uuid,boolean,boolean
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.admin_verify_investor_kyc(uuid,text,text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_publish_investor_notification(
  uuid,text,text,text,text,text,jsonb
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_message_investor(
  uuid,text,text,text,uuid,boolean
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_assign_investor_holding(
  uuid,text,numeric,numeric,numeric,text,uuid,uuid,boolean,boolean
) TO authenticated;

COMMIT;
