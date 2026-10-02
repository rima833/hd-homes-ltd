-- Live inspection wizard: publish availability tables so slot/property
-- changes reach the public booking flow in realtime.
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'property_inspections',
    'property_inspection_config',
    'inspection_blocked_slots',
    'inspection_holidays',
    'inspection_working_hours',
    'inspection_settings',
    'inspection_agents',
    'estates'
  ]
  LOOP
    BEGIN
      EXECUTE format(
        'ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',
        t
      );
    EXCEPTION WHEN duplicate_object THEN
      NULL;
    END;
  END LOOP;
END $$;
