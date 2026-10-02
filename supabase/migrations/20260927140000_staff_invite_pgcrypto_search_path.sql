-- admin_invite_staff set search_path to public only, so pgcrypto
-- gen_random_bytes/digest (schema extensions) raised 42883 for signed-in admins.
ALTER FUNCTION public.admin_invite_staff(text, text, text, text, text, uuid, uuid)
  SET search_path TO public, extensions;
ALTER FUNCTION public.admin_invite_portal_user(text, text, text, text, text, uuid, uuid)
  SET search_path TO public, extensions;
ALTER FUNCTION public.admin_reveal_staff_invite_token(uuid)
  SET search_path TO public, extensions;
ALTER FUNCTION public.admin_reveal_portal_invite_token(uuid)
  SET search_path TO public, extensions;
ALTER FUNCTION public.staff_invite_token_hash(text)
  SET search_path TO public, extensions;

REVOKE EXECUTE ON FUNCTION public.admin_invite_staff(text, text, text, text, text, uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_invite_staff(text, text, text, text, text, uuid, uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.admin_invite_portal_user(text, text, text, text, text, uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_invite_portal_user(text, text, text, text, text, uuid, uuid) TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';

-- lpad(..., 4) truncates codes past 9999 (10001 becomes 1000) and collides.
CREATE OR REPLACE FUNCTION public.next_employee_code()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  SELECT 'HDH-EMP-' || CASE
    WHEN seq < 10000 THEN lpad(seq::text, 4, '0')
    ELSE seq::text
  END
  FROM (
    SELECT coalesce(
      max(nullif(substring(employee_code FROM '([0-9]+)$'), '')::bigint),
      0
    ) + 1 AS seq
    FROM public.employees
  ) s;
$$;

REVOKE ALL ON FUNCTION public.next_employee_code() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.next_employee_code() TO authenticated, service_role;

DO $$
DECLARE
  src text;
  old text := $old$SELECT 'HDH-EMP-' || lpad((coalesce(max(NULLIF(regexp_replace(employee_code, '\D', '', 'g'), '')::int), 0) + 1)::text, 4, '0')
    INTO v_code FROM public.employees;$old$;
BEGIN
  src := pg_get_functiondef('public.admin_invite_staff(text,text,text,text,text,uuid,uuid)'::regprocedure);
  IF position('next_employee_code' in src) = 0 THEN
    IF position(old in src) = 0 THEN
      RAISE EXCEPTION 'employee code select not found in admin_invite_staff';
    END IF;
    src := replace(src, old, 'SELECT public.next_employee_code() INTO v_code;');
    EXECUTE src;
  END IF;
END $$;

ALTER FUNCTION public.admin_invite_staff(text, text, text, text, text, uuid, uuid)
  SET search_path TO public, extensions;

NOTIFY pgrst, 'reload schema';
