-- Calculator applications: applicants can submit a detailed plan request,
-- read their own rows (status + staff reply), and cannot write staff fields.
-- Direct INSERT ... RETURNING failed for clients because only marketing staff
-- could SELECT the new row (PostgREST 42501).

ALTER TABLE public.calculator_applications
  ADD COLUMN IF NOT EXISTS city TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS preferred_contact TEXT NOT NULL DEFAULT 'phone',
  ADD COLUMN IF NOT EXISTS occupation TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS applicant_message TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS admin_reply TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS replied_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS replied_by UUID;

ALTER TABLE public.calculator_applications
  DROP CONSTRAINT IF EXISTS calculator_applications_contact_chk;
ALTER TABLE public.calculator_applications
  ADD CONSTRAINT calculator_applications_contact_chk
  CHECK (preferred_contact IN ('phone', 'email', 'whatsapp'));

CREATE INDEX IF NOT EXISTS calculator_applications_user_idx
  ON public.calculator_applications (user_id, created_at DESC);

DROP POLICY IF EXISTS calculator_applications_public_insert
  ON public.calculator_applications;
CREATE POLICY calculator_applications_public_insert
  ON public.calculator_applications
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (
    status = 'new'
    AND notes = ''
    AND admin_reply = ''
    AND replied_at IS NULL
    AND replied_by IS NULL
    AND (
      (auth.uid() IS NULL AND user_id IS NULL)
      OR user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS calculator_applications_owner_select
  ON public.calculator_applications;
CREATE POLICY calculator_applications_owner_select
  ON public.calculator_applications
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE OR REPLACE FUNCTION public.submit_calculator_application(
  p_plan_id uuid DEFAULT NULL,
  p_property_id uuid DEFAULT NULL,
  p_full_name text DEFAULT '',
  p_email text DEFAULT '',
  p_phone text DEFAULT '',
  p_city text DEFAULT '',
  p_preferred_contact text DEFAULT 'phone',
  p_occupation text DEFAULT '',
  p_message text DEFAULT '',
  p_property_price numeric DEFAULT 0,
  p_deposit_amount numeric DEFAULT 0,
  p_duration_months integer DEFAULT 0,
  p_interest_rate numeric DEFAULT 0,
  p_loan_amount numeric DEFAULT 0,
  p_monthly_payment numeric DEFAULT 0,
  p_total_repayment numeric DEFAULT 0,
  p_total_interest numeric DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_name text := btrim(COALESCE(p_full_name, ''));
  v_email text := lower(btrim(COALESCE(p_email, '')));
  v_phone text := btrim(COALESCE(p_phone, ''));
  v_city text := btrim(COALESCE(p_city, ''));
  v_contact text := lower(btrim(COALESCE(p_preferred_contact, 'phone')));
  v_occupation text := btrim(COALESCE(p_occupation, ''));
  v_message text := btrim(COALESCE(p_message, ''));
  v_row public.calculator_applications;
BEGIN
  IF char_length(v_name) < 2 OR char_length(v_name) > 120 THEN
    RAISE EXCEPTION 'invalid_name';
  END IF;
  IF v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'
     OR char_length(v_email) > 180 THEN
    RAISE EXCEPTION 'invalid_email';
  END IF;
  IF char_length(v_phone) > 40 THEN
    RAISE EXCEPTION 'invalid_phone';
  END IF;
  IF v_contact NOT IN ('phone', 'email', 'whatsapp') THEN
    v_contact := 'phone';
  END IF;
  IF char_length(v_city) > 80 THEN
    RAISE EXCEPTION 'invalid_city';
  END IF;
  IF char_length(v_occupation) > 120 THEN
    RAISE EXCEPTION 'invalid_occupation';
  END IF;
  IF char_length(v_message) > 2000 THEN
    RAISE EXCEPTION 'invalid_message';
  END IF;
  IF COALESCE(p_property_price, 0) < 0
     OR COALESCE(p_deposit_amount, 0) < 0
     OR COALESCE(p_loan_amount, 0) < 0
     OR COALESCE(p_monthly_payment, 0) < 0
     OR COALESCE(p_total_repayment, 0) < 0
     OR COALESCE(p_total_interest, 0) < 0
     OR COALESCE(p_interest_rate, 0) < 0
     OR COALESCE(p_duration_months, 0) < 1
     OR COALESCE(p_duration_months, 0) > 600 THEN
    RAISE EXCEPTION 'invalid_figures';
  END IF;

  INSERT INTO public.calculator_applications (
    plan_id,
    property_id,
    user_id,
    full_name,
    email,
    phone,
    city,
    preferred_contact,
    occupation,
    applicant_message,
    property_price,
    deposit_amount,
    duration_months,
    interest_rate,
    loan_amount,
    monthly_payment,
    total_repayment,
    total_interest,
    status,
    notes,
    admin_reply
  ) VALUES (
    p_plan_id,
    p_property_id,
    auth.uid(),
    v_name,
    v_email,
    v_phone,
    v_city,
    v_contact,
    v_occupation,
    v_message,
    p_property_price,
    p_deposit_amount,
    p_duration_months,
    p_interest_rate,
    p_loan_amount,
    p_monthly_payment,
    p_total_repayment,
    p_total_interest,
    'new',
    '',
    ''
  )
  RETURNING * INTO v_row;

  RETURN to_jsonb(v_row);
END;
$$;

REVOKE ALL ON FUNCTION public.submit_calculator_application(
  uuid, uuid, text, text, text, text, text, text, text,
  numeric, numeric, integer, numeric, numeric, numeric, numeric, numeric
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_calculator_application(
  uuid, uuid, text, text, text, text, text, text, text,
  numeric, numeric, integer, numeric, numeric, numeric, numeric, numeric
) TO anon, authenticated;
