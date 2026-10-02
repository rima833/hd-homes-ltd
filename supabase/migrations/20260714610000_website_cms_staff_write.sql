-- Widen staff write for Website CMS tables + public reads (idempotent companion)

DROP POLICY IF EXISTS cms_sections_staff_write ON public.cms_sections;
CREATE POLICY cms_sections_staff_write ON public.cms_sections
  FOR ALL
  USING (
    public.is_staff()
    OR public.has_permission('marketing.cms')
    OR public.has_permission('marketing.write')
    OR public.has_permission('manage_marketing')
    OR public.has_role('super_admin')
  )
  WITH CHECK (
    public.is_staff()
    OR public.has_permission('marketing.cms')
    OR public.has_permission('marketing.write')
    OR public.has_permission('manage_marketing')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS seo_metadata_staff_write ON public.seo_metadata;
CREATE POLICY seo_metadata_staff_write ON public.seo_metadata
  FOR ALL
  USING (
    public.is_staff()
    OR public.has_permission('marketing.seo')
    OR public.has_permission('marketing.write')
    OR public.has_permission('manage_marketing')
    OR public.has_role('super_admin')
  )
  WITH CHECK (
    public.is_staff()
    OR public.has_permission('marketing.seo')
    OR public.has_permission('marketing.write')
    OR public.has_permission('manage_marketing')
    OR public.has_role('super_admin')
  );
