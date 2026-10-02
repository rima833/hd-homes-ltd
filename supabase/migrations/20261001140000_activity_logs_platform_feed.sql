-- Activity desk: group repeated alerts, score distinct issues, and
-- include module activity logs from the rest of the platform.

CREATE OR REPLACE FUNCTION public.collapse_duplicate_open_alert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_existing UUID;
BEGIN
  SELECT id INTO v_existing
  FROM public.system_alerts
  WHERE lifecycle IS DISTINCT FROM 'resolved'
    AND title = NEW.title
    AND severity = NEW.severity
    AND source_module IS NOT DISTINCT FROM NEW.source_module
    AND description IS NOT DISTINCT FROM NEW.description
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_existing IS NOT NULL THEN
    UPDATE public.system_alerts
    SET metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
          'occurrences', COALESCE((metadata->>'occurrences')::int, 1) + 1,
          'last_seen_at', now()
        )
    WHERE id = v_existing;
    RETURN NULL;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS system_alerts_collapse_dupes ON public.system_alerts;
CREATE TRIGGER system_alerts_collapse_dupes
  BEFORE INSERT ON public.system_alerts
  FOR EACH ROW
  EXECUTE FUNCTION public.collapse_duplicate_open_alert();

CREATE OR REPLACE FUNCTION public.resolve_open_alert_group(
  p_title TEXT,
  p_source_module TEXT,
  p_severity TEXT,
  p_lifecycle TEXT DEFAULT 'resolved'
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_count INT;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication_required' USING ERRCODE = '42501';
  END IF;
  IF NOT (
    public.has_permission('manage_alerts', v_uid)
    OR public.has_permission('view_security_events', v_uid)
    OR public.has_role('admin', v_uid)
    OR public.has_role('super_admin', v_uid)
  ) THEN
    RAISE EXCEPTION 'permission_denied' USING ERRCODE = '42501';
  END IF;

  UPDATE public.system_alerts
  SET lifecycle = CASE
        WHEN p_lifecycle = 'acknowledged' THEN 'acknowledged'
        ELSE 'resolved'
      END,
      resolved_at = CASE
        WHEN p_lifecycle = 'acknowledged' THEN resolved_at
        ELSE now()
      END,
      resolved_by = v_uid
  WHERE lifecycle IS DISTINCT FROM 'resolved'
    AND title = p_title
    AND severity = p_severity
    AND source_module IS NOT DISTINCT FROM p_source_module;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.resolve_open_alert_group(TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.resolve_open_alert_group(TEXT, TEXT, TEXT, TEXT) TO authenticated;

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
  v_open_issues INT;
  v_critical_alerts INT;
  v_warn_groups INT;
  v_error_groups INT;
  v_critical_groups INT;
  v_score INT;
  v_recent JSONB;
  v_alerts JSONB;
  v_health JSONB;
  v_modules JSONB;
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
  FROM (
    SELECT created_at FROM public.audit_logs WHERE created_at >= v_day
    UNION ALL
    SELECT COALESCE(occurred_at, created_at) FROM public.crm_activity_logs
      WHERE COALESCE(occurred_at, created_at) >= v_day
    UNION ALL
    SELECT occurred_at FROM public.sales_activity_logs WHERE occurred_at >= v_day
    UNION ALL
    SELECT occurred_at FROM public.project_activity_logs WHERE occurred_at >= v_day
    UNION ALL
    SELECT occurred_at FROM public.marketing_activity_logs WHERE occurred_at >= v_day
    UNION ALL
    SELECT occurred_at FROM public.finance_activity_logs WHERE occurred_at >= v_day
    UNION ALL
    SELECT COALESCE(occurred_at, created_at) FROM public.support_activity_logs
      WHERE COALESCE(occurred_at, created_at) >= v_day
    UNION ALL
    SELECT occurred_at FROM public.document_activity_logs WHERE occurred_at >= v_day
    UNION ALL
    SELECT COALESCE(occurred_at, created_at) FROM public.investor_activity_logs
      WHERE COALESCE(occurred_at, created_at) >= v_day
  ) today_events;

  SELECT COUNT(DISTINCT uid)::INT INTO v_active_users
  FROM (
    SELECT user_id::text AS uid
    FROM public.audit_logs
    WHERE created_at >= v_day AND user_id IS NOT NULL
    UNION
    SELECT actor_id::text
    FROM public.crm_activity_logs
    WHERE COALESCE(occurred_at, created_at) >= v_day AND actor_id IS NOT NULL
    UNION
    SELECT actor_id::text
    FROM public.investor_activity_logs
    WHERE COALESCE(occurred_at, created_at) >= v_day AND actor_id IS NOT NULL
  ) actors;

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

  SELECT
    COUNT(*)::INT,
    COUNT(*) FILTER (WHERE severity = 'warning')::INT,
    COUNT(*) FILTER (WHERE severity = 'error')::INT,
    COUNT(*) FILTER (WHERE severity IN ('critical', 'emergency'))::INT
  INTO v_open_issues, v_warn_groups, v_error_groups, v_critical_groups
  FROM (
    SELECT severity
    FROM public.system_alerts
    WHERE lifecycle IS DISTINCT FROM 'resolved'
    GROUP BY title, COALESCE(description, ''), severity, COALESCE(source_module, '')
  ) issues;

  -- Distinct open issues, so one repeated warning cannot pin the meter at 0.
  v_score := 100
    - (v_critical_groups * 25)
    - (v_error_groups * 12)
    - (v_warn_groups * 8)
    - ((v_failed_logins / 3) * 5);
  IF v_score < 0 THEN v_score := 0; END IF;
  IF v_score > 100 THEN v_score := 100; END IF;

  SELECT COALESCE(jsonb_agg(to_jsonb(a) ORDER BY a.created_at DESC), '[]'::jsonb)
  INTO v_recent
  FROM (
    SELECT *
    FROM (
      SELECT
        id::text AS id,
        action,
        module,
        COALESCE(event_category, 'system') AS event_category,
        COALESCE(severity, 'info') AS severity,
        COALESCE(result_status, 'success') AS result_status,
        created_at,
        user_id::text AS user_id,
        reason
      FROM public.audit_logs
      UNION ALL
      SELECT
        id::text,
        COALESCE(event_type, 'activity'),
        'crm',
        'crm',
        'info',
        'success',
        COALESCE(occurred_at, created_at),
        actor_id::text,
        description
      FROM public.crm_activity_logs
      UNION ALL
      SELECT
        id::text,
        COALESCE(event_type, 'activity'),
        'sales',
        'crm',
        'info',
        'success',
        occurred_at,
        NULL::text,
        description
      FROM public.sales_activity_logs
      UNION ALL
      SELECT
        id::text,
        COALESCE(event_type, 'activity'),
        'construction',
        'property',
        'info',
        'success',
        occurred_at,
        NULL::text,
        description
      FROM public.project_activity_logs
      UNION ALL
      SELECT
        id::text,
        COALESCE(action, 'activity'),
        'marketing',
        'communication',
        'info',
        'success',
        occurred_at,
        NULL::text,
        summary
      FROM public.marketing_activity_logs
      UNION ALL
      SELECT
        id::text,
        COALESCE(action, 'activity'),
        'finance',
        'payment',
        'info',
        'success',
        occurred_at,
        NULL::text,
        summary
      FROM public.finance_activity_logs
      UNION ALL
      SELECT
        id::text,
        COALESCE(action, 'activity'),
        'support',
        'support',
        'info',
        'success',
        COALESCE(occurred_at, created_at),
        NULL::text,
        summary
      FROM public.support_activity_logs
      UNION ALL
      SELECT
        id::text,
        COALESCE(action, 'activity'),
        'documents',
        'document',
        'info',
        'success',
        occurred_at,
        NULL::text,
        summary
      FROM public.document_activity_logs
      UNION ALL
      SELECT
        id::text,
        COALESCE(event_type, 'activity'),
        'investors',
        'investment',
        'info',
        'success',
        COALESCE(occurred_at, created_at),
        actor_id::text,
        description
      FROM public.investor_activity_logs
    ) feed
    WHERE created_at IS NOT NULL
    ORDER BY created_at DESC
    LIMIT 40
  ) a;

  SELECT COALESCE(jsonb_agg(to_jsonb(al) ORDER BY al.created_at DESC), '[]'::jsonb)
  INTO v_alerts
  FROM (
    SELECT
      (array_agg(id ORDER BY created_at DESC))[1] AS id,
      title,
      description,
      severity,
      lifecycle,
      source_module,
      COUNT(*)::INT AS event_count,
      MAX(created_at) AS created_at
    FROM public.system_alerts
    WHERE lifecycle IS DISTINCT FROM 'resolved'
    GROUP BY title, description, severity, lifecycle, source_module
    ORDER BY MAX(created_at) DESC
    LIMIT 20
  ) al;

  SELECT COALESCE(jsonb_agg(to_jsonb(h) ORDER BY h.service_key), '[]'::jsonb)
  INTO v_health
  FROM public.system_health h;

  SELECT COALESCE(jsonb_agg(to_jsonb(m) ORDER BY m.volume DESC), '[]'::jsonb)
  INTO v_modules
  FROM (
    SELECT module, SUM(cnt)::INT AS volume
    FROM (
      SELECT module, COUNT(*)::INT AS cnt FROM public.audit_logs GROUP BY module
      UNION ALL
      SELECT 'crm', COUNT(*)::INT FROM public.crm_activity_logs
      UNION ALL
      SELECT 'sales', COUNT(*)::INT FROM public.sales_activity_logs
      UNION ALL
      SELECT 'construction', COUNT(*)::INT FROM public.project_activity_logs
      UNION ALL
      SELECT 'marketing', COUNT(*)::INT FROM public.marketing_activity_logs
      UNION ALL
      SELECT 'finance', COUNT(*)::INT FROM public.finance_activity_logs
      UNION ALL
      SELECT 'support', COUNT(*)::INT FROM public.support_activity_logs
      UNION ALL
      SELECT 'documents', COUNT(*)::INT FROM public.document_activity_logs
      UNION ALL
      SELECT 'investors', COUNT(*)::INT FROM public.investor_activity_logs
    ) sources
    GROUP BY module
    HAVING SUM(cnt) > 0
  ) m;

  RETURN jsonb_build_object(
    'today_activity', v_today_activity,
    'active_users', v_active_users,
    'failed_logins', v_failed_logins,
    'open_alerts', v_open_alerts,
    'open_issues', v_open_issues,
    'critical_alerts', v_critical_alerts,
    'security_score', v_score,
    'recent_activity', v_recent,
    'alerts', v_alerts,
    'health', v_health,
    'platform_modules', v_modules,
    'generated_at', now()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.observability_command_center() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.observability_command_center() TO authenticated;

DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'crm_activity_logs',
    'sales_activity_logs',
    'project_activity_logs',
    'marketing_activity_logs',
    'finance_activity_logs',
    'support_activity_logs',
    'document_activity_logs',
    'investor_activity_logs'
  ]
  LOOP
    BEGIN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    EXCEPTION
      WHEN duplicate_object THEN NULL;
      WHEN undefined_object THEN NULL;
      WHEN undefined_table THEN NULL;
    END;
  END LOOP;
END $$;

COMMENT ON FUNCTION public.observability_command_center() IS
  'Staff activity desk: platform logs, grouped alerts, score from distinct open issues.';
