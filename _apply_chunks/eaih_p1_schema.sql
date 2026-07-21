-- Permissions
-- ---------------------------------------------------------------------------
INSERT INTO public.permissions (slug, name, description, module) VALUES
  ('aihub.read', 'View AI Hub', 'View AI Command Center', 'aihub'),
  ('aihub.write', 'Manage AI Hub', 'Create and edit AI hub records', 'aihub'),
  ('aihub.copilots', 'AI Copilots', 'Manage and use enterprise copilots', 'aihub'),
  ('aihub.models', 'AI Models', 'Manage models, versions, and training', 'aihub'),
  ('aihub.predictions', 'AI Predictions', 'View and manage predictions', 'aihub'),
  ('aihub.recommendations', 'AI Recommendations', 'Manage recommendation feeds', 'aihub'),
  ('aihub.search', 'AI Search', 'Use AI search and retrieval', 'aihub'),
  ('aihub.rag', 'AI RAG', 'Manage RAG / knowledge / embeddings', 'aihub'),
  ('aihub.automation', 'AI Automation', 'Manage automation jobs and rules', 'aihub'),
  ('aihub.governance', 'AI Governance', 'Manage AI governance policies', 'aihub'),
  ('aihub.observability', 'AI Observability', 'View model monitoring and drift', 'aihub'),
  ('aihub.approvals', 'AI Approvals', 'Approve sensitive AI actions', 'aihub'),
  ('aihub.analytics', 'AI Analytics', 'View AI hub analytics', 'aihub'),
  ('aihub.admin', 'AI Hub Admin', 'Administer AI Intelligence Hub', 'aihub')
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  module = EXCLUDED.module,
  updated_at = now();

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE p.slug LIKE 'aihub.%'
  AND (
    r.slug IN ('super_admin', 'admin')
    OR (r.slug = 'finance' AND p.slug IN (
      'aihub.read', 'aihub.copilots', 'aihub.predictions', 'aihub.analytics'
    ))
    OR (r.slug = 'construction_manager' AND p.slug IN (
      'aihub.read', 'aihub.copilots', 'aihub.predictions'
    ))
    OR (r.slug = 'sales_team' AND p.slug IN (
      'aihub.read', 'aihub.copilots', 'aihub.recommendations', 'aihub.search'
    ))
    OR (r.slug = 'marketing' AND p.slug IN (
      'aihub.read', 'aihub.copilots', 'aihub.recommendations', 'aihub.search'
    ))
  )
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Enrich Volume 3 AI tables (ALTER ADD COLUMN IF NOT EXISTS only)
-- ---------------------------------------------------------------------------
ALTER TABLE public.ai_conversations
  ADD COLUMN IF NOT EXISTS copilot_slug text,
  ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS aihub_surface text;

ALTER TABLE public.ai_messages
  ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS model_slug text;

ALTER TABLE public.ai_sessions
  ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS copilot_slug text;

ALTER TABLE public.ai_prompt_templates
  ADD COLUMN IF NOT EXISTS copilot_slug text,
  ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS model_slug text;

ALTER TABLE public.ai_knowledge_sources
  ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS embedding_ready boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS source_uri text;

ALTER TABLE public.ai_feedback
  ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS rating_score int;

ALTER TABLE public.ai_usage_logs
  ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS copilot_slug text,
  ADD COLUMN IF NOT EXISTS model_slug text;

ALTER TABLE public.ai_recommendations
  ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS confidence_pct numeric(5,2),
  ADD COLUMN IF NOT EXISTS copilot_slug text,
  ADD COLUMN IF NOT EXISTS target_module text,
  ADD COLUMN IF NOT EXISTS code text;

ALTER TABLE public.ai_context_cache
  ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb;

ALTER TABLE public.ai_provider_settings
  ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS model_default text;

ALTER TABLE public.ai_rate_limits
  ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb;

ALTER TABLE public.ai_audit_logs
  ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS severity text;

-- ---------------------------------------------------------------------------
-- New EAIH tables
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ai_services (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  name text NOT NULL,
  service_type text NOT NULL DEFAULT 'inference'
    CHECK (service_type IN (
      'inference','embedding','rag','automation','copilot','search','other'
    )),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft','active','paused','retired')),
  owner_label text,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ai_models (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  service_id uuid REFERENCES public.ai_services(id) ON DELETE SET NULL,
  code text UNIQUE,
  name text NOT NULL,
  model_family text NOT NULL DEFAULT 'general'
    CHECK (model_family IN (
      'llm','forecast','classification','embedding','recommendation','other'
    )),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft','active','deprecated','retired')),
  provider_label text,
  owner_label text,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ai_model_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  model_id uuid NOT NULL REFERENCES public.ai_models(id) ON DELETE CASCADE,
  code text UNIQUE,
  version_label text NOT NULL,
  status text NOT NULL DEFAULT 'candidate'
    CHECK (status IN ('candidate','staging','production','retired')),
  accuracy_pct numeric(5,2),
  latency_ms int,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ai_training_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  model_id uuid REFERENCES public.ai_models(id) ON DELETE SET NULL,
  version_id uuid REFERENCES public.ai_model_versions(id) ON DELETE SET NULL,
  code text UNIQUE,
  name text NOT NULL,
  status text NOT NULL DEFAULT 'queued'
    CHECK (status IN ('queued','running','success','failed','cancelled')),
  started_at timestamptz,
  finished_at timestamptz,
  owner_label text,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ai_predictions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  model_id uuid REFERENCES public.ai_models(id) ON DELETE SET NULL,
  code text UNIQUE,
  title text NOT NULL,
  prediction_type text NOT NULL DEFAULT 'forecast'
    CHECK (prediction_type IN (
      'forecast','churn','conversion','risk','delay','score','other'
    )),
  predicted_value numeric(18,4),
  confidence_pct numeric(5,2),
  unit text NOT NULL DEFAULT 'count',
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','stale','archived')),
  target_module text,
  owner_label text,
  summary text,
  predicted_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ai_predictions_status
  ON public.ai_predictions(status);

CREATE TABLE IF NOT EXISTS public.ai_copilots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  department text NOT NULL DEFAULT 'general'
    CHECK (department IN (
      'executive','sales','support','construction','finance','hr','legal','general','other'
    )),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft','active','paused','retired')),
  model_id uuid REFERENCES public.ai_models(id) ON DELETE SET NULL,
  owner_label text,
  summary text,
  capabilities text[] NOT NULL DEFAULT '{}',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ai_prompt_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id uuid REFERENCES public.ai_prompt_templates(id) ON DELETE SET NULL,
  copilot_id uuid REFERENCES public.ai_copilots(id) ON DELETE SET NULL,
  code text UNIQUE,
  version_label text NOT NULL,
  body text NOT NULL,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','review','published','retired')),
  requires_approval boolean NOT NULL DEFAULT false,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Embeddings: Phase 1 stores jsonb; optional vector column if extension present
CREATE TABLE IF NOT EXISTS public.ai_embeddings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_table text,
  source_id text,
  knowledge_source_id uuid REFERENCES public.ai_knowledge_sources(id) ON DELETE SET NULL,
  code text UNIQUE,
  content_preview text,
  embedding jsonb NOT NULL DEFAULT '[]'::jsonb,
  embedding_dim int,
  status text NOT NULL DEFAULT 'ready'
    CHECK (status IN ('pending','ready','failed','stale')),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Optional pgvector extension + vector column (non-fatal if unavailable)
DO $$
BEGIN
  BEGIN
    CREATE EXTENSION IF NOT EXISTS vector;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'pgvector extension unavailable — continuing with jsonb embeddings only';
  END;

  IF EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'vector'
  ) THEN
    BEGIN
      ALTER TABLE public.ai_embeddings
        ADD COLUMN IF NOT EXISTS embedding_vector vector(1536);
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'Could not add embedding_vector column — jsonb path remains';
    END;
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.ai_vector_indexes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  name text NOT NULL,
  index_type text NOT NULL DEFAULT 'hnsw'
    CHECK (index_type IN ('hnsw','ivfflat','flat','jsonb_fallback','other')),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft','active','rebuilding','retired')),
  dimension int,
  owner_label text,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ai_search_queries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  query_text text NOT NULL,
  actor_label text,
  query_mode text NOT NULL DEFAULT 'hybrid'
    CHECK (query_mode IN ('keyword','semantic','hybrid','rag','other')),
  result_count int DEFAULT 0,
  latency_ms int,
  copilot_slug text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  queried_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ai_search_results (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  query_id uuid NOT NULL REFERENCES public.ai_search_queries(id) ON DELETE CASCADE,
  rank int NOT NULL DEFAULT 1,
  title text NOT NULL,
  snippet text,
  score numeric(8,4),
  source_label text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ai_knowledge_graph_nodes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  label text NOT NULL,
  node_type text NOT NULL DEFAULT 'entity'
    CHECK (node_type IN (
      'entity','person','property','project','document','process','other'
    )),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','archived')),
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ai_knowledge_graph_edges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  source_node_id uuid NOT NULL REFERENCES public.ai_knowledge_graph_nodes(id) ON DELETE CASCADE,
  target_node_id uuid NOT NULL REFERENCES public.ai_knowledge_graph_nodes(id) ON DELETE CASCADE,
  relation_type text NOT NULL DEFAULT 'related'
    CHECK (relation_type IN (
      'related','owns','depends','mentions','belongs_to','influences','other'
    )),
  weight numeric(8,4) DEFAULT 1,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ai_workflow_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  name text NOT NULL,
  trigger_event text NOT NULL,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft','active','paused','retired')),
  action_label text,
  requires_approval boolean NOT NULL DEFAULT true,
  owner_label text,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ai_automation_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_id uuid REFERENCES public.ai_workflow_rules(id) ON DELETE SET NULL,
  code text UNIQUE,
  name text NOT NULL,
  status text NOT NULL DEFAULT 'queued'
    CHECK (status IN ('queued','running','success','failed','cancelled','awaiting_approval')),
  started_at timestamptz,
  finished_at timestamptz,
  owner_label text,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ai_automation_jobs_status
  ON public.ai_automation_jobs(status);

CREATE TABLE IF NOT EXISTS public.ai_model_monitoring (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  model_id uuid REFERENCES public.ai_models(id) ON DELETE SET NULL,
  code text UNIQUE,
  metric_name text NOT NULL,
  metric_value numeric(18,4),
  status text NOT NULL DEFAULT 'ok'
    CHECK (status IN ('ok','watch','critical','unknown')),
  observed_at timestamptz NOT NULL DEFAULT now(),
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ai_drift_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  model_id uuid REFERENCES public.ai_models(id) ON DELETE SET NULL,
  code text UNIQUE,
  title text NOT NULL,
  severity text NOT NULL DEFAULT 'medium'
    CHECK (severity IN ('low','medium','high','critical')),
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','investigating','mitigated','closed')),
  drift_score numeric(8,4),
  owner_label text,
  summary text,
  detected_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ai_governance_policies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  title text NOT NULL,
  policy_area text NOT NULL DEFAULT 'responsible_ai'
    CHECK (policy_area IN (
      'responsible_ai','privacy','approvals','retention','fairness','security','other'
    )),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft','active','retired')),
  owner_label text,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ai_activity_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  action text NOT NULL,
  summary text NOT NULL,
  actor_label text,
  entity_type text,
  entity_id text,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ai_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  body text NOT NULL,
  severity text NOT NULL DEFAULT 'info'
    CHECK (severity IN ('info','warning','critical')),
  status text NOT NULL DEFAULT 'unread'
    CHECK (status IN ('unread','read','archived')),
  link_path text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ai_hub_insights (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  body text NOT NULL,
  insight_type text NOT NULL DEFAULT 'briefing'
    CHECK (insight_type IN (
      'briefing','decision','risk','ops','recommendation','other'
    )),
  confidence_pct numeric(5,2),
  editable boolean NOT NULL DEFAULT true,
  disclaimer text NOT NULL DEFAULT 'AI-generated — editable / advisory',
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','archived')),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Storage bucket
-- ---------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('ai-artifacts', 'ai-artifacts', false)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.ai_predictions; EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.ai_recommendations; EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.ai_automation_jobs; EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.ai_model_monitoring; EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.ai_activity_logs; EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.ai_notifications; EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.ai_conversations; EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

-- ---------------------------------------------------------------------------
