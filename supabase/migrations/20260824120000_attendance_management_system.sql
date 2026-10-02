-- HD HOMES Attendance Management System
-- Extends existing employees / shifts / attendance_records (HCM).
-- Additive only — does not drop live HR data.

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._attendance_is_hr(p_uid uuid DEFAULT auth.uid())
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    public.has_role('super_admin', p_uid)
    OR public.has_permission('hr.attendance', p_uid)
    OR public.has_permission('hr.write', p_uid)
    OR public.has_permission('hr.read', p_uid),
    false
  );
$$;

CREATE OR REPLACE FUNCTION public._attendance_can_manage(p_uid uuid DEFAULT auth.uid())
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    public.has_role('super_admin', p_uid)
    OR public.has_permission('hr.attendance', p_uid)
    OR public.has_permission('hr.write', p_uid)
    OR public.has_permission('hr.approvals', p_uid),
    false
  );
$$;

CREATE OR REPLACE FUNCTION public._attendance_haversine_m(
  lat1 double precision,
  lng1 double precision,
  lat2 double precision,
  lng2 double precision
)
RETURNS double precision
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN lat1 IS NULL OR lng1 IS NULL OR lat2 IS NULL OR lng2 IS NULL THEN NULL
    ELSE 6371000 * 2 * asin(sqrt(
      power(sin(radians(lat2 - lat1) / 2), 2)
      + cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lng2 - lng1) / 2), 2)
    ))
  END;
$$;

-- ---------------------------------------------------------------------------
-- Locations
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.attendance_locations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text UNIQUE,
  location_type text NOT NULL DEFAULT 'OFFICE'
    CHECK (location_type IN ('OFFICE','SITE','REMOTE','OTHER')),
  address text,
  latitude double precision,
  longitude double precision,
  geofence_radius integer,
  timezone text NOT NULL DEFAULT 'Africa/Lagos',
  qr_enabled boolean NOT NULL DEFAULT true,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','disabled')),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES auth.users(id),
  updated_by uuid REFERENCES auth.users(id)
);

CREATE INDEX IF NOT EXISTS idx_attendance_locations_status
  ON public.attendance_locations (status);

-- ---------------------------------------------------------------------------
-- QR codes (opaque token identifies location, never an employee)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.attendance_qr_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  location_id uuid NOT NULL REFERENCES public.attendance_locations(id) ON DELETE CASCADE,
  token text NOT NULL UNIQUE,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','disabled')),
  label text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  rotated_at timestamptz,
  created_by uuid REFERENCES auth.users(id),
  disabled_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_attendance_qr_location
  ON public.attendance_qr_codes (location_id);

-- ---------------------------------------------------------------------------
-- Shift catalog extras
-- ---------------------------------------------------------------------------
ALTER TABLE public.shifts
  ADD COLUMN IF NOT EXISTS break_duration_minutes integer NOT NULL DEFAULT 60,
  ADD COLUMN IF NOT EXISTS grace_period_minutes integer NOT NULL DEFAULT 15,
  ADD COLUMN IF NOT EXISTS working_days integer[] NOT NULL DEFAULT ARRAY[1,2,3,4,5],
  ADD COLUMN IF NOT EXISTS overtime_threshold_minutes integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

-- ---------------------------------------------------------------------------
-- Employee attendance flags (canonical people table remains employees)
-- ---------------------------------------------------------------------------
ALTER TABLE public.employees
  ADD COLUMN IF NOT EXISTS attendance_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS default_shift_id uuid REFERENCES public.shifts(id),
  ADD COLUMN IF NOT EXISTS default_location_id uuid REFERENCES public.attendance_locations(id);

CREATE INDEX IF NOT EXISTS idx_employees_attendance_user
  ON public.employees (user_id)
  WHERE coalesce(is_deleted, false) = false;

-- ---------------------------------------------------------------------------
-- Policies (single-row org settings)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.attendance_policies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE DEFAULT 'default',
  timezone text NOT NULL DEFAULT 'Africa/Lagos',
  work_week integer[] NOT NULL DEFAULT ARRAY[1,2,3,4,5],
  default_shift_id uuid REFERENCES public.shifts(id),
  grace_period_minutes integer NOT NULL DEFAULT 15,
  max_break_minutes integer NOT NULL DEFAULT 60,
  max_break_count integer NOT NULL DEFAULT 2,
  break_warning_minutes integer NOT NULL DEFAULT 45,
  overtime_mode text NOT NULL DEFAULT 'requires_approval'
    CHECK (overtime_mode IN ('automatic','requires_approval','disabled')),
  late_policy text NOT NULL DEFAULT 'grace_then_late',
  geofencing_enabled boolean NOT NULL DEFAULT false,
  qr_required boolean NOT NULL DEFAULT true,
  remote_requires_approval boolean NOT NULL DEFAULT true,
  correction_requires_approval boolean NOT NULL DEFAULT true,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid REFERENCES auth.users(id)
);

-- ---------------------------------------------------------------------------
-- Daily rollup extras (keep UNIQUE employee_id + work_date)
-- ---------------------------------------------------------------------------
ALTER TABLE public.attendance_records
  ADD COLUMN IF NOT EXISTS location_id uuid REFERENCES public.attendance_locations(id),
  ADD COLUMN IF NOT EXISTS attendance_state text NOT NULL DEFAULT 'not_started',
  ADD COLUMN IF NOT EXISTS late_minutes integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS work_minutes integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS break_minutes integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS overtime_minutes integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS current_break_started_at timestamptz,
  ADD COLUMN IF NOT EXISTS last_event_type text,
  ADD COLUMN IF NOT EXISTS last_event_at timestamptz,
  ADD COLUMN IF NOT EXISTS source text,
  ADD COLUMN IF NOT EXISTS scheduled_start timestamptz,
  ADD COLUMN IF NOT EXISTS scheduled_end timestamptz,
  ADD COLUMN IF NOT EXISTS is_remote boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS qr_code_id uuid REFERENCES public.attendance_qr_codes(id),
  ADD COLUMN IF NOT EXISTS client_latitude double precision,
  ADD COLUMN IF NOT EXISTS client_longitude double precision;

ALTER TABLE public.attendance_records DROP CONSTRAINT IF EXISTS attendance_records_status_check;
ALTER TABLE public.attendance_records
  ADD CONSTRAINT attendance_records_status_check
  CHECK (status IN (
    'present','absent','late','remote','half_day','on_leave','holiday','on_break','clocked_out'
  ));

ALTER TABLE public.attendance_records DROP CONSTRAINT IF EXISTS attendance_records_state_check;
ALTER TABLE public.attendance_records
  ADD CONSTRAINT attendance_records_state_check
  CHECK (attendance_state IN (
    'not_started','working','on_break','after_break','completed'
  ));

-- ---------------------------------------------------------------------------
-- Immutable events
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.attendance_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  attendance_id uuid REFERENCES public.attendance_records(id) ON DELETE SET NULL,
  event_type text NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  location_id uuid REFERENCES public.attendance_locations(id),
  qr_code_id uuid REFERENCES public.attendance_qr_codes(id),
  source text NOT NULL DEFAULT 'qr',
  latitude double precision,
  longitude double precision,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES auth.users(id),
  CHECK (event_type IN (
    'CLOCK_IN','BREAK_START','BREAK_END','CLOCK_OUT',
    'CORRECTION_REQUESTED','CORRECTION_APPROVED','CORRECTION_REJECTED',
    'REMOTE_REQUESTED','REMOTE_APPROVED','REMOTE_REJECTED',
    'OVERTIME_REQUESTED','OVERTIME_APPROVED','OVERTIME_REJECTED'
  ))
);

CREATE INDEX IF NOT EXISTS idx_attendance_events_employee_day
  ON public.attendance_events (employee_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_attendance_events_attendance
  ON public.attendance_events (attendance_id, occurred_at);

CREATE TABLE IF NOT EXISTS public.attendance_breaks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  attendance_id uuid NOT NULL REFERENCES public.attendance_records(id) ON DELETE CASCADE,
  employee_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  started_at timestamptz NOT NULL,
  ended_at timestamptz,
  duration_minutes integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_attendance_breaks_open
  ON public.attendance_breaks (attendance_id)
  WHERE ended_at IS NULL;

CREATE TABLE IF NOT EXISTS public.attendance_corrections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  attendance_id uuid REFERENCES public.attendance_records(id) ON DELETE SET NULL,
  work_date date NOT NULL,
  requested_clock_in timestamptz,
  requested_clock_out timestamptz,
  reason text NOT NULL,
  attachment_url text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  reviewer_id uuid REFERENCES auth.users(id),
  review_note text,
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES auth.users(id)
);

CREATE TABLE IF NOT EXISTS public.overtime_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  attendance_id uuid REFERENCES public.attendance_records(id) ON DELETE SET NULL,
  work_date date NOT NULL,
  minutes integer NOT NULL,
  reason text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  auto_detected boolean NOT NULL DEFAULT false,
  reviewer_id uuid REFERENCES auth.users(id),
  review_note text,
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.remote_work_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  work_date date NOT NULL,
  reason text NOT NULL,
  location_label text,
  start_time time,
  end_time time,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  reviewer_id uuid REFERENCES auth.users(id),
  review_note text,
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES auth.users(id)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_remote_work_employee_date
  ON public.remote_work_requests (employee_id, work_date)
  WHERE status IN ('pending','approved');

CREATE TABLE IF NOT EXISTS public.attendance_audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id uuid REFERENCES auth.users(id),
  action text NOT NULL,
  target_type text,
  target_id uuid,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_attendance_audit_created
  ON public.attendance_audit_logs (created_at DESC);

CREATE TABLE IF NOT EXISTS public.attendance_scan_idempotency (
  idempotency_key text PRIMARY KEY,
  employee_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  result jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Seeds
-- ---------------------------------------------------------------------------
INSERT INTO public.attendance_locations (name, slug, location_type, address, qr_enabled, status)
VALUES
  ('Head Office – Front Desk', 'head-office-front-desk', 'OFFICE', 'HD HOMES Head Office', true, 'active'),
  ('Remote', 'remote', 'REMOTE', 'Approved remote work', false, 'active')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.attendance_policies (slug)
VALUES ('default')
ON CONFLICT (slug) DO NOTHING;

UPDATE public.attendance_policies p
SET default_shift_id = s.id
FROM public.shifts s
WHERE p.slug = 'default' AND p.default_shift_id IS NULL AND s.slug = 'standard-day';

UPDATE public.employees e
SET default_shift_id = coalesce(e.default_shift_id, s.id)
FROM public.shifts s
WHERE s.slug = 'standard-day' AND e.default_shift_id IS NULL;

UPDATE public.employees e
SET default_location_id = coalesce(e.default_location_id, loc.id)
FROM public.attendance_locations loc
WHERE loc.slug = 'head-office-front-desk' AND e.default_location_id IS NULL;

INSERT INTO public.attendance_qr_codes (location_id, token, label, status)
SELECT loc.id, 'HDH-ATT-' || encode(gen_random_bytes(24), 'hex'), loc.name, 'active'
FROM public.attendance_locations loc
WHERE loc.slug = 'head-office-front-desk'
  AND loc.qr_enabled
  AND NOT EXISTS (
    SELECT 1 FROM public.attendance_qr_codes q
    WHERE q.location_id = loc.id AND q.status = 'active'
  );

-- ---------------------------------------------------------------------------
-- Live board (security invoker so RLS applies)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_attendance_live
WITH (security_invoker = true) AS
SELECT
  e.id AS employee_id,
  e.user_id,
  e.employee_code,
  trim(both ' ' FROM coalesce(e.first_name,'') || ' ' || coalesce(e.last_name,'')) AS full_name,
  coalesce(e.work_email, e.email) AS email,
  e.job_title,
  e.employment_status,
  e.attendance_enabled,
  e.department_id,
  d.name AS department_name,
  e.default_shift_id,
  sh.name AS shift_name,
  sh.start_time AS shift_start,
  sh.end_time AS shift_end,
  e.default_location_id,
  loc.name AS default_location_name,
  ar.id AS attendance_id,
  ar.work_date,
  ar.status,
  ar.attendance_state,
  ar.clock_in_at,
  ar.clock_out_at,
  ar.current_break_started_at,
  ar.late_minutes,
  ar.work_minutes,
  ar.break_minutes,
  ar.overtime_minutes,
  ar.is_remote,
  ar.location_id,
  aloc.name AS location_name,
  aloc.location_type,
  ar.last_event_type,
  ar.last_event_at,
  ar.scheduled_start,
  ar.scheduled_end
FROM public.employees e
LEFT JOIN public.departments d ON d.id = e.department_id
LEFT JOIN public.shifts sh ON sh.id = e.default_shift_id
LEFT JOIN public.attendance_locations loc ON loc.id = e.default_location_id
LEFT JOIN public.attendance_records ar
  ON ar.employee_id = e.id
 AND ar.work_date = (timezone(coalesce(
      (SELECT timezone FROM public.attendance_policies WHERE slug = 'default' LIMIT 1),
      'Africa/Lagos'
    ), now()))::date
LEFT JOIN public.attendance_locations aloc ON aloc.id = ar.location_id
WHERE coalesce(e.is_deleted, false) = false;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.attendance_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_qr_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_breaks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_corrections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.overtime_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.remote_work_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_scan_idempotency ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS attendance_locations_select ON public.attendance_locations;
CREATE POLICY attendance_locations_select ON public.attendance_locations FOR SELECT
  USING (
    public.is_staff()
    OR public._attendance_is_hr()
  );

DROP POLICY IF EXISTS attendance_locations_write ON public.attendance_locations;
CREATE POLICY attendance_locations_write ON public.attendance_locations FOR ALL
  USING (public._attendance_can_manage())
  WITH CHECK (public._attendance_can_manage());

DROP POLICY IF EXISTS attendance_qr_select ON public.attendance_qr_codes;
CREATE POLICY attendance_qr_select ON public.attendance_qr_codes FOR SELECT
  USING (public._attendance_can_manage());

DROP POLICY IF EXISTS attendance_qr_write ON public.attendance_qr_codes;
CREATE POLICY attendance_qr_write ON public.attendance_qr_codes FOR ALL
  USING (public._attendance_can_manage())
  WITH CHECK (public._attendance_can_manage());

DROP POLICY IF EXISTS attendance_policies_select ON public.attendance_policies;
CREATE POLICY attendance_policies_select ON public.attendance_policies FOR SELECT
  USING (public.is_staff() OR public._attendance_is_hr());

DROP POLICY IF EXISTS attendance_policies_write ON public.attendance_policies;
CREATE POLICY attendance_policies_write ON public.attendance_policies FOR ALL
  USING (public._attendance_can_manage())
  WITH CHECK (public._attendance_can_manage());

-- Daily records: HR sees all; employee sees own (no direct writes)
DROP POLICY IF EXISTS attendance_records_select ON public.attendance_records;
CREATE POLICY attendance_records_select ON public.attendance_records FOR SELECT
  USING (
    public._attendance_is_hr()
    OR employee_id IN (SELECT id FROM public.employees WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS attendance_records_write ON public.attendance_records;
CREATE POLICY attendance_records_write ON public.attendance_records FOR ALL
  USING (public._attendance_can_manage())
  WITH CHECK (public._attendance_can_manage());

DROP POLICY IF EXISTS attendance_events_select ON public.attendance_events;
CREATE POLICY attendance_events_select ON public.attendance_events FOR SELECT
  USING (
    public._attendance_is_hr()
    OR employee_id IN (SELECT id FROM public.employees WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS attendance_events_write ON public.attendance_events;
CREATE POLICY attendance_events_write ON public.attendance_events FOR ALL
  USING (public._attendance_can_manage())
  WITH CHECK (public._attendance_can_manage());

DROP POLICY IF EXISTS attendance_breaks_select ON public.attendance_breaks;
CREATE POLICY attendance_breaks_select ON public.attendance_breaks FOR SELECT
  USING (
    public._attendance_is_hr()
    OR employee_id IN (SELECT id FROM public.employees WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS attendance_breaks_write ON public.attendance_breaks;
CREATE POLICY attendance_breaks_write ON public.attendance_breaks FOR ALL
  USING (public._attendance_can_manage())
  WITH CHECK (public._attendance_can_manage());

DROP POLICY IF EXISTS attendance_corrections_select ON public.attendance_corrections;
CREATE POLICY attendance_corrections_select ON public.attendance_corrections FOR SELECT
  USING (
    public._attendance_is_hr()
    OR employee_id IN (SELECT id FROM public.employees WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS attendance_corrections_insert ON public.attendance_corrections;
CREATE POLICY attendance_corrections_insert ON public.attendance_corrections FOR INSERT
  WITH CHECK (
    employee_id IN (SELECT id FROM public.employees WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS attendance_corrections_update ON public.attendance_corrections;
CREATE POLICY attendance_corrections_update ON public.attendance_corrections FOR UPDATE
  USING (public._attendance_can_manage())
  WITH CHECK (public._attendance_can_manage());

DROP POLICY IF EXISTS overtime_requests_select ON public.overtime_requests;
CREATE POLICY overtime_requests_select ON public.overtime_requests FOR SELECT
  USING (
    public._attendance_is_hr()
    OR employee_id IN (SELECT id FROM public.employees WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS overtime_requests_insert ON public.overtime_requests;
CREATE POLICY overtime_requests_insert ON public.overtime_requests FOR INSERT
  WITH CHECK (
    employee_id IN (SELECT id FROM public.employees WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS overtime_requests_update ON public.overtime_requests;
CREATE POLICY overtime_requests_update ON public.overtime_requests FOR UPDATE
  USING (public._attendance_can_manage())
  WITH CHECK (public._attendance_can_manage());

DROP POLICY IF EXISTS remote_work_select ON public.remote_work_requests;
CREATE POLICY remote_work_select ON public.remote_work_requests FOR SELECT
  USING (
    public._attendance_is_hr()
    OR employee_id IN (SELECT id FROM public.employees WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS remote_work_insert ON public.remote_work_requests;
CREATE POLICY remote_work_insert ON public.remote_work_requests FOR INSERT
  WITH CHECK (
    employee_id IN (SELECT id FROM public.employees WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS remote_work_update ON public.remote_work_requests;
CREATE POLICY remote_work_update ON public.remote_work_requests FOR UPDATE
  USING (public._attendance_can_manage())
  WITH CHECK (public._attendance_can_manage());

DROP POLICY IF EXISTS attendance_audit_select ON public.attendance_audit_logs;
CREATE POLICY attendance_audit_select ON public.attendance_audit_logs FOR SELECT
  USING (public._attendance_can_manage() OR public.has_permission('view_audit_logs', auth.uid()));

DROP POLICY IF EXISTS attendance_audit_write ON public.attendance_audit_logs;
CREATE POLICY attendance_audit_write ON public.attendance_audit_logs FOR INSERT
  WITH CHECK (public._attendance_can_manage() OR auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS attendance_idemp_all ON public.attendance_scan_idempotency;
CREATE POLICY attendance_idemp_all ON public.attendance_scan_idempotency FOR ALL
  USING (false)
  WITH CHECK (false);

DROP POLICY IF EXISTS shifts_select ON public.shifts;
CREATE POLICY shifts_select ON public.shifts FOR SELECT
  USING (public.is_staff() OR public._attendance_is_hr());

GRANT SELECT ON public.v_attendance_live TO authenticated;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.attendance_events;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.attendance_breaks;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.attendance_corrections;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.overtime_requests;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.remote_work_requests;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.attendance_locations;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.attendance_qr_codes;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.attendance_policies;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.shifts;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE public.attendance_records REPLICA IDENTITY FULL;
ALTER TABLE public.attendance_events REPLICA IDENTITY FULL;
ALTER TABLE public.attendance_breaks REPLICA IDENTITY FULL;
ALTER TABLE public.attendance_corrections REPLICA IDENTITY FULL;
ALTER TABLE public.overtime_requests REPLICA IDENTITY FULL;
ALTER TABLE public.remote_work_requests REPLICA IDENTITY FULL;
