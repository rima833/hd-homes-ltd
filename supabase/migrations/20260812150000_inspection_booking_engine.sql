-- Inspection booking engine: availability, agents, settings, slot RPC, CRM hooks.

-- ---------------------------------------------------------------------------
-- Global settings (singleton row)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.inspection_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slot_duration_minutes int NOT NULL DEFAULT 60,
  buffer_minutes int NOT NULL DEFAULT 15,
  min_notice_hours int NOT NULL DEFAULT 24,
  max_booking_days int NOT NULL DEFAULT 60,
  max_daily_inspections int NOT NULL DEFAULT 20,
  max_agent_daily_inspections int NOT NULL DEFAULT 6,
  allow_agent_selection boolean NOT NULL DEFAULT true,
  timezone text NOT NULL DEFAULT 'Africa/Lagos',
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.inspection_settings (slot_duration_minutes, buffer_minutes, min_notice_hours, max_booking_days)
SELECT 60, 15, 24, 60
WHERE NOT EXISTS (SELECT 1 FROM public.inspection_settings LIMIT 1);

-- ---------------------------------------------------------------------------
-- Working hours (0=Mon .. 6=Sun)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.inspection_working_hours (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  weekday int NOT NULL CHECK (weekday BETWEEN 0 AND 6),
  start_time time NOT NULL DEFAULT '09:00',
  end_time time NOT NULL DEFAULT '18:00',
  is_active boolean NOT NULL DEFAULT true,
  UNIQUE (weekday)
);

INSERT INTO public.inspection_working_hours (weekday, start_time, end_time, is_active)
VALUES
  (0, '08:00', '18:00', true),
  (1, '08:00', '18:00', true),
  (2, '08:00', '18:00', true),
  (3, '08:00', '18:00', true),
  (4, '08:00', '18:00', true),
  (5, '09:00', '16:00', true),
  (6, '00:00', '00:00', false)
ON CONFLICT (weekday) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Holidays & blocked dates
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.inspection_holidays (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  holiday_date date NOT NULL UNIQUE,
  name text NOT NULL DEFAULT 'Holiday',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.inspection_blocked_slots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  blocked_at timestamptz NOT NULL,
  reason text NOT NULL DEFAULT 'Blocked',
  estate_id uuid,
  property_id uuid REFERENCES public.properties(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS inspection_blocked_slots_at_idx
  ON public.inspection_blocked_slots (blocked_at);

-- ---------------------------------------------------------------------------
-- Per-property inspection configuration
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.property_inspection_config (
  property_id uuid PRIMARY KEY REFERENCES public.properties(id) ON DELETE CASCADE,
  inspection_enabled boolean NOT NULL DEFAULT true,
  physical_enabled boolean NOT NULL DEFAULT true,
  virtual_enabled boolean NOT NULL DEFAULT true,
  duration_minutes int,
  min_notice_hours int,
  max_daily_inspections int,
  available_weekdays int[] NOT NULL DEFAULT ARRAY[0,1,2,3,4,5],
  special_instructions text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Agent assignment (links sales advisors to estates)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.inspection_agents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  advisor_id uuid NOT NULL REFERENCES public.consultation_advisors(id) ON DELETE CASCADE,
  estate_ids uuid[] NOT NULL DEFAULT '{}',
  max_daily_inspections int NOT NULL DEFAULT 6,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (advisor_id)
);

INSERT INTO public.inspection_agents (advisor_id, max_daily_inspections, is_active)
SELECT a.id, 6, true
FROM public.consultation_advisors a
JOIN public.consultation_departments d ON d.id = a.department_id
WHERE d.slug = 'sales' AND a.is_active = true
ON CONFLICT (advisor_id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Extend property_inspections
-- ---------------------------------------------------------------------------
ALTER TABLE public.property_inspections
  ADD COLUMN IF NOT EXISTS reference text,
  ADD COLUMN IF NOT EXISTS estate_id uuid,
  ADD COLUMN IF NOT EXISTS advisor_id uuid REFERENCES public.consultation_advisors(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS preferred_language text,
  ADD COLUMN IF NOT EXISTS meeting_url text;

CREATE UNIQUE INDEX IF NOT EXISTS property_inspections_reference_unique
  ON public.property_inspections (reference)
  WHERE reference IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS property_inspections_property_slot_unique
  ON public.property_inspections (property_id, scheduled_at)
  WHERE status IN ('scheduled', 'confirmed');

CREATE UNIQUE INDEX IF NOT EXISTS property_inspections_advisor_slot_unique
  ON public.property_inspections (advisor_id, scheduled_at)
  WHERE advisor_id IS NOT NULL AND status IN ('scheduled', 'confirmed');

-- ---------------------------------------------------------------------------
-- Status audit trail
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.inspection_status_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inspection_id uuid NOT NULL REFERENCES public.property_inspections(id) ON DELETE CASCADE,
  from_status text,
  to_status text NOT NULL,
  changed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  reason text,
  changed_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS inspection_status_history_inspection_idx
  ON public.inspection_status_history (inspection_id, changed_at DESC);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.inspection_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inspection_working_hours ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inspection_holidays ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inspection_blocked_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_inspection_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inspection_agents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inspection_status_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS inspection_settings_public_read ON public.inspection_settings;
CREATE POLICY inspection_settings_public_read ON public.inspection_settings
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS inspection_working_hours_public_read ON public.inspection_working_hours;
CREATE POLICY inspection_working_hours_public_read ON public.inspection_working_hours
  FOR SELECT TO anon, authenticated USING (is_active = true);

DROP POLICY IF EXISTS inspection_holidays_public_read ON public.inspection_holidays;
CREATE POLICY inspection_holidays_public_read ON public.inspection_holidays
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS property_inspection_config_public_read ON public.property_inspection_config;
CREATE POLICY property_inspection_config_public_read ON public.property_inspection_config
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS inspection_agents_public_read ON public.inspection_agents;
CREATE POLICY inspection_agents_public_read ON public.inspection_agents
  FOR SELECT TO anon, authenticated USING (is_active = true);

DROP POLICY IF EXISTS inspection_settings_admin ON public.inspection_settings;
CREATE POLICY inspection_settings_admin ON public.inspection_settings
  FOR ALL TO authenticated
  USING (public.has_permission('properties.inspections', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('properties.inspections', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS inspection_working_hours_admin ON public.inspection_working_hours;
CREATE POLICY inspection_working_hours_admin ON public.inspection_working_hours
  FOR ALL TO authenticated
  USING (public.has_permission('properties.inspections', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('properties.inspections', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS inspection_holidays_admin ON public.inspection_holidays;
CREATE POLICY inspection_holidays_admin ON public.inspection_holidays
  FOR ALL TO authenticated
  USING (public.has_permission('properties.inspections', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('properties.inspections', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS inspection_blocked_slots_admin ON public.inspection_blocked_slots;
CREATE POLICY inspection_blocked_slots_admin ON public.inspection_blocked_slots
  FOR ALL TO authenticated
  USING (public.has_permission('properties.inspections', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('properties.inspections', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS property_inspection_config_admin ON public.property_inspection_config;
CREATE POLICY property_inspection_config_admin ON public.property_inspection_config
  FOR ALL TO authenticated
  USING (public.has_permission('properties.inspections', auth.uid()) OR public.has_permission('properties.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('properties.inspections', auth.uid()) OR public.has_permission('properties.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS inspection_agents_admin ON public.inspection_agents;
CREATE POLICY inspection_agents_admin ON public.inspection_agents
  FOR ALL TO authenticated
  USING (public.has_permission('properties.inspections', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('properties.inspections', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS inspection_status_history_admin ON public.inspection_status_history;
CREATE POLICY inspection_status_history_admin ON public.inspection_status_history
  FOR SELECT TO authenticated
  USING (public.has_permission('properties.inspections', auth.uid()) OR public.has_role('super_admin', auth.uid()));

-- Guest read own booking by reference via RPC only; no public table select on bookings.

-- Realtime (property_inspections already in publication from PMS migration)
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.property_inspection_config;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ---------------------------------------------------------------------------
-- Available slots RPC
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_inspection_slots(
  p_from date DEFAULT CURRENT_DATE,
  p_days int DEFAULT 21,
  p_property_id uuid DEFAULT NULL,
  p_estate_id uuid DEFAULT NULL,
  p_advisor_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_day date;
  v_end date;
  v_slots jsonb := '[]'::jsonb;
  v_wh record;
  v_cursor time;
  v_slot_end time;
  v_ts timestamptz;
  v_busy boolean;
  v_holiday boolean;
  v_weekday int;
  v_settings record;
  v_prop_enabled boolean := true;
  v_prop_weekdays int[];
  v_prop_min_notice_hours int;
  v_duration int;
  v_buffer int;
  v_min_notice interval;
  v_max_end date;
  v_tz text := 'Africa/Lagos';
BEGIN
  SELECT * INTO v_settings FROM public.inspection_settings ORDER BY updated_at DESC LIMIT 1;
  v_duration := COALESCE(v_settings.slot_duration_minutes, 60);
  v_buffer := COALESCE(v_settings.buffer_minutes, 15);
  v_min_notice := make_interval(hours => COALESCE(v_settings.min_notice_hours, 24));
  v_max_end := CURRENT_DATE + COALESCE(v_settings.max_booking_days, 60);
  v_tz := COALESCE(v_settings.timezone, 'Africa/Lagos');

  IF p_property_id IS NOT NULL THEN
    SELECT
      COALESCE(pic.inspection_enabled, true),
      pic.available_weekdays,
      pic.duration_minutes,
      pic.min_notice_hours
    INTO v_prop_enabled, v_prop_weekdays, v_duration, v_prop_min_notice_hours
    FROM public.properties p
    LEFT JOIN public.property_inspection_config pic ON pic.property_id = p.id
    WHERE p.id = p_property_id AND p.is_deleted = false AND p.is_published = true;

    IF NOT FOUND THEN
      RETURN '[]'::jsonb;
    END IF;
    IF v_prop_enabled = false THEN
      RETURN '[]'::jsonb;
    END IF;
    IF v_prop_min_notice_hours IS NOT NULL THEN
      v_min_notice := make_interval(hours => v_prop_min_notice_hours);
    END IF;
    IF v_duration IS NULL THEN
      v_duration := COALESCE(v_settings.slot_duration_minutes, 60);
    END IF;
  END IF;

  v_day := GREATEST(p_from, CURRENT_DATE);
  v_end := LEAST(p_from + GREATEST(p_days, 1), v_max_end + 1);

  WHILE v_day < v_end LOOP
    SELECT EXISTS(
      SELECT 1 FROM public.inspection_holidays h WHERE h.holiday_date = v_day
    ) INTO v_holiday;

    v_weekday := ((EXTRACT(DOW FROM v_day)::int + 6) % 7);

    IF NOT v_holiday
       AND (v_prop_weekdays IS NULL OR v_weekday = ANY(v_prop_weekdays))
    THEN
      SELECT * INTO v_wh
      FROM public.inspection_working_hours
      WHERE weekday = v_weekday AND is_active = true
      LIMIT 1;

      IF FOUND AND v_wh.start_time < v_wh.end_time THEN
        v_cursor := v_wh.start_time;
        WHILE v_cursor + make_interval(mins => v_duration) <= v_wh.end_time LOOP
          v_slot_end := v_cursor + make_interval(mins => v_duration);
          v_ts := (v_day::text || ' ' || v_cursor::text)::timestamp AT TIME ZONE v_tz;

          IF v_ts >= now() + v_min_notice THEN
            v_busy := false;

            IF EXISTS (
              SELECT 1 FROM public.inspection_blocked_slots b
              WHERE b.blocked_at = v_ts
                AND (b.property_id IS NULL OR b.property_id = p_property_id)
                AND (b.estate_id IS NULL OR b.estate_id = p_estate_id)
            ) THEN
              v_busy := true;
            END IF;

            IF NOT v_busy AND p_property_id IS NOT NULL AND EXISTS (
              SELECT 1 FROM public.property_inspections pi
              WHERE pi.property_id = p_property_id
                AND pi.scheduled_at = v_ts
                AND pi.status IN ('scheduled', 'confirmed')
            ) THEN
              v_busy := true;
            END IF;

            IF NOT v_busy AND p_advisor_id IS NOT NULL AND EXISTS (
              SELECT 1 FROM public.property_inspections pi
              WHERE pi.advisor_id = p_advisor_id
                AND pi.scheduled_at = v_ts
                AND pi.status IN ('scheduled', 'confirmed')
            ) THEN
              v_busy := true;
            END IF;

            IF NOT v_busy AND p_advisor_id IS NOT NULL THEN
              IF (
                SELECT count(*) FROM public.property_inspections pi
                WHERE pi.advisor_id = p_advisor_id
                  AND pi.scheduled_at::date = v_day
                  AND pi.status IN ('scheduled', 'confirmed')
              ) >= COALESCE(
                (SELECT ia.max_daily_inspections FROM public.inspection_agents ia WHERE ia.advisor_id = p_advisor_id AND ia.is_active),
                v_settings.max_agent_daily_inspections,
                6
              ) THEN
                v_busy := true;
              END IF;
            END IF;

            v_slots := v_slots || jsonb_build_array(jsonb_build_object(
              'date', v_day,
              'time', to_char(v_cursor, 'HH24:MI'),
              'scheduled_at', v_ts,
              'available', NOT v_busy,
              'duration_minutes', v_duration
            ));
          END IF;

          v_cursor := v_slot_end + make_interval(mins => v_buffer);
        END LOOP;
      END IF;
    END IF;

    v_day := v_day + 1;
  END LOOP;

  RETURN v_slots;
END;
$$;

-- ---------------------------------------------------------------------------
-- Enhanced public booking RPC with slot validation + CRM
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.book_public_inspection(
  p_full_name text,
  p_phone text,
  p_email text,
  p_property_id uuid DEFAULT NULL,
  p_estate_id uuid DEFAULT NULL,
  p_scheduled_at timestamptz DEFAULT NULL,
  p_meeting_type text DEFAULT 'site_visit',
  p_advisor_name text DEFAULT NULL,
  p_notes text DEFAULT NULL,
  p_budget text DEFAULT NULL,
  p_timeline text DEFAULT NULL,
  p_financing text DEFAULT NULL,
  p_location text DEFAULT NULL,
  p_property_type text DEFAULT NULL,
  p_purpose text DEFAULT NULL,
  p_investment_interest boolean DEFAULT false,
  p_document_urls jsonb DEFAULT '[]'::jsonb,
  p_advisor_id uuid DEFAULT NULL,
  p_preferred_language text DEFAULT NULL,
  p_visitor_profile_id uuid DEFAULT NULL
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
  v_meeting text := CASE
    WHEN lower(COALESCE(p_meeting_type, '')) IN ('virtual', 'virtual_tour') THEN 'virtual_tour'
    ELSE 'site_visit'
  END;
  v_when timestamptz := p_scheduled_at;
  v_ref text;
  v_inspection_id uuid;
  v_lead_id uuid;
  v_first text;
  v_last text;
  v_space int;
  v_advisor_id uuid := p_advisor_id;
  v_advisor_name text := p_advisor_name;
  v_crm_client_id uuid;
  v_crm_lead_id uuid;
  v_stage_id uuid;
  v_slot jsonb;
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
  IF p_property_id IS NULL THEN
    RAISE EXCEPTION 'property required';
  END IF;
  IF v_when IS NULL THEN
    RAISE EXCEPTION 'schedule required';
  END IF;

  -- Validate slot is still available
  SELECT s INTO v_slot
  FROM jsonb_array_elements(
    public.get_inspection_slots(
      (v_when AT TIME ZONE 'Africa/Lagos')::date,
      1,
      p_property_id,
      p_estate_id,
      v_advisor_id
    )
  ) s
  WHERE (s->>'scheduled_at')::timestamptz = v_when
    AND (s->>'available')::boolean = true
  LIMIT 1;

  IF v_slot IS NULL THEN
    RAISE EXCEPTION 'slot_unavailable: This inspection slot was just booked. Please select another available time.';
  END IF;

  IF v_advisor_id IS NULL THEN
    SELECT a.id, a.full_name INTO v_advisor_id, v_advisor_name
    FROM public.consultation_advisors a
    JOIN public.inspection_agents ia ON ia.advisor_id = a.id AND ia.is_active
    WHERE a.is_active = true
    ORDER BY a.sort_order, a.rating DESC
    LIMIT 1;
  ELSE
    SELECT full_name INTO v_advisor_name
    FROM public.consultation_advisors WHERE id = v_advisor_id;
  END IF;

  v_space := position(' ' in v_name);
  IF v_space > 0 THEN
    v_first := left(v_name, v_space - 1);
    v_last := trim(substr(v_name, v_space + 1));
  ELSE
    v_first := v_name;
    v_last := '';
  END IF;

  v_ref := 'INS-' || to_char(now(), 'YYYY') || '-' ||
           lpad((floor(random() * 900000) + 100000)::int::text, 6, '0');

  INSERT INTO public.leads (
    first_name, last_name, phone, email, source, status, property_id, notes
  ) VALUES (
    v_first, v_last, v_phone, v_email, 'book_inspection', 'new', p_property_id,
    trim(both E'\n' from concat_ws(E'\n',
      'Ref: ' || v_ref,
      CASE WHEN v_advisor_name IS NOT NULL THEN 'Advisor: ' || v_advisor_name END,
      CASE WHEN p_notes IS NOT NULL AND length(trim(p_notes)) > 0 THEN 'Notes: ' || trim(p_notes) END,
      CASE WHEN p_budget IS NOT NULL THEN 'Budget: ' || p_budget END,
      CASE WHEN p_timeline IS NOT NULL THEN 'Timeline: ' || p_timeline END,
      CASE WHEN p_financing IS NOT NULL THEN 'Financing: ' || p_financing END,
      CASE WHEN p_location IS NOT NULL THEN 'Location: ' || p_location END,
      CASE WHEN p_property_type IS NOT NULL THEN 'Property type: ' || p_property_type END,
      CASE WHEN p_purpose IS NOT NULL THEN 'Purpose: ' || p_purpose END,
      'Investment interest: ' || CASE WHEN p_investment_interest THEN 'yes' ELSE 'no' END,
      'Meeting: ' || v_meeting,
      'Language: ' || COALESCE(p_preferred_language, 'English'),
      'Docs: ' || COALESCE(p_document_urls::text, '[]')
    ))
  )
  RETURNING id INTO v_lead_id;

  BEGIN
    INSERT INTO public.property_inspections (
      property_id, estate_id, inspection_type, status, scheduled_at,
      visitor_name, visitor_email, visitor_phone, visitor_profile_id,
      advisor_id, reference, preferred_language, report_payload
    ) VALUES (
      p_property_id, p_estate_id, v_meeting, 'scheduled', v_when,
      v_name, v_email, v_phone, p_visitor_profile_id,
      v_advisor_id, v_ref, COALESCE(p_preferred_language, 'English'),
      jsonb_build_object(
        'reference', v_ref,
        'lead_id', v_lead_id,
        'estate_id', p_estate_id,
        'advisor_id', v_advisor_id,
        'advisor_name', v_advisor_name,
        'notes', p_notes,
        'qualification', jsonb_build_object(
          'budget', p_budget,
          'timeline', p_timeline,
          'financing', p_financing,
          'location', p_location,
          'property_type', p_property_type,
          'purpose', p_purpose,
          'investment_interest', p_investment_interest
        ),
        'document_urls', COALESCE(p_document_urls, '[]'::jsonb),
        'channel', 'public_web',
        'preferred_language', COALESCE(p_preferred_language, 'English')
      )
    )
    RETURNING id INTO v_inspection_id;
  EXCEPTION
    WHEN unique_violation THEN
      RAISE EXCEPTION 'slot_unavailable: This inspection slot was just booked. Please select another available time.';
  END;

  INSERT INTO public.inspection_status_history (
    inspection_id, from_status, to_status, reason
  ) VALUES (v_inspection_id, NULL, 'scheduled', 'Public web booking');

  -- CRM: upsert client + lead + appointment + activity
  SELECT id INTO v_crm_client_id
  FROM public.crm_clients
  WHERE lower(email) = v_email OR phone = v_phone
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_crm_client_id IS NULL THEN
    INSERT INTO public.crm_clients (
      client_code, full_name, email, phone, customer_type, relationship_status, profile_id
    ) VALUES (
      'CL-' || to_char(now(), 'YYYY') || '-' || lpad((floor(random() * 90000) + 10000)::int::text, 5, '0'),
      v_name, v_email, v_phone, 'guest', 'lead', p_visitor_profile_id
    )
    RETURNING id INTO v_crm_client_id;
  END IF;

  SELECT id INTO v_stage_id
  FROM public.crm_pipeline_stages
  WHERE slug IN ('site_visit', 'qualified', 'new')
  ORDER BY CASE slug
    WHEN 'site_visit' THEN 1
    WHEN 'qualified' THEN 2
    ELSE 3
  END
  LIMIT 1;

  INSERT INTO public.crm_leads (
    client_id, stage_id, title, status, notes, estimated_value
  ) VALUES (
    v_crm_client_id,
    v_stage_id,
    'Property inspection — ' || v_ref,
    'open',
    trim(both E'\n' from concat_ws(E'\n',
      'Property ID: ' || p_property_id::text,
      CASE WHEN p_estate_id IS NOT NULL THEN 'Estate ID: ' || p_estate_id::text END,
      'Scheduled: ' || v_when::text,
      CASE WHEN p_budget IS NOT NULL THEN 'Budget: ' || p_budget END
    )),
    NULL
  )
  RETURNING id INTO v_crm_lead_id;

  INSERT INTO public.crm_appointments (
    client_id, appointment_type, title, scheduled_at,
    property_id, status
  ) VALUES (
    v_crm_client_id,
    CASE WHEN v_meeting = 'virtual_tour' THEN 'virtual_tour' ELSE 'site_visit' END,
    'Property inspection — ' || v_ref,
    v_when,
    p_property_id,
    'scheduled'
  );

  INSERT INTO public.crm_activity_logs (
    client_id, event_type, title, description, payload, occurred_at
  ) VALUES (
    v_crm_client_id,
    'inspection_requested',
    'Property Inspection Requested',
    v_name || ' booked an inspection for ' || v_when::text,
    jsonb_build_object(
      'inspection_id', v_inspection_id,
      'reference', v_ref,
      'property_id', p_property_id,
      'lead_id', v_lead_id,
      'crm_lead_id', v_crm_lead_id
    ),
    now()
  );

  RETURN jsonb_build_object(
    'ok', true,
    'reference', v_ref,
    'inspection_id', v_inspection_id,
    'lead_id', v_lead_id,
    'crm_client_id', v_crm_client_id,
    'scheduled_at', v_when,
    'meeting_type', v_meeting,
    'advisor_id', v_advisor_id,
    'advisor_name', v_advisor_name
  );
END;
$$;

-- Admin status update helper
CREATE OR REPLACE FUNCTION public.admin_update_inspection_status(
  p_inspection_id uuid,
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
    public.has_permission('properties.inspections', v_uid)
    OR public.has_role('super_admin', v_uid)
  ) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF p_status NOT IN ('scheduled','confirmed','completed','cancelled','no_show') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;

  SELECT status INTO v_old FROM public.property_inspections WHERE id = p_inspection_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'inspection not found';
  END IF;

  UPDATE public.property_inspections
  SET status = p_status,
      meeting_url = COALESCE(p_meeting_url, meeting_url),
      completed_at = CASE WHEN p_status = 'completed' THEN now() ELSE completed_at END,
      updated_at = now()
  WHERE id = p_inspection_id;

  INSERT INTO public.inspection_status_history (
    inspection_id, from_status, to_status, changed_by, reason
  ) VALUES (p_inspection_id, v_old, p_status, v_uid, p_reason);

  RETURN jsonb_build_object('ok', true, 'from', v_old, 'to', p_status);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_inspection_slots(date, int, uuid, uuid, uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.book_public_inspection(
  text, text, text, uuid, uuid, timestamptz, text, text, text,
  text, text, text, text, text, text, boolean, jsonb, uuid, text, uuid
) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_inspection_status(uuid, text, text, text) TO authenticated;
