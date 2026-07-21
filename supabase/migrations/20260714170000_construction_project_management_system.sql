-- Volume 4 Part 6 — Enterprise Construction & Project Management System (CPMS)
-- Status: APPLIED remotely 2026-07-14 (chunked p1–p3).
--
-- Approach: NEW hierarchical CPMS tables starting at construction_projects.
-- Legacy public.projects / construction_updates / construction_photos / construction_videos
-- are left unchanged (client/investor portals). Optional FK links to estates/properties when present.
-- Seed UUIDs are hex-only (0-9a-f).

BEGIN;

-- ---------------------------------------------------------------------------
-- Permissions (NO action column — slug, name, description, module only)
-- ---------------------------------------------------------------------------
INSERT INTO public.permissions (slug, name, description, module) VALUES
  ('construction.read', 'View Construction', 'View Construction Command Center and project records', 'construction'),
  ('construction.write', 'Manage Construction', 'Create and edit construction projects and operational records', 'construction'),
  ('construction.projects', 'Manage Projects', 'Create and manage construction projects and phases', 'construction'),
  ('construction.milestones', 'Manage Milestones', 'Create and track project milestones', 'construction'),
  ('construction.tasks', 'Manage Tasks', 'Create and assign construction tasks', 'construction'),
  ('construction.procurement', 'Manage Procurement', 'Handle materials, POs, and procurement requests', 'construction'),
  ('construction.budget', 'Manage Budgets', 'View and edit project budgets and cost transactions', 'construction'),
  ('construction.quality', 'Manage Quality', 'Quality checks, defects, and inspections', 'construction'),
  ('construction.safety', 'Manage Safety', 'Safety incidents and site compliance', 'construction'),
  ('construction.analytics', 'Construction Analytics', 'View progress KPIs, forecasts, and reports', 'construction'),
  ('construction.ai', 'AI Construction Assistant', 'Use AI progress summaries and delay detection', 'construction'),
  ('construction.approvals', 'Construction Approvals', 'Approve change orders and budget exceptions', 'construction')
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  module = EXCLUDED.module,
  updated_at = now();

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE p.slug LIKE 'construction.%'
  AND (
    r.slug IN ('super_admin', 'admin')
    OR (r.slug = 'construction_manager' AND p.slug LIKE 'construction.%')
    OR (r.slug = 'finance' AND p.slug IN (
      'construction.read','construction.budget','construction.analytics','construction.approvals'
    ))
    OR (r.slug = 'sales_team' AND p.slug IN (
      'construction.read','construction.analytics'
    ))
    OR (r.slug = 'marketing' AND p.slug IN (
      'construction.read','construction.ai'
    ))
  )
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Core project hierarchy
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.construction_projects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_code text NOT NULL UNIQUE,
  name text NOT NULL,
  description text,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','planning','approved','active','on_hold','completed','archived')),
  estate_id uuid REFERENCES public.estates(id) ON DELETE SET NULL,
  property_id uuid REFERENCES public.properties(id) ON DELETE SET NULL,
  location_label text,
  manager_label text,
  start_date date,
  target_end_date date,
  actual_end_date date,
  progress_pct numeric(5,2) NOT NULL DEFAULT 0,
  budget_total numeric(16,2) NOT NULL DEFAULT 0,
  budget_spent numeric(16,2) NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'NGN',
  risk_level text NOT NULL DEFAULT 'medium'
    CHECK (risk_level IN ('low','medium','high','critical')),
  delay_days int NOT NULL DEFAULT 0,
  ai_summary text,
  forecast_completion_at date,
  forecast_confidence_pct numeric(5,2),
  forecast_disclaimer text NOT NULL DEFAULT
    'Forecasts are estimates only and are not guarantees of delivery dates or costs.',
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_construction_projects_status
  ON public.construction_projects (status);
CREATE INDEX IF NOT EXISTS idx_construction_projects_estate
  ON public.construction_projects (estate_id);

CREATE TABLE IF NOT EXISTS public.project_phases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES public.construction_projects(id) ON DELETE CASCADE,
  name text NOT NULL,
  sort_order int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'planned'
    CHECK (status IN ('planned','in_progress','completed','on_hold','cancelled')),
  progress_pct numeric(5,2) NOT NULL DEFAULT 0,
  start_date date,
  end_date date,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_project_phases_project
  ON public.project_phases (project_id, sort_order);

CREATE TABLE IF NOT EXISTS public.project_milestones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES public.construction_projects(id) ON DELETE CASCADE,
  phase_id uuid REFERENCES public.project_phases(id) ON DELETE SET NULL,
  name text NOT NULL,
  status text NOT NULL DEFAULT 'planned'
    CHECK (status IN ('planned','in_progress','completed','delayed','cancelled')),
  due_date date,
  completed_at timestamptz,
  progress_pct numeric(5,2) NOT NULL DEFAULT 0,
  is_critical boolean NOT NULL DEFAULT false,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_project_milestones_project
  ON public.project_milestones (project_id, due_date);

CREATE TABLE IF NOT EXISTS public.project_tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES public.construction_projects(id) ON DELETE CASCADE,
  phase_id uuid REFERENCES public.project_phases(id) ON DELETE SET NULL,
  milestone_id uuid REFERENCES public.project_milestones(id) ON DELETE SET NULL,
  title text NOT NULL,
  status text NOT NULL DEFAULT 'todo'
    CHECK (status IN ('todo','in_progress','blocked','done','cancelled')),
  priority text NOT NULL DEFAULT 'medium'
    CHECK (priority IN ('low','medium','high','critical')),
  assignee_label text,
  due_date date,
  progress_pct numeric(5,2) NOT NULL DEFAULT 0,
  estimated_hours numeric(8,2),
  actual_hours numeric(8,2),
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_project_tasks_project
  ON public.project_tasks (project_id, status);

CREATE TABLE IF NOT EXISTS public.project_task_dependencies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id uuid NOT NULL REFERENCES public.project_tasks(id) ON DELETE CASCADE,
  depends_on_task_id uuid NOT NULL REFERENCES public.project_tasks(id) ON DELETE CASCADE,
  dependency_type text NOT NULL DEFAULT 'finish_to_start'
    CHECK (dependency_type IN ('finish_to_start','start_to_start','finish_to_finish','start_to_finish')),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (task_id, depends_on_task_id)
);

-- ---------------------------------------------------------------------------
-- Resources, contractors, suppliers
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.project_resources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES public.construction_projects(id) ON DELETE CASCADE,
  name text NOT NULL,
  resource_type text NOT NULL DEFAULT 'labor'
    CHECK (resource_type IN ('labor','equipment','material','subcontractor','other')),
  quantity numeric(12,2) NOT NULL DEFAULT 1,
  unit text,
  unit_cost numeric(16,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'allocated'
    CHECK (status IN ('planned','allocated','in_use','released','unavailable')),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.project_teams (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES public.construction_projects(id) ON DELETE CASCADE,
  name text NOT NULL,
  lead_label text,
  member_count int NOT NULL DEFAULT 0,
  specialty text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.project_contractors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES public.construction_projects(id) ON DELETE CASCADE,
  company_name text NOT NULL,
  contact_name text,
  specialty text,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('invited','active','on_hold','completed','terminated')),
  contract_value numeric(16,2) NOT NULL DEFAULT 0,
  performance_score numeric(5,2),
  phone text,
  email text,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.project_suppliers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid REFERENCES public.construction_projects(id) ON DELETE SET NULL,
  name text NOT NULL,
  category text,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','inactive','blacklisted')),
  contact_label text,
  lead_time_days int,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.project_materials (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES public.construction_projects(id) ON DELETE CASCADE,
  sku text,
  name text NOT NULL,
  unit text NOT NULL DEFAULT 'unit',
  quantity_on_hand numeric(12,2) NOT NULL DEFAULT 0,
  quantity_reserved numeric(12,2) NOT NULL DEFAULT 0,
  unit_cost numeric(16,2) NOT NULL DEFAULT 0,
  reorder_level numeric(12,2) NOT NULL DEFAULT 0,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.project_inventory_usage (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES public.construction_projects(id) ON DELETE CASCADE,
  material_id uuid REFERENCES public.project_materials(id) ON DELETE SET NULL,
  quantity numeric(12,2) NOT NULL DEFAULT 0,
  used_at timestamptz NOT NULL DEFAULT now(),
  used_by_label text,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS public.project_procurement_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES public.construction_projects(id) ON DELETE CASCADE,
  request_code text NOT NULL UNIQUE,
  title text NOT NULL,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','submitted','approved','rejected','fulfilled','cancelled')),
  requested_by_label text,
  needed_by date,
  estimated_cost numeric(16,2) NOT NULL DEFAULT 0,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.project_purchase_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES public.construction_projects(id) ON DELETE CASCADE,
  procurement_request_id uuid REFERENCES public.project_procurement_requests(id) ON DELETE SET NULL,
  supplier_id uuid REFERENCES public.project_suppliers(id) ON DELETE SET NULL,
  po_code text NOT NULL UNIQUE,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','issued','partial','received','cancelled','closed')),
  total_amount numeric(16,2) NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'NGN',
  issued_at timestamptz,
  expected_at date,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.project_change_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES public.construction_projects(id) ON DELETE CASCADE,
  change_code text NOT NULL UNIQUE,
  title text NOT NULL,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','pending','approved','rejected','implemented','cancelled')),
  cost_impact numeric(16,2) NOT NULL DEFAULT 0,
  schedule_impact_days int NOT NULL DEFAULT 0,
  requested_by_label text,
  rationale text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Budget & cost
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.project_budget_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES public.construction_projects(id) ON DELETE CASCADE,
  category text NOT NULL,
  description text,
  budgeted_amount numeric(16,2) NOT NULL DEFAULT 0,
  committed_amount numeric(16,2) NOT NULL DEFAULT 0,
  spent_amount numeric(16,2) NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'NGN',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.project_cost_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES public.construction_projects(id) ON DELETE CASCADE,
  budget_line_id uuid REFERENCES public.project_budget_lines(id) ON DELETE SET NULL,
  tx_code text,
  label text NOT NULL,
  amount numeric(16,2) NOT NULL DEFAULT 0,
  tx_type text NOT NULL DEFAULT 'expense'
    CHECK (tx_type IN ('expense','commitment','credit','adjustment')),
  occurred_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

-- ---------------------------------------------------------------------------
-- Quality, safety, site diaries, inspections
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.project_quality_checks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES public.construction_projects(id) ON DELETE CASCADE,
  title text NOT NULL,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','passed','failed','waived')),
  checked_at timestamptz,
  inspector_label text,
  score_pct numeric(5,2),
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.project_defects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES public.construction_projects(id) ON DELETE CASCADE,
  title text NOT NULL,
  severity text NOT NULL DEFAULT 'medium'
    CHECK (severity IN ('low','medium','high','critical')),
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','in_progress','resolved','closed','wont_fix')),
  location_label text,
  reported_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.project_safety_incidents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES public.construction_projects(id) ON DELETE CASCADE,
  title text NOT NULL,
  severity text NOT NULL DEFAULT 'medium'
    CHECK (severity IN ('low','medium','high','critical')),
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','investigating','mitigated','closed')),
  occurred_at timestamptz NOT NULL DEFAULT now(),
  location_label text,
  reported_by_label text,
  description text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.project_site_diaries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES public.construction_projects(id) ON DELETE CASCADE,
  entry_date date NOT NULL DEFAULT CURRENT_DATE,
  weather text,
  workforce_count int,
  summary text NOT NULL,
  blockers text,
  author_label text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.project_inspections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES public.construction_projects(id) ON DELETE CASCADE,
  title text NOT NULL,
  inspection_type text NOT NULL DEFAULT 'site'
    CHECK (inspection_type IN ('site','quality','safety','handover','statutory')),
  status text NOT NULL DEFAULT 'scheduled'
    CHECK (status IN ('scheduled','in_progress','passed','failed','rescheduled','cancelled')),
  scheduled_at timestamptz,
  completed_at timestamptz,
  inspector_label text,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.project_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES public.construction_projects(id) ON DELETE CASCADE,
  title text NOT NULL,
  doc_type text NOT NULL DEFAULT 'general',
  storage_path text,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft','active','archived')),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.project_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid REFERENCES public.construction_projects(id) ON DELETE SET NULL,
  report_code text NOT NULL UNIQUE,
  title text NOT NULL,
  report_type text NOT NULL DEFAULT 'progress',
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  forecast_disclaimer text NOT NULL DEFAULT
    'Forecasts and predictions are estimates only and are not guarantees.',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.project_activity_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid REFERENCES public.construction_projects(id) ON DELETE SET NULL,
  event_type text NOT NULL DEFAULT 'note',
  title text NOT NULL,
  description text,
  actor_label text,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS public.project_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid REFERENCES public.construction_projects(id) ON DELETE SET NULL,
  title text NOT NULL,
  body text,
  severity text NOT NULL DEFAULT 'info'
    CHECK (severity IN ('info','warning','critical')),
  status text NOT NULL DEFAULT 'unread'
    CHECK (status IN ('unread','read','dismissed')),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.project_risk_register (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES public.construction_projects(id) ON DELETE CASCADE,
  title text NOT NULL,
  severity text NOT NULL DEFAULT 'medium'
    CHECK (severity IN ('low','medium','high','critical')),
  likelihood text NOT NULL DEFAULT 'possible'
    CHECK (likelihood IN ('rare','unlikely','possible','likely','almost_certain')),
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','monitoring','mitigating','closed')),
  mitigation text,
  owner_label text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.project_equipment (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid REFERENCES public.construction_projects(id) ON DELETE SET NULL,
  name text NOT NULL,
  equipment_type text,
  status text NOT NULL DEFAULT 'available'
    CHECK (status IN ('available','in_use','maintenance','retired')),
  daily_rate numeric(16,2) NOT NULL DEFAULT 0,
  location_label text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Demo seeds (hex-only UUIDs) — optionally link Victoria Crest estate/property
-- ---------------------------------------------------------------------------
INSERT INTO public.construction_projects (
  id, project_code, name, description, status, location_label, manager_label,
  start_date, target_end_date, progress_pct, budget_total, budget_spent,
  risk_level, delay_days, ai_summary, forecast_completion_at, forecast_confidence_pct,
  forecast_disclaimer, notes, metadata, estate_id, property_id
)
SELECT
  'c1000000-0000-4000-8000-000000000001'::uuid,
  'CPMS-VC-PH1',
  'Victoria Crest — Phase 1 Residential',
  'Active residential estate phase: substructure through finishes for Block A/B.',
  'active',
  'Lekki Phase 1, Lagos',
  'Engr. Tunde Balogun',
  CURRENT_DATE - 120,
  CURRENT_DATE + 90,
  62.5,
  1850000000,
  980000000,
  'medium',
  0,
  'On track for envelope close; MEP first-fix remaining in Block B.',
  CURRENT_DATE + 95,
  78.0,
  'Forecasts are estimates only and are not guarantees of delivery dates or costs.',
  'Primary active CPMS demo project.',
  '{"demo":true,"story":"active_residential"}'::jsonb,
  (SELECT id FROM public.estates WHERE slug = 'victoria-crest-estate' LIMIT 1),
  (SELECT id FROM public.properties WHERE slug = 'victoria-crest-unit-4' LIMIT 1)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  status = EXCLUDED.status,
  progress_pct = EXCLUDED.progress_pct,
  estate_id = COALESCE(EXCLUDED.estate_id, public.construction_projects.estate_id),
  property_id = COALESCE(EXCLUDED.property_id, public.construction_projects.property_id),
  updated_at = now();

INSERT INTO public.construction_projects (
  id, project_code, name, description, status, location_label, manager_label,
  start_date, target_end_date, progress_pct, budget_total, budget_spent,
  risk_level, delay_days, ai_summary, forecast_completion_at, forecast_confidence_pct,
  forecast_disclaimer, notes, metadata
) VALUES (
  'c1000000-0000-4000-8000-000000000002'::uuid,
  'CPMS-AJ-RD',
  'Ajah Road Extension — Infrastructure',
  'Delayed infrastructure corridor: drainage and access road delayed by utility relocations.',
  'on_hold',
  'Ajah, Lagos',
  'Engr. Ngozi Eze',
  CURRENT_DATE - 200,
  CURRENT_DATE - 30,
  41.0,
  620000000,
  410000000,
  'high',
  45,
  'Critical path slipped 45 days awaiting utility clearances and change-order approval.',
  CURRENT_DATE + 60,
  52.0,
  'Forecasts are estimates only and are not guarantees of delivery dates or costs. Confidence reflects incomplete utility data.',
  'Delayed demo project for war-room scenarios.',
  '{"demo":true,"story":"delayed"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  status = EXCLUDED.status,
  delay_days = EXCLUDED.delay_days,
  updated_at = now();

INSERT INTO public.construction_projects (
  id, project_code, name, description, status, location_label, manager_label,
  start_date, target_end_date, progress_pct, budget_total, budget_spent,
  risk_level, delay_days, ai_summary, forecast_completion_at, forecast_confidence_pct,
  forecast_disclaimer, notes, metadata
) VALUES (
  'c1000000-0000-4000-8000-000000000003'::uuid,
  'CPMS-IK-SNAG',
  'Ikoyi Showhome — Snag & Handover',
  'Near-completion showhome finishing, snag remediation, and sales handover package.',
  'active',
  'Ikoyi, Lagos',
  'Arch. Femi Adeyemi',
  CURRENT_DATE - 300,
  CURRENT_DATE + 21,
  92.0,
  145000000,
  138000000,
  'low',
  0,
  'Punch-list closing; schedule client inspection next week.',
  CURRENT_DATE + 18,
  88.0,
  'Forecasts are estimates only and are not guarantees of delivery dates or costs.',
  'Near-completion demo for quality & handover coordination.',
  '{"demo":true,"story":"near_completion"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  progress_pct = EXCLUDED.progress_pct,
  updated_at = now();

-- Phases
INSERT INTO public.project_phases (id, project_id, name, sort_order, status, progress_pct, start_date, end_date) VALUES
  ('c2000000-0000-4000-8000-000000000001'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid, 'Enabling Works', 10, 'completed', 100, CURRENT_DATE - 120, CURRENT_DATE - 90),
  ('c2000000-0000-4000-8000-000000000002'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid, 'Superstructure', 20, 'in_progress', 70, CURRENT_DATE - 90, CURRENT_DATE + 30),
  ('c2000000-0000-4000-8000-000000000003'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid, 'MEP & Finishes', 30, 'planned', 15, CURRENT_DATE + 20, CURRENT_DATE + 90),
  ('c2000000-0000-4000-8000-000000000004'::uuid, 'c1000000-0000-4000-8000-000000000002'::uuid, 'Drainage Corridor', 10, 'on_hold', 45, CURRENT_DATE - 180, CURRENT_DATE - 10),
  ('c2000000-0000-4000-8000-000000000005'::uuid, 'c1000000-0000-4000-8000-000000000003'::uuid, 'Snagging', 10, 'in_progress', 85, CURRENT_DATE - 40, CURRENT_DATE + 14)
ON CONFLICT (id) DO NOTHING;

-- Milestones
INSERT INTO public.project_milestones (
  id, project_id, phase_id, name, status, due_date, progress_pct, is_critical, notes
) VALUES
  ('c3000000-0000-4000-8000-000000000001'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid, 'c2000000-0000-4000-8000-000000000002'::uuid,
   'Block A roof structure', 'in_progress', CURRENT_DATE + 14, 68, true, 'Critical path envelope'),
  ('c3000000-0000-4000-8000-000000000002'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid, 'c2000000-0000-4000-8000-000000000003'::uuid,
   'MEP first-fix Block B', 'planned', CURRENT_DATE + 45, 10, true, NULL),
  ('c3000000-0000-4000-8000-000000000003'::uuid, 'c1000000-0000-4000-8000-000000000002'::uuid, 'c2000000-0000-4000-8000-000000000004'::uuid,
   'Utility relocation clearance', 'delayed', CURRENT_DATE - 20, 35, true, 'Blocked on agency permits'),
  ('c3000000-0000-4000-8000-000000000004'::uuid, 'c1000000-0000-4000-8000-000000000003'::uuid, 'c2000000-0000-4000-8000-000000000005'::uuid,
   'Client snag walkthrough', 'planned', CURRENT_DATE + 10, 0, false, 'Sales handover coordination')
ON CONFLICT (id) DO NOTHING;

-- Tasks
INSERT INTO public.project_tasks (
  id, project_id, phase_id, milestone_id, title, status, priority, assignee_label, due_date, progress_pct, estimated_hours
) VALUES
  ('c4000000-0000-4000-8000-000000000001'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid, 'c2000000-0000-4000-8000-000000000002'::uuid, 'c3000000-0000-4000-8000-000000000001'::uuid,
   'Install roof trusses Block A', 'in_progress', 'high', 'Steelworks Team', CURRENT_DATE + 7, 55, 120),
  ('c4000000-0000-4000-8000-000000000002'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid, 'c2000000-0000-4000-8000-000000000002'::uuid, 'c3000000-0000-4000-8000-000000000001'::uuid,
   'Waterproofing inspection prep', 'todo', 'medium', 'QA Lead', CURRENT_DATE + 12, 0, 16),
  ('c4000000-0000-4000-8000-000000000003'::uuid, 'c1000000-0000-4000-8000-000000000002'::uuid, 'c2000000-0000-4000-8000-000000000004'::uuid, 'c3000000-0000-4000-8000-000000000003'::uuid,
   'Chase utility permit package', 'blocked', 'critical', 'PM Office', CURRENT_DATE - 5, 40, 40),
  ('c4000000-0000-4000-8000-000000000004'::uuid, 'c1000000-0000-4000-8000-000000000003'::uuid, 'c2000000-0000-4000-8000-000000000005'::uuid, 'c3000000-0000-4000-8000-000000000004'::uuid,
   'Close bathroom snags', 'in_progress', 'high', 'Finishes Crew', CURRENT_DATE + 5, 70, 48),
  ('c4000000-0000-4000-8000-000000000005'::uuid, 'c1000000-0000-4000-8000-000000000003'::uuid, 'c2000000-0000-4000-8000-000000000005'::uuid, NULL,
   'Compile handover dossier', 'todo', 'medium', 'Document Control', CURRENT_DATE + 14, 20, 24)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.project_task_dependencies (id, task_id, depends_on_task_id, dependency_type) VALUES
  ('c4100000-0000-4000-8000-000000000001'::uuid, 'c4000000-0000-4000-8000-000000000002'::uuid, 'c4000000-0000-4000-8000-000000000001'::uuid, 'finish_to_start')
ON CONFLICT DO NOTHING;

-- Teams / contractors / suppliers / materials
INSERT INTO public.project_teams (id, project_id, name, lead_label, member_count, specialty) VALUES
  ('c5000000-0000-4000-8000-000000000001'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid, 'Superstructure Crew', 'Bayo Lawal', 18, 'structural'),
  ('c5000000-0000-4000-8000-000000000002'::uuid, 'c1000000-0000-4000-8000-000000000003'::uuid, 'Snag Squad', 'Chioma Okeke', 6, 'finishes')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.project_contractors (
  id, project_id, company_name, contact_name, specialty, status, contract_value, performance_score
) VALUES
  ('c5100000-0000-4000-8000-000000000001'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid,
   'Apex Steelworks Ltd', 'Ibrahim Musa', 'structural_steel', 'active', 240000000, 86),
  ('c5100000-0000-4000-8000-000000000002'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid,
   'BlueLine MEP Partners', 'Sarah Nwosu', 'mep', 'active', 180000000, 81),
  ('c5100000-0000-4000-8000-000000000003'::uuid, 'c1000000-0000-4000-8000-000000000002'::uuid,
   'Delta Civil Works', 'Kunle Ade', 'civil', 'on_hold', 95000000, 62)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.project_suppliers (id, project_id, name, category, status, contact_label, lead_time_days) VALUES
  ('c5200000-0000-4000-8000-000000000001'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid, 'CementCo West Africa', 'cement', 'active', 'Desk Sales', 5),
  ('c5200000-0000-4000-8000-000000000002'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid, 'Lagos Timber Supply', 'timber', 'active', 'Store Manager', 7)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.project_materials (id, project_id, sku, name, unit, quantity_on_hand, quantity_reserved, unit_cost, reorder_level) VALUES
  ('c5300000-0000-4000-8000-000000000001'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid, 'CEM-42.5', 'Portland Cement 42.5', 'bag', 1200, 400, 6500, 300),
  ('c5300000-0000-4000-8000-000000000002'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid, 'STL-Y12', 'Y12 Reinforcement Bars', 'ton', 48, 12, 890000, 10),
  ('c5300000-0000-4000-8000-000000000003'::uuid, 'c1000000-0000-4000-8000-000000000003'::uuid, 'TILE-60', 'Porcelain Floor Tile 60x60', 'sqm', 320, 80, 12500, 50)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.project_inventory_usage (id, project_id, material_id, quantity, used_by_label, notes) VALUES
  ('c5310000-0000-4000-8000-000000000001'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid, 'c5300000-0000-4000-8000-000000000001'::uuid, 180, 'Site Store', 'Pour sequence Block A slab'),
  ('c5310000-0000-4000-8000-000000000002'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid, 'c5300000-0000-4000-8000-000000000002'::uuid, 6.5, 'Steelworks Team', 'Roof truss fabrication')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.project_procurement_requests (
  id, project_id, request_code, title, status, requested_by_label, needed_by, estimated_cost, notes
) VALUES
  ('c5400000-0000-4000-8000-000000000001'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid,
   'PR-VC-001', 'Additional waterproofing membrane', 'approved', 'QA Lead', CURRENT_DATE + 10, 4200000, NULL),
  ('c5400000-0000-4000-8000-000000000002'::uuid, 'c1000000-0000-4000-8000-000000000002'::uuid,
   'PR-AJ-002', 'Storm drain culvert sections', 'submitted', 'PM Office', CURRENT_DATE + 21, 18500000, 'Pending CO approval')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.project_purchase_orders (
  id, project_id, procurement_request_id, supplier_id, po_code, status, total_amount, issued_at, expected_at
) VALUES
  ('c5500000-0000-4000-8000-000000000001'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid,
   'c5400000-0000-4000-8000-000000000001'::uuid, 'c5200000-0000-4000-8000-000000000001'::uuid,
   'PO-VC-088', 'issued', 4200000, now() - interval '2 days', CURRENT_DATE + 8)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.project_change_orders (
  id, project_id, change_code, title, status, cost_impact, schedule_impact_days, requested_by_label, rationale
) VALUES
  ('c5600000-0000-4000-8000-000000000001'::uuid, 'c1000000-0000-4000-8000-000000000002'::uuid,
   'CO-AJ-014', 'Utility relocation scope increase', 'pending', 28500000, 30, 'Engr. Ngozi Eze',
   'Agency requires deeper trench and protective sleeves — awaiting finance/PM approval.'),
  ('c5600000-0000-4000-8000-000000000002'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid,
   'CO-VC-003', 'Extra balcony waterproofing detail', 'approved', 6500000, 5, 'Arch. Team',
   'Approved design strengthening after monsoon risk review.')
ON CONFLICT (id) DO NOTHING;

-- Budget lines + cost txs
INSERT INTO public.project_budget_lines (
  id, project_id, category, description, budgeted_amount, committed_amount, spent_amount
) VALUES
  ('c6000000-0000-4000-8000-000000000001'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid, 'Structural', 'Concrete, steel, formwork', 720000000, 510000000, 445000000),
  ('c6000000-0000-4000-8000-000000000002'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid, 'MEP', 'Electrical, plumbing, HVAC packages', 380000000, 210000000, 98000000),
  ('c6000000-0000-4000-8000-000000000003'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid, 'Finishes', 'Tiles, joinery, paint', 290000000, 120000000, 65000000),
  ('c6000000-0000-4000-8000-000000000004'::uuid, 'c1000000-0000-4000-8000-000000000002'::uuid, 'Civil Works', 'Drainage and road formation', 410000000, 350000000, 300000000),
  ('c6000000-0000-4000-8000-000000000005'::uuid, 'c1000000-0000-4000-8000-000000000003'::uuid, 'Snag & Handover', 'Remediation and soft FF&E', 22000000, 18000000, 16000000)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.project_cost_transactions (id, project_id, budget_line_id, tx_code, label, amount, tx_type, occurred_at) VALUES
  ('c6100000-0000-4000-8000-000000000001'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid, 'c6000000-0000-4000-8000-000000000001'::uuid,
   'CTX-001', 'Steel supply batch 4', 89000000, 'expense', now() - interval '5 days'),
  ('c6100000-0000-4000-8000-000000000002'::uuid, 'c1000000-0000-4000-8000-000000000002'::uuid, 'c6000000-0000-4000-8000-000000000004'::uuid,
   'CTX-014', 'Interim civil certificate', 45000000, 'expense', now() - interval '12 days')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.project_resources (id, project_id, name, resource_type, quantity, unit, unit_cost, status) VALUES
  ('c6200000-0000-4000-8000-000000000001'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid, 'Tower crane TC-01', 'equipment', 1, 'unit', 450000, 'in_use'),
  ('c6200000-0000-4000-8000-000000000002'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid, 'Carpenters (day shift)', 'labor', 12, 'pax', 35000, 'allocated')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.project_equipment (id, project_id, name, equipment_type, status, daily_rate, location_label) VALUES
  ('c6300000-0000-4000-8000-000000000001'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid, 'Concrete mixer CM-3', 'mixer', 'in_use', 85000, 'Block A yard'),
  ('c6300000-0000-4000-8000-000000000002'::uuid, 'c1000000-0000-4000-8000-000000000002'::uuid, 'Excavator EX-7', 'excavator', 'maintenance', 220000, 'Ajah depot')
ON CONFLICT (id) DO NOTHING;

-- Quality / defects / safety / diaries / inspections
INSERT INTO public.project_quality_checks (id, project_id, title, status, checked_at, inspector_label, score_pct, notes) VALUES
  ('c7000000-0000-4000-8000-000000000001'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid,
   'Slab level survey Block A', 'passed', now() - interval '3 days', 'QA Lead', 94, NULL),
  ('c7000000-0000-4000-8000-000000000002'::uuid, 'c1000000-0000-4000-8000-000000000003'::uuid,
   'Paint adhesion sample', 'failed', now() - interval '1 day', 'Finishes QA', 62, 'Re-prep guest bath walls')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.project_defects (id, project_id, title, severity, status, location_label, notes) VALUES
  ('c7100000-0000-4000-8000-000000000001'::uuid, 'c1000000-0000-4000-8000-000000000003'::uuid,
   'Hairline crack — guest bath tile joint', 'medium', 'in_progress', 'Showhome en-suite', 'Remediation scheduled'),
  ('c7100000-0000-4000-8000-000000000002'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid,
   'Missing firestop sleeve Level 2', 'high', 'open', 'Block B riser', 'Safety-linked defect')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.project_safety_incidents (
  id, project_id, title, severity, status, occurred_at, location_label, reported_by_label, description
) VALUES
  ('c7200000-0000-4000-8000-000000000001'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid,
   'Near-miss: unsecured scaffold plank', 'high', 'investigating', now() - interval '2 days',
   'Block A east elevation', 'HSE Officer', 'Worker reported loose plank before shift. Access closed pending scaffolding audit.')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.project_site_diaries (id, project_id, entry_date, weather, workforce_count, summary, blockers, author_label) VALUES
  ('c7300000-0000-4000-8000-000000000001'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid,
   CURRENT_DATE - 1, 'Partly cloudy', 46, 'Roof trusses installed on grids A1–A4. Concrete team prepping pour for tomorrow.', NULL, 'Site Agent'),
  ('c7300000-0000-4000-8000-000000000002'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid,
   CURRENT_DATE, 'Light rain AM', 41, 'Waterproofing prep delayed 2h by rain. Steel delivery accepted.', 'Rain delay morning window', 'Site Agent'),
  ('c7300000-0000-4000-8000-000000000003'::uuid, 'c1000000-0000-4000-8000-000000000002'::uuid,
   CURRENT_DATE - 1, 'Overcast', 8, 'Skeleton crew on permit follow-ups only. Civil works on hold.', 'Utility permits outstanding', 'PM Office')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.project_inspections (
  id, project_id, title, inspection_type, status, scheduled_at, inspector_label, notes
) VALUES
  ('c7400000-0000-4000-8000-000000000001'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid,
   'Scaffolding safety audit', 'safety', 'scheduled', now() + interval '1 day', 'HSE Officer', 'Follow-up to near-miss'),
  ('c7400000-0000-4000-8000-000000000002'::uuid, 'c1000000-0000-4000-8000-000000000003'::uuid,
   'Pre-handover client inspection', 'handover', 'scheduled', now() + interval '10 days', 'Sales + QA', 'Coordinate with SBMS handover')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.project_documents (id, project_id, title, doc_type, status, metadata) VALUES
  ('c7500000-0000-4000-8000-000000000001'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid,
   'GFC structural drawings Rev C', 'drawing', 'active', '{"demo":true}'::jsonb),
  ('c7500000-0000-4000-8000-000000000002'::uuid, 'c1000000-0000-4000-8000-000000000003'::uuid,
   'Handover checklist draft', 'checklist', 'draft', '{"demo":true}'::jsonb)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.project_reports (
  id, project_id, report_code, title, report_type, payload, forecast_disclaimer
) VALUES
  ('c7600000-0000-4000-8000-000000000001'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid,
   'RPT-VC-PROG-01', 'Weekly progress intelligence', 'progress',
   '{"predicted_completion":"estimate","confidence_pct":78,"delay_risk":"low","disclaimer":"Forecasts are estimates only and are not guarantees."}'::jsonb,
   'Forecasts and predictions are estimates only and are not guarantees.'),
  ('c7600000-0000-4000-8000-000000000002'::uuid, 'c1000000-0000-4000-8000-000000000002'::uuid,
   'RPT-AJ-DELAY-01', 'Delay recovery forecast', 'forecast',
   '{"predicted_recovery_days":60,"confidence_pct":52,"disclaimer":"Forecasts are estimates only — subject to utility agency outcomes."}'::jsonb,
   'Forecasts and predictions are estimates only and are not guarantees.')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.project_risk_register (
  id, project_id, title, severity, likelihood, status, mitigation, owner_label
) VALUES
  ('c7700000-0000-4000-8000-000000000001'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid,
   'Monsoon waterproofing failure', 'high', 'possible', 'mitigating', 'Extra membrane detail + CO-VC-003', 'QA Lead'),
  ('c7700000-0000-4000-8000-000000000002'::uuid, 'c1000000-0000-4000-8000-000000000002'::uuid,
   'Extended utility permit lock', 'critical', 'likely', 'open', 'Escalate to agency liaison + approve CO-AJ-014', 'PM Office')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.project_activity_logs (id, project_id, event_type, title, description, actor_label, occurred_at) VALUES
  ('c7800000-0000-4000-8000-000000000001'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid,
   'milestone', 'Roof structure advanced', 'Truss install reached 55% on Block A.', 'Site Agent', now() - interval '6 hours'),
  ('c7800000-0000-4000-8000-000000000002'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid,
   'safety', 'Scaffold near-miss logged', 'HSE closed access for audit.', 'HSE Officer', now() - interval '2 days'),
  ('c7800000-0000-4000-8000-000000000003'::uuid, 'c1000000-0000-4000-8000-000000000002'::uuid,
   'change_order', 'CO-AJ-014 pending approval', 'Cost impact ₦28.5M / +30 days.', 'Engr. Ngozi Eze', now() - interval '1 day'),
  ('c7800000-0000-4000-8000-000000000004'::uuid, 'c1000000-0000-4000-8000-000000000003'::uuid,
   'quality', 'Paint adhesion failed', 'Guest bath re-prep required.', 'Finishes QA', now() - interval '1 day')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.project_notifications (id, project_id, title, body, severity, status, metadata) VALUES
  ('c7900000-0000-4000-8000-000000000001'::uuid, 'c1000000-0000-4000-8000-000000000002'::uuid,
   'Change order awaiting approval', 'CO-AJ-014 needs finance/construction approval.', 'warning', 'unread', '{"demo":true}'::jsonb),
  ('c7900000-0000-4000-8000-000000000002'::uuid, 'c1000000-0000-4000-8000-000000000001'::uuid,
   'Safety audit scheduled', 'Scaffolding inspection tomorrow after near-miss.', 'critical', 'unread', '{"demo":true}'::jsonb),
  ('c7900000-0000-4000-8000-000000000003'::uuid, 'c1000000-0000-4000-8000-000000000003'::uuid,
   'Handover inspection in 10 days', 'Align sales handover pack with snag close-out.', 'info', 'unread', '{"demo":true}'::jsonb)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.construction_projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_phases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_milestones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_task_dependencies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_resources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_contractors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_materials ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_inventory_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_procurement_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_change_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_budget_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_cost_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_quality_checks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_defects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_safety_incidents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_site_diaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_inspections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_risk_register ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_equipment ENABLE ROW LEVEL SECURITY;

-- construction_projects
DROP POLICY IF EXISTS construction_projects_select ON public.construction_projects;
DROP POLICY IF EXISTS construction_projects_write ON public.construction_projects;
CREATE POLICY construction_projects_select ON public.construction_projects FOR SELECT
  USING (
    public.has_permission('construction.read', auth.uid())
    OR public.has_permission('construction.projects', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY construction_projects_write ON public.construction_projects FOR ALL
  USING (
    public.has_permission('construction.write', auth.uid())
    OR public.has_permission('construction.projects', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('construction.write', auth.uid())
    OR public.has_permission('construction.projects', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

-- phases
DROP POLICY IF EXISTS project_phases_select ON public.project_phases;
DROP POLICY IF EXISTS project_phases_write ON public.project_phases;
CREATE POLICY project_phases_select ON public.project_phases FOR SELECT
  USING (public.has_permission('construction.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY project_phases_write ON public.project_phases FOR ALL
  USING (public.has_permission('construction.projects', auth.uid()) OR public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('construction.projects', auth.uid()) OR public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

-- milestones
DROP POLICY IF EXISTS project_milestones_select ON public.project_milestones;
DROP POLICY IF EXISTS project_milestones_write ON public.project_milestones;
CREATE POLICY project_milestones_select ON public.project_milestones FOR SELECT
  USING (
    public.has_permission('construction.read', auth.uid())
    OR public.has_permission('construction.milestones', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY project_milestones_write ON public.project_milestones FOR ALL
  USING (public.has_permission('construction.milestones', auth.uid()) OR public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('construction.milestones', auth.uid()) OR public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

-- tasks + dependencies
DROP POLICY IF EXISTS project_tasks_select ON public.project_tasks;
DROP POLICY IF EXISTS project_tasks_write ON public.project_tasks;
CREATE POLICY project_tasks_select ON public.project_tasks FOR SELECT
  USING (
    public.has_permission('construction.read', auth.uid())
    OR public.has_permission('construction.tasks', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY project_tasks_write ON public.project_tasks FOR ALL
  USING (public.has_permission('construction.tasks', auth.uid()) OR public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('construction.tasks', auth.uid()) OR public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS project_task_dependencies_select ON public.project_task_dependencies;
DROP POLICY IF EXISTS project_task_dependencies_write ON public.project_task_dependencies;
CREATE POLICY project_task_dependencies_select ON public.project_task_dependencies FOR SELECT
  USING (public.has_permission('construction.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY project_task_dependencies_write ON public.project_task_dependencies FOR ALL
  USING (public.has_permission('construction.tasks', auth.uid()) OR public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('construction.tasks', auth.uid()) OR public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

-- resources / teams / contractors / suppliers
DROP POLICY IF EXISTS project_resources_select ON public.project_resources;
DROP POLICY IF EXISTS project_resources_write ON public.project_resources;
CREATE POLICY project_resources_select ON public.project_resources FOR SELECT
  USING (public.has_permission('construction.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY project_resources_write ON public.project_resources FOR ALL
  USING (public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS project_teams_select ON public.project_teams;
DROP POLICY IF EXISTS project_teams_write ON public.project_teams;
CREATE POLICY project_teams_select ON public.project_teams FOR SELECT
  USING (public.has_permission('construction.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY project_teams_write ON public.project_teams FOR ALL
  USING (public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS project_contractors_select ON public.project_contractors;
DROP POLICY IF EXISTS project_contractors_write ON public.project_contractors;
CREATE POLICY project_contractors_select ON public.project_contractors FOR SELECT
  USING (public.has_permission('construction.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY project_contractors_write ON public.project_contractors FOR ALL
  USING (public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS project_suppliers_select ON public.project_suppliers;
DROP POLICY IF EXISTS project_suppliers_write ON public.project_suppliers;
CREATE POLICY project_suppliers_select ON public.project_suppliers FOR SELECT
  USING (public.has_permission('construction.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY project_suppliers_write ON public.project_suppliers FOR ALL
  USING (public.has_permission('construction.procurement', auth.uid()) OR public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('construction.procurement', auth.uid()) OR public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

-- procurement stack
DROP POLICY IF EXISTS project_materials_select ON public.project_materials;
DROP POLICY IF EXISTS project_materials_write ON public.project_materials;
CREATE POLICY project_materials_select ON public.project_materials FOR SELECT
  USING (
    public.has_permission('construction.read', auth.uid())
    OR public.has_permission('construction.procurement', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY project_materials_write ON public.project_materials FOR ALL
  USING (public.has_permission('construction.procurement', auth.uid()) OR public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('construction.procurement', auth.uid()) OR public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS project_inventory_usage_select ON public.project_inventory_usage;
DROP POLICY IF EXISTS project_inventory_usage_write ON public.project_inventory_usage;
CREATE POLICY project_inventory_usage_select ON public.project_inventory_usage FOR SELECT
  USING (public.has_permission('construction.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY project_inventory_usage_write ON public.project_inventory_usage FOR ALL
  USING (public.has_permission('construction.procurement', auth.uid()) OR public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('construction.procurement', auth.uid()) OR public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS project_procurement_requests_select ON public.project_procurement_requests;
DROP POLICY IF EXISTS project_procurement_requests_write ON public.project_procurement_requests;
CREATE POLICY project_procurement_requests_select ON public.project_procurement_requests FOR SELECT
  USING (
    public.has_permission('construction.read', auth.uid())
    OR public.has_permission('construction.procurement', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY project_procurement_requests_write ON public.project_procurement_requests FOR ALL
  USING (public.has_permission('construction.procurement', auth.uid()) OR public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('construction.procurement', auth.uid()) OR public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS project_purchase_orders_select ON public.project_purchase_orders;
DROP POLICY IF EXISTS project_purchase_orders_write ON public.project_purchase_orders;
CREATE POLICY project_purchase_orders_select ON public.project_purchase_orders FOR SELECT
  USING (
    public.has_permission('construction.read', auth.uid())
    OR public.has_permission('construction.procurement', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY project_purchase_orders_write ON public.project_purchase_orders FOR ALL
  USING (public.has_permission('construction.procurement', auth.uid()) OR public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('construction.procurement', auth.uid()) OR public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS project_change_orders_select ON public.project_change_orders;
DROP POLICY IF EXISTS project_change_orders_write ON public.project_change_orders;
CREATE POLICY project_change_orders_select ON public.project_change_orders FOR SELECT
  USING (
    public.has_permission('construction.read', auth.uid())
    OR public.has_permission('construction.approvals', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY project_change_orders_write ON public.project_change_orders FOR ALL
  USING (
    public.has_permission('construction.approvals', auth.uid())
    OR public.has_permission('construction.write', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('construction.approvals', auth.uid())
    OR public.has_permission('construction.write', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

-- budget
DROP POLICY IF EXISTS project_budget_lines_select ON public.project_budget_lines;
DROP POLICY IF EXISTS project_budget_lines_write ON public.project_budget_lines;
CREATE POLICY project_budget_lines_select ON public.project_budget_lines FOR SELECT
  USING (
    public.has_permission('construction.read', auth.uid())
    OR public.has_permission('construction.budget', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY project_budget_lines_write ON public.project_budget_lines FOR ALL
  USING (public.has_permission('construction.budget', auth.uid()) OR public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('construction.budget', auth.uid()) OR public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS project_cost_transactions_select ON public.project_cost_transactions;
DROP POLICY IF EXISTS project_cost_transactions_write ON public.project_cost_transactions;
CREATE POLICY project_cost_transactions_select ON public.project_cost_transactions FOR SELECT
  USING (
    public.has_permission('construction.read', auth.uid())
    OR public.has_permission('construction.budget', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY project_cost_transactions_write ON public.project_cost_transactions FOR ALL
  USING (public.has_permission('construction.budget', auth.uid()) OR public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('construction.budget', auth.uid()) OR public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

-- quality / defects / safety / diary / inspections
DROP POLICY IF EXISTS project_quality_checks_select ON public.project_quality_checks;
DROP POLICY IF EXISTS project_quality_checks_write ON public.project_quality_checks;
CREATE POLICY project_quality_checks_select ON public.project_quality_checks FOR SELECT
  USING (
    public.has_permission('construction.read', auth.uid())
    OR public.has_permission('construction.quality', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY project_quality_checks_write ON public.project_quality_checks FOR ALL
  USING (public.has_permission('construction.quality', auth.uid()) OR public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('construction.quality', auth.uid()) OR public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS project_defects_select ON public.project_defects;
DROP POLICY IF EXISTS project_defects_write ON public.project_defects;
CREATE POLICY project_defects_select ON public.project_defects FOR SELECT
  USING (
    public.has_permission('construction.read', auth.uid())
    OR public.has_permission('construction.quality', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY project_defects_write ON public.project_defects FOR ALL
  USING (public.has_permission('construction.quality', auth.uid()) OR public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('construction.quality', auth.uid()) OR public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS project_safety_incidents_select ON public.project_safety_incidents;
DROP POLICY IF EXISTS project_safety_incidents_write ON public.project_safety_incidents;
CREATE POLICY project_safety_incidents_select ON public.project_safety_incidents FOR SELECT
  USING (
    public.has_permission('construction.read', auth.uid())
    OR public.has_permission('construction.safety', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY project_safety_incidents_write ON public.project_safety_incidents FOR ALL
  USING (public.has_permission('construction.safety', auth.uid()) OR public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('construction.safety', auth.uid()) OR public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS project_site_diaries_select ON public.project_site_diaries;
DROP POLICY IF EXISTS project_site_diaries_write ON public.project_site_diaries;
CREATE POLICY project_site_diaries_select ON public.project_site_diaries FOR SELECT
  USING (public.has_permission('construction.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY project_site_diaries_write ON public.project_site_diaries FOR ALL
  USING (public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS project_inspections_select ON public.project_inspections;
DROP POLICY IF EXISTS project_inspections_write ON public.project_inspections;
CREATE POLICY project_inspections_select ON public.project_inspections FOR SELECT
  USING (
    public.has_permission('construction.read', auth.uid())
    OR public.has_permission('construction.quality', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY project_inspections_write ON public.project_inspections FOR ALL
  USING (public.has_permission('construction.quality', auth.uid()) OR public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('construction.quality', auth.uid()) OR public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS project_documents_select ON public.project_documents;
DROP POLICY IF EXISTS project_documents_write ON public.project_documents;
CREATE POLICY project_documents_select ON public.project_documents FOR SELECT
  USING (public.has_permission('construction.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY project_documents_write ON public.project_documents FOR ALL
  USING (public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS project_reports_select ON public.project_reports;
DROP POLICY IF EXISTS project_reports_write ON public.project_reports;
CREATE POLICY project_reports_select ON public.project_reports FOR SELECT
  USING (
    public.has_permission('construction.read', auth.uid())
    OR public.has_permission('construction.analytics', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY project_reports_write ON public.project_reports FOR ALL
  USING (public.has_permission('construction.analytics', auth.uid()) OR public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('construction.analytics', auth.uid()) OR public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS project_activity_logs_select ON public.project_activity_logs;
DROP POLICY IF EXISTS project_activity_logs_write ON public.project_activity_logs;
CREATE POLICY project_activity_logs_select ON public.project_activity_logs FOR SELECT
  USING (public.has_permission('construction.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY project_activity_logs_write ON public.project_activity_logs FOR ALL
  USING (public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS project_notifications_select ON public.project_notifications;
DROP POLICY IF EXISTS project_notifications_write ON public.project_notifications;
CREATE POLICY project_notifications_select ON public.project_notifications FOR SELECT
  USING (public.has_permission('construction.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY project_notifications_write ON public.project_notifications FOR ALL
  USING (public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS project_risk_register_select ON public.project_risk_register;
DROP POLICY IF EXISTS project_risk_register_write ON public.project_risk_register;
CREATE POLICY project_risk_register_select ON public.project_risk_register FOR SELECT
  USING (public.has_permission('construction.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY project_risk_register_write ON public.project_risk_register FOR ALL
  USING (public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS project_equipment_select ON public.project_equipment;
DROP POLICY IF EXISTS project_equipment_write ON public.project_equipment;
CREATE POLICY project_equipment_select ON public.project_equipment FOR SELECT
  USING (public.has_permission('construction.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY project_equipment_write ON public.project_equipment FOR ALL
  USING (public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('construction.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

-- ---------------------------------------------------------------------------
-- Realtime (key live tables)
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'construction_projects',
    'project_milestones',
    'project_tasks',
    'project_change_orders',
    'project_safety_incidents',
    'project_site_diaries',
    'project_activity_logs'
  ]
  LOOP
    BEGIN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    EXCEPTION WHEN duplicate_object THEN
      NULL;
    END;
  END LOOP;
END $$;

COMMIT;

-- Status: LOCAL ONLY — await approve before remote apply.
