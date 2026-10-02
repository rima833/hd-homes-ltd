-- Phase 8: REPLICA IDENTITY FULL for people/RBAC filtered UPDATE payloads.
-- Ensures realtime UPDATE events include full row data when filters are added later.

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'employees',
    'teams',
    'departments',
    'staff_invitations',
    'portal_invitations',
    'roles',
    'role_permissions',
    'permissions',
    'user_roles',
    'permission_groups',
    'permission_group_items',
    'profiles'
  ]
  LOOP
    BEGIN
      EXECUTE format('ALTER TABLE public.%I REPLICA IDENTITY FULL', t);
    EXCEPTION
      WHEN undefined_table THEN NULL;
    END;
  END LOOP;
END $$;

-- Ensure leave_records stays in publication (org hub listens).
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.leave_records;
EXCEPTION
  WHEN duplicate_object THEN NULL;
  WHEN undefined_table THEN NULL;
END $$;
