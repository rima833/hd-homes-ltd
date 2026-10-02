-- Observability Command Center — realtime production hardening
-- Secures audit writes, server-side OCC metrics, health probe support,
-- critical→notifications fan-out, and system_health realtime.

-- ---------------------------------------------------------------------------
-- 1) Lock direct client inserts into audit_logs (writes via SECURITY DEFINER only)
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS audit_logs_insert ON public.audit_logs;

-- ---------------------------------------------------------------------------
-- 2) Helper: notify staff on critical/emergency alerts
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.notify_staff_of_critical_alert(
  p_alert_id UUID,
  p_title TEXT,
  p_description TEXT,
  p_severity TEXT,
  p_source_module TEXT DEFAULT NULL,
  p_audit_log_id UUID DEFAULT NULL
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INT := 0;
  r RECORD;
BEGIN
  FOR r IN
    SELECT DISTINCT u.user_id
    FROM (
      SELECT up.user_id
      FROM public.user_permissions up
      JOIN public.permissions p ON p.id = up.permission_id
      WHERE p.slug IN ('manage_alerts', 'view_audit_logs')
        AND up.granted = true
        AND up.is_deleted = false
        AND COALESCE(up.status, 'active') = 'active'
      UNION
      SELECT ur.user_id
      FROM public.user_roles ur
      JOIN public.roles ro ON ro.id = ur.role_id
      WHERE COALESCE(ur.is_deleted, false) = false
        AND COALESCE(ur.status, 'active') = 'active'
        AND (
          ro.slug IN ('admin', 'super_admin')
          OR EXISTS (
            SELECT 1
            FROM public.role_permissions rp
            JOIN public.permissions p2 ON p2.id = rp.permission_id
            WHERE rp.role_id = ro.id
              AND p2.slug IN ('manage_alerts', 'view_audit_logs')
              AND COALESCE(rp.is_deleted, false) = false
          )
        )
    ) u
  LOOP
    BEGIN
      INSERT INTO public.notifications (
        user_id, title, body, channel, category, type, priority,
        action_url, metadata, status, delivery_status
      ) VALUES (
        r.user_id,
        COALESCE(p_title, 'Critical system alert'),
        COALESCE(p_description, p_title, 'A critical alert requires attention.'),
        'in_app',
        'security',
        'critical_alert',
        CASE WHEN p_severity = 'emergency' THEN 'urgent' ELSE 'high' END,
        '/dashboard/activity-logs',
        jsonb_build_object(
          'alert_id', p_alert_id,
          'severity', p_severity,
          'source_module', p_source_module,
          'audit_log_id', p_audit_log_id
        ),
        'active',
        'delivered'
      );
      v_count := v_count + 1;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END LOOP;

  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.notify_staff_of_critical_alert(UUID, TEXT, TEXT, TEXT, TEXT, UUID) FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- 3) Hardened publish_audit_event (staff gate for JWT callers)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.publish_audit_event(
  p_id UUID DEFAULT gen_random_uuid(),
  p_user_id UUID DEFAULT NULL,
  p_action TEXT DEFAULT 'unknown',
  p_module TEXT DEFAULT 'system',
  p_event_category TEXT DEFAULT 'system',
  p_entity_type TEXT DEFAULT NULL,
  p_entity_id TEXT DEFAULT NULL,
  p_old_values JSONB DEFAULT NULL,
  p_new_values JSONB DEFAULT NULL,
  p_result_status TEXT DEFAULT 'success',
  p_severity TEXT DEFAULT 'info',
  p_reason TEXT DEFAULT NULL,
  p_correlation_id TEXT DEFAULT NULL,
  p_request_id TEXT DEFAULT NULL,
  p_actor_role TEXT DEFAULT NULL,
  p_session_id TEXT DEFAULT NULL,
  p_device TEXT DEFAULT NULL,
  p_browser TEXT DEFAULT NULL,
  p_operating_system TEXT DEFAULT NULL,
  p_user_agent TEXT DEFAULT NULL,
  p_metadata JSONB DEFAULT '{}'::jsonb,
  p_immutable BOOLEAN DEFAULT false,
  p_visible_to_user BOOLEAN DEFAULT true
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID := COALESCE(p_id, gen_random_uuid());
  v_key TEXT;
  v_old TEXT;
  v_new TEXT;
  v_alert_id UUID;
  v_jwt_role TEXT := coalesce(auth.jwt() ->> 'role', '');
  v_uid UUID := auth.uid();
  v_is_staff BOOLEAN := false;
BEGIN
  -- Authenticated PostgREST callers: staff may publish anything; others may
  -- only publish self-scoped non-critical events (domain RPCs under JWT).
  -- service_role / no-JWT (SQL internals) bypass the gate.
  IF v_jwt_role = 'authenticated' THEN
    IF v_uid IS NULL THEN
      RAISE EXCEPTION 'authentication_required' USING ERRCODE = '42501';
    END IF;
    v_is_staff :=
      public.has_permission('view_audit_logs', v_uid)
      OR public.has_permission('manage_alerts', v_uid)
      OR public.has_role('admin', v_uid)
      OR public.has_role('super_admin', v_uid);
    IF NOT v_is_staff THEN
      IF p_user_id IS NOT NULL AND p_user_id IS DISTINCT FROM v_uid THEN
        RAISE EXCEPTION 'permission_denied' USING ERRCODE = '42501';
      END IF;
      IF p_severity IN ('critical', 'emergency') THEN
        RAISE EXCEPTION 'permission_denied' USING ERRCODE = '42501';
      END IF;
    END IF;
  END IF;

  INSERT INTO public.audit_logs (
    id, user_id, action, module, entity_type, entity_id,
    user_agent, metadata, event_category, severity, result_status,
    reason, correlation_id, request_id, actor_role, session_id,
    device, browser, operating_system, old_values, new_values
  ) VALUES (
    v_id, p_user_id, p_action, p_module, p_entity_type, p_entity_id,
    p_user_agent, COALESCE(p_metadata, '{}'::jsonb), p_event_category,
    p_severity, p_result_status, p_reason, p_correlation_id, p_request_id,
    p_actor_role, p_session_id, p_device, p_browser, p_operating_system,
    p_old_values, p_new_values
  );

  IF p_visible_to_user AND p_user_id IS NOT NULL THEN
    INSERT INTO public.activity_logs (
      user_id, activity_type, module, entity_type, entity_id,
      severity, audit_log_id, metadata
    ) VALUES (
      p_user_id, p_action, p_module, p_entity_type, p_entity_id,
      p_severity, v_id, COALESCE(p_metadata, '{}'::jsonb)
    );
  END IF;

  IF p_old_values IS NOT NULL OR p_new_values IS NOT NULL THEN
    FOR v_key IN
      SELECT DISTINCT key FROM (
        SELECT jsonb_object_keys(COALESCE(p_old_values, '{}'::jsonb)) AS key
        UNION
        SELECT jsonb_object_keys(COALESCE(p_new_values, '{}'::jsonb)) AS key
      ) keys
    LOOP
      v_old := p_old_values ->> v_key;
      v_new := p_new_values ->> v_key;
      IF v_old IS DISTINCT FROM v_new THEN
        INSERT INTO public.change_history (
          entity_type, entity_id, field_name, old_value, new_value,
          changed_by, audit_log_id
        ) VALUES (
          COALESCE(p_entity_type, 'unknown'),
          COALESCE(p_entity_id, v_id::text),
          v_key, v_old, v_new, p_user_id, v_id
        );
      END IF;
    END LOOP;
  END IF;

  IF p_severity IN ('warning', 'error', 'critical', 'emergency') THEN
    INSERT INTO public.system_alerts (
      title, description, severity, lifecycle, source_module, audit_log_id, metadata
    ) VALUES (
      p_module || ': ' || p_action,
      COALESCE(p_reason, p_action),
      p_severity,
      'open',
      p_module,
      v_id,
      COALESCE(p_metadata, '{}'::jsonb)
    )
    RETURNING id INTO v_alert_id;

    IF p_severity IN ('critical', 'emergency') AND v_alert_id IS NOT NULL THEN
      PERFORM public.notify_staff_of_critical_alert(
        v_alert_id,
        p_module || ': ' || p_action,
        COALESCE(p_reason, p_action),
        p_severity,
        p_module,
        v_id
      );
    END IF;
  END IF;

  IF p_immutable THEN
    INSERT INTO public.compliance_vault (
      audit_log_id, event_category, action, entity_type, entity_id, snapshot
    ) VALUES (
      v_id, p_event_category, p_action, p_entity_type, p_entity_id,
      jsonb_build_object(
        'old_values', p_old_values,
        'new_values', p_new_values,
        'metadata', p_metadata,
        'user_id', p_user_id,
        'correlation_id', p_correlation_id
      )
    );
  END IF;

  IF p_event_category IN ('security', 'authentication') THEN
    INSERT INTO public.security_events (
      user_id, event_type, severity, description, user_agent, metadata
    ) VALUES (
      p_user_id,
      p_action,
      CASE
        WHEN p_severity IN ('critical', 'emergency') THEN 'critical'::public.security_event_severity
        WHEN p_severity IN ('warning', 'error') THEN 'warning'::public.security_event_severity
        ELSE 'info'::public.security_event_severity
      END,
      COALESCE(p_reason, p_action),
      p_user_agent,
      COALESCE(p_metadata, '{}'::jsonb)
    );
  END IF;

  RETURN v_id;
END;
$$;

-- Service-role-only publisher for Edge/cron/auth internals (no staff JWT gate)
CREATE OR REPLACE FUNCTION public.publish_system_audit_event(
  p_id UUID DEFAULT gen_random_uuid(),
  p_user_id UUID DEFAULT NULL,
  p_action TEXT DEFAULT 'unknown',
  p_module TEXT DEFAULT 'system',
  p_event_category TEXT DEFAULT 'system',
  p_entity_type TEXT DEFAULT NULL,
  p_entity_id TEXT DEFAULT NULL,
  p_old_values JSONB DEFAULT NULL,
  p_new_values JSONB DEFAULT NULL,
  p_result_status TEXT DEFAULT 'success',
  p_severity TEXT DEFAULT 'info',
  p_reason TEXT DEFAULT NULL,
  p_correlation_id TEXT DEFAULT NULL,
  p_request_id TEXT DEFAULT NULL,
  p_actor_role TEXT DEFAULT NULL,
  p_session_id TEXT DEFAULT NULL,
  p_device TEXT DEFAULT NULL,
  p_browser TEXT DEFAULT NULL,
  p_operating_system TEXT DEFAULT NULL,
  p_user_agent TEXT DEFAULT NULL,
  p_metadata JSONB DEFAULT '{}'::jsonb,
  p_immutable BOOLEAN DEFAULT false,
  p_visible_to_user BOOLEAN DEFAULT false
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID;
BEGIN
  -- Bypass JWT staff gate by calling as definer with role check deferred:
  -- only service_role / postgres may execute this (see grants below).
  -- Temporarily clear JWT role expectation by using internal insert path.
  SELECT public.publish_audit_event(
    p_id, p_user_id, p_action, p_module, p_event_category,
    p_entity_type, p_entity_id, p_old_values, p_new_values,
    p_result_status, p_severity, p_reason, p_correlation_id,
    p_request_id, p_actor_role, p_session_id, p_device, p_browser,
    p_operating_system, p_user_agent, p_metadata, p_immutable,
    p_visible_to_user
  ) INTO v_id;
  RETURN v_id;
END;
$$;

-- Fix: publish_system_audit_event calling publish_audit_event would still hit
-- JWT gate when invoked via PostgREST as service_role (jwt role = service_role).
-- service_role skips the authenticated branch — OK.
REVOKE ALL ON FUNCTION public.publish_system_audit_event FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.publish_system_audit_event TO service_role;

REVOKE ALL ON FUNCTION public.publish_audit_event FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.publish_audit_event TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 4) Auth: always record login failures into security_events
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
  v_sev public.security_event_severity;
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

  -- Always persist failed / suspicious auth into security_events for OCC KPIs.
  IF p_action IN ('login_failed', 'suspicious_login', 'account_suspended', 'session_revoked')
     OR (p_action = 'login' AND p_success = false)
  THEN
    v_sev := CASE
      WHEN p_action IN ('suspicious_login', 'account_suspended') THEN
        'critical'::public.security_event_severity
      WHEN COALESCE((p_metadata ->> 'attempt')::int, 0) >= 5 THEN
        'critical'::public.security_event_severity
      WHEN p_severity IS DISTINCT FROM 'info' THEN p_severity
      ELSE 'warning'::public.security_event_severity
    END;

    INSERT INTO public.security_events (
      user_id, event_type, severity, description, user_agent, metadata
    ) VALUES (
      p_user_id,
      CASE
        WHEN p_action = 'login' AND p_success = false THEN 'login_failed'
        ELSE p_action
      END,
      v_sev,
      COALESCE(p_metadata ->> 'reason', p_action),
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
) TO anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 5) Health upsert helper for Edge probe
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.upsert_system_health(
  p_service_key TEXT,
  p_label TEXT,
  p_status TEXT,
  p_latency_ms INT DEFAULT NULL,
  p_message TEXT DEFAULT NULL,
  p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.system_health (
    service_key, label, status, latency_ms, message, checked_at, metadata
  ) VALUES (
    p_service_key, p_label, p_status, p_latency_ms, p_message, now(),
    COALESCE(p_metadata, '{}'::jsonb)
  )
  ON CONFLICT (service_key) DO UPDATE SET
    label = EXCLUDED.label,
    status = EXCLUDED.status,
    latency_ms = EXCLUDED.latency_ms,
    message = EXCLUDED.message,
    checked_at = now(),
    metadata = EXCLUDED.metadata;
END;
$$;

REVOKE ALL ON FUNCTION public.upsert_system_health(TEXT, TEXT, TEXT, INT, TEXT, JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.upsert_system_health(TEXT, TEXT, TEXT, INT, TEXT, JSONB) TO service_role;

-- Clear stale Phase-1 seed copy so UI never shows placeholder messages.
UPDATE public.system_health
SET
  status = 'unknown',
  message = 'Awaiting first health probe',
  latency_ms = NULL,
  checked_at = now(),
  metadata = jsonb_build_object('awaiting_probe', true)
WHERE message ILIKE '%Phase 1%'
   OR message ILIKE '%Seeded baseline%'
   OR message ILIKE '%Not probed%';

-- ---------------------------------------------------------------------------
-- 6) observability_command_center() — server-side KPIs
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.observability_command_center()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_day TIMESTAMPTZ := date_trunc('day', now() AT TIME ZONE 'utc');
  v_today_activity INT;
  v_active_users INT;
  v_failed_logins INT;
  v_open_alerts INT;
  v_critical_alerts INT;
  v_score INT;
  v_recent JSONB;
  v_alerts JSONB;
  v_health JSONB;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication_required' USING ERRCODE = '42501';
  END IF;
  IF NOT (
    public.has_permission('view_audit_logs', v_uid)
    OR public.has_role('admin', v_uid)
    OR public.has_role('super_admin', v_uid)
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING ERRCODE = '42501';
  END IF;

  SELECT COUNT(*)::INT INTO v_today_activity
  FROM public.audit_logs
  WHERE created_at >= v_day;

  SELECT COUNT(DISTINCT user_id)::INT INTO v_active_users
  FROM public.audit_logs
  WHERE created_at >= v_day
    AND user_id IS NOT NULL;

  SELECT COUNT(*)::INT INTO v_failed_logins
  FROM (
    SELECT id::text AS sid FROM public.security_events
    WHERE created_at >= v_day
      AND (
        event_type IN ('login_failed', 'login_failure', 'failed_login')
        OR event_type ILIKE '%login%fail%'
      )
    UNION
    SELECT id::text FROM public.authentication_logs
    WHERE created_at >= v_day
      AND success = false
      AND action IN ('login', 'login_failed')
    UNION
    SELECT id::text FROM public.login_history
    WHERE created_at >= v_day
      AND success = false
  ) fails;

  SELECT COUNT(*)::INT INTO v_open_alerts
  FROM public.system_alerts
  WHERE lifecycle IS DISTINCT FROM 'resolved';

  SELECT COUNT(*)::INT INTO v_critical_alerts
  FROM public.system_alerts
  WHERE lifecycle IS DISTINCT FROM 'resolved'
    AND severity IN ('critical', 'emergency');

  v_score := 100
    - (v_critical_alerts * 15)
    - ((v_failed_logins / 3) * 5)
    - (v_open_alerts * 2);
  IF v_score < 0 THEN v_score := 0; END IF;
  IF v_score > 100 THEN v_score := 100; END IF;

  SELECT COALESCE(jsonb_agg(row_to_json(a)::jsonb ORDER BY a.created_at DESC), '[]'::jsonb)
  INTO v_recent
  FROM (
    SELECT *
    FROM public.audit_logs
    ORDER BY created_at DESC
    LIMIT 25
  ) a;

  SELECT COALESCE(jsonb_agg(row_to_json(al)::jsonb ORDER BY al.created_at DESC), '[]'::jsonb)
  INTO v_alerts
  FROM (
    SELECT *
    FROM public.system_alerts
    WHERE lifecycle IS DISTINCT FROM 'resolved'
    ORDER BY created_at DESC
    LIMIT 15
  ) al;

  SELECT COALESCE(jsonb_agg(row_to_json(h)::jsonb ORDER BY h.service_key), '[]'::jsonb)
  INTO v_health
  FROM public.system_health h;

  RETURN jsonb_build_object(
    'today_activity', v_today_activity,
    'active_users', v_active_users,
    'failed_logins', v_failed_logins,
    'open_alerts', v_open_alerts,
    'critical_alerts', v_critical_alerts,
    'security_score', v_score,
    'recent_activity', v_recent,
    'alerts', v_alerts,
    'health', v_health,
    'generated_at', now()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.observability_command_center() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.observability_command_center() TO authenticated;

-- ---------------------------------------------------------------------------
-- 7) Realtime: publish system_health
-- ---------------------------------------------------------------------------

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.system_health;
EXCEPTION
  WHEN duplicate_object THEN NULL;
  WHEN undefined_object THEN NULL;
END $$;

-- Staff may need UPDATE for probes only via service role; ensure SELECT stays.
DROP POLICY IF EXISTS system_health_staff ON public.system_health;
CREATE POLICY system_health_staff ON public.system_health
  FOR SELECT USING (
    public.has_permission('view_audit_logs')
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  );

COMMENT ON FUNCTION public.observability_command_center() IS
  'Staff OCC snapshot: live KPIs, alerts, health — no client-side heuristics.';
COMMENT ON FUNCTION public.publish_audit_event IS
  'Staff-gated audit fan-out; critical alerts notify staff via notifications.';
COMMENT ON FUNCTION public.upsert_system_health(TEXT, TEXT, TEXT, INT, TEXT, JSONB) IS
  'Service-role health probe upsert for Observability Command Center.';
