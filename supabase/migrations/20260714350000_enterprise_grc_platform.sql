-- APPLIED remotely (2026-07-21) — chunked egrc_p1 / p2 / p3
-- Volume 4 Part 24 — Enterprise Governance, Risk, Compliance, Internal Audit
-- & Business Continuity Platform (EGRC)
-- ENRICHES Part 15 GRCA tables in place. Never recreates them.
-- Does NOT recreate risk_register, corporate_policies, audit_plans, audit_findings,
-- corrective_actions, board_meetings, board_resolutions, board_votes,
-- business_continuity_plans, business_impact_analyses, grc_activity_logs,
-- grc_notifications, grc_ai_insights, resilience_assessments (ESP).
-- Does NOT replace /dashboard/grc (GrcCommandCenterPage) or /dashboard/compliance (KYC).
-- Permissions use (slug, name, description, module); has_permission slug is FIRST.
-- Seed UUIDs are hex-only f240….

BEGIN;

INSERT INTO public.permissions (slug, name, description, module) VALUES
 ('egrc.read','View EGRC','View Enterprise GRC Command Center','egrc'),
 ('egrc.write','Manage EGRC','Create and update EGRC records','egrc'),
 ('egrc.governance','Governance','Manage governance structures, committees, and decisions','egrc'),
 ('egrc.risks','Enterprise Risks','View and manage enterprise risk register surfaces','egrc'),
 ('egrc.compliance','Compliance','Manage compliance requirements and reviews','egrc'),
 ('egrc.policies','Policies','Manage policy acknowledgement and publication surfaces','egrc'),
 ('egrc.controls','Controls','Manage internal controls and assessments','egrc'),
 ('egrc.audit','Internal Audit','Manage audit findings and engagements surfaces','egrc'),
 ('egrc.remediation','Remediation','Manage corrective and preventive actions','egrc'),
 ('egrc.bcm','Business Continuity','Manage BCM plans and continuity tests','egrc'),
 ('egrc.resilience','Operational Resilience','View resilience readiness surfaces','egrc'),
 ('egrc.obligations','Regulatory Obligations','Manage regulatory obligation tracker','egrc'),
 ('egrc.ai','EGRC AI','View EGRC AI governance insights','egrc'),
 ('egrc.admin','EGRC Administration','Administer the Enterprise GRC Platform','egrc')
ON CONFLICT (slug) DO UPDATE SET
 name=EXCLUDED.name, description=EXCLUDED.description, module=EXCLUDED.module, updated_at=now();

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM public.roles r CROSS JOIN public.permissions p
WHERE p.slug LIKE 'egrc.%' AND (
 r.slug IN ('super_admin','admin')
 OR (r.slug='finance' AND p.slug IN (
  'egrc.read','egrc.risks','egrc.compliance','egrc.controls','egrc.audit','egrc.remediation','egrc.ai'
 ))
 OR (r.slug='construction_manager' AND p.slug IN (
  'egrc.read','egrc.risks','egrc.bcm','egrc.resilience','egrc.remediation'
 ))
 OR (r.slug='sales_team' AND p.slug IN ('egrc.read','egrc.policies'))
 OR (r.slug='marketing' AND p.slug IN ('egrc.read','egrc.policies','egrc.compliance'))
) ON CONFLICT DO NOTHING;

-- Part 15 GRCA: enrich only — never DROP/recreate.
ALTER TABLE public.risk_register
 ADD COLUMN IF NOT EXISTS egrc_surface text,
 ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb;
ALTER TABLE public.corporate_policies
 ADD COLUMN IF NOT EXISTS egrc_surface text,
 ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb;
ALTER TABLE public.audit_findings
 ADD COLUMN IF NOT EXISTS egrc_surface text,
 ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb;
ALTER TABLE public.corrective_actions
 ADD COLUMN IF NOT EXISTS egrc_surface text,
 ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb;
ALTER TABLE public.business_continuity_plans
 ADD COLUMN IF NOT EXISTS egrc_surface text,
 ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb;
ALTER TABLE public.compliance_requirements
 ADD COLUMN IF NOT EXISTS egrc_surface text,
 ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb;
ALTER TABLE public.grc_reports
 ADD COLUMN IF NOT EXISTS egrc_surface text,
 ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb;

CREATE TABLE IF NOT EXISTS public.governance_structures (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'structure', structure_type text NOT NULL DEFAULT 'board',
 status text NOT NULL DEFAULT 'active', severity text NOT NULL DEFAULT 'info',
 owner_label text, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.governance_committees (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 structure_id uuid REFERENCES public.governance_structures(id) ON DELETE SET NULL,
 code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'committee', status text NOT NULL DEFAULT 'active',
 severity text NOT NULL DEFAULT 'info', chair_label text, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.governance_meetings (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 committee_id uuid REFERENCES public.governance_committees(id) ON DELETE SET NULL,
 code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'meeting', status text NOT NULL DEFAULT 'scheduled',
 severity text NOT NULL DEFAULT 'info', scheduled_at timestamptz, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.governance_decisions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 meeting_id uuid REFERENCES public.governance_meetings(id) ON DELETE SET NULL,
 code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'decision', status text NOT NULL DEFAULT 'recorded',
 severity text NOT NULL DEFAULT 'info', decided_at timestamptz, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.internal_controls (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'control', control_type text NOT NULL DEFAULT 'preventive',
 status text NOT NULL DEFAULT 'active', severity text NOT NULL DEFAULT 'info',
 effectiveness text DEFAULT 'effective', owner_label text, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.control_assessments (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 control_id uuid REFERENCES public.internal_controls(id) ON DELETE CASCADE,
 title text NOT NULL, category text NOT NULL DEFAULT 'assessment',
 status text NOT NULL DEFAULT 'completed', severity text NOT NULL DEFAULT 'info',
 effectiveness_rating text, tested_at timestamptz, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.compliance_evidence (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'evidence', status text NOT NULL DEFAULT 'filed',
 severity text NOT NULL DEFAULT 'info', requirement_label text, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.preventive_actions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'preventive', status text NOT NULL DEFAULT 'open',
 severity text NOT NULL DEFAULT 'info', owner_label text, due_at timestamptz, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.bcm_continuity_tests (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'exercise', status text NOT NULL DEFAULT 'planned',
 severity text NOT NULL DEFAULT 'info', test_type text DEFAULT 'tabletop',
 result_label text, tested_at timestamptz, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.regulatory_obligations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'regulation', status text NOT NULL DEFAULT 'compliant',
 severity text NOT NULL DEFAULT 'info', jurisdiction text, owner_label text,
 effective_at timestamptz, review_at timestamptz, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.operational_resilience_scores (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'resilience', metric_key text NOT NULL,
 status text NOT NULL DEFAULT 'ok', severity text NOT NULL DEFAULT 'info',
 score_value numeric, maturity_label text, summary text,
 recorded_at timestamptz NOT NULL DEFAULT now(),
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.egrc_activity_logs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), action text NOT NULL, title text NOT NULL,
 category text NOT NULL DEFAULT 'egrc', actor_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
 actor_label text, entity_type text, entity_id uuid, severity text NOT NULL DEFAULT 'info',
 status text NOT NULL DEFAULT 'recorded', summary text, metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 occurred_at timestamptz NOT NULL DEFAULT now(),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.egrc_notifications (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), recipient_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
 title text NOT NULL, category text NOT NULL DEFAULT 'egrc', channel text NOT NULL DEFAULT 'in_app',
 severity text NOT NULL DEFAULT 'info', status text NOT NULL DEFAULT 'unread', body text,
 read_at timestamptz, metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.egrc_ai_insights (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 body text NOT NULL, category text NOT NULL DEFAULT 'egrc', insight_type text NOT NULL,
 confidence_pct numeric(5,2), status text NOT NULL DEFAULT 'active', editable boolean NOT NULL DEFAULT true,
 disclaimer text NOT NULL DEFAULT 'AI-generated — editable / advisory',
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_governance_decisions_status ON public.governance_decisions(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_internal_controls_status ON public.internal_controls(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_preventive_actions_status ON public.preventive_actions(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_bcm_continuity_tests_status ON public.bcm_continuity_tests(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_regulatory_obligations_status ON public.regulatory_obligations(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_operational_resilience_key ON public.operational_resilience_scores(metric_key, recorded_at DESC);

INSERT INTO storage.buckets (id,name,public) VALUES ('egrc-artifacts','egrc-artifacts',false)
ON CONFLICT (id) DO NOTHING;

DO $$ BEGIN
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.governance_decisions; EXCEPTION WHEN duplicate_object THEN NULL; END;
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.internal_controls; EXCEPTION WHEN duplicate_object THEN NULL; END;
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.preventive_actions; EXCEPTION WHEN duplicate_object THEN NULL; END;
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.bcm_continuity_tests; EXCEPTION WHEN duplicate_object THEN NULL; END;
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.regulatory_obligations; EXCEPTION WHEN duplicate_object THEN NULL; END;
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.egrc_notifications; EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

DO $$
DECLARE t text;
BEGIN
 FOREACH t IN ARRAY ARRAY[
  'governance_structures','governance_committees','governance_meetings','governance_decisions',
  'internal_controls','control_assessments','compliance_evidence','preventive_actions',
  'bcm_continuity_tests','regulatory_obligations','operational_resilience_scores',
  'egrc_activity_logs','egrc_notifications','egrc_ai_insights'
 ] LOOP
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
  EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_select', t);
  EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_write', t);
  EXECUTE format(
   'CREATE POLICY %I ON public.%I FOR SELECT USING (public.has_permission(''egrc.read'', auth.uid()) OR public.has_permission(''egrc.admin'', auth.uid()) OR public.has_role(''super_admin'', auth.uid()))',
   t || '_select', t
  );
  EXECUTE format(
   'CREATE POLICY %I ON public.%I FOR ALL USING (public.has_permission(''egrc.write'', auth.uid()) OR public.has_permission(''egrc.admin'', auth.uid()) OR public.has_role(''super_admin'', auth.uid())) WITH CHECK (public.has_permission(''egrc.write'', auth.uid()) OR public.has_permission(''egrc.admin'', auth.uid()) OR public.has_role(''super_admin'', auth.uid()))',
   t || '_write', t
  );
 END LOOP;
END $$;

GRANT SELECT, INSERT, UPDATE, DELETE ON
 public.governance_structures, public.governance_committees, public.governance_meetings, public.governance_decisions,
 public.internal_controls, public.control_assessments, public.compliance_evidence, public.preventive_actions,
 public.bcm_continuity_tests, public.regulatory_obligations, public.operational_resilience_scores,
 public.egrc_activity_logs, public.egrc_notifications, public.egrc_ai_insights
TO authenticated;

-- Phase 1 demo seeds (hex-only f240…).
INSERT INTO public.governance_structures (id,code,title,structure_type,status,owner_label,summary) VALUES
 ('f2400001-0000-4000-8000-000000000010','GS-BOARD','Board of Directors','board','active','Company Secretary','Ultimate governance oversight body')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.governance_committees (id,structure_id,code,title,status,chair_label,summary) VALUES
 ('f2400001-0000-4000-8000-000000000001','f2400001-0000-4000-8000-000000000010','GC-ARC','Audit & Risk Committee','active','Independent Director','Quarterly risk and audit oversight'),
 ('f2400001-0000-4000-8000-000000000002','f2400001-0000-4000-8000-000000000010','GC-EXCO','Executive Management Committee','active','CEO','Weekly operational governance')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.governance_meetings (id,committee_id,code,title,status,scheduled_at,summary) VALUES
 ('f2400001-0000-4000-8000-000000000011','f2400001-0000-4000-8000-000000000001','GM-ARC-Q3','ARC Q3 governance review','scheduled',now() + interval '14 days','Risk heat map + audit findings')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.governance_decisions (id,meeting_id,code,title,status,severity,summary) VALUES
 ('f2400001-0000-4000-8000-000000000012','f2400001-0000-4000-8000-000000000011','GD-RISK-ACCEPT','Accept residual construction risk Lekki P2','recorded','medium','Mitigation plan approved · residual medium')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.internal_controls (id,code,title,control_type,status,effectiveness,owner_label,summary) VALUES
 ('f2400002-0000-4000-8000-000000000001','IC-ESCROW','Escrow dual-authorization control','preventive','active','effective','Finance Controller','Two-person approval for escrow releases'),
 ('f2400002-0000-4000-8000-000000000002','IC-VENDOR','Vendor onboarding screening','detective','active','partially_effective','Procurement','Screening gaps on subcontractors')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.control_assessments (id,control_id,title,status,effectiveness_rating,summary) VALUES
 ('f2400002-0000-4000-8000-000000000003','f2400002-0000-4000-8000-000000000001','Q2 escrow control test','completed','effective','Sample of 20 releases — no exceptions')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.compliance_evidence (id,code,title,status,requirement_label,summary) VALUES
 ('f2400003-0000-4000-8000-000000000001','CE-NDPR-26','NDPR processing records Q2','filed','NDPR Art. 25','Evidence pack for data processing activities'),
 ('f2400003-0000-4000-8000-000000000002','CE-CAC-FILING','CAC annual returns evidence','filed','Companies Act filings','Filed and acknowledged')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.preventive_actions (id,code,title,status,severity,owner_label,summary) VALUES
 ('f2400004-0000-4000-8000-000000000001','PA-VENDOR-SCREEN','Strengthen subcontractor screening','open','high','Procurement Lead','Close detective control gap on IC-VENDOR'),
 ('f2400004-0000-4000-8000-000000000002','PA-BCM-DRILL','Schedule Q4 crisis tabletop','planned','medium','BCM Coordinator','Align with DR test calendar')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.bcm_continuity_tests (id,code,title,category,status,test_type,result_label,summary) VALUES
 ('f2400005-0000-4000-8000-000000000001','BCM-TT-Q2','Q2 crisis tabletop exercise','exercise','completed','tabletop','passed','RTO targets met for sales and finance'),
 ('f2400005-0000-4000-8000-000000000002','BCM-FT-Q4','Q4 full failover exercise','exercise','planned','failover',null,'Pending infrastructure freeze window')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.regulatory_obligations (id,code,title,category,status,jurisdiction,owner_label,summary) VALUES
 ('f2400006-0000-4000-8000-000000000001','RO-NDPR','Nigeria Data Protection Regulation','regulation','compliant','NG','DPO','Annual review due Oct 2026'),
 ('f2400006-0000-4000-8000-000000000002','RO-REDA','Real Estate Developers Association standards','standard','watch','NG','Compliance Officer','Membership evidence refresh needed')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.operational_resilience_scores (id,code,title,metric_key,status,score_value,maturity_label,summary) VALUES
 ('f2400007-0000-4000-8000-000000000001','ORS-OVERALL','Operational resilience score','resilience_score','ok',78,'managed','Managed maturity · improve dependency mapping'),
 ('f2400007-0000-4000-8000-000000000002','ORS-CRIT-SVC','Critical service readiness','critical_service_ready','ok',86,'advanced','Sales, finance, and handover services ready')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.egrc_ai_insights (id,code,title,body,insight_type,confidence_pct) VALUES
 ('f2400008-0000-4000-8000-000000000001','AI-EGRC-01','Escalate vendor screening control gap','IC-VENDOR is only partially effective — open preventive action PA-VENDOR-SCREEN before next ARC meeting to reduce third-party risk exposure.','controls',90),
 ('f2400008-0000-4000-8000-000000000002','AI-EGRC-02','Prioritize Q4 BCM failover drill','Tabletop passed; full failover still planned — schedule before peak handover season to validate RTO for escrow and CRM.','bcm',87)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.egrc_activity_logs (id,action,title,category,actor_label,entity_type,severity,status,summary) VALUES
 ('f2400009-0000-4000-8000-000000000001','control.assessed','Escrow dual-authorization control tested','controls','Internal Audit','internal_controls','info','recorded','Q2 sample clean'),
 ('f2400009-0000-4000-8000-000000000002','bcm.tested','Q2 crisis tabletop completed','bcm','BCM Coordinator','bcm_continuity_tests','info','recorded','RTO targets met')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.kpi_snapshots (id,metric_key,label,value,previous_value,unit,change_pct,series,period,metadata) VALUES
 ('f2400009-0000-4000-8000-000000000003','egrc_risk_score','Enterprise Risk Score',62,68,'score',-8.8,'[74,72,70,68,66,64,62]'::jsonb,'daily','{"module":"egrc"}'),
 ('f2400009-0000-4000-8000-000000000004','egrc_compliance','Compliance Status',94,91,'pct',3.3,'[88,89,90,91,92,93,94]'::jsonb,'daily','{"module":"egrc"}'),
 ('f2400009-0000-4000-8000-000000000005','egrc_bcm_ready','BCM Readiness',81,76,'pct',6.6,'[70,72,74,76,78,80,81]'::jsonb,'daily','{"module":"egrc"}')
ON CONFLICT (id) DO NOTHING;

COMMIT;
