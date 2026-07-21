-- Volume 3 Part 13 — User Preferences & Personalization Engine
-- Status: APPLIED remotely as user_preferences_personalization + user_preferences_personalization_rls (approved 2026-07-13).
-- Extends existing user_preferences / notification_preferences; adds personalization tables.

-- ---------------------------------------------------------------------------
-- Extend user_preferences extras already used for appearance / interests buckets
-- (no destructive column changes — extras JSONB is the extensibility surface)
-- ---------------------------------------------------------------------------

ALTER TABLE public.user_preferences
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- ---------------------------------------------------------------------------
-- Accessibility settings (dedicated for realtime + Accessibility Center)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.accessibility_settings (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  high_contrast BOOLEAN NOT NULL DEFAULT false,
  reduced_motion BOOLEAN NOT NULL DEFAULT false,
  larger_fonts BOOLEAN NOT NULL DEFAULT false,
  keyboard_navigation BOOLEAN NOT NULL DEFAULT true,
  screen_reader_optimized BOOLEAN NOT NULL DEFAULT false,
  focus_highlighting BOOLEAN NOT NULL DEFAULT true,
  font_scale NUMERIC(4,2) NOT NULL DEFAULT 1.0,
  color_accessibility TEXT NOT NULL DEFAULT 'standard',
  extras JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Theme preferences (mirrors appearance; supports accent / density history)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.theme_preferences (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  theme TEXT NOT NULL DEFAULT 'system',
  accent_color TEXT NOT NULL DEFAULT 'gold',
  density TEXT NOT NULL DEFAULT 'comfortable',
  animation_level TEXT NOT NULL DEFAULT 'full',
  card_style TEXT NOT NULL DEFAULT 'elevated',
  extras JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Localization preferences (optional dedicated; also mirrored in user_preferences)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.localization_preferences (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  language TEXT NOT NULL DEFAULT 'en',
  country TEXT NOT NULL DEFAULT 'NG',
  currency TEXT NOT NULL DEFAULT 'NGN',
  timezone TEXT NOT NULL DEFAULT 'Africa/Lagos',
  date_format TEXT NOT NULL DEFAULT 'dd/MM/yyyy',
  number_format TEXT NOT NULL DEFAULT 'en_NG',
  measurement_units TEXT NOT NULL DEFAULT 'metric',
  extras JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Dashboard layouts + widgets (Smart Workspace Builder™)
-- id is TEXT so role defaults / named workspaces can use stable keys
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.dashboard_layouts (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  is_default BOOLEAN NOT NULL DEFAULT false,
  workspace_slug TEXT,
  widgets JSONB NOT NULL DEFAULT '[]'::jsonb,
  layout_mode TEXT NOT NULL DEFAULT 'grid',
  extras JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_dashboard_layouts_user
  ON public.dashboard_layouts (user_id);

CREATE UNIQUE INDEX IF NOT EXISTS uq_dashboard_layouts_user_workspace
  ON public.dashboard_layouts (user_id, COALESCE(workspace_slug, id));

CREATE TABLE IF NOT EXISTS public.dashboard_widgets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  layout_id TEXT NOT NULL REFERENCES public.dashboard_layouts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  widget_id TEXT NOT NULL,
  visible BOOLEAN NOT NULL DEFAULT true,
  pinned BOOLEAN NOT NULL DEFAULT false,
  sort_order INT NOT NULL DEFAULT 0,
  width INT NOT NULL DEFAULT 1,
  height INT NOT NULL DEFAULT 1,
  config JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (layout_id, widget_id)
);

-- ---------------------------------------------------------------------------
-- Favorites, saved searches, recent activity, shortcuts
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.favorite_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  item_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  title TEXT NOT NULL,
  subtitle TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, item_type, entity_id)
);

CREATE INDEX IF NOT EXISTS idx_favorite_items_user
  ON public.favorite_items (user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.saved_searches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  criteria JSONB NOT NULL DEFAULT '{}'::jsonb,
  alerts_enabled BOOLEAN NOT NULL DEFAULT false,
  schedule_cron TEXT,
  shared BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_saved_searches_user
  ON public.saved_searches (user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.personalization_recent_activity (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  activity_type TEXT NOT NULL,
  title TEXT NOT NULL,
  entity_type TEXT,
  entity_id TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_personalization_recent_user
  ON public.personalization_recent_activity (user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.user_shortcuts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  label TEXT NOT NULL,
  action_key TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  icon TEXT,
  extras JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, action_key)
);

-- ---------------------------------------------------------------------------
-- Personalization profile + recommendation + behavior
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.personalization_profiles (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  template_slug TEXT,
  property_interests JSONB NOT NULL DEFAULT '{}'::jsonb,
  privacy JSONB NOT NULL DEFAULT '{}'::jsonb,
  welcome_config JSONB NOT NULL DEFAULT '{}'::jsonb,
  command_palette JSONB NOT NULL DEFAULT '{}'::jsonb,
  extras JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.recommendation_preferences (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  enabled BOOLEAN NOT NULL DEFAULT true,
  categories TEXT[] NOT NULL DEFAULT ARRAY['properties','investments','blog','services'],
  weights JSONB NOT NULL DEFAULT '{}'::jsonb,
  exclude_entity_ids TEXT[] NOT NULL DEFAULT '{}',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.behavior_metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  metric_key TEXT NOT NULL,
  metric_value NUMERIC NOT NULL DEFAULT 0,
  dimensions JSONB NOT NULL DEFAULT '{}'::jsonb,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, metric_key)
);

CREATE INDEX IF NOT EXISTS idx_behavior_metrics_user
  ON public.behavior_metrics (user_id);

-- ---------------------------------------------------------------------------
-- Enterprise Preference Profiles (role templates)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.preference_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  role_slug TEXT,
  description TEXT,
  appearance JSONB NOT NULL DEFAULT '{}'::jsonb,
  accessibility JSONB NOT NULL DEFAULT '{}'::jsonb,
  dashboard_layout JSONB NOT NULL DEFAULT '{}'::jsonb,
  shortcuts JSONB NOT NULL DEFAULT '[]'::jsonb,
  localization JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.preference_templates (name, slug, role_slug, description, dashboard_layout)
VALUES
  (
    'Sales Executive Template',
    'sales_executive',
    'sales_team',
    'Default workspace for sales staff',
    '{"name":"Sales Workspace","widgets":[{"widget_id":"assignedTasks","visible":true,"order":0},{"widget_id":"leads","visible":true,"order":1},{"widget_id":"calendar","visible":true,"order":2}]}'::jsonb
  ),
  (
    'Investor Template',
    'investor',
    'investor',
    'Default workspace for investors',
    '{"name":"Investor Dashboard","widgets":[{"widget_id":"portfolioValue","visible":true,"order":0},{"widget_id":"roi","visible":true,"order":1},{"widget_id":"investmentPerformance","visible":true,"order":2}]}'::jsonb
  ),
  (
    'Customer Support Template',
    'customer_support',
    'sales_team',
    'Support-oriented shortcuts and widgets',
    '{"name":"Support Workspace","widgets":[{"widget_id":"messages","visible":true,"order":0},{"widget_id":"notifications","visible":true,"order":1},{"widget_id":"assignedTasks","visible":true,"order":2}]}'::jsonb
  ),
  (
    'Executive Management Template',
    'executive_management',
    'admin',
    'Executive KPI workspace',
    '{"name":"Executive Dashboard","widgets":[{"widget_id":"executiveKpis","visible":true,"order":0},{"widget_id":"sales","visible":true,"order":1},{"widget_id":"revenue","visible":true,"order":2}]}'::jsonb
  )
ON CONFLICT (slug) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Anonymized personalization analytics (aggregated; no PII required)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.personalization_analytics_daily (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  metric_date DATE NOT NULL DEFAULT CURRENT_DATE,
  metric_key TEXT NOT NULL,
  metric_value NUMERIC NOT NULL DEFAULT 0,
  dimensions JSONB NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (metric_date, metric_key)
);

-- ---------------------------------------------------------------------------
-- RLS — users edit only their own rows
-- ---------------------------------------------------------------------------

ALTER TABLE public.accessibility_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.theme_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.localization_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dashboard_layouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dashboard_widgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorite_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saved_searches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.personalization_recent_activity ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_shortcuts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.personalization_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recommendation_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.behavior_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.preference_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.personalization_analytics_daily ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS accessibility_settings_own ON public.accessibility_settings;
CREATE POLICY accessibility_settings_own ON public.accessibility_settings
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS theme_preferences_own ON public.theme_preferences;
CREATE POLICY theme_preferences_own ON public.theme_preferences
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS localization_preferences_own ON public.localization_preferences;
CREATE POLICY localization_preferences_own ON public.localization_preferences
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS dashboard_layouts_own ON public.dashboard_layouts;
CREATE POLICY dashboard_layouts_own ON public.dashboard_layouts
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS dashboard_widgets_own ON public.dashboard_widgets;
CREATE POLICY dashboard_widgets_own ON public.dashboard_widgets
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS favorite_items_own ON public.favorite_items;
CREATE POLICY favorite_items_own ON public.favorite_items
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS saved_searches_own ON public.saved_searches;
CREATE POLICY saved_searches_own ON public.saved_searches
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS personalization_recent_own ON public.personalization_recent_activity;
CREATE POLICY personalization_recent_own ON public.personalization_recent_activity
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS user_shortcuts_own ON public.user_shortcuts;
CREATE POLICY user_shortcuts_own ON public.user_shortcuts
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS personalization_profiles_own ON public.personalization_profiles;
CREATE POLICY personalization_profiles_own ON public.personalization_profiles
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS recommendation_preferences_own ON public.recommendation_preferences;
CREATE POLICY recommendation_preferences_own ON public.recommendation_preferences
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS behavior_metrics_own ON public.behavior_metrics;
CREATE POLICY behavior_metrics_own ON public.behavior_metrics
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS preference_templates_read ON public.preference_templates;
CREATE POLICY preference_templates_read ON public.preference_templates
  FOR SELECT USING (is_active = true OR public.has_role('admin') OR public.has_role('super_admin'));

DROP POLICY IF EXISTS preference_templates_admin ON public.preference_templates;
CREATE POLICY preference_templates_admin ON public.preference_templates
  FOR ALL USING (public.has_role('admin') OR public.has_role('super_admin'))
  WITH CHECK (public.has_role('admin') OR public.has_role('super_admin'));

DROP POLICY IF EXISTS personalization_analytics_staff ON public.personalization_analytics_daily;
CREATE POLICY personalization_analytics_staff ON public.personalization_analytics_daily
  FOR SELECT USING (
    public.has_role('admin')
    OR public.has_role('super_admin')
    OR public.has_permission('manage_reports')
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON public.accessibility_settings TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.theme_preferences TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.localization_preferences TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.dashboard_layouts TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.dashboard_widgets TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.favorite_items TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.saved_searches TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.personalization_recent_activity TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_shortcuts TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.personalization_profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.recommendation_preferences TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.behavior_metrics TO authenticated;
GRANT SELECT ON public.preference_templates TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.preference_templates TO authenticated;
GRANT SELECT ON public.personalization_analytics_daily TO authenticated;

-- ---------------------------------------------------------------------------
-- Realtime (cross-device sync)
-- ---------------------------------------------------------------------------

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.user_preferences;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.accessibility_settings;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.dashboard_layouts;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.favorite_items;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.saved_searches;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.theme_preferences;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
