-- Public consultation booking: departments, advisors, holidays, bookings + RPCs.

CREATE TABLE IF NOT EXISTS public.consultation_departments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  description text NOT NULL DEFAULT '',
  icon_name text NOT NULL DEFAULT 'headset',
  response_time_label text NOT NULL DEFAULT '< 15 min',
  advisor_count int NOT NULL DEFAULT 1,
  duration_minutes int NOT NULL DEFAULT 45,
  sort_order int NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.consultation_advisors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  department_id uuid REFERENCES public.consultation_departments(id) ON DELETE SET NULL,
  full_name text NOT NULL,
  title text NOT NULL DEFAULT 'Property Consultant',
  photo_url text,
  phone text,
  whatsapp text,
  email text,
  experience_years int NOT NULL DEFAULT 5,
  languages text[] NOT NULL DEFAULT ARRAY['English'],
  rating numeric(3,2) NOT NULL DEFAULT 4.90,
  review_count int NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.consultation_holidays (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  holiday_date date NOT NULL UNIQUE,
  name text NOT NULL DEFAULT 'Holiday',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.consultation_working_hours (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  weekday int NOT NULL CHECK (weekday BETWEEN 0 AND 6), -- 0=Mon .. 6=Sun
  start_time time NOT NULL DEFAULT '09:00',
  end_time time NOT NULL DEFAULT '17:00',
  slot_minutes int NOT NULL DEFAULT 45,
  is_active boolean NOT NULL DEFAULT true,
  UNIQUE (weekday)
);

CREATE TABLE IF NOT EXISTS public.consultation_bookings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference text NOT NULL UNIQUE,
  lead_id uuid REFERENCES public.leads(id) ON DELETE SET NULL,
  department_id uuid REFERENCES public.consultation_departments(id) ON DELETE SET NULL,
  advisor_id uuid REFERENCES public.consultation_advisors(id) ON DELETE SET NULL,
  full_name text NOT NULL,
  phone text NOT NULL,
  email text NOT NULL,
  company text,
  meeting_method text NOT NULL DEFAULT 'video',
  scheduled_at timestamptz NOT NULL,
  duration_minutes int NOT NULL DEFAULT 45,
  timezone text NOT NULL DEFAULT 'Africa/Lagos',
  purpose text,
  budget text,
  property_reference text,
  preferred_estate text,
  timeline text,
  investment_interest boolean NOT NULL DEFAULT false,
  notes text,
  document_urls jsonb NOT NULL DEFAULT '[]'::jsonb,
  status text NOT NULL DEFAULT 'scheduled',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS consultation_bookings_scheduled_idx
  ON public.consultation_bookings (scheduled_at);
CREATE INDEX IF NOT EXISTS consultation_bookings_department_idx
  ON public.consultation_bookings (department_id);
CREATE INDEX IF NOT EXISTS consultation_advisors_department_idx
  ON public.consultation_advisors (department_id);

ALTER TABLE public.consultation_departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consultation_advisors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consultation_holidays ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consultation_working_hours ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consultation_bookings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS consultation_departments_public_read ON public.consultation_departments;
CREATE POLICY consultation_departments_public_read
  ON public.consultation_departments FOR SELECT
  TO anon, authenticated
  USING (is_active = true);

DROP POLICY IF EXISTS consultation_advisors_public_read ON public.consultation_advisors;
CREATE POLICY consultation_advisors_public_read
  ON public.consultation_advisors FOR SELECT
  TO anon, authenticated
  USING (is_active = true);

DROP POLICY IF EXISTS consultation_holidays_public_read ON public.consultation_holidays;
CREATE POLICY consultation_holidays_public_read
  ON public.consultation_holidays FOR SELECT
  TO anon, authenticated
  USING (true);

DROP POLICY IF EXISTS consultation_working_hours_public_read ON public.consultation_working_hours;
CREATE POLICY consultation_working_hours_public_read
  ON public.consultation_working_hours FOR SELECT
  TO anon, authenticated
  USING (is_active = true);

-- Bookings: no public select; insert only via SECURITY DEFINER RPC.

INSERT INTO public.consultation_departments (slug, name, description, icon_name, response_time_label, advisor_count, duration_minutes, sort_order)
VALUES
  ('sales', 'Sales', 'Property purchase guidance from senior consultants.', 'headset', 'Immediate', 12, 45, 1),
  ('investment', 'Investment', 'ROI strategy, portfolios, and wealth planning.', 'trending-up', '< 15 min', 8, 45, 2),
  ('legal', 'Legal', 'Title, contracts, and documentation advisory.', 'scale', '< 30 min', 5, 60, 3),
  ('construction', 'Construction', 'Build progress, quality, and site briefings.', 'hard-hat', '< 1 hr', 6, 45, 4),
  ('architecture', 'Architecture', 'Floor plans, concepts, and design reviews.', 'compass', '< 2 hr', 4, 60, 5),
  ('mortgage', 'Mortgage', 'Financing options and payment structures.', 'landmark', '< 30 min', 5, 45, 6),
  ('customer-support', 'Customer Support', 'After-sales care and account assistance.', 'life-buoy', 'Immediate', 10, 30, 7),
  ('partnership', 'Partnership', 'Joint ventures and strategic alliances.', 'handshake', '< 1 day', 3, 60, 8)
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  response_time_label = EXCLUDED.response_time_label,
  icon_name = EXCLUDED.icon_name,
  advisor_count = EXCLUDED.advisor_count,
  duration_minutes = EXCLUDED.duration_minutes,
  sort_order = EXCLUDED.sort_order,
  is_active = true,
  updated_at = now();

INSERT INTO public.consultation_working_hours (weekday, start_time, end_time, slot_minutes, is_active)
VALUES
  (0, '09:00', '17:00', 45, true),
  (1, '09:00', '17:00', 45, true),
  (2, '09:00', '17:00', 45, true),
  (3, '09:00', '17:00', 45, true),
  (4, '09:00', '17:00', 45, true),
  (5, '10:00', '14:00', 45, true),
  (6, '00:00', '00:00', 45, false)
ON CONFLICT (weekday) DO NOTHING;

INSERT INTO public.consultation_advisors (
  department_id, full_name, title, phone, whatsapp, email,
  experience_years, languages, rating, review_count, sort_order
)
SELECT d.id, v.full_name, v.title, v.phone, v.whatsapp, v.email,
       v.experience_years, v.languages, v.rating, v.review_count, v.sort_order
FROM (VALUES
  ('sales', 'David Okafor', 'Senior Property Consultant', '+2348012345678', '+2348012345678', 'david@hdhomes.ng', 8, ARRAY['English','Yoruba']::text[], 4.90, 128, 1),
  ('investment', 'Amaka Nwosu', 'Investment Specialist', '+2348098765432', '+2348098765432', 'amaka@hdhomes.ng', 10, ARRAY['English','Igbo']::text[], 4.95, 96, 1),
  ('legal', 'Chidi Eze', 'Legal Counsel', '+2348087654321', '+2348087654321', 'chidi@hdhomes.ng', 12, ARRAY['English']::text[], 4.85, 74, 1),
  ('construction', 'Kemi Adeyemi', 'Construction Liaison', '+2348076543210', '+2348076543210', 'kemi@hdhomes.ng', 7, ARRAY['English','Yoruba']::text[], 4.80, 61, 1),
  ('architecture', 'Tunde Bakare', 'Design Consultant', '+2348065432109', '+2348065432109', 'tunde@hdhomes.ng', 9, ARRAY['English']::text[], 4.88, 52, 1),
  ('mortgage', 'Grace Okonkwo', 'Mortgage Advisor', '+2348054321098', '+2348054321098', 'grace@hdhomes.ng', 6, ARRAY['English','Igbo']::text[], 4.82, 45, 1),
  ('customer-support', 'Fatima Bello', 'Client Success Manager', '+2348043210987', '+2348043210987', 'fatima@hdhomes.ng', 5, ARRAY['English','Hausa']::text[], 4.91, 210, 1),
  ('partnership', 'Ibrahim Musa', 'Partnerships Lead', '+2348032109876', '+2348032109876', 'ibrahim@hdhomes.ng', 11, ARRAY['English','Hausa']::text[], 4.87, 38, 1)
) AS v(slug, full_name, title, phone, whatsapp, email, experience_years, languages, rating, review_count, sort_order)
JOIN public.consultation_departments d ON d.slug = v.slug
WHERE NOT EXISTS (
  SELECT 1 FROM public.consultation_advisors a
  WHERE a.full_name = v.full_name AND a.department_id = d.id
);

CREATE OR REPLACE FUNCTION public.get_consultation_slots(
  p_from date DEFAULT CURRENT_DATE,
  p_days int DEFAULT 14,
  p_department_id uuid DEFAULT NULL
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
  v_duration int := 45;
BEGIN
  IF p_department_id IS NOT NULL THEN
    SELECT duration_minutes INTO v_duration
    FROM public.consultation_departments WHERE id = p_department_id;
    v_duration := COALESCE(v_duration, 45);
  END IF;

  v_day := p_from;
  v_end := p_from + GREATEST(p_days, 1);

  WHILE v_day < v_end LOOP
    SELECT EXISTS(
      SELECT 1 FROM public.consultation_holidays h WHERE h.holiday_date = v_day
    ) INTO v_holiday;

    -- Map Postgres DOW (0=Sun) to our weekday (0=Mon)
    v_weekday := ((EXTRACT(DOW FROM v_day)::int + 6) % 7);

    IF NOT v_holiday THEN
      SELECT * INTO v_wh
      FROM public.consultation_working_hours
      WHERE weekday = v_weekday AND is_active = true
      LIMIT 1;

      IF FOUND AND v_wh.start_time < v_wh.end_time THEN
        v_cursor := v_wh.start_time;
        WHILE v_cursor + make_interval(mins => COALESCE(v_wh.slot_minutes, v_duration)) <= v_wh.end_time LOOP
          v_slot_end := v_cursor + make_interval(mins => COALESCE(v_wh.slot_minutes, v_duration));
          v_ts := (v_day::text || ' ' || v_cursor::text)::timestamp AT TIME ZONE 'Africa/Lagos';

          SELECT EXISTS(
            SELECT 1 FROM public.consultation_bookings b
            WHERE b.status IN ('scheduled', 'confirmed', 'pending')
              AND b.scheduled_at = v_ts
              AND (p_department_id IS NULL OR b.department_id = p_department_id)
          ) INTO v_busy;

          v_slots := v_slots || jsonb_build_array(jsonb_build_object(
            'date', v_day,
            'time', to_char(v_cursor, 'HH24:MI'),
            'scheduled_at', v_ts,
            'available', NOT v_busy,
            'period', CASE
              WHEN v_cursor < TIME '12:00' THEN 'morning'
              WHEN v_cursor < TIME '16:00' THEN 'afternoon'
              ELSE 'evening'
            END
          ));

          v_cursor := v_slot_end;
        END LOOP;
      END IF;
    END IF;

    v_day := v_day + 1;
  END LOOP;

  RETURN v_slots;
END;
$$;

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
  p_timezone text DEFAULT 'Africa/Lagos'
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

  SELECT id, duration_minutes INTO v_dept_id, v_duration
  FROM public.consultation_departments
  WHERE slug = COALESCE(NULLIF(trim(p_department_slug), ''), 'sales')
    AND is_active = true
  LIMIT 1;

  IF v_dept_id IS NULL THEN
    SELECT id, duration_minutes INTO v_dept_id, v_duration
    FROM public.consultation_departments
    WHERE is_active = true
    ORDER BY sort_order
    LIMIT 1;
  END IF;

  v_advisor_id := p_advisor_id;
  IF v_advisor_id IS NULL AND v_dept_id IS NOT NULL THEN
    SELECT id INTO v_advisor_id
    FROM public.consultation_advisors
    WHERE department_id = v_dept_id AND is_active = true
    ORDER BY sort_order, rating DESC
    LIMIT 1;
  END IF;

  SELECT full_name INTO v_advisor_name
  FROM public.consultation_advisors WHERE id = v_advisor_id;

  v_space := position(' ' in v_name);
  IF v_space > 0 THEN
    v_first := left(v_name, v_space - 1);
    v_last := trim(substr(v_name, v_space + 1));
  ELSE
    v_first := v_name;
    v_last := '';
  END IF;

  v_ref := 'CON-' || to_char(now(), 'YYYY') || '-' ||
           lpad((floor(random() * 900000) + 100000)::int::text, 6, '0');

  INSERT INTO public.leads (
    first_name, last_name, phone, email, source, status, notes
  ) VALUES (
    v_first, v_last, v_phone, v_email, 'book_consultation', 'new',
    trim(both E'\n' from concat_ws(E'\n',
      'Ref: ' || v_ref,
      'Department: ' || COALESCE(p_department_slug, 'sales'),
      'Meeting: ' || v_method,
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
    reference, lead_id, department_id, advisor_id,
    full_name, phone, email, company,
    meeting_method, scheduled_at, duration_minutes, timezone,
    purpose, budget, property_reference, preferred_estate, timeline,
    investment_interest, notes, document_urls, status
  ) VALUES (
    v_ref, v_lead_id, v_dept_id, v_advisor_id,
    v_name, v_phone, v_email, NULLIF(trim(COALESCE(p_company, '')), ''),
    v_method, v_when, COALESCE(v_duration, 45), COALESCE(p_timezone, 'Africa/Lagos'),
    p_purpose, p_budget, p_property_reference, p_preferred_estate, p_timeline,
    COALESCE(p_investment_interest, false), p_notes, COALESCE(p_document_urls, '[]'::jsonb),
    'scheduled'
  )
  RETURNING id INTO v_booking_id;

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

GRANT EXECUTE ON FUNCTION public.get_consultation_slots(date, int, uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.book_public_consultation(
  text, text, text, text, text, text, timestamptz, uuid,
  text, text, text, text, text, boolean, text, jsonb, text
) TO anon, authenticated;
