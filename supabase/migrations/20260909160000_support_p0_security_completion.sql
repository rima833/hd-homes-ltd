-- Support P0 completion:
-- * make the support_tickets view honor tickets RLS
-- * remove implicit PUBLIC execution from privileged support commands
-- * remove legacy broad ticket policies and grants
-- * provide a catalog-level deployment smoke check

BEGIN;

CREATE OR REPLACE VIEW public.support_tickets
WITH (security_invoker = true)
AS
SELECT *
FROM public.tickets
WHERE COALESCE(is_deleted, false) = false;

REVOKE ALL ON TABLE public.support_tickets FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.support_tickets TO authenticated;

-- Ticket mutations are command-only. SECURITY DEFINER functions below perform
-- their own ownership/permission checks; callers do not need table writes.
REVOKE ALL ON TABLE public.tickets FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON TABLE public.tickets FROM authenticated;
GRANT SELECT ON TABLE public.tickets TO authenticated;

DROP POLICY IF EXISTS tickets_client_insert ON public.tickets;
DROP POLICY IF EXISTS tickets_client_update ON public.tickets;
DROP POLICY IF EXISTS tickets_create ON public.tickets;
DROP POLICY IF EXISTS tickets_own ON public.tickets;
DROP POLICY IF EXISTS tickets_owner_update ON public.tickets;
DROP POLICY IF EXISTS tickets_staff ON public.tickets;
DROP POLICY IF EXISTS tickets_support_select ON public.tickets;
DROP POLICY IF EXISTS tickets_support_write ON public.tickets;

CREATE POLICY tickets_owner_select
ON public.tickets
FOR SELECT TO authenticated
USING (
  user_id = auth.uid()
  AND COALESCE(is_deleted, false) = false
);

CREATE POLICY tickets_support_select
ON public.tickets
FOR SELECT TO authenticated
USING (
  public.has_permission('support.read', auth.uid())
  OR public.has_permission('support.tickets', auth.uid())
  OR public.has_permission('manage_tickets', auth.uid())
  OR public.has_role('super_admin', auth.uid())
);

-- PostgreSQL grants EXECUTE to PUBLIC on new functions by default. Explicitly
-- close every privileged support command, including trigger-only functions.
REVOKE ALL ON FUNCTION public.create_support_ticket(
  text, text, text, text, uuid, uuid, text, text, uuid, text, text, text
) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.manage_support_ticket(
  uuid, text, text, text, uuid, uuid, uuid, uuid, uuid, text
) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.customer_transition_support_ticket(uuid, text)
  FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.create_support_ticket(
  text, text, text, text, uuid, uuid, text, text, uuid, text, text, text
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.manage_support_ticket(
  uuid, text, text, text, uuid, uuid, uuid, uuid, uuid, text
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.customer_transition_support_ticket(uuid, text)
  TO authenticated;

REVOKE ALL ON FUNCTION public.ensure_support_ticket_number()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.apply_support_ticket_lifecycle()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.support_ticket_on_change()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.support_ticket_message_on_insert()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sync_ticket_status_from_message()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.record_resolution_confirmation()
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.support_production_security_smoke()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'ok',
      COALESCE((
        SELECT c.reloptions @> ARRAY['security_invoker=true']
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public'
          AND c.relname = 'support_tickets'
      ), false)
      AND NOT has_function_privilege(
        'anon',
        'public.create_support_ticket(text,text,text,text,uuid,uuid,text,text,uuid,text,text,text)',
        'EXECUTE'
      )
      AND NOT has_function_privilege(
        'anon',
        'public.manage_support_ticket(uuid,text,text,text,uuid,uuid,uuid,uuid,uuid,text)',
        'EXECUTE'
      )
      AND NOT has_table_privilege('anon', 'public.support_tickets', 'SELECT')
      AND NOT has_table_privilege('authenticated', 'public.tickets', 'INSERT')
      AND NOT has_table_privilege('authenticated', 'public.tickets', 'UPDATE'),
    'support_view_security_invoker', COALESCE((
      SELECT c.reloptions @> ARRAY['security_invoker=true']
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public'
        AND c.relname = 'support_tickets'
    ), false),
    'anon_create_ticket_execute', has_function_privilege(
      'anon',
      'public.create_support_ticket(text,text,text,text,uuid,uuid,text,text,uuid,text,text,text)',
      'EXECUTE'
    ),
    'anon_manage_ticket_execute', has_function_privilege(
      'anon',
      'public.manage_support_ticket(uuid,text,text,text,uuid,uuid,uuid,uuid,uuid,text)',
      'EXECUTE'
    ),
    'anon_support_view_select',
      has_table_privilege('anon', 'public.support_tickets', 'SELECT'),
    'authenticated_ticket_insert',
      has_table_privilege('authenticated', 'public.tickets', 'INSERT'),
    'authenticated_ticket_update',
      has_table_privilege('authenticated', 'public.tickets', 'UPDATE'),
    'checked_at', now()
  );
$$;

REVOKE ALL ON FUNCTION public.support_production_security_smoke()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.support_production_security_smoke()
  TO authenticated;

COMMIT;
