-- Public reads for Website CMS → public site

DROP POLICY IF EXISTS cms_sections_public_read ON public.cms_sections;
CREATE POLICY cms_sections_public_read ON public.cms_sections
  FOR SELECT
  USING (COALESCE(is_visible, true) = true);

DROP POLICY IF EXISTS seo_metadata_public_read ON public.seo_metadata;
CREATE POLICY seo_metadata_public_read ON public.seo_metadata
  FOR SELECT
  USING (
    entity_type IN ('page', 'path', 'company', 'route')
    OR path IS NOT NULL
  );

DROP POLICY IF EXISTS employees_website_public_read ON public.employees;
CREATE POLICY employees_website_public_read ON public.employees
  FOR SELECT
  USING (
    COALESCE(is_deleted, false) = false
    AND COALESCE((metadata->>'show_on_website')::boolean, false) = true
  );

DROP POLICY IF EXISTS employees_cms_website_write ON public.employees;
CREATE POLICY employees_cms_website_write ON public.employees
  FOR UPDATE
  USING (
    public.is_staff()
    OR public.has_permission('manage_marketing')
    OR public.has_permission('marketing.cms')
  )
  WITH CHECK (
    public.is_staff()
    OR public.has_permission('manage_marketing')
    OR public.has_permission('marketing.cms')
  );

INSERT INTO public.cms_sections (section_key, section_type, title, sort_order, is_visible, content)
SELECT v.section_key, v.section_type, v.title, v.sort_order, true, v.content::jsonb
FROM (VALUES
  ('homepage_hero', 'hero', 'Hero', 0, '{"key":"hero"}'),
  ('homepage_featured_estates', 'featured_estates', 'Featured Estates', 1, '{"limit":6}'),
  ('homepage_featured_properties', 'featured_properties', 'Featured Properties', 2, '{"limit":6}'),
  ('homepage_testimonials', 'testimonials', 'Testimonials', 3, '{"limit":6}'),
  ('homepage_faq', 'faq', 'FAQ', 4, '{"limit":6}'),
  ('homepage_cta', 'cta', 'CTA', 5, '{"headline":"Book a private inspection today"}')
) AS v(section_key, section_type, title, sort_order, content)
WHERE NOT EXISTS (
  SELECT 1 FROM public.cms_sections s WHERE s.section_key = v.section_key
);

INSERT INTO public.faqs (question, answer, category, sort_order, status)
SELECT * FROM (VALUES
  ('What payment plans do you offer?', 'We offer flexible installment plans with competitive terms tailored to your budget.', 'Buying', 0, 'active'),
  ('Can I inspect properties before buying?', 'Yes. Book an inspection online or contact our sales team to schedule a visit.', 'Buying', 1, 'active'),
  ('Are your developments legally documented?', 'All estates include verified titles and transparent documentation.', 'Legal', 2, 'active')
) AS v(question, answer, category, sort_order, status)
WHERE NOT EXISTS (SELECT 1 FROM public.faqs WHERE COALESCE(is_deleted, false) = false);

INSERT INTO public.testimonials (client_name, client_title, content, rating, is_featured, status)
SELECT * FROM (VALUES
  ('Adaeze O.', 'Homeowner, Horizon Gardens', 'HD Homes delivered exactly what they promised. The quality and transparency throughout the process were exceptional.', 5, true, 'active'),
  ('Chukwuemeka I.', 'Investor', 'Their investment products offer clarity and consistent updates. I have diversified two portfolios with HD Homes.', 5, true, 'active')
) AS v(client_name, client_title, content, rating, is_featured, status)
WHERE NOT EXISTS (SELECT 1 FROM public.testimonials WHERE COALESCE(is_deleted, false) = false);

INSERT INTO public.banners (title, subtitle, link_url, sort_order, status)
SELECT * FROM (VALUES
  ('New estate launch — Horizon Gardens', 'Limited units with flexible payment plans.', '/estates', 0, 'active')
) AS v(title, subtitle, link_url, sort_order, status)
WHERE NOT EXISTS (SELECT 1 FROM public.banners WHERE COALESCE(is_deleted, false) = false);
