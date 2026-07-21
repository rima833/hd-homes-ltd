-- APPLIED remotely 2026-07-21 (chunked enterprise_ai_intelligence_hub_p1_schema / p2_seeds / p3_rls)
-- Volume 4 Part 17 -- Enterprise AI Intelligence Hub, Machine Learning
-- & Decision Support Platform (EAIH)
-- Status: APPLIED remotely 2026-07-21.
--
-- Approach:
--   • Route wires existing /dashboard/ai → AI Command Center.
--   • ENRICH only (never DROP/recreate) Volume 3 AI tables:
--     ai_conversations, ai_messages, ai_sessions, ai_prompt_templates,
--     ai_knowledge_sources, ai_feedback, ai_usage_logs, ai_recommendations,
--     ai_context_cache, ai_provider_settings, ai_rate_limits, ai_audit_logs.
--   • Do NOT recreate: ai_prompts (EOC), ai_executive_insights (Part 1),
--     module *_ai_insights tables, analytics_ai_conversations.
--   • CREATE NEW hub tables: ai_services, ai_models, ai_model_versions,
--     ai_training_jobs, ai_predictions, ai_copilots, ai_prompt_versions,
--     ai_embeddings, ai_vector_indexes, ai_search_queries, ai_search_results,
--     ai_knowledge_graph_nodes, ai_knowledge_graph_edges, ai_workflow_rules,
--     ai_automation_jobs, ai_model_monitoring, ai_drift_reports,
--     ai_governance_policies, ai_activity_logs, ai_notifications, ai_hub_insights.
--   • pgvector optional; embeddings always store jsonb (Phase 1 safe path).
--   • Seed UUIDs hex-only (f170…).
--   • Permissions: slug, name, description, module ONLY.
--   • RLS: has_permission('slug', auth.uid()) — slug FIRST.
--
-- Volume 4 continues Parts 18–25. Wait for approve before Part 18.
-- Part 16 BIADW SQL is APPLIED.

BEGIN;

-- ---------------------------------------------------------------------------
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
-- Seeds (hex-only UUIDs f170…)
-- ---------------------------------------------------------------------------
INSERT INTO public.ai_services (
  id, code, name, service_type, status, owner_label, summary
) VALUES
  (
    'f1700001-0000-4000-8000-000000000001',
    'SVC-INFER-01', 'Enterprise Inference Gateway', 'inference', 'active',
    'AI Platform', 'Primary inference gateway for copilots and predictions.'
  ),
  (
    'f1700001-0000-4000-8000-000000000002',
    'SVC-EMBED-01', 'Embedding & RAG Service', 'embedding', 'active',
    'AI Platform', 'Document and knowledge embeddings for hybrid search.'
  ),
  (
    'f1700001-0000-4000-8000-000000000003',
    'SVC-AUTO-01', 'Automation Orchestrator', 'automation', 'active',
    'Ops Automation', 'Rules-driven enterprise automation jobs.'
  ),
  (
    'f1700001-0000-4000-8000-000000000004',
    'SVC-COP-01', 'Copilot Runtime', 'copilot', 'active',
    'AI Platform', 'Department copilots runtime surface.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_models (
  id, service_id, code, name, model_family, status, provider_label, owner_label, summary
) VALUES
  (
    'f1700002-0000-4000-8000-000000000001',
    'f1700001-0000-4000-8000-000000000001',
    'MDL-LLM-EXEC', 'Executive Decision LLM', 'llm', 'active',
    'localFoundation', 'CEO Office', 'Executive briefing and decision support model.'
  ),
  (
    'f1700002-0000-4000-8000-000000000002',
    'f1700001-0000-4000-8000-000000000001',
    'MDL-FC-SALES', 'Sales Conversion Forecaster', 'forecast', 'active',
    'localFoundation', 'Sales Ops', 'Conversion and pipeline forecast model.'
  ),
  (
    'f1700002-0000-4000-8000-000000000003',
    'f1700001-0000-4000-8000-000000000002',
    'MDL-EMB-01', 'Knowledge Embedding v1', 'embedding', 'active',
    'localFoundation', 'AI Platform', 'Default embedding model for RAG.'
  ),
  (
    'f1700002-0000-4000-8000-000000000004',
    'f1700001-0000-4000-8000-000000000001',
    'MDL-REC-01', 'Next-Best-Action Recommender', 'recommendation', 'active',
    'localFoundation', 'CRM Lead', 'Cross-module recommendation ranker.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_model_versions (
  id, model_id, code, version_label, status, accuracy_pct, latency_ms, summary
) VALUES
  (
    'f1700003-0000-4000-8000-000000000001',
    'f1700002-0000-4000-8000-000000000001',
    'MDL-LLM-EXEC-v1', '1.0.0', 'production', 88.5, 420,
    'Production executive LLM stub.'
  ),
  (
    'f1700003-0000-4000-8000-000000000002',
    'f1700002-0000-4000-8000-000000000002',
    'MDL-FC-SALES-v2', '2.1.0', 'production', 81.2, 180,
    'Sales conversion forecaster production.'
  ),
  (
    'f1700003-0000-4000-8000-000000000003',
    'f1700002-0000-4000-8000-000000000002',
    'MDL-FC-SALES-v3', '3.0.0-rc', 'staging', 84.0, 195,
    'Candidate with improved feature set.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_training_jobs (
  id, model_id, version_id, code, name, status, owner_label, summary, started_at, finished_at
) VALUES
  (
    'f1700004-0000-4000-8000-000000000001',
    'f1700002-0000-4000-8000-000000000002',
    'f1700003-0000-4000-8000-000000000003',
    'TRN-FC-SALES-03', 'Retrain sales forecaster v3', 'success',
    'ML Ops', 'Weekly retrain on last 90 days bookings.',
    now() - interval '2 days', now() - interval '2 days' + interval '45 minutes'
  ),
  (
    'f1700004-0000-4000-8000-000000000002',
    'f1700002-0000-4000-8000-000000000004',
    NULL,
    'TRN-REC-01', 'Refresh recommender features', 'queued',
    'ML Ops', 'Queued feature refresh for next-best-action.',
    NULL, NULL
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_copilots (
  id, slug, name, department, status, model_id, owner_label, summary, capabilities
) VALUES
  (
    'f1700005-0000-4000-8000-000000000001',
    'executive', 'Executive Copilot', 'executive', 'active',
    'f1700002-0000-4000-8000-000000000001', 'CEO Office',
    'Board briefs, KPI narrative, decision packets.',
    ARRAY['briefing','decision','scorecard']
  ),
  (
    'f1700005-0000-4000-8000-000000000002',
    'sales', 'Sales Copilot', 'sales', 'active',
    'f1700002-0000-4000-8000-000000000002', 'Sales Ops',
    'Lead prioritization, follow-up drafts, conversion tips.',
    ARRAY['leads','followup','conversion']
  ),
  (
    'f1700005-0000-4000-8000-000000000003',
    'support', 'Support Copilot', 'support', 'active',
    'f1700002-0000-4000-8000-000000000001', 'CX Lead',
    'Ticket triage and response drafts with approval.',
    ARRAY['triage','draft','escalation']
  ),
  (
    'f1700005-0000-4000-8000-000000000004',
    'construction', 'Construction Copilot', 'construction', 'active',
    'f1700002-0000-4000-8000-000000000001', 'PMO',
    'Delay risk signals and milestone narratives.',
    ARRAY['delay','milestones','risk']
  ),
  (
    'f1700005-0000-4000-8000-000000000005',
    'finance', 'Finance Copilot', 'finance', 'active',
    'f1700002-0000-4000-8000-000000000001', 'CFO Office',
    'Collections watch and cash narrative stubs.',
    ARRAY['collections','cash','budget']
  ),
  (
    'f1700005-0000-4000-8000-000000000006',
    'hr', 'HR Copilot', 'hr', 'active',
    'f1700002-0000-4000-8000-000000000001', 'People Ops',
    'Policy Q&A and workforce insights (advisory).',
    ARRAY['policy','workforce']
  ),
  (
    'f1700005-0000-4000-8000-000000000007',
    'legal', 'Legal Copilot', 'legal', 'active',
    'f1700002-0000-4000-8000-000000000001', 'Legal Counsel',
    'Contract clause assist with mandatory human review.',
    ARRAY['contracts','disclaimer','review']
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_predictions (
  id, model_id, code, title, prediction_type, predicted_value, confidence_pct,
  unit, status, target_module, owner_label, summary, predicted_at
) VALUES
  (
    'f1700006-0000-4000-8000-000000000001',
    'f1700002-0000-4000-8000-000000000002',
    'PRED-CONV-30', 'Conversion next 30 days', 'conversion', 19.4, 82.0,
    'pct', 'active', 'sales', 'Sales Ops',
    'Enterprise prediction stub — conversion outlook.', now() - interval '3 hours'
  ),
  (
    'f1700006-0000-4000-8000-000000000002',
    'f1700002-0000-4000-8000-000000000001',
    'PRED-DELAY-HG', 'Horizon Gardens delay risk', 'delay', 0.34, 76.5,
    'ratio', 'active', 'construction', 'PMO',
    'Elevated delay probability on Block C.', now() - interval '1 day'
  ),
  (
    'f1700006-0000-4000-8000-000000000003',
    'f1700002-0000-4000-8000-000000000001',
    'PRED-CHURN-CRM', 'Warm lead churn risk (top 20)', 'churn', 11.0, 71.0,
    'count', 'active', 'crm', 'CRM Lead',
    'Eleven warm leads show churn risk signals.', now() - interval '6 hours'
  )
ON CONFLICT (id) DO NOTHING;

-- Enrich existing recommendations table with hub seeds (do not recreate table)
INSERT INTO public.ai_recommendations (
  id, user_id, kind, title, body, status, metadata, confidence_pct, copilot_slug, target_module, code
)
SELECT
  v.id,
  (SELECT id FROM public.profiles ORDER BY created_at NULLS LAST LIMIT 1),
  v.kind, v.title, v.body, v.status, v.metadata::jsonb,
  v.confidence_pct, v.copilot_slug, v.target_module, v.code
FROM (VALUES
  (
    'f1700007-0000-4000-8000-000000000001'::uuid,
    'next_best_action',
    'Call top warm leads today',
    'Prioritize 8 warm leads with >70% conversion assist score.',
    'pending_review',
    '{"source":"eaih"}',
    86.0::numeric,
    'sales',
    'sales',
    'REC-SALES-01'
  ),
  (
    'f1700007-0000-4000-8000-000000000002'::uuid,
    'executive_brief',
    'Escalate construction watch to board pack',
    'Include Block C delay risk in weekly executive packet.',
    'pending_review',
    '{"source":"eaih"}',
    79.5::numeric,
    'executive',
    'construction',
    'REC-EXEC-01'
  ),
  (
    'f1700007-0000-4000-8000-000000000003'::uuid,
    'collections',
    'Collections follow-up batch',
    'Queue advisory collections drafts for 5 overdue invoices.',
    'pending_review',
    '{"source":"eaih"}',
    74.0::numeric,
    'finance',
    'finance',
    'REC-FIN-01'
  )
) AS v(id, kind, title, body, status, metadata, confidence_pct, copilot_slug, target_module, code)
WHERE EXISTS (SELECT 1 FROM public.profiles LIMIT 1)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_prompt_versions (
  id, copilot_id, code, version_label, body, status, requires_approval, summary
) VALUES
  (
    'f1700008-0000-4000-8000-000000000001',
    'f1700005-0000-4000-8000-000000000001',
    'PV-EXEC-BRIEF-01', '1.0',
    'Draft an editable executive briefing from KPI and risk signals. Label advisory.',
    'published', false, 'Executive briefing prompt version.'
  ),
  (
    'f1700008-0000-4000-8000-000000000002',
    'f1700005-0000-4000-8000-000000000002',
    'PV-SALES-FOLLOW-01', '1.1',
    'Draft CRM follow-up requiring human review before send.',
    'published', true, 'Sales follow-up with approval gate.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_embeddings (
  id, source_table, source_id, code, content_preview, embedding, embedding_dim, status
) VALUES
  (
    'f1700009-0000-4000-8000-000000000001',
    'ai_knowledge_sources', NULL,
    'EMB-BUY-01', 'Buying process at HD Homes — journey summary.',
    '[0.12,0.04,-0.08,0.33]'::jsonb, 4, 'ready'
  ),
  (
    'f1700009-0000-4000-8000-000000000002',
    'ai_knowledge_sources', NULL,
    'EMB-INV-01', 'Investment products overview — illustrative ROI.',
    '[0.05,-0.11,0.22,0.18]'::jsonb, 4, 'ready'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_vector_indexes (
  id, code, name, index_type, status, dimension, owner_label, summary
) VALUES
  (
    'f170000a-0000-4000-8000-000000000001',
    'VIX-JSONB-01', 'Phase 1 JSONB Embedding Index', 'jsonb_fallback', 'active',
    4, 'AI Platform', 'Fallback index until pgvector is available.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_search_queries (
  id, code, query_text, actor_label, query_mode, result_count, latency_ms, copilot_slug, queried_at
) VALUES
  (
    'f170000b-0000-4000-8000-000000000001',
    'QRY-DELAY-01', 'construction delay risk horizon gardens',
    'PMO', 'hybrid', 3, 95, 'construction', now() - interval '2 hours'
  ),
  (
    'f170000b-0000-4000-8000-000000000002',
    'QRY-CONV-01', 'sales conversion next best actions',
    'Sales Ops', 'rag', 4, 120, 'sales', now() - interval '5 hours'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_search_results (
  id, query_id, rank, title, snippet, score, source_label
) VALUES
  (
    'f170000c-0000-4000-8000-000000000001',
    'f170000b-0000-4000-8000-000000000001',
    1, 'Block C delay signal', 'Elevated weather and supply risk on HG Block C.',
    0.91, 'PRED-DELAY-HG'
  ),
  (
    'f170000c-0000-4000-8000-000000000002',
    'f170000b-0000-4000-8000-000000000002',
    1, 'Warm lead follow-up batch', 'Eight warm leads ranked for today outreach.',
    0.88, 'REC-SALES-01'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_knowledge_graph_nodes (
  id, code, label, node_type, status, summary
) VALUES
  (
    'f170000d-0000-4000-8000-000000000001',
    'KG-EST-HG', 'Horizon Gardens', 'property', 'active',
    'Flagship estate entity in knowledge graph.'
  ),
  (
    'f170000d-0000-4000-8000-000000000002',
    'KG-PROC-BUY', 'Buying Process', 'process', 'active',
    'Discover → enquire → inspect → KYC → offer.'
  ),
  (
    'f170000d-0000-4000-8000-000000000003',
    'KG-DOC-SOP', 'Sales Follow-up SOP', 'document', 'active',
    'Playbook requiring human review of AI drafts.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_knowledge_graph_edges (
  id, code, source_node_id, target_node_id, relation_type, weight, summary
) VALUES
  (
    'f170000e-0000-4000-8000-000000000001',
    'KGE-BUY-HG',
    'f170000d-0000-4000-8000-000000000002',
    'f170000d-0000-4000-8000-000000000001',
    'related', 1.0, 'Buying process applies to Horizon Gardens.'
  ),
  (
    'f170000e-0000-4000-8000-000000000002',
    'KGE-SOP-BUY',
    'f170000d-0000-4000-8000-000000000003',
    'f170000d-0000-4000-8000-000000000002',
    'depends', 0.9, 'SOP governs buying-process follow-ups.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_workflow_rules (
  id, code, name, trigger_event, status, action_label, requires_approval, owner_label, summary
) VALUES
  (
    'f170000f-0000-4000-8000-000000000001',
    'RULE-DELAY-ALERT', 'Construction delay alert',
    'prediction.delay_high', 'active', 'Notify PMO + create draft brief',
    true, 'PMO', 'When delay probability > 0.3, open advisory brief.'
  ),
  (
    'f170000f-0000-4000-8000-000000000002',
    'RULE-LEAD-BATCH', 'Warm lead batch draft',
    'recommendation.sales_batch', 'active', 'Draft CRM follow-ups',
    true, 'Sales Ops', 'Batch next-best-action drafts require approval.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_automation_jobs (
  id, rule_id, code, name, status, owner_label, summary, started_at, finished_at
) VALUES
  (
    'f1700010-0000-4000-8000-000000000001',
    'f170000f-0000-4000-8000-000000000001',
    'AUTO-DELAY-01', 'Delay alert — Horizon Gardens',
    'awaiting_approval', 'PMO',
    'Draft alert ready for human approval.',
    now() - interval '4 hours', NULL
  ),
  (
    'f1700010-0000-4000-8000-000000000002',
    'f170000f-0000-4000-8000-000000000002',
    'AUTO-LEAD-01', 'Warm lead draft batch',
    'success', 'Sales Ops',
    'Eight draft follow-ups staged for review.',
    now() - interval '1 day', now() - interval '1 day' + interval '12 minutes'
  ),
  (
    'f1700010-0000-4000-8000-000000000003',
    NULL,
    'AUTO-DRIFT-01', 'Drift scan — sales forecaster',
    'failed', 'ML Ops',
    'Monitoring job failed on missing feature snapshot.',
    now() - interval '3 days', now() - interval '3 days' + interval '2 minutes'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_model_monitoring (
  id, model_id, code, metric_name, metric_value, status, observed_at, summary
) VALUES
  (
    'f1700011-0000-4000-8000-000000000001',
    'f1700002-0000-4000-8000-000000000002',
    'MON-FC-ACC', 'accuracy_pct', 81.2, 'ok',
    now() - interval '6 hours', 'Sales forecaster accuracy within band.'
  ),
  (
    'f1700011-0000-4000-8000-000000000002',
    'f1700002-0000-4000-8000-000000000002',
    'MON-FC-LAT', 'p95_latency_ms', 240, 'watch',
    now() - interval '2 hours', 'Latency watch — above 200ms target.'
  ),
  (
    'f1700011-0000-4000-8000-000000000003',
    'f1700002-0000-4000-8000-000000000001',
    'MON-LLM-ERR', 'error_rate_pct', 2.4, 'ok',
    now() - interval '1 hour', 'Executive LLM error rate healthy.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_drift_reports (
  id, model_id, code, title, severity, status, drift_score, owner_label, summary, detected_at
) VALUES
  (
    'f1700012-0000-4000-8000-000000000001',
    'f1700002-0000-4000-8000-000000000002',
    'DRIFT-FC-01', 'Feature drift — booking_stage',
    'high', 'open', 0.42, 'ML Ops',
    'Stage distribution shifted after schema change; linked to BI ETL watch.',
    now() - interval '2 days'
  ),
  (
    'f1700012-0000-4000-8000-000000000002',
    'f1700002-0000-4000-8000-000000000004',
    'DRIFT-REC-01', 'Label drift — next-best-action',
    'medium', 'investigating', 0.28, 'CRM Lead',
    'Recommendation acceptance rate down week-over-week.',
    now() - interval '5 days'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_governance_policies (
  id, code, title, policy_area, status, owner_label, summary
) VALUES
  (
    'f1700013-0000-4000-8000-000000000001',
    'POL-RAI-01', 'Responsible AI labeling',
    'responsible_ai', 'active', 'AI Governance',
    'All AI outputs must carry editable / advisory disclaimer.'
  ),
  (
    'f1700013-0000-4000-8000-000000000002',
    'POL-APPR-01', 'Human-in-the-loop approvals',
    'approvals', 'active', 'AI Governance',
    'CRM, legal, and outbound automation require human approval.'
  ),
  (
    'f1700013-0000-4000-8000-000000000003',
    'POL-PRIV-01', 'PII minimization in prompts',
    'privacy', 'active', 'Legal Counsel',
    'Do not embed full client PII in prompt logs.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_hub_insights (
  id, title, body, insight_type, confidence_pct, editable, disclaimer, status
) VALUES
  (
    'f1700014-0000-4000-8000-000000000001',
    'Executive decision packet focus',
    'Prioritize construction delay watch and conversion mart recovery in this week''s decision pack.',
    'decision', 84.0, true, 'AI-generated — editable / advisory', 'active'
  ),
  (
    'f1700014-0000-4000-8000-000000000002',
    'Automation awaiting approval',
    'AUTO-DELAY-01 holds on approval — PMO should clear or amend before notify blast.',
    'ops', 91.0, true, 'AI-generated — editable / advisory', 'active'
  ),
  (
    'f1700014-0000-4000-8000-000000000003',
    'Model drift linked to BI quality',
    'DRIFT-FC-01 correlates with analytics ETL schema drift — treat forecasts as advisory.',
    'risk', 88.5, true, 'AI-generated — editable / advisory', 'active'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_activity_logs (
  id, action, summary, actor_label, entity_type, entity_id, occurred_at
) VALUES
  (
    'f1700015-0000-4000-8000-000000000001',
    'prediction_created',
    'PRED-CONV-30 conversion outlook published',
    'Sales Ops', 'ai_predictions', 'f1700006-0000-4000-8000-000000000001',
    now() - interval '3 hours'
  ),
  (
    'f1700015-0000-4000-8000-000000000002',
    'automation_awaiting_approval',
    'AUTO-DELAY-01 awaiting PMO approval',
    'Automation', 'ai_automation_jobs', 'f1700010-0000-4000-8000-000000000001',
    now() - interval '4 hours'
  ),
  (
    'f1700015-0000-4000-8000-000000000003',
    'drift_opened',
    'DRIFT-FC-01 opened as high severity',
    'ML Ops', 'ai_drift_reports', 'f1700012-0000-4000-8000-000000000001',
    now() - interval '2 days'
  ),
  (
    'f1700015-0000-4000-8000-000000000004',
    'copilot_activated',
    'Executive Copilot marked active in AI Hub',
    'AI Platform', 'ai_copilots', 'f1700005-0000-4000-8000-000000000001',
    now() - interval '7 days'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_notifications (
  id, title, body, severity, status, link_path
) VALUES
  (
    'f1700016-0000-4000-8000-000000000001',
    'Automation awaiting approval',
    'AUTO-DELAY-01 needs PMO review.',
    'warning', 'unread', '/dashboard/ai'
  ),
  (
    'f1700016-0000-4000-8000-000000000002',
    'High drift on sales forecaster',
    'DRIFT-FC-01 opened — treat conversion predictions as advisory.',
    'critical', 'unread', '/dashboard/ai'
  )
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.ai_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_models ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_model_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_training_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_predictions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_copilots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_prompt_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_embeddings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_vector_indexes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_search_queries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_search_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_knowledge_graph_nodes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_knowledge_graph_edges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_workflow_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_automation_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_model_monitoring ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_drift_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_governance_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_hub_insights ENABLE ROW LEVEL SECURITY;

-- Helper: slug FIRST in has_permission

DROP POLICY IF EXISTS ai_services_select ON public.ai_services;
DROP POLICY IF EXISTS ai_services_write ON public.ai_services;
CREATE POLICY ai_services_select ON public.ai_services FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_services_write ON public.ai_services FOR ALL
  USING (public.has_permission('aihub.write', auth.uid()) OR public.has_permission('aihub.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.write', auth.uid()) OR public.has_permission('aihub.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_models_select ON public.ai_models;
DROP POLICY IF EXISTS ai_models_write ON public.ai_models;
CREATE POLICY ai_models_select ON public.ai_models FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.models', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_models_write ON public.ai_models FOR ALL
  USING (public.has_permission('aihub.models', auth.uid()) OR public.has_permission('aihub.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.models', auth.uid()) OR public.has_permission('aihub.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_model_versions_select ON public.ai_model_versions;
DROP POLICY IF EXISTS ai_model_versions_write ON public.ai_model_versions;
CREATE POLICY ai_model_versions_select ON public.ai_model_versions FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.models', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_model_versions_write ON public.ai_model_versions FOR ALL
  USING (public.has_permission('aihub.models', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.models', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_training_jobs_select ON public.ai_training_jobs;
DROP POLICY IF EXISTS ai_training_jobs_write ON public.ai_training_jobs;
CREATE POLICY ai_training_jobs_select ON public.ai_training_jobs FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.models', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_training_jobs_write ON public.ai_training_jobs FOR ALL
  USING (public.has_permission('aihub.models', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.models', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_predictions_select ON public.ai_predictions;
DROP POLICY IF EXISTS ai_predictions_write ON public.ai_predictions;
CREATE POLICY ai_predictions_select ON public.ai_predictions FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.predictions', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_predictions_write ON public.ai_predictions FOR ALL
  USING (public.has_permission('aihub.predictions', auth.uid()) OR public.has_permission('aihub.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.predictions', auth.uid()) OR public.has_permission('aihub.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_copilots_select ON public.ai_copilots;
DROP POLICY IF EXISTS ai_copilots_write ON public.ai_copilots;
CREATE POLICY ai_copilots_select ON public.ai_copilots FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.copilots', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_copilots_write ON public.ai_copilots FOR ALL
  USING (public.has_permission('aihub.copilots', auth.uid()) OR public.has_permission('aihub.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.copilots', auth.uid()) OR public.has_permission('aihub.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_prompt_versions_select ON public.ai_prompt_versions;
DROP POLICY IF EXISTS ai_prompt_versions_write ON public.ai_prompt_versions;
CREATE POLICY ai_prompt_versions_select ON public.ai_prompt_versions FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.copilots', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_prompt_versions_write ON public.ai_prompt_versions FOR ALL
  USING (public.has_permission('aihub.copilots', auth.uid()) OR public.has_permission('aihub.approvals', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.copilots', auth.uid()) OR public.has_permission('aihub.approvals', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_embeddings_select ON public.ai_embeddings;
DROP POLICY IF EXISTS ai_embeddings_write ON public.ai_embeddings;
CREATE POLICY ai_embeddings_select ON public.ai_embeddings FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.rag', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_embeddings_write ON public.ai_embeddings FOR ALL
  USING (public.has_permission('aihub.rag', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.rag', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_vector_indexes_select ON public.ai_vector_indexes;
DROP POLICY IF EXISTS ai_vector_indexes_write ON public.ai_vector_indexes;
CREATE POLICY ai_vector_indexes_select ON public.ai_vector_indexes FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.rag', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_vector_indexes_write ON public.ai_vector_indexes FOR ALL
  USING (public.has_permission('aihub.rag', auth.uid()) OR public.has_permission('aihub.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.rag', auth.uid()) OR public.has_permission('aihub.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_search_queries_select ON public.ai_search_queries;
DROP POLICY IF EXISTS ai_search_queries_write ON public.ai_search_queries;
CREATE POLICY ai_search_queries_select ON public.ai_search_queries FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.search', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_search_queries_write ON public.ai_search_queries FOR ALL
  USING (public.has_permission('aihub.search', auth.uid()) OR public.has_permission('aihub.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.search', auth.uid()) OR public.has_permission('aihub.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_search_results_select ON public.ai_search_results;
DROP POLICY IF EXISTS ai_search_results_write ON public.ai_search_results;
CREATE POLICY ai_search_results_select ON public.ai_search_results FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.search', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_search_results_write ON public.ai_search_results FOR ALL
  USING (public.has_permission('aihub.search', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.search', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_knowledge_graph_nodes_select ON public.ai_knowledge_graph_nodes;
DROP POLICY IF EXISTS ai_knowledge_graph_nodes_write ON public.ai_knowledge_graph_nodes;
CREATE POLICY ai_knowledge_graph_nodes_select ON public.ai_knowledge_graph_nodes FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.rag', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_knowledge_graph_nodes_write ON public.ai_knowledge_graph_nodes FOR ALL
  USING (public.has_permission('aihub.rag', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.rag', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_knowledge_graph_edges_select ON public.ai_knowledge_graph_edges;
DROP POLICY IF EXISTS ai_knowledge_graph_edges_write ON public.ai_knowledge_graph_edges;
CREATE POLICY ai_knowledge_graph_edges_select ON public.ai_knowledge_graph_edges FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.rag', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_knowledge_graph_edges_write ON public.ai_knowledge_graph_edges FOR ALL
  USING (public.has_permission('aihub.rag', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.rag', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_workflow_rules_select ON public.ai_workflow_rules;
DROP POLICY IF EXISTS ai_workflow_rules_write ON public.ai_workflow_rules;
CREATE POLICY ai_workflow_rules_select ON public.ai_workflow_rules FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.automation', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_workflow_rules_write ON public.ai_workflow_rules FOR ALL
  USING (public.has_permission('aihub.automation', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.automation', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_automation_jobs_select ON public.ai_automation_jobs;
DROP POLICY IF EXISTS ai_automation_jobs_write ON public.ai_automation_jobs;
CREATE POLICY ai_automation_jobs_select ON public.ai_automation_jobs FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.automation', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_automation_jobs_write ON public.ai_automation_jobs FOR ALL
  USING (public.has_permission('aihub.automation', auth.uid()) OR public.has_permission('aihub.approvals', auth.uid()) OR public.has_permission('aihub.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.automation', auth.uid()) OR public.has_permission('aihub.approvals', auth.uid()) OR public.has_permission('aihub.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_model_monitoring_select ON public.ai_model_monitoring;
DROP POLICY IF EXISTS ai_model_monitoring_write ON public.ai_model_monitoring;
CREATE POLICY ai_model_monitoring_select ON public.ai_model_monitoring FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.observability', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_model_monitoring_write ON public.ai_model_monitoring FOR ALL
  USING (public.has_permission('aihub.observability', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.observability', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_drift_reports_select ON public.ai_drift_reports;
DROP POLICY IF EXISTS ai_drift_reports_write ON public.ai_drift_reports;
CREATE POLICY ai_drift_reports_select ON public.ai_drift_reports FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.observability', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_drift_reports_write ON public.ai_drift_reports FOR ALL
  USING (public.has_permission('aihub.observability', auth.uid()) OR public.has_permission('aihub.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.observability', auth.uid()) OR public.has_permission('aihub.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_governance_policies_select ON public.ai_governance_policies;
DROP POLICY IF EXISTS ai_governance_policies_write ON public.ai_governance_policies;
CREATE POLICY ai_governance_policies_select ON public.ai_governance_policies FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.governance', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_governance_policies_write ON public.ai_governance_policies FOR ALL
  USING (public.has_permission('aihub.governance', auth.uid()) OR public.has_permission('aihub.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.governance', auth.uid()) OR public.has_permission('aihub.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_activity_logs_select ON public.ai_activity_logs;
DROP POLICY IF EXISTS ai_activity_logs_write ON public.ai_activity_logs;
CREATE POLICY ai_activity_logs_select ON public.ai_activity_logs FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.observability', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_activity_logs_write ON public.ai_activity_logs FOR ALL
  USING (public.has_permission('aihub.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_notifications_select ON public.ai_notifications;
DROP POLICY IF EXISTS ai_notifications_write ON public.ai_notifications;
CREATE POLICY ai_notifications_select ON public.ai_notifications FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_notifications_write ON public.ai_notifications FOR ALL
  USING (public.has_permission('aihub.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_hub_insights_select ON public.ai_hub_insights;
DROP POLICY IF EXISTS ai_hub_insights_write ON public.ai_hub_insights;
CREATE POLICY ai_hub_insights_select ON public.ai_hub_insights FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.analytics', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_hub_insights_write ON public.ai_hub_insights FOR ALL
  USING (public.has_permission('aihub.write', auth.uid()) OR public.has_permission('aihub.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.write', auth.uid()) OR public.has_permission('aihub.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

COMMIT;
