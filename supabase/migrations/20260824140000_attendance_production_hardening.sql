-- Production hardening for HD HOMES attendance.
-- Reuses existing employees / shifts / attendance_* tables.
-- Links staff auth users, default shifts, eligible employment statuses,
-- shift fallback, HR notifications, and realtime audit.

CREATE OR REPLACE FUNCTION public._attendance_employment_ok(p_status text)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT lower(coalesce(p_status, '')) IN (
    'active', 'confirmed', 'probation', 'employed', 'full_time', 'contract'
  );
$$;

CREATE OR REPLACE FUNCTION public._attendance_current_employee()
RETURNS public.employees
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_emp public.employees;
  v_uid uuid := auth.uid();
  v_email text;
  v_prof public.profiles;
  v_shift uuid;
  v_loc uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN v_emp;
  END IF;

  SELECT * INTO v_emp
  FROM public.employees
  WHERE user_id = v_uid
    AND coalesce(is_deleted, false) = false
  ORDER BY updated_at DESC
  LIMIT 1;

  IF v_emp.id IS NULL THEN
    SELECT email INTO v_email FROM auth.users WHERE id = v_uid;
    IF v_email IS NOT NULL THEN
      SELECT * INTO v_emp
      FROM public.employees
      WHERE coalesce(is_deleted, false) = false
        AND (
          lower(coalesce(email, '')) = lower(v_email)
          OR lower(coalesce(work_email, '')) = lower(v_email)
        )
      ORDER BY updated_at DESC
      LIMIT 1;
      IF v_emp.id IS NOT NULL THEN
        UPDATE public.employees
        SET user_id = v_uid, updated_at = now()
        WHERE id = v_emp.id AND user_id IS NULL
        RETURNING * INTO v_emp;
      END IF;
    END IF;
  END IF;

  IF v_emp.id IS NULL AND public.is_staff(v_uid) THEN
    SELECT * INTO v_prof FROM public.profiles WHERE id = v_uid;
    SELECT default_shift_id INTO v_shift FROM public.attendance_policies WHERE slug = 'default' LIMIT 1;
    IF v_shift IS NULL THEN
      SELECT id INTO v_shift FROM public.shifts WHERE status IN ('active','published') ORDER BY start_time LIMIT 1;
    END IF;
    SELECT id INTO v_loc
    FROM public.attendance_locations
    WHERE slug = 'head-office-front-desk' AND status = 'active'
    LIMIT 1;

    INSERT INTO public.employees (
      user_id, first_name, last_name, email, work_email, phone, avatar_url,
      employment_status, attendance_enabled, default_shift_id, default_location_id,
      employee_code, job_title
    ) VALUES (
      v_uid,
      coalesce(nullif(v_prof.first_name, ''), split_part(coalesce(v_prof.email, v_email, 'Staff'), '@', 1)),
      coalesce(nullif(v_prof.last_name, ''), 'Member'),
      coalesce(v_prof.email, v_email),
      coalesce(v_prof.email, v_email),
      v_prof.phone,
      v_prof.avatar_url,
      'active',
      true,
      v_shift,
      v_loc,
      'HDH-EMP-' || upper(substr(replace(v_uid::text, '-', ''), 1, 8)),
      'Staff'
    )
    ON CONFLICT DO NOTHING
    RETURNING * INTO v_emp;

    IF v_emp.id IS NULL THEN
      SELECT * INTO v_emp
      FROM public.employees
      WHERE user_id = v_uid AND coalesce(is_deleted, false) = false
      LIMIT 1;
    END IF;
  END IF;

  RETURN v_emp;
END;
$$;

CREATE OR REPLACE FUNCTION public._attendance_notify(
  p_user_id uuid,
  p_title text,
  p_body text,
  p_url text DEFAULT '/attendance',
  p_meta jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_user_id IS NULL THEN
    RETURN;
  END IF;
  INSERT INTO public.notifications (
    user_id, title, body, channel, action_url, metadata,
    category, type, priority, delivery_status, is_read
  ) VALUES (
    p_user_id, p_title, p_body, 'in_app', p_url, coalesce(p_meta, '{}'::jsonb),
    'system', 'information', 'normal', 'delivered', false
  );
EXCEPTION WHEN OTHERS THEN
  BEGIN
    INSERT INTO public.notifications (user_id, title, body, channel, action_url, metadata)
    VALUES (p_user_id, p_title, p_body, 'in_app', p_url, coalesce(p_meta, '{}'::jsonb));
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;
END;
$$;

CREATE OR REPLACE FUNCTION public._attendance_notify_hr(
  p_title text,
  p_body text,
  p_url text DEFAULT '/dashboard/attendance',
  p_meta jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT DISTINCT ur.user_id
    FROM public.user_roles ur
    JOIN public.roles rl ON rl.id = ur.role_id
    WHERE ur.status = 'active'
      AND coalesce(ur.is_deleted, false) = false
      AND (
        rl.slug IN ('super_admin','admin')
        OR public.has_permission('hr.attendance', ur.user_id)
        OR public.has_permission('hr.write', ur.user_id)
      )
  LOOP
    PERFORM public._attendance_notify(r.user_id, p_title, p_body, p_url, p_meta);
  END LOOP;
END;
$$;

-- Shift fallback inside process_attendance_scan: patch via wrapper around
-- the existing function by replacing the no-shift block. Recreate scan
-- eligibility checks by patching only the employee/shift preamble through
-- a dedicated helper used at the start of the existing function.

CREATE OR REPLACE FUNCTION public._attendance_resolve_shift(p_emp public.employees)
RETURNS public.shifts
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_shift public.shifts;
  v_pol public.attendance_policies;
BEGIN
  SELECT * INTO v_pol FROM public.attendance_policies WHERE slug = 'default' LIMIT 1;
  IF p_emp.default_shift_id IS NOT NULL THEN
    SELECT * INTO v_shift FROM public.shifts WHERE id = p_emp.default_shift_id;
  END IF;
  IF v_shift.id IS NULL AND v_pol.default_shift_id IS NOT NULL THEN
    SELECT * INTO v_shift FROM public.shifts WHERE id = v_pol.default_shift_id;
  END IF;
  IF v_shift.id IS NULL THEN
    SELECT * INTO v_shift
    FROM public.shifts
    WHERE coalesce(status, 'active') IN ('active', 'published')
    ORDER BY start_time
    LIMIT 1;
  END IF;
  RETURN v_shift;
END;
$$;

-- Patch process_attendance_scan eligibility by replacing the function body
-- is too large to duplicate; instead apply targeted CREATE OR REPLACE of
-- a thin interceptor. Postgres cannot intercept easily, so we replace the
-- two IF blocks by redefining the function from the applied version with
-- the eligibility/shift changes. The live function is updated below using
-- search-and-replace of only the employee status and shift lookup.

DO $$
BEGIN
  -- Default policy shift + location
  UPDATE public.attendance_policies p
  SET default_shift_id = coalesce(
        p.default_shift_id,
        (SELECT id FROM public.shifts WHERE name = 'Standard Day' LIMIT 1)
      )
  WHERE p.slug = 'default';

  UPDATE public.employees e
  SET
    default_shift_id = coalesce(
      e.default_shift_id,
      (SELECT default_shift_id FROM public.attendance_policies WHERE slug = 'default' LIMIT 1)
    ),
    default_location_id = coalesce(
      e.default_location_id,
      (SELECT id FROM public.attendance_locations WHERE slug = 'head-office-front-desk' LIMIT 1)
    ),
    updated_at = now()
  WHERE coalesce(e.is_deleted, false) = false;

  UPDATE public.employees e
  SET user_id = u.id, updated_at = now()
  FROM auth.users u
  WHERE e.user_id IS NULL
    AND coalesce(e.is_deleted, false) = false
    AND lower(coalesce(e.work_email, e.email, '')) = lower(u.email);

  INSERT INTO public.attendance_locations (
    name, slug, location_type, status, qr_enabled, timezone
  )
  SELECT 'Victoria Crest Site', 'victoria-crest-site', 'SITE', 'active', true, 'Africa/Lagos'
  WHERE NOT EXISTS (
    SELECT 1 FROM public.attendance_locations WHERE slug = 'victoria-crest-site'
  );

  INSERT INTO public.shifts (
    name, slug, start_time, end_time, break_duration_minutes, grace_period_minutes,
    working_days, overtime_threshold_minutes, status, timezone
  )
  SELECT
    'Evening Shift', 'evening-shift', '14:00'::time, '22:00'::time, 45, 15,
    ARRAY[1,2,3,4,5], 0, 'active', 'Africa/Lagos'
  WHERE NOT EXISTS (SELECT 1 FROM public.shifts WHERE slug = 'evening-shift' OR name = 'Evening Shift');
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.attendance_audit_logs;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE public.attendance_audit_logs REPLICA IDENTITY FULL;

DO $$
DECLARE
  src text;
BEGIN
  src := pg_get_functiondef('public.process_attendance_scan(text,text,double precision,double precision,text)'::regprocedure);
  src := replace(src, 'CREATE FUNCTION', 'CREATE OR REPLACE FUNCTION');
  src := replace(
    src,
    $q$IF lower(coalesce(v_emp.employment_status, '')) NOT IN ('active', 'confirmed') THEN$q$,
    $q$IF NOT public._attendance_employment_ok(v_emp.employment_status) THEN$q$
  );
  src := replace(
    src,
    $q$IF v_emp.default_shift_id IS NOT NULL THEN
    SELECT * INTO v_shift FROM public.shifts WHERE id = v_emp.default_shift_id;
  ELSIF v_pol.default_shift_id IS NOT NULL THEN
    SELECT * INTO v_shift FROM public.shifts WHERE id = v_pol.default_shift_id;
  END IF;$q$,
    $q$v_shift := public._attendance_resolve_shift(v_emp);$q$
  );
  EXECUTE src;

  src := pg_get_functiondef('public.attendance_my_context()'::regprocedure);
  src := replace(src, 'CREATE FUNCTION', 'CREATE OR REPLACE FUNCTION');
  src := replace(
    src,
    $q$coalesce(v_emp.attendance_enabled, false)
      AND lower(coalesce(v_emp.employment_status,'')) IN ('active','confirmed')$q$,
    $q$coalesce(v_emp.attendance_enabled, false)
      AND public._attendance_employment_ok(v_emp.employment_status)$q$
  );
  src := replace(
    src,
    $q$IF v_emp.default_shift_id IS NOT NULL THEN
    SELECT * INTO v_shift FROM public.shifts WHERE id = v_emp.default_shift_id;
  ELSIF v_pol.default_shift_id IS NOT NULL THEN
    SELECT * INTO v_shift FROM public.shifts WHERE id = v_pol.default_shift_id;
  END IF;$q$,
    $q$v_shift := public._attendance_resolve_shift(v_emp);$q$
  );
  EXECUTE src;
END $$;

GRANT EXECUTE ON FUNCTION public._attendance_employment_ok(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public._attendance_resolve_shift(public.employees) TO authenticated;
