-- Volume 4 Part 9 — Enterprise Human Capital Management (HCM)
-- Status: APPLIED remotely 2026-07-15 (chunked human_capital_management_p1–p3).
--
-- Approach:
--   • ENRICH existing departments, employees, employee_profiles, leave_records,
--     staff_onboarding, organization_settings (do NOT drop/recreate).
--   • CREATE IF NOT EXISTS for HCM expansions (recruitment, attendance, leave
--     requests/balances, performance, training, payroll, assets, etc.).
--   • Keep leave_records; add leave_requests + leave_balances.
--   • positions already exists from org migration — CREATE IF NOT EXISTS only.
--   • Seed UUIDs are hex-only (0-9a-f).
--   • RLS: has_permission('slug', auth.uid()) — slug FIRST.
--   • Permissions: slug, name, description, module only.

BEGIN;

-- ---------------------------------------------------------------------------
-- Permissions
-- ---------------------------------------------------------------------------
INSERT INTO public.permissions (slug, name, description, module) VALUES
  ('hr.read', 'View HR', 'View HR Command Center and workforce directory', 'hr'),
  ('hr.write', 'Manage HR', 'Create and edit core HR operational records', 'hr'),
  ('hr.employees', 'Manage Employees', 'Create and update employee records and profiles', 'hr'),
  ('hr.recruitment', 'Recruitment', 'Manage job requisitions, postings, and applicants', 'hr'),
  ('hr.attendance', 'Attendance', 'Manage attendance, shifts, and adjustments', 'hr'),
  ('hr.leave', 'Leave Management', 'Manage leave requests and balances', 'hr'),
  ('hr.performance', 'Performance', 'Manage cycles, reviews, and goals', 'hr'),
  ('hr.payroll', 'Payroll Profiles', 'View and manage payroll profiles and benefits', 'hr'),
  ('hr.analytics', 'HR Analytics', 'View workforce KPIs and HR reports', 'hr'),
  ('hr.ai', 'AI HR Assistant', 'Use Talent Intelligence and CHRO advisory stubs', 'hr'),
  ('hr.approvals', 'HR Approvals', 'Approve leave, disciplinary, and sensitive HR actions', 'hr'),
  ('hr.assets', 'Employee Assets', 'Assign and track employee assets', 'hr')
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  module = EXCLUDED.module,
  updated_at = now();

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE p.slug LIKE 'hr.%'
  AND (
    r.slug IN ('super_admin', 'admin')
    OR (r.slug = 'finance' AND p.slug IN (
      'hr.read', 'hr.payroll', 'hr.analytics', 'hr.approvals'
    ))
    OR (r.slug = 'construction_manager' AND p.slug IN (
      'hr.read', 'hr.attendance', 'hr.leave'
    ))
    OR (r.slug = 'sales_team' AND p.slug IN ('hr.read'))
    OR (r.slug = 'marketing' AND p.slug IN ('hr.read'))
  )
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Enrich existing foundation tables
-- ---------------------------------------------------------------------------
ALTER TABLE public.departments
  ADD COLUMN IF NOT EXISTS cost_center text,
  ADD COLUMN IF NOT EXISTS org_unit_id uuid,
  ADD COLUMN IF NOT EXISTS parent_department_id uuid;

ALTER TABLE public.employees
  ADD COLUMN IF NOT EXISTS display_employee_id text,
  ADD COLUMN IF NOT EXISTS job_title text,
  ADD COLUMN IF NOT EXISTS employment_type text DEFAULT 'full_time',
  ADD COLUMN IF NOT EXISTS supervisor_id uuid,
  ADD COLUMN IF NOT EXISTS hire_date date,
  ADD COLUMN IF NOT EXISTS confirmation_date date,
  ADD COLUMN IF NOT EXISTS salary_grade text,
  ADD COLUMN IF NOT EXISTS salary_band text,
  ADD COLUMN IF NOT EXISTS work_email text,
  ADD COLUMN IF NOT EXISTS work_phone text,
  ADD COLUMN IF NOT EXISTS location_label text,
  ADD COLUMN IF NOT EXISTS hcm_metadata jsonb DEFAULT '{}'::jsonb;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'employees_supervisor_id_fkey'
  ) THEN
    ALTER TABLE public.employees
      ADD CONSTRAINT employees_supervisor_id_fkey
      FOREIGN KEY (supervisor_id) REFERENCES public.employees(id) ON DELETE SET NULL;
  END IF;
END $$;

ALTER TABLE public.employee_profiles
  ADD COLUMN IF NOT EXISTS date_of_birth date,
  ADD COLUMN IF NOT EXISTS nationality text,
  ADD COLUMN IF NOT EXISTS gender text,
  ADD COLUMN IF NOT EXISTS marital_status text,
  ADD COLUMN IF NOT EXISTS address_line text,
  ADD COLUMN IF NOT EXISTS city text,
  ADD COLUMN IF NOT EXISTS state_region text,
  ADD COLUMN IF NOT EXISTS country text DEFAULT 'NG',
  ADD COLUMN IF NOT EXISTS bank_name text,
  ADD COLUMN IF NOT EXISTS bank_account_masked text,
  ADD COLUMN IF NOT EXISTS tax_id_masked text,
  ADD COLUMN IF NOT EXISTS linkedin_url text,
  ADD COLUMN IF NOT EXISTS profile_completeness numeric(5,2) DEFAULT 0;

ALTER TABLE public.leave_records
  ADD COLUMN IF NOT EXISTS leave_request_id uuid,
  ADD COLUMN IF NOT EXISTS days_count numeric(6,2),
  ADD COLUMN IF NOT EXISTS approved_by uuid,
  ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}'::jsonb;

ALTER TABLE public.staff_onboarding
  ADD COLUMN IF NOT EXISTS title text,
  ADD COLUMN IF NOT EXISTS due_at timestamptz,
  ADD COLUMN IF NOT EXISTS assignee_id uuid,
  ADD COLUMN IF NOT EXISTS sort_order int DEFAULT 0,
  ADD COLUMN IF NOT EXISTS status text DEFAULT 'pending';

ALTER TABLE public.organization_settings
  ADD COLUMN IF NOT EXISTS description text;

INSERT INTO public.organization_settings (key, value) VALUES
  ('hcm_leave_year_start_month', '1'::jsonb),
  ('hcm_probation_days', '90'::jsonb),
  ('hcm_default_work_week', '"mon_fri"'::jsonb)
ON CONFLICT (key) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Organizational units + positions (positions may already exist)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.organizational_units (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  unit_type text NOT NULL DEFAULT 'division'
    CHECK (unit_type IN ('company','division','region','branch','team','other')),
  parent_id uuid REFERENCES public.organizational_units(id) ON DELETE SET NULL,
  department_id uuid REFERENCES public.departments(id) ON DELETE SET NULL,
  head_employee_id uuid REFERENCES public.employees(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'active',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.positions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  slug text NOT NULL UNIQUE,
  department_id uuid REFERENCES public.departments(id) ON DELETE SET NULL,
  level int NOT NULL DEFAULT 1,
  description text,
  status text NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.positions
  ADD COLUMN IF NOT EXISTS salary_grade text,
  ADD COLUMN IF NOT EXISTS reports_to_position_id uuid,
  ADD COLUMN IF NOT EXISTS headcount_budget int,
  ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

-- Wire departments.org_unit_id if constraint missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'departments_org_unit_id_fkey'
  ) THEN
    ALTER TABLE public.departments
      ADD CONSTRAINT departments_org_unit_id_fkey
      FOREIGN KEY (org_unit_id) REFERENCES public.organizational_units(id) ON DELETE SET NULL;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Employee documents & skills
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.employee_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  doc_type text NOT NULL DEFAULT 'general',
  title text NOT NULL,
  file_url text,
  status text NOT NULL DEFAULT 'active',
  expires_at date,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_employee_documents_employee
  ON public.employee_documents (employee_id);

CREATE TABLE IF NOT EXISTS public.employee_skills (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  skill_name text NOT NULL,
  proficiency text NOT NULL DEFAULT 'intermediate'
    CHECK (proficiency IN ('beginner','intermediate','advanced','expert')),
  years_experience numeric(4,1),
  certified boolean NOT NULL DEFAULT false,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (employee_id, skill_name)
);

-- ---------------------------------------------------------------------------
-- Recruitment
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.job_requisitions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  requisition_code text NOT NULL UNIQUE,
  title text NOT NULL,
  department_id uuid REFERENCES public.departments(id) ON DELETE SET NULL,
  position_id uuid REFERENCES public.positions(id) ON DELETE SET NULL,
  hiring_manager_id uuid REFERENCES public.employees(id) ON DELETE SET NULL,
  headcount int NOT NULL DEFAULT 1,
  employment_type text NOT NULL DEFAULT 'full_time',
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('draft','open','on_hold','filled','cancelled')),
  location_label text,
  target_start_date date,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.job_postings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  requisition_id uuid REFERENCES public.job_requisitions(id) ON DELETE CASCADE,
  title text NOT NULL,
  slug text,
  channel text NOT NULL DEFAULT 'careers_site',
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('draft','open','closed','archived')),
  description text,
  published_at timestamptz,
  closes_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_job_postings_status ON public.job_postings (status);

CREATE TABLE IF NOT EXISTS public.applicants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  posting_id uuid REFERENCES public.job_postings(id) ON DELETE SET NULL,
  requisition_id uuid REFERENCES public.job_requisitions(id) ON DELETE SET NULL,
  full_name text NOT NULL,
  email text,
  phone text,
  stage text NOT NULL DEFAULT 'applied'
    CHECK (stage IN ('applied','screening','interview','offer','hired','rejected','withdrawn')),
  source text,
  resume_url text,
  score numeric(5,2),
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_applicants_stage ON public.applicants (stage);

CREATE TABLE IF NOT EXISTS public.applicant_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  applicant_id uuid NOT NULL REFERENCES public.applicants(id) ON DELETE CASCADE,
  doc_type text NOT NULL DEFAULT 'resume',
  title text NOT NULL,
  file_url text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.interviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  applicant_id uuid NOT NULL REFERENCES public.applicants(id) ON DELETE CASCADE,
  scheduled_at timestamptz NOT NULL,
  interview_type text NOT NULL DEFAULT 'panel',
  location_label text,
  status text NOT NULL DEFAULT 'scheduled'
    CHECK (status IN ('scheduled','completed','cancelled','no_show')),
  interviewer_employee_id uuid REFERENCES public.employees(id) ON DELETE SET NULL,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.interview_feedback (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  interview_id uuid NOT NULL REFERENCES public.interviews(id) ON DELETE CASCADE,
  reviewer_employee_id uuid REFERENCES public.employees(id) ON DELETE SET NULL,
  rating numeric(3,1),
  recommendation text,
  comments text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Onboarding checklist tasks (complements staff_onboarding)
CREATE TABLE IF NOT EXISTS public.onboarding_tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text,
  due_at timestamptz,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','in_progress','done','skipped')),
  assignee_id uuid REFERENCES public.employees(id) ON DELETE SET NULL,
  sort_order int NOT NULL DEFAULT 0,
  completed_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Attendance & shifts
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.shifts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  start_time time NOT NULL,
  end_time time NOT NULL,
  timezone text NOT NULL DEFAULT 'Africa/Lagos',
  status text NOT NULL DEFAULT 'active',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.attendance_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  work_date date NOT NULL DEFAULT CURRENT_DATE,
  shift_id uuid REFERENCES public.shifts(id) ON DELETE SET NULL,
  clock_in_at timestamptz,
  clock_out_at timestamptz,
  status text NOT NULL DEFAULT 'present'
    CHECK (status IN ('present','absent','late','remote','half_day','on_leave','holiday')),
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (employee_id, work_date)
);

CREATE INDEX IF NOT EXISTS idx_attendance_records_date
  ON public.attendance_records (work_date DESC);

CREATE TABLE IF NOT EXISTS public.attendance_adjustments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  attendance_id uuid NOT NULL REFERENCES public.attendance_records(id) ON DELETE CASCADE,
  reason text NOT NULL,
  previous_status text,
  new_status text NOT NULL,
  adjusted_by uuid REFERENCES public.employees(id) ON DELETE SET NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Leave requests & balances (keep leave_records)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.leave_balances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  leave_type text NOT NULL DEFAULT 'annual',
  year int NOT NULL DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::int,
  entitled_days numeric(6,2) NOT NULL DEFAULT 0,
  used_days numeric(6,2) NOT NULL DEFAULT 0,
  pending_days numeric(6,2) NOT NULL DEFAULT 0,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (employee_id, leave_type, year)
);

CREATE TABLE IF NOT EXISTS public.leave_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  leave_type text NOT NULL DEFAULT 'annual',
  starts_on date NOT NULL,
  ends_on date NOT NULL,
  days_count numeric(6,2) NOT NULL DEFAULT 1,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('draft','pending','approved','rejected','cancelled')),
  reason text,
  approver_id uuid REFERENCES public.employees(id) ON DELETE SET NULL,
  decided_at timestamptz,
  leave_record_id uuid REFERENCES public.leave_records(id) ON DELETE SET NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_leave_requests_status
  ON public.leave_requests (status);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'leave_records_leave_request_id_fkey'
  ) THEN
    ALTER TABLE public.leave_records
      ADD CONSTRAINT leave_records_leave_request_id_fkey
      FOREIGN KEY (leave_request_id) REFERENCES public.leave_requests(id) ON DELETE SET NULL;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Performance
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.performance_cycles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text,
  starts_on date NOT NULL,
  ends_on date NOT NULL,
  status text NOT NULL DEFAULT 'planning'
    CHECK (status IN ('planning','active','calibration','closed')),
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.performance_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cycle_id uuid NOT NULL REFERENCES public.performance_cycles(id) ON DELETE CASCADE,
  employee_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  reviewer_id uuid REFERENCES public.employees(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','submitted','calibrated','final')),
  overall_rating numeric(3,1),
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (cycle_id, employee_id)
);

CREATE TABLE IF NOT EXISTS public.employee_goals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  cycle_id uuid REFERENCES public.performance_cycles(id) ON DELETE SET NULL,
  title text NOT NULL,
  description text,
  progress_pct numeric(5,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','in_progress','done','cancelled')),
  due_on date,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Training & certifications
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.training_courses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  title text NOT NULL,
  provider text,
  delivery_mode text NOT NULL DEFAULT 'blended',
  duration_hours numeric(6,1),
  status text NOT NULL DEFAULT 'active',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.training_enrollments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id uuid NOT NULL REFERENCES public.training_courses(id) ON DELETE CASCADE,
  employee_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'enrolled'
    CHECK (status IN ('enrolled','in_progress','completed','withdrawn')),
  enrolled_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  score numeric(5,2),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (course_id, employee_id)
);

CREATE TABLE IF NOT EXISTS public.certifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  name text NOT NULL,
  issuer text,
  issued_on date,
  expires_on date,
  credential_id text,
  status text NOT NULL DEFAULT 'active',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Payroll profiles, benefits, assets (sensitive)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payroll_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id uuid NOT NULL UNIQUE REFERENCES public.employees(id) ON DELETE CASCADE,
  pay_frequency text NOT NULL DEFAULT 'monthly',
  currency text NOT NULL DEFAULT 'NGN',
  base_salary numeric(16,2),
  allowance_total numeric(16,2) DEFAULT 0,
  bank_name text,
  account_masked text,
  tax_regime text,
  status text NOT NULL DEFAULT 'active',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.employee_benefits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  benefit_type text NOT NULL,
  provider text,
  coverage_label text,
  status text NOT NULL DEFAULT 'active',
  starts_on date,
  ends_on date,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.employee_assets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  asset_tag text NOT NULL,
  asset_type text NOT NULL DEFAULT 'device',
  name text NOT NULL,
  serial_number text,
  assigned_on date NOT NULL DEFAULT CURRENT_DATE,
  returned_on date,
  status text NOT NULL DEFAULT 'assigned'
    CHECK (status IN ('assigned','returned','lost','retired')),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_employee_assets_tag
  ON public.employee_assets (asset_tag);

-- ---------------------------------------------------------------------------
-- Disciplinary & exit
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.disciplinary_cases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  case_code text NOT NULL UNIQUE,
  title text NOT NULL,
  severity text NOT NULL DEFAULT 'low'
    CHECK (severity IN ('low','medium','high','critical')),
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','under_review','closed','appealed')),
  opened_on date NOT NULL DEFAULT CURRENT_DATE,
  closed_on date,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.exit_processes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  exit_type text NOT NULL DEFAULT 'resignation'
    CHECK (exit_type IN ('resignation','termination','contract_end','retirement','other')),
  status text NOT NULL DEFAULT 'initiated'
    CHECK (status IN ('initiated','clearance','completed','cancelled')),
  last_working_day date,
  reason text,
  exit_interview_notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Announcements, reports, activity, notifications
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.hr_announcements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  body text NOT NULL,
  audience text NOT NULL DEFAULT 'all_staff',
  status text NOT NULL DEFAULT 'published'
    CHECK (status IN ('draft','published','archived')),
  published_at timestamptz,
  expires_at timestamptz,
  author_label text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hr_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  report_key text NOT NULL UNIQUE,
  title text NOT NULL,
  period_label text,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  generated_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS public.hr_activity_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  action text NOT NULL,
  summary text NOT NULL,
  actor_label text,
  entity_type text,
  entity_id uuid,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hr_activity_logs_occurred
  ON public.hr_activity_logs (occurred_at DESC);

CREATE TABLE IF NOT EXISTS public.hr_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  body text,
  severity text NOT NULL DEFAULT 'info',
  category text,
  audience text DEFAULT 'hr',
  is_read boolean NOT NULL DEFAULT false,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Seeds (hex-only UUIDs)
-- ---------------------------------------------------------------------------
-- Employees: manager, sales, construction
INSERT INTO public.employees (
  id, employee_code, display_employee_id, first_name, last_name, email,
  department_id, job_title, employment_type, employment_status,
  hire_date, joined_at, salary_grade, location_label, role_slug, status
)
SELECT
  v.id::uuid,
  v.employee_code,
  v.display_employee_id,
  v.first_name,
  v.last_name,
  v.email,
  d.id,
  v.job_title,
  v.employment_type,
  v.employment_status,
  v.hire_date::date,
  v.hire_date::timestamptz,
  v.salary_grade,
  v.location_label,
  v.role_slug,
  'active'
FROM (VALUES
  (
    'a9100001-0000-4000-8000-000000000001',
    'HDH-EMP-1001', 'EMP-1001', 'Amaka', 'Okoro', 'amaka.okoro@hdhomes.demo',
    'human_resources', 'People Operations Manager', 'full_time', 'confirmed',
    '2022-03-01', 'G6', 'Lagos HQ', 'admin'
  ),
  (
    'a9100001-0000-4000-8000-000000000002',
    'HDH-EMP-1002', 'EMP-1002', 'Tunde', 'Adewale', 'tunde.adewale@hdhomes.demo',
    'sales_marketing', 'Sales Executive', 'full_time', 'confirmed',
    '2023-06-15', 'G4', 'Lagos HQ', 'sales_team'
  ),
  (
    'a9100001-0000-4000-8000-000000000003',
    'HDH-EMP-1003', 'EMP-1003', 'Chinedu', 'Eze', 'chinedu.eze@hdhomes.demo',
    'construction_operations', 'Site Supervisor', 'full_time', 'probation',
    '2025-11-01', 'G5', 'Ikeja Site', 'construction_manager'
  )
) AS v(
  id, employee_code, display_employee_id, first_name, last_name, email,
  dept_slug, job_title, employment_type, employment_status,
  hire_date, salary_grade, location_label, role_slug
)
JOIN public.departments d ON d.slug = v.dept_slug
ON CONFLICT (employee_code) DO UPDATE SET
  display_employee_id = EXCLUDED.display_employee_id,
  job_title = EXCLUDED.job_title,
  employment_type = EXCLUDED.employment_type,
  salary_grade = EXCLUDED.salary_grade,
  updated_at = now();

UPDATE public.employees e
SET supervisor_id = 'a9100001-0000-4000-8000-000000000001'::uuid,
    manager_id = 'a9100001-0000-4000-8000-000000000001'::uuid
WHERE e.id IN (
  'a9100001-0000-4000-8000-000000000002'::uuid,
  'a9100001-0000-4000-8000-000000000003'::uuid
);

INSERT INTO public.employee_profiles (employee_id, work_location, bio, skills, profile_completeness)
VALUES
  ('a9100001-0000-4000-8000-000000000001', 'Lagos HQ', 'Leads people ops and talent programs.', ARRAY['HRBP','Talent','Culture'], 88),
  ('a9100001-0000-4000-8000-000000000002', 'Lagos HQ', 'Property sales and client conversion.', ARRAY['Sales','CRM','Negotiation'], 72),
  ('a9100001-0000-4000-8000-000000000003', 'Ikeja Site', 'Site delivery and crew coordination.', ARRAY['HSE','Scheduling','Quality'], 65)
ON CONFLICT (employee_id) DO UPDATE SET
  work_location = EXCLUDED.work_location,
  bio = EXCLUDED.bio,
  skills = EXCLUDED.skills,
  profile_completeness = EXCLUDED.profile_completeness,
  updated_at = now();

INSERT INTO public.organizational_units (id, name, slug, unit_type, department_id, status)
SELECT
  'a9100002-0000-4000-8000-000000000001'::uuid,
  'HD Homes Corporate',
  'hd_homes_corporate',
  'company',
  NULL,
  'active'
WHERE NOT EXISTS (
  SELECT 1 FROM public.organizational_units WHERE slug = 'hd_homes_corporate'
);

INSERT INTO public.shifts (id, name, slug, start_time, end_time)
VALUES
  ('a9100003-0000-4000-8000-000000000001', 'Standard Day', 'standard_day', '08:00', '17:00'),
  ('a9100003-0000-4000-8000-000000000002', 'Site Early', 'site_early', '07:00', '16:00')
ON CONFLICT (slug) DO NOTHING;

-- Open vacancy + posting
INSERT INTO public.job_requisitions (
  id, requisition_code, title, department_id, hiring_manager_id,
  headcount, employment_type, status, location_label, target_start_date, notes,
  metadata
)
SELECT
  'a9100004-0000-4000-8000-000000000001'::uuid,
  'REQ-2026-014',
  'Digital Marketing Specialist',
  d.id,
  'a9100001-0000-4000-8000-000000000001'::uuid,
  1,
  'full_time',
  'open',
  'Lagos HQ',
  CURRENT_DATE + 30,
  'Growth campaigns for estate launches.',
  jsonb_build_object('ai_generated', true, 'editable', true, 'label', 'AI draft JD — advisory')
FROM public.departments d
WHERE d.slug = 'sales_marketing'
ON CONFLICT (requisition_code) DO NOTHING;

INSERT INTO public.job_postings (
  id, requisition_id, title, slug, channel, status, description, published_at, metadata
)
VALUES (
  'a9100004-0000-4000-8000-000000000002',
  'a9100004-0000-4000-8000-000000000001',
  'Digital Marketing Specialist — HD Homes',
  'digital-marketing-specialist',
  'careers_site',
  'open',
  'Own performance marketing for launches and lead gen.',
  now(),
  jsonb_build_object('ai_generated', true, 'editable', true)
)
ON CONFLICT DO NOTHING;

INSERT INTO public.applicants (
  id, posting_id, requisition_id, full_name, email, stage, source, score, metadata
)
VALUES
  (
    'a9100005-0000-4000-8000-000000000001',
    'a9100004-0000-4000-8000-000000000002',
    'a9100004-0000-4000-8000-000000000001',
    'Fatima Bello', 'fatima.bello@example.com', 'screening', 'linkedin', 78,
    '{}'::jsonb
  ),
  (
    'a9100005-0000-4000-8000-000000000002',
    'a9100004-0000-4000-8000-000000000002',
    'a9100004-0000-4000-8000-000000000001',
    'Ibrahim Yusuf', 'ibrahim.yusuf@example.com', 'interview', 'referral', 84,
    '{}'::jsonb
  )
ON CONFLICT DO NOTHING;

INSERT INTO public.interviews (
  id, applicant_id, scheduled_at, interview_type, location_label, status, interviewer_employee_id
)
VALUES (
  'a9100005-0000-4000-8000-000000000011',
  'a9100005-0000-4000-8000-000000000002',
  now() + interval '2 days',
  'panel',
  'Lagos HQ / Hybrid',
  'scheduled',
  'a9100001-0000-4000-8000-000000000001'
)
ON CONFLICT DO NOTHING;

-- Attendance today
INSERT INTO public.attendance_records (
  id, employee_id, work_date, shift_id, clock_in_at, status
)
VALUES
  (
    'a9100006-0000-4000-8000-000000000001',
    'a9100001-0000-4000-8000-000000000001',
    CURRENT_DATE,
    'a9100003-0000-4000-8000-000000000001',
    date_trunc('day', now()) + interval '8 hours 5 minutes',
    'present'
  ),
  (
    'a9100006-0000-4000-8000-000000000002',
    'a9100001-0000-4000-8000-000000000002',
    CURRENT_DATE,
    'a9100003-0000-4000-8000-000000000001',
    date_trunc('day', now()) + interval '8 hours 22 minutes',
    'late'
  ),
  (
    'a9100006-0000-4000-8000-000000000003',
    'a9100001-0000-4000-8000-000000000003',
    CURRENT_DATE,
    'a9100003-0000-4000-8000-000000000002',
    date_trunc('day', now()) + interval '7 hours 5 minutes',
    'present'
  )
ON CONFLICT (employee_id, work_date) DO UPDATE SET
  status = EXCLUDED.status,
  clock_in_at = EXCLUDED.clock_in_at,
  updated_at = now();

-- Leave balances + pending request
INSERT INTO public.leave_balances (id, employee_id, leave_type, year, entitled_days, used_days, pending_days)
VALUES
  ('a9100007-0000-4000-8000-000000000001', 'a9100001-0000-4000-8000-000000000002', 'annual', EXTRACT(YEAR FROM CURRENT_DATE)::int, 20, 4, 2),
  ('a9100007-0000-4000-8000-000000000002', 'a9100001-0000-4000-8000-000000000003', 'annual', EXTRACT(YEAR FROM CURRENT_DATE)::int, 15, 0, 0)
ON CONFLICT (employee_id, leave_type, year) DO UPDATE SET
  entitled_days = EXCLUDED.entitled_days,
  used_days = EXCLUDED.used_days,
  pending_days = EXCLUDED.pending_days,
  updated_at = now();

INSERT INTO public.leave_requests (
  id, employee_id, leave_type, starts_on, ends_on, days_count, status, reason, approver_id
)
VALUES (
  'a9100007-0000-4000-8000-000000000011',
  'a9100001-0000-4000-8000-000000000002',
  'annual',
  CURRENT_DATE + 10,
  CURRENT_DATE + 11,
  2,
  'pending',
  'Family event',
  'a9100001-0000-4000-8000-000000000001'
)
ON CONFLICT DO NOTHING;

-- Performance cycle stub
INSERT INTO public.performance_cycles (id, name, slug, starts_on, ends_on, status, notes, metadata)
VALUES (
  'a9100008-0000-4000-8000-000000000001',
  'H2 2026 Performance Cycle',
  'h2-2026',
  DATE '2026-07-01',
  DATE '2026-12-31',
  'active',
  'Mid-year goals and calibration.',
  jsonb_build_object('ai_generated', true, 'editable', true, 'label', 'AI cycle briefing — advisory')
)
ON CONFLICT DO NOTHING;

INSERT INTO public.employee_goals (
  id, employee_id, cycle_id, title, progress_pct, status, due_on
)
VALUES (
  'a9100008-0000-4000-8000-000000000011',
  'a9100001-0000-4000-8000-000000000002',
  'a9100008-0000-4000-8000-000000000001',
  'Close 8 estate unit bookings',
  40,
  'in_progress',
  DATE '2026-12-15'
)
ON CONFLICT DO NOTHING;

-- Training
INSERT INTO public.training_courses (id, code, title, provider, delivery_mode, duration_hours, status)
VALUES (
  'a9100009-0000-4000-8000-000000000001',
  'TRN-HSE-101',
  'Site HSE Essentials',
  'HD Homes Academy',
  'blended',
  8,
  'active'
)
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.training_enrollments (id, course_id, employee_id, status, enrolled_at)
VALUES (
  'a9100009-0000-4000-8000-000000000011',
  'a9100009-0000-4000-8000-000000000001',
  'a9100001-0000-4000-8000-000000000003',
  'in_progress',
  now()
)
ON CONFLICT (course_id, employee_id) DO NOTHING;

-- Asset assignment
INSERT INTO public.employee_assets (
  id, employee_id, asset_tag, asset_type, name, serial_number, status
)
VALUES (
  'a910000a-0000-4000-8000-000000000001',
  'a9100001-0000-4000-8000-000000000002',
  'HDH-LAP-2048',
  'laptop',
  'Dell Latitude 5540',
  'SN-DL5540-2048',
  'assigned'
)
ON CONFLICT (asset_tag) DO NOTHING;

-- Payroll profile (sensitive seed)
INSERT INTO public.payroll_profiles (
  id, employee_id, pay_frequency, currency, base_salary, allowance_total, account_masked, status
)
VALUES (
  'a910000b-0000-4000-8000-000000000001',
  'a9100001-0000-4000-8000-000000000002',
  'monthly',
  'NGN',
  650000,
  85000,
  '****7842',
  'active'
)
ON CONFLICT (employee_id) DO NOTHING;

-- Announcement + activity + notification
INSERT INTO public.hr_announcements (
  id, title, body, audience, status, published_at, author_label, metadata
)
VALUES (
  'a910000c-0000-4000-8000-000000000001',
  'Q3 People Town Hall',
  'Join the workforce briefing on Friday at 10:00 WAT covering performance cycle timelines.',
  'all_staff',
  'published',
  now(),
  'People Ops',
  '{}'::jsonb
)
ON CONFLICT DO NOTHING;

INSERT INTO public.hr_activity_logs (id, action, summary, actor_label, entity_type, entity_id)
VALUES
  (
    'a910000d-0000-4000-8000-000000000001',
    'leave.request',
    'Leave request pending for Tunde Adewale (2 days annual)',
    'System',
    'leave_request',
    'a9100007-0000-4000-8000-000000000011'
  ),
  (
    'a910000d-0000-4000-8000-000000000002',
    'recruitment.applicant',
    'Ibrahim Yusuf moved to interview stage',
    'Amaka Okoro',
    'applicant',
    'a9100005-0000-4000-8000-000000000002'
  )
ON CONFLICT DO NOTHING;

INSERT INTO public.hr_notifications (id, title, body, severity, category)
VALUES (
  'a910000e-0000-4000-8000-000000000001',
  'Leave approval needed',
  '1 pending leave request requires manager action.',
  'warning',
  'leave'
)
ON CONFLICT DO NOTHING;

INSERT INTO public.onboarding_tasks (
  id, employee_id, title, status, sort_order, due_at
)
VALUES (
  'a910000f-0000-4000-8000-000000000001',
  'a9100001-0000-4000-8000-000000000003',
  'Complete site safety induction',
  'in_progress',
  1,
  now() + interval '7 days'
)
ON CONFLICT DO NOTHING;

INSERT INTO public.staff_onboarding (employee_id, step, completed, title, status, sort_order)
VALUES (
  'a9100001-0000-4000-8000-000000000003',
  'safety_induction',
  false,
  'Site safety induction',
  'in_progress',
  1
)
ON CONFLICT (employee_id, step) DO UPDATE SET
  title = EXCLUDED.title,
  status = EXCLUDED.status;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.organizational_units ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employee_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employee_skills ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.job_requisitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.job_postings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.applicants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.applicant_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.interviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.interview_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.onboarding_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_adjustments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leave_balances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leave_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.performance_cycles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.performance_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employee_goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.certifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payroll_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employee_benefits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employee_assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.disciplinary_cases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exit_processes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hr_announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hr_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hr_activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hr_notifications ENABLE ROW LEVEL SECURITY;

-- Helper: standard read/write policies for HR tables
-- organizational_units
DROP POLICY IF EXISTS organizational_units_select ON public.organizational_units;
DROP POLICY IF EXISTS organizational_units_write ON public.organizational_units;
CREATE POLICY organizational_units_select ON public.organizational_units FOR SELECT
  USING (public.has_permission('hr.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY organizational_units_write ON public.organizational_units FOR ALL
  USING (public.has_permission('hr.write', auth.uid()) OR public.has_permission('hr.employees', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('hr.write', auth.uid()) OR public.has_permission('hr.employees', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS employee_documents_select ON public.employee_documents;
DROP POLICY IF EXISTS employee_documents_write ON public.employee_documents;
CREATE POLICY employee_documents_select ON public.employee_documents FOR SELECT
  USING (public.has_permission('hr.read', auth.uid()) OR public.has_permission('hr.employees', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY employee_documents_write ON public.employee_documents FOR ALL
  USING (public.has_permission('hr.employees', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('hr.employees', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS employee_skills_select ON public.employee_skills;
DROP POLICY IF EXISTS employee_skills_write ON public.employee_skills;
CREATE POLICY employee_skills_select ON public.employee_skills FOR SELECT
  USING (public.has_permission('hr.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY employee_skills_write ON public.employee_skills FOR ALL
  USING (public.has_permission('hr.employees', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('hr.employees', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS job_requisitions_select ON public.job_requisitions;
DROP POLICY IF EXISTS job_requisitions_write ON public.job_requisitions;
CREATE POLICY job_requisitions_select ON public.job_requisitions FOR SELECT
  USING (public.has_permission('hr.read', auth.uid()) OR public.has_permission('hr.recruitment', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY job_requisitions_write ON public.job_requisitions FOR ALL
  USING (public.has_permission('hr.recruitment', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('hr.recruitment', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS job_postings_select ON public.job_postings;
DROP POLICY IF EXISTS job_postings_write ON public.job_postings;
CREATE POLICY job_postings_select ON public.job_postings FOR SELECT
  USING (public.has_permission('hr.read', auth.uid()) OR public.has_permission('hr.recruitment', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY job_postings_write ON public.job_postings FOR ALL
  USING (public.has_permission('hr.recruitment', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('hr.recruitment', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS applicants_select ON public.applicants;
DROP POLICY IF EXISTS applicants_write ON public.applicants;
CREATE POLICY applicants_select ON public.applicants FOR SELECT
  USING (public.has_permission('hr.read', auth.uid()) OR public.has_permission('hr.recruitment', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY applicants_write ON public.applicants FOR ALL
  USING (public.has_permission('hr.recruitment', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('hr.recruitment', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS applicant_documents_select ON public.applicant_documents;
DROP POLICY IF EXISTS applicant_documents_write ON public.applicant_documents;
CREATE POLICY applicant_documents_select ON public.applicant_documents FOR SELECT
  USING (public.has_permission('hr.recruitment', auth.uid()) OR public.has_permission('hr.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY applicant_documents_write ON public.applicant_documents FOR ALL
  USING (public.has_permission('hr.recruitment', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('hr.recruitment', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS interviews_select ON public.interviews;
DROP POLICY IF EXISTS interviews_write ON public.interviews;
CREATE POLICY interviews_select ON public.interviews FOR SELECT
  USING (public.has_permission('hr.read', auth.uid()) OR public.has_permission('hr.recruitment', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY interviews_write ON public.interviews FOR ALL
  USING (public.has_permission('hr.recruitment', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('hr.recruitment', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS interview_feedback_select ON public.interview_feedback;
DROP POLICY IF EXISTS interview_feedback_write ON public.interview_feedback;
CREATE POLICY interview_feedback_select ON public.interview_feedback FOR SELECT
  USING (public.has_permission('hr.recruitment', auth.uid()) OR public.has_permission('hr.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY interview_feedback_write ON public.interview_feedback FOR ALL
  USING (public.has_permission('hr.recruitment', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('hr.recruitment', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS onboarding_tasks_select ON public.onboarding_tasks;
DROP POLICY IF EXISTS onboarding_tasks_write ON public.onboarding_tasks;
CREATE POLICY onboarding_tasks_select ON public.onboarding_tasks FOR SELECT
  USING (public.has_permission('hr.read', auth.uid()) OR public.has_permission('hr.employees', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY onboarding_tasks_write ON public.onboarding_tasks FOR ALL
  USING (public.has_permission('hr.employees', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('hr.employees', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS shifts_select ON public.shifts;
DROP POLICY IF EXISTS shifts_write ON public.shifts;
CREATE POLICY shifts_select ON public.shifts FOR SELECT
  USING (public.has_permission('hr.read', auth.uid()) OR public.has_permission('hr.attendance', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY shifts_write ON public.shifts FOR ALL
  USING (public.has_permission('hr.attendance', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('hr.attendance', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS attendance_records_select ON public.attendance_records;
DROP POLICY IF EXISTS attendance_records_write ON public.attendance_records;
CREATE POLICY attendance_records_select ON public.attendance_records FOR SELECT
  USING (public.has_permission('hr.read', auth.uid()) OR public.has_permission('hr.attendance', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY attendance_records_write ON public.attendance_records FOR ALL
  USING (public.has_permission('hr.attendance', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('hr.attendance', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS attendance_adjustments_select ON public.attendance_adjustments;
DROP POLICY IF EXISTS attendance_adjustments_write ON public.attendance_adjustments;
CREATE POLICY attendance_adjustments_select ON public.attendance_adjustments FOR SELECT
  USING (public.has_permission('hr.attendance', auth.uid()) OR public.has_permission('hr.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY attendance_adjustments_write ON public.attendance_adjustments FOR ALL
  USING (public.has_permission('hr.attendance', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('hr.attendance', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS leave_balances_select ON public.leave_balances;
DROP POLICY IF EXISTS leave_balances_write ON public.leave_balances;
CREATE POLICY leave_balances_select ON public.leave_balances FOR SELECT
  USING (public.has_permission('hr.read', auth.uid()) OR public.has_permission('hr.leave', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY leave_balances_write ON public.leave_balances FOR ALL
  USING (public.has_permission('hr.leave', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('hr.leave', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS leave_requests_select ON public.leave_requests;
DROP POLICY IF EXISTS leave_requests_write ON public.leave_requests;
CREATE POLICY leave_requests_select ON public.leave_requests FOR SELECT
  USING (public.has_permission('hr.read', auth.uid()) OR public.has_permission('hr.leave', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY leave_requests_write ON public.leave_requests FOR ALL
  USING (
    public.has_permission('hr.leave', auth.uid())
    OR public.has_permission('hr.approvals', auth.uid())
    OR public.has_permission('hr.write', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('hr.leave', auth.uid())
    OR public.has_permission('hr.approvals', auth.uid())
    OR public.has_permission('hr.write', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

DROP POLICY IF EXISTS performance_cycles_select ON public.performance_cycles;
DROP POLICY IF EXISTS performance_cycles_write ON public.performance_cycles;
CREATE POLICY performance_cycles_select ON public.performance_cycles FOR SELECT
  USING (public.has_permission('hr.read', auth.uid()) OR public.has_permission('hr.performance', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY performance_cycles_write ON public.performance_cycles FOR ALL
  USING (public.has_permission('hr.performance', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('hr.performance', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS performance_reviews_select ON public.performance_reviews;
DROP POLICY IF EXISTS performance_reviews_write ON public.performance_reviews;
CREATE POLICY performance_reviews_select ON public.performance_reviews FOR SELECT
  USING (public.has_permission('hr.read', auth.uid()) OR public.has_permission('hr.performance', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY performance_reviews_write ON public.performance_reviews FOR ALL
  USING (public.has_permission('hr.performance', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('hr.performance', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS employee_goals_select ON public.employee_goals;
DROP POLICY IF EXISTS employee_goals_write ON public.employee_goals;
CREATE POLICY employee_goals_select ON public.employee_goals FOR SELECT
  USING (public.has_permission('hr.read', auth.uid()) OR public.has_permission('hr.performance', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY employee_goals_write ON public.employee_goals FOR ALL
  USING (public.has_permission('hr.performance', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('hr.performance', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS training_courses_select ON public.training_courses;
DROP POLICY IF EXISTS training_courses_write ON public.training_courses;
CREATE POLICY training_courses_select ON public.training_courses FOR SELECT
  USING (public.has_permission('hr.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY training_courses_write ON public.training_courses FOR ALL
  USING (public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS training_enrollments_select ON public.training_enrollments;
DROP POLICY IF EXISTS training_enrollments_write ON public.training_enrollments;
CREATE POLICY training_enrollments_select ON public.training_enrollments FOR SELECT
  USING (public.has_permission('hr.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY training_enrollments_write ON public.training_enrollments FOR ALL
  USING (public.has_permission('hr.write', auth.uid()) OR public.has_permission('hr.employees', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('hr.write', auth.uid()) OR public.has_permission('hr.employees', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS certifications_select ON public.certifications;
DROP POLICY IF EXISTS certifications_write ON public.certifications;
CREATE POLICY certifications_select ON public.certifications FOR SELECT
  USING (public.has_permission('hr.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY certifications_write ON public.certifications FOR ALL
  USING (public.has_permission('hr.employees', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('hr.employees', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

-- Sensitive: payroll + disciplinary require dedicated permission
DROP POLICY IF EXISTS payroll_profiles_select ON public.payroll_profiles;
DROP POLICY IF EXISTS payroll_profiles_write ON public.payroll_profiles;
CREATE POLICY payroll_profiles_select ON public.payroll_profiles FOR SELECT
  USING (public.has_permission('hr.payroll', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY payroll_profiles_write ON public.payroll_profiles FOR ALL
  USING (public.has_permission('hr.payroll', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('hr.payroll', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS employee_benefits_select ON public.employee_benefits;
DROP POLICY IF EXISTS employee_benefits_write ON public.employee_benefits;
CREATE POLICY employee_benefits_select ON public.employee_benefits FOR SELECT
  USING (public.has_permission('hr.payroll', auth.uid()) OR public.has_permission('hr.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY employee_benefits_write ON public.employee_benefits FOR ALL
  USING (public.has_permission('hr.payroll', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('hr.payroll', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS employee_assets_select ON public.employee_assets;
DROP POLICY IF EXISTS employee_assets_write ON public.employee_assets;
CREATE POLICY employee_assets_select ON public.employee_assets FOR SELECT
  USING (public.has_permission('hr.read', auth.uid()) OR public.has_permission('hr.assets', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY employee_assets_write ON public.employee_assets FOR ALL
  USING (public.has_permission('hr.assets', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('hr.assets', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS disciplinary_cases_select ON public.disciplinary_cases;
DROP POLICY IF EXISTS disciplinary_cases_write ON public.disciplinary_cases;
CREATE POLICY disciplinary_cases_select ON public.disciplinary_cases FOR SELECT
  USING (public.has_permission('hr.approvals', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY disciplinary_cases_write ON public.disciplinary_cases FOR ALL
  USING (public.has_permission('hr.approvals', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('hr.approvals', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS exit_processes_select ON public.exit_processes;
DROP POLICY IF EXISTS exit_processes_write ON public.exit_processes;
CREATE POLICY exit_processes_select ON public.exit_processes FOR SELECT
  USING (public.has_permission('hr.employees', auth.uid()) OR public.has_permission('hr.approvals', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY exit_processes_write ON public.exit_processes FOR ALL
  USING (public.has_permission('hr.employees', auth.uid()) OR public.has_permission('hr.approvals', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('hr.employees', auth.uid()) OR public.has_permission('hr.approvals', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS hr_announcements_select ON public.hr_announcements;
DROP POLICY IF EXISTS hr_announcements_write ON public.hr_announcements;
CREATE POLICY hr_announcements_select ON public.hr_announcements FOR SELECT
  USING (public.has_permission('hr.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY hr_announcements_write ON public.hr_announcements FOR ALL
  USING (public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS hr_reports_select ON public.hr_reports;
DROP POLICY IF EXISTS hr_reports_write ON public.hr_reports;
CREATE POLICY hr_reports_select ON public.hr_reports FOR SELECT
  USING (public.has_permission('hr.analytics', auth.uid()) OR public.has_permission('hr.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY hr_reports_write ON public.hr_reports FOR ALL
  USING (public.has_permission('hr.analytics', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('hr.analytics', auth.uid()) OR public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS hr_activity_logs_select ON public.hr_activity_logs;
DROP POLICY IF EXISTS hr_activity_logs_write ON public.hr_activity_logs;
CREATE POLICY hr_activity_logs_select ON public.hr_activity_logs FOR SELECT
  USING (public.has_permission('hr.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY hr_activity_logs_write ON public.hr_activity_logs FOR ALL
  USING (public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS hr_notifications_select ON public.hr_notifications;
DROP POLICY IF EXISTS hr_notifications_write ON public.hr_notifications;
CREATE POLICY hr_notifications_select ON public.hr_notifications FOR SELECT
  USING (public.has_permission('hr.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY hr_notifications_write ON public.hr_notifications FOR ALL
  USING (public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('hr.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

-- Enrich existing employees policies for hr.* (additive)
DROP POLICY IF EXISTS employees_hr_select ON public.employees;
DROP POLICY IF EXISTS employees_hr_write ON public.employees;
CREATE POLICY employees_hr_select ON public.employees FOR SELECT
  USING (
    public.has_permission('hr.read', auth.uid())
    OR public.has_permission('hr.employees', auth.uid())
    OR public.has_permission('view_organization', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY employees_hr_write ON public.employees FOR ALL
  USING (
    public.has_permission('hr.employees', auth.uid())
    OR public.has_permission('hr.write', auth.uid())
    OR public.has_permission('manage_organization', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('hr.employees', auth.uid())
    OR public.has_permission('hr.write', auth.uid())
    OR public.has_permission('manage_organization', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'employees',
    'attendance_records',
    'leave_requests',
    'job_postings',
    'interviews',
    'hr_announcements',
    'hr_activity_logs'
  ]
  LOOP
    BEGIN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    EXCEPTION
      WHEN duplicate_object THEN NULL;
      WHEN undefined_object THEN NULL;
    END;
  END LOOP;
END $$;

COMMIT;
