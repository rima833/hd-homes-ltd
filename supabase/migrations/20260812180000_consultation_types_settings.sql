-- Consultation types, settings, admin notes, customer cancel.

DROP FUNCTION IF EXISTS public.claim_my_consultation_bookings();

CREATE TABLE IF NOT EXISTS public.consultation_types (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  department_id uuid REFERENCES public.consultation_departments(id) ON DELETE SET NULL,
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  description text NOT NULL DEFAULT '',
  duration_minutes int NOT NULL DEFAULT 45 CHECK (duration_minutes > 0),
  price_amount numeric(12,2) NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'NGN',
  meeting_methods text[] NOT NULL DEFAULT ARRAY['phone','video','office'],
  is_active boolean NOT NULL DEFAULT true,
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS consultation_types_department_idx
  ON public.consultation_types (department_id, sort_order);

ALTER TABLE public.consultation_bookings
  ADD COLUMN IF NOT EXISTS consultation_type_id uuid
    REFERENCES public.consultation_types(id) ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS public.consultation_settings (
  id int PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  default_duration_minutes int NOT NULL DEFAULT 45,
  booking_notice_hours int NOT NULL DEFAULT 2,
  max_booking_window_days int NOT NULL DEFAULT 60,
  cancellation_notice_hours int NOT NULL DEFAULT 12,
  reschedule_notice_hours int NOT NULL DEFAULT 12,
  timezone text NOT NULL DEFAULT 'Africa/Lagos',
  default_meeting_method text NOT NULL DEFAULT 'video',
  email_confirmation_enabled boolean NOT NULL DEFAULT false,
  reminder_hours_before int NOT NULL DEFAULT 24,
  confirmation_message text NOT NULL DEFAULT
    'Your private consultation has been successfully booked.',
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.consultation_settings (id)
VALUES (1)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.consultation_types (
  department_id, slug, name, description, duration_minutes, sort_order
)
SELECT
  d.id,
  d.slug || '-general',
  d.name || ' Consultation',
  COALESCE(NULLIF(d.description, ''), 'Private consultation with HD Homes specialists.'),
  COALESCE(d.duration_minutes, 45),
  d.sort_order
FROM public.consultation_departments d
WHERE d.is_active = true
  AND NOT EXISTS (
    SELECT 1 FROM public.consultation_types t WHERE t.slug = d.slug || '-general'
  );

ALTER TABLE public.consultation_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consultation_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS consultation_types_public_read ON public.consultation_types;
CREATE POLICY consultation_types_public_read
  ON public.consultation_types FOR SELECT
  TO anon, authenticated
  USING (is_active = true);

DROP POLICY IF EXISTS consultation_types_staff ON public.consultation_types;
CREATE POLICY consultation_types_staff
  ON public.consultation_types FOR ALL
  TO authenticated
  USING (
    public.has_permission('consultations.settings', auth.uid())
    OR public.has_permission('consultations.manage', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('consultations.settings', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

DROP POLICY IF EXISTS consultation_settings_public_read ON public.consultation_settings;
CREATE POLICY consultation_settings_public_read
  ON public.consultation_settings FOR SELECT
  TO anon, authenticated
  USING (true);

DROP POLICY IF EXISTS consultation_settings_staff ON public.consultation_settings;
CREATE POLICY consultation_settings_staff
  ON public.consultation_settings FOR ALL
  TO authenticated
  USING (
    public.has_permission('consultations.settings', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('consultations.settings', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

CREATE OR REPLACE FUNCTION public.admin_add_consultation_note(
  p_booking_id uuid,
  p_note text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_note text := NULLIF(trim(COALESCE(p_note, '')), '');
BEGIN
  IF NOT (
    public.has_permission('consultations.manage', v_uid)
    OR public.has_role('super_admin', v_uid)
  ) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF v_note IS NULL THEN
    RAISE EXCEPTION 'note required';
  END IF;

  UPDATE public.consultation_bookings
  SET admin_notes = CASE
        WHEN admin_notes IS NULL OR length(trim(admin_notes)) = 0 THEN v_note
        ELSE admin_notes || E'\n---\n' || v_note
      END,
      updated_at = now()
  WHERE id = p_booking_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'booking not found';
  END IF;

  PERFORM public._log_consultation_event(
    p_booking_id,
    'admin_note_added',
    jsonb_build_object('note', v_note)
  );

  RETURN jsonb_build_object('ok', true);
END;
$$;

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
  v_when timestamptz;
  v_notice int;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;

  SELECT user_id, status, scheduled_at
  INTO v_owner, v_status, v_when
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

  SELECT cancellation_notice_hours INTO v_notice
  FROM public.consultation_settings WHERE id = 1;
  v_notice := COALESCE(v_notice, 12);

  IF v_when <= now() + make_interval(hours => v_notice) THEN
    RAISE EXCEPTION 'cancellation_window_closed';
  END IF;

  UPDATE public.consultation_bookings
  SET status = 'cancelled',
      cancelled_at = now(),
      updated_at = now()
  WHERE id = p_booking_id;

  PERFORM public._log_consultation_event(
    p_booking_id,
    'cancelled_by_customer',
    jsonb_build_object('user_id', v_uid)
  );

  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE FUNCTION public.claim_my_consultation_bookings()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_email text;
  v_count int := 0;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'claimed', 0);
  END IF;

  SELECT lower(email) INTO v_email FROM auth.users WHERE id = v_uid;
  IF v_email IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'claimed', 0);
  END IF;

  UPDATE public.consultation_bookings
  SET user_id = v_uid, updated_at = now()
  WHERE user_id IS NULL
    AND lower(email) = v_email;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'claimed', v_count);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_add_consultation_note(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.customer_cancel_consultation(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_my_consultation_bookings() TO authenticated;

DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.consultation_types;
  EXCEPTION WHEN duplicate_object THEN
    NULL;
  END;
END $$;
