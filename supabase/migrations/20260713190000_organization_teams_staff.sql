-- Volume 3 Part 11 — Organization, Teams & Staff Management
-- Status: APPLIED remotely as organization_teams_staff + organization_teams_staff_rls (approved 2026-07-13).
-- Organizational backbone for HD Homes enterprise admin platform.

-- ---------------------------------------------------------------------------
-- Permissions
-- ---------------------------------------------------------------------------

INSERT INTO public.permissions (name, slug, module, description) VALUES
  ('View Organization', 'view_organization', 'organization', 'View departments, teams, and staff directory'),
  ('Manage Organization', 'manage_organization', 'organization', 'Manage departments, teams, branches, and staff'),
  ('Manage Staff', 'manage_staff', 'organization', 'Create and update employee records'),
  ('View Staff Directory', 'view_staff_directory', 'organization', 'Browse the enterprise employee directory')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE r.slug IN ('super_admin', 'admin')
  AND p.slug IN (
    'view_organization',
    'manage_organization',
    'manage_staff',
    'view_staff_directory'
  )
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Branch offices
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.branch_offices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  address TEXT,
  city TEXT,
  state TEXT,
  country TEXT NOT NULL DEFAULT 'Nigeria',
  phone TEXT,
  email TEXT,
  is_primary BOOLEAN NOT NULL DEFAULT false,
  status TEXT NOT NULL DEFAULT 'active',
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.branch_offices (name, slug, address, city, phone, is_primary, status)
VALUES (
  'Lagos Headquarters',
  'lagos_hq',
  'Victoria Island, Lagos',
  'Lagos',
  '+234 800 000 0000',
  true,
  'active'
)
ON CONFLICT (slug) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Departments
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.departments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  description TEXT,
  head_employee_id UUID,
  status TEXT NOT NULL DEFAULT 'active',
  sort_order INT NOT NULL DEFAULT 0,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.departments (name, slug, description, sort_order) VALUES
  ('Executive Management', 'executive_management', 'Leadership, strategy, and corporate governance', 1),
  ('Sales & Marketing', 'sales_marketing', 'Property sales, campaigns, and brand growth', 2),
  ('Finance & Accounts', 'finance_accounts', 'Payments, accounting, and financial controls', 3),
  ('Construction & Operations', 'construction_operations', 'Site delivery, project operations, and logistics', 4),
  ('Architecture & Design', 'architecture_design', 'Design, drawings, and spatial planning', 5),
  ('Survey & Land Services', 'survey_land', 'Land survey, title, and site assessment', 6),
  ('Customer Support', 'customer_support', 'Client care, tickets, and service recovery', 7),
  ('Human Resources', 'human_resources', 'People operations, leave, and staffing', 8),
  ('Legal & Compliance', 'legal_compliance', 'Contracts, KYC oversight, and regulatory affairs', 9),
  ('Technology & Systems', 'technology_systems', 'Platform engineering, security, and IT', 10),
  ('Investor Relations', 'investor_relations', 'Investor onboarding, reporting, and retention', 11)
ON CONFLICT (slug) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Positions
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.positions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  department_id UUID REFERENCES public.departments(id) ON DELETE SET NULL,
  level INT NOT NULL DEFAULT 1,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.positions (title, slug, level, description) VALUES
  ('Managing Director', 'managing_director', 10, 'Executive leadership'),
  ('General Manager', 'general_manager', 9, 'Operational leadership'),
  ('Sales Manager', 'sales_manager', 7, 'Sales team leadership'),
  ('Finance Manager', 'finance_manager', 7, 'Finance leadership'),
  ('Account Officer', 'account_officer', 4, 'Accounts operations'),
  ('Construction Manager', 'construction_manager', 7, 'Construction leadership'),
  ('Site Engineer', 'site_engineer', 4, 'Site engineering')
ON CONFLICT (slug) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Employees (core staff record — links optional auth user)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.employees (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_code TEXT NOT NULL UNIQUE,
  user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  preferred_name TEXT,
  email TEXT,
  phone TEXT,
  avatar_url TEXT,
  department_id UUID REFERENCES public.departments(id) ON DELETE SET NULL,
  team_id UUID,
  position_id UUID REFERENCES public.positions(id) ON DELETE SET NULL,
  manager_id UUID REFERENCES public.employees(id) ON DELETE SET NULL,
  branch_id UUID REFERENCES public.branch_offices(id) ON DELETE SET NULL,
  employment_status TEXT NOT NULL DEFAULT 'probation',
  joined_at TIMESTAMPTZ,
  left_at TIMESTAMPTZ,
  role_slug TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_employees_department ON public.employees(department_id);
CREATE INDEX IF NOT EXISTS idx_employees_manager ON public.employees(manager_id);
CREATE INDEX IF NOT EXISTS idx_employees_status ON public.employees(employment_status);
CREATE INDEX IF NOT EXISTS idx_employees_branch ON public.employees(branch_id);
CREATE INDEX IF NOT EXISTS idx_employees_user ON public.employees(user_id);

-- Deferred FK: departments.head_employee_id → employees
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'departments_head_employee_id_fkey'
  ) THEN
    ALTER TABLE public.departments
      ADD CONSTRAINT departments_head_employee_id_fkey
      FOREIGN KEY (head_employee_id) REFERENCES public.employees(id) ON DELETE SET NULL;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Teams + members
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.teams (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT,
  description TEXT,
  department_id UUID NOT NULL REFERENCES public.departments(id) ON DELETE CASCADE,
  team_lead_id UUID REFERENCES public.employees(id) ON DELETE SET NULL,
  branch_id UUID REFERENCES public.branch_offices(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'active',
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_teams_dept_name
  ON public.teams(department_id, lower(name));

-- Wire employees.team_id now that teams exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'employees_team_id_fkey'
  ) THEN
    ALTER TABLE public.employees
      ADD CONSTRAINT employees_team_id_fkey
      FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE SET NULL;
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.team_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  employee_id UUID NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  role_in_team TEXT NOT NULL DEFAULT 'member',
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (team_id, employee_id)
);

-- Seed Sales & Marketing teams
INSERT INTO public.teams (name, slug, description, department_id, branch_id)
SELECT
  v.name,
  v.slug,
  v.description,
  d.id,
  b.id
FROM (VALUES
  ('Property Sales Team', 'property_sales', 'Lead conversion and property transactions'),
  ('Digital Marketing Team', 'digital_marketing', 'Campaigns, SEO, and social media'),
  ('Investor Acquisition Team', 'investor_acquisition', 'Investor outreach and onboarding')
) AS v(name, slug, description)
JOIN public.departments d ON d.slug = 'sales_marketing'
CROSS JOIN public.branch_offices b
WHERE b.slug = 'lagos_hq'
  AND NOT EXISTS (
    SELECT 1 FROM public.teams t
    WHERE t.department_id = d.id AND lower(t.name) = lower(v.name)
  );

-- ---------------------------------------------------------------------------
-- Reporting, history, leave, onboarding, settings
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.reporting_structure (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  manager_id UUID NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  relationship TEXT NOT NULL DEFAULT 'direct',
  effective_from TIMESTAMPTZ NOT NULL DEFAULT now(),
  effective_to TIMESTAMPTZ,
  UNIQUE (employee_id, manager_id, relationship, effective_from)
);

CREATE TABLE IF NOT EXISTS public.employment_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,
  notes TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id)
);

CREATE TABLE IF NOT EXISTS public.leave_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  leave_type TEXT NOT NULL DEFAULT 'general',
  starts_at TIMESTAMPTZ NOT NULL,
  ends_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'active',
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_leave_records_employee
  ON public.leave_records(employee_id, status);

CREATE TABLE IF NOT EXISTS public.staff_onboarding (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  step TEXT NOT NULL,
  completed BOOLEAN NOT NULL DEFAULT false,
  completed_at TIMESTAMPTZ,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (employee_id, step)
);

CREATE TABLE IF NOT EXISTS public.employee_profiles (
  employee_id UUID PRIMARY KEY REFERENCES public.employees(id) ON DELETE CASCADE,
  work_location TEXT,
  emergency_contact_name TEXT,
  emergency_contact_phone TEXT,
  bio TEXT,
  skills TEXT[] NOT NULL DEFAULT '{}',
  extras JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.organization_settings (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.organization_settings (key, value) VALUES
  ('employee_code_prefix', '"HDH-EMP"'::jsonb),
  ('default_branch_slug', '"lagos_hq"'::jsonb),
  ('require_mfa_for_staff', 'true'::jsonb)
ON CONFLICT (key) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Helper: next employee code
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.next_employee_code()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_max INT;
BEGIN
  SELECT COALESCE(MAX(
    NULLIF(regexp_replace(employee_code, '[^0-9]', '', 'g'), '')::INT
  ), 0)
  INTO v_max
  FROM public.employees;

  RETURN 'HDH-EMP-' || lpad((v_max + 1)::TEXT, 4, '0');
END;
$$;

GRANT EXECUTE ON FUNCTION public.next_employee_code TO authenticated;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

ALTER TABLE public.branch_offices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.positions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reporting_structure ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employment_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leave_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_onboarding ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employee_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS branch_offices_read ON public.branch_offices;
CREATE POLICY branch_offices_read ON public.branch_offices
  FOR SELECT USING (
    public.has_permission('view_organization')
    OR public.has_permission('view_staff_directory')
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS departments_read ON public.departments;
CREATE POLICY departments_read ON public.departments
  FOR SELECT USING (
    public.has_permission('view_organization')
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS departments_manage ON public.departments;
CREATE POLICY departments_manage ON public.departments
  FOR ALL USING (
    public.has_permission('manage_organization')
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS positions_read ON public.positions;
CREATE POLICY positions_read ON public.positions
  FOR SELECT USING (
    public.has_permission('view_organization')
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS employees_read ON public.employees;
CREATE POLICY employees_read ON public.employees
  FOR SELECT USING (
    user_id = auth.uid()
    OR public.has_permission('view_staff_directory')
    OR public.has_permission('view_organization')
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS employees_manage ON public.employees;
CREATE POLICY employees_manage ON public.employees
  FOR ALL USING (
    public.has_permission('manage_staff')
    OR public.has_permission('manage_organization')
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS teams_read ON public.teams;
CREATE POLICY teams_read ON public.teams
  FOR SELECT USING (
    public.has_permission('view_organization')
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS teams_manage ON public.teams;
CREATE POLICY teams_manage ON public.teams
  FOR ALL USING (
    public.has_permission('manage_organization')
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS team_members_staff ON public.team_members;
CREATE POLICY team_members_staff ON public.team_members
  FOR ALL USING (
    public.has_permission('view_organization')
    OR public.has_permission('manage_staff')
    OR public.has_role('admin')
  );

DROP POLICY IF EXISTS employment_history_staff ON public.employment_history;
CREATE POLICY employment_history_staff ON public.employment_history
  FOR SELECT USING (
    public.has_permission('manage_staff')
    OR public.has_role('admin')
  );

DROP POLICY IF EXISTS leave_records_staff ON public.leave_records;
CREATE POLICY leave_records_staff ON public.leave_records
  FOR ALL USING (
    public.has_permission('manage_staff')
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS staff_onboarding_staff ON public.staff_onboarding;
CREATE POLICY staff_onboarding_staff ON public.staff_onboarding
  FOR ALL USING (
    public.has_permission('manage_staff')
    OR public.has_role('admin')
  );

DROP POLICY IF EXISTS organization_settings_staff ON public.organization_settings;
CREATE POLICY organization_settings_staff ON public.organization_settings
  FOR SELECT USING (
    public.has_permission('manage_organization')
    OR public.has_role('admin')
  );

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.employees;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.teams;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.departments;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.leave_records;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
