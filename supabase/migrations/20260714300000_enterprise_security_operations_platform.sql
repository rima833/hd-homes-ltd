-- APPLIED remotely 2026-07-21 (chunked enterprise_security_operations_p1–p2)
-- Volume 4 Part 19 — Enterprise Security Operations Platform (ESP)
-- ENRICHES identity/MFA/audit tables in place. Never recreates collision tables.
-- Permissions use (slug, name, description, module); has_permission slug is FIRST.
-- Seed UUIDs are hex-only b190….
-- Status: APPLIED remotely 2026-07-21.

BEGIN;

INSERT INTO public.permissions (slug, name, description, module) VALUES
 ('security.read','View Security','View Enterprise Security Command Center','security'),
 ('security.write','Manage Security','Create and update security operations records','security'),
 ('security.iam','Security IAM','Manage identity risk and trust controls','security'),
 ('security.mfa','Security MFA','Manage enterprise MFA posture','security'),
 ('security.threats','Threat Intelligence','Manage alerts and threat detections','security'),
 ('security.incidents','Incident Response','Manage incidents and evidence','security'),
 ('security.audit','Security Audit','View and manage security audit records','security'),
 ('security.privacy','Privacy Operations','Manage consent, privacy requests, and retention','security'),
 ('security.secrets','Secrets Management','Manage encryption policies, keys, and secrets','security'),
 ('security.backup','Backup Operations','Manage disaster recovery backups','security'),
 ('security.dr','Disaster Recovery','Manage recovery plans, tests, and resilience','security'),
 ('security.ai','Security AI','View AI security events and insights','security'),
 ('security.analytics','Security Analytics','View security reports and posture metrics','security'),
 ('security.admin','Security Administration','Administer the Enterprise Security Platform','security')
ON CONFLICT (slug) DO UPDATE SET
 name=EXCLUDED.name, description=EXCLUDED.description, module=EXCLUDED.module, updated_at=now();

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM public.roles r CROSS JOIN public.permissions p
WHERE p.slug LIKE 'security.%' AND (
 r.slug IN ('super_admin','admin')
 OR (r.slug='finance' AND p.slug IN ('security.read','security.audit','security.privacy','security.analytics'))
 OR (r.slug='construction_manager' AND p.slug IN ('security.read','security.incidents'))
 OR (r.slug='sales_team' AND p.slug='security.read')
 OR (r.slug='marketing' AND p.slug IN ('security.read','security.privacy'))
) ON CONFLICT DO NOTHING;

-- Existing Volume 3 identity, MFA and foundation audit tables: enrich only.
ALTER TABLE public.user_sessions
 ADD COLUMN IF NOT EXISTS risk_score numeric(5,2) DEFAULT 0,
 ADD COLUMN IF NOT EXISTS risk_level text DEFAULT 'low',
 ADD COLUMN IF NOT EXISTS last_step_up_at timestamptz,
 ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb;
ALTER TABLE public.trusted_devices
 ADD COLUMN IF NOT EXISTS trust_score numeric(5,2) DEFAULT 0,
 ADD COLUMN IF NOT EXISTS risk_score numeric(5,2) DEFAULT 0,
 ADD COLUMN IF NOT EXISTS attestation_status text DEFAULT 'unknown',
 ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb;
ALTER TABLE public.security_events
 ADD COLUMN IF NOT EXISTS risk_score numeric(5,2) DEFAULT 0,
 ADD COLUMN IF NOT EXISTS correlation_id text,
 ADD COLUMN IF NOT EXISTS source_system text DEFAULT 'identity',
 ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb;
ALTER TABLE public.mfa_settings
 ADD COLUMN IF NOT EXISTS allowed_methods text[] DEFAULT ARRAY['totp']::text[],
 ADD COLUMN IF NOT EXISTS phishing_resistant_enabled boolean DEFAULT false,
 ADD COLUMN IF NOT EXISTS enrollment_risk_score numeric(5,2) DEFAULT 0,
 ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb;
ALTER TABLE public.mfa_policies
 ADD COLUMN IF NOT EXISTS adaptive_risk_threshold numeric(5,2) DEFAULT 70,
 ADD COLUMN IF NOT EXISTS require_phishing_resistant boolean DEFAULT false,
 ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb;
ALTER TABLE public.audit_logs
 ADD COLUMN IF NOT EXISTS risk_score numeric(5,2) DEFAULT 0,
 ADD COLUMN IF NOT EXISTS correlation_id text,
 ADD COLUMN IF NOT EXISTS integrity_hash text,
 ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb;

CREATE TABLE IF NOT EXISTS public.security_alerts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 alert_type text NOT NULL, severity text NOT NULL DEFAULT 'medium', status text NOT NULL DEFAULT 'open',
 source_system text, risk_score numeric(5,2) DEFAULT 0, assigned_to uuid REFERENCES public.profiles(id),
 summary text, details jsonb NOT NULL DEFAULT '{}'::jsonb, occurred_at timestamptz NOT NULL DEFAULT now(),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.threat_detections (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 threat_type text NOT NULL, severity text NOT NULL DEFAULT 'medium', status text NOT NULL DEFAULT 'active',
 indicator_type text, indicator_value text, confidence_pct numeric(5,2), risk_score numeric(5,2),
 summary text, evidence jsonb NOT NULL DEFAULT '{}'::jsonb, occurred_at timestamptz NOT NULL DEFAULT now(),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.security_incidents (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL, severity text NOT NULL DEFAULT 'medium', status text NOT NULL DEFAULT 'open',
 commander_id uuid REFERENCES public.profiles(id), summary text, containment_notes text,
 opened_at timestamptz NOT NULL DEFAULT now(), resolved_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.incident_evidence (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), incident_id uuid NOT NULL REFERENCES public.security_incidents(id) ON DELETE CASCADE,
 title text NOT NULL, evidence_type text NOT NULL, storage_path text, integrity_hash text,
 chain_of_custody jsonb NOT NULL DEFAULT '[]'::jsonb, collected_by uuid REFERENCES public.profiles(id),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.encryption_policies (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, name text NOT NULL,
 scope text NOT NULL, algorithm text NOT NULL DEFAULT 'AES-256-GCM', rotation_days int NOT NULL DEFAULT 90,
 status text NOT NULL DEFAULT 'active', summary text, metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.key_management (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, name text NOT NULL,
 key_ref text NOT NULL, provider text NOT NULL DEFAULT 'managed', purpose text NOT NULL,
 status text NOT NULL DEFAULT 'active', rotated_at timestamptz, next_rotation_at timestamptz,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.secrets_registry (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, name text NOT NULL,
 category text NOT NULL, key_ref text NOT NULL, encrypted_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
 owner_label text, status text NOT NULL DEFAULT 'active', rotated_at timestamptz, next_rotation_at timestamptz,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.privacy_consents (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), subject_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
 purpose text NOT NULL, lawful_basis text, status text NOT NULL DEFAULT 'granted',
 granted_at timestamptz, withdrawn_at timestamptz, source text,
 evidence jsonb NOT NULL DEFAULT '{}'::jsonb, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.privacy_requests (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 subject_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL, request_type text NOT NULL,
 category text NOT NULL DEFAULT 'privacy', status text NOT NULL DEFAULT 'open', due_at timestamptz,
 summary text, response_metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.security_retention_policies (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, name text NOT NULL,
 data_category text NOT NULL, retention_days int NOT NULL, legal_basis text,
 deletion_action text NOT NULL DEFAULT 'delete', status text NOT NULL DEFAULT 'active',
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.backup_jobs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, name text NOT NULL,
 target_type text NOT NULL, schedule_expression text, encryption_key_ref text,
 retention_days int NOT NULL DEFAULT 30, status text NOT NULL DEFAULT 'active',
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.backup_history (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), job_id uuid NOT NULL REFERENCES public.backup_jobs(id) ON DELETE CASCADE,
 title text NOT NULL, category text NOT NULL DEFAULT 'backup', status text NOT NULL,
 started_at timestamptz NOT NULL DEFAULT now(), completed_at timestamptz, size_bytes bigint,
 checksum text, verified_at timestamptz, storage_ref text, summary text,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.disaster_recovery_plans (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'recovery', tier text NOT NULL DEFAULT 'tier_2', status text NOT NULL DEFAULT 'active',
 rto_minutes int NOT NULL, rpo_minutes int NOT NULL, owner_label text, summary text,
 runbook jsonb NOT NULL DEFAULT '{}'::jsonb, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.disaster_recovery_tests (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), plan_id uuid NOT NULL REFERENCES public.disaster_recovery_plans(id) ON DELETE CASCADE,
 title text NOT NULL, category text NOT NULL DEFAULT 'test', test_type text NOT NULL, status text NOT NULL DEFAULT 'planned',
 tested_at timestamptz, actual_rto_minutes int, actual_rpo_minutes int, findings jsonb NOT NULL DEFAULT '[]'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.resilience_assessments (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'resilience', scope text NOT NULL, score numeric(5,2) NOT NULL,
 status text NOT NULL DEFAULT 'complete', summary text, recommendations jsonb NOT NULL DEFAULT '[]'::jsonb,
 assessed_at timestamptz NOT NULL DEFAULT now(), created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.ai_security_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL, event_type text NOT NULL, severity text NOT NULL DEFAULT 'medium',
 status text NOT NULL DEFAULT 'blocked', model_ref text, risk_score numeric(5,2),
 summary text, details jsonb NOT NULL DEFAULT '{}'::jsonb, occurred_at timestamptz NOT NULL DEFAULT now(),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.security_reports (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'analytics', report_type text NOT NULL, status text NOT NULL DEFAULT 'ready',
 period_start timestamptz, period_end timestamptz, summary text, report_data jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.security_activity_logs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), action text NOT NULL, title text NOT NULL,
 category text NOT NULL DEFAULT 'security', actor_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
 actor_label text, entity_type text, entity_id uuid, severity text NOT NULL DEFAULT 'info',
 status text NOT NULL DEFAULT 'recorded', summary text, metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 occurred_at timestamptz NOT NULL DEFAULT now(), created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.security_notifications (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), recipient_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
 title text NOT NULL, category text NOT NULL DEFAULT 'security', channel text NOT NULL DEFAULT 'in_app',
 severity text NOT NULL DEFAULT 'info', status text NOT NULL DEFAULT 'unread', body text,
 read_at timestamptz, metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.security_ai_insights (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 body text NOT NULL, category text NOT NULL DEFAULT 'security', insight_type text NOT NULL,
 confidence_pct numeric(5,2), status text NOT NULL DEFAULT 'active', editable boolean NOT NULL DEFAULT true,
 disclaimer text NOT NULL DEFAULT 'AI-generated — editable / advisory',
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_security_alerts_status ON public.security_alerts(status, severity, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_threat_detections_status ON public.threat_detections(status, severity, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_security_incidents_status ON public.security_incidents(status, severity, opened_at DESC);
CREATE INDEX IF NOT EXISTS idx_privacy_requests_status ON public.privacy_requests(status, due_at);
CREATE INDEX IF NOT EXISTS idx_backup_history_job ON public.backup_history(job_id, started_at DESC);

INSERT INTO storage.buckets (id,name,public) VALUES ('security-evidence','security-evidence',false)
ON CONFLICT (id) DO NOTHING;

DO $$ BEGIN
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.security_alerts; EXCEPTION WHEN duplicate_object THEN NULL; END;
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.threat_detections; EXCEPTION WHEN duplicate_object THEN NULL; END;
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.security_incidents; EXCEPTION WHEN duplicate_object THEN NULL; END;
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.security_events; EXCEPTION WHEN duplicate_object THEN NULL; END;
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.security_activity_logs; EXCEPTION WHEN duplicate_object THEN NULL; END;
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.security_notifications; EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

-- RLS for all ESP-owned tables. Security read is the common read gate; specific/write/admin gates mutate.
DO $$
DECLARE t text;
BEGIN
 FOREACH t IN ARRAY ARRAY[
  'security_alerts','threat_detections','security_incidents','incident_evidence',
  'encryption_policies','key_management','secrets_registry','privacy_consents','privacy_requests',
  'security_retention_policies','backup_jobs','backup_history','disaster_recovery_plans',
  'disaster_recovery_tests','resilience_assessments','ai_security_events','security_reports',
  'security_activity_logs','security_notifications','security_ai_insights'
 ] LOOP
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
  EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_select', t);
  EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_write', t);
  EXECUTE format(
   'CREATE POLICY %I ON public.%I FOR SELECT USING (public.has_permission(''security.read'', auth.uid()) OR public.has_permission(''security.admin'', auth.uid()) OR public.has_role(''super_admin'', auth.uid()))',
   t || '_select', t
  );
  EXECUTE format(
   'CREATE POLICY %I ON public.%I FOR ALL USING (public.has_permission(''security.write'', auth.uid()) OR public.has_permission(''security.admin'', auth.uid()) OR public.has_role(''super_admin'', auth.uid())) WITH CHECK (public.has_permission(''security.write'', auth.uid()) OR public.has_permission(''security.admin'', auth.uid()) OR public.has_role(''super_admin'', auth.uid()))',
   t || '_write', t
  );
 END LOOP;
END $$;

GRANT SELECT, INSERT, UPDATE, DELETE ON
 public.security_alerts, public.threat_detections, public.security_incidents, public.incident_evidence,
 public.encryption_policies, public.key_management, public.secrets_registry, public.privacy_consents,
 public.privacy_requests, public.security_retention_policies, public.backup_jobs, public.backup_history,
 public.disaster_recovery_plans, public.disaster_recovery_tests, public.resilience_assessments,
 public.ai_security_events, public.security_reports, public.security_activity_logs,
 public.security_notifications, public.security_ai_insights TO authenticated;

-- Phase 1 demo seeds.
INSERT INTO public.security_alerts (id,code,title,alert_type,severity,status,source_system,risk_score,summary) VALUES
 ('b1900002-0000-4000-8000-000000000001','ALT-IMPOSSIBLE-TRAVEL','Impossible travel signal','identity','high','open','identity',82,'Admin authentication from distant regions'),
 ('b1900002-0000-4000-8000-000000000002','ALT-API-AUTH','Repeated API authorization failures','application','medium','investigating','api_gateway',61,'Burst of denied privileged requests')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.threat_detections (id,code,title,threat_type,severity,status,confidence_pct,risk_score,summary) VALUES
 ('b1900003-0000-4000-8000-000000000001','THR-CRED-STUFF','Credential stuffing pattern','account_takeover','critical','active',94,96,'Distributed login attempts against known accounts'),
 ('b1900003-0000-4000-8000-000000000002','THR-EXPORT','Suspicious export volume','data_loss','high','active',86,83,'Data export exceeds normal finance baseline')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.security_incidents (id,code,title,category,severity,status,summary) VALUES
 ('b1900004-0000-4000-8000-000000000001','INC-2026-019','Account takeover investigation','identity','high','investigating','Contain affected sessions and preserve authentication evidence')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.incident_evidence (id,incident_id,title,evidence_type,integrity_hash) VALUES
 ('b1900004-0000-4000-8000-000000000002','b1900004-0000-4000-8000-000000000001','Authentication event export','event_log','sha256:demo-not-production')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.privacy_requests (id,code,title,request_type,status,due_at,summary) VALUES
 ('b1900007-0000-4000-8000-000000000001','PRV-2026-004','Customer data access request','access','open',now()+interval '21 days','Verify identity before releasing the data package')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.backup_jobs (id,code,name,target_type,schedule_expression,encryption_key_ref,status) VALUES
 ('b1900009-0000-4000-8000-000000000001','BKP-DB-NIGHTLY','Nightly database backup','database','0 1 * * *','kms://security/backup-primary','active')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.backup_history (id,job_id,title,status,completed_at,size_bytes,checksum,verified_at,summary) VALUES
 ('b1900009-0000-4000-8000-000000000002','b1900009-0000-4000-8000-000000000001','Nightly database backup','succeeded',now()-interval '4 hours',2147483648,'sha256:demo-backup',now()-interval '3 hours','Encrypted backup verified')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.disaster_recovery_plans (id,code,title,tier,status,rto_minutes,rpo_minutes,owner_label,summary) VALUES
 ('b190000a-0000-4000-8000-000000000001','DR-PLATFORM-01','Primary platform recovery plan','tier_1','active',120,15,'Platform & Security','Cross-region service and database recovery')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.disaster_recovery_tests (id,plan_id,title,test_type,status,tested_at,actual_rto_minutes,actual_rpo_minutes) VALUES
 ('b190000a-0000-4000-8000-000000000002','b190000a-0000-4000-8000-000000000001','Quarterly failover exercise','tabletop','passed',now()-interval '14 days',102,12)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.ai_security_events (id,code,title,category,event_type,severity,status,risk_score,summary) VALUES
 ('b190000b-0000-4000-8000-000000000001','AISEC-INJECT-01','Prompt injection blocked','AI firewall','prompt_injection','high','blocked',88,'Untrusted instruction attempted to override policy'),
 ('b190000b-0000-4000-8000-000000000002','AISEC-DLP-01','Sensitive output redacted','DLP','sensitive_output','medium','blocked',72,'Personal data removed before response')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.security_ai_insights (id,code,title,body,insight_type,confidence_pct) VALUES
 ('b190000c-0000-4000-8000-000000000001','AI-SEC-01','Enforce step-up for anomalous finance sessions','Identity risk and transaction sensitivity indicate step-up authentication.','identity',88),
 ('b190000c-0000-4000-8000-000000000002','AI-SEC-02','Prioritize credential-stuffing containment','Rate-limit, revoke affected sessions, and review exposed identifiers.','threat',93)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.kpi_snapshots (id,metric_key,label,value,previous_value,unit,change_pct,series,period,metadata) VALUES
 ('b190000e-0000-4000-8000-000000000001','security_score','Security Score',92,89,'pct',3.4,'[86,87,89,90,89,91,92]'::jsonb,'daily','{"module":"security"}'),
 ('b190000e-0000-4000-8000-000000000002','security_mfa_coverage','MFA Coverage',86,82,'pct',4.9,'[72,75,78,80,82,84,86]'::jsonb,'daily','{"module":"security"}'),
 ('b190000e-0000-4000-8000-000000000003','security_dr_readiness','DR Readiness',94,91,'pct',3.3,'[88,89,90,91,91,93,94]'::jsonb,'daily','{"module":"security"}')
ON CONFLICT (id) DO NOTHING;

COMMIT;
