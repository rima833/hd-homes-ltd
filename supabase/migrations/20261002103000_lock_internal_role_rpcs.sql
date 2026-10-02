-- Privilege escalation fix: internal role assignment was callable by anon
-- and did not check the caller. Other security-definer functions still invoke
-- these as the function owner.

REVOKE ALL ON FUNCTION public._apply_staff_role_to_user(uuid, text, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._apply_staff_role_to_user(uuid, text, uuid) FROM anon;
REVOKE ALL ON FUNCTION public._apply_staff_role_to_user(uuid, text, uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public._apply_staff_role_to_user(uuid, text, uuid) TO service_role;

REVOKE ALL ON FUNCTION public._apply_portal_role_to_user(uuid, text, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._apply_portal_role_to_user(uuid, text, uuid) FROM anon;
REVOKE ALL ON FUNCTION public._apply_portal_role_to_user(uuid, text, uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public._apply_portal_role_to_user(uuid, text, uuid) TO service_role;

-- Permission lookup returns another account's slugs only to staff.
CREATE OR REPLACE FUNCTION public.get_user_permission_slugs(
  target_user_id uuid DEFAULT auth.uid()
)
RETURNS text[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  WITH RECURSIVE denied AS (
    SELECT p.slug
    FROM public.user_permissions up
    JOIN public.permissions p ON p.id = up.permission_id
    WHERE up.user_id = target_user_id
      AND up.granted = false
      AND up.is_deleted = false
      AND (
        target_user_id IS NOT DISTINCT FROM auth.uid()
        OR public.is_staff(auth.uid())
      )
  ),
  role_tree AS (
    SELECT ur.role_id AS id, 1 AS depth
    FROM public.user_roles ur
    WHERE ur.user_id = target_user_id
      AND ur.is_deleted = false
      AND ur.status = 'active'
      AND (
        target_user_id IS NOT DISTINCT FROM auth.uid()
        OR public.is_staff(auth.uid())
      )
    UNION ALL
    SELECT r.parent_role_id, rt.depth + 1
    FROM role_tree rt
    JOIN public.roles r ON r.id = rt.id
    WHERE r.parent_role_id IS NOT NULL
      AND rt.depth < 12
      AND COALESCE(r.is_deleted, false) = false
  ),
  granted AS (
    SELECT p.slug
    FROM public.user_permissions up
    JOIN public.permissions p ON p.id = up.permission_id
    WHERE up.user_id = target_user_id
      AND up.granted = true
      AND up.is_deleted = false
      AND up.status = 'active'
      AND (
        target_user_id IS NOT DISTINCT FROM auth.uid()
        OR public.is_staff(auth.uid())
      )
    UNION
    SELECT p.slug
    FROM role_tree rt
    JOIN public.role_permissions rp ON rp.role_id = rt.id
    JOIN public.permissions p ON p.id = rp.permission_id
    WHERE COALESCE(rp.is_deleted, false) = false
      AND COALESCE(rp.status, 'active') = 'active'
      AND COALESCE(p.is_deleted, false) = false
  )
  SELECT COALESCE(array_agg(DISTINCT g.slug ORDER BY g.slug), ARRAY[]::text[])
  FROM granted g
  WHERE g.slug NOT IN (SELECT d.slug FROM denied d);
$$;
