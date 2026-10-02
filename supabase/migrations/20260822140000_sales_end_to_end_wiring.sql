-- Sales end-to-end wiring: public CRM lead RPC + consultation dual-write + sources

INSERT INTO public.crm_lead_sources (slug, name, description) VALUES
  ('inspection', 'Inspection Request', 'Public property inspection interest'),
  ('consultation', 'Consultation', 'Public consultation booking'),
  ('callback', 'Callback Request', 'Phone callback from website'),
  ('legal', 'Legal Inquiry', 'Trust and compliance inquiries'),
  ('partnership', 'Partnership', 'Business partnership requests'),
  ('careers', 'Careers', 'Career applications from website'),
  ('support', 'Support', 'Support tickets from website')
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  is_active = true,
  updated_at = now();

ALTER TABLE public.consultation_bookings
  ADD COLUMN IF NOT EXISTS crm_client_id uuid REFERENCES public.crm_clients(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_consultation_bookings_crm_client
  ON public.consultation_bookings (crm_client_id);

-- Generic public website lead → CRM (legal, orphan forms, express interest)
CREATE OR REPLACE FUNCTION public.upsert_crm_public_lead(
  p_full_name text,
  p_phone text,
  p_email text DEFAULT NULL,
  p_title text DEFAULT NULL,
  p_notes text DEFAULT NULL,
  p_source_slug text DEFAULT 'website',
  p_property_id uuid DEFAULT NULL,
  p_preferred_location text DEFAULT NULL,
  p_interest_summary text DEFAULT NULL,
  p_priority text DEFAULT 'medium',
  p_estimated_value numeric DEFAULT NULL,
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
  v_crm_client_id uuid;
  v_crm_lead_id uuid;
  v_source_id uuid;
  v_stage_id uuid;
  v_priority text := CASE
    WHEN lower(COALESCE(p_priority, 'medium')) IN ('urgent', 'high') THEN 'high'
    WHEN lower(COALESCE(p_priority, 'medium')) = 'low' THEN 'low'
    ELSE 'medium'
  END;
  v_title text;
BEGIN
  IF v_name IS NULL OR length(v_name) < 2 THEN
    RAISE EXCEPTION 'full name required';
  END IF;
  IF v_phone IS NULL OR length(v_phone) < 7 THEN
    RAISE EXCEPTION 'phone required';
  END IF;

  SELECT id INTO v_source_id
  FROM public.crm_lead_sources
  WHERE slug = COALESCE(NULLIF(trim(p_source_slug), ''), 'website')
    AND is_active = true
  LIMIT 1;

  IF v_source_id IS NULL THEN
    SELECT id INTO v_source_id
    FROM public.crm_lead_sources
    WHERE slug = 'website'
    LIMIT 1;
  END IF;

  SELECT id INTO v_crm_client_id
  FROM public.crm_clients
  WHERE (v_email IS NOT NULL AND lower(email) = v_email) OR phone = v_phone
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_crm_client_id IS NULL THEN
    INSERT INTO public.crm_clients (
      client_code, full_name, email, phone, customer_type, relationship_status, profile_id
    ) VALUES (
      'CL-' || to_char(now(), 'YYYY') || '-' ||
        lpad((floor(random() * 90000) + 10000)::int::text, 5, '0'),
      v_name, v_email, v_phone, 'guest', 'lead', p_visitor_profile_id
    )
    RETURNING id INTO v_crm_client_id;
  ELSE
    UPDATE public.crm_clients SET
      full_name = v_name,
      email = COALESCE(v_email, email),
      updated_at = now()
    WHERE id = v_crm_client_id;
  END IF;

  SELECT id INTO v_stage_id
  FROM public.crm_pipeline_stages
  WHERE slug = 'new' AND is_active = true
  LIMIT 1;

  v_title := COALESCE(NULLIF(trim(p_title), ''), 'Website enquiry — ' || v_name);

  INSERT INTO public.crm_leads (
    client_id, source_id, stage_id, title, status, priority,
    notes, estimated_value, property_id, preferred_location, interest_summary
  ) VALUES (
    v_crm_client_id, v_source_id, v_stage_id, v_title, 'open', v_priority,
    p_notes, p_estimated_value, p_property_id, p_preferred_location, p_interest_summary
  )
  RETURNING id INTO v_crm_lead_id;

  INSERT INTO public.crm_activity_logs (
    client_id, event_type, title, description, payload, occurred_at
  ) VALUES (
    v_crm_client_id,
    'public_lead_captured',
    'Public lead captured',
    v_name || ' submitted via ' || COALESCE(p_source_slug, 'website'),
    jsonb_build_object(
      'crm_lead_id', v_crm_lead_id,
      'source_slug', p_source_slug,
      'property_id', p_property_id
    ),
    now()
  );

  RETURN jsonb_build_object(
    'ok', true,
    'crm_client_id', v_crm_client_id,
    'crm_lead_id', v_crm_lead_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.upsert_crm_public_lead(
  text, text, text, text, text, text, uuid, text, text, text, numeric, uuid
) TO anon, authenticated;

-- Consultation booking → CRM dual-write (mirrors inspection/callback pattern)
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
  v_crm_client_id uuid;
  v_crm_lead_id uuid;
  v_stage_id uuid;
  v_source_id uuid;
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
    FROM public.consultation_advisors
    WHERE id = v_advisor_id AND is_active = true;
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

  -- CRM upsert
  SELECT id INTO v_crm_client_id
  FROM public.crm_clients
  WHERE (v_email IS NOT NULL AND lower(email) = v_email) OR phone = v_phone
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_crm_client_id IS NULL THEN
    INSERT INTO public.crm_clients (
      client_code, full_name, email, phone, customer_type, relationship_status, profile_id
    ) VALUES (
      'CL-' || to_char(now(), 'YYYY') || '-' ||
        lpad((floor(random() * 90000) + 10000)::int::text, 5, '0'),
      v_name, v_email, v_phone, 'guest', 'lead', v_uid
    )
    RETURNING id INTO v_crm_client_id;
  END IF;

  SELECT id INTO v_source_id
  FROM public.crm_lead_sources WHERE slug = 'consultation' LIMIT 1;

  SELECT id INTO v_stage_id
  FROM public.crm_pipeline_stages
  WHERE slug IN ('qualified', 'contacted', 'new')
  ORDER BY CASE slug WHEN 'qualified' THEN 1 WHEN 'contacted' THEN 2 ELSE 3 END
  LIMIT 1;

  INSERT INTO public.crm_leads (
    client_id, source_id, stage_id, title, status, notes, preferred_location, interest_summary
  ) VALUES (
    v_crm_client_id,
    v_source_id,
    v_stage_id,
    'Consultation — ' || v_ref,
    'open',
    trim(both E'\n' from concat_ws(E'\n',
      CASE WHEN p_purpose IS NOT NULL THEN 'Purpose: ' || p_purpose END,
      CASE WHEN p_budget IS NOT NULL THEN 'Budget: ' || p_budget END,
      CASE WHEN p_preferred_estate IS NOT NULL THEN 'Estate: ' || p_preferred_estate END,
      CASE WHEN p_timeline IS NOT NULL THEN 'Timeline: ' || p_timeline END,
      'Scheduled: ' || v_when::text
    )),
    p_preferred_estate,
    p_purpose
  )
  RETURNING id INTO v_crm_lead_id;

  INSERT INTO public.consultation_bookings (
    reference, lead_id, department_id, advisor_id, office_location_id, user_id,
    full_name, phone, email, company,
    meeting_method, scheduled_at, duration_minutes, timezone,
    purpose, budget, property_reference, preferred_estate, timeline,
    investment_interest, notes, document_urls, status, crm_client_id
  ) VALUES (
    v_ref, v_lead_id, v_dept_id, v_advisor_id, p_office_location_id, v_uid,
    v_name, v_phone, v_email, NULLIF(trim(COALESCE(p_company, '')), ''),
    v_method, v_when, COALESCE(v_duration, 45), COALESCE(p_timezone, 'Africa/Lagos'),
    p_purpose, p_budget, p_property_reference, p_preferred_estate, p_timeline,
    COALESCE(p_investment_interest, false), p_notes, COALESCE(p_document_urls, '[]'::jsonb),
    'scheduled', v_crm_client_id
  )
  RETURNING id INTO v_booking_id;

  INSERT INTO public.crm_appointments (
    client_id, appointment_type, title, scheduled_at, status
  ) VALUES (
    v_crm_client_id,
    CASE WHEN v_method = 'office' THEN 'office_meeting' ELSE 'consultation' END,
    'Consultation — ' || v_ref,
    v_when,
    'scheduled'
  );

  INSERT INTO public.crm_activity_logs (
    client_id, event_type, title, description, payload, occurred_at
  ) VALUES (
    v_crm_client_id,
    'consultation_booked',
    'Consultation Booked',
    v_name || ' booked consultation ' || v_ref || ' for ' || v_when::text,
    jsonb_build_object(
      'booking_id', v_booking_id,
      'reference', v_ref,
      'lead_id', v_lead_id,
      'crm_lead_id', v_crm_lead_id,
      'department_slug', p_department_slug
    ),
    now()
  );

  INSERT INTO public.consultation_booking_events (booking_id, event_type, actor_id, metadata)
  VALUES (
    v_booking_id,
    'booking_created',
    v_uid,
    jsonb_build_object(
      'reference', v_ref,
      'department_slug', p_department_slug,
      'meeting_method', v_method,
      'scheduled_at', v_when,
      'crm_client_id', v_crm_client_id,
      'crm_lead_id', v_crm_lead_id
    )
  );

  RETURN jsonb_build_object(
    'ok', true,
    'reference', v_ref,
    'booking_id', v_booking_id,
    'lead_id', v_lead_id,
    'crm_client_id', v_crm_client_id,
    'crm_lead_id', v_crm_lead_id,
    'advisor_id', v_advisor_id,
    'advisor_name', v_advisor_name,
    'scheduled_at', v_when,
    'duration_minutes', COALESCE(v_duration, 45)
  );
END;
$$;
