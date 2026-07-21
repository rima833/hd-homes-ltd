-- LOCAL ONLY — await approve
-- Volume 4 Part 18 -- Enterprise Integration Platform, API Gateway,
-- Workflow Orchestration & Event-Driven Architecture (EIP)
-- Status: LOCAL ONLY — do NOT apply remotely until approved.
--
-- Approach:
--   • Route: /dashboard/integrations → Integration Command Center.
--   • ENRICH only (never DROP/recreate) EOC workflow tables:
--     workflow_definitions, workflow_instances
--     (also present from EOC: workflow_steps, workflow_conditions, workflow_actions).
--   • Do NOT recreate thin logs: api_logs, integration_logs
--     (use prompt names api_usage_logs, integration_activity_logs).
--   • CREATE NEW workflow extensions: workflow_versions, workflow_tasks,
--     workflow_approvals, workflow_execution_logs.
--   • Seed UUIDs hex-only (a180…).
--   • Permissions: slug, name, description, module ONLY.
--   • RLS: has_permission('slug', auth.uid()) — slug FIRST.
--
-- Part 17 EAIH SQL is APPLIED. Volume 4 continues Parts 19–25.
-- Wait for approve before Part 19 and before remote apply of this file.

BEGIN;

-- ---------------------------------------------------------------------------
-- Permissions
-- ---------------------------------------------------------------------------
INSERT INTO public.permissions (slug, name, description, module) VALUES
  ('integration.read', 'View Integrations', 'View Integration Command Center', 'integration'),
  ('integration.write', 'Manage Integrations', 'Create and edit integration records', 'integration'),
  ('integration.apis', 'API Gateway', 'Manage API services, consumers, and keys', 'integration'),
  ('integration.workflows', 'Workflow Orchestration', 'Manage workflow versions, tasks, approvals', 'integration'),
  ('integration.events', 'Domain Events', 'Manage domain events and subscriptions', 'integration'),
  ('integration.webhooks', 'Webhooks', 'Manage webhook endpoints and deliveries', 'integration'),
  ('integration.queues', 'Message Queues', 'Manage queues, items, and DLQ', 'integration'),
  ('integration.connectors', 'Connectors', 'Manage connectors and credentials', 'integration'),
  ('integration.security', 'Integration Security', 'Manage API security policies and keys', 'integration'),
  ('integration.monitoring', 'Integration Monitoring', 'View health checks and activity', 'integration'),
  ('integration.ai', 'Integration AI', 'View integration AI insights', 'integration'),
  ('integration.admin', 'Integration Admin', 'Administer Enterprise Integration Platform', 'integration')
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  module = EXCLUDED.module,
  updated_at = now();

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE p.slug LIKE 'integration.%'
  AND (
    r.slug IN ('super_admin', 'admin')
    OR (r.slug = 'finance' AND p.slug IN (
      'integration.read', 'integration.apis', 'integration.workflows', 'integration.monitoring'
    ))
    OR (r.slug = 'construction_manager' AND p.slug IN (
      'integration.read', 'integration.workflows', 'integration.events', 'integration.monitoring'
    ))
    OR (r.slug = 'sales_team' AND p.slug IN (
      'integration.read', 'integration.webhooks', 'integration.events'
    ))
    OR (r.slug = 'marketing' AND p.slug IN (
      'integration.read', 'integration.webhooks', 'integration.connectors'
    ))
  )
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Enrich EOC workflow tables (ALTER ADD COLUMN IF NOT EXISTS only)
-- ---------------------------------------------------------------------------
ALTER TABLE public.workflow_definitions
  ADD COLUMN IF NOT EXISTS orchestration_engine text DEFAULT 'eoc',
  ADD COLUMN IF NOT EXISTS trigger_event text,
  ADD COLUMN IF NOT EXISTS eip_enabled boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS eip_metadata jsonb DEFAULT '{}'::jsonb;

ALTER TABLE public.workflow_instances
  ADD COLUMN IF NOT EXISTS version_label text,
  ADD COLUMN IF NOT EXISTS correlation_id text,
  ADD COLUMN IF NOT EXISTS eip_metadata jsonb DEFAULT '{}'::jsonb;

-- ---------------------------------------------------------------------------
-- API Gateway
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.api_services (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  name text NOT NULL,
  base_path text NOT NULL DEFAULT '/api/v1',
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft','active','deprecated','retired')),
  owner_label text,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.api_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  service_id uuid NOT NULL REFERENCES public.api_services(id) ON DELETE CASCADE,
  code text UNIQUE,
  version_label text NOT NULL,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft','active','deprecated','retired')),
  changelog text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.api_consumers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  name text NOT NULL,
  consumer_type text NOT NULL DEFAULT 'internal'
    CHECK (consumer_type IN ('internal','partner','public','system')),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft','active','suspended','retired')),
  owner_label text,
  contact_email text,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.api_keys (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  consumer_id uuid NOT NULL REFERENCES public.api_consumers(id) ON DELETE CASCADE,
  code text UNIQUE,
  key_prefix text NOT NULL,
  key_hint text,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','rotated','revoked')),
  scopes text[] NOT NULL DEFAULT '{}',
  expires_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.api_usage_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  service_id uuid REFERENCES public.api_services(id) ON DELETE SET NULL,
  consumer_id uuid REFERENCES public.api_consumers(id) ON DELETE SET NULL,
  code text UNIQUE,
  method text NOT NULL DEFAULT 'GET',
  path text NOT NULL,
  status_code int NOT NULL DEFAULT 200,
  latency_ms int,
  actor_label text,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_api_usage_logs_occurred
  ON public.api_usage_logs(occurred_at DESC);

CREATE TABLE IF NOT EXISTS public.api_rate_limits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  service_id uuid REFERENCES public.api_services(id) ON DELETE CASCADE,
  consumer_id uuid REFERENCES public.api_consumers(id) ON DELETE CASCADE,
  code text UNIQUE,
  name text NOT NULL,
  window_seconds int NOT NULL DEFAULT 60,
  max_requests int NOT NULL DEFAULT 100,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','paused','retired')),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.api_security_policies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  name text NOT NULL,
  policy_type text NOT NULL DEFAULT 'auth'
    CHECK (policy_type IN ('auth','cors','ip_allow','mtls','jwt','other')),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft','active','paused','retired')),
  summary text,
  rules jsonb NOT NULL DEFAULT '{}'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Workflow orchestration extensions (beyond EOC)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.workflow_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  definition_id uuid NOT NULL REFERENCES public.workflow_definitions(id) ON DELETE CASCADE,
  code text UNIQUE,
  version_label text NOT NULL,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','published','retired')),
  changelog text,
  definition_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.workflow_tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  instance_id uuid NOT NULL REFERENCES public.workflow_instances(id) ON DELETE CASCADE,
  code text UNIQUE,
  task_key text NOT NULL,
  name text NOT NULL,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','in_progress','completed','failed','cancelled','waiting')),
  assignee_label text,
  due_at timestamptz,
  completed_at timestamptz,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.workflow_approvals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  instance_id uuid REFERENCES public.workflow_instances(id) ON DELETE CASCADE,
  task_id uuid REFERENCES public.workflow_tasks(id) ON DELETE SET NULL,
  code text UNIQUE,
  title text NOT NULL,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','approved','rejected','cancelled','escalated')),
  approver_label text,
  decided_at timestamptz,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.workflow_execution_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  instance_id uuid REFERENCES public.workflow_instances(id) ON DELETE CASCADE,
  code text UNIQUE,
  step_key text,
  level text NOT NULL DEFAULT 'info'
    CHECK (level IN ('debug','info','warn','error')),
  message text NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_workflow_execution_logs_occurred
  ON public.workflow_execution_logs(occurred_at DESC);

-- ---------------------------------------------------------------------------
-- Event-driven architecture
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.domain_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  event_type text NOT NULL,
  aggregate_type text,
  aggregate_id text,
  status text NOT NULL DEFAULT 'published'
    CHECK (status IN ('draft','published','consumed','failed','archived')),
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  correlation_id text,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_domain_events_type
  ON public.domain_events(event_type, occurred_at DESC);

CREATE TABLE IF NOT EXISTS public.event_subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  name text NOT NULL,
  event_type text NOT NULL,
  target_type text NOT NULL DEFAULT 'webhook'
    CHECK (target_type IN ('webhook','queue','workflow','connector','other')),
  target_ref text,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft','active','paused','retired')),
  owner_label text,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.event_delivery_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid REFERENCES public.domain_events(id) ON DELETE SET NULL,
  subscription_id uuid REFERENCES public.event_subscriptions(id) ON DELETE SET NULL,
  code text UNIQUE,
  status text NOT NULL DEFAULT 'delivered'
    CHECK (status IN ('pending','delivered','failed','retrying')),
  attempt_count int NOT NULL DEFAULT 1,
  latency_ms int,
  error_message text,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Message queues
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.message_queues (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  name text NOT NULL,
  queue_type text NOT NULL DEFAULT 'standard'
    CHECK (queue_type IN ('standard','fifo','priority','delay')),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft','active','paused','retired')),
  depth int NOT NULL DEFAULT 0,
  owner_label text,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.message_queue_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  queue_id uuid NOT NULL REFERENCES public.message_queues(id) ON DELETE CASCADE,
  code text UNIQUE,
  subject text NOT NULL,
  status text NOT NULL DEFAULT 'queued'
    CHECK (status IN ('queued','processing','completed','failed','dead_letter')),
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  priority int NOT NULL DEFAULT 5,
  available_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.dead_letter_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  queue_id uuid REFERENCES public.message_queues(id) ON DELETE SET NULL,
  source_item_id uuid REFERENCES public.message_queue_items(id) ON DELETE SET NULL,
  code text UNIQUE,
  subject text NOT NULL,
  reason text,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','requeued','discarded')),
  occurred_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Webhooks
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.webhook_endpoints (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  name text NOT NULL,
  url text NOT NULL,
  event_types text[] NOT NULL DEFAULT '{}',
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft','active','paused','retired')),
  secret_key_ref text,
  owner_label text,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.webhook_deliveries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  endpoint_id uuid NOT NULL REFERENCES public.webhook_endpoints(id) ON DELETE CASCADE,
  code text UNIQUE,
  event_type text,
  status text NOT NULL DEFAULT 'delivered'
    CHECK (status IN ('pending','delivered','failed','retrying')),
  status_code int,
  latency_ms int,
  attempt_count int NOT NULL DEFAULT 1,
  error_message text,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Connectors & credentials (encrypt-ready)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.integration_connectors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  name text NOT NULL,
  connector_type text NOT NULL DEFAULT 'other'
    CHECK (connector_type IN (
      'payment','email','maps','sms','storage','erp','crm','other'
    )),
  provider_slug text,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft','active','degraded','paused','retired')),
  owner_label text,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.integration_credentials (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  connector_id uuid NOT NULL REFERENCES public.integration_connectors(id) ON DELETE CASCADE,
  code text UNIQUE,
  name text NOT NULL,
  -- Encrypt-ready: never store plaintext secrets in seeds
  encrypted_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  key_ref text NOT NULL DEFAULT 'vault://local/dev',
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','rotated','revoked')),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.integration_health_checks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  connector_id uuid REFERENCES public.integration_connectors(id) ON DELETE SET NULL,
  code text UNIQUE,
  check_name text NOT NULL,
  status text NOT NULL DEFAULT 'ok'
    CHECK (status IN ('ok','watch','critical','unknown')),
  latency_ms int,
  summary text,
  observed_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Service registry / config
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.service_registry (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  name text NOT NULL,
  service_url text,
  environment text NOT NULL DEFAULT 'production'
    CHECK (environment IN ('development','staging','production')),
  status text NOT NULL DEFAULT 'healthy'
    CHECK (status IN ('healthy','degraded','down','unknown')),
  owner_label text,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.feature_flags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  name text NOT NULL,
  flag_key text NOT NULL UNIQUE,
  is_enabled boolean NOT NULL DEFAULT false,
  rollout_pct numeric(5,2) NOT NULL DEFAULT 0,
  owner_label text,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.configuration_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  setting_key text NOT NULL UNIQUE,
  setting_value jsonb NOT NULL DEFAULT '{}'::jsonb,
  scope text NOT NULL DEFAULT 'global'
    CHECK (scope IN ('global','service','environment','tenant')),
  owner_label text,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Reports, activity, notifications, AI insights
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.integration_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  title text NOT NULL,
  report_type text NOT NULL DEFAULT 'ops'
    CHECK (report_type IN ('ops','security','sla','usage','other')),
  status text NOT NULL DEFAULT 'ready'
    CHECK (status IN ('draft','ready','archived')),
  summary text,
  metrics jsonb NOT NULL DEFAULT '{}'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.integration_activity_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  action text NOT NULL,
  summary text NOT NULL,
  actor_label text,
  entity_type text,
  entity_id text,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_integration_activity_logs_occurred
  ON public.integration_activity_logs(occurred_at DESC);

CREATE TABLE IF NOT EXISTS public.integration_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  title text NOT NULL,
  body text,
  severity text NOT NULL DEFAULT 'info'
    CHECK (severity IN ('info','watch','critical')),
  status text NOT NULL DEFAULT 'unread'
    CHECK (status IN ('unread','read','archived')),
  occurred_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.integration_ai_insights (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  title text NOT NULL,
  body text NOT NULL,
  insight_type text NOT NULL DEFAULT 'ops'
    CHECK (insight_type IN ('ops','risk','optimization','security','other')),
  confidence_pct numeric(5,2),
  editable boolean NOT NULL DEFAULT true,
  disclaimer text NOT NULL DEFAULT 'AI-generated — editable / advisory',
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','dismissed','archived')),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Storage bucket
-- ---------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('integration-logs', 'integration-logs', false)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.domain_events; EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.workflow_instances; EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.webhook_deliveries; EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.message_queue_items; EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.integration_health_checks; EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.integration_activity_logs; EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.integration_notifications; EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

-- ---------------------------------------------------------------------------
-- Seeds (hex-only UUIDs a180…)
-- ---------------------------------------------------------------------------

-- Enrich existing EOC workflow defs for EIP orchestration
UPDATE public.workflow_definitions
SET
  orchestration_engine = 'eip',
  eip_enabled = true,
  trigger_event = CASE code
    WHEN 'WF-PO-ESCALATION' THEN 'PurchaseOrderSubmitted'
    WHEN 'WF-SALES-CONTRACT' THEN 'ContractSigned'
    WHEN 'WF-SITE-INCIDENT' THEN 'SiteIncidentReported'
    ELSE trigger_event
  END,
  eip_metadata = coalesce(eip_metadata, '{}'::jsonb) || jsonb_build_object('eip_seeded', true)
WHERE code IN ('WF-PO-ESCALATION', 'WF-SALES-CONTRACT', 'WF-SITE-INCIDENT');

-- Seed additional EIP-owned workflow definition (safe if EOC defs missing)
INSERT INTO public.workflow_definitions (
  id, code, name, description, module_slug, status, orchestration_engine, trigger_event, eip_enabled, eip_metadata
) VALUES
  (
    'a1800009-0000-4000-8000-000000000001',
    'WF-EIP-PAYMENT-RECON',
    'Payment Reconciliation Orchestration',
    'EIP-owned payment completion → ledger reconcile → notify finance',
    'finance',
    'active',
    'eip',
    'PaymentCompleted',
    true,
    '{"eip_owned": true}'::jsonb
  )
ON CONFLICT (code) DO UPDATE SET
  orchestration_engine = EXCLUDED.orchestration_engine,
  eip_enabled = EXCLUDED.eip_enabled,
  trigger_event = EXCLUDED.trigger_event,
  eip_metadata = EXCLUDED.eip_metadata,
  updated_at = now();

INSERT INTO public.api_services (id, code, name, base_path, status, owner_label, summary) VALUES
  (
    'a1800001-0000-4000-8000-000000000001',
    'API-CORE-01', 'HD Homes Core API', '/api/v1', 'active',
    'Platform', 'Primary REST gateway for portal and partners.'
  ),
  (
    'a1800001-0000-4000-8000-000000000002',
    'API-PAY-01', 'Payments API', '/api/v1/payments', 'active',
    'Finance Ops', 'Payment initiation and webhook callbacks.'
  ),
  (
    'a1800001-0000-4000-8000-000000000003',
    'API-EVT-01', 'Events Ingress API', '/api/v1/events', 'active',
    'Integration', 'Domain event publish and subscribe ingress.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.api_versions (id, service_id, code, version_label, status, changelog) VALUES
  (
    'a1800002-0000-4000-8000-000000000001',
    'a1800001-0000-4000-8000-000000000001',
    'API-CORE-01-v1', '1.0.0', 'active', 'Initial core gateway surface.'
  ),
  (
    'a1800002-0000-4000-8000-000000000002',
    'a1800001-0000-4000-8000-000000000002',
    'API-PAY-01-v1', '1.2.0', 'active', 'Paystack callback + reconcile stubs.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.api_consumers (id, code, name, consumer_type, status, owner_label, contact_email, summary) VALUES
  (
    'a1800003-0000-4000-8000-000000000001',
    'CON-PORTAL', 'Admin Portal', 'internal', 'active',
    'Platform', 'ops@hdhomes.local', 'First-party admin Flutter client.'
  ),
  (
    'a1800003-0000-4000-8000-000000000002',
    'CON-PARTNER', 'Channel Partner Hub', 'partner', 'active',
    'Sales Ops', 'partners@hdhomes.local', 'External partner inventory sync.'
  ),
  (
    'a1800003-0000-4000-8000-000000000003',
    'CON-SYSTEM', 'Background Workers', 'system', 'active',
    'Integration', NULL, 'Queue consumers and workflow runners.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.api_keys (id, consumer_id, code, key_prefix, key_hint, status, scopes) VALUES
  (
    'a1800004-0000-4000-8000-000000000001',
    'a1800003-0000-4000-8000-000000000001',
    'KEY-PORTAL-01', 'hdh_live_', '…a1b2', 'active',
    ARRAY['integration.read','integration.apis']
  ),
  (
    'a1800004-0000-4000-8000-000000000002',
    'a1800003-0000-4000-8000-000000000002',
    'KEY-PARTNER-01', 'hdh_part_', '…c3d4', 'active',
    ARRAY['integration.read','integration.webhooks']
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.api_usage_logs (
  id, service_id, consumer_id, code, method, path, status_code, latency_ms, actor_label, occurred_at
) VALUES
  (
    'a1800005-0000-4000-8000-000000000001',
    'a1800001-0000-4000-8000-000000000001',
    'a1800003-0000-4000-8000-000000000001',
    'USG-CORE-01', 'GET', '/api/v1/properties', 200, 42, 'Admin Portal', now() - interval '1 hour'
  ),
  (
    'a1800005-0000-4000-8000-000000000002',
    'a1800001-0000-4000-8000-000000000002',
    'a1800003-0000-4000-8000-000000000003',
    'USG-PAY-01', 'POST', '/api/v1/payments/webhooks/paystack', 200, 118, 'Background Workers', now() - interval '30 minutes'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.api_rate_limits (id, service_id, consumer_id, code, name, window_seconds, max_requests, status) VALUES
  (
    'a1800006-0000-4000-8000-000000000001',
    'a1800001-0000-4000-8000-000000000001',
    'a1800003-0000-4000-8000-000000000002',
    'RL-PARTNER-60', 'Partner 60/min', 60, 60, 'active'
  ),
  (
    'a1800006-0000-4000-8000-000000000002',
    'a1800001-0000-4000-8000-000000000002',
    NULL,
    'RL-PAY-GLOBAL', 'Payments global burst', 10, 200, 'active'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.api_security_policies (id, code, name, policy_type, status, summary, rules) VALUES
  (
    'a1800007-0000-4000-8000-000000000001',
    'SEC-JWT-01', 'JWT required for admin APIs', 'jwt', 'active',
    'Require signed JWT for /api/v1 admin surfaces.',
    '{"alg":"RS256","audience":"hdhomes-admin"}'::jsonb
  ),
  (
    'a1800007-0000-4000-8000-000000000002',
    'SEC-IP-01', 'Partner IP allowlist', 'ip_allow', 'active',
    'Restrict partner consumer to known egress IPs.',
    '{"allow":["203.0.113.0/24"]}'::jsonb
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.workflow_versions (id, definition_id, code, version_label, status, changelog) VALUES
  (
    'a180000a-0000-4000-8000-000000000001',
    'a1800009-0000-4000-8000-000000000001',
    'WFV-PAY-RECON-v1', '1.0.0', 'published',
    'Initial payment reconciliation orchestration.'
  ),
  (
    'a180000a-0000-4000-8000-000000000002',
    'e0100009-0000-4000-8000-000000000001',
    'WFV-PO-ESC-v2', '2.0.0', 'published',
    'EIP enrichment of EOC PO escalation.'
  )
ON CONFLICT (id) DO NOTHING;

-- Sample workflow instance on EIP-owned def
INSERT INTO public.workflow_instances (
  id, definition_id, reference_label, status, current_step_key, started_at, version_label, correlation_id, eip_metadata
) VALUES
  (
    'a180000b-0000-4000-8000-000000000001',
    'a1800009-0000-4000-8000-000000000001',
    'PAY-REC-7781', 'running', 'reconcile', now() - interval '2 hours',
    '1.0.0', 'corr-pay-7781', '{"source":"eip_seed"}'::jsonb
  ),
  (
    'a180000b-0000-4000-8000-000000000002',
    'e0100009-0000-4000-8000-000000000001',
    'PO-4421', 'waiting', 'manager_approval', now() - interval '1 day',
    '2.0.0', 'corr-po-4421', '{"source":"eip_seed"}'::jsonb
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.workflow_tasks (
  id, instance_id, code, task_key, name, status, assignee_label, summary
) VALUES
  (
    'a180000c-0000-4000-8000-000000000001',
    'a180000b-0000-4000-8000-000000000001',
    'WFT-RECON-01', 'reconcile', 'Reconcile ledger entry', 'in_progress',
    'Finance Ops', 'Match Paystack settlement to invoice.'
  ),
  (
    'a180000c-0000-4000-8000-000000000002',
    'a180000b-0000-4000-8000-000000000002',
    'WFT-PO-APPR-01', 'manager_approval', 'Manager approval', 'waiting',
    'Admin', 'Await dual approval for PO above threshold.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.workflow_approvals (
  id, instance_id, task_id, code, title, status, approver_label, summary
) VALUES
  (
    'a180000d-0000-4000-8000-000000000001',
    'a180000b-0000-4000-8000-000000000002',
    'a180000c-0000-4000-8000-000000000002',
    'WFA-PO-01', 'Approve PO-4421 escalation', 'pending',
    'Admin', 'Pending finance dual control.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.workflow_execution_logs (
  id, instance_id, code, step_key, level, message, occurred_at
) VALUES
  (
    'a180000e-0000-4000-8000-000000000001',
    'a180000b-0000-4000-8000-000000000001',
    'WFL-PAY-01', 'reconcile', 'info',
    'Reconciliation task started for PAY-REC-7781', now() - interval '2 hours'
  ),
  (
    'a180000e-0000-4000-8000-000000000002',
    'a180000b-0000-4000-8000-000000000002',
    'WFL-PO-01', 'manager_approval', 'warn',
    'Approval waiting beyond SLA threshold', now() - interval '6 hours'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.domain_events (
  id, code, event_type, aggregate_type, aggregate_id, status, payload, correlation_id, occurred_at
) VALUES
  (
    'a1800010-0000-4000-8000-000000000001',
    'EVT-PAY-01', 'PaymentCompleted', 'payment', 'pay_7781', 'published',
    '{"amount":2500000,"currency":"NGN","channel":"paystack"}'::jsonb,
    'corr-pay-7781', now() - interval '2 hours'
  ),
  (
    'a1800010-0000-4000-8000-000000000002',
    'EVT-BOOK-01', 'BookingConfirmed', 'booking', 'bk_991', 'published',
    '{"unit":"HG-B12","client":"demo"}'::jsonb,
    'corr-book-991', now() - interval '5 hours'
  ),
  (
    'a1800010-0000-4000-8000-000000000003',
    'EVT-LEAD-01', 'LeadCreated', 'lead', 'lead_441', 'published',
    '{"source":"website","score":72}'::jsonb,
    'corr-lead-441', now() - interval '1 day'
  ),
  (
    'a1800010-0000-4000-8000-000000000004',
    'EVT-PO-01', 'PurchaseOrderSubmitted', 'purchase_order', 'po_4421', 'published',
    '{"amount":18000000,"vendor":"BuildCo"}'::jsonb,
    'corr-po-4421', now() - interval '1 day'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.event_subscriptions (
  id, code, name, event_type, target_type, target_ref, status, owner_label, summary
) VALUES
  (
    'a1800011-0000-4000-8000-000000000001',
    'SUB-PAY-WF', 'Payment → reconcile workflow', 'PaymentCompleted',
    'workflow', 'WF-EIP-PAYMENT-RECON', 'active', 'Finance Ops',
    'Start payment reconciliation orchestration.'
  ),
  (
    'a1800011-0000-4000-8000-000000000002',
    'SUB-BOOK-WH', 'Booking → partner webhook', 'BookingConfirmed',
    'webhook', 'WH-PARTNER-01', 'active', 'Sales Ops',
    'Notify channel partners of confirmed bookings.'
  ),
  (
    'a1800011-0000-4000-8000-000000000003',
    'SUB-LEAD-Q', 'Lead → CRM queue', 'LeadCreated',
    'queue', 'Q-CRM-LEADS', 'active', 'CRM Lead',
    'Enqueue new leads for CRM intake.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.event_delivery_logs (
  id, event_id, subscription_id, code, status, attempt_count, latency_ms, occurred_at
) VALUES
  (
    'a1800012-0000-4000-8000-000000000001',
    'a1800010-0000-4000-8000-000000000001',
    'a1800011-0000-4000-8000-000000000001',
    'EDL-PAY-01', 'delivered', 1, 85, now() - interval '2 hours'
  ),
  (
    'a1800012-0000-4000-8000-000000000002',
    'a1800010-0000-4000-8000-000000000002',
    'a1800011-0000-4000-8000-000000000002',
    'EDL-BOOK-01', 'retrying', 2, 410, now() - interval '4 hours'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.message_queues (id, code, name, queue_type, status, depth, owner_label, summary) VALUES
  (
    'a1800013-0000-4000-8000-000000000001',
    'Q-CRM-LEADS', 'CRM Lead Intake', 'standard', 'active', 3,
    'CRM Lead', 'Inbound leads from website and partners.'
  ),
  (
    'a1800013-0000-4000-8000-000000000002',
    'Q-PAY-SETTLE', 'Payment Settlements', 'fifo', 'active', 1,
    'Finance Ops', 'Settlement and reconcile jobs.'
  ),
  (
    'a1800013-0000-4000-8000-000000000003',
    'Q-NOTIFY', 'Notification Dispatch', 'priority', 'active', 8,
    'Platform', 'Outbound email/SMS fan-out.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.message_queue_items (
  id, queue_id, code, subject, status, payload, priority, available_at
) VALUES
  (
    'a1800014-0000-4000-8000-000000000001',
    'a1800013-0000-4000-8000-000000000001',
    'QI-LEAD-01', 'LeadCreated lead_441', 'queued',
    '{"lead_id":"lead_441"}'::jsonb, 5, now()
  ),
  (
    'a1800014-0000-4000-8000-000000000002',
    'a1800013-0000-4000-8000-000000000002',
    'QI-PAY-01', 'Settle pay_7781', 'processing',
    '{"payment_id":"pay_7781"}'::jsonb, 2, now() - interval '30 minutes'
  ),
  (
    'a1800014-0000-4000-8000-000000000003',
    'a1800013-0000-4000-8000-000000000003',
    'QI-NTF-FAIL', 'Email bounce retry', 'failed',
    '{"template":"welcome"}'::jsonb, 7, now() - interval '3 hours'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.dead_letter_messages (
  id, queue_id, source_item_id, code, subject, reason, payload, status, occurred_at
) VALUES
  (
    'a1800015-0000-4000-8000-000000000001',
    'a1800013-0000-4000-8000-000000000003',
    'a1800014-0000-4000-8000-000000000003',
    'DLQ-NTF-01', 'Email bounce retry', 'Max retries exceeded',
    '{"template":"welcome"}'::jsonb, 'open', now() - interval '2 hours'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.webhook_endpoints (
  id, code, name, url, event_types, status, secret_key_ref, owner_label, summary
) VALUES
  (
    'a1800016-0000-4000-8000-000000000001',
    'WH-PARTNER-01', 'Partner booking webhook',
    'https://partners.example.local/hooks/bookings',
    ARRAY['BookingConfirmed'], 'active', 'vault://webhooks/partner-01',
    'Sales Ops', 'Outbound booking notifications.'
  ),
  (
    'a1800016-0000-4000-8000-000000000002',
    'WH-PAYSTACK-IN', 'Paystack inbound callback',
    'https://api.hdhomes.local/webhooks/paystack',
    ARRAY['PaymentCompleted'], 'active', 'vault://webhooks/paystack',
    'Finance Ops', 'Inbound payment provider callbacks.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.webhook_deliveries (
  id, endpoint_id, code, event_type, status, status_code, latency_ms, attempt_count, occurred_at
) VALUES
  (
    'a1800017-0000-4000-8000-000000000001',
    'a1800016-0000-4000-8000-000000000001',
    'WHD-BOOK-01', 'BookingConfirmed', 'delivered', 200, 95, 1, now() - interval '5 hours'
  ),
  (
    'a1800017-0000-4000-8000-000000000002',
    'a1800016-0000-4000-8000-000000000001',
    'WHD-BOOK-02', 'BookingConfirmed', 'failed', 503, 1200, 3, now() - interval '4 hours'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.integration_connectors (
  id, code, name, connector_type, provider_slug, status, owner_label, summary
) VALUES
  (
    'a1800018-0000-4000-8000-000000000001',
    'CONN-PAYSTACK', 'Paystack Payments', 'payment', 'paystack', 'active',
    'Finance Ops', 'Payment initiation and settlement stubs.'
  ),
  (
    'a1800018-0000-4000-8000-000000000002',
    'CONN-EMAIL', 'Transactional Email', 'email', 'resend', 'active',
    'Platform', 'Outbound transactional email stub.'
  ),
  (
    'a1800018-0000-4000-8000-000000000003',
    'CONN-MAPS', 'Maps & Geocoding', 'maps', 'google_maps', 'degraded',
    'Platform', 'Estate map and geocode stub.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.integration_credentials (
  id, connector_id, code, name, encrypted_payload, key_ref, status
) VALUES
  (
    'a1800019-0000-4000-8000-000000000001',
    'a1800018-0000-4000-8000-000000000001',
    'CRED-PAYSTACK', 'Paystack secret ref',
    '{"cipher":"aes-gcm","blob":"enc:stub-paystack"}'::jsonb,
    'vault://connectors/paystack', 'active'
  ),
  (
    'a1800019-0000-4000-8000-000000000002',
    'a1800018-0000-4000-8000-000000000002',
    'CRED-EMAIL', 'Email API key ref',
    '{"cipher":"aes-gcm","blob":"enc:stub-email"}'::jsonb,
    'vault://connectors/email', 'active'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.integration_health_checks (
  id, connector_id, code, check_name, status, latency_ms, summary, observed_at
) VALUES
  (
    'a180001a-0000-4000-8000-000000000001',
    'a1800018-0000-4000-8000-000000000001',
    'HC-PAYSTACK', 'Paystack ping', 'ok', 110,
    'Provider reachable.', now() - interval '10 minutes'
  ),
  (
    'a180001a-0000-4000-8000-000000000002',
    'a1800018-0000-4000-8000-000000000002',
    'HC-EMAIL', 'Email provider ping', 'ok', 85,
    'Provider reachable.', now() - interval '12 minutes'
  ),
  (
    'a180001a-0000-4000-8000-000000000003',
    'a1800018-0000-4000-8000-000000000003',
    'HC-MAPS', 'Maps provider ping', 'watch', 620,
    'Elevated latency on geocode.', now() - interval '8 minutes'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.service_registry (
  id, code, name, service_url, environment, status, owner_label, summary
) VALUES
  (
    'a180001b-0000-4000-8000-000000000001',
    'SVC-REG-API', 'API Gateway', 'https://api.hdhomes.local', 'production',
    'healthy', 'Platform', 'Edge API gateway.'
  ),
  (
    'a180001b-0000-4000-8000-000000000002',
    'SVC-REG-WF', 'Workflow Runner', 'https://wf.hdhomes.local', 'production',
    'healthy', 'Integration', 'Orchestration worker fleet.'
  ),
  (
    'a180001b-0000-4000-8000-000000000003',
    'SVC-REG-Q', 'Queue Workers', 'https://q.hdhomes.local', 'production',
    'degraded', 'Integration', 'One worker pool under load.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.feature_flags (
  id, code, name, flag_key, is_enabled, rollout_pct, owner_label, summary
) VALUES
  (
    'a180001c-0000-4000-8000-000000000001',
    'FF-EIP-EVENTS', 'Enable domain event bus', 'eip.events.enabled',
    true, 100, 'Integration', 'Publish domain events from core modules.'
  ),
  (
    'a180001c-0000-4000-8000-000000000002',
    'FF-EIP-WF-V2', 'EIP workflow engine v2', 'eip.workflows.v2',
    false, 25, 'Integration', 'Gradual rollout of EIP orchestration engine.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.configuration_settings (
  id, code, setting_key, setting_value, scope, owner_label, summary
) VALUES
  (
    'a180001d-0000-4000-8000-000000000001',
    'CFG-RETRY', 'eip.webhook.max_retries',
    '{"max_retries":3,"backoff_ms":5000}'::jsonb,
    'global', 'Integration', 'Default webhook retry policy.'
  ),
  (
    'a180001d-0000-4000-8000-000000000002',
    'CFG-QUEUE', 'eip.queue.visibility_timeout_sec',
    '{"seconds":30}'::jsonb,
    'service', 'Integration', 'Queue visibility timeout.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.integration_reports (
  id, code, title, report_type, status, summary, metrics
) VALUES
  (
    'a180001e-0000-4000-8000-000000000001',
    'RPT-SLA-7D', 'Integration SLA — 7 days', 'sla', 'ready',
    'Gateway and webhook delivery SLA snapshot.',
    '{"api_success_pct":99.2,"webhook_success_pct":96.5}'::jsonb
  ),
  (
    'a180001e-0000-4000-8000-000000000002',
    'RPT-USAGE-24H', 'API usage — 24h', 'usage', 'ready',
    'Request volume by service.',
    '{"requests":18420,"p95_ms":210}'::jsonb
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.integration_activity_logs (
  id, code, action, summary, actor_label, entity_type, entity_id, occurred_at
) VALUES
  (
    'a180001f-0000-4000-8000-000000000001',
    'ACT-EVT-01', 'event_published', 'PaymentCompleted published for pay_7781',
    'Payments API', 'domain_event', 'a1800010-0000-4000-8000-000000000001',
    now() - interval '2 hours'
  ),
  (
    'a180001f-0000-4000-8000-000000000002',
    'ACT-WF-01', 'workflow_started', 'Payment reconciliation workflow started',
    'Workflow Runner', 'workflow_instance', 'a180000b-0000-4000-8000-000000000001',
    now() - interval '2 hours'
  ),
  (
    'a180001f-0000-4000-8000-000000000003',
    'ACT-WH-01', 'webhook_failed', 'Partner booking webhook failed (503)',
    'Webhook Dispatcher', 'webhook_delivery', 'a1800017-0000-4000-8000-000000000002',
    now() - interval '4 hours'
  ),
  (
    'a180001f-0000-4000-8000-000000000004',
    'ACT-HC-01', 'health_watch', 'Maps connector elevated latency',
    'Health Monitor', 'integration_health_check', 'a180001a-0000-4000-8000-000000000003',
    now() - interval '8 minutes'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.integration_notifications (
  id, code, title, body, severity, status, occurred_at
) VALUES
  (
    'a1800020-0000-4000-8000-000000000001',
    'NTF-WH-FAIL', 'Webhook delivery failures',
    'Partner booking webhook failed 3 times — review DLQ and endpoint health.',
    'watch', 'unread', now() - interval '4 hours'
  ),
  (
    'a1800020-0000-4000-8000-000000000002',
    'NTF-MAPS', 'Maps connector watch',
    'Geocode latency elevated above 500ms.',
    'watch', 'unread', now() - interval '8 minutes'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.integration_ai_insights (
  id, code, title, body, insight_type, confidence_pct, editable, disclaimer, status
) VALUES
  (
    'a1800021-0000-4000-8000-000000000001',
    'AI-EIP-01', 'Retry partner webhook with backoff',
    'WHD-BOOK-02 shows 503 pattern — recommend exponential backoff and partner status page check.',
    'ops', 86.5, true, 'AI-generated — editable / advisory', 'active'
  ),
  (
    'a1800021-0000-4000-8000-000000000002',
    'AI-EIP-02', 'Scale queue workers for notify fan-out',
    'Q-NOTIFY depth trending up; temporary worker scale may clear backlog before peak hours.',
    'optimization', 78, true, 'AI-generated — editable / advisory', 'active'
  ),
  (
    'a1800021-0000-4000-8000-000000000003',
    'AI-EIP-03', 'Tighten partner API rate limit',
    'Partner consumer nearing RL-PARTNER-60; consider 45/min during campaign spikes.',
    'security', 81, true, 'AI-generated — editable / advisory', 'active'
  )
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.api_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.api_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.api_consumers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.api_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.api_usage_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.api_rate_limits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.api_security_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workflow_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workflow_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workflow_approvals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workflow_execution_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.domain_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_delivery_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_queues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_queue_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dead_letter_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.webhook_endpoints ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.webhook_deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.integration_connectors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.integration_credentials ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.integration_health_checks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_registry ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feature_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.configuration_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.integration_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.integration_activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.integration_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.integration_ai_insights ENABLE ROW LEVEL SECURITY;

-- Helper pattern: slug FIRST in has_permission
DROP POLICY IF EXISTS api_services_select ON public.api_services;
DROP POLICY IF EXISTS api_services_write ON public.api_services;
CREATE POLICY api_services_select ON public.api_services FOR SELECT
  USING (public.has_permission('integration.read', auth.uid()) OR public.has_permission('integration.apis', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY api_services_write ON public.api_services FOR ALL
  USING (public.has_permission('integration.apis', auth.uid()) OR public.has_permission('integration.write', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('integration.apis', auth.uid()) OR public.has_permission('integration.write', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS api_versions_select ON public.api_versions;
DROP POLICY IF EXISTS api_versions_write ON public.api_versions;
CREATE POLICY api_versions_select ON public.api_versions FOR SELECT
  USING (public.has_permission('integration.read', auth.uid()) OR public.has_permission('integration.apis', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY api_versions_write ON public.api_versions FOR ALL
  USING (public.has_permission('integration.apis', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('integration.apis', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS api_consumers_select ON public.api_consumers;
DROP POLICY IF EXISTS api_consumers_write ON public.api_consumers;
CREATE POLICY api_consumers_select ON public.api_consumers FOR SELECT
  USING (public.has_permission('integration.read', auth.uid()) OR public.has_permission('integration.apis', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY api_consumers_write ON public.api_consumers FOR ALL
  USING (public.has_permission('integration.apis', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('integration.apis', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS api_keys_select ON public.api_keys;
DROP POLICY IF EXISTS api_keys_write ON public.api_keys;
CREATE POLICY api_keys_select ON public.api_keys FOR SELECT
  USING (public.has_permission('integration.security', auth.uid()) OR public.has_permission('integration.apis', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY api_keys_write ON public.api_keys FOR ALL
  USING (public.has_permission('integration.security', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('integration.security', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS api_usage_logs_select ON public.api_usage_logs;
DROP POLICY IF EXISTS api_usage_logs_write ON public.api_usage_logs;
CREATE POLICY api_usage_logs_select ON public.api_usage_logs FOR SELECT
  USING (public.has_permission('integration.read', auth.uid()) OR public.has_permission('integration.monitoring', auth.uid()) OR public.has_permission('integration.apis', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY api_usage_logs_write ON public.api_usage_logs FOR ALL
  USING (public.has_permission('integration.apis', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('integration.apis', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS api_rate_limits_select ON public.api_rate_limits;
DROP POLICY IF EXISTS api_rate_limits_write ON public.api_rate_limits;
CREATE POLICY api_rate_limits_select ON public.api_rate_limits FOR SELECT
  USING (public.has_permission('integration.read', auth.uid()) OR public.has_permission('integration.security', auth.uid()) OR public.has_permission('integration.apis', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY api_rate_limits_write ON public.api_rate_limits FOR ALL
  USING (public.has_permission('integration.security', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('integration.security', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS api_security_policies_select ON public.api_security_policies;
DROP POLICY IF EXISTS api_security_policies_write ON public.api_security_policies;
CREATE POLICY api_security_policies_select ON public.api_security_policies FOR SELECT
  USING (public.has_permission('integration.read', auth.uid()) OR public.has_permission('integration.security', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY api_security_policies_write ON public.api_security_policies FOR ALL
  USING (public.has_permission('integration.security', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('integration.security', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS workflow_versions_select ON public.workflow_versions;
DROP POLICY IF EXISTS workflow_versions_write ON public.workflow_versions;
CREATE POLICY workflow_versions_select ON public.workflow_versions FOR SELECT
  USING (public.has_permission('integration.read', auth.uid()) OR public.has_permission('integration.workflows', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY workflow_versions_write ON public.workflow_versions FOR ALL
  USING (public.has_permission('integration.workflows', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('integration.workflows', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS workflow_tasks_select ON public.workflow_tasks;
DROP POLICY IF EXISTS workflow_tasks_write ON public.workflow_tasks;
CREATE POLICY workflow_tasks_select ON public.workflow_tasks FOR SELECT
  USING (public.has_permission('integration.read', auth.uid()) OR public.has_permission('integration.workflows', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY workflow_tasks_write ON public.workflow_tasks FOR ALL
  USING (public.has_permission('integration.workflows', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('integration.workflows', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS workflow_approvals_select ON public.workflow_approvals;
DROP POLICY IF EXISTS workflow_approvals_write ON public.workflow_approvals;
CREATE POLICY workflow_approvals_select ON public.workflow_approvals FOR SELECT
  USING (public.has_permission('integration.read', auth.uid()) OR public.has_permission('integration.workflows', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY workflow_approvals_write ON public.workflow_approvals FOR ALL
  USING (public.has_permission('integration.workflows', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('integration.workflows', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS workflow_execution_logs_select ON public.workflow_execution_logs;
DROP POLICY IF EXISTS workflow_execution_logs_write ON public.workflow_execution_logs;
CREATE POLICY workflow_execution_logs_select ON public.workflow_execution_logs FOR SELECT
  USING (public.has_permission('integration.read', auth.uid()) OR public.has_permission('integration.workflows', auth.uid()) OR public.has_permission('integration.monitoring', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY workflow_execution_logs_write ON public.workflow_execution_logs FOR ALL
  USING (public.has_permission('integration.workflows', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('integration.workflows', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS domain_events_select ON public.domain_events;
DROP POLICY IF EXISTS domain_events_write ON public.domain_events;
CREATE POLICY domain_events_select ON public.domain_events FOR SELECT
  USING (public.has_permission('integration.read', auth.uid()) OR public.has_permission('integration.events', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY domain_events_write ON public.domain_events FOR ALL
  USING (public.has_permission('integration.events', auth.uid()) OR public.has_permission('integration.write', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('integration.events', auth.uid()) OR public.has_permission('integration.write', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS event_subscriptions_select ON public.event_subscriptions;
DROP POLICY IF EXISTS event_subscriptions_write ON public.event_subscriptions;
CREATE POLICY event_subscriptions_select ON public.event_subscriptions FOR SELECT
  USING (public.has_permission('integration.read', auth.uid()) OR public.has_permission('integration.events', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY event_subscriptions_write ON public.event_subscriptions FOR ALL
  USING (public.has_permission('integration.events', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('integration.events', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS event_delivery_logs_select ON public.event_delivery_logs;
DROP POLICY IF EXISTS event_delivery_logs_write ON public.event_delivery_logs;
CREATE POLICY event_delivery_logs_select ON public.event_delivery_logs FOR SELECT
  USING (public.has_permission('integration.read', auth.uid()) OR public.has_permission('integration.events', auth.uid()) OR public.has_permission('integration.monitoring', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY event_delivery_logs_write ON public.event_delivery_logs FOR ALL
  USING (public.has_permission('integration.events', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('integration.events', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS message_queues_select ON public.message_queues;
DROP POLICY IF EXISTS message_queues_write ON public.message_queues;
CREATE POLICY message_queues_select ON public.message_queues FOR SELECT
  USING (public.has_permission('integration.read', auth.uid()) OR public.has_permission('integration.queues', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY message_queues_write ON public.message_queues FOR ALL
  USING (public.has_permission('integration.queues', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('integration.queues', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS message_queue_items_select ON public.message_queue_items;
DROP POLICY IF EXISTS message_queue_items_write ON public.message_queue_items;
CREATE POLICY message_queue_items_select ON public.message_queue_items FOR SELECT
  USING (public.has_permission('integration.read', auth.uid()) OR public.has_permission('integration.queues', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY message_queue_items_write ON public.message_queue_items FOR ALL
  USING (public.has_permission('integration.queues', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('integration.queues', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS dead_letter_messages_select ON public.dead_letter_messages;
DROP POLICY IF EXISTS dead_letter_messages_write ON public.dead_letter_messages;
CREATE POLICY dead_letter_messages_select ON public.dead_letter_messages FOR SELECT
  USING (public.has_permission('integration.read', auth.uid()) OR public.has_permission('integration.queues', auth.uid()) OR public.has_permission('integration.monitoring', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY dead_letter_messages_write ON public.dead_letter_messages FOR ALL
  USING (public.has_permission('integration.queues', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('integration.queues', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS webhook_endpoints_select ON public.webhook_endpoints;
DROP POLICY IF EXISTS webhook_endpoints_write ON public.webhook_endpoints;
CREATE POLICY webhook_endpoints_select ON public.webhook_endpoints FOR SELECT
  USING (public.has_permission('integration.read', auth.uid()) OR public.has_permission('integration.webhooks', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY webhook_endpoints_write ON public.webhook_endpoints FOR ALL
  USING (public.has_permission('integration.webhooks', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('integration.webhooks', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS webhook_deliveries_select ON public.webhook_deliveries;
DROP POLICY IF EXISTS webhook_deliveries_write ON public.webhook_deliveries;
CREATE POLICY webhook_deliveries_select ON public.webhook_deliveries FOR SELECT
  USING (public.has_permission('integration.read', auth.uid()) OR public.has_permission('integration.webhooks', auth.uid()) OR public.has_permission('integration.monitoring', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY webhook_deliveries_write ON public.webhook_deliveries FOR ALL
  USING (public.has_permission('integration.webhooks', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('integration.webhooks', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS integration_connectors_select ON public.integration_connectors;
DROP POLICY IF EXISTS integration_connectors_write ON public.integration_connectors;
CREATE POLICY integration_connectors_select ON public.integration_connectors FOR SELECT
  USING (public.has_permission('integration.read', auth.uid()) OR public.has_permission('integration.connectors', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY integration_connectors_write ON public.integration_connectors FOR ALL
  USING (public.has_permission('integration.connectors', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('integration.connectors', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS integration_credentials_select ON public.integration_credentials;
DROP POLICY IF EXISTS integration_credentials_write ON public.integration_credentials;
CREATE POLICY integration_credentials_select ON public.integration_credentials FOR SELECT
  USING (public.has_permission('integration.security', auth.uid()) OR public.has_permission('integration.connectors', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY integration_credentials_write ON public.integration_credentials FOR ALL
  USING (public.has_permission('integration.security', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('integration.security', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS integration_health_checks_select ON public.integration_health_checks;
DROP POLICY IF EXISTS integration_health_checks_write ON public.integration_health_checks;
CREATE POLICY integration_health_checks_select ON public.integration_health_checks FOR SELECT
  USING (public.has_permission('integration.read', auth.uid()) OR public.has_permission('integration.monitoring', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY integration_health_checks_write ON public.integration_health_checks FOR ALL
  USING (public.has_permission('integration.monitoring', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('integration.monitoring', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS service_registry_select ON public.service_registry;
DROP POLICY IF EXISTS service_registry_write ON public.service_registry;
CREATE POLICY service_registry_select ON public.service_registry FOR SELECT
  USING (public.has_permission('integration.read', auth.uid()) OR public.has_permission('integration.monitoring', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY service_registry_write ON public.service_registry FOR ALL
  USING (public.has_permission('integration.admin', auth.uid()) OR public.has_permission('integration.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('integration.admin', auth.uid()) OR public.has_permission('integration.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS feature_flags_select ON public.feature_flags;
DROP POLICY IF EXISTS feature_flags_write ON public.feature_flags;
CREATE POLICY feature_flags_select ON public.feature_flags FOR SELECT
  USING (public.has_permission('integration.read', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY feature_flags_write ON public.feature_flags FOR ALL
  USING (public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS configuration_settings_select ON public.configuration_settings;
DROP POLICY IF EXISTS configuration_settings_write ON public.configuration_settings;
CREATE POLICY configuration_settings_select ON public.configuration_settings FOR SELECT
  USING (public.has_permission('integration.read', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY configuration_settings_write ON public.configuration_settings FOR ALL
  USING (public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS integration_reports_select ON public.integration_reports;
DROP POLICY IF EXISTS integration_reports_write ON public.integration_reports;
CREATE POLICY integration_reports_select ON public.integration_reports FOR SELECT
  USING (public.has_permission('integration.read', auth.uid()) OR public.has_permission('integration.monitoring', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY integration_reports_write ON public.integration_reports FOR ALL
  USING (public.has_permission('integration.write', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('integration.write', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS integration_activity_logs_select ON public.integration_activity_logs;
DROP POLICY IF EXISTS integration_activity_logs_write ON public.integration_activity_logs;
CREATE POLICY integration_activity_logs_select ON public.integration_activity_logs FOR SELECT
  USING (public.has_permission('integration.read', auth.uid()) OR public.has_permission('integration.monitoring', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY integration_activity_logs_write ON public.integration_activity_logs FOR ALL
  USING (public.has_permission('integration.write', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('integration.write', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS integration_notifications_select ON public.integration_notifications;
DROP POLICY IF EXISTS integration_notifications_write ON public.integration_notifications;
CREATE POLICY integration_notifications_select ON public.integration_notifications FOR SELECT
  USING (public.has_permission('integration.read', auth.uid()) OR public.has_permission('integration.monitoring', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY integration_notifications_write ON public.integration_notifications FOR ALL
  USING (public.has_permission('integration.write', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('integration.write', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS integration_ai_insights_select ON public.integration_ai_insights;
DROP POLICY IF EXISTS integration_ai_insights_write ON public.integration_ai_insights;
CREATE POLICY integration_ai_insights_select ON public.integration_ai_insights FOR SELECT
  USING (public.has_permission('integration.read', auth.uid()) OR public.has_permission('integration.ai', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY integration_ai_insights_write ON public.integration_ai_insights FOR ALL
  USING (public.has_permission('integration.ai', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('integration.ai', auth.uid()) OR public.has_permission('integration.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

COMMIT;
