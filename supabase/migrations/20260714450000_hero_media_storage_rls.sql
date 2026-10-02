-- Homepage hero media: allow image/video uploads in marketing bucket,
-- and keep drafts private from the public website.

UPDATE storage.buckets
SET
  file_size_limit = 104857600,
  allowed_mime_types = ARRAY[
    'image/jpeg','image/png','image/webp','image/gif',
    'video/mp4','video/webm','video/quicktime'
  ]
WHERE id = 'marketing';

DROP POLICY IF EXISTS hero_public_read ON public.hero_sections;
CREATE POLICY hero_public_read ON public.hero_sections
  FOR SELECT TO anon, authenticated
  USING (COALESCE(is_deleted, false) = false AND status = 'active');

DROP POLICY IF EXISTS hero_staff_all ON public.hero_sections;
CREATE POLICY hero_staff_all ON public.hero_sections
  FOR ALL TO authenticated
  USING (
    public.is_staff()
    OR public.has_permission('marketing.write')
    OR public.has_permission('cms.write')
    OR public.has_permission('website.write')
  )
  WITH CHECK (
    public.is_staff()
    OR public.has_permission('marketing.write')
    OR public.has_permission('cms.write')
    OR public.has_permission('website.write')
  );
