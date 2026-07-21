-- Volume 4 Part 5 — Enterprise Sales & Booking Management System (SBMS)
-- Status: APPLIED remotely 2026-07-14 (chunked p1–p3).
-- Reuses foundational payments / commissions (domain_operations); creates sales_* domain tables.
-- Note: sales_commissions is the SBMS commission ledger; legacy public.commissions is left unchanged.

BEGIN;

-- ---------------------------------------------------------------------------
-- Permissions (NO action column — slug, name, description, module only)
-- ---------------------------------------------------------------------------
INSERT INTO public.permissions (slug, name, description, module) VALUES
  ('sales.read', 'View Sales', 'View Sales Command Center and sales records', 'sales'),
  ('sales.write', 'Manage Sales', 'Create and edit sales orders, deals, and pipeline', 'sales'),
  ('sales.reservations', 'Manage Reservations', 'Create and manage property reservations', 'sales'),
  ('sales.bookings', 'Manage Bookings', 'Schedule inspections, site visits, and consultations', 'sales'),
  ('sales.quotes', 'Manage Quotes', 'Create and send sales quotations', 'sales'),
  ('sales.contracts', 'Manage Contracts', 'Prepare and track sales contracts', 'sales'),
  ('sales.commissions', 'Manage Commissions', 'View and process sales commission entries', 'sales'),
  ('sales.approvals', 'Sales Approvals', 'Approve discounts, overrides, and deal exceptions', 'sales'),
  ('sales.analytics', 'Sales Analytics', 'View pipeline value, forecasts, and leaderboards', 'sales'),
  ('sales.ai', 'AI Sales Assistant', 'Use AI deal intelligence and sales summaries', 'sales')
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  module = EXCLUDED.module,
  updated_at = now();

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE p.slug LIKE 'sales.%'
  AND (
    r.slug IN ('super_admin', 'admin')
    OR (r.slug = 'sales_team' AND p.slug IN (
      'sales.read','sales.write','sales.reservations','sales.bookings',
      'sales.quotes','sales.contracts','sales.commissions','sales.approvals',
      'sales.analytics','sales.ai'
    ))
    OR (r.slug = 'finance' AND p.slug IN (
      'sales.read','sales.commissions','sales.analytics','sales.approvals'
    ))
    OR (r.slug = 'marketing' AND p.slug IN (
      'sales.read','sales.analytics','sales.ai'
    ))
  )
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Optional enrichment of legacy payments (nullable SBMS link)
-- ---------------------------------------------------------------------------
ALTER TABLE public.payments
  ADD COLUMN IF NOT EXISTS sales_order_id uuid,
  ADD COLUMN IF NOT EXISTS sales_installment_id uuid,
  ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}'::jsonb;

-- ---------------------------------------------------------------------------
-- Pipeline catalog + history
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sales_pipeline_stages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  sort_order int NOT NULL DEFAULT 0,
  is_terminal boolean NOT NULL DEFAULT false,
  color text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.sales_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_code text NOT NULL UNIQUE,
  title text NOT NULL,
  client_id uuid REFERENCES public.crm_clients(id) ON DELETE SET NULL,
  property_id uuid REFERENCES public.properties(id) ON DELETE SET NULL,
  stage_id uuid REFERENCES public.sales_pipeline_stages(id) ON DELETE SET NULL,
  stage_slug text,
  deal_value numeric(16,2) NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'NGN',
  probability_pct numeric(5,2) DEFAULT 50,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','negotiation','contract','won','lost','cancelled','on_hold')),
  expected_close_at date,
  assigned_staff_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  ai_summary text,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sales_orders_stage ON public.sales_orders (stage_slug);
CREATE INDEX IF NOT EXISTS idx_sales_orders_client ON public.sales_orders (client_id);
CREATE INDEX IF NOT EXISTS idx_sales_orders_property ON public.sales_orders (property_id);

CREATE TABLE IF NOT EXISTS public.sales_pipeline_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES public.sales_orders(id) ON DELETE CASCADE,
  from_stage_slug text,
  to_stage_slug text NOT NULL,
  changed_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  note text,
  changed_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_sales_pipeline_history_order
  ON public.sales_pipeline_history (order_id, changed_at DESC);

-- ---------------------------------------------------------------------------
-- Reservations & bookings
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sales_reservations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_code text NOT NULL UNIQUE,
  client_id uuid REFERENCES public.crm_clients(id) ON DELETE SET NULL,
  property_id uuid REFERENCES public.properties(id) ON DELETE SET NULL,
  order_id uuid REFERENCES public.sales_orders(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','reserved','confirmed','expired','cancelled','converted')),
  reserved_amount numeric(16,2) NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'NGN',
  reserved_at timestamptz,
  expires_at timestamptz,
  confirmed_at timestamptz,
  converted_at timestamptz,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sales_reservations_status
  ON public.sales_reservations (status);
CREATE INDEX IF NOT EXISTS idx_sales_reservations_expires
  ON public.sales_reservations (expires_at);

CREATE TABLE IF NOT EXISTS public.sales_bookings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_code text NOT NULL UNIQUE,
  client_id uuid REFERENCES public.crm_clients(id) ON DELETE SET NULL,
  property_id uuid REFERENCES public.properties(id) ON DELETE SET NULL,
  order_id uuid REFERENCES public.sales_orders(id) ON DELETE SET NULL,
  booking_type text NOT NULL DEFAULT 'inspection'
    CHECK (booking_type IN (
      'inspection','office','virtual_tour','site_visit','investment_consultation'
    )),
  status text NOT NULL DEFAULT 'scheduled'
    CHECK (status IN ('scheduled','confirmed','completed','cancelled','no_show')),
  scheduled_at timestamptz NOT NULL,
  duration_minutes int NOT NULL DEFAULT 60,
  location text,
  assigned_staff_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sales_bookings_scheduled
  ON public.sales_bookings (scheduled_at);

-- ---------------------------------------------------------------------------
-- Quotes, negotiations, contracts
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sales_quotes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quote_code text NOT NULL UNIQUE,
  client_id uuid REFERENCES public.crm_clients(id) ON DELETE SET NULL,
  property_id uuid REFERENCES public.properties(id) ON DELETE SET NULL,
  order_id uuid REFERENCES public.sales_orders(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','sent','accepted','rejected','expired','superseded')),
  subtotal numeric(16,2) NOT NULL DEFAULT 0,
  discount_amount numeric(16,2) NOT NULL DEFAULT 0,
  total_amount numeric(16,2) NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'NGN',
  valid_until date,
  sent_at timestamptz,
  accepted_at timestamptz,
  notes text,
  estimate_disclaimer text NOT NULL DEFAULT
    'Quoted totals are estimates subject to survey, title, and management approval. Not a binding offer until contract execution.',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.sales_quote_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quote_id uuid NOT NULL REFERENCES public.sales_quotes(id) ON DELETE CASCADE,
  label text NOT NULL,
  description text,
  quantity numeric(12,2) NOT NULL DEFAULT 1,
  unit_price numeric(16,2) NOT NULL DEFAULT 0,
  line_total numeric(16,2) NOT NULL DEFAULT 0,
  sort_order int NOT NULL DEFAULT 0,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.sales_negotiations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES public.sales_orders(id) ON DELETE CASCADE,
  quote_id uuid REFERENCES public.sales_quotes(id) ON DELETE SET NULL,
  event_type text NOT NULL DEFAULT 'offer'
    CHECK (event_type IN ('offer','counter','concession','note','status_change')),
  actor_label text,
  amount numeric(16,2),
  currency text NOT NULL DEFAULT 'NGN',
  body text,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_sales_negotiations_order
  ON public.sales_negotiations (order_id, occurred_at DESC);

CREATE TABLE IF NOT EXISTS public.sales_contracts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contract_code text NOT NULL UNIQUE,
  order_id uuid REFERENCES public.sales_orders(id) ON DELETE SET NULL,
  client_id uuid REFERENCES public.crm_clients(id) ON DELETE SET NULL,
  property_id uuid REFERENCES public.properties(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN (
      'draft','pending_review','awaiting_signature','partially_signed',
      'executed','cancelled','expired'
    )),
  contract_value numeric(16,2) NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'NGN',
  issued_at timestamptz,
  signed_at timestamptz,
  expires_at timestamptz,
  document_url text,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Payment plans, installments, commissions
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sales_payment_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_code text NOT NULL UNIQUE,
  order_id uuid REFERENCES public.sales_orders(id) ON DELETE SET NULL,
  client_id uuid REFERENCES public.crm_clients(id) ON DELETE SET NULL,
  property_id uuid REFERENCES public.properties(id) ON DELETE SET NULL,
  total_amount numeric(16,2) NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'NGN',
  deposit_amount numeric(16,2) NOT NULL DEFAULT 0,
  installment_count int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft','active','completed','cancelled','defaulted')),
  start_date date,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.sales_installments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_plan_id uuid NOT NULL REFERENCES public.sales_payment_plans(id) ON DELETE CASCADE,
  installment_no int NOT NULL,
  amount numeric(16,2) NOT NULL,
  currency text NOT NULL DEFAULT 'NGN',
  due_date date NOT NULL,
  paid_at timestamptz,
  payment_id uuid REFERENCES public.payments(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','due','paid','overdue','waived','cancelled')),
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (payment_plan_id, installment_no)
);

CREATE INDEX IF NOT EXISTS idx_sales_installments_due
  ON public.sales_installments (due_date, status);

-- SBMS commission ledger (distinct from legacy public.commissions)
CREATE TABLE IF NOT EXISTS public.sales_commissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  commission_code text NOT NULL UNIQUE,
  order_id uuid REFERENCES public.sales_orders(id) ON DELETE SET NULL,
  sales_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  agent_name text,
  base_amount numeric(16,2) NOT NULL DEFAULT 0,
  commission_percent numeric(8,4) NOT NULL DEFAULT 0,
  commission_amount numeric(16,2) NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'NGN',
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('earned','pending','approved','paid','cancelled')),
  earned_at timestamptz,
  approved_at timestamptz,
  paid_at timestamptz,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sales_commissions_status
  ON public.sales_commissions (status);

-- ---------------------------------------------------------------------------
-- Handovers, documents, discounts
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sales_handovers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES public.sales_orders(id) ON DELETE SET NULL,
  client_id uuid REFERENCES public.crm_clients(id) ON DELETE SET NULL,
  property_id uuid REFERENCES public.properties(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','in_progress','ready','completed','blocked')),
  checklist jsonb NOT NULL DEFAULT '[]'::jsonb,
  scheduled_at timestamptz,
  completed_at timestamptz,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.sales_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES public.sales_orders(id) ON DELETE SET NULL,
  client_id uuid REFERENCES public.crm_clients(id) ON DELETE SET NULL,
  doc_type text NOT NULL DEFAULT 'other',
  title text NOT NULL,
  file_url text,
  status text NOT NULL DEFAULT 'active',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.sales_discounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  discount_type text NOT NULL DEFAULT 'percent'
    CHECK (discount_type IN ('percent','fixed')),
  value numeric(16,4) NOT NULL DEFAULT 0,
  max_amount numeric(16,2),
  is_active boolean NOT NULL DEFAULT true,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.sales_discount_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES public.sales_orders(id) ON DELETE SET NULL,
  discount_id uuid REFERENCES public.sales_discounts(id) ON DELETE SET NULL,
  requested_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  requester_label text,
  requested_value numeric(16,4) NOT NULL,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','approved','rejected','withdrawn','expired')),
  justification text,
  reviewed_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  review_note text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Targets, forecasts, reports, activity, notifications, leaderboard
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sales_targets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period_label text NOT NULL,
  period_start date NOT NULL,
  period_end date NOT NULL,
  target_amount numeric(16,2) NOT NULL DEFAULT 0,
  achieved_amount numeric(16,2) NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'NGN',
  owner_label text,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.sales_forecasts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period_label text NOT NULL,
  forecast_amount numeric(16,2) NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'NGN',
  confidence_pct numeric(5,2),
  disclaimer text NOT NULL DEFAULT
    'Sales forecasts are estimates only and are not guarantees of future revenue.',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.sales_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  report_code text NOT NULL UNIQUE,
  title text NOT NULL,
  report_type text NOT NULL DEFAULT 'pipeline',
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  generated_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS public.sales_activity_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES public.sales_orders(id) ON DELETE SET NULL,
  client_id uuid REFERENCES public.crm_clients(id) ON DELETE SET NULL,
  event_type text NOT NULL DEFAULT 'note',
  title text NOT NULL,
  description text,
  actor_label text,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_sales_activity_logs_occurred
  ON public.sales_activity_logs (occurred_at DESC);

CREATE TABLE IF NOT EXISTS public.sales_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  body text,
  severity text NOT NULL DEFAULT 'info'
    CHECK (severity IN ('info','low','medium','high','critical')),
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','acknowledged','resolved','dismissed')),
  order_id uuid REFERENCES public.sales_orders(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS public.sales_leaderboards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period_label text NOT NULL,
  agent_name text NOT NULL,
  rank int NOT NULL,
  deals_won int NOT NULL DEFAULT 0,
  revenue numeric(16,2) NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'NGN',
  snapshot_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

-- Link payments enrichment FKs once sales tables exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'payments_sales_order_id_fkey'
  ) THEN
    ALTER TABLE public.payments
      ADD CONSTRAINT payments_sales_order_id_fkey
      FOREIGN KEY (sales_order_id) REFERENCES public.sales_orders(id) ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'payments_sales_installment_id_fkey'
  ) THEN
    ALTER TABLE public.payments
      ADD CONSTRAINT payments_sales_installment_id_fkey
      FOREIGN KEY (sales_installment_id) REFERENCES public.sales_installments(id) ON DELETE SET NULL;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Seeds: pipeline stages
-- ---------------------------------------------------------------------------
INSERT INTO public.sales_pipeline_stages (id, slug, name, sort_order, is_terminal, color) VALUES
  ('b1000000-0000-4000-8000-000000000001', 'enquiry', 'Enquiry', 10, false, '#94A3B8'),
  ('b1000000-0000-4000-8000-000000000002', 'qualification', 'Qualification', 20, false, '#60A5FA'),
  ('b1000000-0000-4000-8000-000000000003', 'viewing', 'Viewing', 30, false, '#34D399'),
  ('b1000000-0000-4000-8000-000000000004', 'negotiation', 'Negotiation', 40, false, '#FBBF24'),
  ('b1000000-0000-4000-8000-000000000005', 'contract', 'Contract', 50, false, '#F59E0B'),
  ('b1000000-0000-4000-8000-000000000006', 'closed_won', 'Closed Won', 60, true, '#22C55E'),
  ('b1000000-0000-4000-8000-000000000007', 'closed_lost', 'Closed Lost', 70, true, '#EF4444')
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  sort_order = EXCLUDED.sort_order,
  is_terminal = EXCLUDED.is_terminal,
  color = EXCLUDED.color,
  updated_at = now();

INSERT INTO public.sales_discounts (id, slug, name, discount_type, value, max_amount) VALUES
  ('b1100000-0000-4000-8000-000000000001', 'early_bird_5', 'Early Bird 5%', 'percent', 5, 5000000),
  ('b1100000-0000-4000-8000-000000000002', 'vip_flat_2m', 'VIP Flat ₦2M', 'fixed', 2000000, 2000000)
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  value = EXCLUDED.value,
  max_amount = EXCLUDED.max_amount;

-- ---------------------------------------------------------------------------
-- Seeds: deals / orders (linked to CRM clients + Victoria Crest when present)
-- ---------------------------------------------------------------------------
INSERT INTO public.sales_orders (
  id, order_code, title, client_id, property_id, stage_id, stage_slug,
  deal_value, probability_pct, status, expected_close_at, ai_summary, notes, metadata
)
SELECT
  'b2000000-0000-4000-8000-000000000001',
  'SO-VC-NEG-001',
  'Adaeze Nwosu — Victoria Crest Unit 4',
  c.id,
  p.id,
  'b1000000-0000-4000-8000-000000000004',
  'negotiation',
  125000000,
  65,
  'negotiation',
  (CURRENT_DATE + 21),
  'Hot VIP duplex negotiation. Counter offer expected after reservation deposit.',
  'Demo deal mid-negotiation',
  '{"demo":true}'::jsonb
FROM (SELECT id FROM public.crm_clients WHERE id = 'a1000000-0000-4000-8000-000000000001' LIMIT 1) c
FULL OUTER JOIN (SELECT id FROM public.properties WHERE slug = 'victoria-crest-unit-4' LIMIT 1) p ON true
ON CONFLICT (order_code) DO UPDATE SET
  title = EXCLUDED.title,
  stage_slug = EXCLUDED.stage_slug,
  deal_value = EXCLUDED.deal_value,
  status = EXCLUDED.status,
  ai_summary = EXCLUDED.ai_summary,
  updated_at = now();

INSERT INTO public.sales_orders (
  id, order_code, title, client_id, property_id, stage_id, stage_slug,
  deal_value, probability_pct, status, expected_close_at, ai_summary, notes, metadata
)
SELECT
  'b2000000-0000-4000-8000-000000000002',
  'SO-VC-CTR-002',
  'Chuka Okonkwo — Lekki 3-bed payment plan',
  c.id,
  p.id,
  'b1000000-0000-4000-8000-000000000005',
  'contract',
  85000000,
  85,
  'contract',
  (CURRENT_DATE + 10),
  'Near contract. Payment plan + installments drafted. Awaiting signature pack.',
  'Demo deal near contract',
  '{"demo":true}'::jsonb
FROM (SELECT id FROM public.crm_clients WHERE id = 'a1000000-0000-4000-8000-000000000002' LIMIT 1) c
FULL OUTER JOIN (SELECT id FROM public.properties WHERE slug = 'victoria-crest-unit-4' LIMIT 1) p ON true
ON CONFLICT (order_code) DO UPDATE SET
  title = EXCLUDED.title,
  stage_slug = EXCLUDED.stage_slug,
  deal_value = EXCLUDED.deal_value,
  status = EXCLUDED.status,
  ai_summary = EXCLUDED.ai_summary,
  updated_at = now();

-- Ensure fixed IDs exist even if CRM/property links missing
INSERT INTO public.sales_orders (
  id, order_code, title, stage_id, stage_slug, deal_value, probability_pct, status, expected_close_at, ai_summary, metadata
) VALUES
  (
    'b2000000-0000-4000-8000-000000000001',
    'SO-VC-NEG-001',
    'Adaeze Nwosu — Victoria Crest Unit 4',
    'b1000000-0000-4000-8000-000000000004',
    'negotiation',
    125000000, 65, 'negotiation', (CURRENT_DATE + 21),
    'Hot VIP duplex negotiation. Counter offer expected after reservation deposit.',
    '{"demo":true}'::jsonb
  ),
  (
    'b2000000-0000-4000-8000-000000000002',
    'SO-VC-CTR-002',
    'Chuka Okonkwo — Lekki 3-bed payment plan',
    'b1000000-0000-4000-8000-000000000005',
    'contract',
    85000000, 85, 'contract', (CURRENT_DATE + 10),
    'Near contract. Payment plan + installments drafted. Awaiting signature pack.',
    '{"demo":true}'::jsonb
  )
ON CONFLICT (order_code) DO NOTHING;

UPDATE public.sales_orders o
SET
  client_id = COALESCE(o.client_id, c.id),
  property_id = COALESCE(o.property_id, p.id),
  updated_at = now()
FROM (SELECT id FROM public.crm_clients WHERE id = 'a1000000-0000-4000-8000-000000000001' LIMIT 1) c
FULL OUTER JOIN (SELECT id FROM public.properties WHERE slug = 'victoria-crest-unit-4' LIMIT 1) p ON true
WHERE o.id = 'b2000000-0000-4000-8000-000000000001';

UPDATE public.sales_orders o
SET
  client_id = COALESCE(o.client_id, c.id),
  property_id = COALESCE(o.property_id, p.id),
  updated_at = now()
FROM (SELECT id FROM public.crm_clients WHERE id = 'a1000000-0000-4000-8000-000000000002' LIMIT 1) c
FULL OUTER JOIN (SELECT id FROM public.properties WHERE slug = 'victoria-crest-unit-4' LIMIT 1) p ON true
WHERE o.id = 'b2000000-0000-4000-8000-000000000002';

INSERT INTO public.sales_pipeline_history (id, order_id, from_stage_slug, to_stage_slug, note, changed_at) VALUES
  ('b2100000-0000-4000-8000-000000000001', 'b2000000-0000-4000-8000-000000000001', 'viewing', 'negotiation', 'Site visit complete — entered negotiation', now() - interval '5 days'),
  ('b2100000-0000-4000-8000-000000000002', 'b2000000-0000-4000-8000-000000000002', 'negotiation', 'contract', 'Terms agreed — contract pack issued', now() - interval '2 days')
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Reservations (one expiring soon, one confirmed)
-- ---------------------------------------------------------------------------
INSERT INTO public.sales_reservations (
  id, reservation_code, client_id, property_id, order_id, status,
  reserved_amount, reserved_at, expires_at, confirmed_at, notes, metadata
)
SELECT
  'b3000000-0000-4000-8000-000000000001',
  'RSV-EXP-001',
  o.client_id,
  o.property_id,
  o.id,
  'reserved',
  5000000,
  now() - interval '5 days',
  now() + interval '36 hours',
  NULL,
  'Deposit held — expires soon. Follow up before expiry.',
  '{"demo":true,"urgency":"expiring_soon"}'::jsonb
FROM public.sales_orders o
WHERE o.id = 'b2000000-0000-4000-8000-000000000001'
ON CONFLICT (reservation_code) DO UPDATE SET
  status = EXCLUDED.status,
  expires_at = EXCLUDED.expires_at,
  notes = EXCLUDED.notes,
  updated_at = now();

INSERT INTO public.sales_reservations (
  id, reservation_code, client_id, property_id, order_id, status,
  reserved_amount, reserved_at, expires_at, confirmed_at, notes, metadata
)
SELECT
  'b3000000-0000-4000-8000-000000000002',
  'RSV-CFM-002',
  o.client_id,
  o.property_id,
  o.id,
  'confirmed',
  8500000,
  now() - interval '12 days',
  now() + interval '14 days',
  now() - interval '10 days',
  'Confirmed reservation supporting near-contract deal.',
  '{"demo":true}'::jsonb
FROM public.sales_orders o
WHERE o.id = 'b2000000-0000-4000-8000-000000000002'
ON CONFLICT (reservation_code) DO UPDATE SET
  status = EXCLUDED.status,
  confirmed_at = EXCLUDED.confirmed_at,
  notes = EXCLUDED.notes,
  updated_at = now();

INSERT INTO public.sales_reservations (
  id, reservation_code, status, reserved_amount, reserved_at, expires_at, notes, metadata
) VALUES (
  'b3000000-0000-4000-8000-000000000003',
  'RSV-DFT-003',
  'draft',
  0,
  NULL,
  now() + interval '7 days',
  'Draft hold for Horizon Capital multi-unit interest.',
  '{"demo":true}'::jsonb
)
ON CONFLICT (reservation_code) DO NOTHING;

UPDATE public.sales_reservations r
SET client_id = COALESCE(r.client_id, c.id)
FROM (SELECT id FROM public.crm_clients WHERE id = 'a1000000-0000-4000-8000-000000000003' LIMIT 1) c
WHERE r.id = 'b3000000-0000-4000-8000-000000000003';

-- ---------------------------------------------------------------------------
-- Bookings
-- ---------------------------------------------------------------------------
INSERT INTO public.sales_bookings (
  id, booking_code, client_id, property_id, order_id, booking_type, status,
  scheduled_at, duration_minutes, location, notes, metadata
)
SELECT
  'b4000000-0000-4000-8000-000000000001',
  'BK-SITE-001',
  o.client_id,
  o.property_id,
  o.id,
  'site_visit',
  'confirmed',
  now() + interval '2 days',
  90,
  'Victoria Crest showflat',
  'VIP site visit with sales + construction escort',
  '{"demo":true}'::jsonb
FROM public.sales_orders o
WHERE o.id = 'b2000000-0000-4000-8000-000000000001'
ON CONFLICT (booking_code) DO UPDATE SET
  scheduled_at = EXCLUDED.scheduled_at,
  status = EXCLUDED.status,
  updated_at = now();

INSERT INTO public.sales_bookings (
  id, booking_code, client_id, property_id, order_id, booking_type, status,
  scheduled_at, duration_minutes, location, notes, metadata
)
SELECT
  'b4000000-0000-4000-8000-000000000002',
  'BK-OFF-002',
  o.client_id,
  o.property_id,
  o.id,
  'office',
  'scheduled',
  now() + interval '5 days',
  60,
  'HD Homes Lekki HQ',
  'Contract review meeting',
  '{"demo":true}'::jsonb
FROM public.sales_orders o
WHERE o.id = 'b2000000-0000-4000-8000-000000000002'
ON CONFLICT (booking_code) DO UPDATE SET
  scheduled_at = EXCLUDED.scheduled_at,
  updated_at = now();

INSERT INTO public.sales_bookings (
  id, booking_code, booking_type, status, scheduled_at, duration_minutes, location, notes, metadata
) VALUES (
  'b4000000-0000-4000-8000-000000000003',
  'BK-VIRT-003',
  'virtual_tour',
  'scheduled',
  now() + interval '1 day',
  45,
  'Zoom',
  'Virtual tour for diaspora enquiry',
  '{"demo":true}'::jsonb
)
ON CONFLICT (booking_code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Quotes + items + negotiations
-- ---------------------------------------------------------------------------
INSERT INTO public.sales_quotes (
  id, quote_code, client_id, property_id, order_id, status,
  subtotal, discount_amount, total_amount, valid_until, sent_at, notes, metadata
)
SELECT
  'b5000000-0000-4000-8000-000000000001',
  'QT-VC-001',
  o.client_id,
  o.property_id,
  o.id,
  'sent',
  128000000,
  3000000,
  125000000,
  (CURRENT_DATE + 14),
  now() - interval '3 days',
  'Estimate disclaimer included in quote pack.',
  '{"demo":true}'::jsonb
FROM public.sales_orders o
WHERE o.id = 'b2000000-0000-4000-8000-000000000001'
ON CONFLICT (quote_code) DO UPDATE SET
  total_amount = EXCLUDED.total_amount,
  status = EXCLUDED.status,
  updated_at = now();

INSERT INTO public.sales_quotes (
  id, quote_code, client_id, property_id, order_id, status,
  subtotal, discount_amount, total_amount, valid_until, sent_at, accepted_at, notes, metadata
)
SELECT
  'b5000000-0000-4000-8000-000000000002',
  'QT-LP-002',
  o.client_id,
  o.property_id,
  o.id,
  'accepted',
  88000000,
  3000000,
  85000000,
  (CURRENT_DATE + 7),
  now() - interval '8 days',
  now() - interval '6 days',
  'Accepted quote feeding contract stage.',
  '{"demo":true}'::jsonb
FROM public.sales_orders o
WHERE o.id = 'b2000000-0000-4000-8000-000000000002'
ON CONFLICT (quote_code) DO UPDATE SET
  status = EXCLUDED.status,
  updated_at = now();

INSERT INTO public.sales_quote_items (id, quote_id, label, description, quantity, unit_price, line_total, sort_order) VALUES
  ('b5100000-0000-4000-8000-000000000001', 'b5000000-0000-4000-8000-000000000001', 'Victoria Crest Unit 4', 'Duplex purchase price (estimate)', 1, 125000000, 125000000, 1),
  ('b5100000-0000-4000-8000-000000000002', 'b5000000-0000-4000-8000-000000000001', 'Furnishings allowance', 'Optional furniture package', 1, 3000000, 3000000, 2),
  ('b5100000-0000-4000-8000-000000000003', 'b5000000-0000-4000-8000-000000000002', 'Lekki 3-bed apartment', 'Base unit price (estimate)', 1, 85000000, 85000000, 1),
  ('b5100000-0000-4000-8000-000000000004', 'b5000000-0000-4000-8000-000000000002', 'Legal & documentation', 'Estimated conveyancing fee', 1, 3000000, 3000000, 2)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.sales_negotiations (id, order_id, quote_id, event_type, actor_label, amount, body, occurred_at) VALUES
  ('b5200000-0000-4000-8000-000000000001', 'b2000000-0000-4000-8000-000000000001', 'b5000000-0000-4000-8000-000000000001', 'offer', 'Sales — Amaka', 128000000, 'Initial offer at list price', now() - interval '6 days'),
  ('b5200000-0000-4000-8000-000000000002', 'b2000000-0000-4000-8000-000000000001', 'b5000000-0000-4000-8000-000000000001', 'counter', 'Client — Adaeze', 120000000, 'Client countered at ₦120M', now() - interval '4 days'),
  ('b5200000-0000-4000-8000-000000000003', 'b2000000-0000-4000-8000-000000000001', 'b5000000-0000-4000-8000-000000000001', 'concession', 'Sales — Amaka', 125000000, 'Meet-in-middle at ₦125M with furnishings optional', now() - interval '3 days'),
  ('b5200000-0000-4000-8000-000000000004', 'b2000000-0000-4000-8000-000000000002', 'b5000000-0000-4000-8000-000000000002', 'status_change', 'System', 85000000, 'Quote accepted — moved to contract', now() - interval '6 days')
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Contracts, payment plans, installments
-- ---------------------------------------------------------------------------
INSERT INTO public.sales_contracts (
  id, contract_code, order_id, client_id, property_id, status,
  contract_value, issued_at, expires_at, notes, metadata
)
SELECT
  'b6000000-0000-4000-8000-000000000001',
  'CT-LP-001',
  o.id,
  o.client_id,
  o.property_id,
  'awaiting_signature',
  85000000,
  now() - interval '1 day',
  now() + interval '10 days',
  'Digital signature pack sent to buyer counsel.',
  '{"demo":true}'::jsonb
FROM public.sales_orders o
WHERE o.id = 'b2000000-0000-4000-8000-000000000002'
ON CONFLICT (contract_code) DO UPDATE SET
  status = EXCLUDED.status,
  contract_value = EXCLUDED.contract_value,
  updated_at = now();

INSERT INTO public.sales_payment_plans (
  id, plan_code, order_id, client_id, property_id, total_amount,
  deposit_amount, installment_count, status, start_date, notes, metadata
)
SELECT
  'b7000000-0000-4000-8000-000000000001',
  'PP-LP-12M',
  o.id,
  o.client_id,
  o.property_id,
  85000000,
  17000000,
  12,
  'active',
  CURRENT_DATE,
  '12-month plan — demo estimates; not a finance product guarantee.',
  '{"demo":true,"disclaimer":"Installment schedules are estimates subject to approval."}'::jsonb
FROM public.sales_orders o
WHERE o.id = 'b2000000-0000-4000-8000-000000000002'
ON CONFLICT (plan_code) DO UPDATE SET
  total_amount = EXCLUDED.total_amount,
  status = EXCLUDED.status,
  updated_at = now();

INSERT INTO public.sales_installments (
  id, payment_plan_id, installment_no, amount, due_date, status, notes
) VALUES
  ('b7100000-0000-4000-8000-000000000001', 'b7000000-0000-4000-8000-000000000001', 1, 17000000, CURRENT_DATE - 5, 'paid', 'Deposit paid'),
  ('b7100000-0000-4000-8000-000000000002', 'b7000000-0000-4000-8000-000000000001', 2, 5666667, CURRENT_DATE + 3, 'due', 'Installment due soon'),
  ('b7100000-0000-4000-8000-000000000003', 'b7000000-0000-4000-8000-000000000001', 3, 5666667, CURRENT_DATE + 33, 'pending', NULL),
  ('b7100000-0000-4000-8000-000000000004', 'b7000000-0000-4000-8000-000000000001', 4, 5666667, CURRENT_DATE + 63, 'pending', NULL)
ON CONFLICT (payment_plan_id, installment_no) DO UPDATE SET
  amount = EXCLUDED.amount,
  due_date = EXCLUDED.due_date,
  status = EXCLUDED.status,
  updated_at = now();

-- ---------------------------------------------------------------------------
-- Commissions, handovers, discount request
-- ---------------------------------------------------------------------------
INSERT INTO public.sales_commissions (
  id, commission_code, order_id, agent_name, base_amount, commission_percent,
  commission_amount, status, earned_at, approved_at, notes, metadata
) VALUES
  (
    'b8000000-0000-4000-8000-000000000001',
    'CM-PEND-001',
    'b2000000-0000-4000-8000-000000000001',
    'Amaka Eze',
    125000000, 2.5, 3125000,
    'pending',
    now() - interval '1 day',
    NULL,
    'Pending approval on negotiation deal',
    '{"demo":true}'::jsonb
  ),
  (
    'b8000000-0000-4000-8000-000000000002',
    'CM-APPR-002',
    'b2000000-0000-4000-8000-000000000002',
    'Tobi Lawal',
    85000000, 2.0, 1700000,
    'approved',
    now() - interval '5 days',
    now() - interval '2 days',
    'Approved — awaiting payroll run',
    '{"demo":true}'::jsonb
  )
ON CONFLICT (commission_code) DO UPDATE SET
  status = EXCLUDED.status,
  commission_amount = EXCLUDED.commission_amount,
  updated_at = now();

INSERT INTO public.sales_handovers (
  id, order_id, client_id, property_id, status, checklist, scheduled_at, notes, metadata
)
SELECT
  'b9000000-0000-4000-8000-000000000001',
  o.id,
  o.client_id,
  o.property_id,
  'in_progress',
  '[
    {"item":"Title pack ready","done":true},
    {"item":"Keys scheduled","done":false},
    {"item":"Snag list signed","done":false},
    {"item":"Utility transfer","done":false}
  ]'::jsonb,
  now() + interval '20 days',
  'Handover checklist started after near-contract acceptance.',
  '{"demo":true}'::jsonb
FROM public.sales_orders o
WHERE o.id = 'b2000000-0000-4000-8000-000000000002'
ON CONFLICT (id) DO UPDATE SET
  checklist = EXCLUDED.checklist,
  status = EXCLUDED.status,
  updated_at = now();

INSERT INTO public.sales_discount_requests (
  id, order_id, discount_id, requester_label, requested_value, status, justification, metadata
) VALUES (
  'ba000000-0000-4000-8000-000000000001',
  'b2000000-0000-4000-8000-000000000001',
  'b1100000-0000-4000-8000-000000000001',
  'Amaka Eze',
  5,
  'pending',
  'VIP early-bird 5% to close within 10 days',
  '{"demo":true}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  status = EXCLUDED.status,
  justification = EXCLUDED.justification,
  updated_at = now();

INSERT INTO public.sales_documents (id, order_id, client_id, doc_type, title, status, metadata)
SELECT
  'bb000000-0000-4000-8000-000000000001',
  o.id,
  o.client_id,
  'quote_pdf',
  'Quote QT-VC-001.pdf',
  'active',
  '{"demo":true}'::jsonb
FROM public.sales_orders o
WHERE o.id = 'b2000000-0000-4000-8000-000000000001'
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Targets, forecasts, leaderboard, activity, notifications
-- ---------------------------------------------------------------------------
INSERT INTO public.sales_targets (
  id, period_label, period_start, period_end, target_amount, achieved_amount, owner_label, notes, metadata
) VALUES (
  'bc000000-0000-4000-8000-000000000001',
  'Q3 2026',
  '2026-07-01',
  '2026-09-30',
  500000000,
  210000000,
  'Sales Team',
  'Target stub — achieved amount is demo estimate.',
  '{"demo":true,"disclaimer":"Targets and achievement figures are estimates for demo."}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  target_amount = EXCLUDED.target_amount,
  achieved_amount = EXCLUDED.achieved_amount,
  updated_at = now();

INSERT INTO public.sales_forecasts (
  id, period_label, forecast_amount, confidence_pct, disclaimer, metadata
) VALUES (
  'bd000000-0000-4000-8000-000000000001',
  'Next 90 days',
  320000000,
  58,
  'Sales forecasts are estimates only and are not guarantees of future revenue.',
  '{"demo":true}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  forecast_amount = EXCLUDED.forecast_amount,
  confidence_pct = EXCLUDED.confidence_pct,
  updated_at = now();

INSERT INTO public.sales_reports (id, report_code, title, report_type, payload) VALUES (
  'be000000-0000-4000-8000-000000000001',
  'RPT-PIPE-DEMO',
  'Pipeline snapshot (demo)',
  'pipeline',
  '{"weighted_pipeline":146250000,"deals_open":2,"disclaimer":"Report figures are demo estimates."}'::jsonb
)
ON CONFLICT (report_code) DO UPDATE SET
  payload = EXCLUDED.payload,
  generated_at = now();

INSERT INTO public.sales_leaderboards (id, period_label, agent_name, rank, deals_won, revenue, snapshot_at, metadata) VALUES
  ('bf000000-0000-4000-8000-000000000001', 'July 2026', 'Amaka Eze', 1, 4, 185000000, now(), '{"demo":true}'::jsonb),
  ('bf000000-0000-4000-8000-000000000002', 'July 2026', 'Tobi Lawal', 2, 3, 142000000, now(), '{"demo":true}'::jsonb),
  ('bf000000-0000-4000-8000-000000000003', 'July 2026', 'Ngozi Bello', 3, 2, 96000000, now(), '{"demo":true}'::jsonb)
ON CONFLICT (id) DO UPDATE SET
  revenue = EXCLUDED.revenue,
  deals_won = EXCLUDED.deals_won,
  snapshot_at = now();

INSERT INTO public.sales_activity_logs (id, order_id, client_id, event_type, title, description, actor_label, occurred_at) VALUES
  ('c1000000-0000-4000-8000-000000000001', 'b2000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', 'negotiation', 'Counter received', 'Client countered at ₦120M', 'Adaeze Nwosu', now() - interval '4 days'),
  ('c1000000-0000-4000-8000-000000000002', 'b2000000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000002', 'contract', 'Contract awaiting signature', 'Signature pack sent', 'System', now() - interval '1 day'),
  ('c1000000-0000-4000-8000-000000000003', 'b2000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', 'reservation', 'Reservation expiring soon', 'RSV-EXP-001 expires within 48h', 'System', now() - interval '2 hours')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.sales_notifications (id, title, body, severity, status, order_id, metadata) VALUES
  (
    'c2000000-0000-4000-8000-000000000001',
    'Reservation expiring',
    'RSV-EXP-001 expires within 36 hours — action required.',
    'high',
    'open',
    'b2000000-0000-4000-8000-000000000001',
    '{"demo":true}'::jsonb
  ),
  (
    'c2000000-0000-4000-8000-000000000002',
    'Discount approval pending',
    'Early Bird 5% request awaits manager approval.',
    'medium',
    'open',
    'b2000000-0000-4000-8000-000000000001',
    '{"demo":true}'::jsonb
  )
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.sales_pipeline_stages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_pipeline_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_quotes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_quote_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_negotiations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_payment_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_installments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_commissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_handovers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_discounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_discount_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_targets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_forecasts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_leaderboards ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS sales_pipeline_stages_select ON public.sales_pipeline_stages;
DROP POLICY IF EXISTS sales_pipeline_stages_write ON public.sales_pipeline_stages;
CREATE POLICY sales_pipeline_stages_select ON public.sales_pipeline_stages FOR SELECT
  USING (public.has_permission('sales.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY sales_pipeline_stages_write ON public.sales_pipeline_stages FOR ALL
  USING (public.has_permission('sales.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('sales.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS sales_orders_select ON public.sales_orders;
DROP POLICY IF EXISTS sales_orders_write ON public.sales_orders;
CREATE POLICY sales_orders_select ON public.sales_orders FOR SELECT
  USING (public.has_permission('sales.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY sales_orders_write ON public.sales_orders FOR ALL
  USING (public.has_permission('sales.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('sales.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS sales_pipeline_history_select ON public.sales_pipeline_history;
DROP POLICY IF EXISTS sales_pipeline_history_write ON public.sales_pipeline_history;
CREATE POLICY sales_pipeline_history_select ON public.sales_pipeline_history FOR SELECT
  USING (public.has_permission('sales.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY sales_pipeline_history_write ON public.sales_pipeline_history FOR ALL
  USING (public.has_permission('sales.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('sales.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS sales_reservations_select ON public.sales_reservations;
DROP POLICY IF EXISTS sales_reservations_write ON public.sales_reservations;
CREATE POLICY sales_reservations_select ON public.sales_reservations FOR SELECT
  USING (
    public.has_permission('sales.read', auth.uid())
    OR public.has_permission('sales.reservations', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY sales_reservations_write ON public.sales_reservations FOR ALL
  USING (public.has_permission('sales.reservations', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('sales.reservations', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS sales_bookings_select ON public.sales_bookings;
DROP POLICY IF EXISTS sales_bookings_write ON public.sales_bookings;
CREATE POLICY sales_bookings_select ON public.sales_bookings FOR SELECT
  USING (
    public.has_permission('sales.read', auth.uid())
    OR public.has_permission('sales.bookings', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY sales_bookings_write ON public.sales_bookings FOR ALL
  USING (public.has_permission('sales.bookings', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('sales.bookings', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS sales_quotes_select ON public.sales_quotes;
DROP POLICY IF EXISTS sales_quotes_write ON public.sales_quotes;
CREATE POLICY sales_quotes_select ON public.sales_quotes FOR SELECT
  USING (
    public.has_permission('sales.read', auth.uid())
    OR public.has_permission('sales.quotes', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY sales_quotes_write ON public.sales_quotes FOR ALL
  USING (public.has_permission('sales.quotes', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('sales.quotes', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS sales_quote_items_select ON public.sales_quote_items;
DROP POLICY IF EXISTS sales_quote_items_write ON public.sales_quote_items;
CREATE POLICY sales_quote_items_select ON public.sales_quote_items FOR SELECT
  USING (
    public.has_permission('sales.read', auth.uid())
    OR public.has_permission('sales.quotes', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY sales_quote_items_write ON public.sales_quote_items FOR ALL
  USING (public.has_permission('sales.quotes', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('sales.quotes', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS sales_negotiations_select ON public.sales_negotiations;
DROP POLICY IF EXISTS sales_negotiations_write ON public.sales_negotiations;
CREATE POLICY sales_negotiations_select ON public.sales_negotiations FOR SELECT
  USING (public.has_permission('sales.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY sales_negotiations_write ON public.sales_negotiations FOR ALL
  USING (public.has_permission('sales.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('sales.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS sales_contracts_select ON public.sales_contracts;
DROP POLICY IF EXISTS sales_contracts_write ON public.sales_contracts;
CREATE POLICY sales_contracts_select ON public.sales_contracts FOR SELECT
  USING (
    public.has_permission('sales.read', auth.uid())
    OR public.has_permission('sales.contracts', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY sales_contracts_write ON public.sales_contracts FOR ALL
  USING (public.has_permission('sales.contracts', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('sales.contracts', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS sales_payment_plans_select ON public.sales_payment_plans;
DROP POLICY IF EXISTS sales_payment_plans_write ON public.sales_payment_plans;
CREATE POLICY sales_payment_plans_select ON public.sales_payment_plans FOR SELECT
  USING (public.has_permission('sales.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY sales_payment_plans_write ON public.sales_payment_plans FOR ALL
  USING (public.has_permission('sales.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('sales.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS sales_installments_select ON public.sales_installments;
DROP POLICY IF EXISTS sales_installments_write ON public.sales_installments;
CREATE POLICY sales_installments_select ON public.sales_installments FOR SELECT
  USING (
    public.has_permission('sales.read', auth.uid())
    OR public.has_permission('sales.commissions', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY sales_installments_write ON public.sales_installments FOR ALL
  USING (public.has_permission('sales.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('sales.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS sales_commissions_select ON public.sales_commissions;
DROP POLICY IF EXISTS sales_commissions_write ON public.sales_commissions;
CREATE POLICY sales_commissions_select ON public.sales_commissions FOR SELECT
  USING (
    public.has_permission('sales.read', auth.uid())
    OR public.has_permission('sales.commissions', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY sales_commissions_write ON public.sales_commissions FOR ALL
  USING (public.has_permission('sales.commissions', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('sales.commissions', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS sales_handovers_select ON public.sales_handovers;
DROP POLICY IF EXISTS sales_handovers_write ON public.sales_handovers;
CREATE POLICY sales_handovers_select ON public.sales_handovers FOR SELECT
  USING (public.has_permission('sales.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY sales_handovers_write ON public.sales_handovers FOR ALL
  USING (public.has_permission('sales.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('sales.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS sales_documents_select ON public.sales_documents;
DROP POLICY IF EXISTS sales_documents_write ON public.sales_documents;
CREATE POLICY sales_documents_select ON public.sales_documents FOR SELECT
  USING (public.has_permission('sales.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY sales_documents_write ON public.sales_documents FOR ALL
  USING (public.has_permission('sales.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('sales.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS sales_discounts_select ON public.sales_discounts;
DROP POLICY IF EXISTS sales_discounts_write ON public.sales_discounts;
CREATE POLICY sales_discounts_select ON public.sales_discounts FOR SELECT
  USING (public.has_permission('sales.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY sales_discounts_write ON public.sales_discounts FOR ALL
  USING (public.has_permission('sales.approvals', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('sales.approvals', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS sales_discount_requests_select ON public.sales_discount_requests;
DROP POLICY IF EXISTS sales_discount_requests_write ON public.sales_discount_requests;
CREATE POLICY sales_discount_requests_select ON public.sales_discount_requests FOR SELECT
  USING (
    public.has_permission('sales.read', auth.uid())
    OR public.has_permission('sales.approvals', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY sales_discount_requests_write ON public.sales_discount_requests FOR ALL
  USING (public.has_permission('sales.approvals', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('sales.approvals', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS sales_targets_select ON public.sales_targets;
DROP POLICY IF EXISTS sales_targets_write ON public.sales_targets;
CREATE POLICY sales_targets_select ON public.sales_targets FOR SELECT
  USING (
    public.has_permission('sales.read', auth.uid())
    OR public.has_permission('sales.analytics', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY sales_targets_write ON public.sales_targets FOR ALL
  USING (public.has_permission('sales.analytics', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('sales.analytics', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS sales_forecasts_select ON public.sales_forecasts;
DROP POLICY IF EXISTS sales_forecasts_write ON public.sales_forecasts;
CREATE POLICY sales_forecasts_select ON public.sales_forecasts FOR SELECT
  USING (
    public.has_permission('sales.read', auth.uid())
    OR public.has_permission('sales.analytics', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY sales_forecasts_write ON public.sales_forecasts FOR ALL
  USING (public.has_permission('sales.analytics', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('sales.analytics', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS sales_reports_select ON public.sales_reports;
DROP POLICY IF EXISTS sales_reports_write ON public.sales_reports;
CREATE POLICY sales_reports_select ON public.sales_reports FOR SELECT
  USING (
    public.has_permission('sales.read', auth.uid())
    OR public.has_permission('sales.analytics', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY sales_reports_write ON public.sales_reports FOR ALL
  USING (public.has_permission('sales.analytics', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('sales.analytics', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS sales_activity_logs_select ON public.sales_activity_logs;
DROP POLICY IF EXISTS sales_activity_logs_write ON public.sales_activity_logs;
CREATE POLICY sales_activity_logs_select ON public.sales_activity_logs FOR SELECT
  USING (public.has_permission('sales.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY sales_activity_logs_write ON public.sales_activity_logs FOR ALL
  USING (public.has_permission('sales.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('sales.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS sales_notifications_select ON public.sales_notifications;
DROP POLICY IF EXISTS sales_notifications_write ON public.sales_notifications;
CREATE POLICY sales_notifications_select ON public.sales_notifications FOR SELECT
  USING (public.has_permission('sales.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY sales_notifications_write ON public.sales_notifications FOR ALL
  USING (public.has_permission('sales.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('sales.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS sales_leaderboards_select ON public.sales_leaderboards;
DROP POLICY IF EXISTS sales_leaderboards_write ON public.sales_leaderboards;
CREATE POLICY sales_leaderboards_select ON public.sales_leaderboards FOR SELECT
  USING (
    public.has_permission('sales.read', auth.uid())
    OR public.has_permission('sales.analytics', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY sales_leaderboards_write ON public.sales_leaderboards FOR ALL
  USING (public.has_permission('sales.analytics', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('sales.analytics', auth.uid()) OR public.has_role('super_admin', auth.uid()));

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'sales_reservations',
    'sales_bookings',
    'sales_orders',
    'sales_quotes',
    'sales_contracts',
    'sales_installments',
    'sales_commissions',
    'sales_discount_requests',
    'sales_activity_logs'
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

-- Status: APPLIED remotely 2026-07-14 (chunked apply_migration p1–p3).
