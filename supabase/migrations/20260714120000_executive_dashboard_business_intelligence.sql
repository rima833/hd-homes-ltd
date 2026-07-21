-- Volume 4 Part 1 — Executive Dashboard & Business Intelligence
-- Status: APPLIED remotely as executive_dashboard_business_intelligence + executive_dashboard_seeds_rls_v2 (approved 2026-07-14).
-- Mission Control configuration, KPI snapshots, activity feed, AI insights,
-- reports, notifications, and business health scores. Reuses manage_reports
-- and existing analytics where possible.
-- Note: has_permission(slug, user_id) / has_role(slug, user_id) argument order.

-- ---------------------------------------------------------------------------
-- Permissions (analytics / executive)
-- ---------------------------------------------------------------------------
INSERT INTO public.permissions (slug, name, module, description)
VALUES
  ('view_executive_dashboard', 'View Executive Dashboard', 'analytics', 'Access Mission Control executive overview'),
  ('customize_dashboard', 'Customize Dashboard', 'analytics', 'Rearrange and save executive dashboard layouts'),
  ('generate_executive_reports', 'Generate Executive Reports', 'analytics', 'Run and export executive briefings / reports'),
  ('view_business_health', 'View Business Health', 'analytics', 'View business health score and risk monitor')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE r.slug IN ('super_admin', 'admin', 'manager')
  AND p.slug IN (
    'view_executive_dashboard',
    'customize_dashboard',
    'generate_executive_reports',
    'view_business_health'
  )
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- executive_dashboards — workspaces / layouts per user
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.executive_dashboards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL DEFAULT 'Executive Dashboard',
  is_default BOOLEAN NOT NULL DEFAULT false,
  is_mission_control BOOLEAN NOT NULL DEFAULT false,
  presentation_mode BOOLEAN NOT NULL DEFAULT false,
  auto_refresh_seconds INT NOT NULL DEFAULT 60,
  layout JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_executive_dashboards_user
  ON public.executive_dashboards(user_id);

-- ---------------------------------------------------------------------------
-- dashboard_widgets catalog (seeded ids used by Part 13 PreferenceEngine)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.executive_widget_catalog (
  id TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'general',
  required_permission TEXT,
  default_span INT NOT NULL DEFAULT 1,
  is_restricted BOOLEAN NOT NULL DEFAULT false,
  sort_order INT NOT NULL DEFAULT 100
);

INSERT INTO public.executive_widget_catalog (id, label, category, required_permission, default_span, sort_order)
VALUES
  ('executive_kpis', 'KPI Overview', 'kpi', 'view_executive_dashboard', 4, 10),
  ('sales', 'Sales Performance', 'sales', 'manage_reports', 2, 20),
  ('revenue', 'Revenue Analytics', 'finance', 'manage_payments', 2, 30),
  ('properties', 'Property Performance', 'property', 'view_properties', 2, 40),
  ('investors', 'Investor Overview', 'investor', 'manage_reports', 2, 50),
  ('crm', 'Client & CRM', 'crm', 'manage_crm', 2, 60),
  ('construction', 'Construction Overview', 'construction', 'manage_construction', 2, 70),
  ('marketing', 'Marketing Overview', 'marketing', 'manage_marketing', 2, 80),
  ('support', 'Support Overview', 'support', 'manage_crm', 2, 90),
  ('finance', 'Financial Summary', 'finance', 'manage_payments', 2, 100),
  ('ai_insights', 'AI Executive Insights', 'ai', 'view_executive_dashboard', 2, 110),
  ('activity_feed', 'Live Activity Feed', 'ops', 'view_executive_dashboard', 2, 120),
  ('notifications', 'Executive Notifications', 'ops', 'view_executive_dashboard', 2, 130),
  ('schedule', 'Upcoming Schedule', 'ops', 'view_executive_dashboard', 2, 140),
  ('quick_actions', 'Quick Actions', 'ops', 'view_executive_dashboard', 2, 150),
  ('health_score', 'Business Health Score', 'kpi', 'view_business_health', 2, 160),
  ('risk_monitor', 'Operational Risk Monitor', 'ops', 'view_business_health', 2, 170),
  ('reports', 'Executive Reports', 'reports', 'generate_executive_reports', 2, 180),
  ('strategy', 'Strategy Workspace', 'strategy', 'view_executive_dashboard', 2, 190)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- widget_layouts — per-dashboard widget placement
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.widget_layouts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  dashboard_id UUID NOT NULL REFERENCES public.executive_dashboards(id) ON DELETE CASCADE,
  widget_id TEXT NOT NULL REFERENCES public.executive_widget_catalog(id),
  position INT NOT NULL DEFAULT 0,
  span INT NOT NULL DEFAULT 1,
  visible BOOLEAN NOT NULL DEFAULT true,
  pinned BOOLEAN NOT NULL DEFAULT false,
  config JSONB NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (dashboard_id, widget_id)
);

CREATE INDEX IF NOT EXISTS idx_widget_layouts_dashboard
  ON public.widget_layouts(dashboard_id);

-- ---------------------------------------------------------------------------
-- kpi_snapshots — time-bucketed KPI values for cards/charts
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.kpi_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  metric_key TEXT NOT NULL,
  label TEXT NOT NULL,
  value NUMERIC NOT NULL DEFAULT 0,
  previous_value NUMERIC,
  unit TEXT NOT NULL DEFAULT 'count',
  change_pct NUMERIC,
  series JSONB NOT NULL DEFAULT '[]'::jsonb,
  captured_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  period TEXT NOT NULL DEFAULT 'daily',
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_kpi_snapshots_metric_time
  ON public.kpi_snapshots(metric_key, captured_at DESC);

-- ---------------------------------------------------------------------------
-- executive_metrics — named metric definitions / forecasts metadata
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.executive_metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  metric_key TEXT NOT NULL UNIQUE,
  category TEXT NOT NULL,
  label TEXT NOT NULL,
  description TEXT,
  aggregation TEXT NOT NULL DEFAULT 'sum',
  forecast_enabled BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.executive_metrics (metric_key, category, label, aggregation, forecast_enabled)
VALUES
  ('total_properties', 'property', 'Total Properties', 'count', false),
  ('available_properties', 'property', 'Available Properties', 'count', false),
  ('sold_properties', 'property', 'Sold Properties', 'count', true),
  ('reserved_properties', 'property', 'Reserved Properties', 'count', false),
  ('total_clients', 'crm', 'Total Clients', 'count', true),
  ('active_investors', 'investor', 'Active Investors', 'count', true),
  ('revenue_today', 'finance', 'Today''s Revenue', 'sum', true),
  ('revenue_month', 'finance', 'Monthly Revenue', 'sum', true),
  ('pending_payments', 'finance', 'Pending Payments', 'sum', false),
  ('completed_sales', 'sales', 'Completed Sales', 'count', true),
  ('construction_projects', 'construction', 'Construction Projects', 'count', false),
  ('support_tickets_open', 'support', 'Active Support Tickets', 'count', false)
ON CONFLICT (metric_key) DO NOTHING;

-- ---------------------------------------------------------------------------
-- business_health_scores
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.business_health_scores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  overall_score INT NOT NULL CHECK (overall_score BETWEEN 0 AND 100),
  status TEXT NOT NULL DEFAULT 'good'
    CHECK (status IN ('excellent', 'good', 'needs_attention', 'critical')),
  factors JSONB NOT NULL DEFAULT '[]'::jsonb,
  history JSONB NOT NULL DEFAULT '[]'::jsonb,
  captured_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_business_health_scores_time
  ON public.business_health_scores(captured_at DESC);

-- ---------------------------------------------------------------------------
-- executive_notifications
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.executive_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  category TEXT NOT NULL DEFAULT 'alert',
  severity TEXT NOT NULL DEFAULT 'info'
    CHECK (severity IN ('info', 'warning', 'critical', 'success')),
  title TEXT NOT NULL,
  body TEXT,
  module TEXT,
  is_read BOOLEAN NOT NULL DEFAULT false,
  is_pinned BOOLEAN NOT NULL DEFAULT false,
  snoozed_until TIMESTAMPTZ,
  action_path TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_executive_notifications_user
  ON public.executive_notifications(user_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- activity_feed (executive live feed; complements activity_logs)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.executive_activity_feed (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  actor_name TEXT,
  action TEXT NOT NULL,
  module TEXT NOT NULL DEFAULT 'system',
  entity_type TEXT,
  entity_id TEXT,
  summary TEXT NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_executive_activity_feed_time
  ON public.executive_activity_feed(created_at DESC);

-- ---------------------------------------------------------------------------
-- ai_executive_insights
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ai_executive_insights (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  insight_type TEXT NOT NULL DEFAULT 'observation'
    CHECK (insight_type IN ('observation', 'recommendation', 'forecast', 'alert')),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  is_ai_generated BOOLEAN NOT NULL DEFAULT true,
  confidence NUMERIC CHECK (confidence IS NULL OR (confidence >= 0 AND confidence <= 1)),
  severity TEXT NOT NULL DEFAULT 'info',
  module TEXT,
  evidence JSONB NOT NULL DEFAULT '{}'::jsonb,
  valid_until TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ai_executive_insights_time
  ON public.ai_executive_insights(created_at DESC);

-- ---------------------------------------------------------------------------
-- quick_actions catalog
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.executive_quick_actions (
  id TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  route_or_key TEXT NOT NULL,
  icon TEXT,
  required_permission TEXT,
  sort_order INT NOT NULL DEFAULT 100,
  is_active BOOLEAN NOT NULL DEFAULT true
);

INSERT INTO public.executive_quick_actions (id, label, route_or_key, icon, required_permission, sort_order)
VALUES
  ('add_property', 'Add Property', '/dashboard/properties', 'building', 'create_property', 10),
  ('register_investor', 'Register Investor', '/dashboard/investors', 'trending-up', 'manage_users', 20),
  ('create_client', 'Create Client', '/dashboard/clients', 'user-plus', 'manage_crm', 30),
  ('schedule_inspection', 'Schedule Inspection', '/book-inspection', 'clipboard-check', 'manage_crm', 40),
  ('generate_report', 'Generate Report', '/dashboard/reports', 'file-bar-chart', 'generate_executive_reports', 50),
  ('launch_campaign', 'Launch Campaign', '/dashboard/marketing', 'megaphone', 'manage_marketing', 60),
  ('approve_kyc', 'Approve KYC', '/dashboard/compliance', 'shield-check', 'manage_users', 70),
  ('assign_lead', 'Assign Lead', '/dashboard/crm', 'user-cog', 'manage_crm', 80),
  ('create_blog', 'Create Blog Post', '/dashboard/blog', 'newspaper', 'manage_blog', 90),
  ('open_crm', 'Open CRM', '/dashboard/crm', 'contact', 'manage_crm', 100),
  ('manage_staff', 'Manage Staff', '/dashboard/organization', 'users', 'manage_users', 110)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- executive_reports
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.executive_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_type TEXT NOT NULL,
  title TEXT NOT NULL,
  requested_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'ready'
    CHECK (status IN ('queued', 'running', 'ready', 'failed')),
  format TEXT NOT NULL DEFAULT 'pdf'
    CHECK (format IN ('pdf', 'excel', 'csv')),
  file_url TEXT,
  summary JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_executive_reports_user_time
  ON public.executive_reports(requested_by, created_at DESC);

-- ---------------------------------------------------------------------------
-- dashboard_preferences (thin prefs; layouts live in executive_dashboards)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.dashboard_preferences (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  active_dashboard_id UUID REFERENCES public.executive_dashboards(id) ON DELETE SET NULL,
  mission_control_enabled BOOLEAN NOT NULL DEFAULT false,
  prefer_compact BOOLEAN NOT NULL DEFAULT false,
  prefs JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Seed demo KPI snapshots (so Mission Control is useful before live ops data)
-- ---------------------------------------------------------------------------
INSERT INTO public.kpi_snapshots (metric_key, label, value, previous_value, unit, change_pct, series, period)
VALUES
  ('total_properties', 'Total Properties', 248, 240, 'count', 3.3, '[210,218,225,232,240,244,248]'::jsonb, 'daily'),
  ('available_properties', 'Available Properties', 96, 102, 'count', -5.9, '[110,108,105,103,102,99,96]'::jsonb, 'daily'),
  ('sold_properties', 'Sold Properties', 112, 105, 'count', 6.7, '[90,94,98,101,105,108,112]'::jsonb, 'daily'),
  ('reserved_properties', 'Reserved Properties', 40, 33, 'count', 21.2, '[28,30,31,32,33,36,40]'::jsonb, 'daily'),
  ('total_clients', 'Total Clients', 1840, 1792, 'count', 2.7, '[1700,1725,1750,1770,1792,1815,1840]'::jsonb, 'daily'),
  ('active_investors', 'Active Investors', 326, 310, 'count', 5.2, '[280,290,295,300,310,318,326]'::jsonb, 'daily'),
  ('revenue_today', 'Today''s Revenue', 18500000, 14200000, 'ngn', 30.3, '[8,9,11,12,14,16,18.5]'::jsonb, 'daily'),
  ('revenue_month', 'Monthly Revenue', 412000000, 368000000, 'ngn', 12.0, '[280,300,320,340,360,368,412]'::jsonb, 'monthly'),
  ('pending_payments', 'Pending Payments', 54000000, 61000000, 'ngn', -11.5, '[70,68,65,62,61,58,54]'::jsonb, 'daily'),
  ('completed_sales', 'Completed Sales', 28, 22, 'count', 27.3, '[15,17,18,19,22,24,28]'::jsonb, 'daily'),
  ('construction_projects', 'Construction Projects', 14, 13, 'count', 7.7, '[10,11,11,12,13,13,14]'::jsonb, 'daily'),
  ('support_tickets_open', 'Active Support Tickets', 19, 24, 'count', -20.8, '[30,28,27,25,24,21,19]'::jsonb, 'daily');

INSERT INTO public.business_health_scores (overall_score, status, factors, history)
VALUES (
  82,
  'good',
  '[
    {"key":"sales","label":"Sales Performance","score":88,"weight":0.2},
    {"key":"revenue","label":"Revenue Growth","score":85,"weight":0.2},
    {"key":"investors","label":"Investor Activity","score":80,"weight":0.15},
    {"key":"satisfaction","label":"Customer Satisfaction","score":78,"weight":0.1},
    {"key":"construction","label":"Construction Progress","score":72,"weight":0.1},
    {"key":"cashflow","label":"Cash Flow","score":84,"weight":0.1},
    {"key":"productivity","label":"Staff Productivity","score":81,"weight":0.1},
    {"key":"security","label":"Security Status","score":90,"weight":0.05}
  ]'::jsonb,
  '[74,76,78,79,80,81,82]'::jsonb
);

INSERT INTO public.ai_executive_insights (insight_type, title, body, is_ai_generated, confidence, severity, module)
VALUES
  ('observation', 'Sales up 18% this week',
   'Completed sales rose from 22 to 28 week-over-week. Lekki inventory contributed the majority of closed deals.',
   true, 0.86, 'success', 'sales'),
  ('alert', 'Three high-value investors pending KYC',
   'Investors with projected AUM above NGN 50M have incomplete KYC packages. Prioritize compliance review.',
   true, 0.91, 'warning', 'compliance'),
  ('observation', 'Lekki outperforming other locations',
   'Property engagement and inspections in Lekki are ahead of Abuja and Port Harcourt this period.',
   true, 0.79, 'info', 'property'),
  ('recommendation', 'Review marketing conversion dip',
   'Campaign conversion is down ~9%. Reallocate budget toward best-performing channels from search analytics.',
   true, 0.74, 'warning', 'marketing'),
  ('alert', 'Construction Project Alpha behind schedule',
   'Milestone slippage detected. Assign PM attention and update investor communications.',
   true, 0.88, 'critical', 'construction');

INSERT INTO public.executive_activity_feed (actor_name, action, module, summary)
VALUES
  ('System', 'property_published', 'property', 'New listing published: Azure Court 3-Bed'),
  ('Amina O.', 'client_registered', 'crm', 'Client registered: Chuka Okonkwo'),
  ('Compliance', 'investor_verified', 'investor', 'Investor KYC verified: Horizon Capital'),
  ('Finance', 'payment_received', 'finance', 'Payment received: NGN 12,500,000 — Unit B4'),
  ('Field Ops', 'inspection_scheduled', 'crm', 'Inspection scheduled for Palm Estate Block C'),
  ('Support', 'ticket_created', 'support', 'Support ticket #4821 created — payment receipt'),
  ('Marketing', 'campaign_launched', 'marketing', 'Campaign launched: Lekki Early Bird July');

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.executive_dashboards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.executive_widget_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.widget_layouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kpi_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.executive_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.business_health_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.executive_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.executive_activity_feed ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_executive_insights ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.executive_quick_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.executive_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dashboard_preferences ENABLE ROW LEVEL SECURITY;

-- Catalogs readable by staff with executive view
CREATE POLICY executive_widget_catalog_select ON public.executive_widget_catalog
  FOR SELECT TO authenticated
  USING (public.has_permission('view_executive_dashboard', auth.uid())
     OR public.has_permission('manage_reports', auth.uid())
     OR public.is_staff(auth.uid()));

CREATE POLICY executive_quick_actions_select ON public.executive_quick_actions
  FOR SELECT TO authenticated
  USING (is_active AND (
    public.has_permission('view_executive_dashboard', auth.uid())
    OR public.is_staff(auth.uid())
  ));

CREATE POLICY executive_metrics_select ON public.executive_metrics
  FOR SELECT TO authenticated
  USING (public.has_permission('view_executive_dashboard', auth.uid())
     OR public.has_permission('manage_reports', auth.uid())
     OR public.is_staff(auth.uid()));

CREATE POLICY kpi_snapshots_select ON public.kpi_snapshots
  FOR SELECT TO authenticated
  USING (public.has_permission('view_executive_dashboard', auth.uid())
     OR public.has_permission('manage_reports', auth.uid())
     OR public.is_staff(auth.uid()));

CREATE POLICY business_health_select ON public.business_health_scores
  FOR SELECT TO authenticated
  USING (public.has_permission('view_business_health', auth.uid())
     OR public.has_permission('manage_reports', auth.uid())
     OR public.has_role('super_admin', auth.uid()));

CREATE POLICY ai_insights_select ON public.ai_executive_insights
  FOR SELECT TO authenticated
  USING (public.has_permission('view_executive_dashboard', auth.uid())
     OR public.has_permission('manage_reports', auth.uid())
     OR public.is_staff(auth.uid()));

CREATE POLICY activity_feed_select ON public.executive_activity_feed
  FOR SELECT TO authenticated
  USING (public.has_permission('view_executive_dashboard', auth.uid())
     OR public.is_staff(auth.uid()));

CREATE POLICY executive_dashboards_own ON public.executive_dashboards
  FOR ALL TO authenticated
  USING (user_id = auth.uid() OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (user_id = auth.uid() OR public.has_role('super_admin', auth.uid()));

CREATE POLICY widget_layouts_via_dashboard ON public.widget_layouts
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.executive_dashboards d
      WHERE d.id = dashboard_id
        AND (d.user_id = auth.uid() OR public.has_role('super_admin', auth.uid()))
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.executive_dashboards d
      WHERE d.id = dashboard_id AND d.user_id = auth.uid()
    )
    AND (
      public.has_permission('customize_dashboard', auth.uid())
      OR public.has_role('super_admin', auth.uid())
    )
  );

CREATE POLICY executive_notifications_own ON public.executive_notifications
  FOR ALL TO authenticated
  USING (user_id = auth.uid() OR user_id IS NULL OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (user_id = auth.uid() OR public.has_role('super_admin', auth.uid()));

CREATE POLICY executive_reports_select ON public.executive_reports
  FOR SELECT TO authenticated
  USING (
    requested_by = auth.uid()
    OR public.has_permission('generate_executive_reports', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

CREATE POLICY executive_reports_insert ON public.executive_reports
  FOR INSERT TO authenticated
  WITH CHECK (
    requested_by = auth.uid()
    AND public.has_permission('generate_executive_reports', auth.uid())
  );

CREATE POLICY dashboard_preferences_own ON public.dashboard_preferences
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Staff can insert feed / insights for demo & ops
CREATE POLICY activity_feed_insert_staff ON public.executive_activity_feed
  FOR INSERT TO authenticated
  WITH CHECK (public.is_staff(auth.uid()));

CREATE POLICY ai_insights_insert_staff ON public.ai_executive_insights
  FOR INSERT TO authenticated
  WITH CHECK (public.is_staff(auth.uid()) OR public.has_role('super_admin', auth.uid()));

GRANT SELECT ON public.executive_widget_catalog TO authenticated;
GRANT SELECT ON public.executive_quick_actions TO authenticated;
GRANT SELECT ON public.executive_metrics TO authenticated;
GRANT SELECT ON public.kpi_snapshots TO authenticated;
GRANT SELECT ON public.business_health_scores TO authenticated;
GRANT SELECT ON public.ai_executive_insights TO authenticated;
GRANT SELECT ON public.executive_activity_feed TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.executive_dashboards TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.widget_layouts TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.executive_notifications TO authenticated;
GRANT SELECT, INSERT ON public.executive_reports TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.dashboard_preferences TO authenticated;
GRANT INSERT ON public.executive_activity_feed TO authenticated;
GRANT INSERT ON public.ai_executive_insights TO authenticated;

-- Realtime for live Mission Control
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.kpi_snapshots;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.executive_activity_feed;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.executive_notifications;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.ai_executive_insights;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.business_health_scores;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
