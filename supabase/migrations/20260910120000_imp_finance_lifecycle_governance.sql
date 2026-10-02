-- Phase 6: governed payment confirmation, commitment funding, owner enrichment.

BEGIN;

-- Directory / 360 owner display name
CREATE OR REPLACE FUNCTION public.admin_list_investors(
  p_search text DEFAULT NULL,
  p_investor_type text DEFAULT NULL,
  p_lifecycle_status text DEFAULT NULL,
  p_kyc_status text DEFAULT NULL,
  p_assigned_staff_id uuid DEFAULT NULL,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_limit integer := least(greatest(COALESCE(p_limit, 50), 1), 100);
  v_offset integer := greatest(COALESCE(p_offset, 0), 0);
  v_search text := NULLIF(trim(COALESCE(p_search, '')), '');
  v_total bigint;
  v_items jsonb;
BEGIN
  IF NOT (
    public.has_permission('investors.read', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN RAISE EXCEPTION 'not authorized'; END IF;

  SELECT count(*) INTO v_total
  FROM public.investors i
  WHERE COALESCE(i.is_deleted, false) = false
    AND (
      v_search IS NULL OR i.full_name ILIKE '%' || v_search || '%'
      OR i.email ILIKE '%' || v_search || '%'
      OR i.phone ILIKE '%' || v_search || '%'
      OR i.investor_code ILIKE '%' || v_search || '%'
      OR i.company ILIKE '%' || v_search || '%'
    )
    AND (p_investor_type IS NULL OR i.investor_type = p_investor_type)
    AND (p_lifecycle_status IS NULL OR i.lifecycle_status = p_lifecycle_status)
    AND (p_kyc_status IS NULL OR i.kyc_status = p_kyc_status)
    AND (
      p_assigned_staff_id IS NULL
      OR i.assigned_staff_id = p_assigned_staff_id
    );

  SELECT COALESCE(jsonb_agg(row_data ORDER BY sort_name, sort_id), '[]'::jsonb)
    INTO v_items
  FROM (
    SELECT
      to_jsonb(i) || jsonb_build_object(
        'assigned_staff_name', (
          SELECT COALESCE(
            NULLIF(trim(concat_ws(' ', p.first_name, p.last_name)), ''),
            p.email
          )
          FROM public.profiles p
          WHERE p.id = i.assigned_staff_id
        ),
        'tags', COALESCE((
          SELECT jsonb_agg(t.name ORDER BY t.name)
          FROM public.investor_tag_assignments a
          JOIN public.investor_tags t ON t.id = a.tag_id
          WHERE a.investor_id = i.id
        ), '[]'::jsonb),
        'open_alerts', (
          SELECT count(*) FROM public.investor_alerts a
          WHERE a.investor_id = i.id AND a.status = 'open'
        ),
        'last_activity_at', (
          SELECT max(a.occurred_at) FROM public.investor_activity_logs a
          WHERE a.investor_id = i.id
        )
      ) AS row_data,
      lower(COALESCE(i.full_name, i.investor_code, '')) AS sort_name,
      i.id AS sort_id
    FROM public.investors i
    WHERE COALESCE(i.is_deleted, false) = false
      AND (
        v_search IS NULL OR i.full_name ILIKE '%' || v_search || '%'
        OR i.email ILIKE '%' || v_search || '%'
        OR i.phone ILIKE '%' || v_search || '%'
        OR i.investor_code ILIKE '%' || v_search || '%'
        OR i.company ILIKE '%' || v_search || '%'
      )
      AND (p_investor_type IS NULL OR i.investor_type = p_investor_type)
      AND (
        p_lifecycle_status IS NULL
        OR i.lifecycle_status = p_lifecycle_status
      )
      AND (p_kyc_status IS NULL OR i.kyc_status = p_kyc_status)
      AND (
        p_assigned_staff_id IS NULL
        OR i.assigned_staff_id = p_assigned_staff_id
      )
    ORDER BY sort_name, sort_id
    LIMIT v_limit OFFSET v_offset
  ) page;

  RETURN jsonb_build_object(
    'items', v_items, 'total', v_total, 'limit', v_limit,
    'offset', v_offset, 'has_more', v_offset + v_limit < v_total
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_get_investor_360(p_investor_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_investor jsonb;
BEGIN
  IF NOT (
    public.has_permission('investors.read', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN RAISE EXCEPTION 'not authorized'; END IF;
  SELECT to_jsonb(i) || jsonb_build_object(
    'assigned_staff_name', (
      SELECT COALESCE(
        NULLIF(trim(concat_ws(' ', p.first_name, p.last_name)), ''),
        p.email
      )
      FROM public.profiles p
      WHERE p.id = i.assigned_staff_id
    )
  )
  INTO v_investor
  FROM public.investors i
  WHERE i.id = p_investor_id AND COALESCE(i.is_deleted, false) = false;
  IF v_investor IS NULL THEN RAISE EXCEPTION 'investor_not_found'; END IF;

  RETURN v_investor || jsonb_build_object(
    'portfolios', COALESCE((
      SELECT jsonb_agg(to_jsonb(p) ORDER BY p.created_at)
      FROM public.investor_portfolios p
      WHERE p.investor_id = p_investor_id
    ), '[]'::jsonb),
    'holdings', COALESCE((
      SELECT jsonb_agg(to_jsonb(h) ORDER BY h.created_at DESC)
      FROM public.portfolio_holdings h
      JOIN public.investor_portfolios p ON p.id = h.portfolio_id
      WHERE p.investor_id = p_investor_id
    ), '[]'::jsonb),
    'commitments', COALESCE((
      SELECT jsonb_agg(to_jsonb(c) ORDER BY c.committed_at DESC)
      FROM public.investment_commitments c
      WHERE c.investor_id = p_investor_id
    ), '[]'::jsonb),
    'distributions', COALESCE((
      SELECT jsonb_agg(to_jsonb(d) ORDER BY d.created_at DESC)
      FROM public.investment_distributions d
      WHERE d.investor_id = p_investor_id
    ), '[]'::jsonb),
    'wallets', COALESCE((
      SELECT jsonb_agg(to_jsonb(w) ORDER BY w.created_at)
      FROM public.investor_wallets w
      WHERE w.investor_id = p_investor_id
    ), '[]'::jsonb),
    'ledger', COALESCE((
      SELECT jsonb_agg(to_jsonb(t) ORDER BY t.posted_at DESC)
      FROM (
        SELECT * FROM public.investment_transactions
        WHERE investor_id = p_investor_id
        ORDER BY posted_at DESC LIMIT 200
      ) t
    ), '[]'::jsonb),
    'kyc_documents', COALESCE((
      SELECT jsonb_agg(to_jsonb(k) ORDER BY k.created_at DESC)
      FROM public.investor_kyc_documents k
      WHERE k.investor_id = p_investor_id
    ), '[]'::jsonb),
    'documents', COALESCE((
      SELECT jsonb_agg(to_jsonb(d) ORDER BY d.created_at DESC)
      FROM public.investor_documents d
      WHERE d.investor_id = p_investor_id
    ), '[]'::jsonb),
    'payment_intents', COALESCE((
      SELECT jsonb_agg(to_jsonb(pi) ORDER BY pi.created_at DESC)
      FROM (
        SELECT * FROM public.investor_payment_intents
        WHERE investor_id = p_investor_id
          AND COALESCE(is_deleted, false) = false
        ORDER BY created_at DESC LIMIT 50
      ) pi
    ), '[]'::jsonb),
    'tasks', COALESCE((
      SELECT jsonb_agg(to_jsonb(t) ORDER BY t.created_at DESC)
      FROM (
        SELECT * FROM public.investor_tasks
        WHERE investor_id = p_investor_id
          AND status IN ('open', 'in_progress')
        ORDER BY created_at DESC LIMIT 50
      ) t
    ), '[]'::jsonb),
    'activities', COALESCE((
      SELECT jsonb_agg(to_jsonb(a) ORDER BY a.occurred_at DESC)
      FROM (
        SELECT * FROM public.investor_activity_logs
        WHERE investor_id = p_investor_id
        ORDER BY occurred_at DESC LIMIT 200
      ) a
    ), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_fund_investment_commitment(
  p_commitment_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cmt public.investment_commitments%ROWTYPE;
  v_portfolio_id uuid;
  v_holding_id uuid;
  v_label text;
  v_ledger jsonb;
  v_currency text;
BEGIN
  IF NOT (
    public.has_permission('investors.portfolio', auth.uid())
    OR public.has_permission('investors.assign', auth.uid())
    OR public.has_permission('investors.payments', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  SELECT * INTO v_cmt
  FROM public.investment_commitments
  WHERE id = p_commitment_id
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'commitment_not_found'; END IF;

  IF v_cmt.status = 'funded' THEN
    RETURN jsonb_build_object(
      'id', v_cmt.id,
      'status', v_cmt.status,
      'holding_id', v_cmt.metadata->>'holding_id',
      'already_funded', true
    );
  END IF;
  IF v_cmt.status IN ('cancelled', 'refunded') THEN
    RAISE EXCEPTION 'commitment_not_fundable';
  END IF;

  v_currency := upper(COALESCE(NULLIF(trim(v_cmt.currency), ''), 'NGN'));

  UPDATE public.investment_commitments
  SET status = 'funded',
      funded_at = coalesce(funded_at, now()),
      updated_at = now()
  WHERE id = p_commitment_id;

  SELECT ip.id INTO v_portfolio_id
  FROM public.investor_portfolios ip
  WHERE ip.investor_id = v_cmt.investor_id
  ORDER BY ip.created_at
  LIMIT 1
  FOR UPDATE;

  IF v_portfolio_id IS NULL THEN
    INSERT INTO public.investor_portfolios (
      investor_id, name, currency, total_value, total_cost
    ) VALUES (
      v_cmt.investor_id, 'Primary Portfolio', v_currency, 0, 0
    )
    RETURNING id INTO v_portfolio_id;
  END IF;

  v_holding_id := NULLIF(v_cmt.metadata->>'holding_id', '')::uuid;
  IF v_holding_id IS NULL THEN
    SELECT o.title INTO v_label
    FROM public.investment_opportunities o
    WHERE o.id = v_cmt.opportunity_id;
    v_label := COALESCE(v_label, 'Funded commitment');

    INSERT INTO public.portfolio_holdings (
      portfolio_id, opportunity_id, label, units,
      cost_basis, current_value, currency, acquired_at, metadata
    ) VALUES (
      v_portfolio_id, v_cmt.opportunity_id, v_label, 1,
      v_cmt.amount, v_cmt.amount, v_currency, now(),
      jsonb_build_object(
        'commitment_id', v_cmt.id,
        'source', 'admin_fund_investment_commitment',
        'funded_by', auth.uid()
      )
    )
    RETURNING id INTO v_holding_id;

    UPDATE public.investment_commitments
    SET metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
      'holding_id', v_holding_id
    )
    WHERE id = p_commitment_id;
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
        WHERE ip.investor_id = v_cmt.investor_id
      ), 0),
      total_committed = COALESCE((
        SELECT SUM(c.amount) FROM public.investment_commitments c
        WHERE c.investor_id = v_cmt.investor_id
          AND c.status NOT IN ('cancelled', 'refunded')
      ), 0),
      lifecycle_status = CASE
        WHEN i.lifecycle_status IN ('prospect', 'onboarding') THEN 'active'
        ELSE i.lifecycle_status
      END,
      updated_at = now(),
      updated_by = auth.uid()
  WHERE i.id = v_cmt.investor_id;

  v_ledger := public.admin_post_investor_ledger_entry(
    v_cmt.investor_id,
    'commitment_funding',
    v_cmt.amount,
    v_currency,
    'out',
    'commitment:' || p_commitment_id::text || ':funding',
    'investment_commitment',
    p_commitment_id,
    v_portfolio_id,
    v_cmt.opportunity_id,
    'Commitment funded',
    NULL,
    jsonb_build_object('holding_id', v_holding_id)
  );

  INSERT INTO public.investor_activity_logs (
    investor_id, event_type, title, description, payload, actor_id, occurred_at
  ) VALUES (
    v_cmt.investor_id,
    'commitment_funded',
    'Commitment funded',
    v_label,
    jsonb_build_object(
      'commitment_id', p_commitment_id,
      'holding_id', v_holding_id,
      'amount', v_cmt.amount,
      'ledger', v_ledger
    ),
    auth.uid(),
    now()
  );

  INSERT INTO public.investor_command_events (
    investor_id, aggregate_type, aggregate_id, event_type, payload, actor_id
  ) VALUES (
    v_cmt.investor_id,
    'investment_commitments',
    p_commitment_id,
    'funded',
    jsonb_build_object(
      'status', 'funded',
      'holding_id', v_holding_id,
      'amount', v_cmt.amount
    ),
    auth.uid()
  );

  RETURN jsonb_build_object(
    'id', p_commitment_id,
    'status', 'funded',
    'holding_id', v_holding_id,
    'ledger', v_ledger,
    'already_funded', false
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_confirm_investor_intent(
  p_intent_id uuid,
  p_status text DEFAULT 'confirmed',
  p_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_intent public.investor_payment_intents%ROWTYPE;
  v_payment_id uuid;
  v_receipt_id uuid;
  v_receipt_no text;
  v_ledger jsonb;
  v_status text := lower(trim(COALESCE(p_status, '')));
  v_currency text;
  v_already boolean := false;
  v_commitment_id uuid;
BEGIN
  IF NOT (
    public.has_permission('investors.payments', auth.uid())
    OR public._finance_can_manage()
    OR public.has_role('super_admin', auth.uid())
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;
  IF v_status NOT IN ('confirmed', 'rejected', 'cancelled') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;

  SELECT * INTO v_intent
  FROM public.investor_payment_intents
  WHERE id = p_intent_id
    AND COALESCE(is_deleted, false) = false
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'intent_not_found';
  END IF;

  IF v_status = 'confirmed' AND v_intent.status = 'confirmed' THEN
    SELECT id INTO v_payment_id
    FROM public.payments
    WHERE metadata->>'intent_id' = p_intent_id::text
      AND COALESCE(is_deleted, false) = false
    LIMIT 1;
    RETURN jsonb_build_object(
      'id', p_intent_id,
      'status', v_intent.status,
      'amount', v_intent.amount,
      'payment_id', v_payment_id,
      'already_confirmed', true
    );
  END IF;

  IF v_intent.status NOT IN (
    'pending', 'submitted', 'awaiting_confirmation',
    'pending_verification', 'info_requested'
  ) THEN
    RAISE EXCEPTION 'invalid_transition from % to %', v_intent.status, v_status;
  END IF;

  v_currency := upper(COALESCE(NULLIF(trim(v_intent.currency), ''), 'NGN'));

  UPDATE public.investor_payment_intents
  SET status = v_status,
      notes = CASE WHEN p_notes IS NULL THEN notes ELSE p_notes END,
      paid_at = CASE
        WHEN v_status = 'confirmed' THEN coalesce(paid_at, now())
        ELSE paid_at
      END,
      updated_at = now(),
      updated_by = auth.uid()
  WHERE id = p_intent_id;

  IF v_status = 'confirmed' THEN
    SELECT id INTO v_payment_id
    FROM public.payments
    WHERE metadata->>'intent_id' = p_intent_id::text
      AND COALESCE(is_deleted, false) = false
    LIMIT 1;

    IF v_payment_id IS NULL THEN
      INSERT INTO public.payments (
        investor_id, amount, currency, payment_method, payment_provider,
        provider_reference, paid_at, status, notes, metadata,
        created_by, updated_by
      ) VALUES (
        v_intent.investor_id,
        v_intent.amount,
        v_currency,
        'bank_transfer',
        COALESCE(v_intent.provider, 'manual'),
        COALESCE(
          v_intent.provider_reference,
          v_intent.bank_reference,
          p_intent_id::text
        ),
        now(),
        'completed',
        p_notes,
        jsonb_build_object(
          'source', 'investor_portal',
          'intent_id', v_intent.id,
          'bank_reference', v_intent.bank_reference,
          'receiving_account_id', v_intent.receiving_account_id
        ),
        auth.uid(),
        auth.uid()
      )
      RETURNING id INTO v_payment_id;
    ELSE
      v_already := true;
    END IF;

    IF NOT v_already THEN
      v_receipt_no := 'INV-RCP-' || upper(
        substr(replace(gen_random_uuid()::text, '-', ''), 1, 10)
      );
      INSERT INTO public.finance_receipts (
        receipt_number, payment_id, amount, currency, issued_at,
        payer_label, method_label, notes, metadata
      ) VALUES (
        v_receipt_no,
        v_payment_id,
        v_intent.amount,
        v_currency,
        now(),
        'Investor',
        'Bank Transfer',
        p_notes,
        jsonb_build_object('intent_id', v_intent.id, 'source', 'investor_portal')
      )
      RETURNING id INTO v_receipt_id;

      UPDATE public.payments
      SET finance_receipt_id = v_receipt_id, updated_at = now()
      WHERE id = v_payment_id;
    END IF;

    v_ledger := public.admin_post_investor_ledger_entry(
      v_intent.investor_id,
      'deposit',
      v_intent.amount,
      v_currency,
      'in',
      'intent:' || p_intent_id::text || ':deposit',
      'investor_payment_intent',
      p_intent_id,
      NULL,
      NULL,
      'Confirmed investor payment intent',
      COALESCE(v_intent.bank_reference, v_intent.provider_reference),
      jsonb_build_object(
        'payment_id', v_payment_id,
        'intent_id', p_intent_id
      )
    );

    -- Keep wallet cache aligned with newly confirmed funds once.
    IF NOT v_already THEN
      INSERT INTO public.investor_wallets (
        investor_id, available_balance, currency
      ) VALUES (
        v_intent.investor_id, v_intent.amount, v_currency
      )
      ON CONFLICT (investor_id) DO UPDATE
      SET available_balance =
            public.investor_wallets.available_balance + EXCLUDED.available_balance,
          updated_at = now();
    END IF;

    v_commitment_id := NULLIF(
      COALESCE(
        v_intent.metadata->>'commitment_id',
        v_intent.metadata->>'investment_commitment_id'
      ),
      ''
    )::uuid;
    IF v_commitment_id IS NOT NULL THEN
      BEGIN
        PERFORM public.admin_fund_investment_commitment(v_commitment_id);
      EXCEPTION WHEN OTHERS THEN
        -- Payment confirmation must still succeed; funding can be retried.
        NULL;
      END;
    END IF;
  END IF;

  INSERT INTO public.investor_activity_logs (
    investor_id, event_type, title, description, payload, actor_id, occurred_at
  ) VALUES (
    v_intent.investor_id,
    'payment_intent_' || v_status,
    'Payment intent ' || v_status,
    COALESCE(p_notes, v_intent.bank_reference, v_intent.provider_reference),
    jsonb_build_object(
      'intent_id', p_intent_id,
      'status', v_status,
      'amount', v_intent.amount,
      'payment_id', v_payment_id,
      'receipt_id', v_receipt_id,
      'ledger', v_ledger
    ),
    auth.uid(),
    now()
  );

  INSERT INTO public.investor_command_events (
    investor_id, aggregate_type, aggregate_id, event_type, payload, actor_id
  ) VALUES (
    v_intent.investor_id,
    'investor_payment_intents',
    p_intent_id,
    'status_' || v_status,
    jsonb_build_object(
      'status', v_status,
      'amount', v_intent.amount,
      'payment_id', v_payment_id
    ),
    auth.uid()
  );

  BEGIN
    PERFORM public._audit_finance(
      'investor_intent_' || v_status,
      'investor_payment_intent',
      p_intent_id,
      jsonb_build_object('status', v_intent.status),
      jsonb_build_object(
        'status', v_status,
        'amount', v_intent.amount,
        'payment_id', v_payment_id,
        'receipt_id', v_receipt_id
      )
    );
  EXCEPTION WHEN undefined_function THEN
    NULL;
  END;

  RETURN jsonb_build_object(
    'id', p_intent_id,
    'status', v_status,
    'amount', v_intent.amount,
    'payment_id', v_payment_id,
    'receipt_id', v_receipt_id,
    'ledger', v_ledger,
    'already_confirmed', v_already
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_confirm_investor_intent(uuid, text, text)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_fund_investment_commitment(uuid)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_confirm_investor_intent(uuid, text, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_fund_investment_commitment(uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_investors(
  text, text, text, text, uuid, integer, integer
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_investor_360(uuid) TO authenticated;

COMMIT;
