-- MFA trust: login session registration must not imply MFA trust.
-- Presence on a device is not the same as "Trust this device" (mfa_trusted_until).

CREATE OR REPLACE FUNCTION public.register_login_session(
  p_user_id UUID,
  p_device_fingerprint TEXT,
  p_device_name TEXT DEFAULT NULL,
  p_browser TEXT DEFAULT NULL,
  p_operating_system TEXT DEFAULT NULL,
  p_user_agent TEXT DEFAULT NULL,
  p_auth_session_id UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_device_id UUID;
  v_session_id UUID;
BEGIN
  IF auth.uid() IS DISTINCT FROM p_user_id
     AND NOT (public.has_role('admin') OR public.has_role('super_admin')) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  INSERT INTO public.trusted_devices (
    user_id, device_fingerprint, device_name, browser, operating_system,
    last_activity_at, is_trusted
  ) VALUES (
    p_user_id, p_device_fingerprint, p_device_name, p_browser, p_operating_system,
    now(), false
  )
  ON CONFLICT (user_id, device_fingerprint) DO UPDATE SET
    device_name = COALESCE(EXCLUDED.device_name, public.trusted_devices.device_name),
    browser = COALESCE(EXCLUDED.browser, public.trusted_devices.browser),
    operating_system = COALESCE(
      EXCLUDED.operating_system,
      public.trusted_devices.operating_system
    ),
    last_activity_at = now(),
    -- Preserve MFA trust window; only clear revoke if the device was soft-revoked
    -- for session tracking (does not grant MFA skip without mfa_trusted_until).
    revoked_at = NULL,
    updated_at = now()
  RETURNING id INTO v_device_id;

  UPDATE public.user_sessions
  SET is_current = false, updated_at = now()
  WHERE user_id = p_user_id AND is_current = true AND revoked_at IS NULL;

  INSERT INTO public.user_sessions (
    user_id, device_id, auth_session_id, user_agent, is_current, last_seen_at
  ) VALUES (
    p_user_id, v_device_id, p_auth_session_id, p_user_agent, true, now()
  )
  RETURNING id INTO v_session_id;

  RETURN v_session_id;
END;
$$;
