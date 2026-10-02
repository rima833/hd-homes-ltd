-- Close remaining website money gaps for Finance admin:
-- 1) Investor confirm posts payment + receipt + wallet credit
-- 2) Calculator lead → invoice conversion
-- 3) Referral / sales commission status updates
-- 4) Realtime publication for those tables

CREATE OR REPLACE FUNCTION public.admin_confirm_investor_intent(
  p_intent_id uuid,
  p_status text DEFAULT 'confirmed',
  p_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_intent public.investor_payment_intents%ROWTYPE;
  v_payment_id uuid;
  v_receipt_id uuid;
  v_receipt_no text;
BEGIN
  IF NOT public._finance_can_manage() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_status NOT IN ('confirmed','rejected','cancelled') THEN
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

  IF p_status = 'confirmed'
     AND v_intent.status IN ('confirmed','completed') THEN
    RETURN jsonb_build_object(
      'id', p_intent_id,
      'status', v_intent.status,
      'amount', v_intent.amount,
      'already_confirmed', true
    );
  END IF;

  UPDATE public.investor_payment_intents
  SET status = p_status,
      notes = CASE WHEN p_notes IS NULL THEN notes ELSE p_notes END,
      paid_at = CASE WHEN p_status = 'confirmed' THEN coalesce(paid_at, now()) ELSE paid_at END,
      updated_at = now(),
      updated_by = auth.uid()
  WHERE id = p_intent_id;

  IF p_status = 'confirmed' THEN
    INSERT INTO public.payments (
      investor_id, amount, currency, payment_method, payment_provider,
      provider_reference, paid_at, status, notes, metadata, created_by, updated_by
    ) VALUES (
      v_intent.investor_id,
      v_intent.amount,
      COALESCE(v_intent.currency, 'NGN'),
      'bank_transfer',
      COALESCE(v_intent.provider, 'manual'),
      COALESCE(v_intent.provider_reference, v_intent.bank_reference, p_intent_id::text),
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

    v_receipt_no := 'INV-RCP-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));

    INSERT INTO public.finance_receipts (
      receipt_number, payment_id, amount, currency, issued_at,
      payer_label, method_label, notes, metadata
    ) VALUES (
      v_receipt_no,
      v_payment_id,
      v_intent.amount,
      COALESCE(v_intent.currency, 'NGN'),
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

    INSERT INTO public.investor_wallets (investor_id, available_balance, currency)
    VALUES (v_intent.investor_id, v_intent.amount, COALESCE(v_intent.currency, 'NGN'))
    ON CONFLICT (investor_id) DO UPDATE
    SET available_balance = public.investor_wallets.available_balance + EXCLUDED.available_balance,
        updated_at = now();
  END IF;

  PERFORM public._audit_finance(
    'investor_intent_' || p_status,
    'investor_payment_intent',
    p_intent_id,
    jsonb_build_object('status', v_intent.status),
    jsonb_build_object(
      'status', p_status,
      'amount', v_intent.amount,
      'payment_id', v_payment_id,
      'receipt_id', v_receipt_id
    )
  );

  RETURN jsonb_build_object(
    'id', p_intent_id,
    'status', p_status,
    'amount', v_intent.amount,
    'payment_id', v_payment_id,
    'receipt_id', v_receipt_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_convert_calculator_lead(
  p_application_id uuid,
  p_status text DEFAULT 'converted',
  p_create_invoice boolean DEFAULT true,
  p_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_app public.calculator_applications%ROWTYPE;
  v_invoice jsonb;
  v_amount numeric(16,2);
BEGIN
  IF NOT public._finance_can_manage() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_status NOT IN ('new','contacted','qualified','converted','closed','spam') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;

  SELECT * INTO v_app
  FROM public.calculator_applications
  WHERE id = p_application_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'lead_not_found';
  END IF;

  UPDATE public.calculator_applications
  SET status = p_status,
      notes = CASE WHEN p_notes IS NULL THEN notes ELSE p_notes END,
      updated_at = now(),
      metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
        'finance_converted_at', now(),
        'finance_status', p_status
      )
  WHERE id = p_application_id;

  IF p_create_invoice AND p_status = 'converted' THEN
    v_amount := COALESCE(v_app.deposit_amount, v_app.monthly_payment, v_app.property_price, 0);
    IF v_amount > 0 THEN
      v_invoice := public.admin_create_invoice(
        COALESCE(v_app.full_name, 'Calculator lead'),
        v_amount,
        NULL,
        v_app.property_id,
        (CURRENT_DATE + 14),
        COALESCE(p_notes, 'Converted from website payment calculator lead')
      );
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'id', p_application_id,
    'status', p_status,
    'invoice', v_invoice
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_commission_status(
  p_source text,
  p_commission_id uuid,
  p_status text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF NOT public._finance_can_manage() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_status NOT IN ('pending','approved','paid','rejected','cancelled') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;

  IF p_source = 'client_referral' THEN
    UPDATE public.client_referral_commissions
    SET status = p_status,
        paid_at = CASE WHEN p_status = 'paid' THEN coalesce(paid_at, now()) ELSE paid_at END,
        updated_at = now(),
        updated_by = auth.uid()
    WHERE id = p_commission_id AND COALESCE(is_deleted, false) = false;
  ELSIF p_source = 'investor_referral' THEN
    UPDATE public.investor_referral_commissions
    SET status = p_status,
        paid_at = CASE WHEN p_status = 'paid' THEN coalesce(paid_at, now()) ELSE paid_at END,
        updated_at = now(),
        updated_by = auth.uid()
    WHERE id = p_commission_id AND COALESCE(is_deleted, false) = false;
  ELSIF p_source = 'sales' THEN
    UPDATE public.sales_commissions
    SET status = p_status,
        approved_at = CASE WHEN p_status = 'approved' THEN coalesce(approved_at, now()) ELSE approved_at END,
        paid_at = CASE WHEN p_status = 'paid' THEN coalesce(paid_at, now()) ELSE paid_at END,
        updated_at = now()
    WHERE id = p_commission_id;
  ELSE
    RAISE EXCEPTION 'invalid_source';
  END IF;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'commission_not_found';
  END IF;

  PERFORM public._audit_finance(
    'commission_' || p_status,
    p_source || '_commission',
    p_commission_id,
    NULL,
    jsonb_build_object('status', p_status)
  );

  RETURN jsonb_build_object('id', p_commission_id, 'source', p_source, 'status', p_status);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_confirm_investor_intent(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_convert_calculator_lead(uuid, text, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_commission_status(text, uuid, text) TO authenticated;

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'calculator_applications',
    'client_referral_commissions',
    'investor_referral_commissions',
    'sales_commissions',
    'commission_payments',
    'investment_distributions',
    'investment_receiving_accounts',
    'investor_wallets'
  ]
  LOOP
    IF EXISTS (
      SELECT 1 FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relname = t AND c.relkind = 'r'
    ) AND NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE %I', t);
    END IF;
  END LOOP;
END $$;
