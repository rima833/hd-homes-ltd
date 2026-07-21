-- Volume 3 Part 10 — Activity Logs, Audit Trails & System Monitoring
-- Status: APPLIED remotely as activity_audit_observability (approved 2026-07-13).
-- Extends existing public.audit_logs and complements security_events / user_activity.

-- ---------------------------------------------------------------------------
-- Permissions
-- ---------------------------------------------------------------------------

INSERT INTO public.permissions (name, slug, module, description) VALUES
  ('View Audit Logs', 'view_audit_logs', 'observability', 'View enterprise audit and activity logs'),
  ('Export Audit Logs', 'export_audit_logs', 'observability', 'Export audit / compliance reports'),
  ('Manage Alerts', 'manage_alerts', 'observability', 'Acknowledge, assign, and resolve system alerts'),
  ('Manage Retention', 'manage_log_retention', 'observability', 'Configure log retention policies'),
  ('View Security Events', 'view_security_events', 'observability', 'View security monitoring events')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE r.slug IN ('super_admin', 'admin')
  AND p.slug IN (
    'view_audit_logs',
    'export_audit_logs',
    'manage_alerts',
    'manage_log_retention',
    'view_security_events'
  )
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Extend audit_logs (foundation table)
-- ---------------------------------------------------------------------------

ALTER TABLE public.audit_logs
  ADD COLUMN IF NOT EXISTS event_category TEXT NOT NULL DEFAULT 'system',
  ADD COLUMN IF NOT EXISTS severity TEXT NOT NULL DEFAULT 'info',
  ADD COLUMN IF NOT EXISTS result_status TEXT NOT NULL DEFAULT 'success',
  ADD COLUMN IF NOT EXISTS reason TEXT,
  ADD COLUMN IF NOT EXISTS correlation_id TEXT,
  ADD COLUMN IF NOT EXISTS request_id TEXT,
  ADD COLUMN IF NOT EXISTS actor_role TEXT,
  ADD COLUMN IF NOT EXISTS session_id TEXT,
  ADD COLUMN IF NOT EXISTS device TEXT,
  ADD COLUMN IF NOT EXISTS browser TEXT,
  ADD COLUMN IF NOT EXISTS operating_system TEXT,
  ADD COLUMN IF NOT EXISTS old_values JSONB,
  ADD COLUMN IF NOT EXISTS new_values JSONB;

-- Allow non-UUID entity identifiers without breaking existing UUID rows
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'audit_logs'
      AND column_name = 'entity_id'
      AND data_type = 'uuid'
  ) THEN
    ALTER TABLE public.audit_logs
      ALTER COLUMN entity_id TYPE TEXT USING entity_id::text;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_audit_logs_category_created
  ON public.audit_logs(event_category, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_severity_created
  ON public.audit_logs(severity, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_correlation
  ON public.audit_logs(correlation_id)
  WHERE correlation_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_audit_logs_module_action
  ON public.audit_logs(module, action, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity
  ON public.audit_logs(entity_type, entity_id)
  WHERE entity_type IS NOT NULL;

-- Immutability: block UPDATE/DELETE on live audit rows (archive soft-flag only via retention job)
CREATE OR REPLACE FUNCTION public.prevent_audit_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'audit_logs are immutable after creation';
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_logs_immutable ON public.audit_logs;
CREATE TRIGGER trg_audit_logs_immutable
  BEFORE UPDATE OR DELETE ON public.audit_logs
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_audit_mutation();

-- ---------------------------------------------------------------------------
-- User-facing activity timeline
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.activity_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  activity_type TEXT NOT NULL,
  module TEXT NOT NULL DEFAULT 'system',
  entity_type TEXT,
  entity_id TEXT,
  severity TEXT NOT NULL DEFAULT 'info',
  audit_log_id UUID REFERENCES public.audit_logs(id) ON DELETE SET NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_activity_logs_user_created
  ON public.activity_logs(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_logs_type
  ON public.activity_logs(activity_type, created_at DESC);

-- ---------------------------------------------------------------------------
-- System / API / jobs / integrations
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.system_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type TEXT NOT NULL,
  source TEXT NOT NULL DEFAULT 'platform',
  severity TEXT NOT NULL DEFAULT 'info',
  message TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_system_events_created
  ON public.system_events(created_at DESC);

CREATE TABLE IF NOT EXISTS public.api_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  method TEXT,
  path TEXT,
  status_code INT,
  latency_ms INT,
  user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  correlation_id TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_api_logs_created ON public.api_logs(created_at DESC);

CREATE TABLE IF NOT EXISTS public.background_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'queued',
  started_at TIMESTAMPTZ,
  finished_at TIMESTAMPTZ,
  error_message TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.integration_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider TEXT NOT NULL,
  operation TEXT NOT NULL,
  success BOOLEAN NOT NULL DEFAULT true,
  latency_ms INT,
  error_message TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Change history + Immutable Compliance Vault™
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.change_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  field_name TEXT NOT NULL,
  old_value TEXT,
  new_value TEXT,
  changed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  reviewer UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  audit_log_id UUID REFERENCES public.audit_logs(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_change_history_entity
  ON public.change_history(entity_type, entity_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.compliance_vault (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_log_id UUID REFERENCES public.audit_logs(id) ON DELETE SET NULL,
  event_category TEXT NOT NULL,
  action TEXT NOT NULL,
  entity_type TEXT,
  entity_id TEXT,
  snapshot JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.prevent_vault_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'compliance_vault snapshots are immutable';
END;
$$;

DROP TRIGGER IF EXISTS trg_compliance_vault_immutable ON public.compliance_vault;
CREATE TRIGGER trg_compliance_vault_immutable
  BEFORE UPDATE OR DELETE ON public.compliance_vault
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_vault_mutation();

-- ---------------------------------------------------------------------------
-- Alerts + assignments
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.system_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  severity TEXT NOT NULL DEFAULT 'warning',
  lifecycle TEXT NOT NULL DEFAULT 'open',
  source_module TEXT,
  audit_log_id UUID REFERENCES public.audit_logs(id) ON DELETE SET NULL,
  assigned_to UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  resolved_at TIMESTAMPTZ,
  resolved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_system_alerts_lifecycle
  ON public.system_alerts(lifecycle, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_system_alerts_severity
  ON public.system_alerts(severity, created_at DESC);

CREATE TABLE IF NOT EXISTS public.alert_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  alert_id UUID NOT NULL REFERENCES public.system_alerts(id) ON DELETE CASCADE,
  assignee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  assigned_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Health + metrics + retention + compliance reports
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.system_health (
  service_key TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'unknown',
  latency_ms INT,
  message TEXT,
  checked_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb
);

INSERT INTO public.system_health (service_key, label, status, message) VALUES
  ('database', 'Database', 'healthy', 'Seeded baseline'),
  ('realtime', 'Realtime', 'healthy', 'Seeded baseline'),
  ('auth', 'Authentication', 'healthy', 'Seeded baseline'),
  ('storage', 'Storage', 'healthy', 'Seeded baseline'),
  ('email', 'Email provider', 'degraded', 'Queued delivery (Phase 1)'),
  ('sms', 'SMS provider', 'degraded', 'Queued delivery (Phase 1)'),
  ('edge_functions', 'Edge Functions', 'unknown', 'Not probed in Phase 1')
ON CONFLICT (service_key) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.monitoring_metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  metric_key TEXT NOT NULL,
  metric_value NUMERIC NOT NULL,
  dimensions JSONB NOT NULL DEFAULT '{}'::jsonb,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_monitoring_metrics_key_time
  ON public.monitoring_metrics(metric_key, recorded_at DESC);

CREATE TABLE IF NOT EXISTS public.log_retention (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  log_class TEXT NOT NULL UNIQUE,
  retention_years INT NOT NULL DEFAULT 2,
  archive_after_days INT NOT NULL DEFAULT 365,
  description TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.log_retention (log_class, retention_years, archive_after_days, description) VALUES
  ('activity', 2, 365, 'User activity timeline'),
  ('security', 5, 730, 'Security monitoring events'),
  ('audit', 7, 1095, 'Enterprise audit trail'),
  ('system_metrics', 1, 180, 'Operational metrics')
ON CONFLICT (log_class) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.compliance_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_type TEXT NOT NULL,
  title TEXT NOT NULL,
  generated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  filters JSONB NOT NULL DEFAULT '{}'::jsonb,
  storage_path TEXT,
  status TEXT NOT NULL DEFAULT 'queued',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.event_metadata (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_log_id UUID REFERENCES public.audit_logs(id) ON DELETE CASCADE,
  key TEXT NOT NULL,
  value TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Central publish RPC (modules must not insert audit tables directly)
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
BEGIN
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
    );
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

GRANT EXECUTE ON FUNCTION public.publish_audit_event TO authenticated;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.api_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.background_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.integration_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.change_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.compliance_vault ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.alert_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_health ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.monitoring_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.log_retention ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.compliance_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_metadata ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS activity_logs_own ON public.activity_logs;
CREATE POLICY activity_logs_own ON public.activity_logs
  FOR SELECT USING (
    user_id = auth.uid()
    OR public.has_permission('view_audit_logs')
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS audit_logs_select ON public.audit_logs;
CREATE POLICY audit_logs_select ON public.audit_logs
  FOR SELECT USING (
    user_id = auth.uid()
    OR public.has_permission('view_audit_logs')
    OR public.has_permission('manage_reports')
    OR public.has_role('super_admin')
    OR public.has_role('admin')
  );

DROP POLICY IF EXISTS audit_logs_insert ON public.audit_logs;
CREATE POLICY audit_logs_insert ON public.audit_logs
  FOR INSERT WITH CHECK (
    auth.uid() IS NOT NULL
  );

DROP POLICY IF EXISTS system_alerts_staff ON public.system_alerts;
CREATE POLICY system_alerts_staff ON public.system_alerts
  FOR ALL USING (
    public.has_permission('manage_alerts')
    OR public.has_permission('view_security_events')
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS system_health_staff ON public.system_health;
CREATE POLICY system_health_staff ON public.system_health
  FOR SELECT USING (
    public.has_permission('view_audit_logs')
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS change_history_staff ON public.change_history;
CREATE POLICY change_history_staff ON public.change_history
  FOR SELECT USING (
    changed_by = auth.uid()
    OR public.has_permission('view_audit_logs')
    OR public.has_role('admin')
  );

DROP POLICY IF EXISTS compliance_vault_staff ON public.compliance_vault;
CREATE POLICY compliance_vault_staff ON public.compliance_vault
  FOR SELECT USING (
    public.has_permission('view_audit_logs')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS log_retention_staff ON public.log_retention;
CREATE POLICY log_retention_staff ON public.log_retention
  FOR SELECT USING (
    public.has_permission('manage_log_retention')
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS system_events_staff ON public.system_events;
CREATE POLICY system_events_staff ON public.system_events
  FOR SELECT USING (
    public.has_permission('view_audit_logs')
    OR public.has_role('admin')
  );

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.audit_logs;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.system_alerts;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.activity_logs;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
