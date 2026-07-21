-- Hotfix: restore EXECUTE on RBAC helper functions used by RLS.
-- Root cause: 20260710110006_security_hardening.sql revoked EXECUTE from
-- authenticated/anon without re-granting, so registration/login RLS failed with
-- 42501 permission denied for function has_permission.

GRANT EXECUTE ON FUNCTION public.get_user_role_slugs(UUID) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.has_role(TEXT, UUID) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.has_permission(TEXT, UUID) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.is_staff(UUID) TO authenticated, anon, service_role;

GRANT EXECUTE ON FUNCTION public.handle_new_user() TO postgres, service_role, supabase_auth_admin;
