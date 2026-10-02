-- Enable realtime on portal construction photos for live gallery updates.

DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.construction_photos;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
END $$;
