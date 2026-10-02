-- Admin Finance ops: installments, invoices, deposits, distributions, settings.
-- Enables end-to-end management of client + investor money flows from Finance CC.

CREATE OR REPLACE FUNCTION public._finance_can_manage()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT public.has_permission('finance.write')
      OR public.has_permission('finance.invoices')
      OR public.has_permission('finance.payments')
      OR public.has_permission('manage_payments')
      OR public.has_role('super_admin');
$$;

-- Investment receiving accounts: staff write
DROP POLICY IF EXISTS investment_receiving_accounts_write ON public.investment_receiving_accounts;
CREATE POLICY investment_receiving_accounts_write
  ON public.investment_receiving_accounts
  FOR ALL
  TO authenticated
  USING (public._finance_can_manage())
  WITH CHECK (public._finance_can_manage());

-- ---------------------------------------------------------------------------
-- Generate installment schedule (deposit + monthly)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_generate_installments(
  p_client_id uuid,
  p_property_id uuid,
  p_total_amount numeric,
  p_deposit_amount numeric DEFAULT 0,
  p_installment_count integer DEFAULT 0,
  p_first_due date DEFAULT CURRENT_DATE,
  p_frequency_days integer DEFAULT 30,
  p_payment_plan_label text DEFAULT NULL,
  p_application_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_balance numeric(16,2);
  v_each numeric(16,2);
  v_last numeric(16,2);
  v_due date;
  v_i int;
  v_ids uuid[] := ARRAY[]::uuid[];
  v_id uuid;
  v_plan_id uuid;
BEGIN
  IF NOT public._finance_can_manage() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_client_id IS NULL OR p_property_id IS NULL THEN
    RAISE EXCEPTION 'client_and_property_required';
  END IF;
  IF COALESCE(p_total_amount, 0) <= 0 THEN
    RAISE EXCEPTION 'invalid_total_amount';
  END IF;
  IF COALESCE(p_deposit_amount, 0) < 0 OR p_deposit_amount > p_total_amount THEN
    RAISE EXCEPTION 'invalid_deposit_amount';
  END IF;
  IF COALESCE(p_installment_count, 0) < 0 THEN
    RAISE EXCEPTION 'invalid_installment_count';
  END IF;

  IF p_payment_plan_label IS NOT NULL THEN
    INSERT INTO public.property_payment_plans (
      property_id, name, initial_deposit_percent, installment_months, details, status
    ) VALUES (
      p_property_id,
      p_payment_plan_label,
      CASE WHEN p_total_amount > 0
        THEN round((p_deposit_amount / p_total_amount) * 100, 2)
        ELSE 0 END,
      GREATEST(p_installment_count, 0),
      jsonb_build_object('source', 'finance_admin', 'application_id', p_application_id),
      'active'
    )
    RETURNING id INTO v_plan_id;
  END IF;

  -- Deposit row
  IF COALESCE(p_deposit_amount, 0) > 0 THEN
    INSERT INTO public.installments (
      payment_plan_id, client_id, property_id, amount, due_date, status,
      amount_paid, amount_outstanding, installment_number, created_by, updated_by
    ) VALUES (
      v_plan_id, p_client_id, p_property_id, p_deposit_amount, p_first_due, 'pending',
      0, p_deposit_amount, 0, auth.uid(), auth.uid()
    )
    RETURNING id INTO v_id;
    v_ids := array_append(v_ids, v_id);
  END IF;

  v_balance := p_total_amount - COALESCE(p_deposit_amount, 0);
  IF p_installment_count > 0 AND v_balance > 0 THEN
    v_each := round(v_balance / p_installment_count, 2);
    v_last := v_balance - (v_each * (p_installment_count - 1));
    FOR v_i IN 1..p_installment_count LOOP
      v_due := (p_first_due + ((v_i) * GREATEST(p_frequency_days, 1)));
      INSERT INTO public.installments (
        payment_plan_id, client_id, property_id, amount, due_date, status,
        amount_paid, amount_outstanding, installment_number, created_by, updated_by
      ) VALUES (
        v_plan_id, p_client_id, p_property_id,
        CASE WHEN v_i = p_installment_count THEN v_last ELSE v_each END,
        v_due, 'pending',
        0,
        CASE WHEN v_i = p_installment_count THEN v_last ELSE v_each END,
        v_i, auth.uid(), auth.uid()
      )
      RETURNING id INTO v_id;
      v_ids := array_append(v_ids, v_id);
    END LOOP;
  ELSIF v_balance > 0 THEN
    -- Single balance due if no installment count
    INSERT INTO public.installments (
      payment_plan_id, client_id, property_id, amount, due_date, status,
      amount_paid, amount_outstanding, installment_number, created_by, updated_by
    ) VALUES (
      v_plan_id, p_client_id, p_property_id, v_balance, p_first_due, 'pending',
      0, v_balance, 1, auth.uid(), auth.uid()
    )
    RETURNING id INTO v_id;
    v_ids := array_append(v_ids, v_id);
  END IF;

  IF p_application_id IS NOT NULL THEN
    UPDATE public.client_property_applications
    SET status = CASE
          WHEN status IN ('approved', 'payment_pending', 'under_review', 'submitted')
            THEN 'payment_active'
          ELSE status
        END,
        updated_at = now(),
        updated_by = auth.uid(),
        metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
          'installment_ids', to_jsonb(v_ids),
          'payment_plan_id', v_plan_id,
          'scheduled_total', p_total_amount
        )
    WHERE id = p_application_id;
  END IF;

  PERFORM public._audit_finance(
    'installments_generated', 'installment', COALESCE(v_ids[1], p_client_id),
    NULL,
    jsonb_build_object(
      'client_id', p_client_id,
      'property_id', p_property_id,
      'count', coalesce(array_length(v_ids, 1), 0),
      'total', p_total_amount,
      'application_id', p_application_id
    )
  );

  RETURN jsonb_build_object(
    'installment_ids', to_jsonb(v_ids),
    'payment_plan_id', v_plan_id,
    'count', coalesce(array_length(v_ids, 1), 0)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_update_installment_status(
  p_installment_id uuid,
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
  IF p_status NOT IN ('pending','partially_paid','paid','overdue','cancelled','waived','completed') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;
  UPDATE public.installments
  SET status = p_status,
      paid_at = CASE WHEN p_status IN ('paid','completed') THEN coalesce(paid_at, now()) ELSE paid_at END,
      amount_outstanding = CASE
        WHEN p_status IN ('paid','completed','waived','cancelled') THEN 0
        ELSE amount_outstanding
      END,
      amount_paid = CASE
        WHEN p_status IN ('paid','completed') THEN amount
        ELSE amount_paid
      END,
      updated_at = now(),
      updated_by = auth.uid()
  WHERE id = p_installment_id AND COALESCE(is_deleted,false)=false;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'installment_not_found';
  END IF;
  RETURN jsonb_build_object('id', p_installment_id, 'status', p_status);
END;
$$;

-- ---------------------------------------------------------------------------
-- Invoices
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_create_invoice(
  p_party_name text,
  p_amount numeric,
  p_client_id uuid DEFAULT NULL,
  p_property_id uuid DEFAULT NULL,
  p_due_date date DEFAULT (CURRENT_DATE + 7),
  p_notes text DEFAULT NULL,
  p_party_type text DEFAULT 'client'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_id uuid;
  v_no text;
BEGIN
  IF NOT public._finance_can_manage() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF coalesce(trim(p_party_name), '') = '' THEN
    RAISE EXCEPTION 'party_required';
  END IF;
  IF coalesce(p_amount, 0) <= 0 THEN
    RAISE EXCEPTION 'invalid_amount';
  END IF;

  v_no := 'HDH-INV-' || to_char(timezone('UTC', now()), 'YYYYMMDD') || '-' ||
          upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));

  INSERT INTO public.invoices (
    invoice_number, party_name, party_type, client_id, property_id,
    amount, balance_due, subtotal, currency, status, due_date, issued_at,
    notes, created_by, updated_by
  ) VALUES (
    v_no, trim(p_party_name), coalesce(p_party_type, 'client'), p_client_id, p_property_id,
    p_amount, p_amount, p_amount, 'NGN', 'sent', p_due_date, CURRENT_DATE,
    p_notes, auth.uid(), auth.uid()
  )
  RETURNING id INTO v_id;

  PERFORM public._audit_finance(
    'invoice_created', 'invoice', v_id,
    NULL, jsonb_build_object('invoice_number', v_no, 'amount', p_amount)
  );

  RETURN jsonb_build_object('id', v_id, 'invoice_number', v_no, 'status', 'sent');
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_invoice_status(
  p_invoice_id uuid,
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
  IF p_status NOT IN ('draft','sent','paid','overdue','cancelled','partial','void') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;
  UPDATE public.invoices
  SET status = CASE WHEN p_status = 'void' THEN 'cancelled' ELSE p_status END,
      balance_due = CASE WHEN p_status IN ('paid','cancelled','void') THEN 0 ELSE balance_due END,
      paid_at = CASE WHEN p_status = 'paid' THEN coalesce(paid_at, now()) ELSE paid_at END,
      updated_at = now(),
      updated_by = auth.uid()
  WHERE id = p_invoice_id AND COALESCE(is_deleted,false)=false;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'invoice_not_found';
  END IF;
  RETURN jsonb_build_object('id', p_invoice_id, 'status', p_status);
END;
$$;

-- Deposit invoice + installment from payment-pending application
CREATE OR REPLACE FUNCTION public.admin_create_deposit_from_application(
  p_application_id uuid,
  p_deposit_amount numeric DEFAULT NULL,
  p_installment_count integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_app public.client_property_applications%ROWTYPE;
  v_deposit numeric(16,2);
  v_total numeric(16,2);
  v_client_name text;
  v_inv jsonb;
  v_sched jsonb;
BEGIN
  IF NOT public._finance_can_manage() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT * INTO v_app FROM public.client_property_applications
  WHERE id = p_application_id AND COALESCE(is_deleted,false)=false
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'application_not_found';
  END IF;
  IF v_app.property_id IS NULL THEN
    RAISE EXCEPTION 'property_required';
  END IF;

  v_total := COALESCE(v_app.amount_offered, p_deposit_amount, 0);
  IF v_total <= 0 THEN
    RAISE EXCEPTION 'invalid_amount';
  END IF;
  v_deposit := COALESCE(p_deposit_amount, v_total);
  IF v_deposit <= 0 OR v_deposit > v_total THEN
    v_deposit := v_total;
  END IF;

  SELECT coalesce(
    nullif(trim(concat_ws(' ', p.first_name, p.last_name)), ''),
    p.email,
    c.client_code,
    'Client'
  )
  INTO v_client_name
  FROM public.clients c
  LEFT JOIN public.profiles p ON p.id = c.user_id
  WHERE c.id = v_app.client_id;

  v_inv := public.admin_create_invoice(
    coalesce(v_client_name, 'Client'),
    v_deposit,
    v_app.client_id,
    v_app.property_id,
    CURRENT_DATE + 3,
    'Deposit for application ' || p_application_id::text,
    'client'
  );

  v_sched := public.admin_generate_installments(
    v_app.client_id,
    v_app.property_id,
    v_total,
    v_deposit,
    GREATEST(COALESCE(p_installment_count, 0), 0),
    CURRENT_DATE,
    30,
    coalesce(v_app.payment_plan, 'Application plan'),
    p_application_id
  );

  UPDATE public.client_property_applications
  SET status = 'payment_pending',
      updated_at = now(),
      updated_by = auth.uid(),
      metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
        'deposit_invoice_id', v_inv->>'id',
        'deposit_invoice_number', v_inv->>'invoice_number'
      )
  WHERE id = p_application_id;

  RETURN jsonb_build_object(
    'application_id', p_application_id,
    'invoice', v_inv,
    'schedule', v_sched
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- Expenses create
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_create_expense(
  p_title text,
  p_amount numeric,
  p_vendor_label text DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_id uuid;
  v_code text;
BEGIN
  IF NOT public._finance_can_manage() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF coalesce(trim(p_title), '') = '' THEN
    RAISE EXCEPTION 'title_required';
  END IF;
  IF coalesce(p_amount, 0) <= 0 THEN
    RAISE EXCEPTION 'invalid_amount';
  END IF;

  v_code := 'EXP-' || to_char(timezone('UTC', now()), 'YYYYMMDD') || '-' ||
            upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 5));

  INSERT INTO public.expenses (
    expense_code, title, amount, currency, status, incurred_at,
    vendor_label, submitted_by_label, notes
  ) VALUES (
    v_code, trim(p_title), p_amount, 'NGN', 'pending', CURRENT_DATE,
    p_vendor_label, coalesce((SELECT email FROM auth.users WHERE id = auth.uid()), 'Finance'),
    p_notes
  )
  RETURNING id INTO v_id;

  RETURN jsonb_build_object('id', v_id, 'expense_code', v_code, 'status', 'pending');
END;
$$;

-- ---------------------------------------------------------------------------
-- Investor distributions
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_set_distribution_status(
  p_distribution_id uuid,
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
  IF p_status NOT IN ('scheduled','pending','paid','cancelled') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;
  UPDATE public.investment_distributions
  SET status = p_status,
      paid_at = CASE WHEN p_status = 'paid' THEN coalesce(paid_at, now()) ELSE paid_at END,
      updated_at = now()
  WHERE id = p_distribution_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'distribution_not_found';
  END IF;
  RETURN jsonb_build_object('id', p_distribution_id, 'status', p_status);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_create_distribution(
  p_investor_id uuid,
  p_amount numeric,
  p_distribution_type text DEFAULT 'dividend',
  p_notes text DEFAULT NULL,
  p_scheduled_at timestamptz DEFAULT now()
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_id uuid;
  v_ref text;
BEGIN
  IF NOT public._finance_can_manage() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_investor_id IS NULL THEN
    RAISE EXCEPTION 'investor_required';
  END IF;
  IF coalesce(p_amount, 0) <= 0 THEN
    RAISE EXCEPTION 'invalid_amount';
  END IF;

  v_ref := 'DIST-' || to_char(timezone('UTC', now()), 'YYYYMMDD') || '-' ||
           upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 5));

  INSERT INTO public.investment_distributions (
    investor_id, amount, currency, status, distribution_type,
    scheduled_at, reference, notes
  ) VALUES (
    p_investor_id, p_amount, 'NGN', 'scheduled', coalesce(p_distribution_type, 'dividend'),
    p_scheduled_at, v_ref, p_notes
  )
  RETURNING id INTO v_id;

  RETURN jsonb_build_object('id', v_id, 'reference', v_ref, 'status', 'scheduled');
END;
$$;

-- Confirm investor intent and optionally mark capital note
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
BEGIN
  IF NOT public._finance_can_manage() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_status NOT IN ('confirmed','rejected','cancelled') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;

  SELECT * INTO v_intent FROM public.investor_payment_intents
  WHERE id = p_intent_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'intent_not_found';
  END IF;

  UPDATE public.investor_payment_intents
  SET status = p_status,
      notes = CASE WHEN p_notes IS NULL THEN notes ELSE p_notes END,
      updated_at = now()
  WHERE id = p_intent_id;

  PERFORM public._audit_finance(
    'investor_intent_' || p_status, 'investor_payment_intent', p_intent_id,
    jsonb_build_object('status', v_intent.status),
    jsonb_build_object('status', p_status, 'amount', v_intent.amount)
  );

  RETURN jsonb_build_object('id', p_intent_id, 'status', p_status, 'amount', v_intent.amount);
END;
$$;

-- Payment settings
CREATE OR REPLACE FUNCTION public.admin_update_payment_settings(
  p_allow_partial boolean DEFAULT NULL,
  p_overpayment_policy text DEFAULT NULL,
  p_require_transfer_proof boolean DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_row public.payment_settings%ROWTYPE;
BEGIN
  IF NOT public._finance_can_manage() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.payment_settings
  SET allow_partial_payments = coalesce(p_allow_partial, allow_partial_payments),
      overpayment_policy = coalesce(p_overpayment_policy, overpayment_policy),
      require_transfer_proof = coalesce(p_require_transfer_proof, require_transfer_proof),
      updated_at = now(),
      updated_by = auth.uid()
  WHERE id = (SELECT id FROM public.payment_settings ORDER BY id LIMIT 1)
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    INSERT INTO public.payment_settings (
      allow_partial_payments, overpayment_policy, require_transfer_proof, updated_by
    ) VALUES (
      coalesce(p_allow_partial, false),
      coalesce(p_overpayment_policy, 'reject'),
      coalesce(p_require_transfer_proof, true),
      auth.uid()
    )
    RETURNING * INTO v_row;
  END IF;

  RETURN jsonb_build_object(
    'id', v_row.id,
    'allow_partial_payments', v_row.allow_partial_payments,
    'overpayment_policy', v_row.overpayment_policy,
    'require_transfer_proof', v_row.require_transfer_proof
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public._finance_can_manage() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_generate_installments(uuid, uuid, numeric, numeric, integer, date, integer, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_installment_status(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_create_invoice(text, numeric, uuid, uuid, date, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_invoice_status(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_create_deposit_from_application(uuid, numeric, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_create_expense(text, numeric, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_distribution_status(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_create_distribution(uuid, numeric, text, text, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_confirm_investor_intent(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_payment_settings(boolean, text, boolean) TO authenticated;

-- Realtime for ops tables
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'installments',
    'finance_receipts',
    'payment_charges',
    'investment_distributions',
    'investment_receiving_accounts',
    'payment_settings',
    'client_property_applications'
  ]
  LOOP
    IF EXISTS (
      SELECT 1 FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relname = t AND c.relkind = 'r'
    ) AND NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE %I', t);
    END IF;
  END LOOP;
END $$;
