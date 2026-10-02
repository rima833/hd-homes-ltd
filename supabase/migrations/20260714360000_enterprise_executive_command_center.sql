-- APPLIED remotely (2026-07-21) — chunked ecc_p1 / p2 / p3
-- Volume 4 Part 25 — Enterprise Executive Command Center, AI Business Intelligence,
-- Strategic Decision Support & Digital Twin Platform (ECC) — Volume 4 FINALE
-- ENRICHES Part 1 / 10 / 15 / 23 tables in place. Never recreates them.
-- Does NOT recreate executive_dashboards, dashboard_widgets (personalization),
-- executive_scorecards, predictive_models, predictive_forecasts, executive_reports,
-- executive_notifications, board_meetings, board_votes, strategic_objectives,
-- executive_kpis, board_reports, scenario_models.
-- Does NOT replace /dashboard, /dashboard/eoc, /dashboard/analytics, /dashboard/epm,
-- /dashboard/grc, or /dashboard/egrc.
-- Permissions use (slug, name, description, module); has_permission slug is FIRST.
-- Seed UUIDs are hex-only f250….

BEGIN;

INSERT INTO public.permissions (slug, name, description, module) VALUES
 ('ecc.read','View ECC','View Executive Command Center','ecc'),
 ('ecc.write','Manage ECC','Create and update ECC records','ecc'),
 ('ecc.dashboards','Executive Dashboards','Manage executive dashboard widgets','ecc'),
 ('ecc.kpis','Strategic KPIs','Manage executive KPI definitions and scorecards','ecc'),
 ('ecc.strategy','Strategic Planning','Manage strategic initiatives and milestones','ecc'),
 ('ecc.portfolios','Portfolio Management','Manage enterprise portfolios','ecc'),
 ('ecc.health','Enterprise Health','View enterprise health scores','ecc'),
 ('ecc.predictive','Predictive Analytics','View predictive forecasts and models','ecc'),
 ('ecc.board','Board Portal','Manage board documents and members surfaces','ecc'),
 ('ecc.decisions','Decision Support','Manage decision support models','ecc'),
 ('ecc.scenarios','Scenario Simulations','Manage ECC scenario simulations','ecc'),
 ('ecc.twins','Digital Twin','Manage digital twin entities and relationships','ecc'),
 ('ecc.ai','ECC AI','View AI Executive Advisor insights','ecc'),
 ('ecc.admin','ECC Administration','Administer the Executive Command Center','ecc')
ON CONFLICT (slug) DO UPDATE SET
 name=EXCLUDED.name, description=EXCLUDED.description, module=EXCLUDED.module, updated_at=now();

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM public.roles r CROSS JOIN public.permissions p
WHERE p.slug LIKE 'ecc.%' AND (
 r.slug IN ('super_admin','admin')
 OR (r.slug='finance' AND p.slug IN (
  'ecc.read','ecc.kpis','ecc.health','ecc.predictive','ecc.portfolios','ecc.board','ecc.ai'
 ))
 OR (r.slug='construction_manager' AND p.slug IN (
  'ecc.read','ecc.kpis','ecc.portfolios','ecc.health','ecc.twins'
 ))
 OR (r.slug='sales_team' AND p.slug IN ('ecc.read','ecc.kpis','ecc.predictive'))
 OR (r.slug='marketing' AND p.slug IN ('ecc.read','ecc.kpis','ecc.ai'))
) ON CONFLICT DO NOTHING;

-- Enrich existing hubs — never DROP/recreate.
ALTER TABLE public.executive_dashboards
 ADD COLUMN IF NOT EXISTS ecc_surface text,
 ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb;
ALTER TABLE public.executive_scorecards
 ADD COLUMN IF NOT EXISTS ecc_surface text,
 ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb;
ALTER TABLE public.predictive_models
 ADD COLUMN IF NOT EXISTS ecc_surface text,
 ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb;
ALTER TABLE public.predictive_forecasts
 ADD COLUMN IF NOT EXISTS ecc_surface text,
 ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb;
ALTER TABLE public.executive_reports
 ADD COLUMN IF NOT EXISTS ecc_surface text,
 ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb;
ALTER TABLE public.strategic_objectives
 ADD COLUMN IF NOT EXISTS ecc_surface text,
 ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb;
ALTER TABLE public.executive_kpis
 ADD COLUMN IF NOT EXISTS ecc_surface text,
 ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb;
ALTER TABLE public.board_meetings
 ADD COLUMN IF NOT EXISTS ecc_surface text,
 ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb;
ALTER TABLE public.business_health_scores
 ADD COLUMN IF NOT EXISTS ecc_surface text,
 ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb;

CREATE TABLE IF NOT EXISTS public.ecc_dashboard_widgets (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'widget', widget_type text NOT NULL DEFAULT 'kpi',
 status text NOT NULL DEFAULT 'active', severity text NOT NULL DEFAULT 'info',
 layout_slot text, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ecc_kpi_definitions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'kpi', domain text NOT NULL DEFAULT 'financial',
 status text NOT NULL DEFAULT 'active', severity text NOT NULL DEFAULT 'info',
 unit text DEFAULT 'pct', target_value numeric, actual_value numeric, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ecc_strategic_initiatives (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 objective_id uuid REFERENCES public.strategic_objectives(id) ON DELETE SET NULL,
 code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'initiative', status text NOT NULL DEFAULT 'active',
 severity text NOT NULL DEFAULT 'info', owner_label text, progress_pct numeric, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ecc_initiative_milestones (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 initiative_id uuid REFERENCES public.ecc_strategic_initiatives(id) ON DELETE CASCADE,
 title text NOT NULL, category text NOT NULL DEFAULT 'milestone',
 status text NOT NULL DEFAULT 'planned', due_at timestamptz, summary text,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ecc_enterprise_portfolios (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'portfolio', portfolio_type text NOT NULL DEFAULT 'strategic',
 status text NOT NULL DEFAULT 'active', severity text NOT NULL DEFAULT 'info',
 budget_amount numeric, roi_pct numeric, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ecc_portfolio_items (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 portfolio_id uuid REFERENCES public.ecc_enterprise_portfolios(id) ON DELETE CASCADE,
 title text NOT NULL, category text NOT NULL DEFAULT 'item',
 status text NOT NULL DEFAULT 'active', priority text DEFAULT 'medium',
 budget_amount numeric, progress_pct numeric, summary text,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ecc_portfolio_metrics (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 portfolio_id uuid REFERENCES public.ecc_enterprise_portfolios(id) ON DELETE CASCADE,
 title text NOT NULL, metric_key text NOT NULL, status text NOT NULL DEFAULT 'ok',
 value numeric, unit text DEFAULT 'pct', summary text,
 recorded_at timestamptz NOT NULL DEFAULT now(),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ecc_health_scores (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'health', domain text NOT NULL DEFAULT 'enterprise',
 status text NOT NULL DEFAULT 'ok', severity text NOT NULL DEFAULT 'info',
 score_value numeric, summary text,
 recorded_at timestamptz NOT NULL DEFAULT now(),
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ecc_alerts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'alert', status text NOT NULL DEFAULT 'open',
 severity text NOT NULL DEFAULT 'medium', summary text,
 raised_at timestamptz NOT NULL DEFAULT now(),
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ecc_board_members (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'member', role_label text NOT NULL DEFAULT 'director',
 status text NOT NULL DEFAULT 'active', summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ecc_board_documents (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'board_pack', status text NOT NULL DEFAULT 'draft',
 severity text NOT NULL DEFAULT 'info', published_at timestamptz, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ecc_decision_support_models (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'decision', status text NOT NULL DEFAULT 'ready',
 severity text NOT NULL DEFAULT 'info', recommendation text, confidence_pct numeric, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ecc_scenario_simulations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'scenario', scenario_type text NOT NULL DEFAULT 'base',
 status text NOT NULL DEFAULT 'modeled', severity text NOT NULL DEFAULT 'info',
 impact_summary text, summary text,
 assumptions jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ecc_digital_twin_entities (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'entity', entity_type text NOT NULL DEFAULT 'department',
 status text NOT NULL DEFAULT 'live', severity text NOT NULL DEFAULT 'info',
 health_label text, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ecc_digital_twin_relationships (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 source_entity_id uuid REFERENCES public.ecc_digital_twin_entities(id) ON DELETE CASCADE,
 target_entity_id uuid REFERENCES public.ecc_digital_twin_entities(id) ON DELETE CASCADE,
 title text NOT NULL, relationship_type text NOT NULL DEFAULT 'depends_on',
 status text NOT NULL DEFAULT 'active', summary text,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ecc_activity_logs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), action text NOT NULL, title text NOT NULL,
 category text NOT NULL DEFAULT 'ecc', actor_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
 actor_label text, entity_type text, entity_id uuid, severity text NOT NULL DEFAULT 'info',
 status text NOT NULL DEFAULT 'recorded', summary text, metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 occurred_at timestamptz NOT NULL DEFAULT now(),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ecc_notifications (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), recipient_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
 title text NOT NULL, category text NOT NULL DEFAULT 'ecc', channel text NOT NULL DEFAULT 'in_app',
 severity text NOT NULL DEFAULT 'info', status text NOT NULL DEFAULT 'unread', body text,
 read_at timestamptz, metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ecc_ai_insights (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 body text NOT NULL, category text NOT NULL DEFAULT 'ecc', insight_type text NOT NULL,
 confidence_pct numeric(5,2), status text NOT NULL DEFAULT 'active', editable boolean NOT NULL DEFAULT true,
 disclaimer text NOT NULL DEFAULT 'AI-generated — editable / advisory',
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ecc_kpi_definitions_domain ON public.ecc_kpi_definitions(domain, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ecc_strategic_initiatives_status ON public.ecc_strategic_initiatives(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ecc_health_scores_domain ON public.ecc_health_scores(domain, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_ecc_alerts_status ON public.ecc_alerts(status, raised_at DESC);
CREATE INDEX IF NOT EXISTS idx_ecc_digital_twin_entities_type ON public.ecc_digital_twin_entities(entity_type, created_at DESC);

INSERT INTO storage.buckets (id,name,public) VALUES ('ecc-artifacts','ecc-artifacts',false)
ON CONFLICT (id) DO NOTHING;

DO $$ BEGIN
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.ecc_kpi_definitions; EXCEPTION WHEN duplicate_object THEN NULL; END;
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.ecc_strategic_initiatives; EXCEPTION WHEN duplicate_object THEN NULL; END;
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.ecc_health_scores; EXCEPTION WHEN duplicate_object THEN NULL; END;
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.ecc_alerts; EXCEPTION WHEN duplicate_object THEN NULL; END;
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.ecc_board_documents; EXCEPTION WHEN duplicate_object THEN NULL; END;
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.ecc_notifications; EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

DO $$
DECLARE t text;
BEGIN
 FOREACH t IN ARRAY ARRAY[
  'ecc_dashboard_widgets','ecc_kpi_definitions','ecc_strategic_initiatives','ecc_initiative_milestones',
  'ecc_enterprise_portfolios','ecc_portfolio_items','ecc_portfolio_metrics','ecc_health_scores',
  'ecc_alerts','ecc_board_members','ecc_board_documents','ecc_decision_support_models',
  'ecc_scenario_simulations','ecc_digital_twin_entities','ecc_digital_twin_relationships',
  'ecc_activity_logs','ecc_notifications','ecc_ai_insights'
 ] LOOP
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
  EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_select', t);
  EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_write', t);
  EXECUTE format(
   'CREATE POLICY %I ON public.%I FOR SELECT USING (public.has_permission(''ecc.read'', auth.uid()) OR public.has_permission(''ecc.admin'', auth.uid()) OR public.has_role(''super_admin'', auth.uid()))',
   t || '_select', t
  );
  EXECUTE format(
   'CREATE POLICY %I ON public.%I FOR ALL USING (public.has_permission(''ecc.write'', auth.uid()) OR public.has_permission(''ecc.admin'', auth.uid()) OR public.has_role(''super_admin'', auth.uid())) WITH CHECK (public.has_permission(''ecc.write'', auth.uid()) OR public.has_permission(''ecc.admin'', auth.uid()) OR public.has_role(''super_admin'', auth.uid()))',
   t || '_write', t
  );
 END LOOP;
END $$;

GRANT SELECT, INSERT, UPDATE, DELETE ON
 public.ecc_dashboard_widgets, public.ecc_kpi_definitions, public.ecc_strategic_initiatives, public.ecc_initiative_milestones,
 public.ecc_enterprise_portfolios, public.ecc_portfolio_items, public.ecc_portfolio_metrics, public.ecc_health_scores,
 public.ecc_alerts, public.ecc_board_members, public.ecc_board_documents, public.ecc_decision_support_models,
 public.ecc_scenario_simulations, public.ecc_digital_twin_entities, public.ecc_digital_twin_relationships,
 public.ecc_activity_logs, public.ecc_notifications, public.ecc_ai_insights
TO authenticated;

-- Phase 1 demo seeds (hex-only f250…).
INSERT INTO public.ecc_dashboard_widgets (id,code,title,widget_type,status,layout_slot,summary) VALUES
 ('f2500001-0000-4000-8000-000000000001','W-REV','Revenue KPI widget','kpi','active','row1-col1','Live revenue strip'),
 ('f2500001-0000-4000-8000-000000000002','W-HEALTH','Enterprise Health Index','health','active','row1-col2','Composite health score')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ecc_kpi_definitions (id,code,title,domain,status,unit,target_value,actual_value,summary) VALUES
 ('f2500002-0000-4000-8000-000000000001','KPI-REV-GROWTH','Revenue Growth','financial','active','pct',18,21.4,'21.4% YoY · above target'),
 ('f2500002-0000-4000-8000-000000000002','KPI-NPS','Net Promoter Score','customer','active','score',60,64,'64 · customer health strong'),
 ('f2500002-0000-4000-8000-000000000003','KPI-UPTIME','Platform Uptime','operations','active','pct',99.5,99.7,'99.7% last 30 days')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ecc_strategic_initiatives (id,code,title,category,status,owner_label,progress_pct,summary) VALUES
 ('f2500003-0000-4000-8000-000000000001','SI-LEKKI-SCALE','Scale Lekki corridor delivery','growth','active','COO',68,'Phase 3 infrastructure + sales alignment'),
 ('f2500003-0000-4000-8000-000000000002','SI-CX-LOYALTY','Enterprise loyalty program launch','customer','in_progress','CMO',42,'ECXP loyalty rails live · enrollments ramping')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ecc_initiative_milestones (id,initiative_id,title,status,summary) VALUES
 ('f2500003-0000-4000-8000-000000000003','f2500003-0000-4000-8000-000000000001','Capex board approval','completed','Approved at ARC'),
 ('f2500003-0000-4000-8000-000000000004','f2500003-0000-4000-8000-000000000002','Loyalty beta cohort','planned','Q3 pilot · 500 customers')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ecc_enterprise_portfolios (id,code,title,portfolio_type,status,budget_amount,roi_pct,summary) VALUES
 ('f2500004-0000-4000-8000-000000000001','PF-CONSTRUCT','Construction Project Portfolio','construction','active',4500000000,16,'₦4.5B · weighted ROI 16%'),
 ('f2500004-0000-4000-8000-000000000002','PF-TECH','Technology Portfolio','technology','active',320000000,22,'Platform + AI investments')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ecc_portfolio_items (id,portfolio_id,title,status,priority,progress_pct,summary) VALUES
 ('f2500004-0000-4000-8000-000000000003','f2500004-0000-4000-8000-000000000001','Lekki Phase 3','active','high',55,'On track · budget variance 2%'),
 ('f2500004-0000-4000-8000-000000000004','f2500004-0000-4000-8000-000000000002','ECC Command Center rollout','active','high',80,'Part 25 Phase 1')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ecc_health_scores (id,code,title,domain,status,score_value,summary) VALUES
 ('f2500005-0000-4000-8000-000000000001','EH-OVERALL','Enterprise Health Index','enterprise','ok',84,'Strong · watch construction timeline risk'),
 ('f2500005-0000-4000-8000-000000000002','EH-FIN','Financial Health','financial','ok',88,'Cash runway healthy'),
 ('f2500005-0000-4000-8000-000000000003','EH-CX','Customer Health','customer','ok',81,'NPS and CSAT stable'),
 ('f2500005-0000-4000-8000-000000000004','EH-SEC','Security Health','security','watch',74,'Open medium alerts in ESP')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ecc_alerts (id,code,title,category,status,severity,summary) VALUES
 ('f2500006-0000-4000-8000-000000000001','AL-CASH-DIP','Q4 liquidity watch','financial','open','medium','Align with EPM 13-week cash forecast'),
 ('f2500006-0000-4000-8000-000000000002','AL-VENDOR-CTRL','Vendor screening control gap','governance','open','high','Escalated from EGRC · IC-VENDOR')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ecc_board_members (id,code,title,role_label,status,summary) VALUES
 ('f2500007-0000-4000-8000-000000000001','BM-CHAIR','Board Chair','chair','active','Strategic oversight'),
 ('f2500007-0000-4000-8000-000000000002','BM-IND','Independent Director — ARC','director','active','Audit & Risk Committee chair')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ecc_board_documents (id,code,title,category,status,summary) VALUES
 ('f2500007-0000-4000-8000-000000000003','BD-Q2-PACK','Q2 Board Pack','board_pack','draft','Finance + risk + strategy summary'),
 ('f2500007-0000-4000-8000-000000000004','BD-STRAT-2026','2026 Strategy Review Memo','strategy','scheduled','Board review 28 Jul')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ecc_decision_support_models (id,code,title,status,recommendation,confidence_pct,summary) VALUES
 ('f2500008-0000-4000-8000-000000000001','DS-CAPEX','Defer non-critical capex Q4','ready','Defer ₦85M Abuja showroom until cash forecast clears Week 9','86','Supports EPM cash preservation insight'),
 ('f2500008-0000-4000-8000-000000000002','DS-LOYALTY','Accelerate loyalty enrollment','ready','Fund CMO cohort incentives to hit 5k members by Q4','79','Supports SI-CX-LOYALTY')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ecc_scenario_simulations (id,code,title,scenario_type,status,severity,impact_summary,summary,assumptions) VALUES
 ('f2500009-0000-4000-8000-000000000001','SIM-BEST','Best case — accelerated handovers','best_case','modeled','info','Revenue +12% · cash +₦140M','Handover acceleration','{"handover_uplift_pct":12}'::jsonb),
 ('f2500009-0000-4000-8000-000000000002','SIM-STRESS','Stress — construction delay + FX','worst_case','modeled','high','Cash -₦220M · margin -3pp','Combined operational and FX shock','{"delay_months":3,"fx_shock_pct":8}'::jsonb)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ecc_digital_twin_entities (id,code,title,entity_type,status,health_label,summary) VALUES
 ('f250000a-0000-4000-8000-000000000001','DT-SALES','Sales Pipeline','department','live','healthy','Pipeline ₦2.1B · conversion 24%'),
 ('f250000a-0000-4000-8000-000000000002','DT-LEKKI','Lekki Phase 3 Site','project','live','watch','Timeline pressure · weather + vendor'),
 ('f250000a-0000-4000-8000-000000000003','DT-FIN','Finance Systems','system','live','healthy','EPM + FAPMS synchronized'),
 ('f250000a-0000-4000-8000-000000000004','DT-CX','Customer Experience','service','live','healthy','ECXP NPS 64')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ecc_digital_twin_relationships (id,source_entity_id,target_entity_id,title,relationship_type,summary) VALUES
 ('f250000a-0000-4000-8000-000000000005','f250000a-0000-4000-8000-000000000002','f250000a-0000-4000-8000-000000000001','Site delivery feeds sales','feeds','Handover dates drive reservation conversions'),
 ('f250000a-0000-4000-8000-000000000006','f250000a-0000-4000-8000-000000000003','f250000a-0000-4000-8000-000000000001','Finance funds sales ops','supports','Cash position gates marketing spend')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ecc_ai_insights (id,code,title,body,insight_type,confidence_pct) VALUES
 ('f250000b-0000-4000-8000-000000000001','AI-ECC-01','Protect Q4 cash while funding loyalty','Enterprise Health is strong (84) but liquidity watch and vendor control gap are open — defer non-critical capex and close IC-VENDOR before accelerating loyalty incentives.','strategy',91),
 ('f250000b-0000-4000-8000-000000000002','AI-ECC-02','Digital twin flags Lekki → Sales dependency','Lekki Phase 3 timeline pressure propagates to sales conversion — prioritize site risk mitigation to protect revenue forecast.','digital_twin',88)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ecc_activity_logs (id,action,title,category,actor_label,entity_type,severity,status,summary) VALUES
 ('f250000c-0000-4000-8000-000000000001','health.recalculated','Enterprise Health Index recalculated','health','ECC Engine','ecc_health_scores','info','recorded','Score 84'),
 ('f250000c-0000-4000-8000-000000000002','board.pack.drafted','Q2 Board Pack drafted','board','Company Secretary','ecc_board_documents','info','recorded','Awaiting CFO review')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.kpi_snapshots (id,metric_key,label,value,previous_value,unit,change_pct,series,period,metadata) VALUES
 ('f250000c-0000-4000-8000-000000000003','ecc_health_index','Enterprise Health Index',84,81,'score',3.7,'[76,78,79,80,81,82,84]'::jsonb,'daily','{"module":"ecc"}'),
 ('f250000c-0000-4000-8000-000000000004','ecc_rev_growth','Revenue Growth',21.4,19.8,'pct',8.1,'[16,17,18,19,19.8,20.5,21.4]'::jsonb,'daily','{"module":"ecc"}'),
 ('f250000c-0000-4000-8000-000000000005','ecc_nps','NPS',64,61,'score',4.9,'[55,57,58,59,60,61,64]'::jsonb,'daily','{"module":"ecc"}')
ON CONFLICT (id) DO NOTHING;

COMMIT;
