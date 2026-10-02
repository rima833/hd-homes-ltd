-- Office Directory platform: extended locations, structured hours, media gallery.

ALTER TABLE public.office_locations
  ADD COLUMN IF NOT EXISTS slug text,
  ADD COLUMN IF NOT EXISTS short_description text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS description text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS city text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS state text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS country text NOT NULL DEFAULT 'Nigeria',
  ADD COLUMN IF NOT EXISTS latitude double precision,
  ADD COLUMN IF NOT EXISTS longitude double precision,
  ADD COLUMN IF NOT EXISTS whatsapp text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS nearby_landmarks jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS cover_image text,
  ADD COLUMN IF NOT EXISTS parking_info text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS is_featured boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS show_on_map boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS allow_appointments boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS facilities jsonb NOT NULL DEFAULT '{}'::jsonb;

CREATE UNIQUE INDEX IF NOT EXISTS office_locations_slug_idx
  ON public.office_locations (slug)
  WHERE slug IS NOT NULL AND COALESCE(is_deleted, false) = false;

CREATE TABLE IF NOT EXISTS public.office_hours (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  office_id uuid NOT NULL REFERENCES public.office_locations(id) ON DELETE CASCADE,
  day_of_week int NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  is_open boolean NOT NULL DEFAULT true,
  open_time time NOT NULL DEFAULT '08:00',
  close_time time NOT NULL DEFAULT '18:00',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (office_id, day_of_week)
);

CREATE INDEX IF NOT EXISTS office_hours_office_idx ON public.office_hours (office_id);

CREATE TABLE IF NOT EXISTS public.office_media (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  office_id uuid NOT NULL REFERENCES public.office_locations(id) ON DELETE CASCADE,
  media_type text NOT NULL DEFAULT 'image',
  storage_path text NOT NULL,
  sort_order int NOT NULL DEFAULT 0,
  is_cover boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS office_media_office_idx ON public.office_media (office_id, sort_order);

ALTER TABLE public.office_hours ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.office_media ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS office_hours_public_read ON public.office_hours;
CREATE POLICY office_hours_public_read ON public.office_hours
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.office_locations o
      WHERE o.id = office_hours.office_id
        AND o.is_deleted = false
        AND o.status = 'active'
    )
  );

DROP POLICY IF EXISTS office_hours_staff ON public.office_hours;
CREATE POLICY office_hours_staff ON public.office_hours
  FOR ALL USING (public.has_permission('manage_marketing'))
  WITH CHECK (public.has_permission('manage_marketing'));

DROP POLICY IF EXISTS office_media_public_read ON public.office_media;
CREATE POLICY office_media_public_read ON public.office_media
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.office_locations o
      WHERE o.id = office_media.office_id
        AND o.is_deleted = false
        AND o.status = 'active'
    )
  );

DROP POLICY IF EXISTS office_media_staff ON public.office_media;
CREATE POLICY office_media_staff ON public.office_media
  FOR ALL USING (public.has_permission('manage_marketing'))
  WITH CHECK (public.has_permission('manage_marketing'));

-- Backfill slugs and geo for seeded offices.
UPDATE public.office_locations SET
  slug = 'head-office-lekki',
  city = 'Lagos',
  state = 'Lagos',
  latitude = 6.4474,
  longitude = 3.4723,
  parking_info = 'Visitor parking available at rear entrance',
  nearby_landmarks = '["Lekki Phase 1", "Admiralty Way"]'::jsonb,
  is_featured = true
WHERE name = 'Head Office' AND (slug IS NULL OR slug = '');

UPDATE public.office_locations SET
  slug = 'abuja-regional',
  city = 'Abuja',
  state = 'FCT',
  latitude = 9.0765,
  longitude = 7.3986,
  parking_info = 'Basement parking available',
  nearby_landmarks = '["Central Business District"]'::jsonb
WHERE name = 'Abuja Regional Office' AND (slug IS NULL OR slug = '');

UPDATE public.office_locations SET
  slug = 'port-harcourt-sales',
  city = 'Port Harcourt',
  state = 'Rivers',
  latitude = 4.8156,
  longitude = 7.0498,
  parking_info = 'On-site parking for visitors',
  nearby_landmarks = '["GRA Phase 2"]'::jsonb
WHERE name = 'Port Harcourt Sales Office' AND (slug IS NULL OR slug = '');

-- Default opening hours (Mon–Fri 8–18, Sat 9–17, Sun closed) for all active offices.
INSERT INTO public.office_hours (office_id, day_of_week, is_open, open_time, close_time)
SELECT o.id, d.day_of_week, d.is_open, d.open_time, d.close_time
FROM public.office_locations o
CROSS JOIN (
  VALUES
    (0, true, '08:00'::time, '18:00'::time),
    (1, true, '08:00'::time, '18:00'::time),
    (2, true, '08:00'::time, '18:00'::time),
    (3, true, '08:00'::time, '18:00'::time),
    (4, true, '08:00'::time, '18:00'::time),
    (5, true, '09:00'::time, '17:00'::time),
    (6, false, '09:00'::time, '17:00'::time)
) AS d(day_of_week, is_open, open_time, close_time)
WHERE COALESCE(o.is_deleted, false) = false
ON CONFLICT (office_id, day_of_week) DO NOTHING;

-- Optional: link consultation bookings to an office.
ALTER TABLE public.consultation_bookings
  ADD COLUMN IF NOT EXISTS office_location_id uuid
    REFERENCES public.office_locations(id) ON DELETE SET NULL;

-- Extend consultation RPC to accept office location.
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

  IF v_advisor_id IS NOT NULL THEN
    SELECT full_name INTO v_advisor_name
    FROM public.consultation_advisors WHERE id = v_advisor_id;
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
    reference, lead_id, department_id, advisor_id, office_location_id,
    full_name, phone, email, company,
    meeting_method, scheduled_at, duration_minutes, timezone,
    purpose, budget, property_reference, preferred_estate, timeline,
    investment_interest, notes, document_urls, status
  ) VALUES (
    v_ref, v_lead_id, v_dept_id, v_advisor_id, p_office_location_id,
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

GRANT EXECUTE ON FUNCTION public.book_public_consultation(
  text, text, text, text, text, text, timestamptz, uuid,
  text, text, text, text, text, boolean, text, jsonb, text, uuid
) TO anon, authenticated;
