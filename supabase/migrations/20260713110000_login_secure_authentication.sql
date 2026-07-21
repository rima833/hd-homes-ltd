-- Volume 3 Part 3 — Login & Secure Authentication
-- Status: APPLIED remotely as login_secure_authentication (approved 2026-07-13).
-- Adds SECURITY DEFINER helpers for durable audit + session registration.

-- ---------------------------------------------------------------------------
-- record_auth_event: login_history + authentication_logs + security_events
-- Callable by anon (failed login) and authenticated (success/logout).
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.record_auth_event(
  p_user_id UUID DEFAULT NULL,
  p_email TEXT DEFAULT NULL,
  p_action TEXT DEFAULT 'login',
  p_success BOOLEAN DEFAULT true,
  p_user_agent TEXT DEFAULT NULL,
  p_metadata JSONB DEFAULT '{}'::jsonb,
  p_severity public.security_event_severity DEFAULT 'info'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_log_id UUID;
BEGIN
  INSERT INTO public.authentication_logs (
    user_id, action, success, user_agent, metadata
  ) VALUES (
    p_user_id, p_action, p_success, p_user_agent,
    COALESCE(p_metadata, '{}'::jsonb) ||
      CASE WHEN p_email IS NOT NULL
        THEN jsonb_build_object('email', p_email)
        ELSE '{}'::jsonb
      END
  )
  RETURNING id INTO v_log_id;

  IF p_action IN ('login', 'login_failed') THEN
    INSERT INTO public.login_history (
      user_id, email, success, failure_reason, user_agent, metadata
    ) VALUES (
      p_user_id,
      p_email,
      p_success,
      CASE WHEN NOT p_success
        THEN COALESCE(p_metadata ->> 'reason', 'invalid_credentials')
        ELSE NULL
      END,
      p_user_agent,
      COALESCE(p_metadata, '{}'::jsonb)
    );
  END IF;

  IF p_action IN ('suspicious_login', 'account_suspended', 'session_revoked')
     OR (p_action = 'login_failed' AND COALESCE((p_metadata ->> 'attempt')::int, 0) >= 5)
  THEN
    INSERT INTO public.security_events (
      user_id, event_type, severity, description, user_agent, metadata
    ) VALUES (
      p_user_id,
      p_action,
      p_severity,
      p_action,
      p_user_agent,
      COALESCE(p_metadata, '{}'::jsonb) ||
        CASE WHEN p_email IS NOT NULL
          THEN jsonb_build_object('email', p_email)
          ELSE '{}'::jsonb
        END
    );
  END IF;

  RETURN v_log_id;
END;
$$;

REVOKE ALL ON FUNCTION public.record_auth_event(
  UUID, TEXT, TEXT, BOOLEAN, TEXT, JSONB, public.security_event_severity
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_auth_event(
  UUID, TEXT, TEXT, BOOLEAN, TEXT, JSONB, public.security_event_severity
) TO anon, authenticated;

-- ---------------------------------------------------------------------------
-- register_login_session: upsert device + create current session row
-- ---------------------------------------------------------------------------

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
    now(), true
  )
  ON CONFLICT (user_id, device_fingerprint) DO UPDATE SET
    device_name = COALESCE(EXCLUDED.device_name, public.trusted_devices.device_name),
    browser = COALESCE(EXCLUDED.browser, public.trusted_devices.browser),
    operating_system = COALESCE(EXCLUDED.operating_system, public.trusted_devices.operating_system),
    last_activity_at = now(),
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

REVOKE ALL ON FUNCTION public.register_login_session(
  UUID, TEXT, TEXT, TEXT, TEXT, TEXT, UUID
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.register_login_session(
  UUID, TEXT, TEXT, TEXT, TEXT, TEXT, UUID
) TO authenticated;

-- ---------------------------------------------------------------------------
-- revoke helpers
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.revoke_user_session(p_session_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.user_sessions
  SET
    revoked_at = now(),
    revoke_reason = 'user_revoked',
    is_current = false,
    updated_at = now()
  WHERE id = p_session_id
    AND user_id = auth.uid()
    AND revoked_at IS NULL;

  RETURN FOUND;
END;
$$;

REVOKE ALL ON FUNCTION public.revoke_user_session(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.revoke_user_session(UUID) TO authenticated;

-- Soft grants so client fallback inserts work when policies allow.
GRANT INSERT ON public.authentication_logs TO authenticated, anon;
GRANT INSERT ON public.login_history TO authenticated, anon;
GRANT INSERT ON public.security_events TO authenticated;
GRANT INSERT ON public.user_sessions TO authenticated;

DROP POLICY IF EXISTS authentication_logs_insert ON public.authentication_logs;
CREATE POLICY authentication_logs_insert ON public.authentication_logs
  FOR INSERT WITH CHECK (user_id IS NULL OR user_id = auth.uid());

DROP POLICY IF EXISTS login_history_insert ON public.login_history;
CREATE POLICY login_history_insert ON public.login_history
  FOR INSERT WITH CHECK (user_id IS NULL OR user_id = auth.uid());

DROP POLICY IF EXISTS user_sessions_insert ON public.user_sessions;
CREATE POLICY user_sessions_insert ON public.user_sessions
  FOR INSERT WITH CHECK (user_id = auth.uid());
