-- =============================================================================
-- Client Payment Verification Engine
-- Reuses: payments, installments, client_payment_intents, payment_methods,
--         finance_receipts, receipts storage bucket, audit_logs, notifications
-- Adds: company receiving accounts, charges, late-fee rules, allocations,
--       verification records, secure RPCs for submit/approve/reject
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1) Payment methods — client visibility + recommended default
-- ---------------------------------------------------------------------------
ALTER TABLE public.payment_methods
  ADD COLUMN IF NOT EXISTS client_enabled boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_recommended boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS client_description text;

INSERT INTO public.payment_methods (slug, name, provider, is_active, client_enabled, is_recommended, sort_order, client_description)
VALUES
  ('bank_transfer', 'Bank Transfer', 'manual', true, true, true, 0,
   'Transfer directly to an official HD Homes account and submit your proof for verification.'),
  ('paystack', 'Paystack', 'paystack', true, false, false, 10,
   'Pay online with card or USSD when enabled by Finance.'),
  ('flutterwave', 'Flutterwave', 'flutterwave', true, false, false, 20,
   'Pay online with Flutterwave when enabled by Finance.')
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  is_active = true,
  client_enabled = CASE
    WHEN public.payment_methods.slug = 'bank_transfer' THEN true
    ELSE COALESCE(public.payment_methods.client_enabled, false)
  END,
  is_recommended = (EXCLUDED.slug = 'bank_transfer'),
  sort_order = EXCLUDED.sort_order,
  client_description = COALESCE(EXCLUDED.client_description, public.payment_methods.client_description),
  updated_at = now();

UPDATE public.payment_methods
SET is_recommended = (slug = 'bank_transfer'),
    client_enabled = CASE WHEN slug = 'bank_transfer' THEN true ELSE client_enabled END,
    sort_order = CASE slug
      WHEN 'bank_transfer' THEN 0
      WHEN 'paystack' THEN 10
      WHEN 'flutterwave' THEN 20
      ELSE sort_order
    END,
    updated_at = now()
WHERE slug IN ('bank_transfer', 'paystack', 'flutterwave');

-- ---------------------------------------------------------------------------
-- 2) Company receiving accounts (client-facing official bank details)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.company_receiving_accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_name text NOT NULL,
  bank_name text NOT NULL,
  account_number text NOT NULL,
  currency text NOT NULL DEFAULT 'NGN',
  branch text,
  account_reference text,
  payment_instructions text,
  is_active boolean NOT NULL DEFAULT true,
  is_default boolean NOT NULL DEFAULT false,
  available_for_clients boolean NOT NULL DEFAULT true,
  sort_order int NOT NULL DEFAULT 0,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by uuid REFERENCES auth.users(id),
  updated_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  is_deleted boolean NOT NULL DEFAULT false
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_company_receiving_accounts_default
  ON public.company_receiving_accounts ((is_default))
  WHERE is_default = true AND COALESCE(is_deleted, false) = false AND is_active = true;

CREATE INDEX IF NOT EXISTS idx_company_receiving_accounts_active
  ON public.company_receiving_accounts (is_active, available_for_clients)
  WHERE COALESCE(is_deleted, false) = false;

ALTER TABLE public.company_receiving_accounts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS company_receiving_accounts_client_read ON public.company_receiving_accounts;
CREATE POLICY company_receiving_accounts_client_read
  ON public.company_receiving_accounts
  FOR SELECT TO authenticated
  USING (
    COALESCE(is_deleted, false) = false
    AND is_active = true
    AND available_for_clients = true
  );

DROP POLICY IF EXISTS company_receiving_accounts_finance_all ON public.company_receiving_accounts;
CREATE POLICY company_receiving_accounts_finance_all
  ON public.company_receiving_accounts
  FOR ALL TO authenticated
  USING (
    public.has_permission('manage_payments')
    OR public.has_permission('finance.payments')
    OR public.has_permission('finance.banking')
    OR public.has_permission('finance.write')
    OR public.has_role('super_admin')
  )
  WITH CHECK (
    public.has_permission('manage_payments')
    OR public.has_permission('finance.payments')
    OR public.has_permission('finance.banking')
    OR public.has_permission('finance.write')
    OR public.has_role('super_admin')
  );

INSERT INTO public.company_receiving_accounts (
  account_name, bank_name, account_number, currency, payment_instructions,
  is_active, is_default, available_for_clients, sort_order
)
SELECT
  'HD Homes Limited',
  'Zenith Bank',
  '1212345678',
  'NGN',
  'Use your unique payment reference as the transfer narration. Do not transfer to any other account.',
  true, true, true, 0
WHERE NOT EXISTS (
  SELECT 1 FROM public.company_receiving_accounts
  WHERE COALESCE(is_deleted, false) = false
);

-- ---------------------------------------------------------------------------
-- 3) Installments — authoritative paid / outstanding amounts
-- ---------------------------------------------------------------------------
ALTER TABLE public.installments
  ADD COLUMN IF NOT EXISTS amount_paid numeric(16,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS amount_outstanding numeric(16,2),
  ADD COLUMN IF NOT EXISTS installment_number int;

UPDATE public.installments
SET amount_outstanding = GREATEST(amount - COALESCE(amount_paid, 0), 0)
WHERE amount_outstanding IS NULL;

ALTER TABLE public.installments
  ALTER COLUMN amount_outstanding SET DEFAULT 0;

UPDATE public.installments i
SET amount_paid = i.amount,
    amount_outstanding = 0,
    status = CASE WHEN i.status IN ('paid', 'completed') THEN i.status ELSE 'paid' END
WHERE i.paid_at IS NOT NULL
  AND COALESCE(i.amount_paid, 0) = 0
  AND COALESCE(i.is_deleted, false) = false;

-- ---------------------------------------------------------------------------
-- 4) Charge types + charges + late fee rules
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payment_charge_types (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.payment_charge_types (slug, name, description, sort_order) VALUES
  ('late_payment_fee', 'Late Payment Fee', 'Applied after grace period per Finance rules', 10),
  ('processing_fee', 'Processing Fee', 'Payment processing fee', 20),
  ('documentation_fee', 'Documentation Fee', 'Document preparation fee', 30),
  ('legal_fee', 'Legal Fee', 'Legal / conveyancing fee', 40),
  ('inspection_fee', 'Inspection Fee', 'Property inspection fee', 50),
  ('administrative_fee', 'Administrative Fee', 'Administrative charge', 60),
  ('other', 'Other', 'Other approved charge', 100)
ON CONFLICT (slug) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.late_fee_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  charge_type_slug text NOT NULL DEFAULT 'late_payment_fee'
    REFERENCES public.payment_charge_types(slug),
  calculation_type text NOT NULL
    CHECK (calculation_type IN ('fixed','percentage','daily_fixed','daily_percentage')),
  value numeric(16,4) NOT NULL,
  grace_period_days int NOT NULL DEFAULT 0 CHECK (grace_period_days >= 0),
  maximum_charge numeric(16,2),
  enabled boolean NOT NULL DEFAULT false,
  applies_to text NOT NULL DEFAULT 'installments',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.late_fee_rules (
  name, calculation_type, value, grace_period_days, enabled, applies_to
)
SELECT 'Default fixed late fee (disabled until Finance enables)', 'fixed', 50000, 3, false, 'installments'
WHERE NOT EXISTS (SELECT 1 FROM public.late_fee_rules);

CREATE TABLE IF NOT EXISTS public.payment_charges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  application_id uuid,
  property_id uuid REFERENCES public.properties(id),
  payment_plan_id uuid,
  installment_id uuid REFERENCES public.installments(id),
  payment_id uuid REFERENCES public.payments(id),
  charge_type text NOT NULL REFERENCES public.payment_charge_types(slug),
  description text NOT NULL,
  amount numeric(16,2) NOT NULL CHECK (amount >= 0),
  currency text NOT NULL DEFAULT 'NGN',
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','applied','waived','cancelled','paid')),
  due_date date,
  late_fee_rule_id uuid REFERENCES public.late_fee_rules(id),
  period_key text,
  waiver_reason text,
  created_by uuid REFERENCES auth.users(id),
  approved_by uuid REFERENCES auth.users(id),
  waived_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (installment_id, late_fee_rule_id, period_key)
);

CREATE INDEX IF NOT EXISTS idx_payment_charges_client
  ON public.payment_charges (client_id, status, created_at DESC);

CREATE TABLE IF NOT EXISTS public.payment_allocations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id uuid NOT NULL REFERENCES public.payments(id) ON DELETE CASCADE,
  intent_id uuid REFERENCES public.client_payment_intents(id),
  installment_id uuid REFERENCES public.installments(id),
  charge_id uuid REFERENCES public.payment_charges(id),
  amount numeric(16,2) NOT NULL CHECK (amount > 0),
  allocation_order int NOT NULL DEFAULT 0,
  notes text,
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payment_allocations_payment
  ON public.payment_allocations (payment_id);

-- ---------------------------------------------------------------------------
-- 5) Extend client_payment_intents for bank-transfer verification
-- ---------------------------------------------------------------------------
ALTER TABLE public.client_payment_intents
  ADD COLUMN IF NOT EXISTS payment_reference text,
  ADD COLUMN IF NOT EXISTS receiving_account_id uuid
    REFERENCES public.company_receiving_accounts(id),
  ADD COLUMN IF NOT EXISTS transfer_date date,
  ADD COLUMN IF NOT EXISTS sender_name text,
  ADD COLUMN IF NOT EXISTS sender_bank text,
  ADD COLUMN IF NOT EXISTS transaction_reference text,
  ADD COLUMN IF NOT EXISTS transfer_note text,
  ADD COLUMN IF NOT EXISTS proof_storage_path text,
  ADD COLUMN IF NOT EXISTS payment_id uuid REFERENCES public.payments(id),
  ADD COLUMN IF NOT EXISTS verified_by uuid REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS verified_at timestamptz,
  ADD COLUMN IF NOT EXISTS rejection_reason text,
  ADD COLUMN IF NOT EXISTS info_request_message text,
  ADD COLUMN IF NOT EXISTS submitted_at timestamptz;

CREATE UNIQUE INDEX IF NOT EXISTS uq_client_payment_intents_reference
  ON public.client_payment_intents (payment_reference)
  WHERE payment_reference IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.payment_verifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  intent_id uuid NOT NULL REFERENCES public.client_payment_intents(id) ON DELETE CASCADE,
  payment_id uuid REFERENCES public.payments(id),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','approved','rejected','info_requested')),
  reviewer_id uuid REFERENCES auth.users(id),
  reviewer_notes text,
  decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payment_verifications_intent
  ON public.payment_verifications (intent_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.payment_settings (
  id int PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  allow_partial_payments boolean NOT NULL DEFAULT false,
  overpayment_policy text NOT NULL DEFAULT 'reject'
    CHECK (overpayment_policy IN ('reject','hold_for_review','apply_to_next')),
  require_transfer_proof boolean NOT NULL DEFAULT true,
  max_proof_bytes int NOT NULL DEFAULT 10485760,
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid REFERENCES auth.users(id)
);

INSERT INTO public.payment_settings (id) VALUES (1)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 6) RLS for charges / rules / allocations / settings / verifications
-- ---------------------------------------------------------------------------
ALTER TABLE public.payment_charge_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.late_fee_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_charges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_verifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS payment_charge_types_read ON public.payment_charge_types;
CREATE POLICY payment_charge_types_read ON public.payment_charge_types
  FOR SELECT TO authenticated
  USING (is_active = true OR public.has_permission('finance.payments') OR public.has_role('super_admin'));

DROP POLICY IF EXISTS payment_charge_types_finance ON public.payment_charge_types;
CREATE POLICY payment_charge_types_finance ON public.payment_charge_types
  FOR ALL TO authenticated
  USING (public.has_permission('finance.payments') OR public.has_permission('manage_payments') OR public.has_role('super_admin'))
  WITH CHECK (public.has_permission('finance.payments') OR public.has_permission('manage_payments') OR public.has_role('super_admin'));

DROP POLICY IF EXISTS late_fee_rules_finance ON public.late_fee_rules;
CREATE POLICY late_fee_rules_finance ON public.late_fee_rules
  FOR ALL TO authenticated
  USING (public.has_permission('finance.payments') OR public.has_permission('manage_payments') OR public.has_role('super_admin'))
  WITH CHECK (public.has_permission('finance.payments') OR public.has_permission('manage_payments') OR public.has_role('super_admin'));

DROP POLICY IF EXISTS payment_charges_client_read ON public.payment_charges;
CREATE POLICY payment_charges_client_read ON public.payment_charges
  FOR SELECT TO authenticated
  USING (
    client_id = public.client_id_for_user(auth.uid())
    OR public.has_permission('finance.payments')
    OR public.has_permission('manage_payments')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS payment_charges_finance_write ON public.payment_charges;
CREATE POLICY payment_charges_finance_write ON public.payment_charges
  FOR ALL TO authenticated
  USING (public.has_permission('finance.payments') OR public.has_permission('manage_payments') OR public.has_role('super_admin'))
  WITH CHECK (public.has_permission('finance.payments') OR public.has_permission('manage_payments') OR public.has_role('super_admin'));

DROP POLICY IF EXISTS payment_allocations_read ON public.payment_allocations;
CREATE POLICY payment_allocations_read ON public.payment_allocations
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.payments p
      WHERE p.id = payment_id
        AND (
          p.client_id = public.client_id_for_user(auth.uid())
          OR public.has_permission('finance.payments')
          OR public.has_permission('manage_payments')
          OR public.has_role('super_admin')
        )
    )
  );

DROP POLICY IF EXISTS payment_verifications_finance ON public.payment_verifications;
CREATE POLICY payment_verifications_finance ON public.payment_verifications
  FOR ALL TO authenticated
  USING (public.has_permission('finance.payments') OR public.has_permission('manage_payments') OR public.has_role('super_admin'))
  WITH CHECK (public.has_permission('finance.payments') OR public.has_permission('manage_payments') OR public.has_role('super_admin'));

DROP POLICY IF EXISTS payment_verifications_client_read ON public.payment_verifications;
CREATE POLICY payment_verifications_client_read ON public.payment_verifications
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.client_payment_intents i
      WHERE i.id = intent_id
        AND i.client_id = public.client_id_for_user(auth.uid())
    )
  );

DROP POLICY IF EXISTS payment_settings_read ON public.payment_settings;
CREATE POLICY payment_settings_read ON public.payment_settings
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS payment_settings_finance ON public.payment_settings;
CREATE POLICY payment_settings_finance ON public.payment_settings
  FOR ALL TO authenticated
  USING (public.has_permission('finance.payments') OR public.has_permission('manage_payments') OR public.has_role('super_admin'))
  WITH CHECK (public.has_permission('finance.payments') OR public.has_permission('manage_payments') OR public.has_role('super_admin'));

-- Client methods catalog (read active/client_enabled)
DROP POLICY IF EXISTS payment_methods_client_read ON public.payment_methods;
CREATE POLICY payment_methods_client_read ON public.payment_methods
  FOR SELECT TO authenticated
  USING (is_active = true OR public.has_permission('finance.payments') OR public.has_role('super_admin'));

-- Finance receipts: allow client to read own via payment link
DROP POLICY IF EXISTS finance_receipts_client_read ON public.finance_receipts;
CREATE POLICY finance_receipts_client_read ON public.finance_receipts
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.payments p
      WHERE p.id = finance_receipts.payment_id
        AND p.client_id = public.client_id_for_user(auth.uid())
        AND COALESCE(p.is_deleted, false) = false
    )
    OR public.has_permission('finance.payments')
    OR public.has_permission('manage_payments')
    OR public.has_role('super_admin')
  );

-- ---------------------------------------------------------------------------
-- 7) Helpers
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_client_payment_reference()
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  ref text;
BEGIN
  LOOP
    ref := 'HDH-PAY-' || to_char(timezone('UTC', now()), 'YYYYMMDD') || '-' ||
           upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM public.client_payment_intents WHERE payment_reference = ref
    );
  END LOOP;
  RETURN ref;
END;
$$;

CREATE OR REPLACE FUNCTION public._finance_can_verify()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.has_permission('manage_payments')
      OR public.has_permission('finance.payments')
      OR public.has_permission('finance.write')
      OR public.has_role('super_admin');
$$;

CREATE OR REPLACE FUNCTION public._notify_user(
  p_user_id uuid,
  p_title text,
  p_body text,
  p_type text DEFAULT 'payment',
  p_data jsonb DEFAULT '{}'::jsonb
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_user_id IS NULL THEN
    RETURN;
  END IF;
  BEGIN
    INSERT INTO public.notifications (
      user_id, title, body, type, category, metadata, is_read, channel, status
    ) VALUES (
      p_user_id, p_title, p_body, p_type, 'payment', p_data, false, 'in_app', 'active'
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;
END;
$$;

CREATE OR REPLACE FUNCTION public._audit_finance(
  p_action text,
  p_entity text,
  p_entity_id uuid,
  p_old jsonb DEFAULT NULL,
  p_new jsonb DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  BEGIN
    INSERT INTO public.audit_logs (
      user_id, action, module, entity_type, entity_id,
      old_values, new_values, metadata, status
    ) VALUES (
      auth.uid(), p_action, 'finance', p_entity, p_entity_id::text,
      p_old, p_new, p_metadata, 'active'
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;
END;
$$;

-- ---------------------------------------------------------------------------
-- 8) Authoritative client payment summary (source of truth)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.client_payment_summary(p_client_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_client_id uuid;
  v_outstanding numeric(16,2);
  v_total_paid numeric(16,2);
  v_pending_verification numeric(16,2);
  v_charges_outstanding numeric(16,2);
  v_property_value numeric(16,2);
  v_next jsonb;
BEGIN
  v_client_id := COALESCE(p_client_id, public.client_id_for_user(auth.uid()));
  IF v_client_id IS NULL THEN
    RAISE EXCEPTION 'client_not_found';
  END IF;
  IF v_client_id <> public.client_id_for_user(auth.uid())
     AND NOT public._finance_can_verify()
     AND NOT public.is_staff() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT COALESCE(SUM(GREATEST(COALESCE(amount_outstanding, amount - COALESCE(amount_paid,0), amount), 0)), 0)
    INTO v_outstanding
  FROM public.installments
  WHERE client_id = v_client_id
    AND COALESCE(is_deleted, false) = false
    AND status NOT IN ('paid', 'completed', 'cancelled', 'waived');

  SELECT COALESCE(SUM(amount), 0) INTO v_total_paid
  FROM public.payments
  WHERE client_id = v_client_id
    AND COALESCE(is_deleted, false) = false
    AND status IN ('completed', 'paid', 'succeeded', 'success');

  SELECT COALESCE(SUM(amount), 0) INTO v_pending_verification
  FROM public.client_payment_intents
  WHERE client_id = v_client_id
    AND COALESCE(is_deleted, false) = false
    AND status IN ('pending_verification', 'info_requested');

  SELECT COALESCE(SUM(amount), 0) INTO v_charges_outstanding
  FROM public.payment_charges
  WHERE client_id = v_client_id
    AND status IN ('pending', 'applied');

  SELECT COALESCE(SUM(COALESCE((p.listing_price)::numeric, 0)), 0) INTO v_property_value
  FROM public.client_properties cp
  JOIN public.properties p ON p.id = cp.property_id
  WHERE cp.client_id = v_client_id
    AND COALESCE(cp.is_deleted, false) = false;

  SELECT jsonb_build_object(
    'installment_id', i.id,
    'property_id', i.property_id,
    'property_title', pr.title,
    'amount', i.amount,
    'amount_outstanding', GREATEST(COALESCE(i.amount_outstanding, i.amount - COALESCE(i.amount_paid,0), i.amount), 0),
    'due_date', i.due_date,
    'status', i.status
  )
  INTO v_next
  FROM public.installments i
  LEFT JOIN public.properties pr ON pr.id = i.property_id
  WHERE i.client_id = v_client_id
    AND COALESCE(i.is_deleted, false) = false
    AND i.status NOT IN ('paid', 'completed', 'cancelled', 'waived')
  ORDER BY i.due_date ASC
  LIMIT 1;

  RETURN jsonb_build_object(
    'client_id', v_client_id,
    'currency', 'NGN',
    'property_value', v_property_value,
    'total_paid', v_total_paid,
    'outstanding', v_outstanding,
    'charges_outstanding', v_charges_outstanding,
    'pending_verification', v_pending_verification,
    'total_payable', v_outstanding + v_charges_outstanding,
    'next_payment', v_next
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.client_payment_summary(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 9) Submit bank transfer (client) — NEVER marks completed
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.submit_client_bank_transfer(
  p_property_id uuid,
  p_installment_id uuid,
  p_amount numeric,
  p_transfer_date date,
  p_sender_name text,
  p_sender_bank text,
  p_transaction_reference text,
  p_transfer_note text DEFAULT NULL,
  p_proof_storage_path text DEFAULT NULL,
  p_receiving_account_id uuid DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_client_id uuid;
  v_user_id uuid := auth.uid();
  v_settings public.payment_settings%ROWTYPE;
  v_method public.payment_methods%ROWTYPE;
  v_account public.company_receiving_accounts%ROWTYPE;
  v_installment public.installments%ROWTYPE;
  v_due numeric(16,2);
  v_charges numeric(16,2);
  v_max numeric(16,2);
  v_ref text;
  v_intent_id uuid;
  v_verification_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  v_client_id := public.client_id_for_user(v_user_id);
  IF v_client_id IS NULL THEN
    RAISE EXCEPTION 'client_not_found';
  END IF;

  SELECT * INTO v_settings FROM public.payment_settings WHERE id = 1;
  SELECT * INTO v_method FROM public.payment_methods
  WHERE slug = 'bank_transfer' AND is_active AND client_enabled
  LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'payment_method_unavailable';
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'invalid_amount';
  END IF;

  IF p_transfer_date IS NULL OR p_transfer_date > CURRENT_DATE + 1 THEN
    RAISE EXCEPTION 'invalid_transfer_date';
  END IF;

  IF coalesce(trim(p_sender_name), '') = '' OR coalesce(trim(p_sender_bank), '') = '' THEN
    RAISE EXCEPTION 'sender_required';
  END IF;

  IF coalesce(trim(p_transaction_reference), '') = '' THEN
    RAISE EXCEPTION 'transaction_reference_required';
  END IF;

  IF v_settings.require_transfer_proof AND coalesce(trim(p_proof_storage_path), '') = '' THEN
    RAISE EXCEPTION 'proof_required';
  END IF;

  -- receiving account
  IF p_receiving_account_id IS NOT NULL THEN
    SELECT * INTO v_account FROM public.company_receiving_accounts
    WHERE id = p_receiving_account_id
      AND is_active AND available_for_clients AND COALESCE(is_deleted,false)=false;
  ELSE
    SELECT * INTO v_account FROM public.company_receiving_accounts
    WHERE is_active AND available_for_clients AND COALESCE(is_deleted,false)=false
    ORDER BY is_default DESC, sort_order ASC
    LIMIT 1;
  END IF;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'no_receiving_account';
  END IF;

  IF p_installment_id IS NOT NULL THEN
    SELECT * INTO v_installment FROM public.installments
    WHERE id = p_installment_id
      AND client_id = v_client_id
      AND COALESCE(is_deleted,false)=false;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'installment_not_found';
    END IF;
    IF v_installment.status IN ('paid','completed','cancelled') THEN
      RAISE EXCEPTION 'installment_not_payable';
    END IF;
    v_due := GREATEST(COALESCE(v_installment.amount_outstanding,
              v_installment.amount - COALESCE(v_installment.amount_paid,0),
              v_installment.amount), 0);
  ELSE
    v_due := p_amount;
  END IF;

  SELECT COALESCE(SUM(amount),0) INTO v_charges
  FROM public.payment_charges
  WHERE client_id = v_client_id
    AND status IN ('pending','applied')
    AND (p_installment_id IS NULL OR installment_id = p_installment_id OR installment_id IS NULL);

  v_max := v_due + v_charges;

  IF p_amount < v_due AND NOT v_settings.allow_partial_payments THEN
    RAISE EXCEPTION 'partial_payments_disabled';
  END IF;

  IF p_amount > v_max THEN
    IF v_settings.overpayment_policy = 'reject' THEN
      RAISE EXCEPTION 'overpayment_not_allowed';
    END IF;
  END IF;

  -- property must belong to client when provided
  IF p_property_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.client_properties
    WHERE client_id = v_client_id AND property_id = p_property_id
      AND COALESCE(is_deleted,false)=false
  ) AND NOT EXISTS (
    SELECT 1 FROM public.installments
    WHERE client_id = v_client_id AND property_id = p_property_id
      AND COALESCE(is_deleted,false)=false
  ) THEN
    RAISE EXCEPTION 'property_not_owned';
  END IF;

  v_ref := public.generate_client_payment_reference();

  INSERT INTO public.client_payment_intents (
    client_id, property_id, installment_id, amount, currency, provider,
    provider_reference, payment_reference, receiving_account_id,
    transfer_date, sender_name, sender_bank, transaction_reference,
    transfer_note, proof_storage_path, bank_reference, status,
    submitted_at, created_by, updated_by, metadata
  ) VALUES (
    v_client_id, p_property_id, p_installment_id, p_amount, 'NGN', 'bank_transfer',
    v_ref, v_ref, v_account.id,
    p_transfer_date, trim(p_sender_name), trim(p_sender_bank), trim(p_transaction_reference),
    nullif(trim(p_transfer_note), ''), nullif(trim(p_proof_storage_path), ''),
    trim(p_transaction_reference), 'pending_verification',
    now(), v_user_id, v_user_id,
    jsonb_build_object(
      'receiving_account_snapshot', jsonb_build_object(
        'id', v_account.id,
        'bank_name', v_account.bank_name,
        'account_name', v_account.account_name,
        'account_number', v_account.account_number,
        'currency', v_account.currency
      )
    )
  )
  RETURNING id INTO v_intent_id;

  INSERT INTO public.payment_verifications (intent_id, status)
  VALUES (v_intent_id, 'pending')
  RETURNING id INTO v_verification_id;

  PERFORM public._audit_finance(
    'payment_submitted', 'client_payment_intent', v_intent_id, NULL,
    jsonb_build_object('amount', p_amount, 'reference', v_ref, 'status', 'pending_verification'),
    jsonb_build_object('verification_id', v_verification_id)
  );

  PERFORM public._notify_user(
    v_user_id,
    'Payment submitted',
    'Your payment ' || v_ref || ' was submitted and is awaiting Finance verification.',
    'payment',
    jsonb_build_object('intent_id', v_intent_id, 'payment_reference', v_ref, 'status', 'pending_verification')
  );

  RETURN jsonb_build_object(
    'intent_id', v_intent_id,
    'verification_id', v_verification_id,
    'payment_reference', v_ref,
    'amount', p_amount,
    'status', 'pending_verification',
    'receiving_account_id', v_account.id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_client_bank_transfer(
  uuid, uuid, numeric, date, text, text, text, text, text, uuid
) TO authenticated;

-- ---------------------------------------------------------------------------
-- 10) Approve bank transfer (Finance) — transactional completion
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.approve_client_payment_intent(
  p_intent_id uuid,
  p_reviewer_notes text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_intent public.client_payment_intents%ROWTYPE;
  v_payment_id uuid;
  v_receipt_id uuid;
  v_receipt_no text;
  v_alloc_remaining numeric(16,2);
  v_charge record;
  v_inst public.installments%ROWTYPE;
  v_client_user uuid;
  v_paid numeric(16,2);
  v_outstanding numeric(16,2);
  v_new_status text;
BEGIN
  IF NOT public._finance_can_verify() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT * INTO v_intent FROM public.client_payment_intents
  WHERE id = p_intent_id AND COALESCE(is_deleted,false)=false
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'intent_not_found';
  END IF;
  IF v_intent.status NOT IN ('pending_verification', 'info_requested') THEN
    RAISE EXCEPTION 'intent_not_pending';
  END IF;
  IF v_intent.payment_id IS NOT NULL THEN
    -- idempotent
    RETURN jsonb_build_object(
      'payment_id', v_intent.payment_id,
      'intent_id', v_intent.id,
      'status', 'completed',
      'idempotent', true
    );
  END IF;

  INSERT INTO public.payments (
    client_id, property_id, amount, currency, payment_method, payment_provider,
    provider_reference, paid_at, status, notes, metadata, created_by, updated_by,
    bank_account_id
  ) VALUES (
    v_intent.client_id, v_intent.property_id, v_intent.amount, COALESCE(v_intent.currency,'NGN'),
    'bank_transfer', 'manual', v_intent.payment_reference, now(), 'completed',
    p_reviewer_notes,
    jsonb_build_object(
      'intent_id', v_intent.id,
      'transaction_reference', v_intent.transaction_reference,
      'sender_name', v_intent.sender_name,
      'sender_bank', v_intent.sender_bank,
      'transfer_date', v_intent.transfer_date
    ),
    auth.uid(), auth.uid(), NULL
  )
  RETURNING id INTO v_payment_id;

  v_alloc_remaining := v_intent.amount;

  -- allocate to applied/pending charges first
  FOR v_charge IN
    SELECT * FROM public.payment_charges
    WHERE client_id = v_intent.client_id
      AND status IN ('pending','applied')
      AND (v_intent.installment_id IS NULL OR installment_id = v_intent.installment_id OR installment_id IS NULL)
    ORDER BY
      CASE WHEN charge_type = 'late_payment_fee' THEN 0 ELSE 1 END,
      created_at ASC
  LOOP
    EXIT WHEN v_alloc_remaining <= 0;
    IF v_charge.amount <= v_alloc_remaining THEN
      INSERT INTO public.payment_allocations (payment_id, intent_id, charge_id, amount, allocation_order, created_by)
      VALUES (v_payment_id, v_intent.id, v_charge.id, v_charge.amount, 1, auth.uid());
      UPDATE public.payment_charges
      SET status = 'paid', payment_id = v_payment_id, updated_at = now()
      WHERE id = v_charge.id;
      v_alloc_remaining := v_alloc_remaining - v_charge.amount;
    END IF;
  END LOOP;

  -- allocate remainder to installment
  IF v_intent.installment_id IS NOT NULL AND v_alloc_remaining > 0 THEN
    SELECT * INTO v_inst FROM public.installments WHERE id = v_intent.installment_id FOR UPDATE;
    IF FOUND THEN
      INSERT INTO public.payment_allocations (payment_id, intent_id, installment_id, amount, allocation_order, created_by)
      VALUES (v_payment_id, v_intent.id, v_inst.id, v_alloc_remaining, 2, auth.uid());

      v_paid := COALESCE(v_inst.amount_paid, 0) + v_alloc_remaining;
      v_outstanding := GREATEST(v_inst.amount - v_paid, 0);
      IF v_outstanding <= 0 THEN
        v_new_status := 'paid';
      ELSIF v_paid > 0 THEN
        v_new_status := 'partially_paid';
      ELSE
        v_new_status := v_inst.status;
      END IF;

      UPDATE public.installments
      SET amount_paid = v_paid,
          amount_outstanding = v_outstanding,
          status = v_new_status,
          paid_at = CASE WHEN v_outstanding <= 0 THEN now() ELSE paid_at END,
          updated_at = now(),
          updated_by = auth.uid()
      WHERE id = v_inst.id;
    END IF;
  END IF;

  v_receipt_no := 'HDH-RCPT-' || to_char(timezone('UTC', now()), 'YYYYMMDD') || '-' ||
                  upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));

  INSERT INTO public.finance_receipts (
    receipt_number, payment_id, amount, currency, issued_at,
    payer_label, method_label, notes, metadata
  ) VALUES (
    v_receipt_no, v_payment_id, v_intent.amount, COALESCE(v_intent.currency,'NGN'), now(),
    v_intent.sender_name, 'Bank Transfer', p_reviewer_notes,
    jsonb_build_object('payment_reference', v_intent.payment_reference, 'intent_id', v_intent.id)
  )
  RETURNING id INTO v_receipt_id;

  UPDATE public.payments
  SET finance_receipt_id = v_receipt_id, updated_at = now()
  WHERE id = v_payment_id;

  UPDATE public.client_payment_intents
  SET status = 'completed',
      payment_id = v_payment_id,
      verified_by = auth.uid(),
      verified_at = now(),
      paid_at = now(),
      updated_at = now(),
      updated_by = auth.uid()
  WHERE id = v_intent.id;

  UPDATE public.payment_verifications
  SET status = 'approved',
      reviewer_id = auth.uid(),
      reviewer_notes = p_reviewer_notes,
      decided_at = now(),
      payment_id = v_payment_id,
      updated_at = now()
  WHERE intent_id = v_intent.id AND status IN ('pending', 'info_requested');

  SELECT user_id INTO v_client_user FROM public.clients WHERE id = v_intent.client_id;
  PERFORM public._notify_user(
    v_client_user,
    'Payment verified',
    'Payment ' || COALESCE(v_intent.payment_reference, '') || ' has been verified. Receipt ' || v_receipt_no || ' is available.',
    'payment',
    jsonb_build_object(
      'intent_id', v_intent.id,
      'payment_id', v_payment_id,
      'receipt_number', v_receipt_no,
      'status', 'completed'
    )
  );

  PERFORM public._audit_finance(
    'payment_approved', 'client_payment_intent', v_intent.id,
    jsonb_build_object('status', v_intent.status),
    jsonb_build_object('status', 'completed', 'payment_id', v_payment_id, 'receipt_id', v_receipt_id),
    jsonb_build_object('notes', p_reviewer_notes)
  );

  RETURN jsonb_build_object(
    'intent_id', v_intent.id,
    'payment_id', v_payment_id,
    'receipt_id', v_receipt_id,
    'receipt_number', v_receipt_no,
    'status', 'completed'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.approve_client_payment_intent(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.reject_client_payment_intent(
  p_intent_id uuid,
  p_reason text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_intent public.client_payment_intents%ROWTYPE;
  v_client_user uuid;
BEGIN
  IF NOT public._finance_can_verify() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF coalesce(trim(p_reason), '') = '' THEN
    RAISE EXCEPTION 'reason_required';
  END IF;

  SELECT * INTO v_intent FROM public.client_payment_intents
  WHERE id = p_intent_id AND COALESCE(is_deleted,false)=false
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'intent_not_found';
  END IF;
  IF v_intent.status NOT IN ('pending_verification', 'info_requested') THEN
    RAISE EXCEPTION 'intent_not_pending';
  END IF;

  UPDATE public.client_payment_intents
  SET status = 'rejected',
      rejection_reason = trim(p_reason),
      verified_by = auth.uid(),
      verified_at = now(),
      updated_at = now(),
      updated_by = auth.uid()
  WHERE id = v_intent.id;

  UPDATE public.payment_verifications
  SET status = 'rejected',
      reviewer_id = auth.uid(),
      reviewer_notes = trim(p_reason),
      decided_at = now(),
      updated_at = now()
  WHERE intent_id = v_intent.id AND status IN ('pending', 'info_requested');

  SELECT user_id INTO v_client_user FROM public.clients WHERE id = v_intent.client_id;
  PERFORM public._notify_user(
    v_client_user,
    'Payment rejected',
    'Payment ' || COALESCE(v_intent.payment_reference, '') || ' was rejected: ' || trim(p_reason),
    'payment',
    jsonb_build_object('intent_id', v_intent.id, 'status', 'rejected')
  );

  PERFORM public._audit_finance(
    'payment_rejected', 'client_payment_intent', v_intent.id,
    jsonb_build_object('status', v_intent.status),
    jsonb_build_object('status', 'rejected', 'reason', trim(p_reason))
  );

  RETURN jsonb_build_object('intent_id', v_intent.id, 'status', 'rejected');
END;
$$;

GRANT EXECUTE ON FUNCTION public.reject_client_payment_intent(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.request_client_payment_info(
  p_intent_id uuid,
  p_message text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_intent public.client_payment_intents%ROWTYPE;
  v_client_user uuid;
BEGIN
  IF NOT public._finance_can_verify() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF coalesce(trim(p_message), '') = '' THEN
    RAISE EXCEPTION 'message_required';
  END IF;

  SELECT * INTO v_intent FROM public.client_payment_intents
  WHERE id = p_intent_id AND COALESCE(is_deleted,false)=false
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'intent_not_found';
  END IF;

  UPDATE public.client_payment_intents
  SET status = 'info_requested',
      info_request_message = trim(p_message),
      updated_at = now(),
      updated_by = auth.uid()
  WHERE id = v_intent.id;

  UPDATE public.payment_verifications
  SET status = 'info_requested',
      reviewer_id = auth.uid(),
      reviewer_notes = trim(p_message),
      updated_at = now()
  WHERE intent_id = v_intent.id AND status = 'pending';

  SELECT user_id INTO v_client_user FROM public.clients WHERE id = v_intent.client_id;
  PERFORM public._notify_user(
    v_client_user,
    'More information needed',
    trim(p_message),
    'payment',
    jsonb_build_object('intent_id', v_intent.id, 'status', 'info_requested')
  );

  PERFORM public._audit_finance(
    'payment_info_requested', 'client_payment_intent', v_intent.id,
    NULL, jsonb_build_object('message', trim(p_message))
  );

  RETURN jsonb_build_object('intent_id', v_intent.id, 'status', 'info_requested');
END;
$$;

GRANT EXECUTE ON FUNCTION public.request_client_payment_info(uuid, text) TO authenticated;

-- ---------------------------------------------------------------------------
-- 11) Late fee engine (server-side, rule-driven, idempotent)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.apply_overdue_late_fees(p_as_of date DEFAULT CURRENT_DATE)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rule public.late_fee_rules%ROWTYPE;
  v_inst record;
  v_amount numeric(16,2);
  v_period text;
  v_applied int := 0;
  v_client_user uuid;
BEGIN
  IF NOT public._finance_can_verify() AND auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT * INTO v_rule FROM public.late_fee_rules
  WHERE enabled = true
  ORDER BY created_at ASC
  LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('applied', 0, 'reason', 'no_enabled_rule');
  END IF;

  FOR v_inst IN
    SELECT i.*
    FROM public.installments i
    WHERE COALESCE(i.is_deleted,false)=false
      AND i.status NOT IN ('paid','completed','cancelled','waived')
      AND i.due_date + make_interval(days => v_rule.grace_period_days) < p_as_of
  LOOP
    v_period := to_char(v_inst.due_date, 'YYYY-MM-DD') || ':' || v_rule.id::text;
    IF EXISTS (
      SELECT 1 FROM public.payment_charges
      WHERE installment_id = v_inst.id
        AND late_fee_rule_id = v_rule.id
        AND period_key = v_period
    ) THEN
      CONTINUE;
    END IF;

    v_amount := CASE v_rule.calculation_type
      WHEN 'fixed' THEN v_rule.value
      WHEN 'percentage' THEN round(v_inst.amount * (v_rule.value / 100.0), 2)
      WHEN 'daily_fixed' THEN v_rule.value * GREATEST(
        (p_as_of - (v_inst.due_date + v_rule.grace_period_days)), 1)
      WHEN 'daily_percentage' THEN round(
        v_inst.amount * (v_rule.value / 100.0) *
        GREATEST((p_as_of - (v_inst.due_date + v_rule.grace_period_days)), 1), 2)
      ELSE v_rule.value
    END;

    IF v_rule.maximum_charge IS NOT NULL THEN
      v_amount := LEAST(v_amount, v_rule.maximum_charge);
    END IF;

    INSERT INTO public.payment_charges (
      client_id, property_id, installment_id, charge_type, description,
      amount, currency, status, due_date, late_fee_rule_id, period_key, created_by
    ) VALUES (
      v_inst.client_id, v_inst.property_id, v_inst.id, v_rule.charge_type_slug,
      v_rule.name, v_amount, 'NGN', 'applied', p_as_of, v_rule.id, v_period, auth.uid()
    );

    UPDATE public.installments
    SET status = 'overdue', updated_at = now()
    WHERE id = v_inst.id AND status NOT IN ('paid','completed','cancelled');

    SELECT user_id INTO v_client_user FROM public.clients WHERE id = v_inst.client_id;
    PERFORM public._notify_user(
      v_client_user,
      'Late charge applied',
      'A late payment charge of ₦' || v_amount::text || ' was applied to an overdue installment.',
      'payment',
      jsonb_build_object('installment_id', v_inst.id, 'amount', v_amount)
    );

    PERFORM public._audit_finance(
      'charge_applied', 'payment_charge', v_inst.id,
      NULL, jsonb_build_object('amount', v_amount, 'rule_id', v_rule.id, 'period_key', v_period)
    );

    v_applied := v_applied + 1;
  END LOOP;

  RETURN jsonb_build_object('applied', v_applied, 'rule_id', v_rule.id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.apply_overdue_late_fees(date) TO authenticated;

-- ---------------------------------------------------------------------------
-- 12) Storage bucket for payment proofs (private)
-- ---------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'payment-proofs',
  'payment-proofs',
  false,
  10485760,
  ARRAY['application/pdf','image/jpeg','image/png','image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  public = false,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS payment_proofs_client_upload ON storage.objects;
CREATE POLICY payment_proofs_client_upload ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'payment-proofs'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS payment_proofs_client_read ON storage.objects;
CREATE POLICY payment_proofs_client_read ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'payment-proofs'
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR public._finance_can_verify()
    )
  );

DROP POLICY IF EXISTS payment_proofs_finance_read ON storage.objects;
CREATE POLICY payment_proofs_finance_read ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'payment-proofs' AND public._finance_can_verify());

-- ---------------------------------------------------------------------------
-- 13) Realtime publication
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.client_payment_intents;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.payment_verifications;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.payment_charges;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.installments;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.payments;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.finance_receipts;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

NOTIFY pgrst, 'reload schema';
