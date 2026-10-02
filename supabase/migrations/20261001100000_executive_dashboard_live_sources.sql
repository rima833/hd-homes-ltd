-- Mission Control was summing a one-time demo analytics seed (24 views)
-- into Property Views, and several live tables were missing from Realtime.

DELETE FROM public.property_analytics_daily
WHERE views = 24
  AND favorites = 8
  AND bookings = 2
  AND inspections = 3
  AND leads = 6
  AND COALESCE(sales, 0) = 0
  AND COALESCE(revenue, 0) = 0
  AND traffic_sources = '{"direct":3,"organic":10,"paid":5,"referral":6}'::jsonb;

DROP POLICY IF EXISTS property_views_staff ON public.property_views;
CREATE POLICY property_views_staff ON public.property_views
  FOR SELECT TO authenticated
  USING (
    public.is_staff(auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR public.has_permission('manage_reports', auth.uid())
    OR public.has_permission('properties.read', auth.uid())
    OR public.has_permission('properties.analytics', auth.uid())
  );

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'property_views',
    'visitor_statistics',
    'marketing_analytics',
    'journey_analytics',
    'user_sessions'
  ]
  LOOP
    BEGIN
      EXECUTE format(
        'ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',
        t
      );
    EXCEPTION
      WHEN duplicate_object THEN NULL;
      WHEN undefined_table THEN NULL;
    END;
  END LOOP;
END $$;
