-- Volume 4 Part 10 — Enterprise Operations Center (EOC)
-- Status: APPLIED remotely 2026-07-15 (chunked enterprise_operations_center_p1–p3).
--
-- Approach:
--   • Do NOT recreate Part 1 tables:
--     executive_dashboards, executive_widget_catalog, widget_layouts /
--     dashboard_widgets, kpi_snapshots, executive_metrics,
--     business_health_scores, executive_notifications,
--     executive_activity_feed, ai_executive_insights,
--     executive_quick_actions, executive_reports, dashboard_preferences.
--   • ENRICH Part 1 + existing ai_conversations via ALTER ADD COLUMN IF NOT EXISTS.
--   • CREATE IF NOT EXISTS for NEW Part 10 / EOC tables (eoc_*, enterprise_*, workflows…).
--   • Seed UUIDs are hex-only (0-9a-f), prefixed e010….
--   • RLS: has_permission('slug', auth.uid()) — slug FIRST.
--   • Permissions: slug, name, description, module only (no action column).
--
-- Volume 4 continues Parts 11–25 after this part is approved.

BEGIN;

-- ---------------------------------------------------------------------------
-- Permissions
-- ---------------------------------------------------------------------------
INSERT INTO public.permissions (slug, name, description, module) VALUES
  ('eoc.read', 'View EOC', 'View Enterprise Operations Center / Mission Control', 'eoc'),
  ('eoc.write', 'Manage EOC', 'Create and edit EOC operational records', 'eoc'),
  ('eoc.kpis', 'EOC KPIs', 'View and manage enterprise KPI definitions and live values', 'eoc'),
  ('eoc.search', 'Enterprise Search', 'Use universal enterprise search and history', 'eoc'),
  ('eoc.ai', 'EOC AI Copilot', 'Use AI Enterprise Brain advisory tools', 'eoc'),
  ('eoc.workflows', 'EOC Workflows', 'Manage workflow definitions and instances', 'eoc'),
  ('eoc.approvals', 'EOC Approvals', 'Review and act on enterprise approval requests', 'eoc'),
  ('eoc.alerts', 'EOC Alerts', 'Manage enterprise operational alerts', 'eoc'),
  ('eoc.tasks', 'EOC Tasks', 'Manage enterprise executive tasks', 'eoc'),
  ('eoc.meetings', 'EOC Meetings', 'Manage meeting records and notes', 'eoc'),
  ('eoc.reports', 'EOC Reports', 'Generate and view EOC report templates/outputs', 'eoc'),
  ('eoc.analytics', 'EOC Analytics', 'View forecasts, scorecards, and predictive intelligence', 'eoc'),
  ('eoc.audit', 'EOC Audit', 'View EOC audit events and activity logs', 'eoc')
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  module = EXCLUDED.module,
  updated_at = now();

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE p.slug LIKE 'eoc.%'
  AND (
    r.slug IN ('super_admin', 'admin')
    OR (r.slug = 'finance' AND p.slug IN (
      'eoc.read', 'eoc.kpis', 'eoc.approvals', 'eoc.analytics', 'eoc.reports'
    ))
    OR (r.slug = 'sales_team' AND p.slug IN (
      'eoc.read', 'eoc.search', 'eoc.tasks'
    ))
    OR (r.slug = 'construction_manager' AND p.slug IN (
      'eoc.read', 'eoc.alerts', 'eoc.tasks'
    ))
    OR (r.slug = 'marketing' AND p.slug IN (
      'eoc.read', 'eoc.analytics', 'eoc.search'
    ))
  )
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Enrich Part 1 + existing AI workspace (do NOT recreate)
-- ---------------------------------------------------------------------------
ALTER TABLE public.executive_dashboards
  ADD COLUMN IF NOT EXISTS eoc_mode boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS command_center_slug text,
  ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}'::jsonb;

ALTER TABLE public.kpi_snapshots
  ADD COLUMN IF NOT EXISTS eoc_surface boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS module_slug text;

ALTER TABLE public.executive_metrics
  ADD COLUMN IF NOT EXISTS eoc_enabled boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS target_value numeric,
  ADD COLUMN IF NOT EXISTS unit text DEFAULT 'count';

ALTER TABLE public.ai_conversations
  ADD COLUMN IF NOT EXISTS eoc_scope text,
  ADD COLUMN IF NOT EXISTS surface text DEFAULT 'general',
  ADD COLUMN IF NOT EXISTS is_editable boolean DEFAULT true;

-- ---------------------------------------------------------------------------
-- EOC dashboards (separate from Part 1 executive_dashboards)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.eoc_dashboards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL DEFAULT 'Mission Control',
  slug text NOT NULL UNIQUE,
  description text,
  is_default boolean NOT NULL DEFAULT false,
  layout jsonb NOT NULL DEFAULT '[]'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.eoc_dashboard_widgets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  label text NOT NULL,
  category text NOT NULL DEFAULT 'ops',
  required_permission text,
  default_span int NOT NULL DEFAULT 1,
  sort_order int NOT NULL DEFAULT 100,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.eoc_dashboard_layouts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dashboard_id uuid NOT NULL REFERENCES public.eoc_dashboards(id) ON DELETE CASCADE,
  widget_id uuid NOT NULL REFERENCES public.eoc_dashboard_widgets(id) ON DELETE CASCADE,
  position int NOT NULL DEFAULT 0,
  span int NOT NULL DEFAULT 1,
  visible boolean NOT NULL DEFAULT true,
  config jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (dashboard_id, widget_id)
);

-- ---------------------------------------------------------------------------
-- Enterprise KPIs (definitions / targets / live) — parallel to kpi_snapshots
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.enterprise_kpi_definitions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  metric_key text NOT NULL UNIQUE,
  label text NOT NULL,
  category text NOT NULL DEFAULT 'ops',
  unit text NOT NULL DEFAULT 'count',
  description text,
  aggregation text NOT NULL DEFAULT 'latest',
  is_active boolean NOT NULL DEFAULT true,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.enterprise_kpi_targets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  definition_id uuid NOT NULL REFERENCES public.enterprise_kpi_definitions(id) ON DELETE CASCADE,
  period text NOT NULL DEFAULT 'monthly',
  target_value numeric NOT NULL DEFAULT 0,
  warn_below numeric,
  warn_above numeric,
  effective_from date,
  effective_to date,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.enterprise_kpis (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  definition_id uuid REFERENCES public.enterprise_kpi_definitions(id) ON DELETE SET NULL,
  metric_key text NOT NULL,
  label text NOT NULL,
  value numeric NOT NULL DEFAULT 0,
  previous_value numeric,
  unit text NOT NULL DEFAULT 'count',
  change_pct numeric,
  status text NOT NULL DEFAULT 'ok'
    CHECK (status IN ('ok','watch','critical','unknown')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  module_slug text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_enterprise_kpis_key_time
  ON public.enterprise_kpis (metric_key, captured_at DESC);

-- ---------------------------------------------------------------------------
-- Enterprise search
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.enterprise_search_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  query text NOT NULL,
  result_count int NOT NULL DEFAULT 0,
  modules text[] NOT NULL DEFAULT '{}',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  searched_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_enterprise_search_history_user
  ON public.enterprise_search_history (user_id, searched_at DESC);

-- ---------------------------------------------------------------------------
-- EOC AI prompts (ai_conversations already exists — enriched above)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ai_prompts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  title text NOT NULL,
  body text NOT NULL,
  category text NOT NULL DEFAULT 'eoc',
  surface text NOT NULL DEFAULT 'mission_control',
  is_active boolean NOT NULL DEFAULT true,
  is_editable boolean NOT NULL DEFAULT true,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Business Process Automation — workflows
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.workflow_definitions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  description text,
  module_slug text,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft','active','paused','archived')),
  version int NOT NULL DEFAULT 1,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.workflow_steps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  definition_id uuid NOT NULL REFERENCES public.workflow_definitions(id) ON DELETE CASCADE,
  step_key text NOT NULL,
  name text NOT NULL,
  step_order int NOT NULL DEFAULT 1,
  step_type text NOT NULL DEFAULT 'task'
    CHECK (step_type IN ('task','approval','condition','action','notify')),
  assignee_role text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (definition_id, step_key)
);

CREATE TABLE IF NOT EXISTS public.workflow_conditions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  step_id uuid NOT NULL REFERENCES public.workflow_steps(id) ON DELETE CASCADE,
  expression text NOT NULL,
  description text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS public.workflow_actions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  step_id uuid NOT NULL REFERENCES public.workflow_steps(id) ON DELETE CASCADE,
  action_type text NOT NULL DEFAULT 'notify',
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS public.workflow_instances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  definition_id uuid NOT NULL REFERENCES public.workflow_definitions(id) ON DELETE CASCADE,
  reference_label text,
  status text NOT NULL DEFAULT 'running'
    CHECK (status IN ('running','waiting','completed','failed','cancelled')),
  current_step_key text,
  started_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_workflow_instances_status
  ON public.workflow_instances (status, started_at DESC);

-- ---------------------------------------------------------------------------
-- Approvals
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.approval_workflows (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  module_slug text,
  min_approvers int NOT NULL DEFAULT 1,
  status text NOT NULL DEFAULT 'active',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.approval_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workflow_id uuid REFERENCES public.approval_workflows(id) ON DELETE SET NULL,
  title text NOT NULL,
  summary text,
  module_slug text,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','approved','rejected','cancelled','escalated')),
  amount numeric,
  currency text DEFAULT 'NGN',
  requested_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  due_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_approval_requests_status
  ON public.approval_requests (status, created_at DESC);

CREATE TABLE IF NOT EXISTS public.approval_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES public.approval_requests(id) ON DELETE CASCADE,
  action text NOT NULL,
  actor_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  note text,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

-- ---------------------------------------------------------------------------
-- Alerts, notifications, tasks
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.enterprise_alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  body text,
  severity text NOT NULL DEFAULT 'info'
    CHECK (severity IN ('info','warning','critical')),
  category text NOT NULL DEFAULT 'ops',
  module_slug text,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','acked','resolved','dismissed')),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_enterprise_alerts_status
  ON public.enterprise_alerts (status, created_at DESC);

-- Avoid collision with executive_notifications (Part 1)
CREATE TABLE IF NOT EXISTS public.eoc_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  body text,
  severity text NOT NULL DEFAULT 'info',
  category text NOT NULL DEFAULT 'eoc',
  is_read boolean NOT NULL DEFAULT false,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.enterprise_tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','in_progress','blocked','done','cancelled')),
  priority text NOT NULL DEFAULT 'medium'
    CHECK (priority IN ('low','medium','high','urgent')),
  module_slug text,
  assignee_label text,
  due_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_enterprise_tasks_status
  ON public.enterprise_tasks (status, due_at);

-- ---------------------------------------------------------------------------
-- Meetings & decisions
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.meeting_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  meeting_type text NOT NULL DEFAULT 'ops'
    CHECK (meeting_type IN ('ops','executive','board','standup','other')),
  scheduled_at timestamptz,
  location_label text,
  status text NOT NULL DEFAULT 'scheduled'
    CHECK (status IN ('scheduled','in_progress','completed','cancelled')),
  organizer_label text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.meeting_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meeting_id uuid NOT NULL REFERENCES public.meeting_records(id) ON DELETE CASCADE,
  body text NOT NULL,
  is_action_item boolean NOT NULL DEFAULT false,
  author_label text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.decision_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  decision text NOT NULL,
  rationale text,
  owners text[] NOT NULL DEFAULT '{}',
  impact text,
  status text NOT NULL DEFAULT 'recorded'
    CHECK (status IN ('recorded','reviewing','implemented','reversed')),
  decided_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

-- ---------------------------------------------------------------------------
-- Predictive intelligence
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.predictive_models (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  domain text NOT NULL DEFAULT 'revenue',
  status text NOT NULL DEFAULT 'active',
  version text NOT NULL DEFAULT '1.0',
  description text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.predictive_forecasts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  model_id uuid REFERENCES public.predictive_models(id) ON DELETE SET NULL,
  label text NOT NULL,
  horizon text NOT NULL DEFAULT '30d',
  predicted_value numeric NOT NULL DEFAULT 0,
  unit text NOT NULL DEFAULT 'count',
  confidence_pct numeric,
  scenario text NOT NULL DEFAULT 'base',
  captured_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

-- ---------------------------------------------------------------------------
-- Knowledge, reports, audit, scorecards, activity
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.knowledge_articles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  title text NOT NULL,
  body text NOT NULL,
  category text NOT NULL DEFAULT 'ops',
  status text NOT NULL DEFAULT 'published'
    CHECK (status IN ('draft','published','archived')),
  tags text[] NOT NULL DEFAULT '{}',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.eoc_report_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  description text,
  format text NOT NULL DEFAULT 'pdf',
  is_active boolean NOT NULL DEFAULT true,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.eoc_generated_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id uuid REFERENCES public.eoc_report_templates(id) ON DELETE SET NULL,
  title text NOT NULL,
  status text NOT NULL DEFAULT 'ready'
    CHECK (status IN ('queued','running','ready','failed')),
  generated_at timestamptz NOT NULL DEFAULT now(),
  file_url text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS public.eoc_audit_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  action text NOT NULL,
  entity_type text,
  entity_id text,
  summary text,
  actor_label text,
  severity text NOT NULL DEFAULT 'info',
  occurred_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_eoc_audit_events_time
  ON public.eoc_audit_events (occurred_at DESC);

CREATE TABLE IF NOT EXISTS public.executive_scorecards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  period text NOT NULL DEFAULT 'q3_2026',
  overall_score numeric,
  status text NOT NULL DEFAULT 'active',
  owner_label text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.executive_scorecard_metrics (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scorecard_id uuid NOT NULL REFERENCES public.executive_scorecards(id) ON DELETE CASCADE,
  metric_key text NOT NULL,
  label text NOT NULL,
  score numeric NOT NULL DEFAULT 0,
  weight numeric NOT NULL DEFAULT 1,
  target_value numeric,
  actual_value numeric,
  status text NOT NULL DEFAULT 'on_track',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (scorecard_id, metric_key)
);

CREATE TABLE IF NOT EXISTS public.eoc_activity_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  action text NOT NULL,
  summary text NOT NULL,
  actor_label text,
  module_slug text,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_eoc_activity_logs_time
  ON public.eoc_activity_logs (occurred_at DESC);

-- ---------------------------------------------------------------------------
-- Module health (Mission Control mosaic)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.eoc_module_health (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  module_slug text NOT NULL UNIQUE,
  label text NOT NULL,
  health_pct numeric NOT NULL DEFAULT 100,
  status text NOT NULL DEFAULT 'healthy'
    CHECK (status IN ('healthy','degraded','critical','unknown')),
  open_alerts int NOT NULL DEFAULT 0,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Seeds (hex-only UUIDs, e010 prefix)
-- ---------------------------------------------------------------------------
INSERT INTO public.eoc_dashboards (id, name, slug, description, is_default) VALUES
  ('e0100001-0000-4000-8000-000000000001', 'Enterprise Mission Control™', 'mission-control',
   'Cross-module command surface for HD Homes executives', true)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.eoc_dashboard_widgets (id, slug, label, category, required_permission, sort_order) VALUES
  ('e0100002-0000-4000-8000-000000000001', 'eoc_kpi_strip', 'KPI Strip', 'kpi', 'eoc.kpis', 10),
  ('e0100002-0000-4000-8000-000000000002', 'eoc_module_health', 'Module Health', 'ops', 'eoc.read', 20),
  ('e0100002-0000-4000-8000-000000000003', 'eoc_alerts', 'Live Alerts', 'ops', 'eoc.alerts', 30),
  ('e0100002-0000-4000-8000-000000000004', 'eoc_approvals', 'Approvals Queue', 'ops', 'eoc.approvals', 40),
  ('e0100002-0000-4000-8000-000000000005', 'eoc_ai_brief', 'AI Briefing', 'ai', 'eoc.ai', 50)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.eoc_dashboard_layouts (id, dashboard_id, widget_id, position, span) VALUES
  ('e0100003-0000-4000-8000-000000000001', 'e0100001-0000-4000-8000-000000000001', 'e0100002-0000-4000-8000-000000000001', 0, 4),
  ('e0100003-0000-4000-8000-000000000002', 'e0100001-0000-4000-8000-000000000001', 'e0100002-0000-4000-8000-000000000002', 1, 2),
  ('e0100003-0000-4000-8000-000000000003', 'e0100001-0000-4000-8000-000000000001', 'e0100002-0000-4000-8000-000000000003', 2, 2)
ON CONFLICT DO NOTHING;

INSERT INTO public.enterprise_kpi_definitions (id, metric_key, label, category, unit, description) VALUES
  ('e0100004-0000-4000-8000-000000000001', 'revenue_mtd', 'Revenue MTD', 'finance', 'currency', 'Month-to-date recognized revenue'),
  ('e0100004-0000-4000-8000-000000000002', 'sales_pipeline', 'Sales Pipeline', 'sales', 'currency', 'Open pipeline value'),
  ('e0100004-0000-4000-8000-000000000003', 'open_alerts', 'Open Alerts', 'ops', 'count', 'Unresolved enterprise alerts'),
  ('e0100004-0000-4000-8000-000000000004', 'pending_approvals', 'Pending Approvals', 'ops', 'count', 'Approvals awaiting action'),
  ('e0100004-0000-4000-8000-000000000005', 'active_workflows', 'Active Workflows', 'ops', 'count', 'Running automation instances'),
  ('e0100004-0000-4000-8000-000000000006', 'module_health_avg', 'Module Health', 'ops', 'percent', 'Average module health score'),
  ('e0100004-0000-4000-8000-000000000007', 'open_tasks', 'Open Tasks', 'ops', 'count', 'Enterprise tasks still open')
ON CONFLICT (metric_key) DO NOTHING;

INSERT INTO public.enterprise_kpi_targets (id, definition_id, period, target_value, warn_below) VALUES
  ('e0100005-0000-4000-8000-000000000001', 'e0100004-0000-4000-8000-000000000001', 'monthly', 250000000, 180000000),
  ('e0100005-0000-4000-8000-000000000002', 'e0100004-0000-4000-8000-000000000006', 'monthly', 90, 75)
ON CONFLICT DO NOTHING;

INSERT INTO public.enterprise_kpis (id, definition_id, metric_key, label, value, previous_value, unit, change_pct, status, module_slug) VALUES
  ('e0100006-0000-4000-8000-000000000001', 'e0100004-0000-4000-8000-000000000001', 'revenue_mtd', 'Revenue MTD', 218500000, 201200000, 'currency', 8.6, 'ok', 'finance'),
  ('e0100006-0000-4000-8000-000000000002', 'e0100004-0000-4000-8000-000000000002', 'sales_pipeline', 'Sales Pipeline', 412000000, 388000000, 'currency', 6.2, 'ok', 'sales'),
  ('e0100006-0000-4000-8000-000000000003', 'e0100004-0000-4000-8000-000000000003', 'open_alerts', 'Open Alerts', 4, 6, 'count', -33.3, 'watch', 'eoc'),
  ('e0100006-0000-4000-8000-000000000004', 'e0100004-0000-4000-8000-000000000004', 'pending_approvals', 'Pending Approvals', 7, 5, 'count', 40.0, 'watch', 'eoc'),
  ('e0100006-0000-4000-8000-000000000005', 'e0100004-0000-4000-8000-000000000005', 'active_workflows', 'Active Workflows', 12, 9, 'count', 33.3, 'ok', 'eoc'),
  ('e0100006-0000-4000-8000-000000000006', 'e0100004-0000-4000-8000-000000000006', 'module_health_avg', 'Module Health', 88, 86, 'percent', 2.3, 'ok', 'eoc'),
  ('e0100006-0000-4000-8000-000000000007', 'e0100004-0000-4000-8000-000000000007', 'open_tasks', 'Open Tasks', 15, 18, 'count', -16.7, 'ok', 'eoc')
ON CONFLICT DO NOTHING;

INSERT INTO public.eoc_module_health (id, module_slug, label, health_pct, status, open_alerts) VALUES
  ('e0100007-0000-4000-8000-000000000001', 'sales', 'Sales', 92, 'healthy', 0),
  ('e0100007-0000-4000-8000-000000000002', 'finance', 'Finance', 86, 'healthy', 1),
  ('e0100007-0000-4000-8000-000000000003', 'construction', 'Construction', 78, 'degraded', 2),
  ('e0100007-0000-4000-8000-000000000004', 'crm', 'CRM', 90, 'healthy', 0),
  ('e0100007-0000-4000-8000-000000000005', 'hr', 'HR', 84, 'healthy', 1),
  ('e0100007-0000-4000-8000-000000000006', 'marketing', 'Marketing', 88, 'healthy', 0)
ON CONFLICT (module_slug) DO NOTHING;

INSERT INTO public.ai_prompts (id, slug, title, body, category, surface, is_editable) VALUES
  ('e0100008-0000-4000-8000-000000000001', 'eoc_daily_brief', 'EOC Daily Brief',
   'Summarize open alerts, pending approvals, KPI variances, and top decisions for HD Homes Mission Control. Label output as AI-generated — editable / advisory.',
   'briefing', 'mission_control', true),
  ('e0100008-0000-4000-8000-000000000002', 'eoc_risk_scan', 'EOC Risk Scan',
   'Scan construction, finance, and sales risks; recommend owner actions. Advisory only.',
   'risk', 'mission_control', true)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.workflow_definitions (id, code, name, description, module_slug, status) VALUES
  ('e0100009-0000-4000-8000-000000000001', 'WF-PO-ESCALATION', 'Purchase Order Escalation',
   'Escalate POs above threshold for dual approval', 'finance', 'active'),
  ('e0100009-0000-4000-8000-000000000002', 'WF-SALES-CONTRACT', 'Sales Contract Routing',
   'Route signed contracts through legal and finance checks', 'sales', 'active'),
  ('e0100009-0000-4000-8000-000000000003', 'WF-SITE-INCIDENT', 'Site Incident Response',
   'Trigger HSE + construction alert chain', 'construction', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.workflow_steps (id, definition_id, step_key, name, step_order, step_type, assignee_role) VALUES
  ('e010000a-0000-4000-8000-000000000001', 'e0100009-0000-4000-8000-000000000001', 'submit', 'Submit PO', 1, 'task', 'finance'),
  ('e010000a-0000-4000-8000-000000000002', 'e0100009-0000-4000-8000-000000000001', 'manager_approval', 'Manager Approval', 2, 'approval', 'admin'),
  ('e010000a-0000-4000-8000-000000000003', 'e0100009-0000-4000-8000-000000000001', 'notify_ops', 'Notify Ops', 3, 'notify', 'admin'),
  ('e010000a-0000-4000-8000-000000000004', 'e0100009-0000-4000-8000-000000000002', 'legal_review', 'Legal Review', 1, 'approval', 'admin'),
  ('e010000a-0000-4000-8000-000000000005', 'e0100009-0000-4000-8000-000000000003', 'ack_site', 'Site Ack', 1, 'task', 'construction_manager')
ON CONFLICT DO NOTHING;

INSERT INTO public.workflow_conditions (id, step_id, expression, description) VALUES
  ('e010000b-0000-4000-8000-000000000001', 'e010000a-0000-4000-8000-000000000002',
   'amount > 5000000', 'Escalate PO above ₦5M')
ON CONFLICT DO NOTHING;

INSERT INTO public.workflow_actions (id, step_id, action_type, payload) VALUES
  ('e010000c-0000-4000-8000-000000000001', 'e010000a-0000-4000-8000-000000000003', 'notify',
   '{"channel":"eoc","message":"PO approved — update ledger"}'::jsonb)
ON CONFLICT DO NOTHING;

INSERT INTO public.workflow_instances (id, definition_id, reference_label, status, current_step_key) VALUES
  ('e010000d-0000-4000-8000-000000000001', 'e0100009-0000-4000-8000-000000000001', 'PO-2026-4481', 'waiting', 'manager_approval'),
  ('e010000d-0000-4000-8000-000000000002', 'e0100009-0000-4000-8000-000000000002', 'CTR-2026-119', 'running', 'legal_review'),
  ('e010000d-0000-4000-8000-000000000003', 'e0100009-0000-4000-8000-000000000003', 'INC-SITE-22', 'completed', 'ack_site')
ON CONFLICT DO NOTHING;

INSERT INTO public.approval_workflows (id, code, name, module_slug, min_approvers) VALUES
  ('e010000e-0000-4000-8000-000000000001', 'APPR-CAPEX', 'CapEx Dual Approval', 'finance', 2),
  ('e010000e-0000-4000-8000-000000000002', 'APPR-DISCOUNT', 'Sales Discount Approval', 'sales', 1)
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.approval_requests (id, workflow_id, title, summary, module_slug, status, amount, currency) VALUES
  ('e010000f-0000-4000-8000-000000000001', 'e010000e-0000-4000-8000-000000000001',
   'CapEx — Generator bank for Ikeja site', 'Backup power upgrade for Phase 2 plot', 'finance', 'pending', 18500000, 'NGN'),
  ('e010000f-0000-4000-8000-000000000002', 'e010000e-0000-4000-8000-000000000002',
   '8% discount — Plot B14 Lekki', 'VIP client discount request', 'sales', 'pending', 3200000, 'NGN'),
  ('e010000f-0000-4000-8000-000000000003', 'e010000e-0000-4000-8000-000000000001',
   'Marketing media kit refresh', 'Brand photography package', 'marketing', 'approved', 950000, 'NGN')
ON CONFLICT DO NOTHING;

INSERT INTO public.approval_history (id, request_id, action, note) VALUES
  ('e0100010-0000-4000-8000-000000000001', 'e010000f-0000-4000-8000-000000000003', 'approved', 'Within Q3 marketing budget'),
  ('e0100010-0000-4000-8000-000000000002', 'e010000f-0000-4000-8000-000000000001', 'submitted', 'Awaiting finance + admin')
ON CONFLICT DO NOTHING;

INSERT INTO public.enterprise_alerts (id, title, body, severity, category, module_slug, status) VALUES
  ('e0100011-0000-4000-8000-000000000001', 'Construction schedule slip — Block C',
   'Milestone concrete pour delayed 4 days; weather + vendor lag.', 'warning', 'schedule', 'construction', 'open'),
  ('e0100011-0000-4000-8000-000000000002', 'Collections aging — 3 accounts > 30d',
   'Finance flagged overdue client installments.', 'critical', 'collections', 'finance', 'open'),
  ('e0100011-0000-4000-8000-000000000003', 'Marketing campaign CTR below target',
   'Lekki launch campaign CTR 0.9% vs 1.5% target.', 'info', 'campaign', 'marketing', 'acked'),
  ('e0100011-0000-4000-8000-000000000004', 'HR leave backlog',
   '5 leave requests pending manager action.', 'warning', 'workforce', 'hr', 'open')
ON CONFLICT DO NOTHING;

INSERT INTO public.eoc_notifications (id, title, body, severity, category) VALUES
  ('e0100012-0000-4000-8000-000000000001', 'Mission Control sync', 'EOC snapshot refreshed with live KPI deltas.', 'info', 'system'),
  ('e0100012-0000-4000-8000-000000000002', 'Approval escalation', 'CapEx generator bank awaiting second approver.', 'warning', 'approvals')
ON CONFLICT DO NOTHING;

INSERT INTO public.enterprise_tasks (id, title, description, status, priority, module_slug, assignee_label, due_at) VALUES
  ('e0100013-0000-4000-8000-000000000001', 'Clear CapEx dual approval', 'Route generator PO to CFO + COO', 'open', 'urgent', 'finance', 'CFO Desk', now() + interval '1 day'),
  ('e0100013-0000-4000-8000-000000000002', 'Site catch-up plan Block C', 'Publish recovery schedule with CPMS', 'in_progress', 'high', 'construction', 'Site Ops', now() + interval '2 day'),
  ('e0100013-0000-4000-8000-000000000003', 'Collections call list', 'Contact 3 aging accounts', 'open', 'high', 'finance', 'AR Lead', now() + interval '1 day'),
  ('e0100013-0000-4000-8000-000000000004', 'Refine Lekki creatives', 'A/B test new hero creative', 'open', 'medium', 'marketing', 'Growth', now() + interval '5 day')
ON CONFLICT DO NOTHING;

INSERT INTO public.meeting_records (id, title, meeting_type, scheduled_at, location_label, status, organizer_label) VALUES
  ('e0100014-0000-4000-8000-000000000001', 'Weekly Ops Sync', 'ops', now() + interval '1 day', 'Lagos HQ Boardroom', 'scheduled', 'COO Office'),
  ('e0100014-0000-4000-8000-000000000002', 'Executive KPI Review', 'executive', now() + interval '3 day', 'Virtual', 'scheduled', 'CEO Office')
ON CONFLICT DO NOTHING;

INSERT INTO public.meeting_notes (id, meeting_id, body, is_action_item, author_label) VALUES
  ('e0100015-0000-4000-8000-000000000001', 'e0100014-0000-4000-8000-000000000001',
   'Prioritize CapEx dual approval before Friday close.', true, 'Ops Admin'),
  ('e0100015-0000-4000-8000-000000000002', 'e0100014-0000-4000-8000-000000000001',
   'Block C recovery plan to be shared in CPMS.', true, 'Site Ops')
ON CONFLICT DO NOTHING;

INSERT INTO public.decision_logs (id, title, decision, rationale, owners, impact, status) VALUES
  ('e0100016-0000-4000-8000-000000000001', 'Accelerate Lekki Phase 2 launch',
   'Pull forward launch window by 2 weeks', 'Pipeline demand + marketing readiness',
   ARRAY['CEO','CMO'], 'Revenue pull-forward / delivery risk', 'reviewing'),
  ('e0100016-0000-4000-8000-000000000002', 'Pause non-critical CapEx',
   'Hold non-site CapEx under ₦2M for 30 days', 'Protect cash for collections recovery',
   ARRAY['CFO'], 'Working capital preservation', 'implemented')
ON CONFLICT DO NOTHING;

INSERT INTO public.predictive_models (id, code, name, domain, status, version, description) VALUES
  ('e0100017-0000-4000-8000-000000000001', 'PM-REV-30D', '30-day Revenue Forecast', 'revenue', 'active', '1.2',
   'Short-horizon revenue prediction for Mission Control'),
  ('e0100017-0000-4000-8000-000000000002', 'PM-PIPE-CLOSE', 'Pipeline Close Probability', 'sales', 'active', '1.0',
   'Weighted close likelihood across open deals')
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.predictive_forecasts (id, model_id, label, horizon, predicted_value, unit, confidence_pct, scenario) VALUES
  ('e0100018-0000-4000-8000-000000000001', 'e0100017-0000-4000-8000-000000000001',
   'Revenue next 30d', '30d', 95000000, 'currency', 72, 'base'),
  ('e0100018-0000-4000-8000-000000000002', 'e0100017-0000-4000-8000-000000000001',
   'Revenue next 30d (upside)', '30d', 112000000, 'currency', 58, 'upside'),
  ('e0100018-0000-4000-8000-000000000003', 'e0100017-0000-4000-8000-000000000002',
   'Expected closes (units)', '30d', 14, 'count', 66, 'base')
ON CONFLICT DO NOTHING;

INSERT INTO public.knowledge_articles (id, slug, title, body, category, status, tags) VALUES
  ('e0100019-0000-4000-8000-000000000001', 'eoc-playbook-alerts', 'EOC Alert Triage Playbook',
   'Severity critical → page owner within 15m; warning → same-day; info → backlog. Always log resolution in eoc_activity_logs.',
   'ops', 'published', ARRAY['alerts','playbook']),
  ('e0100019-0000-4000-8000-000000000002', 'eoc-approval-sla', 'Approval SLA Guide',
   'CapEx dual approval SLA is 48h; discounts above 5% require sales lead + finance.',
   'governance', 'published', ARRAY['approvals','sla'])
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.eoc_report_templates (id, code, name, description, format) VALUES
  ('e010001a-0000-4000-8000-000000000001', 'RPT-EOC-DAILY', 'EOC Daily Ops Pack', 'Alerts, approvals, KPIs, tasks', 'pdf'),
  ('e010001a-0000-4000-8000-000000000002', 'RPT-EOC-SCORE', 'Executive Scorecard', 'Scorecard metric export', 'xlsx')
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.eoc_generated_reports (id, template_id, title, status) VALUES
  ('e010001b-0000-4000-8000-000000000001', 'e010001a-0000-4000-8000-000000000001',
   'EOC Daily Ops Pack — demo', 'ready')
ON CONFLICT DO NOTHING;

INSERT INTO public.executive_scorecards (id, code, name, period, overall_score, status, owner_label) VALUES
  ('e010001c-0000-4000-8000-000000000001', 'SC-Q3-2026', 'Q3 2026 Executive Scorecard', 'q3_2026', 84.5, 'active', 'CEO Office')
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.executive_scorecard_metrics (id, scorecard_id, metric_key, label, score, weight, target_value, actual_value, status) VALUES
  ('e010001d-0000-4000-8000-000000000001', 'e010001c-0000-4000-8000-000000000001', 'revenue', 'Revenue', 86, 2, 250000000, 218500000, 'watch'),
  ('e010001d-0000-4000-8000-000000000002', 'e010001c-0000-4000-8000-000000000001', 'sales_velocity', 'Sales Velocity', 90, 1.5, 20, 18, 'on_track'),
  ('e010001d-0000-4000-8000-000000000003', 'e010001c-0000-4000-8000-000000000001', 'site_delivery', 'Site Delivery', 74, 2, 95, 78, 'at_risk'),
  ('e010001d-0000-4000-8000-000000000004', 'e010001c-0000-4000-8000-000000000001', 'collections', 'Collections', 80, 1.5, 95, 88, 'watch')
ON CONFLICT DO NOTHING;

INSERT INTO public.eoc_activity_logs (id, action, summary, actor_label, module_slug) VALUES
  ('e010001e-0000-4000-8000-000000000001', 'alert.opened', 'Collections aging alert opened', 'System', 'finance'),
  ('e010001e-0000-4000-8000-000000000002', 'approval.submitted', 'CapEx generator bank submitted for dual approval', 'Finance Ops', 'finance'),
  ('e010001e-0000-4000-8000-000000000003', 'workflow.waiting', 'PO-2026-4481 waiting on manager approval', 'Automation', 'finance'),
  ('e010001e-0000-4000-8000-000000000004', 'decision.logged', 'Pause non-critical CapEx recorded', 'CFO Office', 'finance')
ON CONFLICT DO NOTHING;

INSERT INTO public.eoc_audit_events (id, action, entity_type, entity_id, summary, actor_label, severity) VALUES
  ('e010001f-0000-4000-8000-000000000001', 'eoc.seed', 'eoc_dashboards', 'e0100001-0000-4000-8000-000000000001',
   'Mission Control dashboard seeded', 'Migration', 'info'),
  ('e010001f-0000-4000-8000-000000000002', 'approval.view', 'approval_requests', 'e010000f-0000-4000-8000-000000000001',
   'Pending CapEx approval queued in EOC', 'System', 'info')
ON CONFLICT DO NOTHING;

INSERT INTO public.enterprise_search_history (id, query, result_count, modules) VALUES
  ('e0100020-0000-4000-8000-000000000001', 'capex generator', 3, ARRAY['finance','approvals']),
  ('e0100020-0000-4000-8000-000000000002', 'block c slip', 2, ARRAY['construction','alerts'])
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.eoc_dashboards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.eoc_dashboard_widgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.eoc_dashboard_layouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.enterprise_kpi_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.enterprise_kpi_targets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.enterprise_kpis ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.enterprise_search_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_prompts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workflow_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workflow_steps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workflow_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workflow_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workflow_instances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.approval_workflows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.approval_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.approval_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.enterprise_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.eoc_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.enterprise_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meeting_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meeting_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.decision_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.predictive_models ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.predictive_forecasts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.knowledge_articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.eoc_report_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.eoc_generated_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.eoc_audit_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.executive_scorecards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.executive_scorecard_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.eoc_activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.eoc_module_health ENABLE ROW LEVEL SECURITY;

-- Helper policy pattern macros expanded inline
DROP POLICY IF EXISTS eoc_dashboards_select ON public.eoc_dashboards;
DROP POLICY IF EXISTS eoc_dashboards_write ON public.eoc_dashboards;
CREATE POLICY eoc_dashboards_select ON public.eoc_dashboards FOR SELECT
  USING (public.has_permission('eoc.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY eoc_dashboards_write ON public.eoc_dashboards FOR ALL
  USING (public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS eoc_dashboard_widgets_select ON public.eoc_dashboard_widgets;
DROP POLICY IF EXISTS eoc_dashboard_widgets_write ON public.eoc_dashboard_widgets;
CREATE POLICY eoc_dashboard_widgets_select ON public.eoc_dashboard_widgets FOR SELECT
  USING (public.has_permission('eoc.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY eoc_dashboard_widgets_write ON public.eoc_dashboard_widgets FOR ALL
  USING (public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS eoc_dashboard_layouts_select ON public.eoc_dashboard_layouts;
DROP POLICY IF EXISTS eoc_dashboard_layouts_write ON public.eoc_dashboard_layouts;
CREATE POLICY eoc_dashboard_layouts_select ON public.eoc_dashboard_layouts FOR SELECT
  USING (public.has_permission('eoc.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY eoc_dashboard_layouts_write ON public.eoc_dashboard_layouts FOR ALL
  USING (public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS enterprise_kpi_definitions_select ON public.enterprise_kpi_definitions;
DROP POLICY IF EXISTS enterprise_kpi_definitions_write ON public.enterprise_kpi_definitions;
CREATE POLICY enterprise_kpi_definitions_select ON public.enterprise_kpi_definitions FOR SELECT
  USING (public.has_permission('eoc.kpis', auth.uid()) OR public.has_permission('eoc.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY enterprise_kpi_definitions_write ON public.enterprise_kpi_definitions FOR ALL
  USING (public.has_permission('eoc.kpis', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('eoc.kpis', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS enterprise_kpi_targets_select ON public.enterprise_kpi_targets;
DROP POLICY IF EXISTS enterprise_kpi_targets_write ON public.enterprise_kpi_targets;
CREATE POLICY enterprise_kpi_targets_select ON public.enterprise_kpi_targets FOR SELECT
  USING (public.has_permission('eoc.kpis', auth.uid()) OR public.has_permission('eoc.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY enterprise_kpi_targets_write ON public.enterprise_kpi_targets FOR ALL
  USING (public.has_permission('eoc.kpis', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('eoc.kpis', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS enterprise_kpis_select ON public.enterprise_kpis;
DROP POLICY IF EXISTS enterprise_kpis_write ON public.enterprise_kpis;
CREATE POLICY enterprise_kpis_select ON public.enterprise_kpis FOR SELECT
  USING (public.has_permission('eoc.kpis', auth.uid()) OR public.has_permission('eoc.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY enterprise_kpis_write ON public.enterprise_kpis FOR ALL
  USING (public.has_permission('eoc.kpis', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('eoc.kpis', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS enterprise_search_history_select ON public.enterprise_search_history;
DROP POLICY IF EXISTS enterprise_search_history_write ON public.enterprise_search_history;
CREATE POLICY enterprise_search_history_select ON public.enterprise_search_history FOR SELECT
  USING (public.has_permission('eoc.search', auth.uid()) OR public.has_permission('eoc.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY enterprise_search_history_write ON public.enterprise_search_history FOR ALL
  USING (public.has_permission('eoc.search', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('eoc.search', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_prompts_select ON public.ai_prompts;
DROP POLICY IF EXISTS ai_prompts_write ON public.ai_prompts;
CREATE POLICY ai_prompts_select ON public.ai_prompts FOR SELECT
  USING (public.has_permission('eoc.ai', auth.uid()) OR public.has_permission('eoc.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_prompts_write ON public.ai_prompts FOR ALL
  USING (public.has_permission('eoc.ai', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('eoc.ai', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS workflow_definitions_select ON public.workflow_definitions;
DROP POLICY IF EXISTS workflow_definitions_write ON public.workflow_definitions;
CREATE POLICY workflow_definitions_select ON public.workflow_definitions FOR SELECT
  USING (public.has_permission('eoc.workflows', auth.uid()) OR public.has_permission('eoc.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY workflow_definitions_write ON public.workflow_definitions FOR ALL
  USING (public.has_permission('eoc.workflows', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('eoc.workflows', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS workflow_steps_select ON public.workflow_steps;
DROP POLICY IF EXISTS workflow_steps_write ON public.workflow_steps;
CREATE POLICY workflow_steps_select ON public.workflow_steps FOR SELECT
  USING (public.has_permission('eoc.workflows', auth.uid()) OR public.has_permission('eoc.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY workflow_steps_write ON public.workflow_steps FOR ALL
  USING (public.has_permission('eoc.workflows', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('eoc.workflows', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS workflow_conditions_select ON public.workflow_conditions;
DROP POLICY IF EXISTS workflow_conditions_write ON public.workflow_conditions;
CREATE POLICY workflow_conditions_select ON public.workflow_conditions FOR SELECT
  USING (public.has_permission('eoc.workflows', auth.uid()) OR public.has_permission('eoc.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY workflow_conditions_write ON public.workflow_conditions FOR ALL
  USING (public.has_permission('eoc.workflows', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('eoc.workflows', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS workflow_actions_select ON public.workflow_actions;
DROP POLICY IF EXISTS workflow_actions_write ON public.workflow_actions;
CREATE POLICY workflow_actions_select ON public.workflow_actions FOR SELECT
  USING (public.has_permission('eoc.workflows', auth.uid()) OR public.has_permission('eoc.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY workflow_actions_write ON public.workflow_actions FOR ALL
  USING (public.has_permission('eoc.workflows', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('eoc.workflows', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS workflow_instances_select ON public.workflow_instances;
DROP POLICY IF EXISTS workflow_instances_write ON public.workflow_instances;
CREATE POLICY workflow_instances_select ON public.workflow_instances FOR SELECT
  USING (public.has_permission('eoc.workflows', auth.uid()) OR public.has_permission('eoc.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY workflow_instances_write ON public.workflow_instances FOR ALL
  USING (public.has_permission('eoc.workflows', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('eoc.workflows', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS approval_workflows_select ON public.approval_workflows;
DROP POLICY IF EXISTS approval_workflows_write ON public.approval_workflows;
CREATE POLICY approval_workflows_select ON public.approval_workflows FOR SELECT
  USING (public.has_permission('eoc.approvals', auth.uid()) OR public.has_permission('eoc.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY approval_workflows_write ON public.approval_workflows FOR ALL
  USING (public.has_permission('eoc.approvals', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('eoc.approvals', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS approval_requests_select ON public.approval_requests;
DROP POLICY IF EXISTS approval_requests_write ON public.approval_requests;
CREATE POLICY approval_requests_select ON public.approval_requests FOR SELECT
  USING (public.has_permission('eoc.approvals', auth.uid()) OR public.has_permission('eoc.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY approval_requests_write ON public.approval_requests FOR ALL
  USING (public.has_permission('eoc.approvals', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('eoc.approvals', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS approval_history_select ON public.approval_history;
DROP POLICY IF EXISTS approval_history_write ON public.approval_history;
CREATE POLICY approval_history_select ON public.approval_history FOR SELECT
  USING (public.has_permission('eoc.approvals', auth.uid()) OR public.has_permission('eoc.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY approval_history_write ON public.approval_history FOR ALL
  USING (public.has_permission('eoc.approvals', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('eoc.approvals', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS enterprise_alerts_select ON public.enterprise_alerts;
DROP POLICY IF EXISTS enterprise_alerts_write ON public.enterprise_alerts;
CREATE POLICY enterprise_alerts_select ON public.enterprise_alerts FOR SELECT
  USING (public.has_permission('eoc.alerts', auth.uid()) OR public.has_permission('eoc.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY enterprise_alerts_write ON public.enterprise_alerts FOR ALL
  USING (public.has_permission('eoc.alerts', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('eoc.alerts', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS eoc_notifications_select ON public.eoc_notifications;
DROP POLICY IF EXISTS eoc_notifications_write ON public.eoc_notifications;
CREATE POLICY eoc_notifications_select ON public.eoc_notifications FOR SELECT
  USING (public.has_permission('eoc.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY eoc_notifications_write ON public.eoc_notifications FOR ALL
  USING (public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS enterprise_tasks_select ON public.enterprise_tasks;
DROP POLICY IF EXISTS enterprise_tasks_write ON public.enterprise_tasks;
CREATE POLICY enterprise_tasks_select ON public.enterprise_tasks FOR SELECT
  USING (public.has_permission('eoc.tasks', auth.uid()) OR public.has_permission('eoc.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY enterprise_tasks_write ON public.enterprise_tasks FOR ALL
  USING (public.has_permission('eoc.tasks', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('eoc.tasks', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS meeting_records_select ON public.meeting_records;
DROP POLICY IF EXISTS meeting_records_write ON public.meeting_records;
CREATE POLICY meeting_records_select ON public.meeting_records FOR SELECT
  USING (public.has_permission('eoc.meetings', auth.uid()) OR public.has_permission('eoc.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY meeting_records_write ON public.meeting_records FOR ALL
  USING (public.has_permission('eoc.meetings', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('eoc.meetings', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS meeting_notes_select ON public.meeting_notes;
DROP POLICY IF EXISTS meeting_notes_write ON public.meeting_notes;
CREATE POLICY meeting_notes_select ON public.meeting_notes FOR SELECT
  USING (public.has_permission('eoc.meetings', auth.uid()) OR public.has_permission('eoc.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY meeting_notes_write ON public.meeting_notes FOR ALL
  USING (public.has_permission('eoc.meetings', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('eoc.meetings', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS decision_logs_select ON public.decision_logs;
DROP POLICY IF EXISTS decision_logs_write ON public.decision_logs;
CREATE POLICY decision_logs_select ON public.decision_logs FOR SELECT
  USING (public.has_permission('eoc.read', auth.uid()) OR public.has_permission('eoc.analytics', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY decision_logs_write ON public.decision_logs FOR ALL
  USING (public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS predictive_models_select ON public.predictive_models;
DROP POLICY IF EXISTS predictive_models_write ON public.predictive_models;
CREATE POLICY predictive_models_select ON public.predictive_models FOR SELECT
  USING (public.has_permission('eoc.analytics', auth.uid()) OR public.has_permission('eoc.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY predictive_models_write ON public.predictive_models FOR ALL
  USING (public.has_permission('eoc.analytics', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('eoc.analytics', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS predictive_forecasts_select ON public.predictive_forecasts;
DROP POLICY IF EXISTS predictive_forecasts_write ON public.predictive_forecasts;
CREATE POLICY predictive_forecasts_select ON public.predictive_forecasts FOR SELECT
  USING (public.has_permission('eoc.analytics', auth.uid()) OR public.has_permission('eoc.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY predictive_forecasts_write ON public.predictive_forecasts FOR ALL
  USING (public.has_permission('eoc.analytics', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('eoc.analytics', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS knowledge_articles_select ON public.knowledge_articles;
DROP POLICY IF EXISTS knowledge_articles_write ON public.knowledge_articles;
CREATE POLICY knowledge_articles_select ON public.knowledge_articles FOR SELECT
  USING (public.has_permission('eoc.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY knowledge_articles_write ON public.knowledge_articles FOR ALL
  USING (public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS eoc_report_templates_select ON public.eoc_report_templates;
DROP POLICY IF EXISTS eoc_report_templates_write ON public.eoc_report_templates;
CREATE POLICY eoc_report_templates_select ON public.eoc_report_templates FOR SELECT
  USING (public.has_permission('eoc.reports', auth.uid()) OR public.has_permission('eoc.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY eoc_report_templates_write ON public.eoc_report_templates FOR ALL
  USING (public.has_permission('eoc.reports', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('eoc.reports', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS eoc_generated_reports_select ON public.eoc_generated_reports;
DROP POLICY IF EXISTS eoc_generated_reports_write ON public.eoc_generated_reports;
CREATE POLICY eoc_generated_reports_select ON public.eoc_generated_reports FOR SELECT
  USING (public.has_permission('eoc.reports', auth.uid()) OR public.has_permission('eoc.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY eoc_generated_reports_write ON public.eoc_generated_reports FOR ALL
  USING (public.has_permission('eoc.reports', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('eoc.reports', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS eoc_audit_events_select ON public.eoc_audit_events;
DROP POLICY IF EXISTS eoc_audit_events_write ON public.eoc_audit_events;
CREATE POLICY eoc_audit_events_select ON public.eoc_audit_events FOR SELECT
  USING (public.has_permission('eoc.audit', auth.uid()) OR public.has_permission('eoc.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY eoc_audit_events_write ON public.eoc_audit_events FOR ALL
  USING (public.has_permission('eoc.audit', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('eoc.audit', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS executive_scorecards_select ON public.executive_scorecards;
DROP POLICY IF EXISTS executive_scorecards_write ON public.executive_scorecards;
CREATE POLICY executive_scorecards_select ON public.executive_scorecards FOR SELECT
  USING (public.has_permission('eoc.analytics', auth.uid()) OR public.has_permission('eoc.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY executive_scorecards_write ON public.executive_scorecards FOR ALL
  USING (public.has_permission('eoc.analytics', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('eoc.analytics', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS executive_scorecard_metrics_select ON public.executive_scorecard_metrics;
DROP POLICY IF EXISTS executive_scorecard_metrics_write ON public.executive_scorecard_metrics;
CREATE POLICY executive_scorecard_metrics_select ON public.executive_scorecard_metrics FOR SELECT
  USING (public.has_permission('eoc.analytics', auth.uid()) OR public.has_permission('eoc.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY executive_scorecard_metrics_write ON public.executive_scorecard_metrics FOR ALL
  USING (public.has_permission('eoc.analytics', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('eoc.analytics', auth.uid()) OR public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS eoc_activity_logs_select ON public.eoc_activity_logs;
DROP POLICY IF EXISTS eoc_activity_logs_write ON public.eoc_activity_logs;
CREATE POLICY eoc_activity_logs_select ON public.eoc_activity_logs FOR SELECT
  USING (public.has_permission('eoc.read', auth.uid()) OR public.has_permission('eoc.audit', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY eoc_activity_logs_write ON public.eoc_activity_logs FOR ALL
  USING (public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS eoc_module_health_select ON public.eoc_module_health;
DROP POLICY IF EXISTS eoc_module_health_write ON public.eoc_module_health;
CREATE POLICY eoc_module_health_select ON public.eoc_module_health FOR SELECT
  USING (public.has_permission('eoc.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY eoc_module_health_write ON public.eoc_module_health FOR ALL
  USING (public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('eoc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE ON
  public.eoc_dashboards,
  public.eoc_dashboard_widgets,
  public.eoc_dashboard_layouts,
  public.enterprise_kpi_definitions,
  public.enterprise_kpi_targets,
  public.enterprise_kpis,
  public.enterprise_search_history,
  public.ai_prompts,
  public.workflow_definitions,
  public.workflow_steps,
  public.workflow_conditions,
  public.workflow_actions,
  public.workflow_instances,
  public.approval_workflows,
  public.approval_requests,
  public.approval_history,
  public.enterprise_alerts,
  public.eoc_notifications,
  public.enterprise_tasks,
  public.meeting_records,
  public.meeting_notes,
  public.decision_logs,
  public.predictive_models,
  public.predictive_forecasts,
  public.knowledge_articles,
  public.eoc_report_templates,
  public.eoc_generated_reports,
  public.eoc_audit_events,
  public.executive_scorecards,
  public.executive_scorecard_metrics,
  public.eoc_activity_logs,
  public.eoc_module_health
TO authenticated;

-- ---------------------------------------------------------------------------
-- Realtime (alerts, tasks, approvals, activity, workflows)
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'enterprise_alerts',
    'enterprise_tasks',
    'approval_requests',
    'eoc_activity_logs',
    'workflow_instances',
    'enterprise_kpis'
  ]
  LOOP
    BEGIN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    EXCEPTION
      WHEN duplicate_object THEN NULL;
      WHEN undefined_object THEN NULL;
    END;
  END LOOP;
END $$;

COMMIT;
