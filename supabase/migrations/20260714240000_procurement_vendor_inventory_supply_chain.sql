-- APPLIED remotely 2026-07-15 (chunked procurement_vendor_inventory_p1–p3)
-- Volume 4 Part 13 — Procurement, Vendor, Inventory & Supply Chain Management (PVISCM)
-- Status: APPLIED remotely 2026-07-15.
--
-- Approach:
--   • NEVER recreate/drop CPMS project-scoped tables:
--     project_suppliers, project_materials, project_inventory_usage,
--     project_procurement_requests, project_purchase_orders.
--   • Optional: ALTER ADD COLUMN IF NOT EXISTS linking columns (enterprise_vendor_id).
--   • EOC already has approval_workflows / approval_requests — use procurement_approvals.
--   • DDCMS has contract_records — use supplier_contracts for procurement agreements.
--   • Prefer public.purchase_orders (does not exist yet) for enterprise POs.
--   • Seed UUIDs hex-only (b130…).
--   • Permissions: slug, name, description, module ONLY.
--   • RLS: has_permission('slug', auth.uid()) — slug FIRST.
--
-- Volume 4 continues Parts 14–25. Wait for approve before Part 14.

BEGIN;

-- ---------------------------------------------------------------------------
-- Permissions
-- ---------------------------------------------------------------------------
INSERT INTO public.permissions (slug, name, description, module) VALUES
  ('procurement.read', 'View Procurement', 'View Procurement Command Center', 'procurement'),
  ('procurement.write', 'Manage Procurement', 'Create and edit procurement records', 'procurement'),
  ('procurement.vendors', 'Manage Vendors', 'Manage vendors and supplier intelligence', 'procurement'),
  ('procurement.requisitions', 'Manage Requisitions', 'Create and manage purchase requisitions', 'procurement'),
  ('procurement.rfq', 'Manage RFQs', 'Manage RFQs and supplier quotes', 'procurement'),
  ('procurement.orders', 'Manage Purchase Orders', 'Create and manage enterprise purchase orders', 'procurement'),
  ('procurement.receiving', 'Manage Receiving', 'Record goods receipts and GRNs', 'procurement'),
  ('procurement.inventory', 'Manage Inventory', 'Manage inventory items and stock levels', 'procurement'),
  ('procurement.warehouse', 'Manage Warehouses', 'Manage warehouses and locations', 'procurement'),
  ('procurement.logistics', 'Manage Logistics', 'Manage logistics shipments', 'procurement'),
  ('procurement.approvals', 'Procurement Approvals', 'Approve procurement requests and orders', 'procurement'),
  ('procurement.analytics', 'Procurement Analytics', 'View procurement KPIs and analytics', 'procurement'),
  ('procurement.ai', 'Procurement AI', 'Use procurement AI intelligence tools', 'procurement'),
  ('procurement.reports', 'Procurement Reports', 'Generate and view procurement reports', 'procurement')
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  module = EXCLUDED.module,
  updated_at = now();

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE p.slug LIKE 'procurement.%'
  AND (
    r.slug IN ('super_admin', 'admin')
    OR (r.slug = 'finance' AND p.slug IN (
      'procurement.read', 'procurement.orders', 'procurement.approvals',
      'procurement.analytics', 'procurement.reports', 'procurement.vendors'
    ))
    OR (r.slug = 'construction_manager' AND p.slug IN (
      'procurement.read', 'procurement.requisitions', 'procurement.orders',
      'procurement.receiving', 'procurement.inventory', 'procurement.warehouse',
      'procurement.vendors'
    ))
    OR (r.slug = 'sales_team' AND p.slug IN (
      'procurement.read', 'procurement.requisitions'
    ))
    OR (r.slug = 'marketing' AND p.slug IN (
      'procurement.read', 'procurement.requisitions', 'procurement.inventory'
    ))
  )
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Optional CPMS linking columns (do NOT recreate project_* tables)
-- ---------------------------------------------------------------------------
ALTER TABLE public.project_suppliers
  ADD COLUMN IF NOT EXISTS enterprise_vendor_id uuid;
ALTER TABLE public.project_purchase_orders
  ADD COLUMN IF NOT EXISTS enterprise_po_id uuid;
ALTER TABLE public.project_procurement_requests
  ADD COLUMN IF NOT EXISTS enterprise_requisition_id uuid;

-- ---------------------------------------------------------------------------
-- Vendors
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.vendor_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  description text,
  sort_order int NOT NULL DEFAULT 100,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.vendors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  name text NOT NULL,
  category_id uuid REFERENCES public.vendor_categories(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('prospect','active','preferred','suspended','blacklisted')),
  tier text NOT NULL DEFAULT 'standard'
    CHECK (tier IN ('strategic','preferred','standard','trial')),
  contact_email text,
  contact_phone text,
  city text,
  country text DEFAULT 'NG',
  payment_terms text,
  lead_time_days int DEFAULT 7,
  rating_avg numeric(4,2) DEFAULT 0,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_vendors_status ON public.vendors(status);
CREATE INDEX IF NOT EXISTS idx_vendors_category ON public.vendors(category_id);

CREATE TABLE IF NOT EXISTS public.vendor_contacts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id uuid NOT NULL REFERENCES public.vendors(id) ON DELETE CASCADE,
  full_name text NOT NULL,
  role_title text,
  email text,
  phone text,
  is_primary boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.vendor_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id uuid NOT NULL REFERENCES public.vendors(id) ON DELETE CASCADE,
  title text NOT NULL,
  doc_type text NOT NULL DEFAULT 'other'
    CHECK (doc_type IN ('certificate','insurance','tax','contract','catalog','other')),
  storage_bucket text DEFAULT 'vendor-documents',
  storage_path text,
  expires_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.vendor_ratings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id uuid NOT NULL REFERENCES public.vendors(id) ON DELETE CASCADE,
  score numeric(4,2) NOT NULL CHECK (score >= 0 AND score <= 5),
  category text NOT NULL DEFAULT 'overall'
    CHECK (category IN ('overall','quality','delivery','price','service')),
  notes text,
  rated_by text,
  rated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Planning & requisitions
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.procurement_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  title text NOT NULL,
  period_label text,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','active','closed','cancelled')),
  budget_amount numeric(18,2) DEFAULT 0,
  currency text NOT NULL DEFAULT 'NGN',
  summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.purchase_requisitions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid REFERENCES public.procurement_plans(id) ON DELETE SET NULL,
  code text UNIQUE,
  title text NOT NULL,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','submitted','approved','rejected','converted','cancelled')),
  requester_label text,
  department text,
  priority text NOT NULL DEFAULT 'normal'
    CHECK (priority IN ('low','normal','high','urgent')),
  needed_by date,
  estimated_total numeric(18,2) DEFAULT 0,
  currency text NOT NULL DEFAULT 'NGN',
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_purchase_requisitions_status
  ON public.purchase_requisitions(status, created_at DESC);

CREATE TABLE IF NOT EXISTS public.requisition_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  requisition_id uuid NOT NULL REFERENCES public.purchase_requisitions(id) ON DELETE CASCADE,
  line_no int NOT NULL DEFAULT 1,
  description text NOT NULL,
  sku text,
  quantity numeric(18,3) NOT NULL DEFAULT 1,
  uom text NOT NULL DEFAULT 'ea',
  unit_estimate numeric(18,2) DEFAULT 0,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS public.procurement_approvals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  entity_type text NOT NULL DEFAULT 'requisition'
    CHECK (entity_type IN ('requisition','rfq','purchase_order','transfer','contract')),
  entity_id uuid,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','approved','rejected','cancelled')),
  requester_label text,
  approver_label text,
  amount numeric(18,2),
  currency text DEFAULT 'NGN',
  decided_at timestamptz,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_procurement_approvals_status
  ON public.procurement_approvals(status, created_at DESC);

-- ---------------------------------------------------------------------------
-- RFQ / quotes
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.rfqs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  requisition_id uuid REFERENCES public.purchase_requisitions(id) ON DELETE SET NULL,
  code text UNIQUE,
  title text NOT NULL,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','issued','quoting','closed','awarded','cancelled')),
  due_at timestamptz,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.rfq_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rfq_id uuid NOT NULL REFERENCES public.rfqs(id) ON DELETE CASCADE,
  line_no int NOT NULL DEFAULT 1,
  description text NOT NULL,
  quantity numeric(18,3) NOT NULL DEFAULT 1,
  uom text NOT NULL DEFAULT 'ea',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS public.rfq_vendors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rfq_id uuid NOT NULL REFERENCES public.rfqs(id) ON DELETE CASCADE,
  vendor_id uuid NOT NULL REFERENCES public.vendors(id) ON DELETE CASCADE,
  invite_status text NOT NULL DEFAULT 'invited'
    CHECK (invite_status IN ('invited','responded','declined','awarded')),
  UNIQUE (rfq_id, vendor_id)
);

CREATE TABLE IF NOT EXISTS public.supplier_quotes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rfq_id uuid NOT NULL REFERENCES public.rfqs(id) ON DELETE CASCADE,
  vendor_id uuid NOT NULL REFERENCES public.vendors(id) ON DELETE CASCADE,
  quote_number text,
  status text NOT NULL DEFAULT 'submitted'
    CHECK (status IN ('draft','submitted','shortlisted','awarded','rejected','expired')),
  total_amount numeric(18,2) DEFAULT 0,
  currency text NOT NULL DEFAULT 'NGN',
  lead_time_days int,
  valid_until date,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.quote_comparisons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rfq_id uuid NOT NULL REFERENCES public.rfqs(id) ON DELETE CASCADE,
  title text NOT NULL,
  winner_quote_id uuid REFERENCES public.supplier_quotes(id) ON DELETE SET NULL,
  summary text,
  criteria jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Enterprise purchase orders (distinct from project_purchase_orders)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.purchase_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rfq_id uuid REFERENCES public.rfqs(id) ON DELETE SET NULL,
  requisition_id uuid REFERENCES public.purchase_requisitions(id) ON DELETE SET NULL,
  vendor_id uuid REFERENCES public.vendors(id) ON DELETE SET NULL,
  code text UNIQUE,
  title text NOT NULL,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','issued','acknowledged','partial','received','closed','cancelled')),
  order_date date DEFAULT CURRENT_DATE,
  expected_date date,
  currency text NOT NULL DEFAULT 'NGN',
  subtotal numeric(18,2) DEFAULT 0,
  tax_amount numeric(18,2) DEFAULT 0,
  total_amount numeric(18,2) DEFAULT 0,
  shipping_address text,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_purchase_orders_status
  ON public.purchase_orders(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_vendor
  ON public.purchase_orders(vendor_id);

CREATE TABLE IF NOT EXISTS public.purchase_order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  purchase_order_id uuid NOT NULL REFERENCES public.purchase_orders(id) ON DELETE CASCADE,
  line_no int NOT NULL DEFAULT 1,
  description text NOT NULL,
  sku text,
  quantity numeric(18,3) NOT NULL DEFAULT 1,
  uom text NOT NULL DEFAULT 'ea',
  unit_price numeric(18,2) DEFAULT 0,
  line_total numeric(18,2) DEFAULT 0,
  received_qty numeric(18,3) DEFAULT 0,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

-- ---------------------------------------------------------------------------
-- Goods receipts
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.goods_receipts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  purchase_order_id uuid REFERENCES public.purchase_orders(id) ON DELETE SET NULL,
  code text UNIQUE,
  title text NOT NULL,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','posted','partial','cancelled')),
  received_at timestamptz DEFAULT now(),
  received_by text,
  warehouse_label text,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.goods_receipt_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  goods_receipt_id uuid NOT NULL REFERENCES public.goods_receipts(id) ON DELETE CASCADE,
  purchase_order_item_id uuid REFERENCES public.purchase_order_items(id) ON DELETE SET NULL,
  description text NOT NULL,
  quantity numeric(18,3) NOT NULL DEFAULT 1,
  uom text NOT NULL DEFAULT 'ea',
  condition_note text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

-- ---------------------------------------------------------------------------
-- Warehouses & inventory
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.warehouses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  name text NOT NULL,
  location_label text,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','inactive','maintenance')),
  is_default boolean NOT NULL DEFAULT false,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.warehouse_locations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  warehouse_id uuid NOT NULL REFERENCES public.warehouses(id) ON DELETE CASCADE,
  code text NOT NULL,
  name text NOT NULL,
  zone text,
  aisle text,
  bin text,
  is_active boolean NOT NULL DEFAULT true,
  UNIQUE (warehouse_id, code)
);

CREATE TABLE IF NOT EXISTS public.inventory_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sku text UNIQUE,
  name text NOT NULL,
  category text,
  uom text NOT NULL DEFAULT 'ea',
  reorder_point numeric(18,3) DEFAULT 0,
  reorder_qty numeric(18,3) DEFAULT 0,
  on_hand numeric(18,3) NOT NULL DEFAULT 0,
  reserved_qty numeric(18,3) NOT NULL DEFAULT 0,
  unit_cost numeric(18,2) DEFAULT 0,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','low_stock','out_of_stock','discontinued')),
  warehouse_id uuid REFERENCES public.warehouses(id) ON DELETE SET NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inventory_items_status ON public.inventory_items(status);
CREATE INDEX IF NOT EXISTS idx_inventory_items_warehouse ON public.inventory_items(warehouse_id);

CREATE TABLE IF NOT EXISTS public.inventory_batches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inventory_item_id uuid NOT NULL REFERENCES public.inventory_items(id) ON DELETE CASCADE,
  batch_code text NOT NULL,
  quantity numeric(18,3) NOT NULL DEFAULT 0,
  received_at timestamptz DEFAULT now(),
  expiry_date date,
  warehouse_location_id uuid REFERENCES public.warehouse_locations(id) ON DELETE SET NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS public.inventory_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inventory_item_id uuid REFERENCES public.inventory_items(id) ON DELETE SET NULL,
  txn_type text NOT NULL DEFAULT 'receipt'
    CHECK (txn_type IN ('receipt','issue','transfer','adjustment','return')),
  quantity numeric(18,3) NOT NULL,
  reference_label text,
  notes text,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  actor_label text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_inventory_transactions_occurred
  ON public.inventory_transactions(occurred_at DESC);

CREATE TABLE IF NOT EXISTS public.inventory_adjustments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inventory_item_id uuid NOT NULL REFERENCES public.inventory_items(id) ON DELETE CASCADE,
  quantity_delta numeric(18,3) NOT NULL,
  reason text NOT NULL,
  status text NOT NULL DEFAULT 'posted'
    CHECK (status IN ('draft','posted','cancelled')),
  adjusted_by text,
  adjusted_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS public.stock_transfers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE,
  from_warehouse_id uuid REFERENCES public.warehouses(id) ON DELETE SET NULL,
  to_warehouse_id uuid REFERENCES public.warehouses(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','in_transit','received','cancelled')),
  title text NOT NULL,
  shipped_at timestamptz,
  received_at timestamptz,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Logistics & supplier contracts
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.logistics_shipments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  purchase_order_id uuid REFERENCES public.purchase_orders(id) ON DELETE SET NULL,
  code text UNIQUE,
  carrier text,
  tracking_number text,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','in_transit','delivered','delayed','cancelled')),
  origin_label text,
  destination_label text,
  eta_at timestamptz,
  delivered_at timestamptz,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.supplier_contracts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id uuid REFERENCES public.vendors(id) ON DELETE SET NULL,
  contract_number text UNIQUE,
  title text NOT NULL,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','negotiation','active','expired','terminated')),
  start_date date,
  end_date date,
  value_amount numeric(18,2) DEFAULT 0,
  currency text NOT NULL DEFAULT 'NGN',
  payment_terms text,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Reports, activity, notifications, AI
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.procurement_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  report_type text NOT NULL DEFAULT 'spend'
    CHECK (report_type IN ('spend','vendor','inventory','fulfillment','custom')),
  period_label text,
  summary text,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.procurement_activity_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  action text NOT NULL,
  summary text NOT NULL,
  actor_label text,
  entity_type text,
  entity_id uuid,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_procurement_activity_logs_occurred
  ON public.procurement_activity_logs(occurred_at DESC);

CREATE TABLE IF NOT EXISTS public.procurement_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  body text,
  severity text NOT NULL DEFAULT 'info'
    CHECK (severity IN ('info','warning','critical')),
  is_read boolean NOT NULL DEFAULT false,
  entity_type text,
  entity_id uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.procurement_ai_insights (
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
-- Storage bucket: vendor-documents
-- ---------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  (
    'vendor-documents',
    'vendor-documents',
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

DROP POLICY IF EXISTS storage_vendor_documents_staff ON storage.objects;
CREATE POLICY storage_vendor_documents_staff ON storage.objects
  FOR ALL TO authenticated
  USING (
    bucket_id = 'vendor-documents'
    AND (
      public.has_permission('procurement.vendors', auth.uid())
      OR public.has_permission('procurement.read', auth.uid())
      OR public.has_role('super_admin', auth.uid())
    )
  )
  WITH CHECK (
    bucket_id = 'vendor-documents'
    AND (
      public.has_permission('procurement.vendors', auth.uid())
      OR public.has_permission('procurement.write', auth.uid())
      OR public.has_role('super_admin', auth.uid())
    )
  );

-- ---------------------------------------------------------------------------
-- Seed data (hex-only UUIDs b130…)
-- ---------------------------------------------------------------------------
INSERT INTO public.vendor_categories (id, slug, name, description, sort_order) VALUES
  ('b1300002-0000-4000-8000-000000000001', 'building-materials', 'Building Materials', 'Cement, steel, aggregates', 10),
  ('b1300002-0000-4000-8000-000000000002', 'mep-supplies', 'MEP Supplies', 'Electrical, plumbing, HVAC', 20),
  ('b1300002-0000-4000-8000-000000000003', 'finishing', 'Finishing & Fixtures', 'Tiles, fittings, paint', 30)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.vendors (
  id, code, name, category_id, status, tier, contact_email, contact_phone,
  city, country, payment_terms, lead_time_days, rating_avg, notes
) VALUES
  (
    'b1300001-0000-4000-8000-000000000001', 'VEN-001', 'Apex Cement Ltd',
    'b1300002-0000-4000-8000-000000000001', 'preferred', 'strategic',
    'orders@apexcavement.ng', '+2348010000001', 'Lagos', 'NG', 'Net 30', 5, 4.60,
    'Primary cement and aggregate supplier'
  ),
  (
    'b1300001-0000-4000-8000-000000000002', 'VEN-002', 'Voltline Electricals',
    'b1300002-0000-4000-8000-000000000002', 'active', 'preferred',
    'sales@voltline.ng', '+2348010000002', 'Abuja', 'NG', 'Net 21', 7, 4.20,
    'Switchgear and cabling'
  ),
  (
    'b1300001-0000-4000-8000-000000000003', 'VEN-003', 'TileCraft Nigeria',
    'b1300002-0000-4000-8000-000000000003', 'active', 'standard',
    'hello@tilecraft.ng', '+2348010000003', 'Lagos', 'NG', 'Net 14', 10, 3.90,
    'Porcelain and ceramic tiles'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.vendor_contacts (id, vendor_id, full_name, role_title, email, phone, is_primary) VALUES
  ('b1300003-0000-4000-8000-000000000001', 'b1300001-0000-4000-8000-000000000001',
   'Chidi Okonkwo', 'Account Manager', 'chidi@apexcavement.ng', '+2348010000011', true),
  ('b1300003-0000-4000-8000-000000000002', 'b1300001-0000-4000-8000-000000000002',
   'Amina Bello', 'Sales Lead', 'amina@voltline.ng', '+2348010000012', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.vendor_ratings (id, vendor_id, score, category, notes, rated_by) VALUES
  ('b1300005-0000-4000-8000-000000000001', 'b1300001-0000-4000-8000-000000000001',
   4.60, 'overall', 'Reliable on-time deliveries', 'Procurement'),
  ('b1300005-0000-4000-8000-000000000002', 'b1300001-0000-4000-8000-000000000002',
   4.20, 'delivery', 'Occasional lead-time slip', 'Site Office')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.warehouses (id, code, name, location_label, status, is_default) VALUES
  ('b1300014-0000-4000-8000-000000000001', 'WH-LG-01', 'Lagos Central Yard',
   'Ikeja Industrial Estate', 'active', true),
  ('b1300014-0000-4000-8000-000000000002', 'WH-AB-01', 'Abuja Site Store',
   'Gwarinpa Site Camp', 'active', false)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.warehouse_locations (id, warehouse_id, code, name, zone, aisle, bin) VALUES
  ('b1300015-0000-4000-8000-000000000001', 'b1300014-0000-4000-8000-000000000001',
   'A-01-01', 'Cement Bay A', 'A', '01', '01'),
  ('b1300015-0000-4000-8000-000000000002', 'b1300014-0000-4000-8000-000000000001',
   'B-02-03', 'Electrical Rack B', 'B', '02', '03'),
  ('b1300015-0000-4000-8000-000000000003', 'b1300014-0000-4000-8000-000000000002',
   'S-01-01', 'Site Staging', 'S', '01', '01')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.inventory_items (
  id, sku, name, category, uom, reorder_point, reorder_qty, on_hand,
  reserved_qty, unit_cost, status, warehouse_id
) VALUES
  (
    'b1300016-0000-4000-8000-000000000001', 'CEM-42.5-50', 'Portland Cement 42.5 (50kg)',
    'building-materials', 'bag', 200, 500, 85, 20, 6500, 'low_stock',
    'b1300014-0000-4000-8000-000000000001'
  ),
  (
    'b1300016-0000-4000-8000-000000000002', 'CAB-16MM-CU', '16mm Copper Cable',
    'mep-supplies', 'm', 500, 1000, 1200, 100, 1850, 'active',
    'b1300014-0000-4000-8000-000000000001'
  ),
  (
    'b1300016-0000-4000-8000-000000000003', 'TILE-60X60-W', '60x60 Porcelain Tile White',
    'finishing', 'box', 40, 80, 55, 0, 28000, 'active',
    'b1300014-0000-4000-8000-000000000002'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.inventory_batches (id, inventory_item_id, batch_code, quantity, warehouse_location_id) VALUES
  ('b1300017-0000-4000-8000-000000000001', 'b1300016-0000-4000-8000-000000000001',
   'BATCH-CEM-0726', 85, 'b1300015-0000-4000-8000-000000000001'),
  ('b1300017-0000-4000-8000-000000000002', 'b1300016-0000-4000-8000-000000000002',
   'BATCH-CAB-0726', 1200, 'b1300015-0000-4000-8000-000000000002')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.procurement_plans (id, code, title, period_label, status, budget_amount, summary) VALUES
  (
    'b1300006-0000-4000-8000-000000000001', 'PLAN-2026-Q3', 'Q3 Construction Materials Plan',
    'Q3 2026', 'active', 85000000,
    'Cement, steel, MEP for Oceanview Phase 2'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.purchase_requisitions (
  id, plan_id, code, title, status, requester_label, department, priority,
  needed_by, estimated_total, notes
) VALUES
  (
    'b1300007-0000-4000-8000-000000000001',
    'b1300006-0000-4000-8000-000000000001',
    'PR-2026-1301', 'Cement restock — Oceanview Phase 2',
    'approved', 'Site Office', 'Construction', 'high',
    CURRENT_DATE + 14, 3250000, 'Low stock trigger — replenish before pour week'
  ),
  (
    'b1300007-0000-4000-8000-000000000002',
    'b1300006-0000-4000-8000-000000000001',
    'PR-2026-1302', 'MEP cabling for Block C',
    'submitted', 'MEP Lead', 'Construction', 'normal',
    CURRENT_DATE + 21, 1850000, NULL
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.requisition_items (id, requisition_id, line_no, description, sku, quantity, uom, unit_estimate) VALUES
  ('b1300008-0000-4000-8000-000000000001', 'b1300007-0000-4000-8000-000000000001',
   1, 'Portland Cement 42.5 (50kg)', 'CEM-42.5-50', 500, 'bag', 6500),
  ('b1300008-0000-4000-8000-000000000002', 'b1300007-0000-4000-8000-000000000002',
   1, '16mm Copper Cable', 'CAB-16MM-CU', 1000, 'm', 1850)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.procurement_approvals (
  id, title, entity_type, entity_id, status, requester_label, approver_label, amount, decided_at
) VALUES
  (
    'b1300009-0000-4000-8000-000000000001',
    'Approve PR-2026-1301 Cement restock',
    'requisition', 'b1300007-0000-4000-8000-000000000001',
    'approved', 'Site Office', 'Construction Manager', 3250000, now() - interval '2 days'
  ),
  (
    'b1300009-0000-4000-8000-000000000002',
    'Approve PO-2026-1301 Apex Cement',
    'purchase_order', 'b1300010-0000-4000-8000-000000000001',
    'pending', 'Procurement', NULL, 3250000, NULL
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.rfqs (
  id, requisition_id, code, title, status, due_at, notes
) VALUES
  (
    'b130000a-0000-4000-8000-000000000001',
    'b1300007-0000-4000-8000-000000000001',
    'RFQ-2026-1301', 'RFQ — Cement restock Q3',
    'awarded', now() + interval '5 days', 'Awarded to Apex Cement'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.rfq_items (id, rfq_id, line_no, description, quantity, uom) VALUES
  ('b130000b-0000-4000-8000-000000000001', 'b130000a-0000-4000-8000-000000000001',
   1, 'Portland Cement 42.5 (50kg)', 500, 'bag')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.rfq_vendors (id, rfq_id, vendor_id, invite_status) VALUES
  ('b130000c-0000-4000-8000-000000000001', 'b130000a-0000-4000-8000-000000000001',
   'b1300001-0000-4000-8000-000000000001', 'awarded'),
  ('b130000c-0000-4000-8000-000000000002', 'b130000a-0000-4000-8000-000000000001',
   'b1300001-0000-4000-8000-000000000003', 'responded')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.supplier_quotes (
  id, rfq_id, vendor_id, quote_number, status, total_amount, lead_time_days, valid_until
) VALUES
  (
    'b130000d-0000-4000-8000-000000000001',
    'b130000a-0000-4000-8000-000000000001',
    'b1300001-0000-4000-8000-000000000001',
    'Q-APX-7721', 'awarded', 3250000, 5, CURRENT_DATE + 30
  ),
  (
    'b130000d-0000-4000-8000-000000000002',
    'b130000a-0000-4000-8000-000000000001',
    'b1300001-0000-4000-8000-000000000003',
    'Q-TC-3310', 'rejected', 3480000, 12, CURRENT_DATE + 14
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.quote_comparisons (id, rfq_id, title, winner_quote_id, summary) VALUES
  (
    'b130000e-0000-4000-8000-000000000001',
    'b130000a-0000-4000-8000-000000000001',
    'Cement RFQ comparison',
    'b130000d-0000-4000-8000-000000000001',
    'Apex won on price + lead time'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.purchase_orders (
  id, rfq_id, requisition_id, vendor_id, code, title, status,
  order_date, expected_date, subtotal, tax_amount, total_amount, shipping_address
) VALUES
  (
    'b1300010-0000-4000-8000-000000000001',
    'b130000a-0000-4000-8000-000000000001',
    'b1300007-0000-4000-8000-000000000001',
    'b1300001-0000-4000-8000-000000000001',
    'PO-2026-1301', 'PO — Apex Cement restock',
    'issued', CURRENT_DATE, CURRENT_DATE + 7,
    3250000, 0, 3250000, 'Lagos Central Yard — Ikeja'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.purchase_order_items (
  id, purchase_order_id, line_no, description, sku, quantity, uom, unit_price, line_total, received_qty
) VALUES
  (
    'b1300011-0000-4000-8000-000000000001',
    'b1300010-0000-4000-8000-000000000001',
    1, 'Portland Cement 42.5 (50kg)', 'CEM-42.5-50',
    500, 'bag', 6500, 3250000, 0
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.goods_receipts (
  id, purchase_order_id, code, title, status, received_by, warehouse_label, notes
) VALUES
  (
    'b1300012-0000-4000-8000-000000000001',
    'b1300010-0000-4000-8000-000000000001',
    'GRN-2026-1301', 'Partial receive — Apex cement (awaiting delivery)',
    'draft', 'Warehouse Lead', 'Lagos Central Yard',
    'Seeded draft GRN for inbound PO'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.goods_receipt_items (
  id, goods_receipt_id, purchase_order_item_id, description, quantity, uom, condition_note
) VALUES
  (
    'b1300013-0000-4000-8000-000000000001',
    'b1300012-0000-4000-8000-000000000001',
    'b1300011-0000-4000-8000-000000000001',
    'Portland Cement 42.5 (50kg)', 0, 'bag', 'Awaiting truck arrival'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.inventory_transactions (
  id, inventory_item_id, txn_type, quantity, reference_label, notes, actor_label, occurred_at
) VALUES
  (
    'b1300018-0000-4000-8000-000000000001',
    'b1300016-0000-4000-8000-000000000001',
    'issue', -40, 'SITE-ISSUE-0726', 'Issued to pour week staging', 'Warehouse',
    now() - interval '1 day'
  ),
  (
    'b1300018-0000-4000-8000-000000000002',
    'b1300016-0000-4000-8000-000000000002',
    'receipt', 200, 'PO-PRIOR', 'Prior MEP receipt', 'Warehouse',
    now() - interval '3 days'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.logistics_shipments (
  id, purchase_order_id, code, carrier, tracking_number, status,
  origin_label, destination_label, eta_at, notes
) VALUES
  (
    'b1300019-0000-4000-8000-000000000001',
    'b1300010-0000-4000-8000-000000000001',
    'SHIP-2026-1301', 'SwiftHaul Logistics', 'SH-778210',
    'in_transit', 'Apex Plant — Ewekoro', 'Lagos Central Yard',
    now() + interval '2 days', 'Cement bags — 500'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.supplier_contracts (
  id, vendor_id, contract_number, title, status, start_date, end_date, value_amount, payment_terms
) VALUES
  (
    'b130001a-0000-4000-8000-000000000001',
    'b1300001-0000-4000-8000-000000000001',
    'SC-2026-APX-01', 'Apex Cement Annual Supply Agreement',
    'active', CURRENT_DATE - 90, CURRENT_DATE + 275, 120000000, 'Net 30'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.procurement_ai_insights (
  id, title, body, insight_type, confidence_pct, editable, disclaimer
) VALUES
  (
    'b130001c-0000-4000-8000-000000000001',
    'Low-stock — cement replenishment critical',
    'Portland Cement on-hand is below reorder point. Expedite PO-2026-1301 delivery and consider buffer from secondary vendor.',
    'inventory_risk', 88, true, 'AI-generated — editable / advisory'
  ),
  (
    'b130001c-0000-4000-8000-000000000002',
    'Vendor scorecard — Apex preferred',
    'Apex Cement shows strongest delivery reliability on cement RFQs this quarter. Prefer for time-critical pours.',
    'supplier_intel', 81, true, 'AI-generated — editable / advisory'
  ),
  (
    'b130001c-0000-4000-8000-000000000003',
    'Spend concentration watch',
    'Single-vendor concentration on cement exceeds 70% of category spend. Diversify quotes for resilience.',
    'spend', 76, true, 'AI-generated — editable / advisory'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.procurement_activity_logs (id, action, summary, actor_label, entity_type, entity_id, occurred_at) VALUES
  ('b130001b-0000-4000-8000-000000000001', 'requisition_approved',
   'PR-2026-1301 Cement restock approved', 'Construction Manager',
   'requisition', 'b1300007-0000-4000-8000-000000000001', now() - interval '2 days'),
  ('b130001b-0000-4000-8000-000000000002', 'rfq_awarded',
   'RFQ-2026-1301 awarded to Apex Cement', 'Procurement',
   'rfq', 'b130000a-0000-4000-8000-000000000001', now() - interval '1 day'),
  ('b130001b-0000-4000-8000-000000000003', 'po_issued',
   'PO-2026-1301 issued to Apex Cement', 'Procurement',
   'purchase_order', 'b1300010-0000-4000-8000-000000000001', now() - interval '12 hours'),
  ('b130001b-0000-4000-8000-000000000004', 'shipment_in_transit',
   'SHIP-2026-1301 cement load in transit', 'SwiftHaul',
   'shipment', 'b1300019-0000-4000-8000-000000000001', now() - interval '4 hours')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.procurement_notifications (id, title, body, severity, entity_type, entity_id) VALUES
  (
    'b130001d-0000-4000-8000-000000000001',
    'Low stock alert — Cement',
    'CEM-42.5-50 below reorder point (85 vs 200)',
    'warning', 'inventory_item', 'b1300016-0000-4000-8000-000000000001'
  ),
  (
    'b130001d-0000-4000-8000-000000000002',
    'PO awaiting finance approval',
    'PO-2026-1301 pending procurement approval',
    'info', 'purchase_order', 'b1300010-0000-4000-8000-000000000001'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.procurement_reports (id, title, report_type, period_label, summary) VALUES
  (
    'b130001e-0000-4000-8000-000000000001',
    'Procurement Spend Weekly',
    'spend', 'W28 2026',
    'Open PO spend ₦3.25M; low-stock cement driving expedite flags.'
  ),
  (
    'b130001e-0000-4000-8000-000000000002',
    'Vendor Performance Snapshot',
    'vendor', 'Jul 2026',
    'Apex preferred; Voltline active; TileCraft standard tier.'
  )
ON CONFLICT (id) DO NOTHING;

-- Link CPMS project supplier seed if present (non-destructive)
UPDATE public.project_suppliers
SET enterprise_vendor_id = 'b1300001-0000-4000-8000-000000000001'
WHERE enterprise_vendor_id IS NULL
  AND name ILIKE '%apex%'
  AND EXISTS (SELECT 1 FROM public.vendors WHERE id = 'b1300001-0000-4000-8000-000000000001');

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.vendor_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendor_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendor_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendor_ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.procurement_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchase_requisitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.requisition_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.procurement_approvals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rfqs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rfq_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rfq_vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supplier_quotes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quote_comparisons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchase_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.goods_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.goods_receipt_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouse_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_adjustments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_transfers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.logistics_shipments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supplier_contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.procurement_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.procurement_activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.procurement_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.procurement_ai_insights ENABLE ROW LEVEL SECURITY;

-- Helper macro-style policies (slug FIRST)

DROP POLICY IF EXISTS vendor_categories_select ON public.vendor_categories;
DROP POLICY IF EXISTS vendor_categories_write ON public.vendor_categories;
CREATE POLICY vendor_categories_select ON public.vendor_categories FOR SELECT
  USING (public.has_permission('procurement.read', auth.uid()) OR public.has_permission('procurement.vendors', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY vendor_categories_write ON public.vendor_categories FOR ALL
  USING (public.has_permission('procurement.vendors', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('procurement.vendors', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS vendors_select ON public.vendors;
DROP POLICY IF EXISTS vendors_write ON public.vendors;
CREATE POLICY vendors_select ON public.vendors FOR SELECT
  USING (public.has_permission('procurement.read', auth.uid()) OR public.has_permission('procurement.vendors', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY vendors_write ON public.vendors FOR ALL
  USING (public.has_permission('procurement.vendors', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('procurement.vendors', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS vendor_contacts_select ON public.vendor_contacts;
DROP POLICY IF EXISTS vendor_contacts_write ON public.vendor_contacts;
CREATE POLICY vendor_contacts_select ON public.vendor_contacts FOR SELECT
  USING (public.has_permission('procurement.read', auth.uid()) OR public.has_permission('procurement.vendors', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY vendor_contacts_write ON public.vendor_contacts FOR ALL
  USING (public.has_permission('procurement.vendors', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('procurement.vendors', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS vendor_documents_select ON public.vendor_documents;
DROP POLICY IF EXISTS vendor_documents_write ON public.vendor_documents;
CREATE POLICY vendor_documents_select ON public.vendor_documents FOR SELECT
  USING (public.has_permission('procurement.read', auth.uid()) OR public.has_permission('procurement.vendors', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY vendor_documents_write ON public.vendor_documents FOR ALL
  USING (public.has_permission('procurement.vendors', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('procurement.vendors', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS vendor_ratings_select ON public.vendor_ratings;
DROP POLICY IF EXISTS vendor_ratings_write ON public.vendor_ratings;
CREATE POLICY vendor_ratings_select ON public.vendor_ratings FOR SELECT
  USING (public.has_permission('procurement.read', auth.uid()) OR public.has_permission('procurement.vendors', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY vendor_ratings_write ON public.vendor_ratings FOR ALL
  USING (public.has_permission('procurement.vendors', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('procurement.vendors', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS procurement_plans_select ON public.procurement_plans;
DROP POLICY IF EXISTS procurement_plans_write ON public.procurement_plans;
CREATE POLICY procurement_plans_select ON public.procurement_plans FOR SELECT
  USING (public.has_permission('procurement.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY procurement_plans_write ON public.procurement_plans FOR ALL
  USING (public.has_permission('procurement.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('procurement.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS purchase_requisitions_select ON public.purchase_requisitions;
DROP POLICY IF EXISTS purchase_requisitions_write ON public.purchase_requisitions;
CREATE POLICY purchase_requisitions_select ON public.purchase_requisitions FOR SELECT
  USING (public.has_permission('procurement.read', auth.uid()) OR public.has_permission('procurement.requisitions', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY purchase_requisitions_write ON public.purchase_requisitions FOR ALL
  USING (public.has_permission('procurement.requisitions', auth.uid()) OR public.has_permission('procurement.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('procurement.requisitions', auth.uid()) OR public.has_permission('procurement.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS requisition_items_select ON public.requisition_items;
DROP POLICY IF EXISTS requisition_items_write ON public.requisition_items;
CREATE POLICY requisition_items_select ON public.requisition_items FOR SELECT
  USING (public.has_permission('procurement.read', auth.uid()) OR public.has_permission('procurement.requisitions', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY requisition_items_write ON public.requisition_items FOR ALL
  USING (public.has_permission('procurement.requisitions', auth.uid()) OR public.has_permission('procurement.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('procurement.requisitions', auth.uid()) OR public.has_permission('procurement.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS procurement_approvals_select ON public.procurement_approvals;
DROP POLICY IF EXISTS procurement_approvals_write ON public.procurement_approvals;
CREATE POLICY procurement_approvals_select ON public.procurement_approvals FOR SELECT
  USING (public.has_permission('procurement.approvals', auth.uid()) OR public.has_permission('procurement.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY procurement_approvals_write ON public.procurement_approvals FOR ALL
  USING (public.has_permission('procurement.approvals', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('procurement.approvals', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS rfqs_select ON public.rfqs;
DROP POLICY IF EXISTS rfqs_write ON public.rfqs;
CREATE POLICY rfqs_select ON public.rfqs FOR SELECT
  USING (public.has_permission('procurement.read', auth.uid()) OR public.has_permission('procurement.rfq', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY rfqs_write ON public.rfqs FOR ALL
  USING (public.has_permission('procurement.rfq', auth.uid()) OR public.has_permission('procurement.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('procurement.rfq', auth.uid()) OR public.has_permission('procurement.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS rfq_items_select ON public.rfq_items;
DROP POLICY IF EXISTS rfq_items_write ON public.rfq_items;
CREATE POLICY rfq_items_select ON public.rfq_items FOR SELECT
  USING (public.has_permission('procurement.read', auth.uid()) OR public.has_permission('procurement.rfq', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY rfq_items_write ON public.rfq_items FOR ALL
  USING (public.has_permission('procurement.rfq', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('procurement.rfq', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS rfq_vendors_select ON public.rfq_vendors;
DROP POLICY IF EXISTS rfq_vendors_write ON public.rfq_vendors;
CREATE POLICY rfq_vendors_select ON public.rfq_vendors FOR SELECT
  USING (public.has_permission('procurement.read', auth.uid()) OR public.has_permission('procurement.rfq', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY rfq_vendors_write ON public.rfq_vendors FOR ALL
  USING (public.has_permission('procurement.rfq', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('procurement.rfq', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS supplier_quotes_select ON public.supplier_quotes;
DROP POLICY IF EXISTS supplier_quotes_write ON public.supplier_quotes;
CREATE POLICY supplier_quotes_select ON public.supplier_quotes FOR SELECT
  USING (public.has_permission('procurement.read', auth.uid()) OR public.has_permission('procurement.rfq', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY supplier_quotes_write ON public.supplier_quotes FOR ALL
  USING (public.has_permission('procurement.rfq', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('procurement.rfq', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS quote_comparisons_select ON public.quote_comparisons;
DROP POLICY IF EXISTS quote_comparisons_write ON public.quote_comparisons;
CREATE POLICY quote_comparisons_select ON public.quote_comparisons FOR SELECT
  USING (public.has_permission('procurement.read', auth.uid()) OR public.has_permission('procurement.rfq', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY quote_comparisons_write ON public.quote_comparisons FOR ALL
  USING (public.has_permission('procurement.rfq', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('procurement.rfq', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS purchase_orders_select ON public.purchase_orders;
DROP POLICY IF EXISTS purchase_orders_write ON public.purchase_orders;
CREATE POLICY purchase_orders_select ON public.purchase_orders FOR SELECT
  USING (public.has_permission('procurement.read', auth.uid()) OR public.has_permission('procurement.orders', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY purchase_orders_write ON public.purchase_orders FOR ALL
  USING (public.has_permission('procurement.orders', auth.uid()) OR public.has_permission('procurement.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('procurement.orders', auth.uid()) OR public.has_permission('procurement.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS purchase_order_items_select ON public.purchase_order_items;
DROP POLICY IF EXISTS purchase_order_items_write ON public.purchase_order_items;
CREATE POLICY purchase_order_items_select ON public.purchase_order_items FOR SELECT
  USING (public.has_permission('procurement.read', auth.uid()) OR public.has_permission('procurement.orders', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY purchase_order_items_write ON public.purchase_order_items FOR ALL
  USING (public.has_permission('procurement.orders', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('procurement.orders', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS goods_receipts_select ON public.goods_receipts;
DROP POLICY IF EXISTS goods_receipts_write ON public.goods_receipts;
CREATE POLICY goods_receipts_select ON public.goods_receipts FOR SELECT
  USING (public.has_permission('procurement.read', auth.uid()) OR public.has_permission('procurement.receiving', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY goods_receipts_write ON public.goods_receipts FOR ALL
  USING (public.has_permission('procurement.receiving', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('procurement.receiving', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS goods_receipt_items_select ON public.goods_receipt_items;
DROP POLICY IF EXISTS goods_receipt_items_write ON public.goods_receipt_items;
CREATE POLICY goods_receipt_items_select ON public.goods_receipt_items FOR SELECT
  USING (public.has_permission('procurement.read', auth.uid()) OR public.has_permission('procurement.receiving', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY goods_receipt_items_write ON public.goods_receipt_items FOR ALL
  USING (public.has_permission('procurement.receiving', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('procurement.receiving', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS warehouses_select ON public.warehouses;
DROP POLICY IF EXISTS warehouses_write ON public.warehouses;
CREATE POLICY warehouses_select ON public.warehouses FOR SELECT
  USING (public.has_permission('procurement.read', auth.uid()) OR public.has_permission('procurement.warehouse', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY warehouses_write ON public.warehouses FOR ALL
  USING (public.has_permission('procurement.warehouse', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('procurement.warehouse', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS warehouse_locations_select ON public.warehouse_locations;
DROP POLICY IF EXISTS warehouse_locations_write ON public.warehouse_locations;
CREATE POLICY warehouse_locations_select ON public.warehouse_locations FOR SELECT
  USING (public.has_permission('procurement.read', auth.uid()) OR public.has_permission('procurement.warehouse', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY warehouse_locations_write ON public.warehouse_locations FOR ALL
  USING (public.has_permission('procurement.warehouse', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('procurement.warehouse', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS inventory_items_select ON public.inventory_items;
DROP POLICY IF EXISTS inventory_items_write ON public.inventory_items;
CREATE POLICY inventory_items_select ON public.inventory_items FOR SELECT
  USING (public.has_permission('procurement.read', auth.uid()) OR public.has_permission('procurement.inventory', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY inventory_items_write ON public.inventory_items FOR ALL
  USING (public.has_permission('procurement.inventory', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('procurement.inventory', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS inventory_batches_select ON public.inventory_batches;
DROP POLICY IF EXISTS inventory_batches_write ON public.inventory_batches;
CREATE POLICY inventory_batches_select ON public.inventory_batches FOR SELECT
  USING (public.has_permission('procurement.read', auth.uid()) OR public.has_permission('procurement.inventory', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY inventory_batches_write ON public.inventory_batches FOR ALL
  USING (public.has_permission('procurement.inventory', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('procurement.inventory', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS inventory_transactions_select ON public.inventory_transactions;
DROP POLICY IF EXISTS inventory_transactions_write ON public.inventory_transactions;
CREATE POLICY inventory_transactions_select ON public.inventory_transactions FOR SELECT
  USING (public.has_permission('procurement.read', auth.uid()) OR public.has_permission('procurement.inventory', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY inventory_transactions_write ON public.inventory_transactions FOR ALL
  USING (public.has_permission('procurement.inventory', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('procurement.inventory', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS inventory_adjustments_select ON public.inventory_adjustments;
DROP POLICY IF EXISTS inventory_adjustments_write ON public.inventory_adjustments;
CREATE POLICY inventory_adjustments_select ON public.inventory_adjustments FOR SELECT
  USING (public.has_permission('procurement.read', auth.uid()) OR public.has_permission('procurement.inventory', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY inventory_adjustments_write ON public.inventory_adjustments FOR ALL
  USING (public.has_permission('procurement.inventory', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('procurement.inventory', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS stock_transfers_select ON public.stock_transfers;
DROP POLICY IF EXISTS stock_transfers_write ON public.stock_transfers;
CREATE POLICY stock_transfers_select ON public.stock_transfers FOR SELECT
  USING (public.has_permission('procurement.read', auth.uid()) OR public.has_permission('procurement.warehouse', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY stock_transfers_write ON public.stock_transfers FOR ALL
  USING (public.has_permission('procurement.warehouse', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('procurement.warehouse', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS logistics_shipments_select ON public.logistics_shipments;
DROP POLICY IF EXISTS logistics_shipments_write ON public.logistics_shipments;
CREATE POLICY logistics_shipments_select ON public.logistics_shipments FOR SELECT
  USING (public.has_permission('procurement.read', auth.uid()) OR public.has_permission('procurement.logistics', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY logistics_shipments_write ON public.logistics_shipments FOR ALL
  USING (public.has_permission('procurement.logistics', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('procurement.logistics', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS supplier_contracts_select ON public.supplier_contracts;
DROP POLICY IF EXISTS supplier_contracts_write ON public.supplier_contracts;
CREATE POLICY supplier_contracts_select ON public.supplier_contracts FOR SELECT
  USING (public.has_permission('procurement.read', auth.uid()) OR public.has_permission('procurement.vendors', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY supplier_contracts_write ON public.supplier_contracts FOR ALL
  USING (public.has_permission('procurement.vendors', auth.uid()) OR public.has_permission('procurement.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('procurement.vendors', auth.uid()) OR public.has_permission('procurement.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS procurement_reports_select ON public.procurement_reports;
DROP POLICY IF EXISTS procurement_reports_write ON public.procurement_reports;
CREATE POLICY procurement_reports_select ON public.procurement_reports FOR SELECT
  USING (public.has_permission('procurement.reports', auth.uid()) OR public.has_permission('procurement.analytics', auth.uid()) OR public.has_permission('procurement.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY procurement_reports_write ON public.procurement_reports FOR ALL
  USING (public.has_permission('procurement.reports', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('procurement.reports', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS procurement_activity_logs_select ON public.procurement_activity_logs;
DROP POLICY IF EXISTS procurement_activity_logs_write ON public.procurement_activity_logs;
CREATE POLICY procurement_activity_logs_select ON public.procurement_activity_logs FOR SELECT
  USING (public.has_permission('procurement.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY procurement_activity_logs_write ON public.procurement_activity_logs FOR ALL
  USING (public.has_permission('procurement.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('procurement.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS procurement_notifications_select ON public.procurement_notifications;
DROP POLICY IF EXISTS procurement_notifications_write ON public.procurement_notifications;
CREATE POLICY procurement_notifications_select ON public.procurement_notifications FOR SELECT
  USING (public.has_permission('procurement.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY procurement_notifications_write ON public.procurement_notifications FOR ALL
  USING (public.has_permission('procurement.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('procurement.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS procurement_ai_insights_select ON public.procurement_ai_insights;
DROP POLICY IF EXISTS procurement_ai_insights_write ON public.procurement_ai_insights;
CREATE POLICY procurement_ai_insights_select ON public.procurement_ai_insights FOR SELECT
  USING (public.has_permission('procurement.ai', auth.uid()) OR public.has_permission('procurement.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY procurement_ai_insights_write ON public.procurement_ai_insights FOR ALL
  USING (public.has_permission('procurement.ai', auth.uid()) OR public.has_permission('procurement.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('procurement.ai', auth.uid()) OR public.has_permission('procurement.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE ON
  public.vendor_categories,
  public.vendors,
  public.vendor_contacts,
  public.vendor_documents,
  public.vendor_ratings,
  public.procurement_plans,
  public.purchase_requisitions,
  public.requisition_items,
  public.procurement_approvals,
  public.rfqs,
  public.rfq_items,
  public.rfq_vendors,
  public.supplier_quotes,
  public.quote_comparisons,
  public.purchase_orders,
  public.purchase_order_items,
  public.goods_receipts,
  public.goods_receipt_items,
  public.warehouses,
  public.warehouse_locations,
  public.inventory_items,
  public.inventory_batches,
  public.inventory_transactions,
  public.inventory_adjustments,
  public.stock_transfers,
  public.logistics_shipments,
  public.supplier_contracts,
  public.procurement_reports,
  public.procurement_activity_logs,
  public.procurement_notifications,
  public.procurement_ai_insights
TO authenticated;

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'purchase_requisitions',
    'purchase_orders',
    'goods_receipts',
    'inventory_transactions',
    'procurement_approvals',
    'procurement_activity_logs',
    'procurement_notifications'
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
