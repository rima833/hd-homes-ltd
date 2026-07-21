-- Volume 4 Part 4 — Enterprise Investor Management Platform (IMP)
-- Status: APPLIED remotely 2026-07-14 (chunked p1–p3).
-- Extends foundational investors / investment_* tables; creates IMP enrichment tables.

BEGIN;

-- ---------------------------------------------------------------------------
-- Permissions (NO action column — slug, name, description, module only)
-- ---------------------------------------------------------------------------
INSERT INTO public.permissions (slug, name, description, module) VALUES
  ('investors.read', 'View Investors', 'View investor command center and investor records', 'investors'),
  ('investors.write', 'Manage Investors', 'Create and edit investor profiles and preferences', 'investors'),
  ('investors.opportunities', 'Manage Opportunities', 'Create and manage capital raise opportunities', 'investors'),
  ('investors.portfolio', 'Manage Portfolios', 'View and manage investor portfolios and holdings', 'investors'),
  ('investors.distributions', 'Manage Distributions', 'Schedule and process investment distributions', 'investors'),
  ('investors.documents', 'Investor Documents', 'Manage investor documents and statements', 'investors'),
  ('investors.analytics', 'Investor Analytics', 'View AUM, performance, and IMP analytics', 'investors'),
  ('investors.ai', 'AI Investment Assistant', 'Use AI portfolio summaries and investment insights', 'investors'),
  ('investors.assign', 'Assign Investor Owners', 'Assign staff to investors and opportunities', 'investors'),
  ('investors.kyc', 'Investor KYC Reviews', 'Review investor KYC and compliance checks', 'investors')
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  module = EXCLUDED.module,
  updated_at = now();

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE p.slug LIKE 'investors.%'
  AND (
    r.slug IN ('super_admin', 'admin')
    OR (r.slug = 'sales_team' AND p.slug IN (
      'investors.read','investors.write','investors.opportunities',
      'investors.assign','investors.analytics','investors.ai','investors.distributions'
    ))
    OR (r.slug = 'finance' AND p.slug IN (
      'investors.read','investors.portfolio','investors.distributions',
      'investors.analytics','investors.documents'
    ))
    OR (r.slug = 'marketing' AND p.slug IN (
      'investors.read','investors.ai'
    ))
    OR (r.slug = 'investor' AND p.slug IN (
      'investors.read'
    ))
  )
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Enrich existing investors table (foundation already created)
-- ---------------------------------------------------------------------------
ALTER TABLE public.investors
  ADD COLUMN IF NOT EXISTS full_name text,
  ADD COLUMN IF NOT EXISTS email text,
  ADD COLUMN IF NOT EXISTS phone text,
  ADD COLUMN IF NOT EXISTS company text,
  ADD COLUMN IF NOT EXISTS investor_type text DEFAULT 'individual',
  ADD COLUMN IF NOT EXISTS lifecycle_status text DEFAULT 'prospect',
  ADD COLUMN IF NOT EXISTS kyc_status text DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS risk_level text DEFAULT 'moderate',
  ADD COLUMN IF NOT EXISTS nationality text,
  ADD COLUMN IF NOT EXISTS preferred_currency text DEFAULT 'NGN',
  ADD COLUMN IF NOT EXISTS aum numeric(16,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_committed numeric(16,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS assigned_staff_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS ai_summary text,
  ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'investors_investor_type_check'
  ) THEN
    ALTER TABLE public.investors
      ADD CONSTRAINT investors_investor_type_check
      CHECK (investor_type IS NULL OR investor_type IN (
        'individual','hnwi','corporate','institutional','family_office','first_time','fund'
      ));
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'investors_lifecycle_status_check'
  ) THEN
    ALTER TABLE public.investors
      ADD CONSTRAINT investors_lifecycle_status_check
      CHECK (lifecycle_status IS NULL OR lifecycle_status IN (
        'prospect','onboarding','active','vip','dormant','exited','suspended'
      ));
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'investors_kyc_status_check'
  ) THEN
    ALTER TABLE public.investors
      ADD CONSTRAINT investors_kyc_status_check
      CHECK (kyc_status IS NULL OR kyc_status IN (
        'pending','in_progress','awaiting_documents','under_review','approved',
        'partially_approved','rejected','expired','suspended','needs_resubmission'
      ));
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'investors_risk_level_check'
  ) THEN
    ALTER TABLE public.investors
      ADD CONSTRAINT investors_risk_level_check
      CHECK (risk_level IS NULL OR risk_level IN (
        'conservative','moderate','aggressive','speculative'
      ));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_investors_lifecycle ON public.investors (lifecycle_status);
CREATE INDEX IF NOT EXISTS idx_investors_email ON public.investors (email);
CREATE INDEX IF NOT EXISTS idx_investors_assigned ON public.investors (assigned_staff_id);

-- ---------------------------------------------------------------------------
-- Profiles, preferences, tags
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.investor_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL UNIQUE REFERENCES public.investors(id) ON DELETE CASCADE,
  legal_name text,
  date_of_birth date,
  address_line text,
  city text,
  country text,
  tax_id text,
  source_of_funds text,
  investment_experience text,
  linkedin_url text,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_preferences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL UNIQUE REFERENCES public.investors(id) ON DELETE CASCADE,
  preferred_asset_classes text[] NOT NULL DEFAULT '{}',
  preferred_locations text[] NOT NULL DEFAULT '{}',
  min_ticket numeric(16,2),
  max_ticket numeric(16,2),
  target_yield_pct numeric(8,4),
  horizon_years numeric(5,2),
  esg_focus boolean NOT NULL DEFAULT false,
  notification_channels text[] NOT NULL DEFAULT ARRAY['email'],
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_tags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  color text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_tag_assignments (
  investor_id uuid NOT NULL REFERENCES public.investors(id) ON DELETE CASCADE,
  tag_id uuid NOT NULL REFERENCES public.investor_tags(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (investor_id, tag_id)
);

-- ---------------------------------------------------------------------------
-- Opportunities & commitments
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.investment_opportunities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  title text NOT NULL,
  description text,
  property_id uuid REFERENCES public.properties(id) ON DELETE SET NULL,
  estate_id uuid REFERENCES public.estates(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','closed','fully_funded','suspended','completed')),
  target_raise numeric(16,2) NOT NULL DEFAULT 0,
  amount_raised numeric(16,2) NOT NULL DEFAULT 0,
  min_ticket numeric(16,2),
  max_ticket numeric(16,2),
  currency text NOT NULL DEFAULT 'NGN',
  projected_return_pct numeric(8,4),
  return_disclaimer text NOT NULL DEFAULT
    'Projected returns are estimates only and are not guaranteed. Past performance does not predict future results.',
  risk_level text NOT NULL DEFAULT 'moderate'
    CHECK (risk_level IN ('conservative','moderate','aggressive','speculative')),
  open_at timestamptz,
  close_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_investment_opportunities_status
  ON public.investment_opportunities (status);

CREATE TABLE IF NOT EXISTS public.investment_commitments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.investors(id) ON DELETE CASCADE,
  opportunity_id uuid NOT NULL REFERENCES public.investment_opportunities(id) ON DELETE CASCADE,
  amount numeric(16,2) NOT NULL,
  currency text NOT NULL DEFAULT 'NGN',
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','reserved','confirmed','funded','cancelled','refunded')),
  committed_at timestamptz NOT NULL DEFAULT now(),
  funded_at timestamptz,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_investment_commitments_investor
  ON public.investment_commitments (investor_id);
CREATE INDEX IF NOT EXISTS idx_investment_commitments_opportunity
  ON public.investment_commitments (opportunity_id);

-- ---------------------------------------------------------------------------
-- Portfolios & holdings (new IMP tables; legacy investment_portfolios retained)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.investor_portfolios (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL UNIQUE REFERENCES public.investors(id) ON DELETE CASCADE,
  name text NOT NULL DEFAULT 'Primary Portfolio',
  currency text NOT NULL DEFAULT 'NGN',
  total_value numeric(16,2) NOT NULL DEFAULT 0,
  total_cost numeric(16,2) NOT NULL DEFAULT 0,
  unrealized_gain numeric(16,2) NOT NULL DEFAULT 0,
  realized_gain numeric(16,2) NOT NULL DEFAULT 0,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.portfolio_holdings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  portfolio_id uuid NOT NULL REFERENCES public.investor_portfolios(id) ON DELETE CASCADE,
  opportunity_id uuid REFERENCES public.investment_opportunities(id) ON DELETE SET NULL,
  property_id uuid REFERENCES public.properties(id) ON DELETE SET NULL,
  label text NOT NULL,
  units numeric(16,4) NOT NULL DEFAULT 1,
  cost_basis numeric(16,2) NOT NULL DEFAULT 0,
  current_value numeric(16,2) NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'NGN',
  acquired_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_portfolio_holdings_portfolio
  ON public.portfolio_holdings (portfolio_id);

-- Enrich legacy investment_transactions for IMP ledger use (supports remote + local shapes)
ALTER TABLE public.investment_transactions
  ADD COLUMN IF NOT EXISTS opportunity_id uuid,
  ADD COLUMN IF NOT EXISTS description text,
  ADD COLUMN IF NOT EXISTS direction text DEFAULT 'in',
  ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS portfolio_id uuid,
  ADD COLUMN IF NOT EXISTS transaction_type text,
  ADD COLUMN IF NOT EXISTS amount numeric(15,2),
  ADD COLUMN IF NOT EXISTS transaction_date timestamptz DEFAULT now(),
  ADD COLUMN IF NOT EXISTS reference text,
  ADD COLUMN IF NOT EXISTS investor_id uuid,
  ADD COLUMN IF NOT EXISTS investment_amount numeric(15,2);

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'investment_transactions'
      AND column_name = 'portfolio_id'
      AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE public.investment_transactions
      ALTER COLUMN portfolio_id DROP NOT NULL;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Distributions, wallets, bank accounts
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.investment_distributions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.investors(id) ON DELETE CASCADE,
  opportunity_id uuid REFERENCES public.investment_opportunities(id) ON DELETE SET NULL,
  portfolio_id uuid REFERENCES public.investor_portfolios(id) ON DELETE SET NULL,
  amount numeric(16,2) NOT NULL,
  currency text NOT NULL DEFAULT 'NGN',
  status text NOT NULL DEFAULT 'scheduled'
    CHECK (status IN ('scheduled','processing','paid','failed','cancelled')),
  distribution_type text NOT NULL DEFAULT 'dividend'
    CHECK (distribution_type IN ('dividend','interest','capital_return','bonus','other')),
  scheduled_at timestamptz,
  paid_at timestamptz,
  reference text,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_investment_distributions_investor
  ON public.investment_distributions (investor_id);
CREATE INDEX IF NOT EXISTS idx_investment_distributions_status
  ON public.investment_distributions (status);

CREATE TABLE IF NOT EXISTS public.investor_wallets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL UNIQUE REFERENCES public.investors(id) ON DELETE CASCADE,
  currency text NOT NULL DEFAULT 'NGN',
  available_balance numeric(16,2) NOT NULL DEFAULT 0,
  pending_balance numeric(16,2) NOT NULL DEFAULT 0,
  reserved_balance numeric(16,2) NOT NULL DEFAULT 0,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_bank_accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.investors(id) ON DELETE CASCADE,
  bank_name text NOT NULL,
  account_name text NOT NULL,
  account_number_masked text NOT NULL,
  currency text NOT NULL DEFAULT 'NGN',
  is_primary boolean NOT NULL DEFAULT false,
  is_verified boolean NOT NULL DEFAULT false,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Documents, statements, reports
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.investor_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.investors(id) ON DELETE CASCADE,
  title text NOT NULL,
  document_type text NOT NULL DEFAULT 'other',
  file_url text,
  version int NOT NULL DEFAULT 1,
  is_sensitive boolean NOT NULL DEFAULT true,
  expires_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_statements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.investors(id) ON DELETE CASCADE,
  period_label text NOT NULL,
  period_start date,
  period_end date,
  file_url text,
  opening_balance numeric(16,2) DEFAULT 0,
  closing_balance numeric(16,2) DEFAULT 0,
  currency text NOT NULL DEFAULT 'NGN',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid REFERENCES public.investors(id) ON DELETE CASCADE,
  title text NOT NULL,
  report_type text NOT NULL DEFAULT 'portfolio'
    CHECK (report_type IN ('portfolio','performance','tax','compliance','market','custom')),
  file_url text,
  period_label text,
  generated_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Tasks, relationships, activity, notifications, alerts
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.investor_tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.investors(id) ON DELETE CASCADE,
  title text NOT NULL,
  task_type text NOT NULL DEFAULT 'follow_up',
  priority text NOT NULL DEFAULT 'medium'
    CHECK (priority IN ('low','medium','high','urgent')),
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','in_progress','done','cancelled')),
  due_at timestamptz,
  assigned_to uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_relationships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.investors(id) ON DELETE CASCADE,
  related_investor_id uuid REFERENCES public.investors(id) ON DELETE SET NULL,
  related_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  relationship_type text NOT NULL DEFAULT 'referral'
    CHECK (relationship_type IN (
      'referral','family','advisor','co_investor','introducer','staff_owner','other'
    )),
  label text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_activity_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.investors(id) ON DELETE CASCADE,
  event_type text NOT NULL,
  title text NOT NULL,
  description text,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  actor_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_investor_activity_logs_investor
  ON public.investor_activity_logs (investor_id);
CREATE INDEX IF NOT EXISTS idx_investor_activity_logs_occurred
  ON public.investor_activity_logs (occurred_at DESC);

CREATE TABLE IF NOT EXISTS public.investor_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.investors(id) ON DELETE CASCADE,
  channel text NOT NULL DEFAULT 'in_app'
    CHECK (channel IN ('email','sms','whatsapp','in_app','push')),
  title text NOT NULL,
  body text,
  is_read boolean NOT NULL DEFAULT false,
  sent_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid REFERENCES public.investors(id) ON DELETE CASCADE,
  opportunity_id uuid REFERENCES public.investment_opportunities(id) ON DELETE SET NULL,
  severity text NOT NULL DEFAULT 'info'
    CHECK (severity IN ('info','low','medium','high','critical')),
  title text NOT NULL,
  body text,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','acknowledged','resolved','dismissed')),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investment_performance (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid REFERENCES public.investors(id) ON DELETE CASCADE,
  portfolio_id uuid REFERENCES public.investor_portfolios(id) ON DELETE CASCADE,
  opportunity_id uuid REFERENCES public.investment_opportunities(id) ON DELETE SET NULL,
  as_of_date date NOT NULL DEFAULT CURRENT_DATE,
  nav numeric(16,2) NOT NULL DEFAULT 0,
  twr_pct numeric(8,4),
  irr_pct numeric(8,4),
  yield_pct numeric(8,4),
  currency text NOT NULL DEFAULT 'NGN',
  breakdown jsonb NOT NULL DEFAULT '{}'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_kyc_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.investors(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN (
      'pending','in_progress','awaiting_documents','under_review','approved',
      'partially_approved','rejected','expired','suspended','needs_resubmission'
    )),
  reviewer_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  notes text,
  risk_flags text[] NOT NULL DEFAULT '{}',
  reviewed_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Tags seed
-- ---------------------------------------------------------------------------
INSERT INTO public.investor_tags (slug, name, color) VALUES
  ('vip', 'VIP', '#D4AF37'),
  ('platinum', 'Platinum', '#94A3B8'),
  ('hnwi', 'HNWI', '#7C3AED'),
  ('institutional', 'Institutional', '#2563EB'),
  ('first_time', 'First Time', '#059669'),
  ('international', 'International', '#0891B2')
ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name, color = EXCLUDED.color;

-- ---------------------------------------------------------------------------
-- Demo seeds (fixed UUIDs)
-- ---------------------------------------------------------------------------
INSERT INTO public.investors (
  id, investor_code, full_name, email, phone, company, investor_type,
  lifecycle_status, kyc_status, risk_level, nationality, preferred_currency,
  aum, total_committed, ai_summary, status, metadata
) VALUES
  (
    'b2000000-0000-4000-8000-000000000001',
    'INV-VIP-001',
    'Folake Adeyemi',
    'folake.adeyemi@example.com',
    '+2348021000001',
    'Adeyemi Family Office',
    'hnwi',
    'vip',
    'approved',
    'moderate',
    'Nigerian',
    'NGN',
    420000000,
    185000000,
    'VIP HNWI with strong appetite for Lekki coastal assets. Prioritize Victoria Crest upsell and quarterly briefings.',
    'active',
    '{"demo":true,"persona":"vip_hnwi"}'::jsonb
  ),
  (
    'b2000000-0000-4000-8000-000000000002',
    'INV-CORP-002',
    'Meridian Equity Partners',
    'deals@meridianequity.example',
    '+2348021000002',
    'Meridian Equity Partners',
    'institutional',
    'active',
    'under_review',
    'conservative',
    'Nigerian',
    'NGN',
    980000000,
    450000000,
    'Institutional buyer seeking fully funded multi-unit tranches with audited yield packs and escrow clarity.',
    'active',
    '{"demo":true,"persona":"corporate_institutional"}'::jsonb
  ),
  (
    'b2000000-0000-4000-8000-000000000003',
    'INV-FT-003',
    'Tunde Bakare',
    'tunde.bakare@example.com',
    '+2348021000003',
    NULL,
    'first_time',
    'onboarding',
    'awaiting_documents',
    'moderate',
    'Nigerian',
    'NGN',
    25000000,
    15000000,
    'First-time investor mid-KYC. Guide with smaller tickets and clear estimate disclaimers before commit.',
    'active',
    '{"demo":true,"persona":"first_time"}'::jsonb
  )
ON CONFLICT (id) DO UPDATE SET
  full_name = EXCLUDED.full_name,
  email = EXCLUDED.email,
  investor_type = EXCLUDED.investor_type,
  lifecycle_status = EXCLUDED.lifecycle_status,
  kyc_status = EXCLUDED.kyc_status,
  aum = EXCLUDED.aum,
  total_committed = EXCLUDED.total_committed,
  ai_summary = EXCLUDED.ai_summary,
  metadata = EXCLUDED.metadata,
  updated_at = now();

UPDATE public.investors
SET investor_code = COALESCE(investor_code, 'INV-' || LEFT(id::text, 8))
WHERE id IN (
  'b2000000-0000-4000-8000-000000000001',
  'b2000000-0000-4000-8000-000000000002',
  'b2000000-0000-4000-8000-000000000003'
);

INSERT INTO public.investor_profiles (investor_id, legal_name, country, city, source_of_funds, investment_experience, notes)
VALUES
  ('b2000000-0000-4000-8000-000000000001', 'Folake Olufunke Adeyemi', 'Nigeria', 'Lagos', 'Business proceeds', 'Experienced', 'VIP family office mandate'),
  ('b2000000-0000-4000-8000-000000000002', 'Meridian Equity Partners Ltd', 'Nigeria', 'Lagos', 'Institutional capital', 'Institutional', 'Requires board pack'),
  ('b2000000-0000-4000-8000-000000000003', 'Olútúndé Bakare', 'Nigeria', 'Abuja', 'Salary savings', 'Beginner', 'First commitment path')
ON CONFLICT (investor_id) DO UPDATE SET
  legal_name = EXCLUDED.legal_name,
  country = EXCLUDED.country,
  city = EXCLUDED.city,
  source_of_funds = EXCLUDED.source_of_funds,
  investment_experience = EXCLUDED.investment_experience,
  notes = EXCLUDED.notes,
  updated_at = now();

INSERT INTO public.investor_preferences (
  investor_id, preferred_asset_classes, preferred_locations, min_ticket, max_ticket, target_yield_pct, horizon_years, esg_focus
) VALUES
  ('b2000000-0000-4000-8000-000000000001', ARRAY['residential','waterfront'], ARRAY['Lekki','Victoria Island'], 50000000, 200000000, 14.5, 5, true),
  ('b2000000-0000-4000-8000-000000000002', ARRAY['multi_unit','commercial'], ARRAY['Lekki','Port Harcourt','Abuja'], 100000000, 500000000, 12.0, 7, false),
  ('b2000000-0000-4000-8000-000000000003', ARRAY['residential'], ARRAY['Abuja','Lekki'], 5000000, 30000000, 10.0, 3, false)
ON CONFLICT (investor_id) DO UPDATE SET
  preferred_asset_classes = EXCLUDED.preferred_asset_classes,
  preferred_locations = EXCLUDED.preferred_locations,
  min_ticket = EXCLUDED.min_ticket,
  max_ticket = EXCLUDED.max_ticket,
  target_yield_pct = EXCLUDED.target_yield_pct,
  horizon_years = EXCLUDED.horizon_years,
  updated_at = now();

-- Tag assignments
INSERT INTO public.investor_tag_assignments (investor_id, tag_id)
SELECT 'b2000000-0000-4000-8000-000000000001', t.id FROM public.investor_tags t WHERE t.slug IN ('vip','platinum','hnwi')
ON CONFLICT DO NOTHING;
INSERT INTO public.investor_tag_assignments (investor_id, tag_id)
SELECT 'b2000000-0000-4000-8000-000000000002', t.id FROM public.investor_tags t WHERE t.slug IN ('institutional','platinum')
ON CONFLICT DO NOTHING;
INSERT INTO public.investor_tag_assignments (investor_id, tag_id)
SELECT 'b2000000-0000-4000-8000-000000000003', t.id FROM public.investor_tags t WHERE t.slug IN ('first_time')
ON CONFLICT DO NOTHING;

-- Opportunities (link Victoria Crest when property exists)
INSERT INTO public.investment_opportunities (
  id, code, title, description, property_id, status, target_raise, amount_raised,
  min_ticket, max_ticket, currency, projected_return_pct, return_disclaimer, risk_level, open_at, close_at, metadata
)
SELECT
  'c2000000-0000-4000-8000-000000000001',
  'OPP-VC-OPEN',
  'Victoria Crest Unit 4 — Capital Raise',
  'Open raise for Victoria Crest residential unit targeting yield-oriented HNWI allocations.',
  p.id,
  'open',
  250000000,
  96000000,
  25000000,
  100000000,
  'NGN',
  13.50,
  'Projected returns are estimates only and are not guaranteed. Past performance does not predict future results.',
  'moderate',
  now() - interval '14 days',
  now() + interval '45 days',
  '{"demo":true,"estate":"victoria-crest"}'::jsonb
FROM (SELECT id FROM public.properties WHERE slug = 'victoria-crest-unit-4' LIMIT 1) p
WHERE NOT EXISTS (
  SELECT 1 FROM public.investment_opportunities o WHERE o.id = 'c2000000-0000-4000-8000-000000000001'
);

-- Fallback if property missing
INSERT INTO public.investment_opportunities (
  id, code, title, description, status, target_raise, amount_raised,
  min_ticket, max_ticket, currency, projected_return_pct, return_disclaimer, risk_level, open_at, close_at, metadata
)
SELECT
  'c2000000-0000-4000-8000-000000000001',
  'OPP-VC-OPEN',
  'Victoria Crest Unit 4 — Capital Raise',
  'Open raise for Victoria Crest residential unit targeting yield-oriented HNWI allocations.',
  'open',
  250000000,
  96000000,
  25000000,
  100000000,
  'NGN',
  13.50,
  'Projected returns are estimates only and are not guaranteed. Past performance does not predict future results.',
  'moderate',
  now() - interval '14 days',
  now() + interval '45 days',
  '{"demo":true,"estate":"victoria-crest"}'::jsonb
WHERE NOT EXISTS (
  SELECT 1 FROM public.investment_opportunities o WHERE o.id = 'c2000000-0000-4000-8000-000000000001'
);

INSERT INTO public.investment_opportunities (
  id, code, title, description, status, target_raise, amount_raised,
  min_ticket, max_ticket, currency, projected_return_pct, return_disclaimer, risk_level, open_at, close_at, metadata
)
SELECT
  'c2000000-0000-4000-8000-000000000002',
  'OPP-HV-FUNDED',
  'Harbour View Multi-Unit Tranche',
  'Fully funded institutional tranche with scheduled distributions underway.',
  'fully_funded',
  500000000,
  500000000,
  100000000,
  250000000,
  'NGN',
  11.25,
  'Projected returns are estimates only and are not guaranteed. Past performance does not predict future results.',
  'conservative',
  now() - interval '120 days',
  now() - interval '30 days',
  '{"demo":true,"estate":"harbour-view"}'::jsonb
WHERE NOT EXISTS (
  SELECT 1 FROM public.investment_opportunities o WHERE o.id = 'c2000000-0000-4000-8000-000000000002'
);

INSERT INTO public.investment_commitments (
  id, investor_id, opportunity_id, amount, currency, status, committed_at, funded_at, notes
)
SELECT
  'd2000000-0000-4000-8000-000000000001',
  'b2000000-0000-4000-8000-000000000001',
  'c2000000-0000-4000-8000-000000000001',
  75000000,
  'NGN',
  'confirmed',
  now() - interval '7 days',
  NULL,
  'VIP soft commit pending final KYC refresh'
WHERE NOT EXISTS (
  SELECT 1 FROM public.investment_commitments c WHERE c.id = 'd2000000-0000-4000-8000-000000000001'
);

INSERT INTO public.investment_commitments (
  id, investor_id, opportunity_id, amount, currency, status, committed_at, funded_at, notes
)
SELECT
  'd2000000-0000-4000-8000-000000000002',
  'b2000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000002',
  250000000,
  'NGN',
  'funded',
  now() - interval '90 days',
  now() - interval '60 days',
  'Institutional funded tranche'
WHERE NOT EXISTS (
  SELECT 1 FROM public.investment_commitments c WHERE c.id = 'd2000000-0000-4000-8000-000000000002'
);

INSERT INTO public.investment_commitments (
  id, investor_id, opportunity_id, amount, currency, status, committed_at, notes
)
SELECT
  'd2000000-0000-4000-8000-000000000003',
  'b2000000-0000-4000-8000-000000000003',
  'c2000000-0000-4000-8000-000000000001',
  15000000,
  'NGN',
  'reserved',
  now() - interval '2 days',
  'First-time ticket reservation'
WHERE NOT EXISTS (
  SELECT 1 FROM public.investment_commitments c WHERE c.id = 'd2000000-0000-4000-8000-000000000003'
);

INSERT INTO public.investor_portfolios (
  id, investor_id, name, currency, total_value, total_cost, unrealized_gain, realized_gain
) VALUES
  ('e2000000-0000-4000-8000-000000000001', 'b2000000-0000-4000-8000-000000000001', 'Adeyemi Primary', 'NGN', 420000000, 380000000, 40000000, 12000000),
  ('e2000000-0000-4000-8000-000000000002', 'b2000000-0000-4000-8000-000000000002', 'Meridian Core', 'NGN', 980000000, 900000000, 80000000, 45000000),
  ('e2000000-0000-4000-8000-000000000003', 'b2000000-0000-4000-8000-000000000003', 'Bakare Starter', 'NGN', 25000000, 24000000, 1000000, 0)
ON CONFLICT (investor_id) DO UPDATE SET
  total_value = EXCLUDED.total_value,
  total_cost = EXCLUDED.total_cost,
  unrealized_gain = EXCLUDED.unrealized_gain,
  realized_gain = EXCLUDED.realized_gain,
  updated_at = now();

INSERT INTO public.portfolio_holdings (
  id, portfolio_id, opportunity_id, label, units, cost_basis, current_value, currency, acquired_at
)
SELECT
  'f2000000-0000-4000-8000-000000000001',
  'e2000000-0000-4000-8000-000000000001',
  'c2000000-0000-4000-8000-000000000001',
  'Victoria Crest allocation',
  1,
  70000000,
  78000000,
  'NGN',
  now() - interval '30 days'
WHERE NOT EXISTS (
  SELECT 1 FROM public.portfolio_holdings h WHERE h.id = 'f2000000-0000-4000-8000-000000000001'
);

INSERT INTO public.portfolio_holdings (
  id, portfolio_id, opportunity_id, label, units, cost_basis, current_value, currency, acquired_at
)
SELECT
  'f2000000-0000-4000-8000-000000000002',
  'e2000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000002',
  'Harbour View tranche A',
  1,
  250000000,
  275000000,
  'NGN',
  now() - interval '60 days'
WHERE NOT EXISTS (
  SELECT 1 FROM public.portfolio_holdings h WHERE h.id = 'f2000000-0000-4000-8000-000000000002'
);

INSERT INTO public.investor_wallets (investor_id, currency, available_balance, pending_balance, reserved_balance)
VALUES
  ('b2000000-0000-4000-8000-000000000001', 'NGN', 18500000, 2500000, 5000000),
  ('b2000000-0000-4000-8000-000000000002', 'NGN', 42000000, 0, 10000000),
  ('b2000000-0000-4000-8000-000000000003', 'NGN', 3200000, 1500000, 0)
ON CONFLICT (investor_id) DO UPDATE SET
  available_balance = EXCLUDED.available_balance,
  pending_balance = EXCLUDED.pending_balance,
  reserved_balance = EXCLUDED.reserved_balance,
  updated_at = now();

INSERT INTO public.investment_distributions (
  id, investor_id, opportunity_id, portfolio_id, amount, currency, status,
  distribution_type, scheduled_at, paid_at, reference, notes
)
SELECT
  'a1200000-0000-4000-8000-000000000001',
  'b2000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000002',
  'e2000000-0000-4000-8000-000000000002',
  12500000,
  'NGN',
  'paid',
  'dividend',
  now() - interval '20 days',
  now() - interval '18 days',
  'DIST-HV-001',
  'Q1 tranche dividend'
WHERE NOT EXISTS (
  SELECT 1 FROM public.investment_distributions d WHERE d.id = 'a1200000-0000-4000-8000-000000000001'
);

INSERT INTO public.investment_distributions (
  id, investor_id, opportunity_id, portfolio_id, amount, currency, status,
  distribution_type, scheduled_at, reference, notes
)
SELECT
  'a1200000-0000-4000-8000-000000000002',
  'b2000000-0000-4000-8000-000000000001',
  'c2000000-0000-4000-8000-000000000001',
  'e2000000-0000-4000-8000-000000000001',
  4800000,
  'NGN',
  'scheduled',
  'dividend',
  now() + interval '12 days',
  'DIST-VC-002',
  'Upcoming projected payout (estimate)'
WHERE NOT EXISTS (
  SELECT 1 FROM public.investment_distributions d WHERE d.id = 'a1200000-0000-4000-8000-000000000002'
);

INSERT INTO public.investment_distributions (
  id, investor_id, opportunity_id, portfolio_id, amount, currency, status,
  distribution_type, scheduled_at, reference
)
SELECT
  'a1200000-0000-4000-8000-000000000003',
  'b2000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000002',
  'e2000000-0000-4000-8000-000000000002',
  12500000,
  'NGN',
  'scheduled',
  'dividend',
  now() + interval '25 days',
  'DIST-HV-002'
WHERE NOT EXISTS (
  SELECT 1 FROM public.investment_distributions d WHERE d.id = 'a1200000-0000-4000-8000-000000000003'
);

INSERT INTO public.investment_transactions (
  id, investor_id, opportunity_id, transaction_type, amount, investment_amount,
  currency, transaction_date, reference, description, direction, status, metadata
)
SELECT
  'a2200000-0000-4000-8000-000000000001',
  'b2000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000002',
  'commitment_funding',
  250000000,
  250000000,
  'NGN',
  now() - interval '60 days',
  'TXN-MER-001',
  'Harbour View tranche funding',
  'in',
  'active',
  '{"demo":true}'::jsonb
WHERE NOT EXISTS (
  SELECT 1 FROM public.investment_transactions t WHERE t.id = 'a2200000-0000-4000-8000-000000000001'
);

INSERT INTO public.investor_activity_logs (
  id, investor_id, event_type, title, description, occurred_at
)
SELECT * FROM (VALUES
  ('a3200000-0000-4000-8000-000000000001'::uuid, 'b2000000-0000-4000-8000-000000000001'::uuid, 'commitment', 'VIP commitment confirmed', '₦75M reserved on Victoria Crest raise', now() - interval '7 days'),
  ('a3200000-0000-4000-8000-000000000002'::uuid, 'b2000000-0000-4000-8000-000000000002'::uuid, 'distribution', 'Dividend paid', 'Harbour View Q1 dividend settled', now() - interval '18 days'),
  ('a3200000-0000-4000-8000-000000000003'::uuid, 'b2000000-0000-4000-8000-000000000003'::uuid, 'kyc', 'KYC documents requested', 'Awaiting utility bill and BVN proof', now() - interval '1 day'),
  ('a3200000-0000-4000-8000-000000000004'::uuid, 'b2000000-0000-4000-8000-000000000001'::uuid, 'alert', 'Upcoming payout reminder', 'Scheduled distribution in 12 days', now() - interval '2 hours')
) AS v(id, investor_id, event_type, title, description, occurred_at)
WHERE NOT EXISTS (
  SELECT 1 FROM public.investor_activity_logs a WHERE a.id = v.id
);

INSERT INTO public.investor_alerts (
  id, investor_id, opportunity_id, severity, title, body, status
)
SELECT
  'a4200000-0000-4000-8000-000000000001',
  'b2000000-0000-4000-8000-000000000003',
  NULL,
  'high',
  'KYC stalled — first-time investor',
  'Tunde Bakare awaiting documents for 48h+. Assign onboarding specialist.',
  'open'
WHERE NOT EXISTS (SELECT 1 FROM public.investor_alerts a WHERE a.id = 'a4200000-0000-4000-8000-000000000001');

INSERT INTO public.investor_alerts (
  id, investor_id, opportunity_id, severity, title, body, status
)
SELECT
  'a4200000-0000-4000-8000-000000000002',
  'b2000000-0000-4000-8000-000000000001',
  'c2000000-0000-4000-8000-000000000001',
  'medium',
  'Capital raise pacing',
  'Victoria Crest open raise at ~38% of target. Engage VIP network this week.',
  'open'
WHERE NOT EXISTS (SELECT 1 FROM public.investor_alerts a WHERE a.id = 'a4200000-0000-4000-8000-000000000002');

INSERT INTO public.investor_alerts (
  id, investor_id, opportunity_id, severity, title, body, status
)
SELECT
  'a4200000-0000-4000-8000-000000000003',
  'b2000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000002',
  'info',
  'Institutional KYC review queued',
  'Meridian Equity under_review — finance pack attached.',
  'acknowledged'
WHERE NOT EXISTS (SELECT 1 FROM public.investor_alerts a WHERE a.id = 'a4200000-0000-4000-8000-000000000003');

INSERT INTO public.investor_kyc_reviews (
  id, investor_id, status, notes, risk_flags, reviewed_at
)
SELECT
  'a5200000-0000-4000-8000-000000000001',
  'b2000000-0000-4000-8000-000000000001',
  'approved',
  'HNWI KYC cleared with source-of-funds attestation.',
  ARRAY[]::text[],
  now() - interval '40 days'
WHERE NOT EXISTS (SELECT 1 FROM public.investor_kyc_reviews r WHERE r.id = 'a5200000-0000-4000-8000-000000000001');

INSERT INTO public.investor_kyc_reviews (
  id, investor_id, status, notes, risk_flags
)
SELECT
  'a5200000-0000-4000-8000-000000000002',
  'b2000000-0000-4000-8000-000000000002',
  'under_review',
  'Institutional UBO schedule pending.',
  ARRAY['ubo_pending']
WHERE NOT EXISTS (SELECT 1 FROM public.investor_kyc_reviews r WHERE r.id = 'a5200000-0000-4000-8000-000000000002');

INSERT INTO public.investor_kyc_reviews (
  id, investor_id, status, notes, risk_flags
)
SELECT
  'a5200000-0000-4000-8000-000000000003',
  'b2000000-0000-4000-8000-000000000003',
  'awaiting_documents',
  'Missing proof of address.',
  ARRAY['missing_poa']
WHERE NOT EXISTS (SELECT 1 FROM public.investor_kyc_reviews r WHERE r.id = 'a5200000-0000-4000-8000-000000000003');

INSERT INTO public.investment_performance (
  investor_id, portfolio_id, as_of_date, nav, twr_pct, irr_pct, yield_pct, currency, breakdown
) VALUES
  ('b2000000-0000-4000-8000-000000000001', 'e2000000-0000-4000-8000-000000000001', CURRENT_DATE, 420000000, 9.40, 11.20, 8.10, 'NGN', '{"demo":true}'::jsonb),
  ('b2000000-0000-4000-8000-000000000002', 'e2000000-0000-4000-8000-000000000002', CURRENT_DATE, 980000000, 8.20, 10.50, 7.60, 'NGN', '{"demo":true}'::jsonb);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.investors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_tag_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investment_opportunities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investment_commitments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_portfolios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.portfolio_holdings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investment_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investment_distributions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_bank_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_statements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_relationships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investment_performance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_kyc_reviews ENABLE ROW LEVEL SECURITY;

-- Replace legacy investor staff policies with permission-scoped ones
DROP POLICY IF EXISTS investors_own ON public.investors;
DROP POLICY IF EXISTS investors_staff ON public.investors;
DROP POLICY IF EXISTS portfolios_own ON public.investment_portfolios;
DROP POLICY IF EXISTS portfolios_staff ON public.investment_portfolios;

CREATE POLICY investors_select ON public.investors FOR SELECT
  USING (
    public.has_permission('investors.read', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR user_id = auth.uid()
  );
CREATE POLICY investors_write ON public.investors FOR ALL
  USING (
    public.has_permission('investors.write', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('investors.write', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

CREATE POLICY investor_profiles_select ON public.investor_profiles FOR SELECT
  USING (public.has_permission('investors.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY investor_profiles_write ON public.investor_profiles FOR ALL
  USING (public.has_permission('investors.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('investors.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

CREATE POLICY investor_preferences_select ON public.investor_preferences FOR SELECT
  USING (public.has_permission('investors.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY investor_preferences_write ON public.investor_preferences FOR ALL
  USING (public.has_permission('investors.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('investors.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

CREATE POLICY investor_tags_select ON public.investor_tags FOR SELECT
  USING (public.has_permission('investors.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY investor_tags_write ON public.investor_tags FOR ALL
  USING (public.has_permission('investors.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('investors.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

CREATE POLICY investor_tag_assignments_select ON public.investor_tag_assignments FOR SELECT
  USING (public.has_permission('investors.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY investor_tag_assignments_write ON public.investor_tag_assignments FOR ALL
  USING (public.has_permission('investors.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('investors.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

CREATE POLICY investment_opportunities_select ON public.investment_opportunities FOR SELECT
  USING (
    public.has_permission('investors.read', auth.uid())
    OR public.has_permission('investors.opportunities', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY investment_opportunities_write ON public.investment_opportunities FOR ALL
  USING (public.has_permission('investors.opportunities', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('investors.opportunities', auth.uid()) OR public.has_role('super_admin', auth.uid()));

CREATE POLICY investment_commitments_select ON public.investment_commitments FOR SELECT
  USING (
    public.has_permission('investors.read', auth.uid())
    OR public.has_permission('investors.opportunities', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY investment_commitments_write ON public.investment_commitments FOR ALL
  USING (
    public.has_permission('investors.write', auth.uid())
    OR public.has_permission('investors.opportunities', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('investors.write', auth.uid())
    OR public.has_permission('investors.opportunities', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

CREATE POLICY investor_portfolios_select ON public.investor_portfolios FOR SELECT
  USING (
    public.has_permission('investors.read', auth.uid())
    OR public.has_permission('investors.portfolio', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY investor_portfolios_write ON public.investor_portfolios FOR ALL
  USING (public.has_permission('investors.portfolio', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('investors.portfolio', auth.uid()) OR public.has_role('super_admin', auth.uid()));

CREATE POLICY portfolio_holdings_select ON public.portfolio_holdings FOR SELECT
  USING (
    public.has_permission('investors.read', auth.uid())
    OR public.has_permission('investors.portfolio', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY portfolio_holdings_write ON public.portfolio_holdings FOR ALL
  USING (public.has_permission('investors.portfolio', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('investors.portfolio', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS investment_transactions_select ON public.investment_transactions;
DROP POLICY IF EXISTS investment_transactions_write ON public.investment_transactions;
CREATE POLICY investment_transactions_select ON public.investment_transactions FOR SELECT
  USING (
    public.has_permission('investors.read', auth.uid())
    OR public.has_permission('investors.portfolio', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY investment_transactions_write ON public.investment_transactions FOR ALL
  USING (
    public.has_permission('investors.portfolio', auth.uid())
    OR public.has_permission('investors.distributions', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('investors.portfolio', auth.uid())
    OR public.has_permission('investors.distributions', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

CREATE POLICY investment_distributions_select ON public.investment_distributions FOR SELECT
  USING (
    public.has_permission('investors.read', auth.uid())
    OR public.has_permission('investors.distributions', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY investment_distributions_write ON public.investment_distributions FOR ALL
  USING (public.has_permission('investors.distributions', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('investors.distributions', auth.uid()) OR public.has_role('super_admin', auth.uid()));

CREATE POLICY investor_wallets_select ON public.investor_wallets FOR SELECT
  USING (
    public.has_permission('investors.read', auth.uid())
    OR public.has_permission('investors.portfolio', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY investor_wallets_write ON public.investor_wallets FOR ALL
  USING (
    public.has_permission('investors.portfolio', auth.uid())
    OR public.has_permission('investors.distributions', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('investors.portfolio', auth.uid())
    OR public.has_permission('investors.distributions', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

CREATE POLICY investor_bank_accounts_select ON public.investor_bank_accounts FOR SELECT
  USING (
    public.has_permission('investors.read', auth.uid())
    OR public.has_permission('investors.documents', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY investor_bank_accounts_write ON public.investor_bank_accounts FOR ALL
  USING (public.has_permission('investors.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('investors.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

CREATE POLICY investor_documents_select ON public.investor_documents FOR SELECT
  USING (
    public.has_permission('investors.read', auth.uid())
    OR public.has_permission('investors.documents', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY investor_documents_write ON public.investor_documents FOR ALL
  USING (public.has_permission('investors.documents', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('investors.documents', auth.uid()) OR public.has_role('super_admin', auth.uid()));

CREATE POLICY investor_statements_select ON public.investor_statements FOR SELECT
  USING (
    public.has_permission('investors.read', auth.uid())
    OR public.has_permission('investors.documents', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY investor_statements_write ON public.investor_statements FOR ALL
  USING (public.has_permission('investors.documents', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('investors.documents', auth.uid()) OR public.has_role('super_admin', auth.uid()));

CREATE POLICY investor_reports_select ON public.investor_reports FOR SELECT
  USING (
    public.has_permission('investors.read', auth.uid())
    OR public.has_permission('investors.analytics', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY investor_reports_write ON public.investor_reports FOR ALL
  USING (public.has_permission('investors.analytics', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('investors.analytics', auth.uid()) OR public.has_role('super_admin', auth.uid()));

CREATE POLICY investor_tasks_select ON public.investor_tasks FOR SELECT
  USING (public.has_permission('investors.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY investor_tasks_write ON public.investor_tasks FOR ALL
  USING (
    public.has_permission('investors.write', auth.uid())
    OR public.has_permission('investors.assign', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('investors.write', auth.uid())
    OR public.has_permission('investors.assign', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

CREATE POLICY investor_relationships_select ON public.investor_relationships FOR SELECT
  USING (public.has_permission('investors.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY investor_relationships_write ON public.investor_relationships FOR ALL
  USING (public.has_permission('investors.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('investors.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

CREATE POLICY investor_activity_logs_select ON public.investor_activity_logs FOR SELECT
  USING (public.has_permission('investors.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY investor_activity_logs_write ON public.investor_activity_logs FOR ALL
  USING (public.has_permission('investors.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('investors.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

CREATE POLICY investor_notifications_select ON public.investor_notifications FOR SELECT
  USING (public.has_permission('investors.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY investor_notifications_write ON public.investor_notifications FOR ALL
  USING (public.has_permission('investors.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('investors.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

CREATE POLICY investor_alerts_select ON public.investor_alerts FOR SELECT
  USING (
    public.has_permission('investors.read', auth.uid())
    OR public.has_permission('investors.analytics', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY investor_alerts_write ON public.investor_alerts FOR ALL
  USING (public.has_permission('investors.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('investors.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

CREATE POLICY investment_performance_select ON public.investment_performance FOR SELECT
  USING (
    public.has_permission('investors.read', auth.uid())
    OR public.has_permission('investors.analytics', auth.uid())
    OR public.has_permission('investors.portfolio', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY investment_performance_write ON public.investment_performance FOR ALL
  USING (public.has_permission('investors.analytics', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('investors.analytics', auth.uid()) OR public.has_role('super_admin', auth.uid()));

CREATE POLICY investor_kyc_reviews_select ON public.investor_kyc_reviews FOR SELECT
  USING (
    public.has_permission('investors.read', auth.uid())
    OR public.has_permission('investors.kyc', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY investor_kyc_reviews_write ON public.investor_kyc_reviews FOR ALL
  USING (public.has_permission('investors.kyc', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('investors.kyc', auth.uid()) OR public.has_role('super_admin', auth.uid()));

-- Legacy investment_portfolios permission bridge
CREATE POLICY investment_portfolios_select ON public.investment_portfolios FOR SELECT
  USING (
    public.has_permission('investors.read', auth.uid())
    OR public.has_permission('investors.portfolio', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR EXISTS (SELECT 1 FROM public.investors i WHERE i.id = investor_id AND i.user_id = auth.uid())
  );
CREATE POLICY investment_portfolios_write ON public.investment_portfolios FOR ALL
  USING (public.has_permission('investors.portfolio', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('investors.portfolio', auth.uid()) OR public.has_role('super_admin', auth.uid()));

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'investors',
    'investment_opportunities',
    'investment_commitments',
    'investment_distributions',
    'investor_wallets',
    'investor_activity_logs',
    'investor_alerts'
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

-- Status: LOCAL ONLY — await approve before remote SQL apply.

-- Status: APPLIED remotely 2026-07-14 (chunked apply_migration p1–p3).
