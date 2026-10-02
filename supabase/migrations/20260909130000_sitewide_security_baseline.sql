-- Site-wide security baseline.
--
-- PostgreSQL row-level security does not apply to TRUNCATE. Supabase API
-- roles must never inherit that privilege on application tables.

BEGIN;

DO $$
DECLARE
  table_record record;
BEGIN
  FOR table_record IN
    SELECT schemaname, tablename
    FROM pg_tables
    WHERE schemaname = 'public'
  LOOP
    EXECUTE format(
      'REVOKE TRUNCATE ON TABLE %I.%I FROM anon, authenticated',
      table_record.schemaname,
      table_record.tablename
    );
  END LOOP;
END;
$$;

-- Compatibility views can retain table-like grants even though they are not
-- returned by pg_tables.
REVOKE TRUNCATE ON
  public.general_ledger_accounts,
  public.media_library,
  public.support_tickets,
  public.v_attendance_live
FROM anon, authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  REVOKE TRUNCATE ON TABLES FROM anon, authenticated;

-- Enforce enterprise-search visibility at the data boundary. Flutter also
-- filters results for UX, but client-side checks are not authorization.
DROP POLICY IF EXISTS search_index_read ON public.search_index;
CREATE POLICY search_index_read ON public.search_index
  FOR SELECT TO anon, authenticated
  USING (
    is_active = true
    AND (
      permission_slug IS NULL
      OR (
        auth.uid() IS NOT NULL
        AND (
          public.has_permission(permission_slug, auth.uid())
          OR public.has_role('admin', auth.uid())
          OR public.has_role('super_admin', auth.uid())
        )
      )
    )
  );

COMMIT;
