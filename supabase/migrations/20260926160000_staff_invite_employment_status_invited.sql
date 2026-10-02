-- Expand employment_status check for invite/onboarding lifecycle.

ALTER TABLE public.employees
  DROP CONSTRAINT IF EXISTS employees_employment_status_check;

ALTER TABLE public.employees
  ADD CONSTRAINT employees_employment_status_check
  CHECK (employment_status = ANY (ARRAY[
    'invited'::text,
    'onboarding'::text,
    'active'::text,
    'confirmed'::text,
    'probation'::text,
    'on_leave'::text,
    'remote'::text,
    'suspended'::text,
    'inactive'::text,
    'resigned'::text,
    'terminated'::text,
    'retired'::text,
    'archived'::text,
    'pending'::text
  ]));

CREATE OR REPLACE FUNCTION public.admin_invite_staff(
  p_email text,
  p_role_slug text,
  p_first_name text DEFAULT NULL::text,
  p_last_name text DEFAULT NULL::text,
  p_phone text DEFAULT NULL::text,
  p_department_id uuid DEFAULT NULL::uuid,
  p_team_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_email text := lower(trim(p_email));
  v_role text := lower(trim(p_role_slug));
  v_token text;
  v_hash text;
  v_employee_id uuid;
  v_code text;
  v_existing uuid;
  v_invite public.staff_invitations%ROWTYPE;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF v_email IS NULL OR position('@' in v_email) = 0 THEN RAISE EXCEPTION 'invalid_email'; END IF;
  IF NOT public.staff_invite_can_assign(v_role, v_actor) THEN
    RAISE EXCEPTION 'forbidden_role_assignment:%', v_role;
  END IF;

  UPDATE public.staff_invitations
  SET status = 'revoked', revoked_at = now(), revoked_by = v_actor, updated_at = now(), token = NULL
  WHERE lower(email) = v_email AND status = 'pending';

  v_token := encode(extensions.gen_random_bytes(24), 'hex');
  v_hash := public.staff_invite_token_hash(v_token);

  SELECT id INTO v_employee_id FROM public.employees
  WHERE lower(coalesce(email, work_email, '')) = v_email
    AND coalesce(is_deleted, false) = false
  LIMIT 1;

  IF v_employee_id IS NULL THEN
    SELECT 'HDH-EMP-' || lpad((coalesce(max(NULLIF(regexp_replace(employee_code, '\D', '', 'g'), '')::int), 0) + 1)::text, 4, '0')
    INTO v_code FROM public.employees;

    INSERT INTO public.employees (
      employee_code, first_name, last_name, email, work_email, phone,
      department_id, team_id, role_slug, employment_status, created_by
    ) VALUES (
      coalesce(v_code, 'HDH-EMP-0001'),
      coalesce(nullif(trim(p_first_name), ''), split_part(v_email, '@', 1)),
      coalesce(nullif(trim(p_last_name), ''), 'Staff'),
      v_email, v_email, nullif(trim(p_phone), ''),
      p_department_id, p_team_id, v_role, 'invited', v_actor
    ) RETURNING id INTO v_employee_id;
  ELSE
    UPDATE public.employees SET
      role_slug = v_role,
      department_id = coalesce(p_department_id, department_id),
      team_id = coalesce(p_team_id, team_id),
      first_name = coalesce(nullif(trim(p_first_name), ''), first_name),
      last_name = coalesce(nullif(trim(p_last_name), ''), last_name),
      phone = coalesce(nullif(trim(p_phone), ''), phone),
      employment_status = CASE
        WHEN user_id IS NULL AND employment_status IN ('probation', 'inactive', 'pending')
          THEN 'invited'
        ELSE employment_status
      END,
      updated_at = now(), updated_by = v_actor
    WHERE id = v_employee_id;
  END IF;

  INSERT INTO public.staff_invitations (
    email, role_slug, first_name, last_name, phone,
    department_id, team_id, employee_id, invited_by, token, token_hash, status
  ) VALUES (
    v_email, v_role, nullif(trim(p_first_name), ''), nullif(trim(p_last_name), ''),
    nullif(trim(p_phone), ''), p_department_id, p_team_id, v_employee_id, v_actor,
    NULL, v_hash, 'pending'
  ) RETURNING * INTO v_invite;

  SELECT id INTO v_existing FROM auth.users WHERE lower(email) = v_email LIMIT 1;
  IF v_existing IS NOT NULL THEN
    PERFORM public._apply_staff_role_to_user(v_existing, v_role, v_actor);
    UPDATE public.employees SET user_id = v_existing, employment_status = 'active',
      updated_at = now(), updated_by = v_actor WHERE id = v_employee_id;
    UPDATE public.profiles SET employee_id = v_employee_id WHERE id = v_existing;
    UPDATE public.staff_invitations SET status = 'accepted', accepted_at = now(),
      accepted_user_id = v_existing, updated_at = now()
    WHERE id = v_invite.id RETURNING * INTO v_invite;
  END IF;

  INSERT INTO public.audit_logs (user_id, action, module, entity_type, entity_id, metadata)
  VALUES (v_actor, 'staff.invite', 'people', 'staff_invitation', v_invite.id::text,
    jsonb_build_object('email', v_email, 'role_slug', v_role, 'employee_id', v_employee_id, 'status', v_invite.status));

  RETURN jsonb_build_object(
    'id', v_invite.id, 'email', v_invite.email, 'role_slug', v_invite.role_slug,
    'token', CASE WHEN v_invite.status = 'pending' THEN v_token ELSE NULL END,
    'status', v_invite.status, 'employee_id', v_invite.employee_id,
    'expires_at', v_invite.expires_at, 'accepted_user_id', v_invite.accepted_user_id,
    'already_had_account', v_existing IS NOT NULL
  );
END;
$function$;

UPDATE public.employees e
SET employment_status = 'invited',
    updated_at = now()
FROM public.staff_invitations i
WHERE i.employee_id = e.id
  AND i.status = 'pending'
  AND e.user_id IS NULL
  AND coalesce(e.is_deleted, false) = false
  AND e.employment_status IN ('probation', 'active', 'confirmed', 'pending');
