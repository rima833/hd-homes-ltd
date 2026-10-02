-- Phase 2: Platform Control Center — settings security foundations.
-- Extends app_settings (no duplicate mega-tables), seeds portal/integration
-- keys, expands website feature flags, and adds a real health snapshot RPC.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1) Portal module flags (staff-only — not public)
-- ---------------------------------------------------------------------------
INSERT INTO public.app_settings (key, value, category, is_public, description)
VALUES (
  'portal_features',
  jsonb_build_object(
    'client', jsonb_build_object(
      'enabled', true,
      'welcome_message', 'Welcome to your HD Homes client portal.',
      'show_dashboard', true,
      'show_properties', true,
      'show_payments', true,
      'show_documents', true,
      'show_inspections', true,
      'show_construction', true,
      'show_messages', true,
      'show_support', true,
      'show_referrals', true,
      'show_notifications', true,
      'show_settings', true
    ),
    'investor', jsonb_build_object(
      'enabled', true,
      'welcome_message', 'Welcome to your HD Homes investor portal.',
      'show_dashboard', true,
      'show_portfolio', true,
      'show_analytics', true,
      'show_construction', true,
      'show_reports', true,
      'show_payments', true,
      'show_documents', true,
      'show_referrals', true,
      'show_messages', true,
      'show_support', true,
      'show_notifications', true,
      'show_settings', true
    )
  ),
  'portals',
  false,
  'Client and investor portal module visibility (staff-managed)'
)
ON CONFLICT (key) DO UPDATE
SET
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  is_public = false,
  is_deleted = false,
  status = 'active',
  updated_at = now(),
  -- Seed only when empty; never wipe admin portal configuration.
  value = CASE
    WHEN public.app_settings.value IS NULL
      OR public.app_settings.value = '{}'::jsonb
    THEN EXCLUDED.value
    ELSE public.app_settings.value
  END;

-- ---------------------------------------------------------------------------
-- 2) Integrations registry status (no secrets — staff-only)
-- ---------------------------------------------------------------------------
INSERT INTO public.app_settings (key, value, category, is_public, description)
VALUES (
  'integrations',
  jsonb_build_object(
    'supabase', jsonb_build_object('configured', true, 'notes', 'Primary data platform'),
    'cloudinary', jsonb_build_object('configured', false, 'notes', 'Verify Edge Function secrets'),
    'email', jsonb_build_object('configured', false, 'notes', 'Auth SMTP / transactional email'),
    'sms', jsonb_build_object('configured', false),
    'whatsapp', jsonb_build_object('configured', false),
    'analytics', jsonb_build_object('configured', false),
    'maps', jsonb_build_object('configured', false),
    'payments_online', jsonb_build_object('configured', false, 'notes', 'Bank transfer is primary')
  ),
  'integrations',
  false,
  'Integration registry status (no secrets)'
)
ON CONFLICT (key) DO UPDATE
SET
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  is_public = false,
  is_deleted = false,
  status = 'active',
  updated_at = now(),
  value = CASE
    WHEN public.app_settings.value IS NULL
      OR public.app_settings.value = '{}'::jsonb
    THEN EXCLUDED.value
    ELSE public.app_settings.value
  END;

-- ---------------------------------------------------------------------------
-- 3) Expand public website_features with additional toggles (non-destructive)
-- ---------------------------------------------------------------------------
UPDATE public.app_settings
SET
  value = COALESCE(value, '{}'::jsonb) || jsonb_build_object(
    'enable_blog', COALESCE((value ->> 'enable_blog')::boolean, true),
    'enable_testimonials', COALESCE((value ->> 'enable_testimonials')::boolean, true),
    'enable_partners', COALESCE((value ->> 'enable_partners')::boolean, true),
    'enable_faq', COALESCE((value ->> 'enable_faq')::boolean, true),
    'enable_newsletter', COALESCE((value ->> 'enable_newsletter')::boolean, true),
    'enable_contact_forms', COALESCE((value ->> 'enable_contact_forms')::boolean, true),
    'enable_property_listings', COALESCE((value ->> 'enable_property_listings')::boolean, true),
    'enable_featured_properties', COALESCE((value ->> 'enable_featured_properties')::boolean, true),
    'enable_investment_section', COALESCE((value ->> 'enable_investment_section')::boolean, true),
    'enable_construction_updates', COALESCE((value ->> 'enable_construction_updates')::boolean, true),
    'enable_client_portal_entry', COALESCE((value ->> 'enable_client_portal_entry')::boolean, true),
    'enable_investor_portal_entry', COALESCE((value ->> 'enable_investor_portal_entry')::boolean, true)
  ),
  updated_at = now()
WHERE key = 'website_features'
  AND coalesce(is_deleted, false) = false;

-- ---------------------------------------------------------------------------
-- 4) Real health snapshot RPC (staff / manage_settings)
-- Does NOT invent connected — probes live tables.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.platform_health_snapshot()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_keys int := 0;
  v_media_cloudinary int := 0;
  v_seo int := 0;
  v_last_settings public.app_settings%ROWTYPE;
  v_last_audit_at timestamptz;
  v_db_status text := 'connected';
  v_auth_status text := 'connected';
  v_cloudinary_status text := 'not_configured';
  v_seo_status text := 'warning';
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication_required';
  END IF;

  IF NOT (
    public.has_permission('manage_settings', v_uid)
    OR public.has_role('super_admin', v_uid)
    OR public.is_staff(v_uid)
  ) THEN
    RAISE EXCEPTION 'permission_denied';
  END IF;

  SELECT count(*)::int INTO v_keys
  FROM public.app_settings
  WHERE coalesce(is_deleted, false) = false;

  SELECT * INTO v_last_settings
  FROM public.app_settings
  WHERE coalesce(is_deleted, false) = false
  ORDER BY updated_at DESC NULLS LAST
  LIMIT 1;

  SELECT max(created_at) INTO v_last_audit_at
  FROM public.audit_logs
  WHERE module = 'platform_settings'
    AND coalesce(is_deleted, false) = false;

  BEGIN
    SELECT count(*)::int INTO v_media_cloudinary
    FROM public.media
    WHERE coalesce(is_deleted, false) = false
      AND nullif(trim(coalesce(cloudinary_public_id, '')), '') IS NOT NULL;
  EXCEPTION WHEN undefined_table OR undefined_column THEN
    v_media_cloudinary := 0;
  END;

  BEGIN
    SELECT count(*)::int INTO v_seo
    FROM public.seo_metadata
    WHERE path IS NOT NULL;
  EXCEPTION WHEN undefined_table THEN
    v_seo := 0;
  END;

  IF v_keys = 0 THEN
    v_db_status := 'warning';
  END IF;

  IF v_media_cloudinary > 0 THEN
    v_cloudinary_status := 'connected';
  ELSE
    v_cloudinary_status := 'not_configured';
  END IF;

  IF v_seo > 0 THEN
    v_seo_status := 'connected';
  END IF;

  RETURN jsonb_build_object(
    'checked_at', now(),
    'database', jsonb_build_object(
      'status', v_db_status,
      'notes', 'PostgreSQL reachable via RPC',
      'app_settings_keys', v_keys
    ),
    'authentication', jsonb_build_object(
      'status', v_auth_status,
      'notes', 'Authenticated session verified',
      'user_id', v_uid
    ),
    'cloudinary', jsonb_build_object(
      'status', v_cloudinary_status,
      'notes', CASE
        WHEN v_media_cloudinary > 0 THEN 'Media rows with Cloudinary public IDs present'
        ELSE 'No Cloudinary-linked media rows found'
      END,
      'assets_with_public_id', v_media_cloudinary
    ),
    'seo', jsonb_build_object(
      'status', v_seo_status,
      'notes', CASE
        WHEN v_seo > 0 THEN 'Path-level seo_metadata rows present'
        ELSE 'No seo_metadata path rows'
      END,
      'path_rows', v_seo
    ),
    'last_settings_update', jsonb_build_object(
      'at', v_last_settings.updated_at,
      'by', v_last_settings.updated_by,
      'key', v_last_settings.key
    ),
    'last_settings_audit_at', v_last_audit_at
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.platform_health_snapshot() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.platform_health_snapshot() TO authenticated;

-- Helpful index for Settings audit queries
CREATE INDEX IF NOT EXISTS audit_logs_platform_settings_idx
  ON public.audit_logs (module, created_at DESC)
  WHERE coalesce(is_deleted, false) = false
    AND module = 'platform_settings';

COMMIT;
