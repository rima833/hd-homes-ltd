-- Finance live ops hardening: waive charges, realtime gaps, investor wallet publication.

CREATE OR REPLACE FUNCTION public.waive_payment_charge(
  p_charge_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_charge public.payment_charges%ROWTYPE;
BEGIN
  IF NOT public._finance_can_manage() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF coalesce(trim(p_reason), '') = '' THEN
    RAISE EXCEPTION 'reason_required';
  END IF;

  SELECT * INTO v_charge
  FROM public.payment_charges
  WHERE id = p_charge_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'charge_not_found';
  END IF;

  IF v_charge.status NOT IN ('pending', 'applied') THEN
    RAISE EXCEPTION 'charge_not_waivable';
  END IF;

  UPDATE public.payment_charges
  SET status = 'waived',
      waiver_reason = trim(p_reason),
      waived_by = auth.uid(),
      updated_at = now()
  WHERE id = p_charge_id;

  PERFORM public._audit_finance(
    'charge_waived',
    'payment_charge',
    p_charge_id,
    jsonb_build_object('status', v_charge.status, 'amount', v_charge.amount),
    jsonb_build_object('status', 'waived', 'reason', trim(p_reason))
  );

  RETURN jsonb_build_object(
    'id', p_charge_id,
    'status', 'waived',
    'amount', v_charge.amount
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.waive_payment_charge(uuid, text) TO authenticated;

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'payment_methods',
    'late_fee_rules',
    'payment_settings',
    'investor_wallets',
    'investor_payment_intents'
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
