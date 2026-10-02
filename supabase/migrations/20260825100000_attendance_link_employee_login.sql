-- Link employee records to auth logins (admin RPC)
CREATE OR REPLACE FUNCTION public.attendance_admin_link_employee_login(
  p_employee_id uuid,
  p_login_email text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid;
  v_email text;
BEGIN
  IF NOT public._attendance_can_manage() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'forbidden', 'message', 'Permission denied.');
  END IF;

  v_email := lower(trim(coalesce(p_login_email, '')));
  IF v_email = '' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'invalid', 'message', 'Login email is required.');
  END IF;

  SELECT id INTO v_uid FROM auth.users WHERE lower(email) = v_email LIMIT 1;
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'user_not_found', 'message', 'No auth account found for that email.');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.employees
    WHERE user_id = v_uid
      AND id <> p_employee_id
      AND coalesce(is_deleted, false) = false
  ) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'already_linked', 'message', 'That login is already linked to another employee.');
  END IF;

  UPDATE public.employees SET
    user_id = v_uid,
    email = coalesce(nullif(email, ''), v_email),
    work_email = coalesce(nullif(work_email, ''), v_email),
    updated_at = now(),
    updated_by = auth.uid()
  WHERE id = p_employee_id
    AND coalesce(is_deleted, false) = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'not_found', 'message', 'Employee not found.');
  END IF;

  PERFORM public._attendance_audit(
    'EMPLOYEE_LINK_LOGIN',
    'employee',
    p_employee_id,
    jsonb_build_object('login_email', v_email, 'user_id', v_uid)
  );

  RETURN jsonb_build_object('ok', true, 'user_id', v_uid, 'email', v_email);
END;
$$;

GRANT EXECUTE ON FUNCTION public.attendance_admin_link_employee_login(uuid, text) TO authenticated;

-- Seed link: Chinedu Eze ↔ diorima606@gmail.com
UPDATE public.employees e
SET
  user_id = u.id,
  work_email = coalesce(nullif(e.work_email, ''), u.email),
  email = coalesce(nullif(e.email, ''), u.email),
  updated_at = now()
FROM auth.users u
WHERE e.id = 'a9100001-0000-4000-8000-000000000003'
  AND lower(u.email) = 'diorima606@gmail.com'
  AND e.user_id IS NULL
  AND coalesce(e.is_deleted, false) = false;
