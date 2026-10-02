-- Keep command-palette search tables on the realtime publication so the
-- analytics channel and the index channel can subscribe independently.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'search_index'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.search_index;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'search_history'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.search_history;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'favorite_commands'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.favorite_commands;
  END IF;
END $$;
