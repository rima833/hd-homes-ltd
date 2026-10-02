-- Allow public reads of homepage section rows even when hidden, so the
-- client can honor Admin → Website → Homepage visibility toggles.
-- Non-homepage cms_sections remain visible-only for anonymous users.

DROP POLICY IF EXISTS cms_sections_public_read ON public.cms_sections;
CREATE POLICY cms_sections_public_read ON public.cms_sections
  FOR SELECT
  USING (
    COALESCE(is_visible, true) = true
    OR section_key ILIKE 'homepage%'
  );

-- Public can read published CMS pages (About and other static pages).
DROP POLICY IF EXISTS pages_public_read ON public.pages;
CREATE POLICY pages_public_read ON public.pages
  FOR SELECT
  USING (
    COALESCE(is_deleted, false) = false
    AND COALESCE(is_published, false) = true
  );
