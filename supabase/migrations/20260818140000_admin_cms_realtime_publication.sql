-- Enable Supabase Realtime for website CMS + admin inbox tables used by the
-- Flutter admin portal (invalidates Riverpod providers on Postgres changes).

BEGIN;

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    -- Core website CMS
    'cms_sections',
    'hero_sections',
    'pages',
    'banners',
    'seo_metadata',
    'testimonials',
    'awards',
    'partners',
    'company_statistics',
    'faqs',
    'media',
    'media_folders',
    'media_library',
    -- Properties catalog
    'estates',
    'estate_images',
    'properties',
    'property_locations',
    'property_pricing',
    'property_images',
    'property_views',
    'leads',
    -- Hubs & directories
    'client_journey_steps',
    'journey_benefits',
    'office_locations',
    'office_hours',
    'office_media',
    'digital_company_profile',
    'website_browse_categories',
    'website_service_categories',
    'website_service_items',
    'website_service_case_studies',
    -- Careers & calculators
    'careers_settings',
    'career_jobs',
    'career_benefits',
    'career_stats',
    'career_tags',
    'calculator_settings',
    'calculator_payment_plans',
    'calculator_plan_properties',
    'calculator_applications',
    'roi_calculator_settings',
    -- Consultations
    'consultation_bookings',
    'consultation_departments',
    'consultation_advisors'
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

COMMIT;
