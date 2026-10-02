-- Link guest calculator applications to a confirmed account that uses the
-- same email, so public visitors, clients, and investors can read replies
-- after they sign in.

CREATE OR REPLACE FUNCTION public.claim_my_calculator_applications()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email text;
  v_confirmed timestamptz;
  v_count integer := 0;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN 0;
  END IF;

  SELECT lower(u.email), u.email_confirmed_at
  INTO v_email, v_confirmed
  FROM auth.users u
  WHERE u.id = auth.uid();

  IF v_email IS NULL OR btrim(v_email) = '' OR v_confirmed IS NULL THEN
    RETURN 0;
  END IF;

  UPDATE public.calculator_applications
  SET user_id = auth.uid(),
      updated_at = now()
  WHERE user_id IS NULL
    AND lower(email) = v_email;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.claim_my_calculator_applications() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.claim_my_calculator_applications() TO authenticated;
