-- Inquiry counts on the listings desk listen to public.leads.
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.leads;
EXCEPTION
  WHEN duplicate_object THEN NULL;
  WHEN undefined_object THEN NULL;
  WHEN undefined_table THEN NULL;
END $$;
