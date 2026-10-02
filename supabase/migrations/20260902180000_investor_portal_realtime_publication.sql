-- Investor portal realtime publication parity with client portal.
-- Ensures holdings, conversations, reports, statements, and performance
-- stream live to the Flutter investor shell hub.

DO $$
DECLARE
  tbl text;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'portfolio_holdings',
    'investor_conversations',
    'investor_reports',
    'investor_statements',
    'investment_performance',
    'investor_preferences'
  ]
  LOOP
    IF EXISTS (
      SELECT 1
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public'
        AND c.relname = tbl
        AND c.relkind IN ('r', 'p')
    ) AND NOT EXISTS (
      SELECT 1
      FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = tbl
    ) THEN
      EXECUTE format(
        'ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',
        tbl
      );
    END IF;
  END LOOP;
END $$;
