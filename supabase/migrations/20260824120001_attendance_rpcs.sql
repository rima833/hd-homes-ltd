-- Attendance RPCs: server timestamps, atomic state machine, QR validation.

CREATE OR REPLACE FUNCTION public._attendance_current_employee()
RETURNS public.employees
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_emp public.employees;
BEGIN
  SELECT * INTO v_emp
  FROM public.employees
  WHERE user_id = auth.uid()
    AND coalesce(is_deleted, false) = false
  ORDER BY updated_at DESC
  LIMIT 1;
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
    'system', 'info', 'normal', 'delivered', false
  );
EXCEPTION WHEN OTHERS THEN
  NULL;
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
      AND rl.slug IN ('super_admin','admin')
  LOOP
    PERFORM public._attendance_notify(r.user_id, p_title, p_body, p_url, p_meta);
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public._attendance_audit(
  p_action text,
  p_target_type text,
  p_target_id uuid,
  p_meta jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.attendance_audit_logs (actor_id, action, target_type, target_id, metadata)
  VALUES (auth.uid(), p_action, p_target_type, p_target_id, coalesce(p_meta, '{}'::jsonb));
END;
$$;

CREATE OR REPLACE FUNCTION public._attendance_recompute(p_attendance_id uuid)
RETURNS public.attendance_records
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rec public.attendance_records;
  v_shift public.shifts;
  v_pol public.attendance_policies;
  v_now timestamptz := clock_timestamp();
  v_break int := 0;
  v_work int := 0;
  v_expected int := 0;
  v_ot int := 0;
  v_open timestamptz;
BEGIN
  SELECT * INTO v_rec FROM public.attendance_records WHERE id = p_attendance_id FOR UPDATE;
  SELECT * INTO v_pol FROM public.attendance_policies WHERE slug = 'default' LIMIT 1;
  IF v_rec.shift_id IS NOT NULL THEN
    SELECT * INTO v_shift FROM public.shifts WHERE id = v_rec.shift_id;
  END IF;

  SELECT coalesce(sum(
    CASE
      WHEN ended_at IS NULL THEN greatest(0, floor(extract(epoch FROM (v_now - started_at)) / 60))::int
      ELSE duration_minutes
    END
  ), 0)
  INTO v_break
  FROM public.attendance_breaks
  WHERE attendance_id = p_attendance_id;

  SELECT started_at INTO v_open
  FROM public.attendance_breaks
  WHERE attendance_id = p_attendance_id AND ended_at IS NULL
  LIMIT 1;

  IF v_rec.clock_in_at IS NOT NULL THEN
    v_work := greatest(
      0,
      floor(extract(epoch FROM (coalesce(v_rec.clock_out_at, v_now) - v_rec.clock_in_at)) / 60)::int - v_break
    );
  END IF;

  IF v_shift.id IS NOT NULL THEN
    v_expected := greatest(
      0,
      floor(extract(epoch FROM (v_shift.end_time - v_shift.start_time)) / 60)::int
        - coalesce(v_shift.break_duration_minutes, 0)
        + coalesce(v_shift.overtime_threshold_minutes, 0)
    );
  END IF;

  IF v_rec.clock_out_at IS NOT NULL AND v_expected > 0 THEN
    v_ot := greatest(0, v_work - v_expected);
  ELSE
    v_ot := 0;
  END IF;

  IF v_rec.clock_out_at IS NOT NULL THEN
    v_rec.attendance_state := 'completed';
    v_rec.status := CASE
      WHEN v_rec.is_remote THEN 'remote'
      WHEN v_rec.late_minutes > 0 THEN 'late'
      ELSE 'clocked_out'
    END;
  ELSIF v_open IS NOT NULL THEN
    v_rec.attendance_state := 'on_break';
    v_rec.status := 'on_break';
  ELSIF v_rec.clock_in_at IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM public.attendance_breaks WHERE attendance_id = p_attendance_id
    ) THEN
      v_rec.attendance_state := 'after_break';
    ELSE
      v_rec.attendance_state := 'working';
    END IF;
    v_rec.status := CASE
      WHEN v_rec.is_remote THEN 'remote'
      WHEN v_rec.late_minutes > 0 THEN 'late'
      ELSE 'present'
    END;
  ELSE
    v_rec.attendance_state := 'not_started';
  END IF;

  UPDATE public.attendance_records SET
    attendance_state = v_rec.attendance_state,
    status = v_rec.status,
    break_minutes = v_break,
    work_minutes = v_work,
    overtime_minutes = v_ot,
    current_break_started_at = v_open,
    updated_at = v_now
  WHERE id = p_attendance_id
  RETURNING * INTO v_rec;

  RETURN v_rec;
END;
$$;

CREATE OR REPLACE FUNCTION public.process_attendance_scan(
  p_token text,
  p_requested_action text DEFAULT NULL,
  p_latitude double precision DEFAULT NULL,
  p_longitude double precision DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_emp public.employees;
  v_pol public.attendance_policies;
  v_qr public.attendance_qr_codes;
  v_loc public.attendance_locations;
  v_shift public.shifts;
  v_rec public.attendance_records;
  v_now timestamptz := clock_timestamp();
  v_tz text;
  v_date date;
  v_action text;
  v_state text;
  v_token text := trim(coalesce(p_token, ''));
  v_dist double precision;
  v_grace int;
  v_late int := 0;
  v_sched_start timestamptz;
  v_sched_end timestamptz;
  v_break public.attendance_breaks;
  v_event_id uuid;
  v_allowed text[];
  v_remote public.remote_work_requests;
  v_max_breaks int;
  v_break_count int;
  v_prior jsonb;
  v_msg text;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'unauthenticated', 'message', 'Sign in to record attendance.');
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT result INTO v_prior
    FROM public.attendance_scan_idempotency
    WHERE idempotency_key = p_idempotency_key;
    IF v_prior IS NOT NULL THEN
      RETURN v_prior;
    END IF;
  END IF;

  v_emp := public._attendance_current_employee();
  IF v_emp.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'unauthorized_employee', 'message', 'Your account is not enabled for attendance.');
  END IF;
  IF lower(coalesce(v_emp.employment_status, '')) NOT IN ('active', 'confirmed') THEN
    RETURN jsonb_build_object('ok', false, 'code', 'unauthorized_employee', 'message', 'Your account is not enabled for attendance.');
  END IF;
  IF coalesce(v_emp.attendance_enabled, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'code', 'unauthorized_employee', 'message', 'Your account is not enabled for attendance.');
  END IF;

  SELECT * INTO v_pol FROM public.attendance_policies WHERE slug = 'default' LIMIT 1;
  v_tz := coalesce(v_pol.timezone, 'Africa/Lagos');
  v_date := (timezone(v_tz, v_now))::date;

  SELECT * INTO v_remote
  FROM public.remote_work_requests
  WHERE employee_id = v_emp.id AND work_date = v_date AND status = 'approved'
  LIMIT 1;

  IF v_token = '' THEN
    IF v_remote.id IS NULL AND coalesce(v_pol.qr_required, true) THEN
      RETURN jsonb_build_object('ok', false, 'code', 'invalid_qr', 'message', 'This attendance QR code is invalid.');
    END IF;
    SELECT * INTO v_loc FROM public.attendance_locations WHERE slug = 'remote' LIMIT 1;
  ELSE
    IF v_token NOT LIKE 'HDH-ATT-%' THEN
      -- allow raw token without prefix
      NULL;
    END IF;
    SELECT * INTO v_qr FROM public.attendance_qr_codes WHERE token = v_token LIMIT 1;
    IF v_qr.id IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'code', 'invalid_qr', 'message', 'This attendance QR code is invalid.');
    END IF;
    IF v_qr.status <> 'active' THEN
      RETURN jsonb_build_object('ok', false, 'code', 'disabled_qr', 'message', 'This attendance location is currently unavailable.');
    END IF;
    SELECT * INTO v_loc FROM public.attendance_locations WHERE id = v_qr.location_id;
    IF v_loc.id IS NULL OR v_loc.status <> 'active' THEN
      RETURN jsonb_build_object('ok', false, 'code', 'disabled_qr', 'message', 'This attendance location is currently unavailable.');
    END IF;
    IF coalesce(v_pol.geofencing_enabled, false)
       AND v_loc.latitude IS NOT NULL AND v_loc.longitude IS NOT NULL
       AND coalesce(v_loc.geofence_radius, 0) > 0 THEN
      v_dist := public._attendance_haversine_m(p_latitude, p_longitude, v_loc.latitude, v_loc.longitude);
      IF v_dist IS NULL OR v_dist > v_loc.geofence_radius THEN
        RETURN jsonb_build_object(
          'ok', false,
          'code', 'outside_location',
          'message', 'You are outside the permitted attendance location.'
        );
      END IF;
    END IF;
  END IF;

  IF v_emp.default_shift_id IS NOT NULL THEN
    SELECT * INTO v_shift FROM public.shifts WHERE id = v_emp.default_shift_id;
  ELSIF v_pol.default_shift_id IS NOT NULL THEN
    SELECT * INTO v_shift FROM public.shifts WHERE id = v_pol.default_shift_id;
  END IF;

  IF v_shift.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'no_shift', 'message', 'You do not have an active shift assigned.');
  END IF;
  IF v_shift.status IS NOT NULL AND v_shift.status NOT IN ('active', 'published') THEN
    RETURN jsonb_build_object('ok', false, 'code', 'no_shift', 'message', 'You do not have an active shift assigned.');
  END IF;

  -- Serialize punches per employee
  PERFORM pg_advisory_xact_lock(hashtext(v_emp.id::text));

  SELECT * INTO v_rec
  FROM public.attendance_records
  WHERE employee_id = v_emp.id AND work_date = v_date
  FOR UPDATE;

  v_state := coalesce(v_rec.attendance_state, 'not_started');
  IF v_rec.id IS NULL THEN
    v_state := 'not_started';
  END IF;

  v_allowed := CASE v_state
    WHEN 'not_started' THEN ARRAY['CLOCK_IN']
    WHEN 'working' THEN ARRAY['BREAK_START','CLOCK_OUT']
    WHEN 'on_break' THEN ARRAY['BREAK_END']
    WHEN 'after_break' THEN ARRAY['BREAK_START','CLOCK_OUT']
    WHEN 'completed' THEN ARRAY[]::text[]
    ELSE ARRAY['CLOCK_IN']
  END;

  v_action := nullif(upper(trim(coalesce(p_requested_action, ''))), '');
  IF v_action IS NULL THEN
    IF array_length(v_allowed, 1) = 1 THEN
      v_action := v_allowed[1];
    ELSIF array_length(v_allowed, 1) IS NULL THEN
      RETURN jsonb_build_object(
        'ok', false,
        'code', 'already_completed',
        'message', 'Today''s attendance has already been completed.',
        'state', v_state,
        'clock_in_at', v_rec.clock_in_at,
        'clock_out_at', v_rec.clock_out_at,
        'location_name', v_loc.name
      );
    ELSE
      RETURN jsonb_build_object(
        'ok', true,
        'needs_choice', true,
        'code', 'choose_action',
        'message', 'Choose your next attendance action.',
        'state', v_state,
        'allowed_actions', to_jsonb(v_allowed),
        'clock_in_at', v_rec.clock_in_at,
        'location_name', coalesce(v_loc.name, ''),
        'work_minutes', v_rec.work_minutes,
        'break_minutes', v_rec.break_minutes,
        'employee_name', trim(both ' ' FROM coalesce(v_emp.first_name,'') || ' ' || coalesce(v_emp.last_name,'')),
        'work_date', v_date
      );
    END IF;
  END IF;

  IF NOT (v_action = ANY (v_allowed)) THEN
    IF v_state = 'completed' THEN
      RETURN jsonb_build_object('ok', false, 'code', 'already_completed', 'message', 'Today''s attendance has already been completed.');
    END IF;
    IF v_action = 'CLOCK_IN' THEN
      RETURN jsonb_build_object('ok', false, 'code', 'already_clocked_in', 'message', 'You are already clocked in.');
    END IF;
    RETURN jsonb_build_object('ok', false, 'code', 'invalid_action', 'message', 'That attendance action is not allowed right now.', 'state', v_state);
  END IF;

  v_grace := coalesce(v_shift.grace_period_minutes, v_pol.grace_period_minutes, 15);
  v_sched_start := (v_date::text || ' ' || v_shift.start_time::text)::timestamp AT TIME ZONE v_tz;
  v_sched_end := (v_date::text || ' ' || v_shift.end_time::text)::timestamp AT TIME ZONE v_tz;
  IF v_sched_end <= v_sched_start THEN
    v_sched_end := v_sched_end + interval '1 day';
  END IF;

  IF v_rec.id IS NULL THEN
    INSERT INTO public.attendance_records (
      employee_id, work_date, shift_id, location_id, qr_code_id, status,
      attendance_state, scheduled_start, scheduled_end, is_remote, source,
      client_latitude, client_longitude
    ) VALUES (
      v_emp.id, v_date, v_shift.id, v_loc.id, v_qr.id, 'absent',
      'not_started', v_sched_start, v_sched_end,
      (v_remote.id IS NOT NULL OR coalesce(v_loc.location_type,'') = 'REMOTE'),
      CASE WHEN v_qr.id IS NOT NULL THEN 'qr' ELSE 'remote' END,
      p_latitude, p_longitude
    )
    RETURNING * INTO v_rec;
  END IF;

  v_max_breaks := coalesce(v_pol.max_break_count, 2);

  IF v_action = 'CLOCK_IN' THEN
    IF v_now > v_sched_start + make_interval(mins => v_grace) THEN
      v_late := greatest(0, floor(extract(epoch FROM (v_now - v_sched_start)) / 60)::int);
    END IF;
    UPDATE public.attendance_records SET
      clock_in_at = v_now,
      location_id = v_loc.id,
      qr_code_id = v_qr.id,
      late_minutes = v_late,
      scheduled_start = v_sched_start,
      scheduled_end = v_sched_end,
      is_remote = (v_remote.id IS NOT NULL OR coalesce(v_loc.location_type,'') = 'REMOTE'),
      source = CASE WHEN v_qr.id IS NOT NULL THEN 'qr' ELSE 'remote' END,
      last_event_type = 'CLOCK_IN',
      last_event_at = v_now,
      client_latitude = p_latitude,
      client_longitude = p_longitude,
      notes = CASE WHEN v_late > 0 THEN 'Late by ' || v_late || ' min' ELSE notes END
    WHERE id = v_rec.id;
    v_msg := 'CLOCK IN SUCCESSFUL';

  ELSIF v_action = 'BREAK_START' THEN
    SELECT count(*) INTO v_break_count FROM public.attendance_breaks WHERE attendance_id = v_rec.id;
    IF v_break_count >= v_max_breaks THEN
      RETURN jsonb_build_object('ok', false, 'code', 'break_limit', 'message', 'You have used the allowed number of breaks today.');
    END IF;
    IF EXISTS (SELECT 1 FROM public.attendance_breaks WHERE attendance_id = v_rec.id AND ended_at IS NULL) THEN
      RETURN jsonb_build_object('ok', false, 'code', 'break_open', 'message', 'You already have an open break.');
    END IF;
    INSERT INTO public.attendance_breaks (attendance_id, employee_id, started_at)
    VALUES (v_rec.id, v_emp.id, v_now);
    UPDATE public.attendance_records SET
      last_event_type = 'BREAK_START',
      last_event_at = v_now,
      location_id = coalesce(v_loc.id, location_id)
    WHERE id = v_rec.id;
    v_msg := 'BREAK STARTED';

  ELSIF v_action = 'BREAK_END' THEN
    SELECT * INTO v_break
    FROM public.attendance_breaks
    WHERE attendance_id = v_rec.id AND ended_at IS NULL
    FOR UPDATE;
    IF v_break.id IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'code', 'no_break', 'message', 'There is no open break to end.');
    END IF;
    UPDATE public.attendance_breaks SET
      ended_at = v_now,
      duration_minutes = greatest(0, floor(extract(epoch FROM (v_now - started_at)) / 60)::int)
    WHERE id = v_break.id;
    UPDATE public.attendance_records SET
      last_event_type = 'BREAK_END',
      last_event_at = v_now
    WHERE id = v_rec.id;
    v_msg := 'BREAK ENDED';

  ELSIF v_action = 'CLOCK_OUT' THEN
    UPDATE public.attendance_records SET
      clock_out_at = v_now,
      last_event_type = 'CLOCK_OUT',
      last_event_at = v_now,
      location_id = coalesce(v_loc.id, location_id)
    WHERE id = v_rec.id;
    v_msg := 'CLOCK OUT SUCCESSFUL';
  END IF;

  INSERT INTO public.attendance_events (
    employee_id, attendance_id, event_type, occurred_at, location_id, qr_code_id,
    source, latitude, longitude, created_by, metadata
  ) VALUES (
    v_emp.id, v_rec.id, v_action, v_now, v_loc.id, v_qr.id,
    CASE WHEN v_qr.id IS NOT NULL THEN 'qr' ELSE 'app' END,
    p_latitude, p_longitude, v_uid,
    jsonb_build_object('late_minutes', v_late)
  ) RETURNING id INTO v_event_id;

  v_rec := public._attendance_recompute(v_rec.id);

  IF v_action = 'CLOCK_OUT'
     AND v_rec.overtime_minutes > 0
     AND coalesce(v_pol.overtime_mode, 'requires_approval') <> 'disabled' THEN
    INSERT INTO public.overtime_requests (
      employee_id, attendance_id, work_date, minutes, reason, status, auto_detected
    ) VALUES (
      v_emp.id, v_rec.id, v_date, v_rec.overtime_minutes, 'Auto-detected overtime',
      CASE WHEN v_pol.overtime_mode = 'automatic' THEN 'approved' ELSE 'pending' END,
      true
    );
    INSERT INTO public.attendance_events (
      employee_id, attendance_id, event_type, occurred_at, created_by, metadata
    ) VALUES (
      v_emp.id, v_rec.id, 'OVERTIME_REQUESTED', v_now, v_uid,
      jsonb_build_object('minutes', v_rec.overtime_minutes)
    );
    IF v_pol.overtime_mode = 'requires_approval' THEN
      PERFORM public._attendance_notify_hr(
        'Overtime requested',
        trim(both ' ' FROM coalesce(v_emp.first_name,'') || ' ' || coalesce(v_emp.last_name,''))
          || ' has ' || v_rec.overtime_minutes || ' min overtime pending approval.'
      );
    END IF;
  END IF;

  PERFORM public._attendance_audit(
    v_action, 'attendance_record', v_rec.id,
    jsonb_build_object('event_id', v_event_id, 'location_id', v_loc.id, 'late_minutes', v_late)
  );

  PERFORM public._attendance_notify(
    v_uid,
    v_msg,
    CASE v_action
      WHEN 'CLOCK_IN' THEN 'You are now clocked in at ' || coalesce(v_loc.name, 'your location') || '.'
      WHEN 'BREAK_START' THEN 'Your break has started.'
      WHEN 'BREAK_END' THEN 'Your break has ended. You are back on duty.'
      WHEN 'CLOCK_OUT' THEN 'You are clocked out. Total work '
        || (v_rec.work_minutes / 60) || 'h ' || (v_rec.work_minutes % 60) || 'm.'
      ELSE v_msg
    END,
    '/attendance',
    jsonb_build_object('action', v_action, 'attendance_id', v_rec.id)
  );

  IF v_action = 'CLOCK_IN' AND v_late > coalesce(v_grace, 15) + 20 THEN
    PERFORM public._attendance_notify_hr(
      'Late arrival',
      trim(both ' ' FROM coalesce(v_emp.first_name,'') || ' ' || coalesce(v_emp.last_name,''))
        || ' clocked in ' || v_late || ' minutes late.'
    );
  END IF;

  DECLARE
    v_result jsonb;
  BEGIN
    v_result := jsonb_build_object(
      'ok', true,
      'needs_choice', false,
      'code', 'ok',
      'action', v_action,
      'message', v_msg,
      'occurred_at', v_now,
      'state', v_rec.attendance_state,
      'status', v_rec.status,
      'clock_in_at', v_rec.clock_in_at,
      'clock_out_at', v_rec.clock_out_at,
      'work_minutes', v_rec.work_minutes,
      'break_minutes', v_rec.break_minutes,
      'overtime_minutes', v_rec.overtime_minutes,
      'late_minutes', v_rec.late_minutes,
      'location_name', coalesce(v_loc.name, ''),
      'location_type', coalesce(v_loc.location_type, ''),
      'shift_name', coalesce(v_shift.name, ''),
      'employee_name', trim(both ' ' FROM coalesce(v_emp.first_name,'') || ' ' || coalesce(v_emp.last_name,'')),
      'work_date', v_date,
      'attendance_id', v_rec.id
    );
    IF p_idempotency_key IS NOT NULL THEN
      INSERT INTO public.attendance_scan_idempotency (idempotency_key, employee_id, result)
      VALUES (p_idempotency_key, v_emp.id, v_result)
      ON CONFLICT (idempotency_key) DO NOTHING;
    END IF;
    RETURN v_result;
  END;
END;
$$;

CREATE OR REPLACE FUNCTION public.attendance_my_context()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_emp public.employees;
  v_pol public.attendance_policies;
  v_rec public.attendance_records;
  v_shift public.shifts;
  v_loc public.attendance_locations;
  v_tz text;
  v_date date;
  v_now timestamptz := clock_timestamp();
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'unauthenticated');
  END IF;
  v_emp := public._attendance_current_employee();
  SELECT * INTO v_pol FROM public.attendance_policies WHERE slug = 'default' LIMIT 1;
  v_tz := coalesce(v_pol.timezone, 'Africa/Lagos');
  v_date := (timezone(v_tz, v_now))::date;
  IF v_emp.id IS NULL THEN
    RETURN jsonb_build_object(
      'ok', true,
      'enabled', false,
      'message', 'Your account is not enabled for attendance.',
      'work_date', v_date
    );
  END IF;
  SELECT * INTO v_rec FROM public.attendance_records WHERE employee_id = v_emp.id AND work_date = v_date;
  IF v_emp.default_shift_id IS NOT NULL THEN
    SELECT * INTO v_shift FROM public.shifts WHERE id = v_emp.default_shift_id;
  ELSIF v_pol.default_shift_id IS NOT NULL THEN
    SELECT * INTO v_shift FROM public.shifts WHERE id = v_pol.default_shift_id;
  END IF;
  IF v_rec.location_id IS NOT NULL THEN
    SELECT * INTO v_loc FROM public.attendance_locations WHERE id = v_rec.location_id;
  ELSIF v_emp.default_location_id IS NOT NULL THEN
    SELECT * INTO v_loc FROM public.attendance_locations WHERE id = v_emp.default_location_id;
  END IF;
  RETURN jsonb_build_object(
    'ok', true,
    'enabled', coalesce(v_emp.attendance_enabled, false)
      AND lower(coalesce(v_emp.employment_status,'')) IN ('active','confirmed'),
    'employee', jsonb_build_object(
      'id', v_emp.id,
      'full_name', trim(both ' ' FROM coalesce(v_emp.first_name,'') || ' ' || coalesce(v_emp.last_name,'')),
      'first_name', v_emp.first_name,
      'job_title', v_emp.job_title,
      'employee_code', v_emp.employee_code,
      'department_id', v_emp.department_id,
      'avatar_url', v_emp.avatar_url
    ),
    'work_date', v_date,
    'timezone', v_tz,
    'server_now', v_now,
    'policy', jsonb_build_object(
      'max_break_minutes', v_pol.max_break_minutes,
      'max_break_count', v_pol.max_break_count,
      'geofencing_enabled', v_pol.geofencing_enabled,
      'qr_required', v_pol.qr_required,
      'overtime_mode', v_pol.overtime_mode
    ),
    'shift', CASE WHEN v_shift.id IS NULL THEN NULL ELSE jsonb_build_object(
      'id', v_shift.id,
      'name', v_shift.name,
      'start_time', v_shift.start_time,
      'end_time', v_shift.end_time,
      'grace_period_minutes', v_shift.grace_period_minutes,
      'break_duration_minutes', v_shift.break_duration_minutes
    ) END,
    'location', CASE WHEN v_loc.id IS NULL THEN NULL ELSE jsonb_build_object(
      'id', v_loc.id,
      'name', v_loc.name,
      'location_type', v_loc.location_type
    ) END,
    'today', CASE WHEN v_rec.id IS NULL THEN jsonb_build_object(
      'state', 'not_started',
      'status', 'absent'
    ) ELSE to_jsonb(v_rec) END
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.attendance_request_correction(
  p_work_date date,
  p_clock_in timestamptz,
  p_clock_out timestamptz,
  p_reason text,
  p_attachment_url text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_emp public.employees;
  v_id uuid;
  v_att uuid;
BEGIN
  v_emp := public._attendance_current_employee();
  IF v_emp.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'unauthorized_employee', 'message', 'Your account is not enabled for attendance.');
  END IF;
  IF coalesce(trim(p_reason), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'invalid', 'message', 'A reason is required.');
  END IF;
  SELECT id INTO v_att FROM public.attendance_records
  WHERE employee_id = v_emp.id AND work_date = p_work_date;
  INSERT INTO public.attendance_corrections (
    employee_id, attendance_id, work_date, requested_clock_in, requested_clock_out,
    reason, attachment_url, created_by
  ) VALUES (
    v_emp.id, v_att, p_work_date, p_clock_in, p_clock_out, trim(p_reason), p_attachment_url, auth.uid()
  ) RETURNING id INTO v_id;
  INSERT INTO public.attendance_events (employee_id, attendance_id, event_type, created_by, metadata)
  VALUES (v_emp.id, v_att, 'CORRECTION_REQUESTED', auth.uid(), jsonb_build_object('correction_id', v_id));
  PERFORM public._attendance_audit('CORRECTION_REQUESTED', 'attendance_correction', v_id, '{}'::jsonb);
  PERFORM public._attendance_notify_hr(
    'Attendance correction requested',
    trim(both ' ' FROM coalesce(v_emp.first_name,'') || ' ' || coalesce(v_emp.last_name,''))
      || ' requested a correction for ' || p_work_date::text
  );
  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.attendance_request_overtime(
  p_work_date date,
  p_minutes integer,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_emp public.employees;
  v_id uuid;
  v_att uuid;
BEGIN
  v_emp := public._attendance_current_employee();
  IF v_emp.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'unauthorized_employee');
  END IF;
  SELECT id INTO v_att FROM public.attendance_records WHERE employee_id = v_emp.id AND work_date = p_work_date;
  INSERT INTO public.overtime_requests (employee_id, attendance_id, work_date, minutes, reason)
  VALUES (v_emp.id, v_att, p_work_date, greatest(1, p_minutes), p_reason)
  RETURNING id INTO v_id;
  INSERT INTO public.attendance_events (employee_id, attendance_id, event_type, created_by, metadata)
  VALUES (v_emp.id, v_att, 'OVERTIME_REQUESTED', auth.uid(), jsonb_build_object('overtime_id', v_id));
  PERFORM public._attendance_notify_hr('Overtime requested', coalesce(p_reason, 'Overtime request submitted'));
  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.attendance_request_remote(
  p_work_date date,
  p_reason text,
  p_location text DEFAULT NULL,
  p_start time DEFAULT NULL,
  p_end time DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_emp public.employees;
  v_id uuid;
  v_pol public.attendance_policies;
  v_status text := 'pending';
BEGIN
  v_emp := public._attendance_current_employee();
  IF v_emp.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'unauthorized_employee', 'message', 'Your account is not enabled for attendance.');
  END IF;
  SELECT * INTO v_pol FROM public.attendance_policies WHERE slug = 'default';
  IF coalesce(v_pol.remote_requires_approval, true) IS FALSE THEN
    v_status := 'approved';
  END IF;
  INSERT INTO public.remote_work_requests (
    employee_id, work_date, reason, location_label, start_time, end_time, status, created_by
  ) VALUES (
    v_emp.id, p_work_date, trim(p_reason), p_location, p_start, p_end, v_status, auth.uid()
  ) RETURNING id INTO v_id;
  INSERT INTO public.attendance_events (employee_id, event_type, created_by, metadata)
  VALUES (v_emp.id, 'REMOTE_REQUESTED', auth.uid(), jsonb_build_object('remote_id', v_id));
  IF v_status = 'pending' THEN
    PERFORM public._attendance_notify_hr('Remote work requested', trim(p_reason));
  END IF;
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'status', v_status);
END;
$$;

CREATE OR REPLACE FUNCTION public.attendance_admin_review(
  p_kind text,
  p_id uuid,
  p_approve boolean,
  p_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_status text := CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END;
  v_emp_id uuid;
  v_user uuid;
  v_att uuid;
  v_date date;
  v_in timestamptz;
  v_out timestamptz;
  v_event text;
BEGIN
  IF auth.uid() IS NULL OR NOT public._attendance_can_manage() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'forbidden', 'message', 'You cannot review this request.');
  END IF;

  IF p_kind = 'correction' THEN
    UPDATE public.attendance_corrections SET
      status = v_status, reviewer_id = auth.uid(), review_note = p_note, reviewed_at = clock_timestamp(), updated_at = clock_timestamp()
    WHERE id = p_id AND status = 'pending'
    RETURNING employee_id, attendance_id, work_date, requested_clock_in, requested_clock_out
    INTO v_emp_id, v_att, v_date, v_in, v_out;
    IF v_emp_id IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'code', 'not_found', 'message', 'Request not found.');
    END IF;
    v_event := CASE WHEN p_approve THEN 'CORRECTION_APPROVED' ELSE 'CORRECTION_REJECTED' END;
    IF p_approve THEN
      INSERT INTO public.attendance_records (employee_id, work_date, clock_in_at, clock_out_at, status, attendance_state, notes)
      VALUES (v_emp_id, v_date, v_in, v_out, 'present', CASE WHEN v_out IS NULL THEN 'working' ELSE 'completed' END, 'Corrected by admin')
      ON CONFLICT (employee_id, work_date) DO UPDATE SET
        clock_in_at = coalesce(EXCLUDED.clock_in_at, public.attendance_records.clock_in_at),
        clock_out_at = coalesce(EXCLUDED.clock_out_at, public.attendance_records.clock_out_at),
        notes = coalesce(public.attendance_records.notes, '') || ' | Correction applied';
      SELECT id INTO v_att FROM public.attendance_records WHERE employee_id = v_emp_id AND work_date = v_date;
      PERFORM public._attendance_recompute(v_att);
    END IF;

  ELSIF p_kind = 'overtime' THEN
    UPDATE public.overtime_requests SET
      status = v_status, reviewer_id = auth.uid(), review_note = p_note, reviewed_at = clock_timestamp(), updated_at = clock_timestamp()
    WHERE id = p_id AND status = 'pending'
    RETURNING employee_id, attendance_id INTO v_emp_id, v_att;
    IF v_emp_id IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'code', 'not_found', 'message', 'Request not found.');
    END IF;
    v_event := CASE WHEN p_approve THEN 'OVERTIME_APPROVED' ELSE 'OVERTIME_REJECTED' END;

  ELSIF p_kind = 'remote' THEN
    UPDATE public.remote_work_requests SET
      status = v_status, reviewer_id = auth.uid(), review_note = p_note, reviewed_at = clock_timestamp(), updated_at = clock_timestamp()
    WHERE id = p_id AND status = 'pending'
    RETURNING employee_id, work_date INTO v_emp_id, v_date;
    IF v_emp_id IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'code', 'not_found', 'message', 'Request not found.');
    END IF;
    v_event := CASE WHEN p_approve THEN 'REMOTE_APPROVED' ELSE 'REMOTE_REJECTED' END;
    IF p_approve THEN
      INSERT INTO public.attendance_records (employee_id, work_date, status, attendance_state, is_remote, notes)
      VALUES (v_emp_id, v_date, 'remote', 'not_started', true, 'Approved remote work')
      ON CONFLICT (employee_id, work_date) DO UPDATE SET is_remote = true, status = CASE
        WHEN public.attendance_records.clock_in_at IS NULL THEN 'remote'
        ELSE public.attendance_records.status
      END;
    END IF;
  ELSE
    RETURN jsonb_build_object('ok', false, 'code', 'invalid', 'message', 'Unknown review type.');
  END IF;

  INSERT INTO public.attendance_events (employee_id, attendance_id, event_type, created_by, metadata)
  VALUES (v_emp_id, v_att, v_event, auth.uid(), jsonb_build_object('id', p_id, 'note', p_note));
  PERFORM public._attendance_audit(v_event, p_kind, p_id, jsonb_build_object('approve', p_approve));

  SELECT user_id INTO v_user FROM public.employees WHERE id = v_emp_id;
  PERFORM public._attendance_notify(
    v_user,
    replace(v_event, '_', ' '),
    coalesce(p_note, CASE WHEN p_approve THEN 'Your request was approved.' ELSE 'Your request was rejected.' END),
    '/attendance'
  );
  RETURN jsonb_build_object('ok', true, 'status', v_status);
END;
$$;

CREATE OR REPLACE FUNCTION public.attendance_admin_upsert_location(
  p_id uuid,
  p_name text,
  p_type text,
  p_address text DEFAULT NULL,
  p_lat double precision DEFAULT NULL,
  p_lng double precision DEFAULT NULL,
  p_radius integer DEFAULT NULL,
  p_qr_enabled boolean DEFAULT true,
  p_status text DEFAULT 'active',
  p_timezone text DEFAULT 'Africa/Lagos'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public._attendance_can_manage() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'forbidden');
  END IF;
  IF p_id IS NULL THEN
    INSERT INTO public.attendance_locations (
      name, slug, location_type, address, latitude, longitude, geofence_radius, qr_enabled, status, timezone, created_by, updated_by
    ) VALUES (
      trim(p_name),
      lower(regexp_replace(trim(p_name), '[^a-zA-Z0-9]+', '-', 'g')),
      upper(p_type),
      p_address, p_lat, p_lng, p_radius, coalesce(p_qr_enabled, true), coalesce(p_status, 'active'),
      coalesce(p_timezone, 'Africa/Lagos'), auth.uid(), auth.uid()
    ) RETURNING id INTO v_id;
  ELSE
    UPDATE public.attendance_locations SET
      name = trim(p_name),
      location_type = upper(p_type),
      address = p_address,
      latitude = p_lat,
      longitude = p_lng,
      geofence_radius = p_radius,
      qr_enabled = coalesce(p_qr_enabled, qr_enabled),
      status = coalesce(p_status, status),
      timezone = coalesce(p_timezone, timezone),
      updated_at = now(),
      updated_by = auth.uid()
    WHERE id = p_id
    RETURNING id INTO v_id;
  END IF;
  PERFORM public._attendance_audit('LOCATION_UPSERT', 'attendance_location', v_id, jsonb_build_object('name', p_name));
  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.attendance_admin_upsert_shift(
  p_id uuid,
  p_name text,
  p_start time,
  p_end time,
  p_break integer DEFAULT 60,
  p_grace integer DEFAULT 15,
  p_days integer[] DEFAULT ARRAY[1,2,3,4,5],
  p_ot integer DEFAULT 0,
  p_status text DEFAULT 'active'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_slug text;
BEGIN
  IF NOT public._attendance_can_manage() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'forbidden');
  END IF;
  v_slug := lower(regexp_replace(trim(p_name), '[^a-zA-Z0-9]+', '-', 'g'));
  IF p_id IS NULL THEN
    INSERT INTO public.shifts (
      name, slug, start_time, end_time, break_duration_minutes, grace_period_minutes,
      working_days, overtime_threshold_minutes, status, timezone
    ) VALUES (
      trim(p_name), v_slug, p_start, p_end, p_break, p_grace, p_days, p_ot, coalesce(p_status,'active'), 'Africa/Lagos'
    ) RETURNING id INTO v_id;
  ELSE
    UPDATE public.shifts SET
      name = trim(p_name),
      start_time = p_start,
      end_time = p_end,
      break_duration_minutes = p_break,
      grace_period_minutes = p_grace,
      working_days = p_days,
      overtime_threshold_minutes = p_ot,
      status = coalesce(p_status, status),
      updated_at = now()
    WHERE id = p_id
    RETURNING id INTO v_id;
  END IF;
  PERFORM public._attendance_audit('SHIFT_UPSERT', 'shift', v_id, jsonb_build_object('name', p_name));
  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.attendance_admin_issue_qr(
  p_location_id uuid,
  p_regenerate boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_token text;
  v_id uuid;
  v_loc public.attendance_locations;
BEGIN
  IF NOT public._attendance_can_manage() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'forbidden');
  END IF;
  SELECT * INTO v_loc FROM public.attendance_locations WHERE id = p_location_id;
  IF v_loc.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'not_found');
  END IF;
  v_token := 'HDH-ATT-' || encode(gen_random_bytes(24), 'hex');
  IF p_regenerate THEN
    UPDATE public.attendance_qr_codes
    SET status = 'disabled', disabled_at = now(), updated_at = now()
    WHERE location_id = p_location_id AND status = 'active';
  ELSIF EXISTS (
    SELECT 1 FROM public.attendance_qr_codes WHERE location_id = p_location_id AND status = 'active'
  ) THEN
    SELECT id, token INTO v_id, v_token FROM public.attendance_qr_codes
    WHERE location_id = p_location_id AND status = 'active'
    ORDER BY created_at DESC LIMIT 1;
    RETURN jsonb_build_object('ok', true, 'id', v_id, 'token', v_token, 'existing', true);
  END IF;
  INSERT INTO public.attendance_qr_codes (location_id, token, label, status, created_by)
  VALUES (p_location_id, v_token, v_loc.name, 'active', auth.uid())
  RETURNING id INTO v_id;
  PERFORM public._attendance_audit(
    CASE WHEN p_regenerate THEN 'QR_REGENERATE' ELSE 'QR_CREATE' END,
    'attendance_qr_code', v_id, jsonb_build_object('location_id', p_location_id)
  );
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'token', v_token, 'existing', false);
END;
$$;

CREATE OR REPLACE FUNCTION public.attendance_admin_set_qr_status(
  p_id uuid,
  p_status text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public._attendance_can_manage() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'forbidden');
  END IF;
  UPDATE public.attendance_qr_codes SET
    status = p_status,
    disabled_at = CASE WHEN p_status = 'disabled' THEN now() ELSE NULL END,
    updated_at = now()
  WHERE id = p_id;
  PERFORM public._attendance_audit('QR_STATUS', 'attendance_qr_code', p_id, jsonb_build_object('status', p_status));
  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.attendance_admin_update_employee(
  p_employee_id uuid,
  p_enabled boolean DEFAULT NULL,
  p_shift_id uuid DEFAULT NULL,
  p_location_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public._attendance_can_manage() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'forbidden');
  END IF;
  UPDATE public.employees SET
    attendance_enabled = coalesce(p_enabled, attendance_enabled),
    default_shift_id = coalesce(p_shift_id, default_shift_id),
    default_location_id = coalesce(p_location_id, default_location_id),
    updated_at = now(),
    updated_by = auth.uid()
  WHERE id = p_employee_id;
  PERFORM public._attendance_audit('EMPLOYEE_ATTENDANCE', 'employee', p_employee_id, jsonb_build_object(
    'enabled', p_enabled, 'shift_id', p_shift_id, 'location_id', p_location_id
  ));
  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.attendance_admin_upsert_policy(
  p_patch jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public._attendance_can_manage() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'forbidden');
  END IF;
  UPDATE public.attendance_policies SET
    timezone = coalesce(p_patch->>'timezone', timezone),
    grace_period_minutes = coalesce((p_patch->>'grace_period_minutes')::int, grace_period_minutes),
    max_break_minutes = coalesce((p_patch->>'max_break_minutes')::int, max_break_minutes),
    max_break_count = coalesce((p_patch->>'max_break_count')::int, max_break_count),
    break_warning_minutes = coalesce((p_patch->>'break_warning_minutes')::int, break_warning_minutes),
    overtime_mode = coalesce(p_patch->>'overtime_mode', overtime_mode),
    geofencing_enabled = coalesce((p_patch->>'geofencing_enabled')::boolean, geofencing_enabled),
    qr_required = coalesce((p_patch->>'qr_required')::boolean, qr_required),
    remote_requires_approval = coalesce((p_patch->>'remote_requires_approval')::boolean, remote_requires_approval),
    correction_requires_approval = coalesce((p_patch->>'correction_requires_approval')::boolean, correction_requires_approval),
    default_shift_id = coalesce((p_patch->>'default_shift_id')::uuid, default_shift_id),
    updated_at = now(),
    updated_by = auth.uid()
  WHERE slug = 'default'
  RETURNING id INTO v_id;
  PERFORM public._attendance_audit('POLICY_UPDATE', 'attendance_policy', v_id, p_patch);
  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.process_attendance_scan(text, text, double precision, double precision, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.attendance_my_context() TO authenticated;
GRANT EXECUTE ON FUNCTION public.attendance_request_correction(date, timestamptz, timestamptz, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.attendance_request_overtime(date, integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.attendance_request_remote(date, text, text, time, time) TO authenticated;
GRANT EXECUTE ON FUNCTION public.attendance_admin_review(text, uuid, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.attendance_admin_upsert_location(uuid, text, text, text, double precision, double precision, integer, boolean, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.attendance_admin_upsert_shift(uuid, text, time, time, integer, integer, integer[], integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.attendance_admin_issue_qr(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.attendance_admin_set_qr_status(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.attendance_admin_update_employee(uuid, boolean, uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.attendance_admin_upsert_policy(jsonb) TO authenticated;

REVOKE ALL ON FUNCTION public._attendance_recompute(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public._attendance_recompute(uuid) TO authenticated;
