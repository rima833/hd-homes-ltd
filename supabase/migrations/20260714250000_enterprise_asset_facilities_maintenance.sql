-- APPLIED remotely 2026-07-15 (chunked enterprise_asset_facilities_p1–p3)
-- Volume 4 Part 14 — Enterprise Asset, Facilities & Maintenance Management (EAFMS)
-- Status: APPLIED remotely 2026-07-15.
--
-- Approach:
--   • NEVER recreate/drop DDCMS: digital_assets, asset_collections,
--     asset_collection_items, asset_usage_logs.
--   • NEVER CREATE/DROP HCM employee_assets — optional ALTER ADD COLUMN only.
--   • NEVER recreate PVISCM warehouses / inventory_items / vendors / POs.
--   • Physical asset register uses public.assets (name verified free).
--   • Activity logs use asset_activity_logs (NOT asset_usage_logs — DDCMS).
--   • Seed UUIDs hex-only (c140…).
--   • Permissions: slug, name, description, module ONLY.
--   • RLS: has_permission('slug', auth.uid()) — slug FIRST.
--
-- Volume 4 continues Parts 15–25. Wait for approve before Part 15.

BEGIN;

-- ---------------------------------------------------------------------------
-- Permissions
-- ---------------------------------------------------------------------------
INSERT INTO public.permissions (slug, name, description, module) VALUES
  ('assets.read', 'View Assets', 'View Asset Command Center', 'assets'),
  ('assets.write', 'Manage Assets', 'Create and edit enterprise assets', 'assets'),
  ('assets.register', 'Register Assets', 'Register physical assets in the enterprise register', 'assets'),
  ('assets.assign', 'Assign Assets', 'Assign assets to people or locations', 'assets'),
  ('assets.maintenance', 'Manage Maintenance', 'Manage maintenance plans and records', 'assets'),
  ('assets.workorders', 'Manage Work Orders', 'Create and manage work orders', 'assets'),
  ('assets.inspections', 'Manage Inspections', 'Manage asset and facility inspections', 'assets'),
  ('assets.fleet', 'Manage Fleet', 'Manage fleet vehicles and fuel logs', 'assets'),
  ('assets.facilities', 'Manage Facilities', 'Manage facilities and zones', 'assets'),
  ('assets.utilities', 'Manage Utilities', 'Manage utility meters and readings', 'assets'),
  ('assets.depreciation', 'Asset Depreciation', 'View and manage asset depreciation', 'assets'),
  ('assets.approvals', 'Asset Approvals', 'Approve asset and maintenance requests', 'assets'),
  ('assets.analytics', 'Asset Analytics', 'View asset KPIs and analytics', 'assets'),
  ('assets.ai', 'Asset AI', 'Use asset AI intelligence tools', 'assets'),
  ('assets.reports', 'Asset Reports', 'Generate and view asset reports', 'assets')
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  module = EXCLUDED.module,
  updated_at = now();

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE p.slug LIKE 'assets.%'
  AND (
    r.slug IN ('super_admin', 'admin')
    OR (r.slug = 'finance' AND p.slug IN (
      'assets.read', 'assets.depreciation', 'assets.analytics',
      'assets.reports', 'assets.approvals'
    ))
    OR (r.slug = 'construction_manager' AND p.slug IN (
      'assets.read', 'assets.register', 'assets.maintenance',
      'assets.workorders', 'assets.inspections', 'assets.fleet',
      'assets.facilities'
    ))
    OR (r.slug = 'sales_team' AND p.slug IN (
      'assets.read'
    ))
    OR (r.slug = 'marketing' AND p.slug IN (
      'assets.read', 'assets.facilities'
    ))
  )
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Optional HCM linking (do NOT recreate employee_assets)
-- ---------------------------------------------------------------------------
ALTER TABLE public.employee_assets
  ADD COLUMN IF NOT EXISTS enterprise_asset_id uuid;

-- ---------------------------------------------------------------------------
-- Categories & physical asset register (NOT digital_assets)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.asset_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  description text,
  sort_order int NOT NULL DEFAULT 100,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.facilities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  name text NOT NULL,
  facility_type text NOT NULL DEFAULT 'office'
    CHECK (facility_type IN ('hq','office','site','warehouse','yard','other')),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','inactive','under_maintenance','decommissioned')),
  address_label text,
  city text,
  country text DEFAULT 'NG',
  floors int DEFAULT 1,
  area_sqm numeric(12,2),
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_facilities_status ON public.facilities(status);

CREATE TABLE IF NOT EXISTS public.facility_zones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_id uuid NOT NULL REFERENCES public.facilities(id) ON DELETE CASCADE,
  code text,
  name text NOT NULL,
  zone_type text NOT NULL DEFAULT 'area'
    CHECK (zone_type IN ('floor','wing','room','yard','parking','plant','other','area')),
  floor_label text,
  area_sqm numeric(12,2),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','inactive','restricted')),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.asset_locations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  name text NOT NULL,
  facility_id uuid REFERENCES public.facilities(id) ON DELETE SET NULL,
  zone_id uuid REFERENCES public.facility_zones(id) ON DELETE SET NULL,
  location_label text,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','inactive')),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.assets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_tag text UNIQUE,
  name text NOT NULL,
  category_id uuid REFERENCES public.asset_categories(id) ON DELETE SET NULL,
  asset_class text NOT NULL DEFAULT 'equipment'
    CHECK (asset_class IN ('it','fleet','construction','facility','furniture','equipment','other')),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft','active','assigned','in_maintenance','retired','disposed','lost')),
  serial_number text,
  manufacturer text,
  model_label text,
  facility_id uuid REFERENCES public.facilities(id) ON DELETE SET NULL,
  location_id uuid REFERENCES public.asset_locations(id) ON DELETE SET NULL,
  purchase_cost numeric(18,2) DEFAULT 0,
  currency text NOT NULL DEFAULT 'NGN',
  purchase_date date,
  in_service_date date,
  condition_label text DEFAULT 'good',
  criticality text NOT NULL DEFAULT 'medium'
    CHECK (criticality IN ('low','medium','high','critical')),
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_assets_status ON public.assets(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_assets_class ON public.assets(asset_class);
CREATE INDEX IF NOT EXISTS idx_assets_facility ON public.assets(facility_id);

CREATE TABLE IF NOT EXISTS public.asset_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_id uuid NOT NULL REFERENCES public.assets(id) ON DELETE CASCADE,
  assignee_label text NOT NULL,
  assignment_type text NOT NULL DEFAULT 'custody'
    CHECK (assignment_type IN ('custody','location','project','fleet','other')),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','returned','transferred','cancelled')),
  assigned_at timestamptz NOT NULL DEFAULT now(),
  returned_at timestamptz,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_asset_assignments_asset
  ON public.asset_assignments(asset_id, status);

CREATE TABLE IF NOT EXISTS public.asset_movements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_id uuid NOT NULL REFERENCES public.assets(id) ON DELETE CASCADE,
  from_location_id uuid REFERENCES public.asset_locations(id) ON DELETE SET NULL,
  to_location_id uuid REFERENCES public.asset_locations(id) ON DELETE SET NULL,
  movement_type text NOT NULL DEFAULT 'transfer'
    CHECK (movement_type IN ('transfer','checkout','checkin','disposal','other')),
  moved_by text,
  moved_at timestamptz NOT NULL DEFAULT now(),
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS public.asset_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_id uuid NOT NULL REFERENCES public.assets(id) ON DELETE CASCADE,
  title text NOT NULL,
  doc_type text NOT NULL DEFAULT 'other'
    CHECK (doc_type IN ('manual','certificate','photo','invoice','warranty','other')),
  storage_bucket text DEFAULT 'asset-documents',
  storage_path text,
  expires_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.asset_warranties (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_id uuid NOT NULL REFERENCES public.assets(id) ON DELETE CASCADE,
  provider_label text,
  warranty_type text NOT NULL DEFAULT 'manufacturer'
    CHECK (warranty_type IN ('manufacturer','extended','service','other')),
  starts_on date,
  ends_on date,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','expired','void','claimed')),
  coverage_notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_asset_warranties_ends
  ON public.asset_warranties(ends_on, status);

CREATE TABLE IF NOT EXISTS public.asset_depreciation (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_id uuid NOT NULL REFERENCES public.assets(id) ON DELETE CASCADE,
  method text NOT NULL DEFAULT 'straight_line'
    CHECK (method IN ('straight_line','declining_balance','units','other')),
  useful_life_months int NOT NULL DEFAULT 60,
  salvage_value numeric(18,2) DEFAULT 0,
  book_value numeric(18,2) DEFAULT 0,
  monthly_amount numeric(18,2) DEFAULT 0,
  currency text NOT NULL DEFAULT 'NGN',
  as_of_date date NOT NULL DEFAULT CURRENT_DATE,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','fully_depreciated','paused','closed')),
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Maintenance
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.maintenance_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  title text NOT NULL,
  asset_id uuid REFERENCES public.assets(id) ON DELETE SET NULL,
  facility_id uuid REFERENCES public.facilities(id) ON DELETE SET NULL,
  plan_type text NOT NULL DEFAULT 'preventive'
    CHECK (plan_type IN ('preventive','predictive','corrective','inspection','other')),
  frequency_days int DEFAULT 30,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft','active','paused','retired')),
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.maintenance_schedules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid NOT NULL REFERENCES public.maintenance_plans(id) ON DELETE CASCADE,
  due_at timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'scheduled'
    CHECK (status IN ('scheduled','due','overdue','completed','cancelled','skipped')),
  assignee_label text,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_maintenance_schedules_due
  ON public.maintenance_schedules(due_at, status);

CREATE TABLE IF NOT EXISTS public.maintenance_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid REFERENCES public.maintenance_plans(id) ON DELETE SET NULL,
  schedule_id uuid REFERENCES public.maintenance_schedules(id) ON DELETE SET NULL,
  asset_id uuid REFERENCES public.assets(id) ON DELETE SET NULL,
  code text UNIQUE,
  title text NOT NULL,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','in_progress','completed','cancelled')),
  performed_by text,
  performed_at timestamptz,
  cost_amount numeric(18,2) DEFAULT 0,
  currency text NOT NULL DEFAULT 'NGN',
  findings text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_maintenance_records_status
  ON public.maintenance_records(status, created_at DESC);

CREATE TABLE IF NOT EXISTS public.maintenance_incidents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_id uuid REFERENCES public.assets(id) ON DELETE SET NULL,
  facility_id uuid REFERENCES public.facilities(id) ON DELETE SET NULL,
  code text UNIQUE,
  title text NOT NULL,
  severity text NOT NULL DEFAULT 'medium'
    CHECK (severity IN ('low','medium','high','critical')),
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','investigating','resolved','closed')),
  reported_by text,
  reported_at timestamptz NOT NULL DEFAULT now(),
  resolution_notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Work orders
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.work_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  title text NOT NULL,
  asset_id uuid REFERENCES public.assets(id) ON DELETE SET NULL,
  facility_id uuid REFERENCES public.facilities(id) ON DELETE SET NULL,
  maintenance_plan_id uuid REFERENCES public.maintenance_plans(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('draft','open','assigned','in_progress','on_hold','completed','cancelled')),
  priority text NOT NULL DEFAULT 'normal'
    CHECK (priority IN ('low','normal','high','urgent')),
  assignee_label text,
  requested_by text,
  due_at timestamptz,
  completed_at timestamptz,
  estimated_cost numeric(18,2) DEFAULT 0,
  actual_cost numeric(18,2) DEFAULT 0,
  currency text NOT NULL DEFAULT 'NGN',
  description text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_work_orders_status
  ON public.work_orders(status, created_at DESC);

CREATE TABLE IF NOT EXISTS public.work_order_tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  work_order_id uuid NOT NULL REFERENCES public.work_orders(id) ON DELETE CASCADE,
  line_no int NOT NULL DEFAULT 1,
  title text NOT NULL,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','in_progress','done','skipped')),
  assignee_label text,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS public.work_order_materials (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  work_order_id uuid NOT NULL REFERENCES public.work_orders(id) ON DELETE CASCADE,
  line_no int NOT NULL DEFAULT 1,
  description text NOT NULL,
  quantity numeric(18,3) NOT NULL DEFAULT 1,
  uom text NOT NULL DEFAULT 'ea',
  unit_cost numeric(18,2) DEFAULT 0,
  inventory_item_id uuid,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

-- Optional PVISCM inventory link (non-destructive; only if inventory_items exists)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'inventory_items'
  ) THEN
    BEGIN
      ALTER TABLE public.work_order_materials
        ADD CONSTRAINT work_order_materials_inventory_item_id_fkey
        FOREIGN KEY (inventory_item_id)
        REFERENCES public.inventory_items(id)
        ON DELETE SET NULL;
    EXCEPTION
      WHEN duplicate_object THEN NULL;
    END;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Inspections
-- Note: Volume 3/CRM may have a legacy public.inspections (property_id).
-- PMS uses property_inspections. If an empty CRM-shaped inspections table
-- exists without asset_id, rename it so EAFMS can own public.inspections.
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'inspections'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'inspections' AND column_name = 'asset_id'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'inspections' AND column_name = 'property_id'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'legacy_crm_inspections'
  ) THEN
    -- Only rename when empty (safe for greenfield / unused CRM stub)
    IF (SELECT COUNT(*) FROM public.inspections) = 0 THEN
      ALTER TABLE public.inspections RENAME TO legacy_crm_inspections;
    END IF;
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.inspections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  title text NOT NULL,
  asset_id uuid REFERENCES public.assets(id) ON DELETE SET NULL,
  facility_id uuid REFERENCES public.facilities(id) ON DELETE SET NULL,
  inspection_type text NOT NULL DEFAULT 'routine'
    CHECK (inspection_type IN ('routine','safety','compliance','handover','other')),
  status text NOT NULL DEFAULT 'scheduled'
    CHECK (status IN ('scheduled','in_progress','passed','failed','cancelled')),
  scheduled_at timestamptz,
  completed_at timestamptz,
  inspector_label text,
  score_pct numeric(5,2),
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inspections_status
  ON public.inspections(status, created_at DESC);

CREATE TABLE IF NOT EXISTS public.inspection_checklists (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inspection_id uuid NOT NULL REFERENCES public.inspections(id) ON DELETE CASCADE,
  line_no int NOT NULL DEFAULT 1,
  item_label text NOT NULL,
  result text NOT NULL DEFAULT 'pending'
    CHECK (result IN ('pending','pass','fail','na')),
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS public.inspection_findings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inspection_id uuid NOT NULL REFERENCES public.inspections(id) ON DELETE CASCADE,
  severity text NOT NULL DEFAULT 'medium'
    CHECK (severity IN ('low','medium','high','critical')),
  title text NOT NULL,
  description text,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','mitigated','closed')),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Fleet
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.fleet_vehicles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_id uuid REFERENCES public.assets(id) ON DELETE SET NULL,
  plate_number text UNIQUE,
  make_label text,
  model_label text,
  year_label text,
  fuel_type text NOT NULL DEFAULT 'petrol'
    CHECK (fuel_type IN ('petrol','diesel','hybrid','electric','other')),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','in_shop','reserved','retired')),
  odometer_km numeric(12,1) DEFAULT 0,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.vehicle_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id uuid NOT NULL REFERENCES public.fleet_vehicles(id) ON DELETE CASCADE,
  driver_label text NOT NULL,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','returned','cancelled')),
  assigned_at timestamptz NOT NULL DEFAULT now(),
  returned_at timestamptz,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS public.fuel_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id uuid NOT NULL REFERENCES public.fleet_vehicles(id) ON DELETE CASCADE,
  logged_at timestamptz NOT NULL DEFAULT now(),
  liters numeric(12,2) NOT NULL DEFAULT 0,
  cost_amount numeric(18,2) DEFAULT 0,
  currency text NOT NULL DEFAULT 'NGN',
  odometer_km numeric(12,1),
  station_label text,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

-- ---------------------------------------------------------------------------
-- Utilities
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.utility_meters (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_id uuid REFERENCES public.facilities(id) ON DELETE SET NULL,
  code text UNIQUE,
  meter_type text NOT NULL DEFAULT 'electricity'
    CHECK (meter_type IN ('electricity','water','gas','diesel','other')),
  unit_label text NOT NULL DEFAULT 'kWh',
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','inactive','faulty')),
  location_label text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.utility_readings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meter_id uuid NOT NULL REFERENCES public.utility_meters(id) ON DELETE CASCADE,
  reading_value numeric(18,3) NOT NULL DEFAULT 0,
  read_at timestamptz NOT NULL DEFAULT now(),
  reader_label text,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

-- ---------------------------------------------------------------------------
-- Reports, activity (NOT asset_usage_logs), notifications, AI
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.asset_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  report_type text NOT NULL DEFAULT 'register'
    CHECK (report_type IN ('register','maintenance','fleet','utilities','depreciation','other')),
  period_label text,
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.asset_activity_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  action text NOT NULL,
  summary text NOT NULL,
  actor_label text,
  entity_type text,
  entity_id uuid,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_asset_activity_logs_occurred
  ON public.asset_activity_logs(occurred_at DESC);

CREATE TABLE IF NOT EXISTS public.asset_notifications (
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

CREATE TABLE IF NOT EXISTS public.asset_ai_insights (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  body text NOT NULL,
  insight_type text NOT NULL DEFAULT 'advisory',
  confidence_pct numeric(5,2),
  editable boolean NOT NULL DEFAULT true,
  disclaimer text NOT NULL DEFAULT 'AI-generated — editable / advisory',
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Storage bucket: asset-documents
-- ---------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  (
    'asset-documents',
    'asset-documents',
    false,
    52428800,
    ARRAY[
      'application/pdf',
      'image/jpeg',
      'image/png',
      'image/webp',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    ]
  )
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS storage_asset_documents_staff ON storage.objects;
CREATE POLICY storage_asset_documents_staff ON storage.objects
  FOR ALL TO authenticated
  USING (
    bucket_id = 'asset-documents'
    AND (
      public.has_permission('assets.read', auth.uid())
      OR public.has_permission('assets.register', auth.uid())
      OR public.has_role('super_admin', auth.uid())
    )
  )
  WITH CHECK (
    bucket_id = 'asset-documents'
    AND (
      public.has_permission('assets.write', auth.uid())
      OR public.has_permission('assets.register', auth.uid())
      OR public.has_role('super_admin', auth.uid())
    )
  );

-- ---------------------------------------------------------------------------
-- Seed data (hex-only UUIDs c140…)
-- ---------------------------------------------------------------------------
INSERT INTO public.asset_categories (id, slug, name, description, sort_order) VALUES
  ('c1400001-0000-4000-8000-000000000001', 'it-equipment', 'IT Equipment', 'Laptops, servers, network gear', 10),
  ('c1400001-0000-4000-8000-000000000002', 'fleet', 'Fleet Vehicles', 'Company cars and site vehicles', 20),
  ('c1400001-0000-4000-8000-000000000003', 'construction-equipment', 'Construction Equipment', 'Plant and heavy equipment', 30),
  ('c1400001-0000-4000-8000-000000000004', 'facility-systems', 'Facility Systems', 'HVAC, lifts, generators', 40)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.facilities (id, code, name, facility_type, status, address_label, city, floors, area_sqm) VALUES
  (
    'c1400002-0000-4000-8000-000000000001',
    'FAC-HQ-01', 'HD Homes HQ', 'hq', 'active',
    'Victoria Island Corporate Tower', 'Lagos', 8, 4200
  ),
  (
    'c1400002-0000-4000-8000-000000000002',
    'FAC-SITE-01', 'Oceanview Phase 2 Site', 'site', 'active',
    'Lekki Free Trade Zone Access', 'Lagos', 1, 18500
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.facility_zones (id, facility_id, code, name, zone_type, floor_label) VALUES
  (
    'c1400003-0000-4000-8000-000000000001',
    'c1400002-0000-4000-8000-000000000001',
    'Z-HQ-L3', 'HQ Floor 3 — Ops', 'floor', 'L3'
  ),
  (
    'c1400003-0000-4000-8000-000000000002',
    'c1400002-0000-4000-8000-000000000002',
    'Z-SITE-YARD', 'Site Plant Yard', 'yard', 'Ground'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.asset_locations (id, code, name, facility_id, zone_id, location_label) VALUES
  (
    'c1400004-0000-4000-8000-000000000001',
    'LOC-HQ-IT', 'HQ IT Cage',
    'c1400002-0000-4000-8000-000000000001',
    'c1400003-0000-4000-8000-000000000001',
    'Secure IT cage L3'
  ),
  (
    'c1400004-0000-4000-8000-000000000002',
    'LOC-SITE-YARD', 'Site Equipment Bay',
    'c1400002-0000-4000-8000-000000000002',
    'c1400003-0000-4000-8000-000000000002',
    'Plant yard bay A'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.assets (
  id, asset_tag, name, category_id, asset_class, status, serial_number,
  manufacturer, model_label, facility_id, location_id, purchase_cost,
  purchase_date, in_service_date, condition_label, criticality
) VALUES
  (
    'c1400005-0000-4000-8000-000000000001',
    'AST-IT-1401', 'Dell Latitude 5540 — Ops Lead',
    'c1400001-0000-4000-8000-000000000001', 'it', 'assigned',
    'DL5540-NG-88421', 'Dell', 'Latitude 5540',
    'c1400002-0000-4000-8000-000000000001',
    'c1400004-0000-4000-8000-000000000001',
    1250000, '2025-03-12', '2025-03-20', 'good', 'medium'
  ),
  (
    'c1400005-0000-4000-8000-000000000002',
    'AST-FLT-1401', 'Toyota Hilux — Site Runner',
    'c1400001-0000-4000-8000-000000000002', 'fleet', 'active',
    'TH-HIL-2024-091', 'Toyota', 'Hilux 2.8',
    'c1400002-0000-4000-8000-000000000002',
    'c1400004-0000-4000-8000-000000000002',
    28500000, '2024-11-01', '2024-11-15', 'good', 'high'
  ),
  (
    'c1400005-0000-4000-8000-000000000003',
    'AST-CEQ-1401', 'Boom Lift — Genie S-65',
    'c1400001-0000-4000-8000-000000000003', 'construction', 'in_maintenance',
    'GN-S65-77812', 'Genie', 'S-65',
    'c1400002-0000-4000-8000-000000000002',
    'c1400004-0000-4000-8000-000000000002',
    42000000, '2023-06-18', '2023-07-01', 'fair', 'critical'
  ),
  (
    'c1400005-0000-4000-8000-000000000004',
    'AST-FAC-1401', 'HQ Generator 250kVA',
    'c1400001-0000-4000-8000-000000000004', 'facility', 'active',
    'GEN-250-HQ-01', 'Perkins', '250kVA Silent',
    'c1400002-0000-4000-8000-000000000001',
    'c1400004-0000-4000-8000-000000000001',
    18500000, '2022-01-10', '2022-02-01', 'good', 'critical'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.asset_assignments (
  id, asset_id, assignee_label, assignment_type, status, assigned_at
) VALUES
  (
    'c1400006-0000-4000-8000-000000000001',
    'c1400005-0000-4000-8000-000000000001',
    'Ops Lead — Lagos', 'custody', 'active', now() - interval '120 days'
  ),
  (
    'c1400006-0000-4000-8000-000000000002',
    'c1400005-0000-4000-8000-000000000002',
    'Site Logistics', 'fleet', 'active', now() - interval '60 days'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.asset_warranties (
  id, asset_id, provider_label, warranty_type, starts_on, ends_on, status, coverage_notes
) VALUES
  (
    'c1400007-0000-4000-8000-000000000001',
    'c1400005-0000-4000-8000-000000000001',
    'Dell ProSupport', 'manufacturer',
    '2025-03-12', CURRENT_DATE + interval '45 days', 'active',
    'Parts + onsite — expiry approaching'
  ),
  (
    'c1400007-0000-4000-8000-000000000002',
    'c1400005-0000-4000-8000-000000000003',
    'Genie Extended Care', 'extended',
    '2023-07-01', '2026-07-01', 'active',
    'Hydraulics and boom structural coverage'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.asset_depreciation (
  id, asset_id, method, useful_life_months, salvage_value, book_value, monthly_amount, as_of_date, status
) VALUES
  (
    'c1400008-0000-4000-8000-000000000001',
    'c1400005-0000-4000-8000-000000000001',
    'straight_line', 36, 50000, 875000, 33333.33, CURRENT_DATE, 'active'
  ),
  (
    'c1400008-0000-4000-8000-000000000002',
    'c1400005-0000-4000-8000-000000000003',
    'straight_line', 84, 2000000, 31000000, 47619.05, CURRENT_DATE, 'active'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.maintenance_plans (
  id, code, title, asset_id, facility_id, plan_type, frequency_days, status, summary
) VALUES
  (
    'c1400009-0000-4000-8000-000000000001',
    'MP-1401', 'Boom Lift hydraulic PMI',
    'c1400005-0000-4000-8000-000000000003',
    'c1400002-0000-4000-8000-000000000002',
    'preventive', 30, 'active',
    'Monthly hydraulic & safety PMI for Genie S-65'
  ),
  (
    'c1400009-0000-4000-8000-000000000002',
    'MP-1402', 'HQ Generator service',
    'c1400005-0000-4000-8000-000000000004',
    'c1400002-0000-4000-8000-000000000001',
    'preventive', 90, 'active',
    'Quarterly generator load-bank and oil service'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.maintenance_schedules (
  id, plan_id, due_at, status, assignee_label, notes
) VALUES
  (
    'c140000a-0000-4000-8000-000000000001',
    'c1400009-0000-4000-8000-000000000001',
    now() + interval '3 days', 'due', 'Plant Technician',
    'Hydraulic PMI due this week'
  ),
  (
    'c140000a-0000-4000-8000-000000000002',
    'c1400009-0000-4000-8000-000000000002',
    now() + interval '21 days', 'scheduled', 'Facilities Lead',
    'Q3 generator service'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.maintenance_records (
  id, plan_id, schedule_id, asset_id, code, title, status, performed_by, cost_amount, findings
) VALUES
  (
    'c140000b-0000-4000-8000-000000000001',
    'c1400009-0000-4000-8000-000000000001',
    'c140000a-0000-4000-8000-000000000001',
    'c1400005-0000-4000-8000-000000000003',
    'MR-2026-1401', 'Boom Lift PMI — Jul cycle', 'open',
    'Plant Technician', 185000, 'Awaiting hose kit install'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.work_orders (
  id, code, title, asset_id, facility_id, maintenance_plan_id,
  status, priority, assignee_label, requested_by, due_at, estimated_cost, description
) VALUES
  (
    'c140000c-0000-4000-8000-000000000001',
    'WO-2026-1401', 'Replace boom lift hydraulic hose kit',
    'c1400005-0000-4000-8000-000000000003',
    'c1400002-0000-4000-8000-000000000002',
    'c1400009-0000-4000-8000-000000000001',
    'open', 'high', 'Plant Technician', 'Site Manager',
    now() + interval '5 days', 420000,
    'Corrective WO linked to PMI findings'
  ),
  (
    'c140000c-0000-4000-8000-000000000002',
    'WO-2026-1402', 'HQ generator battery bank check',
    'c1400005-0000-4000-8000-000000000004',
    'c1400002-0000-4000-8000-000000000001',
    'c1400009-0000-4000-8000-000000000002',
    'assigned', 'normal', 'Facilities Lead', 'Ops',
    now() + interval '14 days', 95000,
    'Pre-service battery inspection'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.work_order_tasks (id, work_order_id, line_no, title, status, assignee_label) VALUES
  (
    'c140000d-0000-4000-8000-000000000001',
    'c140000c-0000-4000-8000-000000000001',
    1, 'Isolate machine & lockout', 'pending', 'Plant Technician'
  ),
  (
    'c140000d-0000-4000-8000-000000000002',
    'c140000c-0000-4000-8000-000000000001',
    2, 'Install hose kit & pressure test', 'pending', 'Plant Technician'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.work_order_materials (id, work_order_id, line_no, description, quantity, uom, unit_cost) VALUES
  (
    'c140000e-0000-4000-8000-000000000001',
    'c140000c-0000-4000-8000-000000000001',
    1, 'Hydraulic hose kit — Genie S-65', 1, 'kit', 285000
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.inspections (
  id, code, title, asset_id, facility_id, inspection_type, status,
  scheduled_at, inspector_label, score_pct, notes
) VALUES
  (
    'c140000f-0000-4000-8000-000000000001',
    'INS-2026-1401', 'Boom Lift safety inspection',
    'c1400005-0000-4000-8000-000000000003',
    'c1400002-0000-4000-8000-000000000002',
    'safety', 'scheduled', now() + interval '2 days',
    'HSE Officer', NULL, 'Pre-use safety certification'
  ),
  (
    'c140000f-0000-4000-8000-000000000002',
    'INS-2026-1402', 'HQ facility walkthrough',
    NULL,
    'c1400002-0000-4000-8000-000000000001',
    'routine', 'passed', now() - interval '7 days',
    'Facilities Lead', 92, 'Minor lighting defects logged'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.inspection_checklists (id, inspection_id, line_no, item_label, result) VALUES
  (
    'c1400010-0000-4000-8000-000000000001',
    'c140000f-0000-4000-8000-000000000001',
    1, 'Emergency descent functional', 'pending'
  ),
  (
    'c1400010-0000-4000-8000-000000000002',
    'c140000f-0000-4000-8000-000000000002',
    1, 'Fire exits clear', 'pass'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.inspection_findings (
  id, inspection_id, severity, title, description, status
) VALUES
  (
    'c1400011-0000-4000-8000-000000000001',
    'c140000f-0000-4000-8000-000000000002',
    'low', 'Corridor L3 lighting flicker',
    'Two fixtures flickering near IT cage — replace ballast',
    'open'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.fleet_vehicles (
  id, asset_id, plate_number, make_label, model_label, year_label,
  fuel_type, status, odometer_km
) VALUES
  (
    'c1400012-0000-4000-8000-000000000001',
    'c1400005-0000-4000-8000-000000000002',
    'KJA-482-AB', 'Toyota', 'Hilux 2.8', '2024',
    'diesel', 'active', 18450
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.vehicle_assignments (
  id, vehicle_id, driver_label, status, assigned_at
) VALUES
  (
    'c1400013-0000-4000-8000-000000000001',
    'c1400012-0000-4000-8000-000000000001',
    'Site Driver — Chinedu', 'active', now() - interval '45 days'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.fuel_logs (
  id, vehicle_id, logged_at, liters, cost_amount, odometer_km, station_label
) VALUES
  (
    'c1400014-0000-4000-8000-000000000001',
    'c1400012-0000-4000-8000-000000000001',
    now() - interval '2 days', 55, 71500, 18420, 'Total Lekki Express'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.utility_meters (
  id, facility_id, code, meter_type, unit_label, status, location_label
) VALUES
  (
    'c1400015-0000-4000-8000-000000000001',
    'c1400002-0000-4000-8000-000000000001',
    'UM-HQ-ELE-01', 'electricity', 'kWh', 'active', 'HQ basement switchgear'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.utility_readings (
  id, meter_id, reading_value, read_at, reader_label, notes
) VALUES
  (
    'c1400016-0000-4000-8000-000000000001',
    'c1400015-0000-4000-8000-000000000001',
    128450.5, now() - interval '1 day', 'Facilities Lead',
    'Monthly electricity reading'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.maintenance_incidents (
  id, asset_id, facility_id, code, title, severity, status, reported_by, reported_at
) VALUES
  (
    'c1400017-0000-4000-8000-000000000001',
    'c1400005-0000-4000-8000-000000000003',
    'c1400002-0000-4000-8000-000000000002',
    'INC-2026-1401', 'Boom lift hydraulic leak reported',
    'high', 'investigating', 'Site Manager', now() - interval '1 day'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.asset_ai_insights (
  id, title, body, insight_type, confidence_pct, editable, disclaimer
) VALUES
  (
    'c1400018-0000-4000-8000-000000000001',
    'Predictive maintenance — boom lift hose risk',
    'Genie S-65 shows elevated hydraulic PMI urgency. Complete WO-2026-1401 before next lift cycle.',
    'predictive_maintenance', 87, true, 'AI-generated — editable / advisory'
  ),
  (
    'c1400018-0000-4000-8000-000000000002',
    'Warranty expiry — Dell fleet laptop',
    'AST-IT-1401 manufacturer warranty expires within 45 days. Decide renew vs replace.',
    'warranty_risk', 91, true, 'AI-generated — editable / advisory'
  ),
  (
    'c1400018-0000-4000-8000-000000000003',
    'Facility energy watch — HQ meter drift',
    'HQ electricity readings trending above prior 30-day baseline. Validate after-hours loads.',
    'utilities', 74, true, 'AI-generated — editable / advisory'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.asset_activity_logs (id, action, summary, actor_label, entity_type, entity_id, occurred_at) VALUES
  (
    'c1400019-0000-4000-8000-000000000001', 'asset_registered',
    'AST-CEQ-1401 Boom Lift registered in enterprise register',
    'Construction Manager', 'asset', 'c1400005-0000-4000-8000-000000000003',
    now() - interval '30 days'
  ),
  (
    'c1400019-0000-4000-8000-000000000002', 'work_order_opened',
    'WO-2026-1401 opened for boom lift hose kit',
    'Site Manager', 'work_order', 'c140000c-0000-4000-8000-000000000001',
    now() - interval '1 day'
  ),
  (
    'c1400019-0000-4000-8000-000000000003', 'maintenance_due',
    'MP-1401 boom lift PMI marked due',
    'EAFMS Scheduler', 'maintenance_schedule', 'c140000a-0000-4000-8000-000000000001',
    now() - interval '6 hours'
  ),
  (
    'c1400019-0000-4000-8000-000000000004', 'fuel_logged',
    'Fuel log for KJA-482-AB (55L)',
    'Site Driver', 'fuel_log', 'c1400014-0000-4000-8000-000000000001',
    now() - interval '2 days'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.asset_notifications (id, title, body, severity, entity_type, entity_id) VALUES
  (
    'c140001a-0000-4000-8000-000000000001',
    'Maintenance due — Boom Lift PMI',
    'MP-1401 due within 3 days',
    'warning', 'maintenance_schedule', 'c140000a-0000-4000-8000-000000000001'
  ),
  (
    'c140001a-0000-4000-8000-000000000002',
    'Warranty expiring — Dell Latitude',
    'AST-IT-1401 warranty ends within 45 days',
    'info', 'asset_warranty', 'c1400007-0000-4000-8000-000000000001'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.asset_reports (id, title, report_type, period_label, summary) VALUES
  (
    'c140001b-0000-4000-8000-000000000001',
    'Enterprise Asset Register Snapshot',
    'register', 'Jul 2026',
    '4 seeded assets spanning IT, fleet, construction, facility systems.'
  ),
  (
    'c140001b-0000-4000-8000-000000000002',
    'Maintenance & Work Order Weekly',
    'maintenance', 'W28 2026',
    '1 open WO high-priority; boom lift PMI due; warranty expiry watch.'
  )
ON CONFLICT (id) DO NOTHING;

-- Link HCM employee asset seed if present (non-destructive)
UPDATE public.employee_assets
SET enterprise_asset_id = 'c1400005-0000-4000-8000-000000000001'
WHERE enterprise_asset_id IS NULL
  AND asset_tag ILIKE '%AST-IT%'
  AND EXISTS (SELECT 1 FROM public.assets WHERE id = 'c1400005-0000-4000-8000-000000000001');

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.asset_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.asset_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.asset_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.asset_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.asset_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.asset_warranties ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.asset_depreciation ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.facilities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.facility_zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.work_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.work_order_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.work_order_materials ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inspections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inspection_checklists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inspection_findings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fleet_vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicle_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fuel_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.utility_meters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.utility_readings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_incidents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.asset_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.asset_activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.asset_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.asset_ai_insights ENABLE ROW LEVEL SECURITY;

-- Helper policies (slug FIRST)

DROP POLICY IF EXISTS asset_categories_select ON public.asset_categories;
DROP POLICY IF EXISTS asset_categories_write ON public.asset_categories;
CREATE POLICY asset_categories_select ON public.asset_categories FOR SELECT
  USING (public.has_permission('assets.read', auth.uid()) OR public.has_permission('assets.register', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY asset_categories_write ON public.asset_categories FOR ALL
  USING (public.has_permission('assets.register', auth.uid()) OR public.has_permission('assets.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('assets.register', auth.uid()) OR public.has_permission('assets.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS assets_select ON public.assets;
DROP POLICY IF EXISTS assets_write ON public.assets;
CREATE POLICY assets_select ON public.assets FOR SELECT
  USING (public.has_permission('assets.read', auth.uid()) OR public.has_permission('assets.register', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY assets_write ON public.assets FOR ALL
  USING (public.has_permission('assets.register', auth.uid()) OR public.has_permission('assets.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('assets.register', auth.uid()) OR public.has_permission('assets.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS asset_assignments_select ON public.asset_assignments;
DROP POLICY IF EXISTS asset_assignments_write ON public.asset_assignments;
CREATE POLICY asset_assignments_select ON public.asset_assignments FOR SELECT
  USING (public.has_permission('assets.read', auth.uid()) OR public.has_permission('assets.assign', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY asset_assignments_write ON public.asset_assignments FOR ALL
  USING (public.has_permission('assets.assign', auth.uid()) OR public.has_permission('assets.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('assets.assign', auth.uid()) OR public.has_permission('assets.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS asset_locations_select ON public.asset_locations;
DROP POLICY IF EXISTS asset_locations_write ON public.asset_locations;
CREATE POLICY asset_locations_select ON public.asset_locations FOR SELECT
  USING (public.has_permission('assets.read', auth.uid()) OR public.has_permission('assets.facilities', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY asset_locations_write ON public.asset_locations FOR ALL
  USING (public.has_permission('assets.facilities', auth.uid()) OR public.has_permission('assets.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('assets.facilities', auth.uid()) OR public.has_permission('assets.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS asset_movements_select ON public.asset_movements;
DROP POLICY IF EXISTS asset_movements_write ON public.asset_movements;
CREATE POLICY asset_movements_select ON public.asset_movements FOR SELECT
  USING (public.has_permission('assets.read', auth.uid()) OR public.has_permission('assets.assign', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY asset_movements_write ON public.asset_movements FOR ALL
  USING (public.has_permission('assets.assign', auth.uid()) OR public.has_permission('assets.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('assets.assign', auth.uid()) OR public.has_permission('assets.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS asset_documents_select ON public.asset_documents;
DROP POLICY IF EXISTS asset_documents_write ON public.asset_documents;
CREATE POLICY asset_documents_select ON public.asset_documents FOR SELECT
  USING (public.has_permission('assets.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY asset_documents_write ON public.asset_documents FOR ALL
  USING (public.has_permission('assets.write', auth.uid()) OR public.has_permission('assets.register', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('assets.write', auth.uid()) OR public.has_permission('assets.register', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS asset_warranties_select ON public.asset_warranties;
DROP POLICY IF EXISTS asset_warranties_write ON public.asset_warranties;
CREATE POLICY asset_warranties_select ON public.asset_warranties FOR SELECT
  USING (public.has_permission('assets.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY asset_warranties_write ON public.asset_warranties FOR ALL
  USING (public.has_permission('assets.write', auth.uid()) OR public.has_permission('assets.register', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('assets.write', auth.uid()) OR public.has_permission('assets.register', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS asset_depreciation_select ON public.asset_depreciation;
DROP POLICY IF EXISTS asset_depreciation_write ON public.asset_depreciation;
CREATE POLICY asset_depreciation_select ON public.asset_depreciation FOR SELECT
  USING (public.has_permission('assets.depreciation', auth.uid()) OR public.has_permission('assets.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY asset_depreciation_write ON public.asset_depreciation FOR ALL
  USING (public.has_permission('assets.depreciation', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('assets.depreciation', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS facilities_select ON public.facilities;
DROP POLICY IF EXISTS facilities_write ON public.facilities;
CREATE POLICY facilities_select ON public.facilities FOR SELECT
  USING (public.has_permission('assets.read', auth.uid()) OR public.has_permission('assets.facilities', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY facilities_write ON public.facilities FOR ALL
  USING (public.has_permission('assets.facilities', auth.uid()) OR public.has_permission('assets.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('assets.facilities', auth.uid()) OR public.has_permission('assets.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS facility_zones_select ON public.facility_zones;
DROP POLICY IF EXISTS facility_zones_write ON public.facility_zones;
CREATE POLICY facility_zones_select ON public.facility_zones FOR SELECT
  USING (public.has_permission('assets.read', auth.uid()) OR public.has_permission('assets.facilities', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY facility_zones_write ON public.facility_zones FOR ALL
  USING (public.has_permission('assets.facilities', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('assets.facilities', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS maintenance_plans_select ON public.maintenance_plans;
DROP POLICY IF EXISTS maintenance_plans_write ON public.maintenance_plans;
CREATE POLICY maintenance_plans_select ON public.maintenance_plans FOR SELECT
  USING (public.has_permission('assets.read', auth.uid()) OR public.has_permission('assets.maintenance', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY maintenance_plans_write ON public.maintenance_plans FOR ALL
  USING (public.has_permission('assets.maintenance', auth.uid()) OR public.has_permission('assets.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('assets.maintenance', auth.uid()) OR public.has_permission('assets.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS maintenance_schedules_select ON public.maintenance_schedules;
DROP POLICY IF EXISTS maintenance_schedules_write ON public.maintenance_schedules;
CREATE POLICY maintenance_schedules_select ON public.maintenance_schedules FOR SELECT
  USING (public.has_permission('assets.read', auth.uid()) OR public.has_permission('assets.maintenance', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY maintenance_schedules_write ON public.maintenance_schedules FOR ALL
  USING (public.has_permission('assets.maintenance', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('assets.maintenance', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS maintenance_records_select ON public.maintenance_records;
DROP POLICY IF EXISTS maintenance_records_write ON public.maintenance_records;
CREATE POLICY maintenance_records_select ON public.maintenance_records FOR SELECT
  USING (public.has_permission('assets.read', auth.uid()) OR public.has_permission('assets.maintenance', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY maintenance_records_write ON public.maintenance_records FOR ALL
  USING (public.has_permission('assets.maintenance', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('assets.maintenance', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS work_orders_select ON public.work_orders;
DROP POLICY IF EXISTS work_orders_write ON public.work_orders;
CREATE POLICY work_orders_select ON public.work_orders FOR SELECT
  USING (public.has_permission('assets.read', auth.uid()) OR public.has_permission('assets.workorders', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY work_orders_write ON public.work_orders FOR ALL
  USING (public.has_permission('assets.workorders', auth.uid()) OR public.has_permission('assets.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('assets.workorders', auth.uid()) OR public.has_permission('assets.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS work_order_tasks_select ON public.work_order_tasks;
DROP POLICY IF EXISTS work_order_tasks_write ON public.work_order_tasks;
CREATE POLICY work_order_tasks_select ON public.work_order_tasks FOR SELECT
  USING (public.has_permission('assets.read', auth.uid()) OR public.has_permission('assets.workorders', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY work_order_tasks_write ON public.work_order_tasks FOR ALL
  USING (public.has_permission('assets.workorders', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('assets.workorders', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS work_order_materials_select ON public.work_order_materials;
DROP POLICY IF EXISTS work_order_materials_write ON public.work_order_materials;
CREATE POLICY work_order_materials_select ON public.work_order_materials FOR SELECT
  USING (public.has_permission('assets.read', auth.uid()) OR public.has_permission('assets.workorders', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY work_order_materials_write ON public.work_order_materials FOR ALL
  USING (public.has_permission('assets.workorders', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('assets.workorders', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS inspections_select ON public.inspections;
DROP POLICY IF EXISTS inspections_write ON public.inspections;
CREATE POLICY inspections_select ON public.inspections FOR SELECT
  USING (public.has_permission('assets.read', auth.uid()) OR public.has_permission('assets.inspections', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY inspections_write ON public.inspections FOR ALL
  USING (public.has_permission('assets.inspections', auth.uid()) OR public.has_permission('assets.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('assets.inspections', auth.uid()) OR public.has_permission('assets.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS inspection_checklists_select ON public.inspection_checklists;
DROP POLICY IF EXISTS inspection_checklists_write ON public.inspection_checklists;
CREATE POLICY inspection_checklists_select ON public.inspection_checklists FOR SELECT
  USING (public.has_permission('assets.read', auth.uid()) OR public.has_permission('assets.inspections', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY inspection_checklists_write ON public.inspection_checklists FOR ALL
  USING (public.has_permission('assets.inspections', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('assets.inspections', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS inspection_findings_select ON public.inspection_findings;
DROP POLICY IF EXISTS inspection_findings_write ON public.inspection_findings;
CREATE POLICY inspection_findings_select ON public.inspection_findings FOR SELECT
  USING (public.has_permission('assets.read', auth.uid()) OR public.has_permission('assets.inspections', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY inspection_findings_write ON public.inspection_findings FOR ALL
  USING (public.has_permission('assets.inspections', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('assets.inspections', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS fleet_vehicles_select ON public.fleet_vehicles;
DROP POLICY IF EXISTS fleet_vehicles_write ON public.fleet_vehicles;
CREATE POLICY fleet_vehicles_select ON public.fleet_vehicles FOR SELECT
  USING (public.has_permission('assets.read', auth.uid()) OR public.has_permission('assets.fleet', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY fleet_vehicles_write ON public.fleet_vehicles FOR ALL
  USING (public.has_permission('assets.fleet', auth.uid()) OR public.has_permission('assets.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('assets.fleet', auth.uid()) OR public.has_permission('assets.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS vehicle_assignments_select ON public.vehicle_assignments;
DROP POLICY IF EXISTS vehicle_assignments_write ON public.vehicle_assignments;
CREATE POLICY vehicle_assignments_select ON public.vehicle_assignments FOR SELECT
  USING (public.has_permission('assets.read', auth.uid()) OR public.has_permission('assets.fleet', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY vehicle_assignments_write ON public.vehicle_assignments FOR ALL
  USING (public.has_permission('assets.fleet', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('assets.fleet', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS fuel_logs_select ON public.fuel_logs;
DROP POLICY IF EXISTS fuel_logs_write ON public.fuel_logs;
CREATE POLICY fuel_logs_select ON public.fuel_logs FOR SELECT
  USING (public.has_permission('assets.read', auth.uid()) OR public.has_permission('assets.fleet', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY fuel_logs_write ON public.fuel_logs FOR ALL
  USING (public.has_permission('assets.fleet', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('assets.fleet', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS utility_meters_select ON public.utility_meters;
DROP POLICY IF EXISTS utility_meters_write ON public.utility_meters;
CREATE POLICY utility_meters_select ON public.utility_meters FOR SELECT
  USING (public.has_permission('assets.read', auth.uid()) OR public.has_permission('assets.utilities', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY utility_meters_write ON public.utility_meters FOR ALL
  USING (public.has_permission('assets.utilities', auth.uid()) OR public.has_permission('assets.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('assets.utilities', auth.uid()) OR public.has_permission('assets.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS utility_readings_select ON public.utility_readings;
DROP POLICY IF EXISTS utility_readings_write ON public.utility_readings;
CREATE POLICY utility_readings_select ON public.utility_readings FOR SELECT
  USING (public.has_permission('assets.read', auth.uid()) OR public.has_permission('assets.utilities', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY utility_readings_write ON public.utility_readings FOR ALL
  USING (public.has_permission('assets.utilities', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('assets.utilities', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS maintenance_incidents_select ON public.maintenance_incidents;
DROP POLICY IF EXISTS maintenance_incidents_write ON public.maintenance_incidents;
CREATE POLICY maintenance_incidents_select ON public.maintenance_incidents FOR SELECT
  USING (public.has_permission('assets.read', auth.uid()) OR public.has_permission('assets.maintenance', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY maintenance_incidents_write ON public.maintenance_incidents FOR ALL
  USING (public.has_permission('assets.maintenance', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('assets.maintenance', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS asset_reports_select ON public.asset_reports;
DROP POLICY IF EXISTS asset_reports_write ON public.asset_reports;
CREATE POLICY asset_reports_select ON public.asset_reports FOR SELECT
  USING (public.has_permission('assets.reports', auth.uid()) OR public.has_permission('assets.analytics', auth.uid()) OR public.has_permission('assets.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY asset_reports_write ON public.asset_reports FOR ALL
  USING (public.has_permission('assets.reports', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('assets.reports', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS asset_activity_logs_select ON public.asset_activity_logs;
DROP POLICY IF EXISTS asset_activity_logs_write ON public.asset_activity_logs;
CREATE POLICY asset_activity_logs_select ON public.asset_activity_logs FOR SELECT
  USING (public.has_permission('assets.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY asset_activity_logs_write ON public.asset_activity_logs FOR ALL
  USING (public.has_permission('assets.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('assets.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS asset_notifications_select ON public.asset_notifications;
DROP POLICY IF EXISTS asset_notifications_write ON public.asset_notifications;
CREATE POLICY asset_notifications_select ON public.asset_notifications FOR SELECT
  USING (public.has_permission('assets.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY asset_notifications_write ON public.asset_notifications FOR ALL
  USING (public.has_permission('assets.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('assets.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS asset_ai_insights_select ON public.asset_ai_insights;
DROP POLICY IF EXISTS asset_ai_insights_write ON public.asset_ai_insights;
CREATE POLICY asset_ai_insights_select ON public.asset_ai_insights FOR SELECT
  USING (public.has_permission('assets.ai', auth.uid()) OR public.has_permission('assets.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY asset_ai_insights_write ON public.asset_ai_insights FOR ALL
  USING (public.has_permission('assets.ai', auth.uid()) OR public.has_permission('assets.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('assets.ai', auth.uid()) OR public.has_permission('assets.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE ON
  public.asset_categories,
  public.assets,
  public.asset_assignments,
  public.asset_locations,
  public.asset_movements,
  public.asset_documents,
  public.asset_warranties,
  public.asset_depreciation,
  public.facilities,
  public.facility_zones,
  public.maintenance_plans,
  public.maintenance_schedules,
  public.maintenance_records,
  public.work_orders,
  public.work_order_tasks,
  public.work_order_materials,
  public.inspections,
  public.inspection_checklists,
  public.inspection_findings,
  public.fleet_vehicles,
  public.vehicle_assignments,
  public.fuel_logs,
  public.utility_meters,
  public.utility_readings,
  public.maintenance_incidents,
  public.asset_reports,
  public.asset_activity_logs,
  public.asset_notifications,
  public.asset_ai_insights
TO authenticated;

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'assets',
    'work_orders',
    'maintenance_records',
    'inspections',
    'asset_activity_logs',
    'asset_notifications'
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
