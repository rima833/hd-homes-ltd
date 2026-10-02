-- Live admin platform settings: expand app_settings contracts, sync legacy
-- company blob from seo_metadata, harden manage RLS, and publish Realtime.

BEGIN;

-- Staff / super-admin can manage; public keys remain publicly readable.
DROP POLICY IF EXISTS app_settings_select_staff ON public.app_settings;
CREATE POLICY app_settings_select_staff ON public.app_settings
  FOR SELECT TO authenticated
  USING (
    public.has_permission('manage_settings', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR public.is_staff(auth.uid())
  );

DROP POLICY IF EXISTS app_settings_manage ON public.app_settings;
CREATE POLICY app_settings_manage ON public.app_settings
  FOR ALL TO authenticated
  USING (
    public.has_permission('manage_settings', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('manage_settings', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

-- Seed / expand canonical public settings keys.
INSERT INTO public.app_settings (key, value, category, is_public, description)
VALUES
  (
    'company',
    jsonb_build_object(
      'name', 'HD Homes Limited',
      'tagline', 'Making Quality Housing Accessible',
      'country', 'Nigeria',
      'legal_name', 'HD Homes Limited',
      'registration_number', '',
      'timezone', 'Africa/Lagos'
    ),
    'general',
    true,
    'Company business profile'
  ),
  (
    'contact',
    jsonb_build_object(
      'email', '',
      'phone', '',
      'whatsapp', '',
      'address', '',
      'support_hours', 'Mon–Fri 9:00–18:00 WAT'
    ),
    'general',
    true,
    'Public contact channels'
  ),
  (
    'theme',
    jsonb_build_object(
      'primary', '#B48743',
      'secondary', '#5A5A5C',
      'accent', '#D4A34E',
      'background', '#000000',
      'text', '#FFFFFF'
    ),
    'branding',
    true,
    'Brand color references'
  ),
  (
    'seo',
    jsonb_build_object(
      'default_title', 'HD Homes Limited',
      'default_description', 'Making Quality Housing Accessible',
      'site_url', '',
      'og_image_url', '',
      'twitter_handle', ''
    ),
    'seo',
    true,
    'Default SEO metadata'
  ),
  (
    'social',
    jsonb_build_object(
      'facebook_url', '',
      'instagram_url', '',
      'twitter_url', '',
      'linkedin_url', '',
      'youtube_url', ''
    ),
    'branding',
    true,
    'Public social profile links'
  ),
  (
    'website_features',
    jsonb_build_object(
      'show_whatsapp_fab', true,
      'show_live_chat_fab', true,
      'show_call_fab_mobile', true,
      'show_book_fab_mobile', true,
      'enable_payment_calculator', true,
      'enable_roi_calculator', true,
      'enable_public_search', true
    ),
    'website',
    true,
    'Public website feature toggles'
  ),
  (
    'maintenance',
    jsonb_build_object(
      'enabled', false,
      'title', 'We will be right back',
      'message',
        'HD Homes is performing scheduled maintenance. Please check again shortly.',
      'allow_admin_bypass', true,
      'show_banner', false,
      'banner_message', ''
    ),
    'ops',
    true,
    'Maintenance mode and public banners'
  )
ON CONFLICT (key) DO UPDATE
SET
  category = EXCLUDED.category,
  is_public = EXCLUDED.is_public,
  description = COALESCE(public.app_settings.description, EXCLUDED.description),
  value = public.app_settings.value || EXCLUDED.value,
  updated_at = now(),
  is_deleted = false,
  status = 'active';

-- Migrate any legacy company blob from seo_metadata into app_settings.
DO $$
DECLARE
  v_meta jsonb;
BEGIN
  SELECT metadata
  INTO v_meta
  FROM public.seo_metadata
  WHERE entity_type = 'company'
    AND path = '/admin/company'
  ORDER BY updated_at DESC NULLS LAST
  LIMIT 1;

  IF v_meta IS NULL THEN
    RETURN;
  END IF;

  UPDATE public.app_settings
  SET
    value = value || jsonb_strip_nulls(
      jsonb_build_object(
        'name', NULLIF(trim(COALESCE(v_meta ->> 'company_name', '')), ''),
        'tagline', NULLIF(trim(COALESCE(v_meta ->> 'tagline', '')), ''),
        'legal_name', NULLIF(trim(COALESCE(v_meta ->> 'company_name', '')), '')
      )
    ),
    updated_at = now()
  WHERE key = 'company';

  UPDATE public.app_settings
  SET
    value = value || jsonb_strip_nulls(
      jsonb_build_object(
        'email', NULLIF(trim(COALESCE(v_meta ->> 'support_email', '')), ''),
        'phone', NULLIF(trim(COALESCE(v_meta ->> 'support_phone', '')), ''),
        'whatsapp', NULLIF(trim(COALESCE(v_meta ->> 'support_whatsapp', '')), ''),
        'address', NULLIF(trim(COALESCE(v_meta ->> 'address', '')), '')
      )
    ),
    updated_at = now()
  WHERE key = 'contact';

  UPDATE public.app_settings
  SET
    value = value || jsonb_strip_nulls(
      jsonb_build_object(
        'primary', NULLIF(trim(COALESCE(v_meta ->> 'brand_primary_color', '')), ''),
        'accent', NULLIF(trim(COALESCE(v_meta ->> 'brand_accent_color', '')), '')
      )
    ),
    updated_at = now()
  WHERE key = 'theme';

  UPDATE public.app_settings
  SET
    value = value || jsonb_strip_nulls(
      jsonb_build_object(
        'facebook_url', NULLIF(trim(COALESCE(v_meta ->> 'facebook_url', '')), ''),
        'instagram_url', NULLIF(trim(COALESCE(v_meta ->> 'instagram_url', '')), ''),
        'twitter_url', NULLIF(trim(COALESCE(v_meta ->> 'twitter_url', '')), '')
      )
    ),
    updated_at = now()
  WHERE key = 'social';
END $$;

CREATE OR REPLACE FUNCTION public.upsert_app_setting(
  p_key text,
  p_value jsonb,
  p_category text DEFAULT NULL,
  p_is_public boolean DEFAULT NULL,
  p_description text DEFAULT NULL
)
RETURNS public.app_settings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.app_settings;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication_required';
  END IF;

  IF NOT (
    public.has_permission('manage_settings', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN
    RAISE EXCEPTION 'permission_denied';
  END IF;

  IF NULLIF(trim(COALESCE(p_key, '')), '') IS NULL THEN
    RAISE EXCEPTION 'setting_key_required';
  END IF;

  INSERT INTO public.app_settings AS s (
    key,
    value,
    category,
    is_public,
    description,
    status,
    is_deleted
  )
  VALUES (
    trim(p_key),
    COALESCE(p_value, '{}'::jsonb),
    COALESCE(NULLIF(trim(COALESCE(p_category, '')), ''), 'general'),
    COALESCE(p_is_public, true),
    NULLIF(trim(COALESCE(p_description, '')), ''),
    'active',
    false
  )
  ON CONFLICT (key) DO UPDATE
  SET
    value = COALESCE(EXCLUDED.value, s.value),
    category = COALESCE(NULLIF(trim(COALESCE(p_category, '')), ''), s.category),
    is_public = COALESCE(p_is_public, s.is_public),
    description = COALESCE(
      NULLIF(trim(COALESCE(p_description, '')), ''),
      s.description
    ),
    updated_at = now(),
    updated_by = auth.uid(),
    status = 'active',
    is_deleted = false
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

REVOKE ALL ON FUNCTION public.upsert_app_setting(text, jsonb, text, boolean, text)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.upsert_app_setting(text, jsonb, text, boolean, text)
  FROM anon;
GRANT EXECUTE ON FUNCTION public.upsert_app_setting(text, jsonb, text, boolean, text)
  TO authenticated;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'app_settings'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.app_settings;
  END IF;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

COMMIT;
