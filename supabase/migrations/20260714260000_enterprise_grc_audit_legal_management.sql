-- APPLIED remotely 2026-07-15 (chunked enterprise_grc_audit_legal_p1–p3)
-- Volume 4 Part 15 — Enterprise Governance, Risk, Compliance (GRC),
-- Internal Audit & Legal Management System (GRCA)
-- Status: APPLIED remotely 2026-07-15.
--
-- Approach:
--   • Route is /dashboard/grc — NEVER collide with KYC /dashboard/compliance.
--   • NEVER recreate/drop: compliance_vault, compliance_reports, audit_logs,
--     ai_audit_logs, eoc_audit_events, legal_acceptances, policy_rules,
--     project_risk_register, meeting_records.
--   • Use free names: risk_register, corporate_policies, grc_reports,
--     board_meetings, grc_activity_logs (NOT audit_logs / compliance_reports).
--   • Seed UUIDs hex-only (d150…).
--   • Permissions: slug, name, description, module ONLY.
--   • RLS: has_permission('slug', auth.uid()) — slug FIRST.
--   • Ethics/whistleblower tables require grc.ethics / grc.investigations
--     (stricter than grc.read).
--
-- Volume 4 continues Parts 16–25. Wait for approve before Part 16.

BEGIN;

-- ---------------------------------------------------------------------------
-- Permissions
-- ---------------------------------------------------------------------------
INSERT INTO public.permissions (slug, name, description, module) VALUES
  ('grc.read', 'View GRC', 'View GRC Command Center', 'grc'),
  ('grc.write', 'Manage GRC', 'Create and edit GRC records', 'grc'),
  ('grc.risks', 'Manage Risks', 'Manage enterprise risk register', 'grc'),
  ('grc.compliance', 'Manage Compliance', 'Manage compliance frameworks and reviews', 'grc'),
  ('grc.policies', 'Manage Policies', 'Manage corporate policies', 'grc'),
  ('grc.audit', 'Internal Audit', 'Manage internal audit plans and findings', 'grc'),
  ('grc.legal', 'Legal Management', 'Manage legal cases and obligations', 'grc'),
  ('grc.ethics', 'Ethics & Whistleblower', 'Access ethics reports (sensitive)', 'grc'),
  ('grc.investigations', 'Ethics Investigations', 'Manage ethics investigations (sensitive)', 'grc'),
  ('grc.board', 'Board Governance', 'Manage board meetings and resolutions', 'grc'),
  ('grc.bcm', 'Business Continuity', 'Manage BCM plans and BIA', 'grc'),
  ('grc.approvals', 'GRC Approvals', 'Approve GRC workflows', 'grc'),
  ('grc.analytics', 'GRC Analytics', 'View GRC KPIs and analytics', 'grc'),
  ('grc.ai', 'GRC AI', 'Use GRC AI intelligence tools', 'grc'),
  ('grc.reports', 'GRC Reports', 'Generate and view GRC reports', 'grc')
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  module = EXCLUDED.module,
  updated_at = now();

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE p.slug LIKE 'grc.%'
  AND (
    r.slug IN ('super_admin', 'admin')
    OR (r.slug = 'finance' AND p.slug IN (
      'grc.read', 'grc.risks', 'grc.compliance', 'grc.audit',
      'grc.analytics', 'grc.reports', 'grc.approvals'
    ))
    OR (r.slug = 'construction_manager' AND p.slug IN (
      'grc.read', 'grc.risks', 'grc.compliance', 'grc.bcm'
    ))
    OR (r.slug = 'sales_team' AND p.slug IN (
      'grc.read', 'grc.policies'
    ))
    OR (r.slug = 'marketing' AND p.slug IN (
      'grc.read', 'grc.policies'
    ))
  )
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Governance frameworks
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.governance_frameworks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  name text NOT NULL,
  framework_type text NOT NULL DEFAULT 'corporate'
    CHECK (framework_type IN ('corporate','regulatory','iso','coso','other')),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft','active','retired')),
  version_label text,
  owner_label text,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Risk
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.risk_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  description text,
  sort_order int NOT NULL DEFAULT 100,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.risk_register (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  title text NOT NULL,
  category_id uuid REFERENCES public.risk_categories(id) ON DELETE SET NULL,
  framework_id uuid REFERENCES public.governance_frameworks(id) ON DELETE SET NULL,
  risk_type text NOT NULL DEFAULT 'operational'
    CHECK (risk_type IN ('strategic','operational','financial','compliance','legal','cyber','reputational','other')),
  severity text NOT NULL DEFAULT 'medium'
    CHECK (severity IN ('low','medium','high','critical')),
  likelihood text NOT NULL DEFAULT 'possible'
    CHECK (likelihood IN ('rare','unlikely','possible','likely','almost_certain')),
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('draft','open','mitigating','accepted','closed','transferred')),
  inherent_score numeric(6,2) DEFAULT 0,
  residual_score numeric(6,2) DEFAULT 0,
  owner_label text,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  identified_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_risk_register_status
  ON public.risk_register(status, severity);
CREATE INDEX IF NOT EXISTS idx_risk_register_category
  ON public.risk_register(category_id);

CREATE TABLE IF NOT EXISTS public.risk_assessments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  risk_id uuid NOT NULL REFERENCES public.risk_register(id) ON DELETE CASCADE,
  assessed_at timestamptz NOT NULL DEFAULT now(),
  assessor_label text,
  inherent_score numeric(6,2) DEFAULT 0,
  residual_score numeric(6,2) DEFAULT 0,
  methodology text DEFAULT 'qualitative',
  findings text,
  status text NOT NULL DEFAULT 'completed'
    CHECK (status IN ('draft','completed','superseded')),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.risk_treatments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  risk_id uuid NOT NULL REFERENCES public.risk_register(id) ON DELETE CASCADE,
  treatment_type text NOT NULL DEFAULT 'mitigate'
    CHECK (treatment_type IN ('mitigate','accept','transfer','avoid','other')),
  title text NOT NULL,
  status text NOT NULL DEFAULT 'planned'
    CHECK (status IN ('planned','in_progress','completed','cancelled')),
  owner_label text,
  due_at timestamptz,
  cost_estimate numeric(18,2) DEFAULT 0,
  currency text NOT NULL DEFAULT 'NGN',
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Compliance (NOT compliance_reports / compliance_vault)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.compliance_frameworks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  name text NOT NULL,
  regulator_label text,
  jurisdiction text DEFAULT 'NG',
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft','active','retired')),
  score_pct numeric(5,2) DEFAULT 0,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.compliance_requirements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  framework_id uuid NOT NULL REFERENCES public.compliance_frameworks(id) ON DELETE CASCADE,
  code text,
  title text NOT NULL,
  control_ref text,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','partial','met','waived','not_applicable')),
  severity text NOT NULL DEFAULT 'medium'
    CHECK (severity IN ('low','medium','high','critical')),
  owner_label text,
  due_at timestamptz,
  evidence_notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.compliance_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  framework_id uuid REFERENCES public.compliance_frameworks(id) ON DELETE SET NULL,
  requirement_id uuid REFERENCES public.compliance_requirements(id) ON DELETE SET NULL,
  review_type text NOT NULL DEFAULT 'periodic'
    CHECK (review_type IN ('periodic','ad_hoc','regulatory','self_assessment','other')),
  title text NOT NULL,
  status text NOT NULL DEFAULT 'scheduled'
    CHECK (status IN ('scheduled','in_progress','completed','cancelled')),
  reviewer_label text,
  score_pct numeric(5,2),
  reviewed_at timestamptz,
  findings text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.regulatory_calendar (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  regulator_label text,
  event_type text NOT NULL DEFAULT 'deadline'
    CHECK (event_type IN ('deadline','filing','hearing','renewal','inspection','other')),
  due_at timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'upcoming'
    CHECK (status IN ('upcoming','due','completed','overdue','cancelled')),
  jurisdiction text DEFAULT 'NG',
  owner_label text,
  related_framework_id uuid REFERENCES public.compliance_frameworks(id) ON DELETE SET NULL,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_regulatory_calendar_due
  ON public.regulatory_calendar(due_at, status);

-- ---------------------------------------------------------------------------
-- Policies (NOT policy_rules — RBAC)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.corporate_policies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  title text NOT NULL,
  policy_domain text NOT NULL DEFAULT 'corporate'
    CHECK (policy_domain IN ('corporate','hr','finance','it','hse','ethics','legal','other')),
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','active','under_review','retired')),
  owner_label text,
  effective_on date,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.policy_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  policy_id uuid NOT NULL REFERENCES public.corporate_policies(id) ON DELETE CASCADE,
  version_label text NOT NULL,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','published','superseded')),
  change_summary text,
  published_at timestamptz,
  storage_bucket text DEFAULT 'grc-documents',
  storage_path text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.policy_acknowledgements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  policy_id uuid NOT NULL REFERENCES public.corporate_policies(id) ON DELETE CASCADE,
  version_id uuid REFERENCES public.policy_versions(id) ON DELETE SET NULL,
  employee_label text NOT NULL,
  acknowledged_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'acknowledged'
    CHECK (status IN ('pending','acknowledged','declined','expired')),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Internal audit (NOT audit_logs / ai_audit_logs / eoc_audit_events)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.audit_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  title text NOT NULL,
  fiscal_year text,
  status text NOT NULL DEFAULT 'planned'
    CHECK (status IN ('draft','planned','in_progress','completed','cancelled')),
  lead_auditor_label text,
  scope_summary text,
  start_on date,
  end_on date,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.audit_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid NOT NULL REFERENCES public.audit_plans(id) ON DELETE CASCADE,
  auditor_label text NOT NULL,
  area_label text,
  status text NOT NULL DEFAULT 'assigned'
    CHECK (status IN ('assigned','in_progress','completed','cancelled')),
  due_at timestamptz,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.audit_workpapers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid NOT NULL REFERENCES public.audit_plans(id) ON DELETE CASCADE,
  assignment_id uuid REFERENCES public.audit_assignments(id) ON DELETE SET NULL,
  title text NOT NULL,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','under_review','final','archived')),
  storage_bucket text DEFAULT 'grc-documents',
  storage_path text,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.audit_findings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid REFERENCES public.audit_plans(id) ON DELETE SET NULL,
  workpaper_id uuid REFERENCES public.audit_workpapers(id) ON DELETE SET NULL,
  code text UNIQUE,
  title text NOT NULL,
  severity text NOT NULL DEFAULT 'medium'
    CHECK (severity IN ('low','medium','high','critical')),
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','remediating','closed','accepted')),
  finding_type text NOT NULL DEFAULT 'control_gap'
    CHECK (finding_type IN ('control_gap','policy_breach','process','fraud','other')),
  owner_label text,
  due_at timestamptz,
  description text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_findings_status
  ON public.audit_findings(status, severity);

CREATE TABLE IF NOT EXISTS public.corrective_actions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  finding_id uuid NOT NULL REFERENCES public.audit_findings(id) ON DELETE CASCADE,
  title text NOT NULL,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','in_progress','completed','cancelled','overdue')),
  owner_label text,
  due_at timestamptz,
  completed_at timestamptz,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Legal (NOT legal_acceptances)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.legal_cases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  title text NOT NULL,
  case_type text NOT NULL DEFAULT 'civil'
    CHECK (case_type IN ('civil','regulatory','employment','contract','ip','criminal','other')),
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('intake','open','in_progress','settled','closed','archived')),
  jurisdiction text DEFAULT 'NG',
  counsel_label text,
  opposing_party text,
  risk_level text NOT NULL DEFAULT 'medium'
    CHECK (risk_level IN ('low','medium','high','critical')),
  opened_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_legal_cases_status
  ON public.legal_cases(status, risk_level);

CREATE TABLE IF NOT EXISTS public.legal_parties (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id uuid NOT NULL REFERENCES public.legal_cases(id) ON DELETE CASCADE,
  party_role text NOT NULL DEFAULT 'counterparty'
    CHECK (party_role IN ('plaintiff','defendant','counsel','witness','regulator','counterparty','other')),
  name_label text NOT NULL,
  contact_label text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.legal_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id uuid NOT NULL REFERENCES public.legal_cases(id) ON DELETE CASCADE,
  title text NOT NULL,
  doc_type text NOT NULL DEFAULT 'pleading'
    CHECK (doc_type IN ('pleading','contract','correspondence','evidence','opinion','other')),
  storage_bucket text DEFAULT 'grc-documents',
  storage_path text,
  filed_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.legal_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id uuid NOT NULL REFERENCES public.legal_cases(id) ON DELETE CASCADE,
  event_type text NOT NULL DEFAULT 'hearing'
    CHECK (event_type IN ('hearing','filing','deadline','settlement','call','other')),
  title text NOT NULL,
  event_at timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'scheduled'
    CHECK (status IN ('scheduled','completed','adjourned','cancelled')),
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.contract_obligations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  title text NOT NULL,
  counterparty_label text,
  obligation_type text NOT NULL DEFAULT 'performance'
    CHECK (obligation_type IN ('performance','payment','notice','renewal','confidentiality','other')),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','due','completed','breached','waived','expired')),
  due_at timestamptz,
  owner_label text,
  related_case_id uuid REFERENCES public.legal_cases(id) ON DELETE SET NULL,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Ethics / whistleblower (SENSITIVE — stricter RLS)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ethics_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  -- Store metadata-only; no complainant PII in seeds
  report_category text NOT NULL DEFAULT 'other'
    CHECK (report_category IN ('fraud','harassment','conflict','safety','bribery','other')),
  status text NOT NULL DEFAULT 'intake'
    CHECK (status IN ('intake','triage','investigating','closed','referred')),
  severity text NOT NULL DEFAULT 'medium'
    CHECK (severity IN ('low','medium','high','critical')),
  channel_label text DEFAULT 'anonymous_hotline',
  received_at timestamptz NOT NULL DEFAULT now(),
  summary_redacted text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ethics_investigations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id uuid NOT NULL REFERENCES public.ethics_reports(id) ON DELETE CASCADE,
  code text UNIQUE,
  lead_investigator_label text,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','in_progress','closed','referred')),
  opened_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz,
  outcome_summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.compliance_incidents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  title text NOT NULL,
  incident_type text NOT NULL DEFAULT 'policy_breach'
    CHECK (incident_type IN ('policy_breach','regulatory','safety','data','other')),
  severity text NOT NULL DEFAULT 'medium'
    CHECK (severity IN ('low','medium','high','critical')),
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','investigating','remediating','closed')),
  reported_by text,
  reported_at timestamptz NOT NULL DEFAULT now(),
  framework_id uuid REFERENCES public.compliance_frameworks(id) ON DELETE SET NULL,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Business continuity
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.business_continuity_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  title text NOT NULL,
  plan_type text NOT NULL DEFAULT 'bcm'
    CHECK (plan_type IN ('bcm','dr','crisis','pandemic','other')),
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','active','under_review','retired')),
  owner_label text,
  rto_hours numeric(8,2),
  rpo_hours numeric(8,2),
  last_tested_at timestamptz,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.business_impact_analyses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid REFERENCES public.business_continuity_plans(id) ON DELETE SET NULL,
  process_label text NOT NULL,
  criticality text NOT NULL DEFAULT 'medium'
    CHECK (criticality IN ('low','medium','high','critical')),
  max_tolerable_downtime_hours numeric(8,2),
  financial_impact_label text,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','approved','superseded')),
  assessed_at timestamptz DEFAULT now(),
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Board (NOT meeting_records — EOC)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.board_meetings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  title text NOT NULL,
  meeting_type text NOT NULL DEFAULT 'board'
    CHECK (meeting_type IN ('board','committee','agm','egm','other')),
  status text NOT NULL DEFAULT 'scheduled'
    CHECK (status IN ('scheduled','in_progress','completed','cancelled','adjourned')),
  scheduled_at timestamptz NOT NULL,
  location_label text,
  chair_label text,
  quorum_met boolean DEFAULT false,
  agenda_summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.board_resolutions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meeting_id uuid NOT NULL REFERENCES public.board_meetings(id) ON DELETE CASCADE,
  code text UNIQUE,
  title text NOT NULL,
  status text NOT NULL DEFAULT 'proposed'
    CHECK (status IN ('proposed','passed','rejected','deferred','withdrawn')),
  resolution_text text,
  passed_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.board_votes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  resolution_id uuid NOT NULL REFERENCES public.board_resolutions(id) ON DELETE CASCADE,
  voter_label text NOT NULL,
  vote_value text NOT NULL DEFAULT 'abstain'
    CHECK (vote_value IN ('for','against','abstain')),
  voted_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- GRC reports / activity / notifications / AI
-- (grc_reports NOT compliance_reports; grc_activity_logs NOT audit_logs)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.grc_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  report_type text NOT NULL DEFAULT 'risk'
    CHECK (report_type IN ('risk','compliance','audit','legal','board','bcm','executive','other')),
  period_label text,
  summary text,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','published','archived')),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.grc_activity_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  action text NOT NULL,
  summary text NOT NULL,
  actor_label text,
  entity_type text,
  entity_id uuid,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_grc_activity_logs_occurred
  ON public.grc_activity_logs(occurred_at DESC);

CREATE TABLE IF NOT EXISTS public.grc_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  body text,
  severity text NOT NULL DEFAULT 'info'
    CHECK (severity IN ('info','warning','critical')),
  entity_type text,
  entity_id uuid,
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.grc_ai_insights (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  body text NOT NULL,
  insight_type text NOT NULL DEFAULT 'risk'
    CHECK (insight_type IN ('risk','compliance','audit','legal','ethics','board','bcm','other')),
  confidence_pct numeric(5,2),
  editable boolean NOT NULL DEFAULT true,
  disclaimer text NOT NULL DEFAULT 'AI-generated — editable / advisory',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Storage bucket
-- ---------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('grc-documents', 'grc-documents', false)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.risk_register; EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.audit_findings; EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.ethics_reports; EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.regulatory_calendar; EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.legal_cases; EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.grc_activity_logs; EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.grc_notifications; EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

-- ---------------------------------------------------------------------------
-- Seeds (hex-only UUIDs d150…)
-- ---------------------------------------------------------------------------
INSERT INTO public.governance_frameworks (
  id, code, name, framework_type, status, version_label, owner_label, summary
) VALUES
  (
    'd1500001-0000-4000-8000-000000000001',
    'GF-HDH-01', 'HD Homes Corporate Governance Framework',
    'corporate', 'active', '2026.1', 'Company Secretary',
    'Board, risk, compliance, and ethics oversight model for HD Homes Ltd.'
  ),
  (
    'd1500001-0000-4000-8000-000000000002',
    'GF-ISO-01', 'ISO 31000 Risk Management Alignment',
    'iso', 'active', '2024', 'Chief Risk Officer',
    'Enterprise risk methodology aligned to ISO 31000.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.risk_categories (id, slug, name, description, sort_order) VALUES
  ('d1500002-0000-4000-8000-000000000001', 'strategic', 'Strategic', 'Strategy and market risks', 10),
  ('d1500002-0000-4000-8000-000000000002', 'operational', 'Operational', 'Delivery and operations risks', 20),
  ('d1500002-0000-4000-8000-000000000003', 'compliance', 'Compliance', 'Regulatory and policy risks', 30),
  ('d1500002-0000-4000-8000-000000000004', 'financial', 'Financial', 'Liquidity and credit risks', 40)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.risk_register (
  id, code, title, category_id, framework_id, risk_type, severity, likelihood,
  status, inherent_score, residual_score, owner_label, summary
) VALUES
  (
    'd1500003-0000-4000-8000-000000000001',
    'RSK-2026-1501', 'Construction permit delay — Oceanview Phase 2',
    'd1500002-0000-4000-8000-000000000002',
    'd1500001-0000-4000-8000-000000000001',
    'operational', 'critical', 'likely', 'open', 20, 16,
    'Construction Manager',
    'Critical/open: permit lag may slip handover and investor milestones.'
  ),
  (
    'd1500003-0000-4000-8000-000000000002',
    'RSK-2026-1502', 'FX volatility on imported fixtures',
    'd1500002-0000-4000-8000-000000000004',
    'd1500001-0000-4000-8000-000000000002',
    'financial', 'high', 'possible', 'mitigating', 12, 8,
    'CFO',
    'NGN/USD swing pressure on specified finishing packages.'
  ),
  (
    'd1500003-0000-4000-8000-000000000003',
    'RSK-2026-1503', 'Data protection compliance gap — CRM exports',
    'd1500002-0000-4000-8000-000000000003',
    'd1500001-0000-4000-8000-000000000001',
    'compliance', 'high', 'possible', 'open', 12, 10,
    'Compliance Lead',
    'Open compliance risk on client data export controls.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.risk_assessments (
  id, risk_id, assessor_label, inherent_score, residual_score, findings, status
) VALUES
  (
    'd1500004-0000-4000-8000-000000000001',
    'd1500003-0000-4000-8000-000000000001',
    'Chief Risk Officer', 20, 16,
    'Permit queue remains elevated; escalate to MD weekly.', 'completed'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.risk_treatments (
  id, risk_id, treatment_type, title, status, owner_label, due_at, cost_estimate, notes
) VALUES
  (
    'd1500005-0000-4000-8000-000000000001',
    'd1500003-0000-4000-8000-000000000001',
    'mitigate', 'Engage planning consultant & weekly regulator dial',
    'in_progress', 'Construction Manager', now() + interval '14 days', 850000,
    'Track against RSK-2026-1501 residual score'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.compliance_frameworks (
  id, code, name, regulator_label, jurisdiction, status, score_pct, summary
) VALUES
  (
    'd1500006-0000-4000-8000-000000000001',
    'CF-NDPR-01', 'Nigeria Data Protection Regulation (NDPR)',
    'NDPC', 'NG', 'active', 78.5,
    'Compliance score stub — privacy controls and DPO oversight.'
  ),
  (
    'd1500006-0000-4000-8000-000000000002',
    'CF-CAMA-01', 'Companies and Allied Matters Act (CAMA)',
    'CAC', 'NG', 'active', 91.0,
    'Corporate filings and statutory register compliance stub.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.compliance_requirements (
  id, framework_id, code, title, control_ref, status, severity, owner_label, due_at
) VALUES
  (
    'd1500007-0000-4000-8000-000000000001',
    'd1500006-0000-4000-8000-000000000001',
    'REQ-NDPR-01', 'Maintain processing records for CRM leads',
    'Art. Processing Inventory', 'partial', 'high', 'Compliance Lead',
    now() + interval '30 days'
  ),
  (
    'd1500007-0000-4000-8000-000000000002',
    'd1500006-0000-4000-8000-000000000002',
    'REQ-CAMA-01', 'File annual returns on time',
    'CAMA s. Annual Returns', 'met', 'critical', 'Company Secretary',
    now() + interval '90 days'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.compliance_reviews (
  id, framework_id, requirement_id, review_type, title, status, reviewer_label, score_pct, reviewed_at
) VALUES
  (
    'd1500008-0000-4000-8000-000000000001',
    'd1500006-0000-4000-8000-000000000001',
    'd1500007-0000-4000-8000-000000000001',
    'self_assessment', 'Q3 NDPR control self-assessment',
    'completed', 'Compliance Lead', 76, now() - interval '5 days'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.regulatory_calendar (
  id, title, regulator_label, event_type, due_at, status, owner_label, related_framework_id, notes
) VALUES
  (
    'd1500009-0000-4000-8000-000000000001',
    'NDPR annual compliance filing',
    'NDPC', 'filing', now() + interval '21 days', 'upcoming',
    'Compliance Lead', 'd1500006-0000-4000-8000-000000000001',
    'Regulatory deadline within 3 weeks'
  ),
  (
    'd1500009-0000-4000-8000-000000000002',
    'CAC annual returns deadline',
    'CAC', 'deadline', now() + interval '60 days', 'upcoming',
    'Company Secretary', 'd1500006-0000-4000-8000-000000000002',
    'Statutory filing window'
  ),
  (
    'd1500009-0000-4000-8000-000000000003',
    'LASBCA inspection — Oceanview Phase 2',
    'LASBCA', 'inspection', now() + interval '10 days', 'due',
    'Construction Manager', NULL,
    'Site inspection slot confirmed'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.corporate_policies (
  id, code, title, policy_domain, status, owner_label, effective_on, summary
) VALUES
  (
    'd150000a-0000-4000-8000-000000000001',
    'POL-ETH-01', 'Code of Conduct & Ethics',
    'ethics', 'active', 'Chief People Officer', '2026-01-01',
    'Mandatory annual acknowledgement for all staff.'
  ),
  (
    'd150000a-0000-4000-8000-000000000002',
    'POL-IT-01', 'Information Security Acceptable Use',
    'it', 'active', 'CTO', '2025-06-01',
    'Device and data handling standards.'
  ),
  (
    'd150000a-0000-4000-8000-000000000003',
    'POL-FIN-01', 'Anti-Bribery & Gifts Policy',
    'finance', 'under_review', 'CFO', '2024-09-01',
    'Gift thresholds and third-party diligence.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.policy_versions (
  id, policy_id, version_label, status, change_summary, published_at
) VALUES
  (
    'd150000b-0000-4000-8000-000000000001',
    'd150000a-0000-4000-8000-000000000001',
    'v2026.1', 'published', 'Annual refresh — whistleblower channel update',
    '2026-01-01'::timestamptz
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.policy_acknowledgements (
  id, policy_id, version_id, employee_label, status
) VALUES
  (
    'd150000c-0000-4000-8000-000000000001',
    'd150000a-0000-4000-8000-000000000001',
    'd150000b-0000-4000-8000-000000000001',
    'Ops Lead — Lagos', 'acknowledged'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.audit_plans (
  id, code, title, fiscal_year, status, lead_auditor_label, scope_summary, start_on, end_on
) VALUES
  (
    'd150000d-0000-4000-8000-000000000001',
    'AP-2026-Q3', 'Q3 Internal Audit Plan — Ops & Procurement',
    'FY2026', 'in_progress', 'Internal Audit Lead',
    'Procurement controls, site cash handling, NDPR export controls',
    '2026-07-01', '2026-09-30'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.audit_assignments (
  id, plan_id, auditor_label, area_label, status, due_at
) VALUES
  (
    'd150000e-0000-4000-8000-000000000001',
    'd150000d-0000-4000-8000-000000000001',
    'Senior Auditor A', 'Procurement POs & vendor onboarding',
    'in_progress', now() + interval '20 days'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.audit_workpapers (
  id, plan_id, assignment_id, title, status, notes
) VALUES
  (
    'd150000f-0000-4000-8000-000000000001',
    'd150000d-0000-4000-8000-000000000001',
    'd150000e-0000-4000-8000-000000000001',
    'WP — Vendor onboarding sample 25',
    'under_review', 'Sample testing vendor KYC completeness'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.audit_findings (
  id, plan_id, workpaper_id, code, title, severity, status, finding_type, owner_label, due_at, description
) VALUES
  (
    'd1500010-0000-4000-8000-000000000001',
    'd150000d-0000-4000-8000-000000000001',
    'd150000f-0000-4000-8000-000000000001',
    'AF-2026-1501', 'Vendor KYC incomplete on 3 active vendors',
    'high', 'open', 'control_gap', 'Procurement Lead',
    now() + interval '30 days',
    'Three vendors missing tax ID / beneficial ownership attestation.'
  ),
  (
    'd1500010-0000-4000-8000-000000000002',
    'd150000d-0000-4000-8000-000000000001',
    'd150000f-0000-4000-8000-000000000001',
    'AF-2026-1502', 'PO approval threshold bypassed twice',
    'medium', 'remediating', 'policy_breach', 'Finance Controller',
    now() + interval '14 days',
    'Two POs above threshold without dual approval evidence.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.corrective_actions (
  id, finding_id, title, status, owner_label, due_at
) VALUES
  (
    'd1500011-0000-4000-8000-000000000001',
    'd1500010-0000-4000-8000-000000000001',
    'Complete vendor KYC pack for AF-2026-1501 vendors',
    'open', 'Procurement Lead', now() + interval '21 days'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.legal_cases (
  id, code, title, case_type, status, jurisdiction, counsel_label, opposing_party, risk_level, summary
) VALUES
  (
    'd1500012-0000-4000-8000-000000000001',
    'LC-2026-1501', 'Contractor variations dispute — Oceanview Phase 2',
    'contract', 'open', 'NG', 'External Counsel — Banjo & Co.',
    'SiteWorks Engineering Ltd', 'high',
    'Dispute over variation claims and retention release timing.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.legal_parties (
  id, case_id, party_role, name_label
) VALUES
  (
    'd1500013-0000-4000-8000-000000000001',
    'd1500012-0000-4000-8000-000000000001',
    'counsel', 'Banjo & Co.'
  ),
  (
    'd1500013-0000-4000-8000-000000000002',
    'd1500012-0000-4000-8000-000000000001',
    'counterparty', 'SiteWorks Engineering Ltd'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.legal_documents (
  id, case_id, title, doc_type, filed_at
) VALUES
  (
    'd1500014-0000-4000-8000-000000000001',
    'd1500012-0000-4000-8000-000000000001',
    'Statement of claim (draft)', 'pleading', now() - interval '10 days'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.legal_events (
  id, case_id, event_type, title, event_at, status, notes
) VALUES
  (
    'd1500015-0000-4000-8000-000000000001',
    'd1500012-0000-4000-8000-000000000001',
    'hearing', 'Pre-action mediation session',
    now() + interval '18 days', 'scheduled', 'Lagos mediation centre'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.contract_obligations (
  id, code, title, counterparty_label, obligation_type, status, due_at, owner_label, related_case_id
) VALUES
  (
    'd1500016-0000-4000-8000-000000000001',
    'COB-2026-1501', 'Retention release notice window',
    'SiteWorks Engineering Ltd', 'notice', 'due',
    now() + interval '7 days', 'Legal Counsel',
    'd1500012-0000-4000-8000-000000000001'
  )
ON CONFLICT (id) DO NOTHING;

-- Ethics report: metadata-only (no complainant PII)
INSERT INTO public.ethics_reports (
  id, code, report_category, status, severity, channel_label, summary_redacted
) VALUES
  (
    'd1500017-0000-4000-8000-000000000001',
    'ETH-2026-1501', 'conflict', 'triage', 'medium', 'anonymous_hotline',
    'Anonymous tip: alleged undeclared conflict on vendor selection (metadata only).'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ethics_investigations (
  id, report_id, code, lead_investigator_label, status, outcome_summary
) VALUES
  (
    'd1500018-0000-4000-8000-000000000001',
    'd1500017-0000-4000-8000-000000000001',
    'INV-2026-1501', 'Ethics Officer', 'open',
    'Preliminary triage — access restricted to ethics/investigations roles.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.compliance_incidents (
  id, code, title, incident_type, severity, status, reported_by, framework_id, summary
) VALUES
  (
    'd1500019-0000-4000-8000-000000000001',
    'CI-2026-1501', 'CRM lead export without approval trail',
    'data', 'high', 'investigating', 'Compliance Lead',
    'd1500006-0000-4000-8000-000000000001',
    'Linked to RSK-2026-1503 — export control gap.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.business_continuity_plans (
  id, code, title, plan_type, status, owner_label, rto_hours, rpo_hours, last_tested_at, summary
) VALUES
  (
    'd150001a-0000-4000-8000-000000000001',
    'BCP-HQ-01', 'HQ Business Continuity Plan',
    'bcm', 'active', 'COO', 24, 4, now() - interval '90 days',
    'Primary BCM for Lagos HQ and critical SaaS failover.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.business_impact_analyses (
  id, plan_id, process_label, criticality, max_tolerable_downtime_hours, financial_impact_label, status
) VALUES
  (
    'd150001b-0000-4000-8000-000000000001',
    'd150001a-0000-4000-8000-000000000001',
    'Payment processing & receipting',
    'critical', 8, 'High — cashflow delay', 'approved'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.board_meetings (
  id, code, title, meeting_type, status, scheduled_at, location_label, chair_label, quorum_met, agenda_summary
) VALUES
  (
    'd150001c-0000-4000-8000-000000000001',
    'BM-2026-Q3', 'Board of Directors — Q3 2026',
    'board', 'scheduled', now() + interval '28 days',
    'Victoria Island Boardroom', 'Board Chair', false,
    'Risk appetite, Oceanview dispute, BCM refresh'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.board_resolutions (
  id, meeting_id, code, title, status, resolution_text
) VALUES
  (
    'd150001d-0000-4000-8000-000000000001',
    'd150001c-0000-4000-8000-000000000001',
    'BR-2026-1501', 'Approve Q3 risk appetite statement',
    'proposed', 'Board to approve residual risk tolerance for construction and FX.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.board_votes (
  id, resolution_id, voter_label, vote_value
) VALUES
  (
    'd150001e-0000-4000-8000-000000000001',
    'd150001d-0000-4000-8000-000000000001',
    'Director A', 'abstain'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.grc_reports (id, title, report_type, period_label, summary, status) VALUES
  (
    'd150001f-0000-4000-8000-000000000001',
    'Enterprise Risk & Compliance Snapshot',
    'executive', 'Jul 2026',
    '3 register risks (1 critical open); NDPR score 78.5%; 2 open audit findings.',
    'published'
  ),
  (
    'd150001f-0000-4000-8000-000000000002',
    'Internal Audit Q3 Progress',
    'audit', 'Q3 2026',
    'AP-2026-Q3 in progress — vendor KYC findings open.',
    'draft'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.grc_activity_logs (id, action, summary, actor_label, entity_type, entity_id, occurred_at) VALUES
  (
    'd1500020-0000-4000-8000-000000000001', 'risk_opened',
    'RSK-2026-1501 opened as critical/open',
    'Chief Risk Officer', 'risk_register', 'd1500003-0000-4000-8000-000000000001',
    now() - interval '14 days'
  ),
  (
    'd1500020-0000-4000-8000-000000000002', 'finding_logged',
    'AF-2026-1501 vendor KYC finding logged',
    'Internal Audit Lead', 'audit_finding', 'd1500010-0000-4000-8000-000000000001',
    now() - interval '3 days'
  ),
  (
    'd1500020-0000-4000-8000-000000000003', 'policy_published',
    'POL-ETH-01 v2026.1 published',
    'Company Secretary', 'corporate_policy', 'd150000a-0000-4000-8000-000000000001',
    now() - interval '30 days'
  ),
  (
    'd1500020-0000-4000-8000-000000000004', 'ethics_intake',
    'ETH-2026-1501 metadata-only intake recorded',
    'Ethics Officer', 'ethics_report', 'd1500017-0000-4000-8000-000000000001',
    now() - interval '2 days'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.grc_notifications (id, title, body, severity, entity_type, entity_id) VALUES
  (
    'd1500021-0000-4000-8000-000000000001',
    'Critical risk open — permit delay',
    'RSK-2026-1501 remains critical/open',
    'critical', 'risk_register', 'd1500003-0000-4000-8000-000000000001'
  ),
  (
    'd1500021-0000-4000-8000-000000000002',
    'Regulatory deadline approaching',
    'NDPR annual filing due within 21 days',
    'warning', 'regulatory_calendar', 'd1500009-0000-4000-8000-000000000001'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.grc_ai_insights (
  id, title, body, insight_type, confidence_pct, editable, disclaimer
) VALUES
  (
    'd1500022-0000-4000-8000-000000000001',
    'Critical risk cluster — construction regulatory path',
    'RSK-2026-1501 + LASBCA inspection window suggest elevating MD risk brief this week.',
    'risk', 88, true, 'AI-generated — editable / advisory'
  ),
  (
    'd1500022-0000-4000-8000-000000000002',
    'Compliance score watch — NDPR vs CRM exports',
    'NDPR score stub 78.5% with open CRM export incident; prioritize REQ-NDPR-01 evidence.',
    'compliance', 82, true, 'AI-generated — editable / advisory'
  ),
  (
    'd1500022-0000-4000-8000-000000000003',
    'Audit remediation overdue risk',
    'AF-2026-1501/1502 open concurrent with LC-2026-1501 — align legal & audit closures.',
    'audit', 79, true, 'AI-generated — editable / advisory'
  )
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.governance_frameworks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.risk_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.risk_register ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.risk_assessments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.risk_treatments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.compliance_frameworks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.compliance_requirements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.compliance_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.regulatory_calendar ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.corporate_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.policy_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.policy_acknowledgements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_workpapers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_findings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.corrective_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.legal_cases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.legal_parties ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.legal_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.legal_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contract_obligations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ethics_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ethics_investigations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.compliance_incidents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.business_continuity_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.business_impact_analyses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.board_meetings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.board_resolutions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.board_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grc_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grc_activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grc_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grc_ai_insights ENABLE ROW LEVEL SECURITY;

-- Helper: slug FIRST in has_permission

DROP POLICY IF EXISTS governance_frameworks_select ON public.governance_frameworks;
DROP POLICY IF EXISTS governance_frameworks_write ON public.governance_frameworks;
CREATE POLICY governance_frameworks_select ON public.governance_frameworks FOR SELECT
  USING (public.has_permission('grc.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY governance_frameworks_write ON public.governance_frameworks FOR ALL
  USING (public.has_permission('grc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('grc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS risk_categories_select ON public.risk_categories;
DROP POLICY IF EXISTS risk_categories_write ON public.risk_categories;
CREATE POLICY risk_categories_select ON public.risk_categories FOR SELECT
  USING (public.has_permission('grc.read', auth.uid()) OR public.has_permission('grc.risks', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY risk_categories_write ON public.risk_categories FOR ALL
  USING (public.has_permission('grc.risks', auth.uid()) OR public.has_permission('grc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('grc.risks', auth.uid()) OR public.has_permission('grc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS risk_register_select ON public.risk_register;
DROP POLICY IF EXISTS risk_register_write ON public.risk_register;
CREATE POLICY risk_register_select ON public.risk_register FOR SELECT
  USING (public.has_permission('grc.read', auth.uid()) OR public.has_permission('grc.risks', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY risk_register_write ON public.risk_register FOR ALL
  USING (public.has_permission('grc.risks', auth.uid()) OR public.has_permission('grc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('grc.risks', auth.uid()) OR public.has_permission('grc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS risk_assessments_select ON public.risk_assessments;
DROP POLICY IF EXISTS risk_assessments_write ON public.risk_assessments;
CREATE POLICY risk_assessments_select ON public.risk_assessments FOR SELECT
  USING (public.has_permission('grc.read', auth.uid()) OR public.has_permission('grc.risks', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY risk_assessments_write ON public.risk_assessments FOR ALL
  USING (public.has_permission('grc.risks', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('grc.risks', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS risk_treatments_select ON public.risk_treatments;
DROP POLICY IF EXISTS risk_treatments_write ON public.risk_treatments;
CREATE POLICY risk_treatments_select ON public.risk_treatments FOR SELECT
  USING (public.has_permission('grc.read', auth.uid()) OR public.has_permission('grc.risks', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY risk_treatments_write ON public.risk_treatments FOR ALL
  USING (public.has_permission('grc.risks', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('grc.risks', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS compliance_frameworks_select ON public.compliance_frameworks;
DROP POLICY IF EXISTS compliance_frameworks_write ON public.compliance_frameworks;
CREATE POLICY compliance_frameworks_select ON public.compliance_frameworks FOR SELECT
  USING (public.has_permission('grc.read', auth.uid()) OR public.has_permission('grc.compliance', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY compliance_frameworks_write ON public.compliance_frameworks FOR ALL
  USING (public.has_permission('grc.compliance', auth.uid()) OR public.has_permission('grc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('grc.compliance', auth.uid()) OR public.has_permission('grc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS compliance_requirements_select ON public.compliance_requirements;
DROP POLICY IF EXISTS compliance_requirements_write ON public.compliance_requirements;
CREATE POLICY compliance_requirements_select ON public.compliance_requirements FOR SELECT
  USING (public.has_permission('grc.read', auth.uid()) OR public.has_permission('grc.compliance', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY compliance_requirements_write ON public.compliance_requirements FOR ALL
  USING (public.has_permission('grc.compliance', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('grc.compliance', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS compliance_reviews_select ON public.compliance_reviews;
DROP POLICY IF EXISTS compliance_reviews_write ON public.compliance_reviews;
CREATE POLICY compliance_reviews_select ON public.compliance_reviews FOR SELECT
  USING (public.has_permission('grc.read', auth.uid()) OR public.has_permission('grc.compliance', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY compliance_reviews_write ON public.compliance_reviews FOR ALL
  USING (public.has_permission('grc.compliance', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('grc.compliance', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS regulatory_calendar_select ON public.regulatory_calendar;
DROP POLICY IF EXISTS regulatory_calendar_write ON public.regulatory_calendar;
CREATE POLICY regulatory_calendar_select ON public.regulatory_calendar FOR SELECT
  USING (public.has_permission('grc.read', auth.uid()) OR public.has_permission('grc.compliance', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY regulatory_calendar_write ON public.regulatory_calendar FOR ALL
  USING (public.has_permission('grc.compliance', auth.uid()) OR public.has_permission('grc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('grc.compliance', auth.uid()) OR public.has_permission('grc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS corporate_policies_select ON public.corporate_policies;
DROP POLICY IF EXISTS corporate_policies_write ON public.corporate_policies;
CREATE POLICY corporate_policies_select ON public.corporate_policies FOR SELECT
  USING (public.has_permission('grc.read', auth.uid()) OR public.has_permission('grc.policies', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY corporate_policies_write ON public.corporate_policies FOR ALL
  USING (public.has_permission('grc.policies', auth.uid()) OR public.has_permission('grc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('grc.policies', auth.uid()) OR public.has_permission('grc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS policy_versions_select ON public.policy_versions;
DROP POLICY IF EXISTS policy_versions_write ON public.policy_versions;
CREATE POLICY policy_versions_select ON public.policy_versions FOR SELECT
  USING (public.has_permission('grc.read', auth.uid()) OR public.has_permission('grc.policies', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY policy_versions_write ON public.policy_versions FOR ALL
  USING (public.has_permission('grc.policies', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('grc.policies', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS policy_acknowledgements_select ON public.policy_acknowledgements;
DROP POLICY IF EXISTS policy_acknowledgements_write ON public.policy_acknowledgements;
CREATE POLICY policy_acknowledgements_select ON public.policy_acknowledgements FOR SELECT
  USING (public.has_permission('grc.read', auth.uid()) OR public.has_permission('grc.policies', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY policy_acknowledgements_write ON public.policy_acknowledgements FOR ALL
  USING (public.has_permission('grc.policies', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('grc.policies', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS audit_plans_select ON public.audit_plans;
DROP POLICY IF EXISTS audit_plans_write ON public.audit_plans;
CREATE POLICY audit_plans_select ON public.audit_plans FOR SELECT
  USING (public.has_permission('grc.read', auth.uid()) OR public.has_permission('grc.audit', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY audit_plans_write ON public.audit_plans FOR ALL
  USING (public.has_permission('grc.audit', auth.uid()) OR public.has_permission('grc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('grc.audit', auth.uid()) OR public.has_permission('grc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS audit_assignments_select ON public.audit_assignments;
DROP POLICY IF EXISTS audit_assignments_write ON public.audit_assignments;
CREATE POLICY audit_assignments_select ON public.audit_assignments FOR SELECT
  USING (public.has_permission('grc.read', auth.uid()) OR public.has_permission('grc.audit', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY audit_assignments_write ON public.audit_assignments FOR ALL
  USING (public.has_permission('grc.audit', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('grc.audit', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS audit_workpapers_select ON public.audit_workpapers;
DROP POLICY IF EXISTS audit_workpapers_write ON public.audit_workpapers;
CREATE POLICY audit_workpapers_select ON public.audit_workpapers FOR SELECT
  USING (public.has_permission('grc.read', auth.uid()) OR public.has_permission('grc.audit', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY audit_workpapers_write ON public.audit_workpapers FOR ALL
  USING (public.has_permission('grc.audit', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('grc.audit', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS audit_findings_select ON public.audit_findings;
DROP POLICY IF EXISTS audit_findings_write ON public.audit_findings;
CREATE POLICY audit_findings_select ON public.audit_findings FOR SELECT
  USING (public.has_permission('grc.read', auth.uid()) OR public.has_permission('grc.audit', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY audit_findings_write ON public.audit_findings FOR ALL
  USING (public.has_permission('grc.audit', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('grc.audit', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS corrective_actions_select ON public.corrective_actions;
DROP POLICY IF EXISTS corrective_actions_write ON public.corrective_actions;
CREATE POLICY corrective_actions_select ON public.corrective_actions FOR SELECT
  USING (public.has_permission('grc.read', auth.uid()) OR public.has_permission('grc.audit', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY corrective_actions_write ON public.corrective_actions FOR ALL
  USING (public.has_permission('grc.audit', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('grc.audit', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS legal_cases_select ON public.legal_cases;
DROP POLICY IF EXISTS legal_cases_write ON public.legal_cases;
CREATE POLICY legal_cases_select ON public.legal_cases FOR SELECT
  USING (public.has_permission('grc.read', auth.uid()) OR public.has_permission('grc.legal', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY legal_cases_write ON public.legal_cases FOR ALL
  USING (public.has_permission('grc.legal', auth.uid()) OR public.has_permission('grc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('grc.legal', auth.uid()) OR public.has_permission('grc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS legal_parties_select ON public.legal_parties;
DROP POLICY IF EXISTS legal_parties_write ON public.legal_parties;
CREATE POLICY legal_parties_select ON public.legal_parties FOR SELECT
  USING (public.has_permission('grc.read', auth.uid()) OR public.has_permission('grc.legal', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY legal_parties_write ON public.legal_parties FOR ALL
  USING (public.has_permission('grc.legal', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('grc.legal', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS legal_documents_select ON public.legal_documents;
DROP POLICY IF EXISTS legal_documents_write ON public.legal_documents;
CREATE POLICY legal_documents_select ON public.legal_documents FOR SELECT
  USING (public.has_permission('grc.read', auth.uid()) OR public.has_permission('grc.legal', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY legal_documents_write ON public.legal_documents FOR ALL
  USING (public.has_permission('grc.legal', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('grc.legal', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS legal_events_select ON public.legal_events;
DROP POLICY IF EXISTS legal_events_write ON public.legal_events;
CREATE POLICY legal_events_select ON public.legal_events FOR SELECT
  USING (public.has_permission('grc.read', auth.uid()) OR public.has_permission('grc.legal', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY legal_events_write ON public.legal_events FOR ALL
  USING (public.has_permission('grc.legal', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('grc.legal', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS contract_obligations_select ON public.contract_obligations;
DROP POLICY IF EXISTS contract_obligations_write ON public.contract_obligations;
CREATE POLICY contract_obligations_select ON public.contract_obligations FOR SELECT
  USING (public.has_permission('grc.read', auth.uid()) OR public.has_permission('grc.legal', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY contract_obligations_write ON public.contract_obligations FOR ALL
  USING (public.has_permission('grc.legal', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('grc.legal', auth.uid()) OR public.has_role('super_admin', auth.uid()));

-- Ethics / investigations: STRICTER — grc.ethics / grc.investigations only (not grc.read)
DROP POLICY IF EXISTS ethics_reports_select ON public.ethics_reports;
DROP POLICY IF EXISTS ethics_reports_write ON public.ethics_reports;
CREATE POLICY ethics_reports_select ON public.ethics_reports FOR SELECT
  USING (public.has_permission('grc.ethics', auth.uid()) OR public.has_permission('grc.investigations', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ethics_reports_write ON public.ethics_reports FOR ALL
  USING (public.has_permission('grc.ethics', auth.uid()) OR public.has_permission('grc.investigations', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('grc.ethics', auth.uid()) OR public.has_permission('grc.investigations', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ethics_investigations_select ON public.ethics_investigations;
DROP POLICY IF EXISTS ethics_investigations_write ON public.ethics_investigations;
CREATE POLICY ethics_investigations_select ON public.ethics_investigations FOR SELECT
  USING (public.has_permission('grc.investigations', auth.uid()) OR public.has_permission('grc.ethics', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ethics_investigations_write ON public.ethics_investigations FOR ALL
  USING (public.has_permission('grc.investigations', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('grc.investigations', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS compliance_incidents_select ON public.compliance_incidents;
DROP POLICY IF EXISTS compliance_incidents_write ON public.compliance_incidents;
CREATE POLICY compliance_incidents_select ON public.compliance_incidents FOR SELECT
  USING (public.has_permission('grc.read', auth.uid()) OR public.has_permission('grc.compliance', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY compliance_incidents_write ON public.compliance_incidents FOR ALL
  USING (public.has_permission('grc.compliance', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('grc.compliance', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS business_continuity_plans_select ON public.business_continuity_plans;
DROP POLICY IF EXISTS business_continuity_plans_write ON public.business_continuity_plans;
CREATE POLICY business_continuity_plans_select ON public.business_continuity_plans FOR SELECT
  USING (public.has_permission('grc.read', auth.uid()) OR public.has_permission('grc.bcm', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY business_continuity_plans_write ON public.business_continuity_plans FOR ALL
  USING (public.has_permission('grc.bcm', auth.uid()) OR public.has_permission('grc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('grc.bcm', auth.uid()) OR public.has_permission('grc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS business_impact_analyses_select ON public.business_impact_analyses;
DROP POLICY IF EXISTS business_impact_analyses_write ON public.business_impact_analyses;
CREATE POLICY business_impact_analyses_select ON public.business_impact_analyses FOR SELECT
  USING (public.has_permission('grc.read', auth.uid()) OR public.has_permission('grc.bcm', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY business_impact_analyses_write ON public.business_impact_analyses FOR ALL
  USING (public.has_permission('grc.bcm', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('grc.bcm', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS board_meetings_select ON public.board_meetings;
DROP POLICY IF EXISTS board_meetings_write ON public.board_meetings;
CREATE POLICY board_meetings_select ON public.board_meetings FOR SELECT
  USING (public.has_permission('grc.read', auth.uid()) OR public.has_permission('grc.board', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY board_meetings_write ON public.board_meetings FOR ALL
  USING (public.has_permission('grc.board', auth.uid()) OR public.has_permission('grc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('grc.board', auth.uid()) OR public.has_permission('grc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS board_resolutions_select ON public.board_resolutions;
DROP POLICY IF EXISTS board_resolutions_write ON public.board_resolutions;
CREATE POLICY board_resolutions_select ON public.board_resolutions FOR SELECT
  USING (public.has_permission('grc.read', auth.uid()) OR public.has_permission('grc.board', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY board_resolutions_write ON public.board_resolutions FOR ALL
  USING (public.has_permission('grc.board', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('grc.board', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS board_votes_select ON public.board_votes;
DROP POLICY IF EXISTS board_votes_write ON public.board_votes;
CREATE POLICY board_votes_select ON public.board_votes FOR SELECT
  USING (public.has_permission('grc.read', auth.uid()) OR public.has_permission('grc.board', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY board_votes_write ON public.board_votes FOR ALL
  USING (public.has_permission('grc.board', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('grc.board', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS grc_reports_select ON public.grc_reports;
DROP POLICY IF EXISTS grc_reports_write ON public.grc_reports;
CREATE POLICY grc_reports_select ON public.grc_reports FOR SELECT
  USING (public.has_permission('grc.read', auth.uid()) OR public.has_permission('grc.reports', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY grc_reports_write ON public.grc_reports FOR ALL
  USING (public.has_permission('grc.reports', auth.uid()) OR public.has_permission('grc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('grc.reports', auth.uid()) OR public.has_permission('grc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS grc_activity_logs_select ON public.grc_activity_logs;
DROP POLICY IF EXISTS grc_activity_logs_write ON public.grc_activity_logs;
CREATE POLICY grc_activity_logs_select ON public.grc_activity_logs FOR SELECT
  USING (public.has_permission('grc.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY grc_activity_logs_write ON public.grc_activity_logs FOR ALL
  USING (public.has_permission('grc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('grc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS grc_notifications_select ON public.grc_notifications;
DROP POLICY IF EXISTS grc_notifications_write ON public.grc_notifications;
CREATE POLICY grc_notifications_select ON public.grc_notifications FOR SELECT
  USING (public.has_permission('grc.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY grc_notifications_write ON public.grc_notifications FOR ALL
  USING (public.has_permission('grc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('grc.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS grc_ai_insights_select ON public.grc_ai_insights;
DROP POLICY IF EXISTS grc_ai_insights_write ON public.grc_ai_insights;
CREATE POLICY grc_ai_insights_select ON public.grc_ai_insights FOR SELECT
  USING (public.has_permission('grc.read', auth.uid()) OR public.has_permission('grc.ai', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY grc_ai_insights_write ON public.grc_ai_insights FOR ALL
  USING (public.has_permission('grc.ai', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('grc.ai', auth.uid()) OR public.has_role('super_admin', auth.uid()));

COMMIT;
