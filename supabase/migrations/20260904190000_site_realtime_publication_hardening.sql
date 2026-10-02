-- Site-wide realtime publication + client portal REPLICA IDENTITY hardening.
-- Restores CMS/public tables that were not on supabase_realtime, and ensures
-- client-scoped filtered UPDATEs deliver (REPLICA IDENTITY FULL).

DO $$
DECLARE
  tbl text;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    -- Client portal
    'clients',
    'client_properties',
    'client_timeline',
    'client_documents',
    'client_property_applications',
    'client_payment_intents',
    'payments',
    'installments',
    'payment_charges',
    'finance_receipts',
    'payment_verifications',
    'payment_methods',
    'payment_settings',
    'company_receiving_accounts',
    'construction_progress_updates',
    'construction_update_media',
    'construction_projects',
    'property_inspections',
    'favorite_items',
    'client_referral_commissions',
    'client_preferences',
    'client_conversations',
    'client_conversation_messages',
    'tickets',
    'ticket_messages',
    'faqs',
    -- Public / CMS website
    'hero_sections',
    'cms_sections',
    'pages',
    'banners',
    'seo_metadata',
    'testimonials',
    'awards',
    'partners',
    'company_statistics',
    'media',
    'media_folders',
    'media_library',
    'estates',
    'estate_images',
    'properties',
    'property_locations',
    'property_pricing',
    'property_images',
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
    'website_investment_opportunities',
    'website_investment_categories',
    'website_market_insights',
    'website_construction_updates',
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
    'consultation_bookings',
    'consultation_departments',
    'consultation_advisors',
    'menus',
    'team_members',
    'blogs',
    'blog_categories',
    'blog_authors',
    'notifications',
    'announcements'
  ]
  LOOP
    IF EXISTS (
      SELECT 1
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public'
        AND c.relname = tbl
        AND c.relkind IN ('r', 'p')
    ) AND NOT EXISTS (
      SELECT 1
      FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = tbl
    ) THEN
      EXECUTE format(
        'ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',
        tbl
      );
    END IF;
  END LOOP;
END $$;

-- Filtered client_id / user_id subscriptions need FULL replica identity.
DO $$
DECLARE
  tbl text;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'clients',
    'client_properties',
    'client_timeline',
    'client_documents',
    'client_property_applications',
    'client_payment_intents',
    'payments',
    'installments',
    'payment_charges',
    'client_referral_commissions',
    'client_preferences',
    'client_conversations',
    'client_conversation_messages',
    'favorite_items',
    'tickets',
    'ticket_messages',
    'faqs',
    'property_inspections',
    'finance_receipts',
    'payment_verifications',
    'company_receiving_accounts'
  ]
  LOOP
    IF EXISTS (
      SELECT 1
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public'
        AND c.relname = tbl
        AND c.relkind IN ('r', 'p')
    ) THEN
      EXECUTE format(
        'ALTER TABLE public.%I REPLICA IDENTITY FULL',
        tbl
      );
    END IF;
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.site_realtime_publication_smoke()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_needed text[] := ARRAY[
    'clients', 'client_properties', 'client_property_applications',
    'client_payment_intents', 'payments', 'faqs', 'hero_sections',
    'properties', 'calculator_settings', 'roi_calculator_settings'
  ];
  v_missing text[] := ARRAY[]::text[];
  t text;
BEGIN
  FOREACH t IN ARRAY v_needed LOOP
    IF EXISTS (
      SELECT 1 FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relname = t AND c.relkind IN ('r', 'p')
    ) AND NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = t
    ) THEN
      v_missing := array_append(v_missing, t);
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'ok', coalesce(array_length(v_missing, 1), 0) = 0,
    'checked_at', now(),
    'missing_publication', to_jsonb(v_missing)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.site_realtime_publication_smoke() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.site_realtime_publication_smoke() TO authenticated, service_role;
