-- Client portal fix: property_inspections RLS for buyers (EAFMS owns public.inspections for assets)
-- APPLIED remotely 2026-07-22 as client_portal_property_inspections_rls

DROP POLICY IF EXISTS property_inspections_client_select ON public.property_inspections;
CREATE POLICY property_inspections_client_select ON public.property_inspections
  FOR SELECT TO authenticated
  USING (
    visitor_profile_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.client_properties cp
      JOIN public.clients c ON c.id = cp.client_id
      WHERE cp.property_id = property_inspections.property_id
        AND c.user_id = auth.uid()
        AND cp.is_deleted = false
    )
  );

DROP POLICY IF EXISTS property_inspections_client_insert ON public.property_inspections;
CREATE POLICY property_inspections_client_insert ON public.property_inspections
  FOR INSERT TO authenticated
  WITH CHECK (
    visitor_profile_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.client_properties cp
      JOIN public.clients c ON c.id = cp.client_id
      WHERE cp.property_id = property_inspections.property_id
        AND c.user_id = auth.uid()
        AND cp.is_deleted = false
    )
  );

DROP POLICY IF EXISTS property_inspections_client_update ON public.property_inspections;
CREATE POLICY property_inspections_client_update ON public.property_inspections
  FOR UPDATE TO authenticated
  USING (
    visitor_profile_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.client_properties cp
      JOIN public.clients c ON c.id = cp.client_id
      WHERE cp.property_id = property_inspections.property_id
        AND c.user_id = auth.uid()
        AND cp.is_deleted = false
    )
  )
  WITH CHECK (
    visitor_profile_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.client_properties cp
      JOIN public.clients c ON c.id = cp.client_id
      WHERE cp.property_id = property_inspections.property_id
        AND c.user_id = auth.uid()
        AND cp.is_deleted = false
    )
  );
