-- APPLIED remotely 2026-07-15 (chunked enterprise_bi_analytics_warehouse_p1–p3)
-- Volume 4 Part 16 — Enterprise Business Intelligence (BI),
-- Advanced Analytics & Data Warehouse Platform (BIADW)
-- Status: APPLIED remotely 2026-07-15.
--
-- Approach:
--   • Route wires existing /dashboard/analytics → BI Command Center.
--   • NEVER recreate/drop: kpi_snapshots, executive_dashboards, executive_metrics,
--     dashboard_preferences, ai_executive_insights, dashboard_layouts,
--     dashboard_widgets, eoc_dashboards, eoc_dashboard_widgets, enterprise_kpis,
--     enterprise_kpi_definitions, enterprise_kpi_targets, predictive_models,
--     predictive_forecasts, executive_scorecards, executive_scorecard_metrics,
--     ai_conversations.
--   • Use analytics_* prefixed tables exclusively.
--   • Seed UUIDs hex-only (e160…).
--   • Permissions: slug, name, description, module ONLY.
--   • RLS: has_permission('slug', auth.uid()) — slug FIRST.
--
-- Volume 4 continues Parts 17–25. Wait for approve before Part 17.

BEGIN;

-- ---------------------------------------------------------------------------
-- Permissions
-- ---------------------------------------------------------------------------
INSERT INTO public.permissions (slug, name, description, module) VALUES
  ('analytics.read', 'View Analytics', 'View BI Command Center', 'analytics'),
  ('analytics.write', 'Manage Analytics', 'Create and edit analytics records', 'analytics'),
  ('analytics.warehouse', 'Data Warehouse', 'Manage warehouse datasets and facts', 'analytics'),
  ('analytics.etl', 'ETL Pipelines', 'Manage ETL jobs and pipeline logs', 'analytics'),
  ('analytics.kpis', 'Analytics KPIs', 'Manage analytics KPIs and targets', 'analytics'),
  ('analytics.dashboards', 'Analytics Dashboards', 'Manage analytics dashboards and widgets', 'analytics'),
  ('analytics.reports', 'Analytics Reports', 'Generate and view analytics reports', 'analytics'),
  ('analytics.forecasts', 'Forecasts', 'Manage forecasts and predictive models', 'analytics'),
  ('analytics.governance', 'Data Governance', 'Manage metadata, catalog, and lineage', 'analytics'),
  ('analytics.quality', 'Data Quality', 'Manage quality rules and issues', 'analytics'),
  ('analytics.ai', 'Analytics AI', 'Use analytics AI insights', 'analytics'),
  ('analytics.schedule', 'Scheduled Reports', 'Schedule and deliver analytics reports', 'analytics'),
  ('analytics.admin', 'Analytics Admin', 'Administer analytics platform settings', 'analytics')
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  module = EXCLUDED.module,
  updated_at = now();

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE p.slug LIKE 'analytics.%'
  AND (
    r.slug IN ('super_admin', 'admin')
    OR (r.slug = 'finance' AND p.slug IN (
      'analytics.read', 'analytics.kpis', 'analytics.dashboards',
      'analytics.reports', 'analytics.forecasts'
    ))
    OR (r.slug = 'construction_manager' AND p.slug IN (
      'analytics.read', 'analytics.dashboards', 'analytics.reports', 'analytics.kpis'
    ))
    OR (r.slug = 'sales_team' AND p.slug IN (
      'analytics.read', 'analytics.dashboards', 'analytics.reports', 'analytics.kpis'
    ))
    OR (r.slug = 'marketing' AND p.slug IN (
      'analytics.read', 'analytics.dashboards', 'analytics.reports', 'analytics.kpis'
    ))
  )
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Warehouse / sources
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.analytics_data_sources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  name text NOT NULL,
  source_module text NOT NULL DEFAULT 'core'
    CHECK (source_module IN (
      'finance','sales','crm','construction','inventory','hr','marketing','support','core','other'
    )),
  source_type text NOT NULL DEFAULT 'supabase'
    CHECK (source_type IN ('supabase','api','file','warehouse','stream','other')),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft','active','paused','retired')),
  connection_label text,
  owner_label text,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.analytics_datasets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_id uuid REFERENCES public.analytics_data_sources(id) ON DELETE SET NULL,
  code text UNIQUE,
  name text NOT NULL,
  dataset_type text NOT NULL DEFAULT 'mart'
    CHECK (dataset_type IN ('raw','staging','mart','aggregate','snapshot','other')),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft','active','deprecated')),
  grain_label text,
  owner_label text,
  row_estimate bigint DEFAULT 0,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.analytics_fact_tables (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dataset_id uuid REFERENCES public.analytics_datasets(id) ON DELETE SET NULL,
  code text UNIQUE,
  name text NOT NULL,
  grain_label text,
  measure_labels text[] NOT NULL DEFAULT '{}',
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft','active','retired')),
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.analytics_dimension_tables (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dataset_id uuid REFERENCES public.analytics_datasets(id) ON DELETE SET NULL,
  code text UNIQUE,
  name text NOT NULL,
  key_column text,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft','active','retired')),
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- ETL
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.analytics_etl_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  name text NOT NULL,
  source_id uuid REFERENCES public.analytics_data_sources(id) ON DELETE SET NULL,
  dataset_id uuid REFERENCES public.analytics_datasets(id) ON DELETE SET NULL,
  schedule_cron text,
  status text NOT NULL DEFAULT 'idle'
    CHECK (status IN ('idle','running','success','failed','paused')),
  last_run_at timestamptz,
  last_duration_ms int,
  owner_label text,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_analytics_etl_jobs_status
  ON public.analytics_etl_jobs(status);

CREATE TABLE IF NOT EXISTS public.analytics_pipeline_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id uuid NOT NULL REFERENCES public.analytics_etl_jobs(id) ON DELETE CASCADE,
  run_status text NOT NULL DEFAULT 'success'
    CHECK (run_status IN ('running','success','failed','cancelled')),
  started_at timestamptz NOT NULL DEFAULT now(),
  finished_at timestamptz,
  rows_processed bigint DEFAULT 0,
  error_message text,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- KPIs (analytics_* only — NOT enterprise_kpis / kpi_snapshots)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.analytics_kpis (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  name text NOT NULL,
  category text NOT NULL DEFAULT 'finance'
    CHECK (category IN (
      'finance','sales','construction','operations','marketing','hr','support','executive','other'
    )),
  unit text NOT NULL DEFAULT 'count'
    CHECK (unit IN ('count','pct','currency','ratio','score','other')),
  current_value numeric(18,4) DEFAULT 0,
  prior_value numeric(18,4),
  change_pct numeric(8,2),
  status text NOT NULL DEFAULT 'ok'
    CHECK (status IN ('ok','watch','critical','unknown')),
  owner_label text,
  summary text,
  -- Optional non-destructive cross-read links (columns only; no FKs required)
  enterprise_kpi_id uuid,
  kpi_snapshot_id uuid,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  measured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_analytics_kpis_category
  ON public.analytics_kpis(category, status);

CREATE TABLE IF NOT EXISTS public.analytics_kpi_targets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kpi_id uuid NOT NULL REFERENCES public.analytics_kpis(id) ON DELETE CASCADE,
  period_label text NOT NULL,
  target_value numeric(18,4) NOT NULL DEFAULT 0,
  stretch_value numeric(18,4),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft','active','closed')),
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Dashboards / widgets (analytics_* only — NOT dashboard_widgets / eoc_*)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.analytics_dashboards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  title text NOT NULL,
  audience text NOT NULL DEFAULT 'executive'
    CHECK (audience IN ('executive','finance','sales','ops','board','other')),
  status text NOT NULL DEFAULT 'published'
    CHECK (status IN ('draft','published','archived')),
  owner_label text,
  summary text,
  layout_json jsonb NOT NULL DEFAULT '{}'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.analytics_dashboard_widgets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dashboard_id uuid NOT NULL REFERENCES public.analytics_dashboards(id) ON DELETE CASCADE,
  title text NOT NULL,
  widget_type text NOT NULL DEFAULT 'kpi'
    CHECK (widget_type IN ('kpi','chart','table','scorecard','text','other')),
  kpi_id uuid REFERENCES public.analytics_kpis(id) ON DELETE SET NULL,
  sort_order int NOT NULL DEFAULT 100,
  config jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Reports / visualizations / filters / views
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.analytics_report_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  name text NOT NULL,
  template_type text NOT NULL DEFAULT 'executive'
    CHECK (template_type IN ('executive','operational','financial','board','custom')),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft','active','retired')),
  summary text,
  body_template text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.analytics_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id uuid REFERENCES public.analytics_report_templates(id) ON DELETE SET NULL,
  code text UNIQUE,
  title text NOT NULL,
  report_type text NOT NULL DEFAULT 'executive'
    CHECK (report_type IN ('executive','operational','financial','board','ad_hoc','other')),
  period_label text,
  status text NOT NULL DEFAULT 'ready'
    CHECK (status IN ('draft','ready','published','archived')),
  summary text,
  owner_label text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.analytics_visualizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  title text NOT NULL,
  viz_type text NOT NULL DEFAULT 'line'
    CHECK (viz_type IN ('line','bar','pie','area','scatter','heatmap','table','other')),
  dataset_id uuid REFERENCES public.analytics_datasets(id) ON DELETE SET NULL,
  config jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft','active','retired')),
  summary text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.analytics_filters (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  name text NOT NULL,
  filter_type text NOT NULL DEFAULT 'dimension'
    CHECK (filter_type IN ('dimension','measure','date','status','custom')),
  field_path text,
  default_value text,
  options jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.analytics_saved_views (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  title text NOT NULL,
  owner_label text,
  dashboard_id uuid REFERENCES public.analytics_dashboards(id) ON DELETE SET NULL,
  filter_json jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','archived')),
  summary text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Scorecards (analytics_* only — NOT executive_scorecards)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.analytics_scorecards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  title text NOT NULL,
  audience text NOT NULL DEFAULT 'ceo'
    CHECK (audience IN ('ceo','cfo','coo','board','other')),
  period_label text,
  overall_score numeric(5,2) DEFAULT 0,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','published','archived')),
  owner_label text,
  summary text,
  metrics jsonb NOT NULL DEFAULT '[]'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Forecasts / models (analytics_* only — NOT predictive_*)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.analytics_models (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  name text NOT NULL,
  model_type text NOT NULL DEFAULT 'forecast'
    CHECK (model_type IN ('forecast','classification','regression','anomaly','other')),
  algorithm_label text,
  status text NOT NULL DEFAULT 'trained'
    CHECK (status IN ('draft','training','trained','retired','failed')),
  owner_label text,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.analytics_forecasts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  model_id uuid REFERENCES public.analytics_models(id) ON DELETE SET NULL,
  code text UNIQUE,
  title text NOT NULL,
  metric_label text,
  horizon_label text,
  forecast_value numeric(18,4) DEFAULT 0,
  lower_bound numeric(18,4),
  upper_bound numeric(18,4),
  confidence_pct numeric(5,2) DEFAULT 0,
  unit text NOT NULL DEFAULT 'currency'
    CHECK (unit IN ('count','pct','currency','ratio','other')),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft','active','superseded')),
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  forecast_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Quality / governance
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.analytics_data_quality_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  name text NOT NULL,
  dataset_id uuid REFERENCES public.analytics_datasets(id) ON DELETE SET NULL,
  rule_type text NOT NULL DEFAULT 'completeness'
    CHECK (rule_type IN ('completeness','accuracy','uniqueness','timeliness','consistency','other')),
  severity text NOT NULL DEFAULT 'medium'
    CHECK (severity IN ('low','medium','high','critical')),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft','active','paused','retired')),
  expression_label text,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.analytics_quality_issues (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_id uuid REFERENCES public.analytics_data_quality_rules(id) ON DELETE SET NULL,
  code text UNIQUE,
  title text NOT NULL,
  severity text NOT NULL DEFAULT 'medium'
    CHECK (severity IN ('low','medium','high','critical')),
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','investigating','resolved','wont_fix')),
  dataset_label text,
  owner_label text,
  summary text,
  detected_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_analytics_quality_issues_status
  ON public.analytics_quality_issues(status, severity);

CREATE TABLE IF NOT EXISTS public.analytics_metadata (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type text NOT NULL DEFAULT 'dataset'
    CHECK (entity_type IN ('dataset','kpi','dashboard','report','column','other')),
  entity_ref text NOT NULL,
  key text NOT NULL,
  value text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (entity_type, entity_ref, key)
);

CREATE TABLE IF NOT EXISTS public.analytics_data_catalog (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  title text NOT NULL,
  catalog_type text NOT NULL DEFAULT 'dataset'
    CHECK (catalog_type IN ('dataset','fact','dimension','kpi','report','other')),
  owner_label text,
  tags text[] NOT NULL DEFAULT '{}',
  summary text,
  status text NOT NULL DEFAULT 'published'
    CHECK (status IN ('draft','published','archived')),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.analytics_lineage (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  source_label text NOT NULL,
  target_label text NOT NULL,
  lineage_type text NOT NULL DEFAULT 'etl'
    CHECK (lineage_type IN ('etl','transform','aggregate','export','manual','other')),
  dataset_id uuid REFERENCES public.analytics_datasets(id) ON DELETE SET NULL,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Scheduling / search / AI / activity / notifications
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.analytics_scheduled_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id uuid REFERENCES public.analytics_reports(id) ON DELETE SET NULL,
  code text UNIQUE,
  title text NOT NULL,
  schedule_cron text,
  channel_label text DEFAULT 'email',
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft','active','paused','retired')),
  next_run_at timestamptz,
  owner_label text,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.analytics_search_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  query_text text NOT NULL,
  actor_label text,
  result_count int DEFAULT 0,
  searched_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS public.analytics_ai_conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','closed','archived')),
  actor_label text,
  last_message text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.analytics_ai_insights (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  body text NOT NULL,
  insight_type text NOT NULL DEFAULT 'briefing'
    CHECK (insight_type IN ('briefing','forecast','quality','anomaly','kpi','other')),
  confidence_pct numeric(5,2),
  editable boolean NOT NULL DEFAULT true,
  disclaimer text NOT NULL DEFAULT 'AI-generated — editable / advisory',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.analytics_activity_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  action text NOT NULL,
  summary text NOT NULL,
  actor_label text,
  entity_type text,
  entity_id uuid,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS public.analytics_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  body text,
  severity text NOT NULL DEFAULT 'info'
    CHECK (severity IN ('info','warning','critical')),
  status text NOT NULL DEFAULT 'unread'
    CHECK (status IN ('unread','read','dismissed')),
  link_path text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Optional non-destructive cross-read columns on existing tables (IF NOT EXISTS)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'enterprise_kpis'
  ) THEN
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'enterprise_kpis'
        AND column_name = 'analytics_kpi_id'
    ) THEN
      ALTER TABLE public.enterprise_kpis ADD COLUMN analytics_kpi_id uuid;
    END IF;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'kpi_snapshots'
  ) THEN
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'kpi_snapshots'
        AND column_name = 'analytics_kpi_id'
    ) THEN
      ALTER TABLE public.kpi_snapshots ADD COLUMN analytics_kpi_id uuid;
    END IF;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Storage bucket
-- ---------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('analytics-exports', 'analytics-exports', false)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.analytics_kpis; EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.analytics_dashboards; EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.analytics_etl_jobs; EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.analytics_quality_issues; EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.analytics_activity_logs; EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.analytics_notifications; EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

-- ---------------------------------------------------------------------------
-- Seeds (hex-only UUIDs e160…)
-- ---------------------------------------------------------------------------
INSERT INTO public.analytics_data_sources (
  id, code, name, source_module, source_type, status, connection_label, owner_label, summary
) VALUES
  (
    'e1600001-0000-4000-8000-000000000001',
    'SRC-FIN-01', 'Finance Ledger Mirror', 'finance', 'supabase', 'active',
    'public.finance_*', 'CFO Office', 'Invoice, receipt, and GL extracts for warehouse marts.'
  ),
  (
    'e1600001-0000-4000-8000-000000000002',
    'SRC-SALES-01', 'Sales & Booking Feed', 'sales', 'supabase', 'active',
    'public.sales_*', 'Sales Ops', 'Reservations, bookings, and conversion events.'
  ),
  (
    'e1600001-0000-4000-8000-000000000003',
    'SRC-CRM-01', 'CRM Pipeline Feed', 'crm', 'supabase', 'active',
    'public.crm_*', 'CRM Lead', 'Leads, opportunities, and stage transitions.'
  ),
  (
    'e1600001-0000-4000-8000-000000000004',
    'SRC-CPMS-01', 'Construction Progress Feed', 'construction', 'supabase', 'active',
    'public.construction_*', 'PMO', 'Milestone % complete and site delay signals.'
  ),
  (
    'e1600001-0000-4000-8000-000000000005',
    'SRC-INV-01', 'Inventory & Supply Mirror', 'inventory', 'supabase', 'active',
    'public.procurement_*', 'Supply Chain', 'Stock levels and goods receipt lag.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.analytics_datasets (
  id, source_id, code, name, dataset_type, status, grain_label, owner_label, row_estimate, summary
) VALUES
  (
    'e1600002-0000-4000-8000-000000000001',
    'e1600001-0000-4000-8000-000000000001',
    'DS-REV-DAILY', 'Daily Revenue Mart', 'mart', 'active', 'day × estate',
    'BI Team', 42000, 'Daily recognized revenue by estate and channel.'
  ),
  (
    'e1600002-0000-4000-8000-000000000002',
    'e1600001-0000-4000-8000-000000000002',
    'DS-CONV', 'Sales Conversion Mart', 'mart', 'active', 'week × funnel stage',
    'BI Team', 18000, 'Funnel conversion rates and booking lag.'
  ),
  (
    'e1600002-0000-4000-8000-000000000003',
    'e1600001-0000-4000-8000-000000000004',
    'DS-CONST-PCT', 'Construction Completeness Mart', 'mart', 'active', 'week × project',
    'PMO Analyst', 9600, 'Weighted milestone completion % by project.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.analytics_fact_tables (
  id, dataset_id, code, name, grain_label, measure_labels, status, summary
) VALUES
  (
    'e1600003-0000-4000-8000-000000000001',
    'e1600002-0000-4000-8000-000000000001',
    'FACT-REV', 'fact_revenue_daily', 'day × estate',
    ARRAY['gross_revenue','net_revenue','collections'], 'active',
    'Core revenue fact for executive KPIs.'
  ),
  (
    'e1600003-0000-4000-8000-000000000002',
    'e1600002-0000-4000-8000-000000000002',
    'FACT-CONV', 'fact_sales_conversion', 'week × stage',
    ARRAY['leads','bookings','conversion_pct'], 'active',
    'Sales funnel conversion fact.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.analytics_dimension_tables (
  id, dataset_id, code, name, key_column, status, summary
) VALUES
  (
    'e1600004-0000-4000-8000-000000000001',
    'e1600002-0000-4000-8000-000000000001',
    'DIM-ESTATE', 'dim_estate', 'estate_id', 'active',
    'Estate master dimension for revenue and construction mashups.'
  ),
  (
    'e1600004-0000-4000-8000-000000000002',
    'e1600002-0000-4000-8000-000000000002',
    'DIM-CHANNEL', 'dim_sales_channel', 'channel_id', 'active',
    'Sales channel dimension (direct, referral, partner).'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.analytics_etl_jobs (
  id, code, name, source_id, dataset_id, schedule_cron, status,
  last_run_at, last_duration_ms, owner_label, summary
) VALUES
  (
    'e1600005-0000-4000-8000-000000000001',
    'ETL-REV-DAILY', 'Load Daily Revenue Mart',
    'e1600001-0000-4000-8000-000000000001',
    'e1600002-0000-4000-8000-000000000001',
    '0 2 * * *', 'success', now() - interval '6 hours', 48200,
    'Data Eng', 'Nightly finance → DS-REV-DAILY load.'
  ),
  (
    'e1600005-0000-4000-8000-000000000002',
    'ETL-CONV-WK', 'Load Sales Conversion Mart',
    'e1600001-0000-4000-8000-000000000002',
    'e1600002-0000-4000-8000-000000000002',
    '0 3 * * 1', 'failed', now() - interval '2 days', 1200,
    'Data Eng', 'Weekly sales funnel load — last run failed on schema drift.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.analytics_pipeline_logs (
  id, job_id, run_status, started_at, finished_at, rows_processed, error_message, summary
) VALUES
  (
    'e1600006-0000-4000-8000-000000000001',
    'e1600005-0000-4000-8000-000000000001',
    'success', now() - interval '6 hours 5 minutes', now() - interval '6 hours',
    12540, NULL, 'Revenue mart refreshed successfully.'
  ),
  (
    'e1600006-0000-4000-8000-000000000002',
    'e1600005-0000-4000-8000-000000000002',
    'failed', now() - interval '2 days', now() - interval '2 days' + interval '1 minute',
    0, 'column booking_stage missing in source extract',
    'Conversion ETL failed — schema drift on sales feed.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.analytics_kpis (
  id, code, name, category, unit, current_value, prior_value, change_pct, status, owner_label, summary
) VALUES
  (
    'e1600007-0000-4000-8000-000000000001',
    'KPI-REV-MTD', 'Revenue MTD', 'finance', 'currency',
    185000000, 162000000, 14.2, 'ok', 'CFO',
    'Month-to-date recognized revenue across estates.'
  ),
  (
    'e1600007-0000-4000-8000-000000000002',
    'KPI-CONV', 'Sales Conversion Rate', 'sales', 'pct',
    18.6, 16.1, 15.5, 'ok', 'Sales Director',
    'Lead → booking conversion for last 30 days.'
  ),
  (
    'e1600007-0000-4000-8000-000000000003',
    'KPI-CONST-PCT', 'Construction Completion %', 'construction', 'pct',
    72.4, 68.0, 6.5, 'watch', 'PMO',
    'Weighted average milestone completion across active sites.'
  ),
  (
    'e1600007-0000-4000-8000-000000000004',
    'KPI-ETL-HEALTH', 'ETL Success Rate (7d)', 'operations', 'pct',
    87.5, 95.0, -7.9, 'watch', 'Data Eng',
    'Pipeline success rate over trailing 7 days.'
  ),
  (
    'e1600007-0000-4000-8000-000000000005',
    'KPI-DQ-OPEN', 'Open Data Quality Issues', 'operations', 'count',
    3, 1, 200.0, 'critical', 'Data Steward',
    'Open quality issues requiring steward attention.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.analytics_kpi_targets (
  id, kpi_id, period_label, target_value, stretch_value, status, notes
) VALUES
  (
    'e1600008-0000-4000-8000-000000000001',
    'e1600007-0000-4000-8000-000000000001',
    'Jul 2026', 200000000, 220000000, 'active', 'Board revenue target'
  ),
  (
    'e1600008-0000-4000-8000-000000000002',
    'e1600007-0000-4000-8000-000000000002',
    'Jul 2026', 20.0, 22.0, 'active', 'Sales conversion target'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.analytics_dashboards (
  id, code, title, audience, status, owner_label, summary
) VALUES
  (
    'e1600009-0000-4000-8000-000000000001',
    'DB-EXEC-01', 'Executive Intelligence Hub', 'executive', 'published',
    'CEO Office', 'Primary executive BI surface — revenue, conversion, construction.'
  ),
  (
    'e1600009-0000-4000-8000-000000000002',
    'DB-FIN-01', 'Finance Performance Board', 'finance', 'published',
    'CFO Office', 'Collections, revenue, and forecast variance.'
  ),
  (
    'e1600009-0000-4000-8000-000000000003',
    'DB-BOARD-01', 'Board Pack Snapshot', 'board', 'draft',
    'Company Secretary', 'Board & Executive Intelligence Center stub.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.analytics_dashboard_widgets (
  id, dashboard_id, title, widget_type, kpi_id, sort_order, config
) VALUES
  (
    'e160000a-0000-4000-8000-000000000001',
    'e1600009-0000-4000-8000-000000000001',
    'Revenue MTD', 'kpi', 'e1600007-0000-4000-8000-000000000001', 10, '{}'::jsonb
  ),
  (
    'e160000a-0000-4000-8000-000000000002',
    'e1600009-0000-4000-8000-000000000001',
    'Conversion Rate', 'kpi', 'e1600007-0000-4000-8000-000000000002', 20, '{}'::jsonb
  ),
  (
    'e160000a-0000-4000-8000-000000000003',
    'e1600009-0000-4000-8000-000000000001',
    'Construction %', 'kpi', 'e1600007-0000-4000-8000-000000000003', 30, '{}'::jsonb
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.analytics_report_templates (
  id, code, name, template_type, status, summary, body_template
) VALUES
  (
    'e160000b-0000-4000-8000-000000000001',
    'RT-EXEC-WK', 'Weekly Executive Brief', 'executive', 'active',
    'Standard weekly MD brief template.',
    'Revenue · Conversion · Construction · Quality watchlist'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.analytics_reports (
  id, template_id, code, title, report_type, period_label, status, summary, owner_label
) VALUES
  (
    'e160000c-0000-4000-8000-000000000001',
    'e160000b-0000-4000-8000-000000000001',
    'RPT-2026-0714', 'Weekly Executive Brief — 14 Jul 2026',
    'executive', 'W29 2026', 'published',
    'Revenue MTD up 14.2%; conversion 18.6%; construction 72.4%; ETL watch.',
    'BI Team'
  ),
  (
    'e160000c-0000-4000-8000-000000000002',
    NULL,
    'RPT-BOARD-Q3', 'Board Q3 Intelligence Pack (stub)',
    'board', 'Q3 2026', 'draft',
    'Board pack stub linking scorecards and forecasts.',
    'Company Secretary'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.analytics_visualizations (
  id, code, title, viz_type, dataset_id, status, summary
) VALUES
  (
    'e160000d-0000-4000-8000-000000000001',
    'VIZ-REV-TREND', 'Revenue Trend (30d)', 'line',
    'e1600002-0000-4000-8000-000000000001', 'active',
    'Daily revenue line for executive hub.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.analytics_filters (
  id, code, name, filter_type, field_path, default_value
) VALUES
  (
    'e160000e-0000-4000-8000-000000000001',
    'FLT-ESTATE', 'Estate', 'dimension', 'estate_id', 'all'
  ),
  (
    'e160000e-0000-4000-8000-000000000002',
    'FLT-PERIOD', 'Period', 'date', 'period_start', 'mtd'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.analytics_saved_views (
  id, code, title, owner_label, dashboard_id, filter_json, status, summary
) VALUES
  (
    'e160000f-0000-4000-8000-000000000001',
    'SV-CEO-MTD', 'CEO MTD Focus', 'CEO',
    'e1600009-0000-4000-8000-000000000001',
    '{"period":"mtd","estate":"all"}'::jsonb, 'active',
    'Saved executive view for month-to-date performance.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.analytics_scorecards (
  id, code, title, audience, period_label, overall_score, status, owner_label, summary, metrics
) VALUES
  (
    'e1600010-0000-4000-8000-000000000001',
    'SC-CEO-01', 'CEO Scorecard — Jul 2026', 'ceo', 'Jul 2026', 82.5, 'published',
    'CEO Office',
    'Executive scorecard stub — growth, delivery, risk.',
    '[{"label":"Revenue","score":88},{"label":"Conversion","score":80},{"label":"Construction","score":74}]'::jsonb
  ),
  (
    'e1600010-0000-4000-8000-000000000002',
    'SC-CFO-01', 'CFO Scorecard — Jul 2026', 'cfo', 'Jul 2026', 79.0, 'published',
    'CFO Office',
    'Finance scorecard stub — revenue, collections, forecast confidence.',
    '[{"label":"Revenue","score":88},{"label":"Collections","score":76},{"label":"Forecast","score":73}]'::jsonb
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.analytics_models (
  id, code, name, model_type, algorithm_label, status, owner_label, summary
) VALUES
  (
    'e1600011-0000-4000-8000-000000000001',
    'MDL-REV-30', 'Revenue 30-day Forecast', 'forecast', 'holt_winters', 'trained',
    'Analytics Science', 'Short-horizon revenue forecast for cash planning.'
  ),
  (
    'e1600011-0000-4000-8000-000000000002',
    'MDL-CONV-FWD', 'Conversion Outlook', 'forecast', 'prophet_stub', 'trained',
    'Analytics Science', 'Lead→booking conversion outlook next 4 weeks.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.analytics_forecasts (
  id, model_id, code, title, metric_label, horizon_label,
  forecast_value, lower_bound, upper_bound, confidence_pct, unit, status, summary
) VALUES
  (
    'e1600012-0000-4000-8000-000000000001',
    'e1600011-0000-4000-8000-000000000001',
    'FC-REV-30', 'Revenue next 30 days', 'Revenue', '30d',
    210000000, 185000000, 235000000, 84.0, 'currency', 'active',
    'Enterprise Forecast Engine™ stub — confidence 84%.'
  ),
  (
    'e1600012-0000-4000-8000-000000000002',
    'e1600011-0000-4000-8000-000000000002',
    'FC-CONV-4W', 'Conversion next 4 weeks', 'Conversion %', '4w',
    19.2, 17.0, 21.5, 78.5, 'pct', 'active',
    'Conversion outlook with mid confidence band.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.analytics_data_quality_rules (
  id, code, name, dataset_id, rule_type, severity, status, expression_label, summary
) VALUES
  (
    'e1600013-0000-4000-8000-000000000001',
    'DQR-REV-NULL', 'Revenue amount non-null',
    'e1600002-0000-4000-8000-000000000001',
    'completeness', 'high', 'active', 'gross_revenue IS NOT NULL',
    'Reject null revenue measures in daily mart.'
  ),
  (
    'e1600013-0000-4000-8000-000000000002',
    'DQR-CONV-STAGE', 'Booking stage known values',
    'e1600002-0000-4000-8000-000000000002',
    'accuracy', 'critical', 'active', 'booking_stage IN known_set',
    'Detect schema drift on sales stage enum.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.analytics_quality_issues (
  id, rule_id, code, title, severity, status, dataset_label, owner_label, summary
) VALUES
  (
    'e1600014-0000-4000-8000-000000000001',
    'e1600013-0000-4000-8000-000000000002',
    'DQI-2026-1601', 'Schema drift — booking_stage missing',
    'critical', 'open', 'DS-CONV', 'Data Steward',
    'ETL-CONV-WK failed; stage column absent in source extract.'
  ),
  (
    'e1600014-0000-4000-8000-000000000002',
    'e1600013-0000-4000-8000-000000000001',
    'DQI-2026-1602', 'Null revenue rows (12)',
    'high', 'investigating', 'DS-REV-DAILY', 'Finance Analyst',
    '12 daily rows with null gross_revenue pending finance correction.'
  ),
  (
    'e1600014-0000-4000-8000-000000000003',
    NULL,
    'DQI-2026-1603', 'Late construction weekly feed',
    'medium', 'open', 'DS-CONST-PCT', 'PMO Analyst',
    'Construction completeness mart delayed > 24h.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.analytics_metadata (
  id, entity_type, entity_ref, key, value
) VALUES
  (
    'e1600015-0000-4000-8000-000000000001',
    'dataset', 'DS-REV-DAILY', 'owner', 'BI Team'
  ),
  (
    'e1600015-0000-4000-8000-000000000002',
    'kpi', 'KPI-REV-MTD', 'board_visible', 'true'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.analytics_data_catalog (
  id, code, title, catalog_type, owner_label, tags, summary, status
) VALUES
  (
    'e1600016-0000-4000-8000-000000000001',
    'CAT-REV', 'Daily Revenue Mart', 'dataset', 'BI Team',
    ARRAY['finance','executive'], 'Catalog entry for DS-REV-DAILY', 'published'
  ),
  (
    'e1600016-0000-4000-8000-000000000002',
    'CAT-KPI-REV', 'Revenue MTD KPI', 'kpi', 'CFO Office',
    ARRAY['kpi','board'], 'Catalog entry for KPI-REV-MTD', 'published'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.analytics_lineage (
  id, code, source_label, target_label, lineage_type, dataset_id, summary
) VALUES
  (
    'e1600017-0000-4000-8000-000000000001',
    'LIN-FIN-REV', 'Finance Ledger Mirror', 'Daily Revenue Mart', 'etl',
    'e1600002-0000-4000-8000-000000000001',
    'SRC-FIN-01 → DS-REV-DAILY via ETL-REV-DAILY'
  ),
  (
    'e1600017-0000-4000-8000-000000000002',
    'LIN-REV-KPI', 'Daily Revenue Mart', 'Revenue MTD KPI', 'aggregate',
    'e1600002-0000-4000-8000-000000000001',
    'DS-REV-DAILY → KPI-REV-MTD aggregate'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.analytics_scheduled_reports (
  id, report_id, code, title, schedule_cron, channel_label, status, next_run_at, owner_label, summary
) VALUES
  (
    'e1600018-0000-4000-8000-000000000001',
    'e160000c-0000-4000-8000-000000000001',
    'SCH-EXEC-MON', 'Monday Executive Brief', '0 7 * * 1', 'email', 'active',
    now() + interval '3 days', 'BI Team',
    'Delivers weekly executive brief every Monday 07:00.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.analytics_ai_insights (
  id, title, body, insight_type, confidence_pct, editable, disclaimer
) VALUES
  (
    'e1600019-0000-4000-8000-000000000001',
    'Revenue momentum vs board target',
    'MTD revenue at ₦185M (+14.2%) tracking toward ₦200M target; collections lag may compress cash conversion.',
    'briefing', 86, true, 'AI-generated — editable / advisory'
  ),
  (
    'e1600019-0000-4000-8000-000000000002',
    'ETL failure impacting sales KPIs',
    'ETL-CONV-WK failure and DQI-2026-1601 suggest treating conversion KPI as watch until schema fix lands.',
    'quality', 91, true, 'AI-generated — editable / advisory'
  ),
  (
    'e1600019-0000-4000-8000-000000000003',
    'Construction completion slowing',
    'Construction completion 72.4% with watch status; board pack should call out site delay risk.',
    'kpi', 79, true, 'AI-generated — editable / advisory'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.analytics_activity_logs (
  id, action, summary, actor_label, entity_type, occurred_at
) VALUES
  (
    'e160001a-0000-4000-8000-000000000001',
    'etl_success', 'ETL-REV-DAILY completed — 12,540 rows',
    'Data Eng', 'etl_job', now() - interval '6 hours'
  ),
  (
    'e160001a-0000-4000-8000-000000000002',
    'etl_failed', 'ETL-CONV-WK failed — booking_stage missing',
    'Data Eng', 'etl_job', now() - interval '2 days'
  ),
  (
    'e160001a-0000-4000-8000-000000000003',
    'quality_opened', 'DQI-2026-1601 opened as critical',
    'Data Steward', 'quality_issue', now() - interval '2 days'
  ),
  (
    'e160001a-0000-4000-8000-000000000004',
    'dashboard_published', 'DB-EXEC-01 Executive Intelligence Hub published',
    'BI Lead', 'dashboard', now() - interval '5 days'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.analytics_notifications (
  id, title, body, severity, status, link_path
) VALUES
  (
    'e160001b-0000-4000-8000-000000000001',
    'ETL failure — Sales Conversion',
    'ETL-CONV-WK failed. Open quality issue DQI-2026-1601.',
    'critical', 'unread', '/dashboard/analytics'
  ),
  (
    'e160001b-0000-4000-8000-000000000002',
    'Construction % on watch',
    'KPI-CONST-PCT at 72.4% — below stretch pace.',
    'warning', 'unread', '/dashboard/analytics'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.analytics_ai_conversations (
  id, title, status, actor_label, last_message
) VALUES
  (
    'e160001c-0000-4000-8000-000000000001',
    'Why is conversion KPI stale?', 'open', 'CFO',
    'AI: Conversion mart ETL failed on schema drift — treat as advisory until fix.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.analytics_search_history (
  id, query_text, actor_label, result_count
) VALUES
  (
    'e160001d-0000-4000-8000-000000000001',
    'revenue mtd', 'CEO', 4
  ),
  (
    'e160001d-0000-4000-8000-000000000002',
    'etl failed', 'Data Steward', 2
  )
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.analytics_data_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_datasets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_fact_tables ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_dimension_tables ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_etl_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_pipeline_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_kpis ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_kpi_targets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_dashboards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_dashboard_widgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_report_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_visualizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_filters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_saved_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_scorecards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_models ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_forecasts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_data_quality_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_quality_issues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_metadata ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_data_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_lineage ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_scheduled_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_search_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_ai_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_ai_insights ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_notifications ENABLE ROW LEVEL SECURITY;

-- Helper: slug FIRST in has_permission

DROP POLICY IF EXISTS analytics_data_sources_select ON public.analytics_data_sources;
DROP POLICY IF EXISTS analytics_data_sources_write ON public.analytics_data_sources;
CREATE POLICY analytics_data_sources_select ON public.analytics_data_sources FOR SELECT
  USING (public.has_permission('analytics.read', auth.uid()) OR public.has_permission('analytics.warehouse', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY analytics_data_sources_write ON public.analytics_data_sources FOR ALL
  USING (public.has_permission('analytics.warehouse', auth.uid()) OR public.has_permission('analytics.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('analytics.warehouse', auth.uid()) OR public.has_permission('analytics.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS analytics_datasets_select ON public.analytics_datasets;
DROP POLICY IF EXISTS analytics_datasets_write ON public.analytics_datasets;
CREATE POLICY analytics_datasets_select ON public.analytics_datasets FOR SELECT
  USING (public.has_permission('analytics.read', auth.uid()) OR public.has_permission('analytics.warehouse', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY analytics_datasets_write ON public.analytics_datasets FOR ALL
  USING (public.has_permission('analytics.warehouse', auth.uid()) OR public.has_permission('analytics.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('analytics.warehouse', auth.uid()) OR public.has_permission('analytics.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS analytics_fact_tables_select ON public.analytics_fact_tables;
DROP POLICY IF EXISTS analytics_fact_tables_write ON public.analytics_fact_tables;
CREATE POLICY analytics_fact_tables_select ON public.analytics_fact_tables FOR SELECT
  USING (public.has_permission('analytics.read', auth.uid()) OR public.has_permission('analytics.warehouse', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY analytics_fact_tables_write ON public.analytics_fact_tables FOR ALL
  USING (public.has_permission('analytics.warehouse', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('analytics.warehouse', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS analytics_dimension_tables_select ON public.analytics_dimension_tables;
DROP POLICY IF EXISTS analytics_dimension_tables_write ON public.analytics_dimension_tables;
CREATE POLICY analytics_dimension_tables_select ON public.analytics_dimension_tables FOR SELECT
  USING (public.has_permission('analytics.read', auth.uid()) OR public.has_permission('analytics.warehouse', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY analytics_dimension_tables_write ON public.analytics_dimension_tables FOR ALL
  USING (public.has_permission('analytics.warehouse', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('analytics.warehouse', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS analytics_etl_jobs_select ON public.analytics_etl_jobs;
DROP POLICY IF EXISTS analytics_etl_jobs_write ON public.analytics_etl_jobs;
CREATE POLICY analytics_etl_jobs_select ON public.analytics_etl_jobs FOR SELECT
  USING (public.has_permission('analytics.read', auth.uid()) OR public.has_permission('analytics.etl', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY analytics_etl_jobs_write ON public.analytics_etl_jobs FOR ALL
  USING (public.has_permission('analytics.etl', auth.uid()) OR public.has_permission('analytics.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('analytics.etl', auth.uid()) OR public.has_permission('analytics.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS analytics_pipeline_logs_select ON public.analytics_pipeline_logs;
DROP POLICY IF EXISTS analytics_pipeline_logs_write ON public.analytics_pipeline_logs;
CREATE POLICY analytics_pipeline_logs_select ON public.analytics_pipeline_logs FOR SELECT
  USING (public.has_permission('analytics.read', auth.uid()) OR public.has_permission('analytics.etl', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY analytics_pipeline_logs_write ON public.analytics_pipeline_logs FOR ALL
  USING (public.has_permission('analytics.etl', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('analytics.etl', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS analytics_kpis_select ON public.analytics_kpis;
DROP POLICY IF EXISTS analytics_kpis_write ON public.analytics_kpis;
CREATE POLICY analytics_kpis_select ON public.analytics_kpis FOR SELECT
  USING (public.has_permission('analytics.read', auth.uid()) OR public.has_permission('analytics.kpis', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY analytics_kpis_write ON public.analytics_kpis FOR ALL
  USING (public.has_permission('analytics.kpis', auth.uid()) OR public.has_permission('analytics.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('analytics.kpis', auth.uid()) OR public.has_permission('analytics.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS analytics_kpi_targets_select ON public.analytics_kpi_targets;
DROP POLICY IF EXISTS analytics_kpi_targets_write ON public.analytics_kpi_targets;
CREATE POLICY analytics_kpi_targets_select ON public.analytics_kpi_targets FOR SELECT
  USING (public.has_permission('analytics.read', auth.uid()) OR public.has_permission('analytics.kpis', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY analytics_kpi_targets_write ON public.analytics_kpi_targets FOR ALL
  USING (public.has_permission('analytics.kpis', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('analytics.kpis', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS analytics_dashboards_select ON public.analytics_dashboards;
DROP POLICY IF EXISTS analytics_dashboards_write ON public.analytics_dashboards;
CREATE POLICY analytics_dashboards_select ON public.analytics_dashboards FOR SELECT
  USING (public.has_permission('analytics.read', auth.uid()) OR public.has_permission('analytics.dashboards', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY analytics_dashboards_write ON public.analytics_dashboards FOR ALL
  USING (public.has_permission('analytics.dashboards', auth.uid()) OR public.has_permission('analytics.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('analytics.dashboards', auth.uid()) OR public.has_permission('analytics.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS analytics_dashboard_widgets_select ON public.analytics_dashboard_widgets;
DROP POLICY IF EXISTS analytics_dashboard_widgets_write ON public.analytics_dashboard_widgets;
CREATE POLICY analytics_dashboard_widgets_select ON public.analytics_dashboard_widgets FOR SELECT
  USING (public.has_permission('analytics.read', auth.uid()) OR public.has_permission('analytics.dashboards', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY analytics_dashboard_widgets_write ON public.analytics_dashboard_widgets FOR ALL
  USING (public.has_permission('analytics.dashboards', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('analytics.dashboards', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS analytics_report_templates_select ON public.analytics_report_templates;
DROP POLICY IF EXISTS analytics_report_templates_write ON public.analytics_report_templates;
CREATE POLICY analytics_report_templates_select ON public.analytics_report_templates FOR SELECT
  USING (public.has_permission('analytics.read', auth.uid()) OR public.has_permission('analytics.reports', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY analytics_report_templates_write ON public.analytics_report_templates FOR ALL
  USING (public.has_permission('analytics.reports', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('analytics.reports', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS analytics_reports_select ON public.analytics_reports;
DROP POLICY IF EXISTS analytics_reports_write ON public.analytics_reports;
CREATE POLICY analytics_reports_select ON public.analytics_reports FOR SELECT
  USING (public.has_permission('analytics.read', auth.uid()) OR public.has_permission('analytics.reports', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY analytics_reports_write ON public.analytics_reports FOR ALL
  USING (public.has_permission('analytics.reports', auth.uid()) OR public.has_permission('analytics.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('analytics.reports', auth.uid()) OR public.has_permission('analytics.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS analytics_visualizations_select ON public.analytics_visualizations;
DROP POLICY IF EXISTS analytics_visualizations_write ON public.analytics_visualizations;
CREATE POLICY analytics_visualizations_select ON public.analytics_visualizations FOR SELECT
  USING (public.has_permission('analytics.read', auth.uid()) OR public.has_permission('analytics.dashboards', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY analytics_visualizations_write ON public.analytics_visualizations FOR ALL
  USING (public.has_permission('analytics.dashboards', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('analytics.dashboards', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS analytics_filters_select ON public.analytics_filters;
DROP POLICY IF EXISTS analytics_filters_write ON public.analytics_filters;
CREATE POLICY analytics_filters_select ON public.analytics_filters FOR SELECT
  USING (public.has_permission('analytics.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY analytics_filters_write ON public.analytics_filters FOR ALL
  USING (public.has_permission('analytics.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('analytics.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS analytics_saved_views_select ON public.analytics_saved_views;
DROP POLICY IF EXISTS analytics_saved_views_write ON public.analytics_saved_views;
CREATE POLICY analytics_saved_views_select ON public.analytics_saved_views FOR SELECT
  USING (public.has_permission('analytics.read', auth.uid()) OR public.has_permission('analytics.dashboards', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY analytics_saved_views_write ON public.analytics_saved_views FOR ALL
  USING (public.has_permission('analytics.dashboards', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('analytics.dashboards', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS analytics_scorecards_select ON public.analytics_scorecards;
DROP POLICY IF EXISTS analytics_scorecards_write ON public.analytics_scorecards;
CREATE POLICY analytics_scorecards_select ON public.analytics_scorecards FOR SELECT
  USING (public.has_permission('analytics.read', auth.uid()) OR public.has_permission('analytics.kpis', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY analytics_scorecards_write ON public.analytics_scorecards FOR ALL
  USING (public.has_permission('analytics.kpis', auth.uid()) OR public.has_permission('analytics.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('analytics.kpis', auth.uid()) OR public.has_permission('analytics.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS analytics_models_select ON public.analytics_models;
DROP POLICY IF EXISTS analytics_models_write ON public.analytics_models;
CREATE POLICY analytics_models_select ON public.analytics_models FOR SELECT
  USING (public.has_permission('analytics.read', auth.uid()) OR public.has_permission('analytics.forecasts', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY analytics_models_write ON public.analytics_models FOR ALL
  USING (public.has_permission('analytics.forecasts', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('analytics.forecasts', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS analytics_forecasts_select ON public.analytics_forecasts;
DROP POLICY IF EXISTS analytics_forecasts_write ON public.analytics_forecasts;
CREATE POLICY analytics_forecasts_select ON public.analytics_forecasts FOR SELECT
  USING (public.has_permission('analytics.read', auth.uid()) OR public.has_permission('analytics.forecasts', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY analytics_forecasts_write ON public.analytics_forecasts FOR ALL
  USING (public.has_permission('analytics.forecasts', auth.uid()) OR public.has_permission('analytics.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('analytics.forecasts', auth.uid()) OR public.has_permission('analytics.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS analytics_data_quality_rules_select ON public.analytics_data_quality_rules;
DROP POLICY IF EXISTS analytics_data_quality_rules_write ON public.analytics_data_quality_rules;
CREATE POLICY analytics_data_quality_rules_select ON public.analytics_data_quality_rules FOR SELECT
  USING (public.has_permission('analytics.read', auth.uid()) OR public.has_permission('analytics.quality', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY analytics_data_quality_rules_write ON public.analytics_data_quality_rules FOR ALL
  USING (public.has_permission('analytics.quality', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('analytics.quality', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS analytics_quality_issues_select ON public.analytics_quality_issues;
DROP POLICY IF EXISTS analytics_quality_issues_write ON public.analytics_quality_issues;
CREATE POLICY analytics_quality_issues_select ON public.analytics_quality_issues FOR SELECT
  USING (public.has_permission('analytics.read', auth.uid()) OR public.has_permission('analytics.quality', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY analytics_quality_issues_write ON public.analytics_quality_issues FOR ALL
  USING (public.has_permission('analytics.quality', auth.uid()) OR public.has_permission('analytics.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('analytics.quality', auth.uid()) OR public.has_permission('analytics.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS analytics_metadata_select ON public.analytics_metadata;
DROP POLICY IF EXISTS analytics_metadata_write ON public.analytics_metadata;
CREATE POLICY analytics_metadata_select ON public.analytics_metadata FOR SELECT
  USING (public.has_permission('analytics.read', auth.uid()) OR public.has_permission('analytics.governance', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY analytics_metadata_write ON public.analytics_metadata FOR ALL
  USING (public.has_permission('analytics.governance', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('analytics.governance', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS analytics_data_catalog_select ON public.analytics_data_catalog;
DROP POLICY IF EXISTS analytics_data_catalog_write ON public.analytics_data_catalog;
CREATE POLICY analytics_data_catalog_select ON public.analytics_data_catalog FOR SELECT
  USING (public.has_permission('analytics.read', auth.uid()) OR public.has_permission('analytics.governance', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY analytics_data_catalog_write ON public.analytics_data_catalog FOR ALL
  USING (public.has_permission('analytics.governance', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('analytics.governance', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS analytics_lineage_select ON public.analytics_lineage;
DROP POLICY IF EXISTS analytics_lineage_write ON public.analytics_lineage;
CREATE POLICY analytics_lineage_select ON public.analytics_lineage FOR SELECT
  USING (public.has_permission('analytics.read', auth.uid()) OR public.has_permission('analytics.governance', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY analytics_lineage_write ON public.analytics_lineage FOR ALL
  USING (public.has_permission('analytics.governance', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('analytics.governance', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS analytics_scheduled_reports_select ON public.analytics_scheduled_reports;
DROP POLICY IF EXISTS analytics_scheduled_reports_write ON public.analytics_scheduled_reports;
CREATE POLICY analytics_scheduled_reports_select ON public.analytics_scheduled_reports FOR SELECT
  USING (public.has_permission('analytics.read', auth.uid()) OR public.has_permission('analytics.schedule', auth.uid()) OR public.has_permission('analytics.reports', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY analytics_scheduled_reports_write ON public.analytics_scheduled_reports FOR ALL
  USING (public.has_permission('analytics.schedule', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('analytics.schedule', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS analytics_search_history_select ON public.analytics_search_history;
DROP POLICY IF EXISTS analytics_search_history_write ON public.analytics_search_history;
CREATE POLICY analytics_search_history_select ON public.analytics_search_history FOR SELECT
  USING (public.has_permission('analytics.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY analytics_search_history_write ON public.analytics_search_history FOR ALL
  USING (public.has_permission('analytics.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('analytics.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS analytics_ai_conversations_select ON public.analytics_ai_conversations;
DROP POLICY IF EXISTS analytics_ai_conversations_write ON public.analytics_ai_conversations;
CREATE POLICY analytics_ai_conversations_select ON public.analytics_ai_conversations FOR SELECT
  USING (public.has_permission('analytics.read', auth.uid()) OR public.has_permission('analytics.ai', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY analytics_ai_conversations_write ON public.analytics_ai_conversations FOR ALL
  USING (public.has_permission('analytics.ai', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('analytics.ai', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS analytics_ai_insights_select ON public.analytics_ai_insights;
DROP POLICY IF EXISTS analytics_ai_insights_write ON public.analytics_ai_insights;
CREATE POLICY analytics_ai_insights_select ON public.analytics_ai_insights FOR SELECT
  USING (public.has_permission('analytics.read', auth.uid()) OR public.has_permission('analytics.ai', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY analytics_ai_insights_write ON public.analytics_ai_insights FOR ALL
  USING (public.has_permission('analytics.ai', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('analytics.ai', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS analytics_activity_logs_select ON public.analytics_activity_logs;
DROP POLICY IF EXISTS analytics_activity_logs_write ON public.analytics_activity_logs;
CREATE POLICY analytics_activity_logs_select ON public.analytics_activity_logs FOR SELECT
  USING (public.has_permission('analytics.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY analytics_activity_logs_write ON public.analytics_activity_logs FOR ALL
  USING (public.has_permission('analytics.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('analytics.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS analytics_notifications_select ON public.analytics_notifications;
DROP POLICY IF EXISTS analytics_notifications_write ON public.analytics_notifications;
CREATE POLICY analytics_notifications_select ON public.analytics_notifications FOR SELECT
  USING (public.has_permission('analytics.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY analytics_notifications_write ON public.analytics_notifications FOR ALL
  USING (public.has_permission('analytics.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('analytics.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

COMMIT;
