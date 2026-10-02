-- Ensure inspection status history streams to the admin command center.
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.inspection_status_history;
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;
