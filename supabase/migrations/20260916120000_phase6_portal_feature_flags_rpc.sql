-- Phase 6: Portal feature flags readable by authenticated portal users.
-- Staff continue to manage via upsert_app_setting / Control Center.
-- Does not expose integrations or other staff-only keys.

CREATE OR REPLACE FUNCTION public.portal_feature_flags(p_portal text)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_portal text := lower(trim(COALESCE(p_portal, '')));
  v_flags jsonb;
  v_allowed boolean := false;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication_required';
  END IF;

  IF v_portal NOT IN ('client', 'investor') THEN
    RAISE EXCEPTION 'invalid_portal';
  END IF;

  IF public.is_staff(auth.uid())
     OR public.has_permission('manage_settings', auth.uid())
     OR public.has_role('super_admin', auth.uid()) THEN
    v_allowed := true;
  ELSIF v_portal = 'client' THEN
    v_allowed := EXISTS (
      SELECT 1
      FROM public.clients c
      WHERE c.user_id = auth.uid()
        AND coalesce(c.is_deleted, false) = false
    );
  ELSIF v_portal = 'investor' THEN
    v_allowed := EXISTS (
      SELECT 1
      FROM public.investors i
      WHERE i.user_id = auth.uid()
        AND coalesce(i.is_deleted, false) = false
    );
  END IF;

  IF NOT v_allowed THEN
    RAISE EXCEPTION 'permission_denied';
  END IF;

  SELECT COALESCE(s.value -> v_portal, '{}'::jsonb)
  INTO v_flags
  FROM public.app_settings s
  WHERE s.key = 'portal_features'
    AND coalesce(s.is_deleted, false) = false
  LIMIT 1;

  RETURN jsonb_build_object(
    'portal', v_portal,
    'flags', COALESCE(v_flags, '{}'::jsonb)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.portal_feature_flags(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.portal_feature_flags(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.portal_feature_flags(text) TO authenticated;
