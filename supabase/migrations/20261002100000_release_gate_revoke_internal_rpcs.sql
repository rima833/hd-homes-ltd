-- Release gate: internal helpers are not public RPCs, and ledger/media
-- views must follow the caller's row security.

DO $revoke$
DECLARE
  fn record;
BEGIN
  FOR fn IN
    SELECT p.oid::regprocedure AS signature
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname LIKE '\_%' ESCAPE '\'
  LOOP
    EXECUTE format(
      'REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated',
      fn.signature
    );
  END LOOP;
END
$revoke$;

ALTER VIEW public.general_ledger_accounts SET (security_invoker = true);
ALTER VIEW public.media_library SET (security_invoker = true);
