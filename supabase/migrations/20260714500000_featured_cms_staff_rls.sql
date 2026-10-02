-- Featured estates/properties CMS: cover flag + staff-friendly RLS
-- so Website admin can edit/upload without requiring edit_property alone.

ALTER TABLE public.estate_images
  ADD COLUMN IF NOT EXISTS is_cover boolean NOT NULL DEFAULT false;

ALTER TABLE public.estates
  ADD COLUMN IF NOT EXISTS price_from_label text,
  ADD COLUMN IF NOT EXISTS marketing_status text;

-- Estates: staff or property editors
DROP POLICY IF EXISTS estates_staff ON public.estates;
CREATE POLICY estates_staff ON public.estates FOR ALL USING (
  public.is_staff()
  OR public.has_permission('edit_property')
  OR public.has_permission('manage_marketing')
);

DROP POLICY IF EXISTS estate_images_staff ON public.estate_images;
CREATE POLICY estate_images_staff ON public.estate_images FOR ALL USING (
  public.is_staff()
  OR public.has_permission('edit_property')
  OR public.has_permission('manage_marketing')
);

-- Properties: staff or property editors
DROP POLICY IF EXISTS properties_staff ON public.properties;
CREATE POLICY properties_staff ON public.properties FOR ALL USING (
  public.is_staff()
  OR public.has_permission('create_property')
  OR public.has_permission('edit_property')
  OR public.has_permission('delete_property')
  OR public.has_permission('manage_marketing')
);

DROP POLICY IF EXISTS property_images_staff ON public.property_images;
CREATE POLICY property_images_staff ON public.property_images FOR ALL USING (
  public.is_staff()
  OR public.has_permission('edit_property')
  OR public.has_permission('manage_marketing')
);

DROP POLICY IF EXISTS property_locations_staff ON public.property_locations;
CREATE POLICY property_locations_staff ON public.property_locations FOR ALL USING (
  public.is_staff()
  OR public.has_permission('edit_property')
  OR public.has_permission('manage_marketing')
);

DROP POLICY IF EXISTS property_pricing_staff ON public.property_pricing;
CREATE POLICY property_pricing_staff ON public.property_pricing FOR ALL USING (
  public.is_staff()
  OR public.has_permission('edit_property')
  OR public.has_permission('manage_marketing')
);
