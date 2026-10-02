-- APPLIED remotely (2026-07-21) via MCP chunks: edp_p1_schema, edp_p2_rls, edp_p3_seeds
-- Volume 4 Part 20 — Enterprise DevOps, Platform Engineering, Infrastructure,
-- Observability & Release Management Platform (EDP)
-- ENRICHES feature_flags / configuration_settings in place. Never recreates them.
-- Does NOT create analytics_pipeline_logs or bare change_requests.
-- Permissions use (slug, name, description, module); has_permission slug is FIRST.
-- Seed UUIDs are hex-only c200….

BEGIN;

INSERT INTO public.permissions (slug, name, description, module) VALUES
 ('platform.read','View Platform','View DevOps Command Center','platform'),
 ('platform.write','Manage Platform','Create and update platform operations records','platform'),
 ('platform.environments','Environments','Manage deployment environments','platform'),
 ('platform.pipelines','Pipelines','Manage deployment pipelines and runs','platform'),
 ('platform.deployments','Deployments','Manage deployments and artifacts','platform'),
 ('platform.releases','Releases','Manage releases, notes, and approvals','platform'),
 ('platform.changes','Change Management','Manage platform change requests and reviews','platform'),
 ('platform.infrastructure','Infrastructure','Manage infrastructure resources and versions','platform'),
 ('platform.observability','Observability','View metrics, logs, and performance','platform'),
 ('platform.flags','Feature Flags','Manage feature flag rules and config profiles','platform'),
 ('platform.incidents','Incident Operations','Manage operational incidents and runbooks','platform'),
 ('platform.ai','Platform AI','View platform AI insights','platform'),
 ('platform.analytics','Platform Analytics','View platform analytics and capacity','platform'),
 ('platform.admin','Platform Administration','Administer the Enterprise DevOps Platform','platform')
ON CONFLICT (slug) DO UPDATE SET
 name=EXCLUDED.name, description=EXCLUDED.description, module=EXCLUDED.module, updated_at=now();

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM public.roles r CROSS JOIN public.permissions p
WHERE p.slug LIKE 'platform.%' AND (
 r.slug IN ('super_admin','admin')
 OR (r.slug='finance' AND p.slug IN ('platform.read','platform.analytics','platform.releases'))
 OR (r.slug='construction_manager' AND p.slug IN ('platform.read','platform.observability'))
 OR (r.slug='sales_team' AND p.slug='platform.read')
 OR (r.slug='marketing' AND p.slug IN ('platform.read','platform.flags'))
) ON CONFLICT DO NOTHING;

-- Environments first (configuration_settings may reference them).
CREATE TABLE IF NOT EXISTS public.environments (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, name text NOT NULL,
 slug text NOT NULL UNIQUE, env_type text NOT NULL DEFAULT 'development',
 status text NOT NULL DEFAULT 'active', region text, owner_label text, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

-- EIP collision tables: enrich only — never DROP/recreate.
ALTER TABLE public.feature_flags
 ADD COLUMN IF NOT EXISTS platform_surface text,
 ADD COLUMN IF NOT EXISTS owner_label text,
 ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb;
ALTER TABLE public.configuration_settings
 ADD COLUMN IF NOT EXISTS environment_id uuid REFERENCES public.environments(id) ON DELETE SET NULL,
 ADD COLUMN IF NOT EXISTS version int DEFAULT 1,
 ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb;

CREATE TABLE IF NOT EXISTS public.deployment_pipelines (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, name text NOT NULL,
 category text NOT NULL DEFAULT 'ci_cd', status text NOT NULL DEFAULT 'active',
 trigger_type text NOT NULL DEFAULT 'manual', repository_ref text, owner_label text,
 summary text, config jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.pipeline_runs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), pipeline_id uuid NOT NULL REFERENCES public.deployment_pipelines(id) ON DELETE CASCADE,
 code text UNIQUE, title text NOT NULL, category text NOT NULL DEFAULT 'pipeline',
 status text NOT NULL DEFAULT 'queued', environment_id uuid REFERENCES public.environments(id) ON DELETE SET NULL,
 triggered_by text, started_at timestamptz, completed_at timestamptz, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.pipeline_stages (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), run_id uuid NOT NULL REFERENCES public.pipeline_runs(id) ON DELETE CASCADE,
 name text NOT NULL, stage_order int NOT NULL DEFAULT 1, status text NOT NULL DEFAULT 'pending',
 started_at timestamptz, completed_at timestamptz, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.deployments (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'deployment', status text NOT NULL DEFAULT 'pending',
 environment_id uuid REFERENCES public.environments(id) ON DELETE SET NULL,
 pipeline_run_id uuid REFERENCES public.pipeline_runs(id) ON DELETE SET NULL,
 version_label text, deployed_at timestamptz, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.deployment_artifacts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), deployment_id uuid NOT NULL REFERENCES public.deployments(id) ON DELETE CASCADE,
 name text NOT NULL, artifact_type text NOT NULL DEFAULT 'build', storage_path text,
 checksum text, size_bytes bigint, status text NOT NULL DEFAULT 'ready', summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.releases (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 version_label text NOT NULL, category text NOT NULL DEFAULT 'release',
 status text NOT NULL DEFAULT 'draft', environment_id uuid REFERENCES public.environments(id) ON DELETE SET NULL,
 target_date date, summary text, metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.release_notes (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), release_id uuid NOT NULL REFERENCES public.releases(id) ON DELETE CASCADE,
 title text NOT NULL, note_type text NOT NULL DEFAULT 'feature', body text,
 status text NOT NULL DEFAULT 'published', metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.release_approvals (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), release_id uuid NOT NULL REFERENCES public.releases(id) ON DELETE CASCADE,
 title text NOT NULL, approver_label text, status text NOT NULL DEFAULT 'pending',
 decided_at timestamptz, summary text, metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.platform_change_requests (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'change', change_type text NOT NULL DEFAULT 'standard',
 severity text NOT NULL DEFAULT 'medium', status text NOT NULL DEFAULT 'open',
 environment_id uuid REFERENCES public.environments(id) ON DELETE SET NULL,
 requester_label text, summary text, planned_at timestamptz,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.platform_change_reviews (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), change_request_id uuid NOT NULL REFERENCES public.platform_change_requests(id) ON DELETE CASCADE,
 title text NOT NULL, reviewer_label text, status text NOT NULL DEFAULT 'pending',
 decided_at timestamptz, summary text, metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.infrastructure_resources (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, name text NOT NULL,
 resource_type text NOT NULL, category text NOT NULL DEFAULT 'infrastructure',
 status text NOT NULL DEFAULT 'healthy', environment_id uuid REFERENCES public.environments(id) ON DELETE SET NULL,
 region text, owner_label text, summary text, metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.infrastructure_versions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), resource_id uuid NOT NULL REFERENCES public.infrastructure_resources(id) ON DELETE CASCADE,
 version_label text NOT NULL, status text NOT NULL DEFAULT 'active', summary text,
 applied_at timestamptz, metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.configuration_profiles (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, name text NOT NULL,
 environment_id uuid REFERENCES public.environments(id) ON DELETE SET NULL,
 status text NOT NULL DEFAULT 'active', owner_label text, summary text,
 profile_data jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.feature_flag_rules (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), flag_id uuid REFERENCES public.feature_flags(id) ON DELETE CASCADE,
 code text UNIQUE, name text NOT NULL, rule_type text NOT NULL DEFAULT 'percentage',
 environment_id uuid REFERENCES public.environments(id) ON DELETE SET NULL,
 status text NOT NULL DEFAULT 'active', rollout_pct numeric(5,2) DEFAULT 0,
 summary text, rule_config jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.observability_metrics (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 metric_key text NOT NULL, category text NOT NULL DEFAULT 'observability',
 status text NOT NULL DEFAULT 'ok', value numeric, unit text DEFAULT 'count',
 environment_id uuid REFERENCES public.environments(id) ON DELETE SET NULL,
 summary text, series jsonb NOT NULL DEFAULT '[]'::jsonb, recorded_at timestamptz NOT NULL DEFAULT now(),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.application_logs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), title text NOT NULL, category text NOT NULL DEFAULT 'application',
 severity text NOT NULL DEFAULT 'info', status text NOT NULL DEFAULT 'recorded',
 service_name text, environment_id uuid REFERENCES public.environments(id) ON DELETE SET NULL,
 summary text, metadata jsonb NOT NULL DEFAULT '{}'::jsonb, occurred_at timestamptz NOT NULL DEFAULT now(),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.platform_logs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), title text NOT NULL, category text NOT NULL DEFAULT 'platform',
 severity text NOT NULL DEFAULT 'info', status text NOT NULL DEFAULT 'recorded',
 component text, environment_id uuid REFERENCES public.environments(id) ON DELETE SET NULL,
 summary text, metadata jsonb NOT NULL DEFAULT '{}'::jsonb, occurred_at timestamptz NOT NULL DEFAULT now(),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.performance_metrics (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'performance', metric_key text NOT NULL,
 status text NOT NULL DEFAULT 'ok', value numeric, unit text DEFAULT 'ms',
 environment_id uuid REFERENCES public.environments(id) ON DELETE SET NULL,
 summary text, recorded_at timestamptz NOT NULL DEFAULT now(),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.incident_operations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'incident', severity text NOT NULL DEFAULT 'medium',
 status text NOT NULL DEFAULT 'open', environment_id uuid REFERENCES public.environments(id) ON DELETE SET NULL,
 commander_label text, summary text, opened_at timestamptz NOT NULL DEFAULT now(), resolved_at timestamptz,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.operational_runbooks (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'runbook', status text NOT NULL DEFAULT 'active',
 owner_label text, summary text, steps jsonb NOT NULL DEFAULT '[]'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.service_health (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 service_name text NOT NULL, category text NOT NULL DEFAULT 'health',
 status text NOT NULL DEFAULT 'healthy', environment_id uuid REFERENCES public.environments(id) ON DELETE SET NULL,
 latency_ms numeric, error_rate_pct numeric(5,2), summary text,
 checked_at timestamptz NOT NULL DEFAULT now(),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.service_level_objectives (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 service_name text NOT NULL, category text NOT NULL DEFAULT 'slo',
 status text NOT NULL DEFAULT 'active', target_pct numeric(5,2) NOT NULL DEFAULT 99.9,
 current_pct numeric(5,2), window_days int NOT NULL DEFAULT 30, summary text,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.service_level_indicators (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), slo_id uuid NOT NULL REFERENCES public.service_level_objectives(id) ON DELETE CASCADE,
 title text NOT NULL, indicator_key text NOT NULL, status text NOT NULL DEFAULT 'ok',
 value numeric, unit text DEFAULT 'pct', recorded_at timestamptz NOT NULL DEFAULT now(),
 summary text, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.capacity_forecasts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'capacity', resource_type text NOT NULL,
 status text NOT NULL DEFAULT 'ok', forecast_pct numeric(5,2), horizon_days int DEFAULT 30,
 summary text, metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.platform_activity_logs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), action text NOT NULL, title text NOT NULL,
 category text NOT NULL DEFAULT 'platform', actor_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
 actor_label text, entity_type text, entity_id uuid, severity text NOT NULL DEFAULT 'info',
 status text NOT NULL DEFAULT 'recorded', summary text, metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 occurred_at timestamptz NOT NULL DEFAULT now(),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.platform_notifications (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), recipient_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
 title text NOT NULL, category text NOT NULL DEFAULT 'platform', channel text NOT NULL DEFAULT 'in_app',
 severity text NOT NULL DEFAULT 'info', status text NOT NULL DEFAULT 'unread', body text,
 read_at timestamptz, metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.platform_ai_insights (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 body text NOT NULL, category text NOT NULL DEFAULT 'platform', insight_type text NOT NULL,
 confidence_pct numeric(5,2), status text NOT NULL DEFAULT 'active', editable boolean NOT NULL DEFAULT true,
 disclaimer text NOT NULL DEFAULT 'AI-generated — editable / advisory',
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pipeline_runs_status ON public.pipeline_runs(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_deployments_status ON public.deployments(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_releases_status ON public.releases(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_platform_change_requests_status ON public.platform_change_requests(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_service_health_status ON public.service_health(status, checked_at DESC);
CREATE INDEX IF NOT EXISTS idx_incident_operations_status ON public.incident_operations(status, severity, opened_at DESC);

INSERT INTO storage.buckets (id,name,public) VALUES ('platform-artifacts','platform-artifacts',false)
ON CONFLICT (id) DO NOTHING;

DO $$ BEGIN
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.pipeline_runs; EXCEPTION WHEN duplicate_object THEN NULL; END;
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.deployments; EXCEPTION WHEN duplicate_object THEN NULL; END;
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.releases; EXCEPTION WHEN duplicate_object THEN NULL; END;
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.service_health; EXCEPTION WHEN duplicate_object THEN NULL; END;
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.platform_activity_logs; EXCEPTION WHEN duplicate_object THEN NULL; END;
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.platform_notifications; EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

DO $$
DECLARE t text;
BEGIN
 FOREACH t IN ARRAY ARRAY[
  'environments','deployment_pipelines','pipeline_runs','pipeline_stages',
  'deployments','deployment_artifacts','releases','release_notes','release_approvals',
  'platform_change_requests','platform_change_reviews',
  'infrastructure_resources','infrastructure_versions','configuration_profiles','feature_flag_rules',
  'observability_metrics','application_logs','platform_logs','performance_metrics',
  'incident_operations','operational_runbooks','service_health',
  'service_level_objectives','service_level_indicators','capacity_forecasts',
  'platform_activity_logs','platform_notifications','platform_ai_insights'
 ] LOOP
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
  EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_select', t);
  EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_write', t);
  EXECUTE format(
   'CREATE POLICY %I ON public.%I FOR SELECT USING (public.has_permission(''platform.read'', auth.uid()) OR public.has_permission(''platform.admin'', auth.uid()) OR public.has_role(''super_admin'', auth.uid()))',
   t || '_select', t
  );
  EXECUTE format(
   'CREATE POLICY %I ON public.%I FOR ALL USING (public.has_permission(''platform.write'', auth.uid()) OR public.has_permission(''platform.admin'', auth.uid()) OR public.has_role(''super_admin'', auth.uid())) WITH CHECK (public.has_permission(''platform.write'', auth.uid()) OR public.has_permission(''platform.admin'', auth.uid()) OR public.has_role(''super_admin'', auth.uid()))',
   t || '_write', t
  );
 END LOOP;
END $$;

GRANT SELECT, INSERT, UPDATE, DELETE ON
 public.environments, public.deployment_pipelines, public.pipeline_runs, public.pipeline_stages,
 public.deployments, public.deployment_artifacts, public.releases, public.release_notes, public.release_approvals,
 public.platform_change_requests, public.platform_change_reviews,
 public.infrastructure_resources, public.infrastructure_versions, public.configuration_profiles, public.feature_flag_rules,
 public.observability_metrics, public.application_logs, public.platform_logs, public.performance_metrics,
 public.incident_operations, public.operational_runbooks, public.service_health,
 public.service_level_objectives, public.service_level_indicators, public.capacity_forecasts,
 public.platform_activity_logs, public.platform_notifications, public.platform_ai_insights
TO authenticated;

-- Phase 1 demo seeds (hex-only c200…).
INSERT INTO public.environments (id,code,name,slug,env_type,status,region,owner_label,summary) VALUES
 ('c2000001-0000-4000-8000-000000000001','ENV-DEV','Development','dev','development','active','eu-west-1','Platform Engineering','Local and shared development'),
 ('c2000001-0000-4000-8000-000000000002','ENV-STG','Staging','staging','staging','active','eu-west-1','Platform Engineering','Pre-production validation'),
 ('c2000001-0000-4000-8000-000000000003','ENV-PRD','Production','prod','production','active','eu-west-1','Platform Engineering','Customer-facing production')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.deployment_pipelines (id,code,name,category,status,trigger_type,repository_ref,owner_label,summary) VALUES
 ('c2000002-0000-4000-8000-000000000001','PIPE-APP-MAIN','HD Homes app mainline','ci_cd','active','push','github.com/hdhomes/app','Platform Engineering','Build, test, and deploy Flutter + Supabase')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.pipeline_runs (id,pipeline_id,code,title,status,environment_id,triggered_by,started_at,summary) VALUES
 ('c2000003-0000-4000-8000-000000000001','c2000002-0000-4000-8000-000000000001','RUN-2026-0721','Mainline staging deploy','running','c2000001-0000-4000-8000-000000000002','ci-bot',now()-interval '12 minutes','Stages: build → test → deploy')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.pipeline_stages (id,run_id,name,stage_order,status,started_at,summary) VALUES
 ('c2000003-0000-4000-8000-000000000002','c2000003-0000-4000-8000-000000000001','build',1,'succeeded',now()-interval '12 minutes','Artifacts published'),
 ('c2000003-0000-4000-8000-000000000003','c2000003-0000-4000-8000-000000000001','test',2,'succeeded',now()-interval '8 minutes','Unit and widget tests passed'),
 ('c2000003-0000-4000-8000-000000000004','c2000003-0000-4000-8000-000000000001','deploy',3,'running',now()-interval '3 minutes','Deploying to staging')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.deployments (id,code,title,status,environment_id,pipeline_run_id,version_label,deployed_at,summary) VALUES
 ('c2000004-0000-4000-8000-000000000001','DEP-STG-0721','Staging web + API deploy','in_progress','c2000001-0000-4000-8000-000000000002','c2000003-0000-4000-8000-000000000001','2026.07.21-rc1',now()-interval '3 minutes','Rolling deploy to staging')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.deployment_artifacts (id,deployment_id,name,artifact_type,storage_path,checksum,status,summary) VALUES
 ('c2000004-0000-4000-8000-000000000002','c2000004-0000-4000-8000-000000000001','web-bundle','build','platform-artifacts/2026.07.21-rc1/web.zip','sha256:demo-artifact','ready','Flutter web release bundle')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.releases (id,code,title,version_label,status,environment_id,target_date,summary) VALUES
 ('c2000005-0000-4000-8000-000000000001','REL-2026-07','July platform release','2026.07.21','awaiting_approval','c2000001-0000-4000-8000-000000000003',current_date + 2,'Production cutover pending CAB approval')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.release_notes (id,release_id,title,note_type,body,status) VALUES
 ('c2000005-0000-4000-8000-000000000002','c2000005-0000-4000-8000-000000000001','DevOps Command Center','feature','Enterprise DevOps Platform Phase 1 surfaces','published')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.release_approvals (id,release_id,title,approver_label,status,summary) VALUES
 ('c2000005-0000-4000-8000-000000000003','c2000005-0000-4000-8000-000000000001','CAB production approval','Release Manager','pending','Awaiting change advisory board')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.platform_change_requests (id,code,title,category,change_type,severity,status,environment_id,requester_label,summary,planned_at) VALUES
 ('c2000006-0000-4000-8000-000000000001','CHG-2026-041','Enable staging feature flag for investor portal','change','standard','medium','open','c2000001-0000-4000-8000-000000000002','Platform Engineering','Toggle investor portal beta on staging',now()+interval '1 day')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.platform_change_reviews (id,change_request_id,title,reviewer_label,status,summary) VALUES
 ('c2000006-0000-4000-8000-000000000002','c2000006-0000-4000-8000-000000000001','Peer review','SRE Lead','pending','Validate rollback plan')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.infrastructure_resources (id,code,name,resource_type,status,environment_id,region,owner_label,summary) VALUES
 ('c2000007-0000-4000-8000-000000000001','INF-DB-PRD','Production Postgres','database','healthy','c2000001-0000-4000-8000-000000000003','eu-west-1','Platform Engineering','Primary Supabase Postgres cluster')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.infrastructure_versions (id,resource_id,version_label,status,summary,applied_at) VALUES
 ('c2000007-0000-4000-8000-000000000002','c2000007-0000-4000-8000-000000000001','pg-15.6','active','Managed Postgres 15.6',now()-interval '30 days')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.service_level_objectives (id,code,title,service_name,status,target_pct,current_pct,window_days,summary) VALUES
 ('c2000008-0000-4000-8000-000000000001','SLO-API-AVAIL','API availability','api-gateway','active',99.90,99.95,30,'Availability objective for public API gateway')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.service_level_indicators (id,slo_id,title,indicator_key,status,value,unit,summary) VALUES
 ('c2000008-0000-4000-8000-000000000002','c2000008-0000-4000-8000-000000000001','30-day availability','availability_pct','ok',99.95,'pct','Within error budget')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.service_health (id,code,title,service_name,status,environment_id,latency_ms,error_rate_pct,summary) VALUES
 ('c2000009-0000-4000-8000-000000000001','HLTH-API-PRD','API gateway health','api-gateway','healthy','c2000001-0000-4000-8000-000000000003',118,0.12,'All probes green'),
 ('c2000009-0000-4000-8000-000000000002','HLTH-WEB-STG','Staging web health','web-app','degraded','c2000001-0000-4000-8000-000000000002',420,1.80,'Elevated latency during deploy')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.feature_flag_rules (id,flag_id,code,name,rule_type,environment_id,status,rollout_pct,summary)
SELECT 'c200000a-0000-4000-8000-000000000001', ff.id, 'FFR-STG-INVESTOR', 'Staging investor portal rollout', 'percentage',
 'c2000001-0000-4000-8000-000000000002', 'active', 25, 'Gradual staging rollout'
FROM public.feature_flags ff
ORDER BY ff.created_at
LIMIT 1
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.feature_flag_rules (id,code,name,rule_type,environment_id,status,rollout_pct,summary) VALUES
 ('c200000a-0000-4000-8000-000000000002','FFR-DEV-DEMO','Dev demo flag rule','percentage','c2000001-0000-4000-8000-000000000001','active',100,'Always-on for development')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.incident_operations (id,code,title,category,severity,status,environment_id,commander_label,summary) VALUES
 ('c200000b-0000-4000-8000-000000000001','OPS-INC-012','Staging deploy latency spike','incident','medium','investigating','c2000001-0000-4000-8000-000000000002','SRE On-call','Correlate with active staging deploy')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.operational_runbooks (id,code,title,status,owner_label,summary,steps) VALUES
 ('c200000b-0000-4000-8000-000000000002','RB-DEPLOY-ROLLBACK','Staging deploy rollback','active','Platform Engineering','Rollback staging to previous artifact','["Pause pipeline","Redeploy previous artifact","Verify health"]'::jsonb)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.observability_metrics (id,code,title,metric_key,status,value,unit,environment_id,summary) VALUES
 ('c200000c-0000-4000-8000-000000000001','OBS-DEPLOY-SUCCESS','Deploy success rate','deploy_success_pct','ok',98.5,'pct','c2000001-0000-4000-8000-000000000003','Last 30 days')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.performance_metrics (id,code,title,metric_key,status,value,unit,environment_id,summary) VALUES
 ('c200000c-0000-4000-8000-000000000002','PERF-API-P95','API p95 latency','api_p95_ms','watch',240,'ms','c2000001-0000-4000-8000-000000000003','Slightly above baseline')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.capacity_forecasts (id,code,title,resource_type,status,forecast_pct,horizon_days,summary) VALUES
 ('c200000c-0000-4000-8000-000000000003','CAP-DB-30D','Postgres storage forecast','database','ok',62,30,'Headroom remains comfortable')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.platform_ai_insights (id,code,title,body,insight_type,confidence_pct) VALUES
 ('c200000d-0000-4000-8000-000000000001','AI-EDP-01','Hold production until CAB signs off','Release is awaiting approval; keep staging soak window open and monitor degraded web health.','release',91),
 ('c200000d-0000-4000-8000-000000000002','AI-EDP-02','Investigate staging latency before promote','Elevated staging latency overlaps an active deploy — confirm error budget before production cutover.','reliability',87)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.platform_activity_logs (id,action,title,category,actor_label,entity_type,severity,status,summary) VALUES
 ('c200000e-0000-4000-8000-000000000001','pipeline.started','Pipeline run started','pipeline','ci-bot','pipeline_runs','info','recorded','RUN-2026-0721 started'),
 ('c200000e-0000-4000-8000-000000000002','release.approval_requested','Release approval requested','release','Release Manager','releases','info','recorded','REL-2026-07 awaiting CAB')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.kpi_snapshots (id,metric_key,label,value,previous_value,unit,change_pct,series,period,metadata) VALUES
 ('c200000f-0000-4000-8000-000000000001','platform_deploy_success','Deploy Success',98.5,97.2,'pct',1.3,'[94,95,96,97,97,98,98.5]'::jsonb,'daily','{"module":"platform"}'),
 ('c200000f-0000-4000-8000-000000000002','platform_pipeline_health','Pipeline Health',96,94,'pct',2.1,'[90,91,92,93,94,95,96]'::jsonb,'daily','{"module":"platform"}'),
 ('c200000f-0000-4000-8000-000000000003','platform_slo_compliance','SLO Compliance',99.95,99.92,'pct',0.03,'[99.8,99.85,99.9,99.9,99.92,99.94,99.95]'::jsonb,'daily','{"module":"platform"}')
ON CONFLICT (id) DO NOTHING;

COMMIT;
