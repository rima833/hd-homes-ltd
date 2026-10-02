-- Harden staff invite RPC: safe UUID handling, employee codes, clearer errors.

CREATE OR REPLACE FUNCTION public._next_employee_code()
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_max INT;
BEGIN
  SELECT coalesce(
    max(
      NULLIF(
        regexp_replace(employee_code, '^HDH-EMP-', ''),
        ''
      )::int
    ),
    0
  )
  INTO v_max
  FROM public.employees
  WHERE employee_code ~ '^HDH-EMP-[0-9]+$';

  RETURN 'HDH-EMP-' || lpad((v_max + 1)::text, 4, '0');
END;
$$;

CREATE OR REPLACE FUNCTION public._safe_uuid(p_value TEXT)
RETURNS UUID
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  IF p_value IS NULL OR btrim(p_value) = '' THEN
    RETURN NULL;
  END IF;
  BEGIN
    RETURN btrim(p_value)::uuid;
  EXCEPTION
    WHEN invalid_text_representation THEN
      RETURN NULL;
  END;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_invite_staff(
  p_email TEXT,
  p_role_slug TEXT,
  p_first_name TEXT DEFAULT NULL,
  p_last_name TEXT DEFAULT NULL,
  p_phone TEXT DEFAULT NULL,
  p_department_id UUID DEFAULT NULL,
  p_team_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_email TEXT := lower(btrim(p_email));
  v_role TEXT := lower(btrim(p_role_slug));
  v_token TEXT;
  v_employee_id UUID;
  v_code TEXT;
  v_existing UUID;
  v_invite public.staff_invitations%ROWTYPE;
  v_department_id UUID := public._safe_uuid(p_department_id::text);
  v_team_id UUID := public._safe_uuid(p_team_id::text);
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF v_email IS NULL OR v_email = '' OR position('@' in v_email) = 0 THEN
    RAISE EXCEPTION 'invalid_email';
  END IF;

  IF NOT public.staff_invite_can_assign(v_role, v_actor) THEN
    RAISE EXCEPTION 'forbidden_role_assignment:%', v_role;
  END IF;

  IF v_department_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.departments d WHERE d.id = v_department_id
  ) THEN
    v_department_id := NULL;
  END IF;

  IF v_team_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.teams t WHERE t.id = v_team_id
  ) THEN
    v_team_id := NULL;
  END IF;

  UPDATE public.staff_invitations
  SET status = 'revoked', updated_at = now()
  WHERE lower(email) = v_email
    AND status = 'pending';

  v_token := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');

  SELECT id INTO v_employee_id
  FROM public.employees
  WHERE lower(coalesce(email, work_email, '')) = v_email
    AND coalesce(is_deleted, false) = false
  LIMIT 1;

  IF v_employee_id IS NULL THEN
    v_code := public._next_employee_code();

    INSERT INTO public.employees (
      employee_code,
      first_name,
      last_name,
      email,
      work_email,
      phone,
      department_id,
      team_id,
      role_slug,
      employment_status,
      created_by
    ) VALUES (
      v_code,
      coalesce(nullif(btrim(p_first_name), ''), split_part(v_email, '@', 1)),
      coalesce(nullif(btrim(p_last_name), ''), 'Staff'),
      v_email,
      v_email,
      nullif(btrim(p_phone), ''),
      v_department_id,
      v_team_id,
      v_role,
      'probation',
      v_actor
    )
    RETURNING id INTO v_employee_id;
  ELSE
    UPDATE public.employees
    SET role_slug = v_role,
        department_id = coalesce(v_department_id, department_id),
        team_id = coalesce(v_team_id, team_id),
        first_name = coalesce(nullif(btrim(p_first_name), ''), first_name),
        last_name = coalesce(nullif(btrim(p_last_name), ''), last_name),
        phone = coalesce(nullif(btrim(p_phone), ''), phone),
        updated_at = now(),
        updated_by = v_actor
    WHERE id = v_employee_id;
  END IF;

  INSERT INTO public.staff_invitations (
    email,
    role_slug,
    first_name,
    last_name,
    phone,
    department_id,
    team_id,
    employee_id,
    invited_by,
    token,
    status
  ) VALUES (
    v_email,
    v_role,
    nullif(btrim(p_first_name), ''),
    nullif(btrim(p_last_name), ''),
    nullif(btrim(p_phone), ''),
    v_department_id,
    v_team_id,
    v_employee_id,
    v_actor,
    v_token,
    'pending'
  )
  RETURNING * INTO v_invite;

  SELECT id INTO v_existing
  FROM auth.users
  WHERE lower(email) = v_email
  LIMIT 1;

  IF v_existing IS NOT NULL THEN
    PERFORM public._apply_staff_role_to_user(v_existing, v_role, v_actor);

    UPDATE public.employees
    SET user_id = v_existing,
        employment_status = 'active',
        updated_at = now(),
        updated_by = v_actor
    WHERE id = v_employee_id;

    UPDATE public.staff_invitations
    SET status = 'accepted',
        accepted_at = now(),
        accepted_user_id = v_existing,
        updated_at = now()
    WHERE id = v_invite.id
    RETURNING * INTO v_invite;
  END IF;

  RETURN jsonb_build_object(
    'id', v_invite.id,
    'email', v_invite.email,
    'role_slug', v_invite.role_slug,
    'token', v_invite.token,
    'status', v_invite.status,
    'employee_id', v_invite.employee_id,
    'expires_at', v_invite.expires_at,
    'accepted_user_id', v_invite.accepted_user_id,
    'already_had_account', v_existing IS NOT NULL
  );
END;
$$;

NOTIFY pgrst, 'reload schema';
