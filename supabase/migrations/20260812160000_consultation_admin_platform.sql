-- Consultation admin platform: events, staff access, admin RPCs, double-booking protection.

-- Permissions
INSERT INTO public.permissions (slug, name, description, module)
VALUES
  ('consultations.view', 'View Consultations', 'View consultation bookings and analytics', 'consultations'),
  ('consultations.manage', 'Manage Consultations', 'Confirm, assign, reschedule, and cancel consultations', 'consultations'),
  ('consultations.settings', 'Consultation Settings', 'Manage departments, advisors, and availability', 'consultations')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE r.slug IN ('super_admin', 'admin')
  AND p.slug IN ('consultations.view', 'consultations.manage', 'consultations.settings')
ON CONFLICT DO NOTHING;

-- Extend bookings table
ALTER TABLE public.consultation_bookings
  ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS admin_notes text,
  ADD COLUMN IF NOT EXISTS meeting_url text,
  ADD COLUMN IF NOT EXISTS cancelled_at timestamptz,
  ADD COLUMN IF NOT EXISTS confirmed_at timestamptz,
  ADD COLUMN IF NOT EXISTS completed_at timestamptz;

CREATE INDEX IF NOT EXISTS consultation_bookings_user_idx
  ON public.consultation_bookings (user_id);
CREATE INDEX IF NOT EXISTS consultation_bookings_status_idx
  ON public.consultation_bookings (status);
CREATE INDEX IF NOT EXISTS consultation_bookings_advisor_scheduled_idx
  ON public.consultation_bookings (advisor_id, scheduled_at)
  WHERE status NOT IN ('cancelled', 'rejected');

-- Booking audit events
CREATE TABLE IF NOT EXISTS public.consultation_booking_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL REFERENCES public.consultation_bookings(id) ON DELETE CASCADE,
  event_type text NOT NULL,
  actor_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS consultation_booking_events_booking_idx
  ON public.consultation_booking_events (booking_id, created_at DESC);

ALTER TABLE public.consultation_booking_events ENABLE ROW LEVEL SECURITY;

-- Staff read/write on bookings
DROP POLICY IF EXISTS consultation_bookings_staff ON public.consultation_bookings;
CREATE POLICY consultation_bookings_staff
  ON public.consultation_bookings
  FOR ALL
  TO authenticated
  USING (
    public.has_permission('consultations.view', auth.uid())
    OR public.has_permission('consultations.manage', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR user_id = auth.uid()
  )
  WITH CHECK (
    public.has_permission('consultations.manage', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR user_id = auth.uid()
  );

DROP POLICY IF EXISTS consultation_booking_events_staff ON public.consultation_booking_events;
CREATE POLICY consultation_booking_events_staff
  ON public.consultation_booking_events
  FOR SELECT
  TO authenticated
  USING (
    public.has_permission('consultations.view', auth.uid())
    OR public.has_permission('consultations.manage', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.consultation_bookings b
      WHERE b.id = booking_id AND b.user_id = auth.uid()
    )
  );

-- Staff manage departments/advisors
DROP POLICY IF EXISTS consultation_departments_staff ON public.consultation_departments;
CREATE POLICY consultation_departments_staff
  ON public.consultation_departments
  FOR ALL
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

DROP POLICY IF EXISTS consultation_advisors_staff ON public.consultation_advisors;
CREATE POLICY consultation_advisors_staff
  ON public.consultation_advisors
  FOR ALL
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

DROP POLICY IF EXISTS consultation_working_hours_staff ON public.consultation_working_hours;
CREATE POLICY consultation_working_hours_staff
  ON public.consultation_working_hours
  FOR ALL
  TO authenticated
  USING (
    public.has_permission('consultations.settings', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('consultations.settings', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

DROP POLICY IF EXISTS consultation_holidays_staff ON public.consultation_holidays;
CREATE POLICY consultation_holidays_staff
  ON public.consultation_holidays
  FOR ALL
  TO authenticated
  USING (
    public.has_permission('consultations.settings', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('consultations.settings', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

-- Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.consultation_bookings;

-- Helper: log booking event
CREATE OR REPLACE FUNCTION public._log_consultation_event(
  p_booking_id uuid,
  p_event_type text,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.consultation_booking_events (booking_id, event_type, actor_id, metadata)
  VALUES (p_booking_id, p_event_type, auth.uid(), COALESCE(p_metadata, '{}'::jsonb));
END;
$$;

-- Admin status update
CREATE OR REPLACE FUNCTION public.admin_update_consultation_status(
  p_booking_id uuid,
  p_status text,
  p_reason text DEFAULT NULL,
  p_meeting_url text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old text;
  v_uid uuid := auth.uid();
BEGIN
  IF NOT (
    public.has_permission('consultations.manage', v_uid)
    OR public.has_role('super_admin', v_uid)
  ) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF p_status NOT IN (
    'pending','scheduled','confirmed','assigned','in_progress',
    'completed','cancelled','rescheduled','rejected','no_show'
  ) THEN
    RAISE EXCEPTION 'invalid status';
  END IF;

  SELECT status INTO v_old
  FROM public.consultation_bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'booking not found';
  END IF;

  UPDATE public.consultation_bookings
  SET status = p_status,
      meeting_url = COALESCE(p_meeting_url, meeting_url),
      confirmed_at = CASE WHEN p_status = 'confirmed' AND confirmed_at IS NULL THEN now() ELSE confirmed_at END,
      completed_at = CASE WHEN p_status = 'completed' THEN now() ELSE completed_at END,
      cancelled_at = CASE WHEN p_status IN ('cancelled','rejected') THEN now() ELSE cancelled_at END,
      updated_at = now(),
      admin_notes = CASE
        WHEN p_reason IS NOT NULL AND length(trim(p_reason)) > 0
        THEN trim(both E'\n' from concat_ws(E'\n', admin_notes, p_reason))
        ELSE admin_notes
      END
  WHERE id = p_booking_id;

  PERFORM public._log_consultation_event(
    p_booking_id,
    'status_changed',
    jsonb_build_object('from', v_old, 'to', p_status, 'reason', p_reason)
  );

  RETURN jsonb_build_object('ok', true, 'from', v_old, 'to', p_status);
END;
$$;

-- Admin assign advisor
CREATE OR REPLACE FUNCTION public.admin_assign_consultation_advisor(
  p_booking_id uuid,
  p_advisor_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_advisor_name text;
BEGIN
  IF NOT (
    public.has_permission('consultations.manage', v_uid)
    OR public.has_role('super_admin', v_uid)
  ) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT full_name INTO v_advisor_name
  FROM public.consultation_advisors
  WHERE id = p_advisor_id AND is_active = true;

  IF v_advisor_name IS NULL THEN
    RAISE EXCEPTION 'advisor not found';
  END IF;

  UPDATE public.consultation_bookings
  SET advisor_id = p_advisor_id,
      status = CASE WHEN status = 'scheduled' THEN 'assigned' ELSE status END,
      updated_at = now()
  WHERE id = p_booking_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'booking not found';
  END IF;

  PERFORM public._log_consultation_event(
    p_booking_id,
    'advisor_assigned',
    jsonb_build_object('advisor_id', p_advisor_id, 'advisor_name', v_advisor_name)
  );

  RETURN jsonb_build_object('ok', true, 'advisor_name', v_advisor_name);
END;
$$;

-- Admin reschedule
CREATE OR REPLACE FUNCTION public.admin_reschedule_consultation(
  p_booking_id uuid,
  p_scheduled_at timestamptz,
  p_advisor_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_old timestamptz;
  v_advisor uuid;
  v_busy boolean;
BEGIN
  IF NOT (
    public.has_permission('consultations.manage', v_uid)
    OR public.has_role('super_admin', v_uid)
  ) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT scheduled_at, advisor_id INTO v_old, v_advisor
  FROM public.consultation_bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'booking not found';
  END IF;

  v_advisor := COALESCE(p_advisor_id, v_advisor);

  SELECT EXISTS(
    SELECT 1 FROM public.consultation_bookings b
    WHERE b.id <> p_booking_id
      AND b.advisor_id IS NOT DISTINCT FROM v_advisor
      AND b.scheduled_at = p_scheduled_at
      AND b.status NOT IN ('cancelled', 'rejected')
  ) INTO v_busy;

  IF v_busy THEN
    RAISE EXCEPTION 'slot_unavailable';
  END IF;

  UPDATE public.consultation_bookings
  SET scheduled_at = p_scheduled_at,
      advisor_id = v_advisor,
      status = 'rescheduled',
      updated_at = now()
  WHERE id = p_booking_id;

  PERFORM public._log_consultation_event(
    p_booking_id,
    'rescheduled',
    jsonb_build_object('from', v_old, 'to', p_scheduled_at, 'advisor_id', v_advisor)
  );

  RETURN jsonb_build_object('ok', true, 'scheduled_at', p_scheduled_at);
END;
$$;

-- Update book_public_consultation with double-booking protection + event + user_id
CREATE OR REPLACE FUNCTION public.book_public_consultation(
  p_full_name text,
  p_phone text,
  p_email text,
  p_company text DEFAULT NULL,
  p_department_slug text DEFAULT 'sales',
  p_meeting_method text DEFAULT 'video',
  p_scheduled_at timestamptz DEFAULT NULL,
  p_advisor_id uuid DEFAULT NULL,
  p_purpose text DEFAULT NULL,
  p_budget text DEFAULT NULL,
  p_property_reference text DEFAULT NULL,
  p_preferred_estate text DEFAULT NULL,
  p_timeline text DEFAULT NULL,
  p_investment_interest boolean DEFAULT false,
  p_notes text DEFAULT NULL,
  p_document_urls jsonb DEFAULT '[]'::jsonb,
  p_timezone text DEFAULT 'Africa/Lagos',
  p_office_location_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_name text := NULLIF(trim(COALESCE(p_full_name, '')), '');
  v_phone text := NULLIF(trim(COALESCE(p_phone, '')), '');
  v_email text := lower(NULLIF(trim(COALESCE(p_email, '')), ''));
  v_method text := lower(COALESCE(p_meeting_method, 'video'));
  v_when timestamptz := COALESCE(p_scheduled_at, now() + interval '1 day');
  v_ref text;
  v_lead_id uuid;
  v_booking_id uuid;
  v_dept_id uuid;
  v_advisor_id uuid;
  v_duration int := 45;
  v_first text;
  v_last text;
  v_space int;
  v_advisor_name text;
  v_office_name text;
  v_busy boolean;
  v_uid uuid := auth.uid();
BEGIN
  IF v_name IS NULL OR length(v_name) < 2 THEN
    RAISE EXCEPTION 'full name required';
  END IF;
  IF v_phone IS NULL OR length(v_phone) < 7 THEN
    RAISE EXCEPTION 'phone required';
  END IF;
  IF v_email IS NULL OR position('@' in v_email) = 0 THEN
    RAISE EXCEPTION 'valid email required';
  END IF;

  IF v_method NOT IN ('phone', 'video', 'office') THEN
    v_method := 'video';
  END IF;

  IF v_when <= now() THEN
    RAISE EXCEPTION 'cannot book in the past';
  END IF;

  IF p_office_location_id IS NOT NULL THEN
    SELECT name INTO v_office_name
    FROM public.office_locations
    WHERE id = p_office_location_id AND is_deleted = false AND status = 'active'
    LIMIT 1;
  END IF;

  SELECT id, duration_minutes INTO v_dept_id, v_duration
  FROM public.consultation_departments
  WHERE slug = COALESCE(NULLIF(trim(p_department_slug), ''), 'sales')
    AND is_active = true
  LIMIT 1;

  IF v_dept_id IS NULL THEN
    RAISE EXCEPTION 'department unavailable';
  END IF;

  v_advisor_id := p_advisor_id;
  IF v_advisor_id IS NULL THEN
    SELECT id INTO v_advisor_id
    FROM public.consultation_advisors
    WHERE department_id = v_dept_id AND is_active = true
    ORDER BY sort_order, rating DESC
    LIMIT 1;
  END IF;

  IF v_advisor_id IS NOT NULL THEN
    SELECT full_name INTO v_advisor_name
    FROM public.consultation_advisors WHERE id = v_advisor_id AND is_active = true;
    IF v_advisor_name IS NULL THEN
      v_advisor_id := NULL;
    END IF;
  END IF;

  SELECT EXISTS(
    SELECT 1 FROM public.consultation_bookings b
    WHERE b.scheduled_at = v_when
      AND b.status NOT IN ('cancelled', 'rejected')
      AND (
        (v_advisor_id IS NOT NULL AND b.advisor_id = v_advisor_id)
        OR (v_advisor_id IS NULL AND b.department_id = v_dept_id)
      )
  ) INTO v_busy;

  IF v_busy THEN
    RAISE EXCEPTION 'slot_unavailable';
  END IF;

  v_ref := 'CON-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
  v_space := position(' ' in v_name);
  IF v_space > 0 THEN
    v_first := substr(v_name, 1, v_space - 1);
    v_last := substr(v_name, v_space + 1);
  ELSE
    v_first := v_name;
    v_last := '';
  END IF;

  INSERT INTO public.leads (
    first_name, last_name, phone, email, source, status, notes
  ) VALUES (
    v_first, v_last, v_phone, v_email, 'book_consultation', 'new',
    trim(both E'\n' from concat_ws(E'\n',
      'Ref: ' || v_ref,
      'Department: ' || COALESCE(p_department_slug, 'sales'),
      'Meeting: ' || v_method,
      CASE WHEN v_office_name IS NOT NULL THEN 'Office: ' || v_office_name END,
      CASE WHEN v_advisor_name IS NOT NULL THEN 'Advisor: ' || v_advisor_name END,
      CASE WHEN p_company IS NOT NULL THEN 'Company: ' || p_company END,
      CASE WHEN p_purpose IS NOT NULL THEN 'Purpose: ' || p_purpose END,
      CASE WHEN p_budget IS NOT NULL THEN 'Budget: ' || p_budget END,
      CASE WHEN p_property_reference IS NOT NULL THEN 'Property ref: ' || p_property_reference END,
      CASE WHEN p_preferred_estate IS NOT NULL THEN 'Estate: ' || p_preferred_estate END,
      CASE WHEN p_timeline IS NOT NULL THEN 'Timeline: ' || p_timeline END,
      'Investment interest: ' || CASE WHEN p_investment_interest THEN 'yes' ELSE 'no' END,
      CASE WHEN p_notes IS NOT NULL AND length(trim(p_notes)) > 0 THEN 'Notes: ' || trim(p_notes) END,
      'Docs: ' || COALESCE(p_document_urls::text, '[]')
    ))
  )
  RETURNING id INTO v_lead_id;

  INSERT INTO public.consultation_bookings (
    reference, lead_id, department_id, advisor_id, office_location_id, user_id,
    full_name, phone, email, company,
    meeting_method, scheduled_at, duration_minutes, timezone,
    purpose, budget, property_reference, preferred_estate, timeline,
    investment_interest, notes, document_urls, status
  ) VALUES (
    v_ref, v_lead_id, v_dept_id, v_advisor_id, p_office_location_id, v_uid,
    v_name, v_phone, v_email, NULLIF(trim(COALESCE(p_company, '')), ''),
    v_method, v_when, COALESCE(v_duration, 45), COALESCE(p_timezone, 'Africa/Lagos'),
    p_purpose, p_budget, p_property_reference, p_preferred_estate, p_timeline,
    COALESCE(p_investment_interest, false), p_notes, COALESCE(p_document_urls, '[]'::jsonb),
    'scheduled'
  )
  RETURNING id INTO v_booking_id;

  INSERT INTO public.consultation_booking_events (booking_id, event_type, actor_id, metadata)
  VALUES (
    v_booking_id,
    'booking_created',
    v_uid,
    jsonb_build_object(
      'reference', v_ref,
      'department_slug', p_department_slug,
      'meeting_method', v_method,
      'scheduled_at', v_when
    )
  );

  RETURN jsonb_build_object(
    'ok', true,
    'reference', v_ref,
    'booking_id', v_booking_id,
    'lead_id', v_lead_id,
    'advisor_id', v_advisor_id,
    'advisor_name', v_advisor_name,
    'scheduled_at', v_when,
    'duration_minutes', COALESCE(v_duration, 45)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_update_consultation_status(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_assign_consultation_advisor(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reschedule_consultation(uuid, timestamptz, uuid) TO authenticated;
