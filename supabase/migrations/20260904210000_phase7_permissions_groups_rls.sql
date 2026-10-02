-- Phase 7: permission groups RLS, inherited role permissions, catalog seeds.

-- ---------------------------------------------------------------------------
-- permission_group_items policies (table had RLS enabled with zero policies)
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS permission_group_items_read ON public.permission_group_items;
CREATE POLICY permission_group_items_read ON public.permission_group_items
  FOR SELECT USING (
    public.can_manage_rbac()
    OR public.has_permission('manage_roles')
    OR public.has_permission('configure_permissions')
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS permission_group_items_manage ON public.permission_group_items;
CREATE POLICY permission_group_items_manage ON public.permission_group_items
  FOR ALL USING (public.can_manage_rbac())
  WITH CHECK (public.can_manage_rbac());

-- Align group table manage policy with can_manage_rbac()
DROP POLICY IF EXISTS permission_groups_manage ON public.permission_groups;
CREATE POLICY permission_groups_manage ON public.permission_groups
  FOR ALL USING (public.can_manage_rbac())
  WITH CHECK (public.can_manage_rbac());

DROP POLICY IF EXISTS permission_groups_read ON public.permission_groups;
CREATE POLICY permission_groups_read ON public.permission_groups
  FOR SELECT USING (
    public.can_manage_rbac()
    OR public.has_permission('manage_roles')
    OR public.has_permission('configure_permissions')
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  );

-- ---------------------------------------------------------------------------
-- Inherited permissions via roles.parent_role_id
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.has_permission(
  permission_slug TEXT,
  target_user_id UUID DEFAULT auth.uid()
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF target_user_id IS NULL THEN
    RETURN false;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.user_permissions up
    JOIN public.permissions p ON p.id = up.permission_id
    WHERE up.user_id = target_user_id
      AND p.slug = permission_slug
      AND up.granted = false
      AND up.is_deleted = false
  ) THEN
    RETURN false;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.user_permissions up
    JOIN public.permissions p ON p.id = up.permission_id
    WHERE up.user_id = target_user_id
      AND p.slug = permission_slug
      AND up.granted = true
      AND up.is_deleted = false
      AND up.status = 'active'
  ) THEN
    RETURN true;
  END IF;

  RETURN EXISTS (
    WITH RECURSIVE role_tree AS (
      SELECT ur.role_id AS id, 1 AS depth
      FROM public.user_roles ur
      WHERE ur.user_id = target_user_id
        AND ur.is_deleted = false
        AND ur.status = 'active'
      UNION ALL
      SELECT r.parent_role_id, rt.depth + 1
      FROM role_tree rt
      JOIN public.roles r ON r.id = rt.id
      WHERE r.parent_role_id IS NOT NULL
        AND rt.depth < 12
        AND COALESCE(r.is_deleted, false) = false
    )
    SELECT 1
    FROM role_tree rt
    JOIN public.role_permissions rp ON rp.role_id = rt.id
    JOIN public.permissions p ON p.id = rp.permission_id
    WHERE p.slug = permission_slug
      AND COALESCE(rp.is_deleted, false) = false
      AND COALESCE(rp.status, 'active') = 'active'
      AND COALESCE(p.is_deleted, false) = false
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_user_permission_slugs(
  target_user_id UUID DEFAULT auth.uid()
)
RETURNS TEXT[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH RECURSIVE denied AS (
    SELECT p.slug
    FROM public.user_permissions up
    JOIN public.permissions p ON p.id = up.permission_id
    WHERE up.user_id = target_user_id
      AND up.granted = false
      AND up.is_deleted = false
  ),
  role_tree AS (
    SELECT ur.role_id AS id, 1 AS depth
    FROM public.user_roles ur
    WHERE ur.user_id = target_user_id
      AND ur.is_deleted = false
      AND ur.status = 'active'
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
    UNION
    SELECT p.slug
    FROM role_tree rt
    JOIN public.role_permissions rp ON rp.role_id = rt.id
    JOIN public.permissions p ON p.id = rp.permission_id
    WHERE COALESCE(rp.is_deleted, false) = false
      AND COALESCE(rp.status, 'active') = 'active'
      AND COALESCE(p.is_deleted, false) = false
  )
  SELECT COALESCE(array_agg(DISTINCT g.slug ORDER BY g.slug), ARRAY[]::TEXT[])
  FROM granted g
  WHERE g.slug NOT IN (SELECT d.slug FROM denied d);
$$;

REVOKE ALL ON FUNCTION public.has_permission(TEXT, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_user_permission_slugs(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.has_permission(TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_permission_slugs(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_permission(TEXT, UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_user_permission_slugs(UUID) TO service_role;

-- ---------------------------------------------------------------------------
-- Additional permission group bundles (people / RBAC)
-- ---------------------------------------------------------------------------

INSERT INTO public.permission_groups (name, slug, description) VALUES
  ('People Management', 'people_management', 'Staff directory, organization structure, invites'),
  ('Access Control', 'access_control', 'Roles, permission configuration, user administration')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.permission_group_items (group_id, permission_id)
SELECT g.id, p.id
FROM public.permission_groups g
JOIN public.permissions p ON (
  (g.slug = 'people_management' AND p.slug IN (
    'view_staff_directory', 'manage_staff', 'view_organization', 'manage_organization'
  ))
  OR (g.slug = 'access_control' AND p.slug IN (
    'manage_roles', 'configure_permissions', 'manage_users', 'view_users', 'view_audit_logs'
  ))
)
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.permission_group_items;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.permissions;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
