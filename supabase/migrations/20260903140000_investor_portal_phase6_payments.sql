-- Phase 6 — Investor payments & finance hardening
-- 1) Investor can read receipts for their own payments
-- 2) investor_submit_bank_transfer RPC (confirmation only — never settled)

DROP POLICY IF EXISTS finance_receipts_investor_read ON public.finance_receipts;
CREATE POLICY finance_receipts_investor_read
  ON public.finance_receipts
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.payments p
      WHERE p.id = finance_receipts.payment_id
        AND p.investor_id = public.investor_id_for_user(auth.uid())
        AND COALESCE(p.is_deleted, false) = false
    )
  );

CREATE OR REPLACE FUNCTION public.investor_submit_bank_transfer(
  p_amount numeric,
  p_receiving_account_id uuid DEFAULT NULL,
  p_notes text DEFAULT NULL,
  p_bank_reference text DEFAULT NULL,
  p_holding_id uuid DEFAULT NULL,
  p_transfer_date date DEFAULT NULL,
  p_payer_bank text DEFAULT NULL,
  p_proof jsonb DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_investor_id uuid := public.investor_id_for_user(auth.uid());
  v_ref text;
  v_holding public.portfolio_holdings%ROWTYPE;
  v_portfolio_id uuid;
  v_row public.investor_payment_intents%ROWTYPE;
  v_meta jsonb := '{}'::jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  IF v_investor_id IS NULL THEN
    RAISE EXCEPTION 'investor_not_provisioned';
  END IF;
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'invalid_amount';
  END IF;

  IF p_receiving_account_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.investment_receiving_accounts a
    WHERE a.id = p_receiving_account_id
      AND a.is_active = true
      AND COALESCE(a.is_deleted, false) = false
  ) THEN
    RAISE EXCEPTION 'receiving_account_invalid';
  END IF;

  IF p_holding_id IS NOT NULL THEN
    SELECT ip.id INTO v_portfolio_id
    FROM public.investor_portfolios ip
    WHERE ip.investor_id = v_investor_id
    LIMIT 1;

    SELECT * INTO v_holding
    FROM public.portfolio_holdings h
    WHERE h.id = p_holding_id
      AND h.portfolio_id = v_portfolio_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'holding_not_found';
    END IF;

    v_meta := v_meta || jsonb_build_object(
      'holding_id', v_holding.id,
      'property_id', v_holding.property_id,
      'holding_label', v_holding.label
    );
  END IF;

  IF p_transfer_date IS NOT NULL THEN
    v_meta := v_meta || jsonb_build_object('transfer_date', p_transfer_date);
  END IF;
  IF NULLIF(trim(COALESCE(p_payer_bank, '')), '') IS NOT NULL THEN
    v_meta := v_meta || jsonb_build_object('payer_bank', trim(p_payer_bank));
  END IF;
  IF p_proof IS NOT NULL THEN
    v_meta := v_meta || jsonb_build_object(
      'proof', p_proof,
      'proof_public_id', p_proof->>'public_id',
      'proof_secure_url', p_proof->>'secure_url',
      'proof_resource_type', COALESCE(p_proof->>'resource_type', 'image')
    );
  END IF;

  v_meta := v_meta || jsonb_build_object(
    'submitted_by', auth.uid(),
    'submitted_at', now(),
    'payment_method', 'bank_transfer',
    'verification_status', 'pending_verification'
  );

  v_ref := 'INV-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));

  INSERT INTO public.investor_payment_intents (
    investor_id,
    amount,
    currency,
    provider,
    provider_reference,
    bank_reference,
    receiving_account_id,
    notes,
    metadata,
    status,
    created_by,
    updated_by
  ) VALUES (
    v_investor_id,
    round(p_amount, 2),
    'NGN',
    'bank_transfer',
    v_ref,
    NULLIF(trim(COALESCE(p_bank_reference, '')), ''),
    p_receiving_account_id,
    NULLIF(trim(COALESCE(p_notes, '')), ''),
    v_meta,
    'awaiting_confirmation',
    auth.uid(),
    auth.uid()
  )
  RETURNING * INTO v_row;

  BEGIN
    INSERT INTO public.investor_activity_logs (
      investor_id, event_type, title, description, occurred_at
    ) VALUES (
      v_investor_id,
      'payment',
      'Bank transfer submitted',
      'Payment confirmation ' || v_ref || ' awaiting finance verification',
      now()
    );
  EXCEPTION WHEN others THEN
    NULL;
  END;

  RETURN jsonb_build_object(
    'id', v_row.id,
    'status', v_row.status,
    'amount', v_row.amount,
    'provider_reference', v_row.provider_reference,
    'bank_reference', v_row.bank_reference,
    'metadata', v_row.metadata,
    'created_at', v_row.created_at
  );
END;
$$;

REVOKE ALL ON FUNCTION public.investor_submit_bank_transfer(
  numeric, uuid, text, text, uuid, date, text, jsonb
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.investor_submit_bank_transfer(
  numeric, uuid, text, text, uuid, date, text, jsonb
) TO authenticated;

-- Ensure realtime still covers intents (idempotent)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'investor_payment_intents'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.investor_payment_intents;
  END IF;
END $$;
