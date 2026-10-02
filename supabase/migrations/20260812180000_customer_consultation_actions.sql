-- Customer cancel consultation + link guest bookings by email on login helper.

CREATE OR REPLACE FUNCTION public.customer_cancel_consultation(
  p_booking_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_owner uuid;
  v_status text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  SELECT user_id, status INTO v_owner, v_status
  FROM public.consultation_bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'booking not found';
  END IF;

  IF v_owner IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF v_status IN ('cancelled', 'completed', 'rejected', 'no_show') THEN
    RAISE EXCEPTION 'cannot cancel';
  END IF;

  UPDATE public.consultation_bookings
  SET status = 'cancelled',
      cancelled_at = now(),
      updated_at = now()
  WHERE id = p_booking_id;

  PERFORM public._log_consultation_event(
    p_booking_id,
    'cancelled_by_customer',
    jsonb_build_object('actor_id', v_uid)
  );

  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.customer_cancel_consultation(uuid) TO authenticated;

-- Allow customers to claim guest bookings that match their email once.
CREATE OR REPLACE FUNCTION public.claim_my_consultation_bookings()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_email text;
  v_count integer := 0;
BEGIN
  IF v_uid IS NULL THEN
    RETURN 0;
  END IF;

  SELECT lower(email) INTO v_email FROM auth.users WHERE id = v_uid;
  IF v_email IS NULL THEN
    RETURN 0;
  END IF;

  UPDATE public.consultation_bookings
  SET user_id = v_uid,
      updated_at = now()
  WHERE user_id IS NULL
    AND lower(email) = v_email;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.claim_my_consultation_bookings() TO authenticated;
