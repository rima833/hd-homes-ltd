-- APPLIED remotely (2026-07-21) — chunked epm_p1a / p1b / p2 / p3
-- Volume 4 Part 23 — Enterprise Financial Planning, Budgeting, Forecasting,
-- Treasury & Corporate Performance Management (EPM)
-- ENRICHES FAPMS budgets / financial_reports in place. Never recreates them.
-- Does NOT recreate budget_lines, board_meetings, board_resolutions, board_votes.
-- Does NOT replace /dashboard/finance (FinanceCommandCenterPage).
-- Permissions use (slug, name, description, module); has_permission slug is FIRST.
-- Seed UUIDs are hex-only f230….

BEGIN;

INSERT INTO public.permissions (slug, name, description, module) VALUES
 ('epm.read','View EPM','View Enterprise Performance Management Command Center','epm'),
 ('epm.write','Manage EPM','Create and update EPM records','epm'),
 ('epm.budgets','Budgets','Manage budget cycles, versions, and approvals','epm'),
 ('epm.planning','Financial Planning','Manage financial plans','epm'),
 ('epm.forecasts','Forecasts','Manage forecast models and results','epm'),
 ('epm.treasury','Treasury','Manage treasury accounts and transactions','epm'),
 ('epm.cashflow','Cash Flow','Manage cash flow snapshots and forecasts','epm'),
 ('epm.capital','Capital','Manage capital projects and allocations','epm'),
 ('epm.scenarios','Scenarios','Manage scenario models and results','epm'),
 ('epm.kpis','Executive KPIs','Manage executive KPIs and objectives','epm'),
 ('epm.performance','Performance','View corporate performance metrics','epm'),
 ('epm.board','Board Reporting','Manage board reports','epm'),
 ('epm.ai','EPM AI','View EPM AI insights','epm'),
 ('epm.admin','EPM Administration','Administer the Enterprise Performance Management Platform','epm')
ON CONFLICT (slug) DO UPDATE SET
 name=EXCLUDED.name, description=EXCLUDED.description, module=EXCLUDED.module, updated_at=now();

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM public.roles r CROSS JOIN public.permissions p
WHERE p.slug LIKE 'epm.%' AND (
 r.slug IN ('super_admin','admin')
 OR (r.slug='finance' AND p.slug IN (
  'epm.read','epm.write','epm.budgets','epm.planning','epm.forecasts',
  'epm.treasury','epm.cashflow','epm.capital','epm.kpis','epm.performance','epm.board','epm.ai'
 ))
 OR (r.slug='construction_manager' AND p.slug IN ('epm.read','epm.capital','epm.budgets'))
 OR (r.slug='sales_team' AND p.slug IN ('epm.read','epm.forecasts','epm.kpis'))
 OR (r.slug='marketing' AND p.slug IN ('epm.read','epm.budgets','epm.forecasts'))
) ON CONFLICT DO NOTHING;

-- FAPMS budgets / financial_reports: enrich only — never DROP/recreate.
ALTER TABLE public.budgets
 ADD COLUMN IF NOT EXISTS epm_surface text,
 ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb;
ALTER TABLE public.financial_reports
 ADD COLUMN IF NOT EXISTS epm_surface text,
 ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb;

CREATE TABLE IF NOT EXISTS public.budget_cycles (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'annual', status text NOT NULL DEFAULT 'active',
 severity text NOT NULL DEFAULT 'info', fiscal_year int, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.budget_versions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 cycle_id uuid REFERENCES public.budget_cycles(id) ON DELETE CASCADE,
 code text UNIQUE, title text NOT NULL, category text NOT NULL DEFAULT 'version',
 status text NOT NULL DEFAULT 'draft', severity text NOT NULL DEFAULT 'info',
 version_label text, total_amount numeric, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.budget_items (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 version_id uuid REFERENCES public.budget_versions(id) ON DELETE CASCADE,
 title text NOT NULL, category text NOT NULL DEFAULT 'line',
 status text NOT NULL DEFAULT 'active', department_label text,
 budgeted_amount numeric, actual_amount numeric, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.budget_approvals (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 version_id uuid REFERENCES public.budget_versions(id) ON DELETE CASCADE,
 title text NOT NULL, category text NOT NULL DEFAULT 'approval',
 status text NOT NULL DEFAULT 'pending', severity text NOT NULL DEFAULT 'info',
 approver_label text, decided_at timestamptz, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.financial_plans (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'plan', plan_type text NOT NULL DEFAULT 'strategic',
 status text NOT NULL DEFAULT 'active', severity text NOT NULL DEFAULT 'info',
 horizon_years int DEFAULT 3, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.financial_plan_versions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 plan_id uuid REFERENCES public.financial_plans(id) ON DELETE CASCADE,
 title text NOT NULL, version_label text, status text NOT NULL DEFAULT 'draft',
 summary text, metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.forecast_models (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'model', model_type text NOT NULL DEFAULT 'rolling',
 status text NOT NULL DEFAULT 'active', summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.forecast_results (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 model_id uuid REFERENCES public.forecast_models(id) ON DELETE SET NULL,
 code text UNIQUE, title text NOT NULL, category text NOT NULL DEFAULT 'forecast',
 forecast_type text NOT NULL DEFAULT 'rolling', status text NOT NULL DEFAULT 'active',
 severity text NOT NULL DEFAULT 'info', value numeric, unit text DEFAULT 'currency',
 confidence_pct numeric(5,2), summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.treasury_accounts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'treasury', account_type text NOT NULL DEFAULT 'operating',
 status text NOT NULL DEFAULT 'active', severity text NOT NULL DEFAULT 'info',
 currency text DEFAULT 'NGN', balance numeric, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.treasury_transactions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 account_id uuid REFERENCES public.treasury_accounts(id) ON DELETE CASCADE,
 title text NOT NULL, category text NOT NULL DEFAULT 'transfer',
 status text NOT NULL DEFAULT 'posted', amount numeric, direction text DEFAULT 'in',
 summary text, occurred_at timestamptz NOT NULL DEFAULT now(),
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.cash_flow_snapshots (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'monthly', status text NOT NULL DEFAULT 'ok',
 severity text NOT NULL DEFAULT 'info', inflow numeric, outflow numeric, net_amount numeric,
 summary text, recorded_at timestamptz NOT NULL DEFAULT now(),
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.cash_flow_forecasts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'forecast', status text NOT NULL DEFAULT 'active',
 severity text NOT NULL DEFAULT 'info', horizon_weeks int DEFAULT 13, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.capital_projects (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'capex', status text NOT NULL DEFAULT 'proposed',
 severity text NOT NULL DEFAULT 'info', approved_budget numeric, actual_spend numeric,
 roi_pct numeric, payback_years numeric, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.capital_allocations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 project_id uuid REFERENCES public.capital_projects(id) ON DELETE CASCADE,
 title text NOT NULL, category text NOT NULL DEFAULT 'allocation',
 status text NOT NULL DEFAULT 'allocated', amount numeric, summary text,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.capital_roi (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 project_id uuid REFERENCES public.capital_projects(id) ON DELETE CASCADE,
 title text NOT NULL, category text NOT NULL DEFAULT 'roi',
 status text NOT NULL DEFAULT 'calculated', npv numeric, irr_pct numeric,
 payback_years numeric, summary text,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.financial_consolidations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'consolidation', status text NOT NULL DEFAULT 'ready',
 period_label text, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.scenario_models (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'scenario', scenario_type text NOT NULL DEFAULT 'expected',
 status text NOT NULL DEFAULT 'modeled', severity text NOT NULL DEFAULT 'info',
 summary text, assumptions jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.scenario_results (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 scenario_id uuid REFERENCES public.scenario_models(id) ON DELETE CASCADE,
 title text NOT NULL, category text NOT NULL DEFAULT 'result',
 status text NOT NULL DEFAULT 'ready', impact_amount numeric, summary text,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.executive_kpis (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'kpi', metric_key text NOT NULL,
 status text NOT NULL DEFAULT 'ok', severity text NOT NULL DEFAULT 'info',
 target_value numeric, actual_value numeric, unit text DEFAULT 'pct', summary text,
 recorded_at timestamptz NOT NULL DEFAULT now(),
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.strategic_objectives (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'objective', status text NOT NULL DEFAULT 'active',
 owner_label text, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.corporate_performance_metrics (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'metric', metric_key text NOT NULL,
 status text NOT NULL DEFAULT 'ok', severity text NOT NULL DEFAULT 'info',
 value numeric, variance_pct numeric, unit text DEFAULT 'pct', summary text,
 recorded_at timestamptz NOT NULL DEFAULT now(),
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.board_reports (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'report', report_type text NOT NULL DEFAULT 'board_pack',
 status text NOT NULL DEFAULT 'draft', severity text NOT NULL DEFAULT 'info',
 summary text, published_at timestamptz,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.financial_risk_indicators (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'risk', status text NOT NULL DEFAULT 'watch',
 severity text NOT NULL DEFAULT 'medium', risk_type text, threshold_value numeric,
 current_value numeric, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.epm_activity_logs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), action text NOT NULL, title text NOT NULL,
 category text NOT NULL DEFAULT 'epm', actor_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
 actor_label text, entity_type text, entity_id uuid, severity text NOT NULL DEFAULT 'info',
 status text NOT NULL DEFAULT 'recorded', summary text, metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 occurred_at timestamptz NOT NULL DEFAULT now(),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.epm_notifications (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), recipient_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
 title text NOT NULL, category text NOT NULL DEFAULT 'epm', channel text NOT NULL DEFAULT 'in_app',
 severity text NOT NULL DEFAULT 'info', status text NOT NULL DEFAULT 'unread', body text,
 read_at timestamptz, metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.epm_ai_insights (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 body text NOT NULL, category text NOT NULL DEFAULT 'epm', insight_type text NOT NULL,
 confidence_pct numeric(5,2), status text NOT NULL DEFAULT 'active', editable boolean NOT NULL DEFAULT true,
 disclaimer text NOT NULL DEFAULT 'AI-generated — editable / advisory',
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_budget_versions_status ON public.budget_versions(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_budget_approvals_status ON public.budget_approvals(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_forecast_results_status ON public.forecast_results(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_treasury_accounts_status ON public.treasury_accounts(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_capital_projects_status ON public.capital_projects(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_executive_kpis_key ON public.executive_kpis(metric_key, recorded_at DESC);

INSERT INTO storage.buckets (id,name,public) VALUES ('epm-artifacts','epm-artifacts',false)
ON CONFLICT (id) DO NOTHING;

DO $$ BEGIN
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.budget_approvals; EXCEPTION WHEN duplicate_object THEN NULL; END;
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.forecast_results; EXCEPTION WHEN duplicate_object THEN NULL; END;
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.treasury_transactions; EXCEPTION WHEN duplicate_object THEN NULL; END;
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.cash_flow_snapshots; EXCEPTION WHEN duplicate_object THEN NULL; END;
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.executive_kpis; EXCEPTION WHEN duplicate_object THEN NULL; END;
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.epm_notifications; EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

DO $$
DECLARE t text;
BEGIN
 FOREACH t IN ARRAY ARRAY[
  'budget_cycles','budget_versions','budget_items','budget_approvals',
  'financial_plans','financial_plan_versions','forecast_models','forecast_results',
  'treasury_accounts','treasury_transactions','cash_flow_snapshots','cash_flow_forecasts',
  'capital_projects','capital_allocations','capital_roi','financial_consolidations',
  'scenario_models','scenario_results','executive_kpis','strategic_objectives',
  'corporate_performance_metrics','board_reports','financial_risk_indicators',
  'epm_activity_logs','epm_notifications','epm_ai_insights'
 ] LOOP
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
  EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_select', t);
  EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_write', t);
  EXECUTE format(
   'CREATE POLICY %I ON public.%I FOR SELECT USING (public.has_permission(''epm.read'', auth.uid()) OR public.has_permission(''epm.admin'', auth.uid()) OR public.has_role(''super_admin'', auth.uid()))',
   t || '_select', t
  );
  EXECUTE format(
   'CREATE POLICY %I ON public.%I FOR ALL USING (public.has_permission(''epm.write'', auth.uid()) OR public.has_permission(''epm.admin'', auth.uid()) OR public.has_role(''super_admin'', auth.uid())) WITH CHECK (public.has_permission(''epm.write'', auth.uid()) OR public.has_permission(''epm.admin'', auth.uid()) OR public.has_role(''super_admin'', auth.uid()))',
   t || '_write', t
  );
 END LOOP;
END $$;

GRANT SELECT, INSERT, UPDATE, DELETE ON
 public.budget_cycles, public.budget_versions, public.budget_items, public.budget_approvals,
 public.financial_plans, public.financial_plan_versions, public.forecast_models, public.forecast_results,
 public.treasury_accounts, public.treasury_transactions, public.cash_flow_snapshots, public.cash_flow_forecasts,
 public.capital_projects, public.capital_allocations, public.capital_roi, public.financial_consolidations,
 public.scenario_models, public.scenario_results, public.executive_kpis, public.strategic_objectives,
 public.corporate_performance_metrics, public.board_reports, public.financial_risk_indicators,
 public.epm_activity_logs, public.epm_notifications, public.epm_ai_insights
TO authenticated;

-- Phase 1 demo seeds (hex-only f230…).
INSERT INTO public.budget_cycles (id,code,title,category,status,fiscal_year,summary) VALUES
 ('f2300001-0000-4000-8000-000000000010','BC-FY2026','FY2026 Budget Cycle','annual','active',2026,'Primary operating and capital cycle')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.budget_versions (id,cycle_id,code,title,category,status,version_label,total_amount,summary) VALUES
 ('f2300001-0000-4000-8000-000000000001','f2300001-0000-4000-8000-000000000010','BV-DEV-2026','FY2026 Development Budget','annual','awaiting_approval','v1.0',2400000000,'₦2.4B · CFO review pending'),
 ('f2300001-0000-4000-8000-000000000002','f2300001-0000-4000-8000-000000000010','BV-MKT-2026','Marketing OPEX FY2026','departmental','active','v1.0',180000000,'₦180M allocated · 62% utilized')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.budget_approvals (id,version_id,title,status,approver_label,summary) VALUES
 ('f2300001-0000-4000-8000-000000000011','f2300001-0000-4000-8000-000000000001','CFO approval — Development Budget','pending','CFO','Awaiting sign-off')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.financial_plans (id,code,title,plan_type,status,horizon_years,summary) VALUES
 ('f2300002-0000-4000-8000-000000000001','FP-STRAT-2628','3-Year Strategic Plan 2026–2028','strategic','active',3,'Revenue CAGR 18% target'),
 ('f2300002-0000-4000-8000-000000000002','FP-LEKKI-P3','Lekki expansion financial plan','project','in_review',2,'Phase 3 capex alignment')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.forecast_models (id,code,title,model_type,status,summary) VALUES
 ('f2300003-0000-4000-8000-000000000010','FM-ROLL','Rolling revenue model','rolling','active','Weekly refresh')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.forecast_results (id,model_id,code,title,category,forecast_type,status,value,confidence_pct,summary) VALUES
 ('f2300003-0000-4000-8000-000000000001','f2300003-0000-4000-8000-000000000010','FR-Q3-ROLL','Q3 Rolling Forecast','rolling','rolling','active',1050000000,91,'Revenue ₦1.05B · updated weekly'),
 ('f2300003-0000-4000-8000-000000000002','f2300003-0000-4000-8000-000000000010','FR-FY2026','FY2026 Revenue Forecast','annual','annual','active',4200000000,88,'Base case ₦4.2B')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.treasury_accounts (id,code,title,account_type,status,balance,summary) VALUES
 ('f2300004-0000-4000-8000-000000000001','TA-OPS-NGN','Operating Account NGN','operating','active',820000000,'₦820M available · 45-day runway'),
 ('f2300004-0000-4000-8000-000000000002','TA-ESCROW','Escrow Collections','escrow','active',340000000,'₦340M reserved for handovers')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.treasury_transactions (id,account_id,title,status,amount,direction,summary) VALUES
 ('f2300004-0000-4000-8000-000000000003','f2300004-0000-4000-8000-000000000001','Reservation collections','posted',95000000,'in','Weekly inbound')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.cash_flow_snapshots (id,code,title,category,status,inflow,outflow,net_amount,summary) VALUES
 ('f2300005-0000-4000-8000-000000000001','CFS-2026-07','July cash flow snapshot','monthly','ok',420000000,310000000,110000000,'Inflow ₦420M · Outflow ₦310M'),
 ('f2300005-0000-4000-8000-000000000003','CFS-13W','13-week cash forecast','forecast','watch',0,0,0,'Week 9 liquidity dip projected')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.cash_flow_forecasts (id,code,title,category,status,severity,horizon_weeks,summary) VALUES
 ('f2300005-0000-4000-8000-000000000002','CFF-13W','13-week cash forecast','forecast','watch','medium',13,'Week 9 liquidity dip projected')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.capital_projects (id,code,title,category,status,approved_budget,actual_spend,roi_pct,payback_years,summary) VALUES
 ('f2300006-0000-4000-8000-000000000001','CAP-LEKKI-P3','Lekki Phase 3 Infrastructure','capex','approved',450000000,120000000,18,4.2,'₦450M · ROI 18% · payback 4.2 yrs'),
 ('f2300006-0000-4000-8000-000000000002','CAP-ABJ-SHOW','Abuja showroom fit-out','capex','proposed',85000000,0,12,5.5,'₦85M · ROI 12%')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.capital_roi (id,project_id,title,status,npv,irr_pct,payback_years,summary) VALUES
 ('f2300006-0000-4000-8000-000000000003','f2300006-0000-4000-8000-000000000001','Lekki Phase 3 ROI model','calculated',185000000,18,4.2,'Base case NPV')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.scenario_models (id,code,title,category,scenario_type,status,severity,summary,assumptions) VALUES
 ('f2300007-0000-4000-8000-000000000001','SCN-BEST','Best Case — accelerated sales','best_case','best_case','modeled','info','Revenue +14% vs base','{"sales_uplift_pct":14}'::jsonb),
 ('f2300007-0000-4000-8000-000000000002','SCN-WORST','Worst Case — delayed handovers','worst_case','worst_case','modeled','high','Cash position -₦180M in Q4','{"handover_delay_months":3,"cash_hit":-180000000}'::jsonb)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.executive_kpis (id,code,title,metric_key,status,target_value,actual_value,unit,summary) VALUES
 ('f2300008-0000-4000-8000-000000000001','KPI-REV-PLAN','Revenue vs Plan','revenue_vs_plan','ok',100,102,'pct','102% of target YTD'),
 ('f2300008-0000-4000-8000-000000000002','KPI-EBITDA','EBITDA Margin','ebitda_margin','ok',25,28.4,'pct','28.4% · above benchmark')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.corporate_performance_metrics (id,code,title,metric_key,status,value,variance_pct,unit,summary) VALUES
 ('f2300009-0000-4000-8000-000000000001','CPM-CONV','Sales conversion rate','sales_conversion','ok',24,2,'pct','24% · +2pp vs prior quarter'),
 ('f2300009-0000-4000-8000-000000000002','CPM-COST','Construction cost variance','construction_cost_variance','watch',4.2,4.2,'pct','4.2% over plan · Lekki Phase 2')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.board_reports (id,code,title,report_type,status,summary) VALUES
 ('f230000a-0000-4000-8000-000000000001','BR-Q2-2026','Q2 Board Pack','board_pack','draft','Financial summary + capital pipeline'),
 ('f230000a-0000-4000-8000-000000000002','BR-CAP-MEMO','Capital allocation memo','memo','scheduled','Board review 28 Jul')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.financial_risk_indicators (id,code,title,status,severity,risk_type,threshold_value,current_value,summary) VALUES
 ('f230000a-0000-4000-8000-000000000003','FRI-LIQ','Liquidity runway','watch','medium','liquidity',30,45,'Days of runway above threshold')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.epm_ai_insights (id,code,title,body,insight_type,confidence_pct) VALUES
 ('f230000b-0000-4000-8000-000000000001','AI-EPM-01','Prioritize Q4 cash preservation','Week 9 liquidity dip in 13-week forecast — defer non-critical capex and accelerate escrow collections before October.','cashflow',91),
 ('f230000b-0000-4000-8000-000000000002','AI-EPM-02','Accelerate Lekki Phase 3 ROI validation','Capital project shows 18% ROI — model sensitivity against worst-case handover delays before board approval.','capital',88)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.epm_activity_logs (id,action,title,category,actor_label,entity_type,severity,status,summary) VALUES
 ('f230000c-0000-4000-8000-000000000001','budget.submitted','FY2026 budget submitted for approval','budget','Finance','budget_versions','info','recorded','BV-DEV-2026 awaiting CFO'),
 ('f230000c-0000-4000-8000-000000000002','forecast.refreshed','Q3 rolling forecast refreshed','forecast','FP&A','forecast_results','info','recorded','FR-Q3-ROLL updated')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.kpi_snapshots (id,metric_key,label,value,previous_value,unit,change_pct,series,period,metadata) VALUES
 ('f230000c-0000-4000-8000-000000000003','epm_budget_util','Budget Utilization',78,72,'pct',8.3,'[65,68,70,72,74,76,78]'::jsonb,'daily','{"module":"epm"}'),
 ('f230000c-0000-4000-8000-000000000004','epm_forecast_acc','Forecast Accuracy',92,89,'pct',3.4,'[84,86,87,88,89,90,92]'::jsonb,'daily','{"module":"epm"}'),
 ('f230000c-0000-4000-8000-000000000005','epm_cash_position','Cash Position',820,760,'currency_m',7.9,'[700,720,740,760,780,800,820]'::jsonb,'daily','{"module":"epm"}')
ON CONFLICT (id) DO NOTHING;

COMMIT;
