-- Ensure consultation admin tables are on supabase_realtime for live UI sync.
-- Idempotent: skips tables already in the publication.

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'consultation_bookings',
    'consultation_booking_events',
    'consultation_departments',
    'consultation_advisors',
    'consultation_types',
    'consultation_working_hours',
    'consultation_holidays',
    'consultation_settings'
  ]
  LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = t
    ) THEN
      EXECUTE format(
        'ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',
        t
      );
    END IF;
  END LOOP;
END $$;
