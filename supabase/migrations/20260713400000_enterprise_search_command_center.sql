-- Volume 3 Part 14 — Enterprise Search & Global Command Center
-- Status: APPLIED remotely as enterprise_search_command_center + enterprise_search_command_center_rls (approved 2026-07-13).
-- Extends Part 13 saved_searches; adds search index, history, analytics, commands.

-- ---------------------------------------------------------------------------
-- Search index (permission-aware metadata for universal search)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.search_index (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_id TEXT NOT NULL,
  module TEXT NOT NULL,
  title TEXT NOT NULL,
  subtitle TEXT,
  path TEXT NOT NULL DEFAULT '/',
  keywords TEXT[] NOT NULL DEFAULT '{}',
  permission_slug TEXT,
  popularity INT NOT NULL DEFAULT 0,
  preview JSONB NOT NULL DEFAULT '{}'::jsonb,
  related_ids TEXT[] NOT NULL DEFAULT '{}',
  is_active BOOLEAN NOT NULL DEFAULT true,
  indexed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (module, entity_id)
);

DO $$ BEGIN
  CREATE EXTENSION IF NOT EXISTS pg_trgm;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_search_index_module
  ON public.search_index (module) WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_search_index_keywords
  ON public.search_index USING gin (keywords);

DO $$ BEGIN
  CREATE INDEX IF NOT EXISTS idx_search_index_title_trgm
    ON public.search_index USING gin (title gin_trgm_ops);
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- Search history + preferences + favorite commands
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.search_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  query TEXT NOT NULL,
  mode TEXT NOT NULL DEFAULT 'universal',
  result_count INT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_search_history_user
  ON public.search_history (user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.search_preferences (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  default_mode TEXT NOT NULL DEFAULT 'universal',
  show_previews BOOLEAN NOT NULL DEFAULT true,
  include_commands BOOLEAN NOT NULL DEFAULT true,
  extras JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.favorite_commands (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  action_key TEXT NOT NULL,
  label TEXT NOT NULL,
  path TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, action_key)
);

-- Extend Part 13 saved_searches for command-center scope
ALTER TABLE public.saved_searches
  ADD COLUMN IF NOT EXISTS search_mode TEXT DEFAULT 'universal',
  ADD COLUMN IF NOT EXISTS source TEXT DEFAULT 'personalization';

-- ---------------------------------------------------------------------------
-- Command palette catalog (admin-manageable)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.command_palette_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  action_key TEXT NOT NULL UNIQUE,
  label TEXT NOT NULL,
  path TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'action',
  keywords TEXT[] NOT NULL DEFAULT '{}',
  required_permission TEXT,
  is_executive BOOLEAN NOT NULL DEFAULT false,
  is_active BOOLEAN NOT NULL DEFAULT true,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.command_palette_items
  (action_key, label, path, category, keywords, required_permission, is_executive, sort_order)
VALUES
  ('create_property', 'Create Property', '/dashboard/properties', 'create', ARRAY['add','new','property'], 'edit_property', false, 10),
  ('book_inspection', 'Book Inspection', '/book-inspection', 'create', ARRAY['schedule','visit'], NULL, false, 20),
  ('open_investor_dashboard', 'Open Investor Dashboard', '/investor', 'navigate', ARRAY['investor','portfolio'], 'view_investments', false, 30),
  ('generate_sales_report', 'Generate Sales Report', '/dashboard/reports', 'report', ARRAY['sales','report'], 'manage_reports', true, 40),
  ('approve_kyc', 'Approve KYC', '/dashboard/compliance', 'action', ARRAY['kyc','compliance'], 'manage_roles', true, 50),
  ('system_health', 'Open system health dashboard', '/dashboard/activity-logs', 'executive', ARRAY['health','audit'], 'view_audit_logs', true, 60),
  ('today_sales', 'View today''s sales summary', '/dashboard/reports', 'executive', ARRAY['sales','today'], 'manage_reports', true, 70)
ON CONFLICT (action_key) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Synonyms (semantic foundation) + filter presets + analytics
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.search_synonyms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  term TEXT NOT NULL,
  synonym TEXT NOT NULL,
  UNIQUE (term, synonym)
);

INSERT INTO public.search_synonyms (term, synonym) VALUES
  ('house', 'property'),
  ('property', 'house'),
  ('apartment', 'flat'),
  ('flat', 'apartment'),
  ('kyc', 'verification'),
  ('lekki', 'lekki phase 1')
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS public.search_filters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  filters JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_shared BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.search_analytics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  metric_key TEXT NOT NULL,
  metric_value NUMERIC NOT NULL DEFAULT 1,
  dimensions JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_search_analytics_key
  ON public.search_analytics (metric_key, created_at DESC);

-- Seed a few index rows for demo / bootstrap
INSERT INTO public.search_index
  (entity_id, module, title, subtitle, path, keywords, permission_slug, popularity, preview)
VALUES
  ('prop-lekki-pearl', 'property', 'Lekki Pearl Residence', 'Lekki Phase 1 · ₦185M', '/properties',
   ARRAY['lekki','phase 1','apartment'], NULL, 95,
   '{"price":"₦185M","location":"Lekki Phase 1","status":"Available"}'::jsonb),
  ('cmd-create-property', 'command', 'Create Property', 'Quick action', '/dashboard/properties',
   ARRAY['create','property','add'], 'edit_property', 90, '{}'::jsonb)
ON CONFLICT (module, entity_id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

ALTER TABLE public.search_index ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.search_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.search_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorite_commands ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.command_palette_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.search_synonyms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.search_filters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.search_analytics ENABLE ROW LEVEL SECURITY;

-- Index: authenticated can read active rows; server-side permission filtering in app
DROP POLICY IF EXISTS search_index_read ON public.search_index;
CREATE POLICY search_index_read ON public.search_index
  FOR SELECT USING (is_active = true);

DROP POLICY IF EXISTS search_index_admin ON public.search_index;
CREATE POLICY search_index_admin ON public.search_index
  FOR ALL USING (public.has_role('admin') OR public.has_role('super_admin'))
  WITH CHECK (public.has_role('admin') OR public.has_role('super_admin'));

DROP POLICY IF EXISTS search_history_own ON public.search_history;
CREATE POLICY search_history_own ON public.search_history
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS search_preferences_own ON public.search_preferences;
CREATE POLICY search_preferences_own ON public.search_preferences
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS favorite_commands_own ON public.favorite_commands;
CREATE POLICY favorite_commands_own ON public.favorite_commands
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS command_palette_items_read ON public.command_palette_items;
CREATE POLICY command_palette_items_read ON public.command_palette_items
  FOR SELECT USING (is_active = true);

DROP POLICY IF EXISTS command_palette_items_admin ON public.command_palette_items;
CREATE POLICY command_palette_items_admin ON public.command_palette_items
  FOR ALL USING (public.has_role('admin') OR public.has_role('super_admin'))
  WITH CHECK (public.has_role('admin') OR public.has_role('super_admin'));

DROP POLICY IF EXISTS search_synonyms_read ON public.search_synonyms;
CREATE POLICY search_synonyms_read ON public.search_synonyms
  FOR SELECT USING (true);

DROP POLICY IF EXISTS search_filters_own ON public.search_filters;
CREATE POLICY search_filters_own ON public.search_filters
  FOR ALL USING (user_id = auth.uid() OR is_shared = true)
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS search_analytics_staff ON public.search_analytics;
CREATE POLICY search_analytics_staff ON public.search_analytics
  FOR SELECT USING (
    public.has_role('admin')
    OR public.has_role('super_admin')
    OR public.has_permission('manage_reports')
  );

DROP POLICY IF EXISTS search_analytics_insert ON public.search_analytics;
CREATE POLICY search_analytics_insert ON public.search_analytics
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

GRANT SELECT ON public.search_index TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.search_index TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.search_history TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.search_preferences TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.favorite_commands TO authenticated;
GRANT SELECT ON public.command_palette_items TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.command_palette_items TO authenticated;
GRANT SELECT ON public.search_synonyms TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.search_filters TO authenticated;
GRANT SELECT, INSERT ON public.search_analytics TO authenticated;

-- Realtime for index + history
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.search_index;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.search_history;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.command_palette_items;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
