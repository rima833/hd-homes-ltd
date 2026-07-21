-- Volume 4 Part 7 — Enterprise Finance, Accounting & Payment Management System (FAPMS)
-- Status: APPLIED remotely 2026-07-14 (chunked p1–p3b).
--
-- Approach:
--   • Do NOT recreate legacy payments / commissions / sales_installments / sales_payment_plans.
--   • Enrich payments (+ invoices) via ALTER ADD COLUMN IF NOT EXISTS.
--   • Prefer finance_receipts (legacy receipts table remains untouched).
--   • chart_of_accounts is the primary COA catalog; general_ledger_accounts is a compatibility VIEW.
--   • Seed UUIDs are hex-only (0-9a-f).
--   • RLS: has_permission('slug', auth.uid()) — slug FIRST.

BEGIN;

-- ---------------------------------------------------------------------------
-- Permissions (NO action column — slug, name, description, module only)
-- ---------------------------------------------------------------------------
INSERT INTO public.permissions (slug, name, description, module) VALUES
  ('finance.read', 'View Finance', 'View Finance Command Center and financial records', 'finance'),
  ('finance.write', 'Manage Finance', 'Create and edit finance operational records', 'finance'),
  ('finance.ledger', 'General Ledger', 'Post and review journal entries and COA', 'finance'),
  ('finance.invoices', 'Manage Invoices', 'Create and manage invoices and items', 'finance'),
  ('finance.payments', 'Manage Payments', 'Record payments, gateways, and receipts', 'finance'),
  ('finance.banking', 'Banking & Reconciliation', 'Bank accounts, transactions, reconciliations', 'finance'),
  ('finance.budgets', 'Budgets', 'Create and track budgets and variances', 'finance'),
  ('finance.expenses', 'Expenses', 'Submit and manage expenses', 'finance'),
  ('finance.approvals', 'Finance Approvals', 'Approve expenses, journals, and payouts', 'finance'),
  ('finance.analytics', 'Finance Analytics', 'View KPIs, aging, cash-flow, and reports', 'finance'),
  ('finance.ai', 'AI Finance Assistant', 'Use AI financial briefing and anomaly stubs', 'finance'),
  ('finance.tax', 'Tax Management', 'Manage tax rates and tax transactions', 'finance')
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  module = EXCLUDED.module,
  updated_at = now();

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE p.slug LIKE 'finance.%'
  AND (
    r.slug IN ('super_admin', 'admin')
    OR (r.slug = 'finance' AND p.slug LIKE 'finance.%')
    OR (r.slug = 'sales_team' AND p.slug IN (
      'finance.read', 'finance.invoices', 'finance.payments', 'finance.analytics'
    ))
    OR (r.slug = 'construction_manager' AND p.slug IN (
      'finance.read', 'finance.expenses', 'finance.budgets', 'finance.analytics'
    ))
    OR (r.slug = 'marketing' AND p.slug IN (
      'finance.read', 'finance.analytics', 'finance.ai'
    ))
  )
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Enrich legacy payments (do not recreate)
-- ---------------------------------------------------------------------------
ALTER TABLE public.payments
  ADD COLUMN IF NOT EXISTS invoice_id uuid,
  ADD COLUMN IF NOT EXISTS bank_account_id uuid,
  ADD COLUMN IF NOT EXISTS gl_account_id uuid,
  ADD COLUMN IF NOT EXISTS notes text,
  ADD COLUMN IF NOT EXISTS reconciliation_status text DEFAULT 'unreconciled',
  ADD COLUMN IF NOT EXISTS finance_receipt_id uuid;

ALTER TABLE public.payments
  ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}'::jsonb;

-- Enrich legacy invoices (thin foundation table)
ALTER TABLE public.invoices
  ADD COLUMN IF NOT EXISTS party_name text,
  ADD COLUMN IF NOT EXISTS party_type text DEFAULT 'client',
  ADD COLUMN IF NOT EXISTS investor_id uuid,
  ADD COLUMN IF NOT EXISTS property_id uuid,
  ADD COLUMN IF NOT EXISTS sales_order_id uuid,
  ADD COLUMN IF NOT EXISTS issued_at date,
  ADD COLUMN IF NOT EXISTS paid_at timestamptz,
  ADD COLUMN IF NOT EXISTS subtotal numeric(16,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS tax_amount numeric(16,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS balance_due numeric(16,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS revenue_account_id uuid,
  ADD COLUMN IF NOT EXISTS notes text,
  ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}'::jsonb;

-- ---------------------------------------------------------------------------
-- Chart of accounts (primary) + GL alias view
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.chart_of_accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_code text NOT NULL UNIQUE,
  name text NOT NULL,
  account_type text NOT NULL
    CHECK (account_type IN ('asset','liability','equity','revenue','expense')),
  parent_id uuid REFERENCES public.chart_of_accounts(id) ON DELETE SET NULL,
  normal_balance text NOT NULL DEFAULT 'debit'
    CHECK (normal_balance IN ('debit','credit')),
  is_active boolean NOT NULL DEFAULT true,
  description text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_coa_type ON public.chart_of_accounts (account_type);

CREATE OR REPLACE VIEW public.general_ledger_accounts AS
SELECT * FROM public.chart_of_accounts;

CREATE TABLE IF NOT EXISTS public.accounting_periods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  period_start date NOT NULL,
  period_end date NOT NULL,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','closed','locked')),
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (period_start, period_end)
);

CREATE TABLE IF NOT EXISTS public.journal_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entry_number text NOT NULL UNIQUE,
  period_id uuid REFERENCES public.accounting_periods(id) ON DELETE SET NULL,
  entry_date date NOT NULL DEFAULT CURRENT_DATE,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','posted','void')),
  memo text,
  source_module text,
  source_ref text,
  posted_at timestamptz,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_journal_entries_date ON public.journal_entries (entry_date DESC);
CREATE INDEX IF NOT EXISTS idx_journal_entries_status ON public.journal_entries (status);

CREATE TABLE IF NOT EXISTS public.journal_entry_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  journal_entry_id uuid NOT NULL REFERENCES public.journal_entries(id) ON DELETE CASCADE,
  account_id uuid NOT NULL REFERENCES public.chart_of_accounts(id) ON DELETE RESTRICT,
  description text,
  debit numeric(16,2) NOT NULL DEFAULT 0,
  credit numeric(16,2) NOT NULL DEFAULT 0,
  sort_order int NOT NULL DEFAULT 0,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_journal_lines_entry ON public.journal_entry_lines (journal_entry_id);

-- ---------------------------------------------------------------------------
-- Invoices (enriched) + items
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.invoice_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id uuid NOT NULL REFERENCES public.invoices(id) ON DELETE CASCADE,
  description text NOT NULL,
  quantity numeric(12,2) NOT NULL DEFAULT 1,
  unit_price numeric(16,2) NOT NULL DEFAULT 0,
  line_total numeric(16,2) NOT NULL DEFAULT 0,
  tax_rate_pct numeric(5,2) DEFAULT 0,
  sort_order int NOT NULL DEFAULT 0,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_invoice_items_invoice ON public.invoice_items (invoice_id);

-- finance_receipts — prefer over legacy receipts (file stubs on payments)
CREATE TABLE IF NOT EXISTS public.finance_receipts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  receipt_number text NOT NULL UNIQUE,
  payment_id uuid REFERENCES public.payments(id) ON DELETE SET NULL,
  invoice_id uuid REFERENCES public.invoices(id) ON DELETE SET NULL,
  amount numeric(16,2) NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'NGN',
  issued_at timestamptz NOT NULL DEFAULT now(),
  payer_label text,
  method_label text,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Payment methods + gateway ledger
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payment_methods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  provider text,
  is_active boolean NOT NULL DEFAULT true,
  sort_order int NOT NULL DEFAULT 0,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.payment_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id uuid REFERENCES public.payments(id) ON DELETE SET NULL,
  invoice_id uuid REFERENCES public.invoices(id) ON DELETE SET NULL,
  method_id uuid REFERENCES public.payment_methods(id) ON DELETE SET NULL,
  provider text NOT NULL DEFAULT 'manual',
  provider_reference text,
  amount numeric(16,2) NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'NGN',
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','processing','succeeded','failed','refunded','cancelled')),
  direction text NOT NULL DEFAULT 'inbound'
    CHECK (direction IN ('inbound','outbound')),
  occurred_at timestamptz NOT NULL DEFAULT now(),
  failure_reason text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payment_transactions_status
  ON public.payment_transactions (status, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_payment
  ON public.payment_transactions (payment_id);

-- FAPMS installment bridge (sales_* already covers sales plans)
CREATE TABLE IF NOT EXISTS public.finance_installment_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_code text NOT NULL UNIQUE,
  invoice_id uuid REFERENCES public.invoices(id) ON DELETE SET NULL,
  client_label text,
  total_amount numeric(16,2) NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'NGN',
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft','active','completed','cancelled')),
  sales_payment_plan_id uuid,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.finance_installment_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid NOT NULL REFERENCES public.finance_installment_plans(id) ON DELETE CASCADE,
  installment_number int NOT NULL DEFAULT 1,
  amount numeric(16,2) NOT NULL DEFAULT 0,
  due_date date,
  paid_at timestamptz,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','paid','overdue','waived','cancelled')),
  payment_id uuid REFERENCES public.payments(id) ON DELETE SET NULL,
  sales_installment_id uuid,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Optional FKs to sales tables when present
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='sales_payment_plans') THEN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'finance_installment_plans_sales_plan_fkey') THEN
      ALTER TABLE public.finance_installment_plans
        ADD CONSTRAINT finance_installment_plans_sales_plan_fkey
        FOREIGN KEY (sales_payment_plan_id) REFERENCES public.sales_payment_plans(id) ON DELETE SET NULL;
    END IF;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='sales_installments') THEN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'finance_installment_payments_sales_inst_fkey') THEN
      ALTER TABLE public.finance_installment_payments
        ADD CONSTRAINT finance_installment_payments_sales_inst_fkey
        FOREIGN KEY (sales_installment_id) REFERENCES public.sales_installments(id) ON DELETE SET NULL;
    END IF;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Banking
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.bank_accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_name text NOT NULL,
  bank_name text NOT NULL,
  account_number_masked text,
  currency text NOT NULL DEFAULT 'NGN',
  gl_account_id uuid REFERENCES public.chart_of_accounts(id) ON DELETE SET NULL,
  balance numeric(16,2) NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.bank_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bank_account_id uuid NOT NULL REFERENCES public.bank_accounts(id) ON DELETE CASCADE,
  transaction_date date NOT NULL DEFAULT CURRENT_DATE,
  description text NOT NULL,
  amount numeric(16,2) NOT NULL DEFAULT 0,
  direction text NOT NULL DEFAULT 'credit'
    CHECK (direction IN ('debit','credit')),
  status text NOT NULL DEFAULT 'posted'
    CHECK (status IN ('pending','posted','reconciled','void')),
  payment_id uuid REFERENCES public.payments(id) ON DELETE SET NULL,
  payment_transaction_id uuid REFERENCES public.payment_transactions(id) ON DELETE SET NULL,
  reference text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_bank_transactions_account
  ON public.bank_transactions (bank_account_id, transaction_date DESC);

CREATE TABLE IF NOT EXISTS public.bank_reconciliations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bank_account_id uuid NOT NULL REFERENCES public.bank_accounts(id) ON DELETE CASCADE,
  period_start date NOT NULL,
  period_end date NOT NULL,
  statement_balance numeric(16,2) NOT NULL DEFAULT 0,
  book_balance numeric(16,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'in_progress'
    CHECK (status IN ('draft','in_progress','balanced','discrepancy')),
  notes text,
  completed_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Expenses & budgets
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.expense_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  gl_account_id uuid REFERENCES public.chart_of_accounts(id) ON DELETE SET NULL,
  is_active boolean NOT NULL DEFAULT true,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.expenses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  expense_code text NOT NULL UNIQUE,
  category_id uuid REFERENCES public.expense_categories(id) ON DELETE SET NULL,
  title text NOT NULL,
  amount numeric(16,2) NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'NGN',
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('draft','pending','approved','rejected','paid','cancelled')),
  incurred_at date NOT NULL DEFAULT CURRENT_DATE,
  vendor_label text,
  submitted_by_label text,
  approved_by_label text,
  gl_account_id uuid REFERENCES public.chart_of_accounts(id) ON DELETE SET NULL,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_expenses_status ON public.expenses (status);

CREATE TABLE IF NOT EXISTS public.budgets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  budget_code text NOT NULL UNIQUE,
  name text NOT NULL,
  period_id uuid REFERENCES public.accounting_periods(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft','active','closed','archived')),
  total_amount numeric(16,2) NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'NGN',
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.budget_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  budget_id uuid NOT NULL REFERENCES public.budgets(id) ON DELETE CASCADE,
  account_id uuid REFERENCES public.chart_of_accounts(id) ON DELETE SET NULL,
  category text NOT NULL,
  budgeted_amount numeric(16,2) NOT NULL DEFAULT 0,
  actual_amount numeric(16,2) NOT NULL DEFAULT 0,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.budget_variances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  budget_id uuid NOT NULL REFERENCES public.budgets(id) ON DELETE CASCADE,
  budget_line_id uuid REFERENCES public.budget_lines(id) ON DELETE SET NULL,
  category text NOT NULL,
  budgeted_amount numeric(16,2) NOT NULL DEFAULT 0,
  actual_amount numeric(16,2) NOT NULL DEFAULT 0,
  variance_amount numeric(16,2) NOT NULL DEFAULT 0,
  variance_pct numeric(8,2),
  severity text NOT NULL DEFAULT 'normal'
    CHECK (severity IN ('favorable','normal','watch','critical')),
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Tax
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.finance_taxes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  jurisdiction text DEFAULT 'NG',
  is_active boolean NOT NULL DEFAULT true,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.tax_rates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tax_id uuid NOT NULL REFERENCES public.finance_taxes(id) ON DELETE CASCADE,
  rate_pct numeric(8,4) NOT NULL DEFAULT 0,
  effective_from date NOT NULL DEFAULT CURRENT_DATE,
  effective_to date,
  is_active boolean NOT NULL DEFAULT true,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.tax_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tax_id uuid REFERENCES public.finance_taxes(id) ON DELETE SET NULL,
  invoice_id uuid REFERENCES public.invoices(id) ON DELETE SET NULL,
  payment_id uuid REFERENCES public.payments(id) ON DELETE SET NULL,
  taxable_amount numeric(16,2) NOT NULL DEFAULT 0,
  tax_amount numeric(16,2) NOT NULL DEFAULT 0,
  rate_pct numeric(8,4) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'recorded'
    CHECK (status IN ('recorded','remitted','adjusted','void')),
  occurred_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- AR / AP / reports / statements
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.accounts_receivable (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  party_name text NOT NULL,
  party_type text NOT NULL DEFAULT 'client',
  invoice_id uuid REFERENCES public.invoices(id) ON DELETE SET NULL,
  amount_due numeric(16,2) NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'NGN',
  due_date date,
  aging_bucket text NOT NULL DEFAULT 'current'
    CHECK (aging_bucket IN ('current','1_30','31_60','61_90','90_plus')),
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','partial','paid','written_off')),
  as_of_date date NOT NULL DEFAULT CURRENT_DATE,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.accounts_payable (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_name text NOT NULL,
  expense_id uuid REFERENCES public.expenses(id) ON DELETE SET NULL,
  amount_due numeric(16,2) NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'NGN',
  due_date date,
  aging_bucket text NOT NULL DEFAULT 'current'
    CHECK (aging_bucket IN ('current','1_30','31_60','61_90','90_plus')),
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','partial','paid','void')),
  as_of_date date NOT NULL DEFAULT CURRENT_DATE,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.financial_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  report_code text NOT NULL UNIQUE,
  title text NOT NULL,
  report_type text NOT NULL
    CHECK (report_type IN (
      'income_statement','balance_sheet','cash_flow','cash_flow_projection',
      'aging_ar','aging_ap','budget_variance','custom'
    )),
  period_id uuid REFERENCES public.accounting_periods(id) ON DELETE SET NULL,
  summary jsonb NOT NULL DEFAULT '{}'::jsonb,
  disclaimer text,
  generated_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.financial_statements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  statement_code text NOT NULL UNIQUE,
  title text NOT NULL,
  statement_type text NOT NULL
    CHECK (statement_type IN ('income','balance_sheet','cash_flow','equity')),
  period_id uuid REFERENCES public.accounting_periods(id) ON DELETE SET NULL,
  line_items jsonb NOT NULL DEFAULT '[]'::jsonb,
  is_projection boolean NOT NULL DEFAULT false,
  disclaimer text,
  as_of_date date NOT NULL DEFAULT CURRENT_DATE,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Commission payout ledger (leave legacy commissions alone)
CREATE TABLE IF NOT EXISTS public.commission_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payout_code text NOT NULL UNIQUE,
  salesperson_label text NOT NULL,
  amount numeric(16,2) NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'NGN',
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','approved','paid','cancelled')),
  commission_id uuid,
  payment_id uuid REFERENCES public.payments(id) ON DELETE SET NULL,
  paid_at timestamptz,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='commissions') THEN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'commission_payments_commission_fkey') THEN
      ALTER TABLE public.commission_payments
        ADD CONSTRAINT commission_payments_commission_fkey
        FOREIGN KEY (commission_id) REFERENCES public.commissions(id) ON DELETE SET NULL;
    END IF;
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.investor_financial_accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid,
  account_label text NOT NULL,
  gl_account_id uuid REFERENCES public.chart_of_accounts(id) ON DELETE SET NULL,
  balance numeric(16,2) NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'NGN',
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','frozen','closed')),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='investors') THEN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'investor_financial_accounts_investor_fkey') THEN
      ALTER TABLE public.investor_financial_accounts
        ADD CONSTRAINT investor_financial_accounts_investor_fkey
        FOREIGN KEY (investor_id) REFERENCES public.investors(id) ON DELETE SET NULL;
    END IF;
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.finance_activity_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  action text NOT NULL,
  entity_type text,
  entity_id uuid,
  summary text NOT NULL,
  actor_label text,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS public.finance_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  body text,
  severity text NOT NULL DEFAULT 'info'
    CHECK (severity IN ('info','warning','critical','success')),
  category text DEFAULT 'general',
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

-- Optional payment FKs once dependent tables exist
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'payments_invoice_id_fkey') THEN
    ALTER TABLE public.payments
      ADD CONSTRAINT payments_invoice_id_fkey
      FOREIGN KEY (invoice_id) REFERENCES public.invoices(id) ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'payments_bank_account_id_fkey') THEN
    ALTER TABLE public.payments
      ADD CONSTRAINT payments_bank_account_id_fkey
      FOREIGN KEY (bank_account_id) REFERENCES public.bank_accounts(id) ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'payments_gl_account_id_fkey') THEN
    ALTER TABLE public.payments
      ADD CONSTRAINT payments_gl_account_id_fkey
      FOREIGN KEY (gl_account_id) REFERENCES public.chart_of_accounts(id) ON DELETE SET NULL;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Seeds (hex-only UUIDs)
-- ---------------------------------------------------------------------------
INSERT INTO public.chart_of_accounts (id, account_code, name, account_type, normal_balance, description) VALUES
  ('f4700000-0000-4000-8000-000000000001', '1000', 'Cash & Bank', 'asset', 'debit', 'Operating cash'),
  ('f4700000-0000-4000-8000-000000000002', '1100', 'Accounts Receivable', 'asset', 'debit', 'Customer balances'),
  ('f4700000-0000-4000-8000-000000000003', '2000', 'Accounts Payable', 'liability', 'credit', 'Vendor balances'),
  ('f4700000-0000-4000-8000-000000000004', '2100', 'Investor Funds Held', 'liability', 'credit', 'Investor capital liability'),
  ('f4700000-0000-4000-8000-000000000005', '3000', 'Owner Equity', 'equity', 'credit', 'Retained / owner equity'),
  ('f4700000-0000-4000-8000-000000000006', '4000', 'Property Sales Revenue', 'revenue', 'credit', 'Unit / property revenue'),
  ('f4700000-0000-4000-8000-000000000007', '4100', 'Other Income', 'revenue', 'credit', 'Fees and other income'),
  ('f4700000-0000-4000-8000-000000000008', '5000', 'Operating Expenses', 'expense', 'debit', 'General operating spend'),
  ('f4700000-0000-4000-8000-000000000009', '5100', 'Construction Costs', 'expense', 'debit', 'Site and build costs'),
  ('f4700000-0000-4000-8000-00000000000a', '5200', 'Sales Commissions', 'expense', 'debit', 'Agent commission expense')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.accounting_periods (id, name, period_start, period_end, status, notes) VALUES
  ('f4700000-0000-4000-8000-000000000010', 'FY2026 Q3 Open', DATE '2026-07-01', DATE '2026-09-30', 'open', 'Primary open FAPMS period')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.payment_methods (id, slug, name, provider, sort_order) VALUES
  ('f4700000-0000-4000-8000-000000000020', 'paystack', 'Paystack', 'paystack', 1),
  ('f4700000-0000-4000-8000-000000000021', 'flutterwave', 'Flutterwave', 'flutterwave', 2),
  ('f4700000-0000-4000-8000-000000000022', 'bank_transfer', 'Bank Transfer', 'manual', 3)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.expense_categories (id, slug, name, gl_account_id) VALUES
  ('f4700000-0000-4000-8000-000000000030', 'site_materials', 'Site Materials', 'f4700000-0000-4000-8000-000000000009'),
  ('f4700000-0000-4000-8000-000000000031', 'marketing', 'Marketing', 'f4700000-0000-4000-8000-000000000008'),
  ('f4700000-0000-4000-8000-000000000032', 'professional_fees', 'Professional Fees', 'f4700000-0000-4000-8000-000000000008')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.finance_taxes (id, code, name, jurisdiction) VALUES
  ('f4700000-0000-4000-8000-000000000040', 'VAT', 'Value Added Tax', 'NG')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.tax_rates (id, tax_id, rate_pct, effective_from) VALUES
  ('f4700000-0000-4000-8000-000000000041', 'f4700000-0000-4000-8000-000000000040', 7.5, DATE '2026-01-01')
ON CONFLICT (id) DO NOTHING;

-- Bank account
INSERT INTO public.bank_accounts (
  id, account_name, bank_name, account_number_masked, currency, gl_account_id, balance
) VALUES (
  'f4700000-0000-4000-8000-000000000050',
  'HD Homes Operating',
  'Access Bank',
  '****8842',
  'NGN',
  'f4700000-0000-4000-8000-000000000001',
  428500000
) ON CONFLICT (id) DO NOTHING;

-- Invoices: paid + overdue + draft/open
INSERT INTO public.invoices (
  id, invoice_number, client_id, amount, currency, due_date, status,
  party_name, party_type, issued_at, paid_at, subtotal, tax_amount, balance_due,
  revenue_account_id, notes, metadata
) VALUES
(
  'f4700000-0000-4000-8000-000000000060',
  'INV-FAPMS-001',
  NULL,
  45000000,
  'NGN',
  CURRENT_DATE - 10,
  'paid',
  'Adaeze Okonkwo',
  'client',
  CURRENT_DATE - 40,
  now() - interval '12 days',
  41860465.12,
  3139534.88,
  0,
  'f4700000-0000-4000-8000-000000000006',
  'Paid villa deposit invoice',
  '{"demo":true,"story":"paid"}'::jsonb
),
(
  'f4700000-0000-4000-8000-000000000061',
  'INV-FAPMS-002',
  NULL,
  18500000,
  'NGN',
  CURRENT_DATE - 21,
  'overdue',
  'Chinedu Mensah',
  'client',
  CURRENT_DATE - 50,
  NULL,
  17209302.33,
  1290697.67,
  18500000,
  'f4700000-0000-4000-8000-000000000006',
  'Overdue installment invoice',
  '{"demo":true,"story":"overdue"}'::jsonb
),
(
  'f4700000-0000-4000-8000-000000000062',
  'INV-FAPMS-003',
  NULL,
  9200000,
  'NGN',
  CURRENT_DATE + 14,
  'sent',
  'Lekki Holdings Ltd',
  'client',
  CURRENT_DATE - 5,
  NULL,
  8558139.53,
  641860.47,
  9200000,
  'f4700000-0000-4000-8000-000000000006',
  'Open service invoice',
  '{"demo":true,"story":"open"}'::jsonb
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.invoice_items (id, invoice_id, description, quantity, unit_price, line_total, tax_rate_pct, sort_order) VALUES
  ('f4700000-0000-4000-8000-000000000070', 'f4700000-0000-4000-8000-000000000060', 'Victoria Crest — Unit deposit', 1, 41860465.12, 41860465.12, 7.5, 1),
  ('f4700000-0000-4000-8000-000000000071', 'f4700000-0000-4000-8000-000000000061', 'Installment 3 of 12', 1, 17209302.33, 17209302.33, 7.5, 1),
  ('f4700000-0000-4000-8000-000000000072', 'f4700000-0000-4000-8000-000000000062', 'Documentation & legal pack', 1, 8558139.53, 8558139.53, 7.5, 1)
ON CONFLICT (id) DO NOTHING;

-- Sample payments stubs (gateway references)
INSERT INTO public.payments (
  id, amount, currency, payment_method, payment_provider, provider_reference,
  paid_at, status, invoice_id, bank_account_id, gl_account_id, notes, metadata
) VALUES
(
  'f4700000-0000-4000-8000-000000000080',
  45000000, 'NGN', 'card', 'paystack', 'PSK-demo-001',
  now() - interval '12 days', 'completed',
  'f4700000-0000-4000-8000-000000000060',
  'f4700000-0000-4000-8000-000000000050',
  'f4700000-0000-4000-8000-000000000001',
  'Paystack card capture',
  '{"demo":true,"provider":"paystack"}'::jsonb
),
(
  'f4700000-0000-4000-8000-000000000081',
  5000000, 'NGN', 'bank_transfer', 'manual', 'BT-demo-8842',
  now() - interval '3 days', 'completed',
  NULL,
  'f4700000-0000-4000-8000-000000000050',
  'f4700000-0000-4000-8000-000000000001',
  'Manual bank transfer',
  '{"demo":true,"provider":"bank_transfer"}'::jsonb
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.payment_transactions (
  id, payment_id, invoice_id, method_id, provider, provider_reference,
  amount, currency, status, direction, occurred_at, metadata
) VALUES
(
  'f4700000-0000-4000-8000-000000000090',
  'f4700000-0000-4000-8000-000000000080',
  'f4700000-0000-4000-8000-000000000060',
  'f4700000-0000-4000-8000-000000000020',
  'paystack', 'PSK-demo-001',
  45000000, 'NGN', 'succeeded', 'inbound', now() - interval '12 days',
  '{"demo":true}'::jsonb
),
(
  'f4700000-0000-4000-8000-000000000091',
  NULL,
  'f4700000-0000-4000-8000-000000000061',
  'f4700000-0000-4000-8000-000000000021',
  'flutterwave', 'FLW-demo-pending',
  18500000, 'NGN', 'pending', 'inbound', now() - interval '1 day',
  '{"demo":true}'::jsonb
),
(
  'f4700000-0000-4000-8000-000000000092',
  'f4700000-0000-4000-8000-000000000081',
  NULL,
  'f4700000-0000-4000-8000-000000000022',
  'bank_transfer', 'BT-demo-8842',
  5000000, 'NGN', 'succeeded', 'inbound', now() - interval '3 days',
  '{"demo":true}'::jsonb
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.finance_receipts (
  id, receipt_number, payment_id, invoice_id, amount, currency, payer_label, method_label, notes
) VALUES
(
  'f4700000-0000-4000-8000-0000000000a0',
  'RCT-FAPMS-001',
  'f4700000-0000-4000-8000-000000000080',
  'f4700000-0000-4000-8000-000000000060',
  45000000, 'NGN', 'Adaeze Okonkwo', 'Paystack', 'Official receipt for INV-FAPMS-001'
),
(
  'f4700000-0000-4000-8000-0000000000a1',
  'RCT-FAPMS-002',
  'f4700000-0000-4000-8000-000000000081',
  NULL,
  5000000, 'NGN', 'Walk-in client', 'Bank Transfer', 'Miscellaneous receipt'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.journal_entries (
  id, entry_number, period_id, entry_date, status, memo, source_module, posted_at
) VALUES (
  'f4700000-0000-4000-8000-0000000000b0',
  'JE-2026-0001',
  'f4700000-0000-4000-8000-000000000010',
  CURRENT_DATE - 12,
  'posted',
  'Recognize Paystack receipt INV-FAPMS-001',
  'payments',
  now() - interval '12 days'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.journal_entry_lines (id, journal_entry_id, account_id, description, debit, credit, sort_order) VALUES
  ('f4700000-0000-4000-8000-0000000000b1', 'f4700000-0000-4000-8000-0000000000b0',
   'f4700000-0000-4000-8000-000000000001', 'Cash in', 45000000, 0, 1),
  ('f4700000-0000-4000-8000-0000000000b2', 'f4700000-0000-4000-8000-0000000000b0',
   'f4700000-0000-4000-8000-000000000002', 'Clear AR', 0, 45000000, 2)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.bank_transactions (
  id, bank_account_id, transaction_date, description, amount, direction, status, payment_id, reference
) VALUES
(
  'f4700000-0000-4000-8000-0000000000c0',
  'f4700000-0000-4000-8000-000000000050',
  CURRENT_DATE - 12, 'Paystack settlement INV-FAPMS-001', 45000000, 'credit', 'reconciled',
  'f4700000-0000-4000-8000-000000000080', 'PSK-demo-001'
),
(
  'f4700000-0000-4000-8000-0000000000c1',
  'f4700000-0000-4000-8000-000000000050',
  CURRENT_DATE - 3, 'Bank transfer receipt', 5000000, 'credit', 'posted',
  'f4700000-0000-4000-8000-000000000081', 'BT-demo-8842'
),
(
  'f4700000-0000-4000-8000-0000000000c2',
  'f4700000-0000-4000-8000-000000000050',
  CURRENT_DATE - 2, 'Site materials vendor payout', 8500000, 'debit', 'posted',
  NULL, 'AP-out-001'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.bank_reconciliations (
  id, bank_account_id, period_start, period_end, statement_balance, book_balance, status, notes
) VALUES (
  'f4700000-0000-4000-8000-0000000000c8',
  'f4700000-0000-4000-8000-000000000050',
  DATE '2026-07-01', CURRENT_DATE,
  428500000, 428500000, 'balanced', 'July operating account reconciliation'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.budgets (id, budget_code, name, period_id, status, total_amount, notes) VALUES (
  'f4700000-0000-4000-8000-0000000000d0',
  'BUD-FY26-Q3',
  'Q3 Operating Budget',
  'f4700000-0000-4000-8000-000000000010',
  'active',
  250000000,
  'Enterprise FAPMS demo budget'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.budget_lines (id, budget_id, account_id, category, budgeted_amount, actual_amount) VALUES
  ('f4700000-0000-4000-8000-0000000000d1', 'f4700000-0000-4000-8000-0000000000d0',
   'f4700000-0000-4000-8000-000000000008', 'Operating Expenses', 80000000, 62000000),
  ('f4700000-0000-4000-8000-0000000000d2', 'f4700000-0000-4000-8000-0000000000d0',
   'f4700000-0000-4000-8000-000000000009', 'Construction Costs', 140000000, 152000000),
  ('f4700000-0000-4000-8000-0000000000d3', 'f4700000-0000-4000-8000-0000000000d0',
   'f4700000-0000-4000-8000-00000000000a', 'Sales Commissions', 30000000, 18500000)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.budget_variances (
  id, budget_id, budget_line_id, category, budgeted_amount, actual_amount, variance_amount, variance_pct, severity, notes
) VALUES (
  'f4700000-0000-4000-8000-0000000000d8',
  'f4700000-0000-4000-8000-0000000000d0',
  'f4700000-0000-4000-8000-0000000000d2',
  'Construction Costs',
  140000000, 152000000, 12000000, 8.57, 'watch',
  'Construction spend ahead of plan — review change orders'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.expenses (
  id, expense_code, category_id, title, amount, currency, status, incurred_at,
  vendor_label, submitted_by_label, notes, metadata
) VALUES
(
  'f4700000-0000-4000-8000-0000000000e0',
  'EXP-FAPMS-001',
  'f4700000-0000-4000-8000-000000000030',
  'Block B rebar delivery',
  12500000, 'NGN', 'pending', CURRENT_DATE - 2,
  'SteelHub Lagos', 'Engr. Ngozi Eze',
  'Awaiting finance approval',
  '{"demo":true,"approval":"pending"}'::jsonb
),
(
  'f4700000-0000-4000-8000-0000000000e1',
  'EXP-FAPMS-002',
  'f4700000-0000-4000-8000-000000000031',
  'Q3 digital ads boost',
  3200000, 'NGN', 'pending', CURRENT_DATE - 1,
  'Meta Ads', 'Marketing Ops',
  'Campaign top-up pending approval',
  '{"demo":true,"approval":"pending"}'::jsonb
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.accounts_receivable (
  id, party_name, party_type, invoice_id, amount_due, due_date, aging_bucket, status, as_of_date
) VALUES
(
  'f4700000-0000-4000-8000-0000000000f0',
  'Chinedu Mensah', 'client',
  'f4700000-0000-4000-8000-000000000061',
  18500000, CURRENT_DATE - 21, '1_30', 'open', CURRENT_DATE
),
(
  'f4700000-0000-4000-8000-0000000000f1',
  'Lekki Holdings Ltd', 'client',
  'f4700000-0000-4000-8000-000000000062',
  9200000, CURRENT_DATE + 14, 'current', 'open', CURRENT_DATE
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.accounts_payable (
  id, vendor_name, expense_id, amount_due, due_date, aging_bucket, status, as_of_date
) VALUES
(
  'f4700000-0000-4000-8000-0000000000f8',
  'SteelHub Lagos',
  'f4700000-0000-4000-8000-0000000000e0',
  12500000, CURRENT_DATE + 7, 'current', 'open', CURRENT_DATE
),
(
  'f4700000-0000-4000-8000-0000000000f9',
  'Utility Co. Ajah',
  NULL,
  4800000, CURRENT_DATE - 40, '31_60', 'open', CURRENT_DATE
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.financial_reports (
  id, report_code, title, report_type, period_id, summary, disclaimer, generated_at
) VALUES (
  'f4700000-0000-4000-8000-000000000100',
  'CFR-PROJ-Q3',
  'Q3 Cash Flow Projection',
  'cash_flow_projection',
  'f4700000-0000-4000-8000-000000000010',
  '{"months":["Jul","Aug","Sep"],"inflows":[120000000,95000000,110000000],"outflows":[88000000,102000000,97000000],"net":[32000000,-7000000,13000000],"label":"PROJECTION"}'::jsonb,
  'PROJECTION — Cash flow figures are estimates only and are not guarantees of future liquidity or results.',
  now()
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.financial_statements (
  id, statement_code, title, statement_type, period_id, line_items, is_projection, disclaimer, as_of_date
) VALUES (
  'f4700000-0000-4000-8000-000000000108',
  'CFS-PROJ-90D',
  '90-Day Cash Flow Engine Projection',
  'cash_flow',
  'f4700000-0000-4000-8000-000000000010',
  '[
    {"label":"Week 1-4","inflow":45000000,"outflow":38000000,"net":7000000},
    {"label":"Week 5-8","inflow":52000000,"outflow":41000000,"net":11000000},
    {"label":"Week 9-12","inflow":48000000,"outflow":44000000,"net":4000000}
  ]'::jsonb,
  true,
  'PROJECTION — Estimates only; not a guarantee of cash availability.',
  CURRENT_DATE
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.commission_payments (
  id, payout_code, salesperson_label, amount, currency, status, notes
) VALUES (
  'f4700000-0000-4000-8000-000000000110',
  'CMP-FAPMS-001',
  'Tolu Adeyemi',
  2250000, 'NGN', 'pending', 'Pending CFO approval for Q3 payout'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.investor_financial_accounts (
  id, account_label, gl_account_id, balance, currency, status, metadata
) VALUES (
  'f4700000-0000-4000-8000-000000000118',
  'Investor pool — Victoria holdings',
  'f4700000-0000-4000-8000-000000000004',
  312000000, 'NGN', 'active',
  '{"demo":true}'::jsonb
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.finance_activity_logs (id, action, entity_type, entity_id, summary, actor_label, occurred_at) VALUES
  ('f4700000-0000-4000-8000-000000000120', 'payment.captured', 'payment',
   'f4700000-0000-4000-8000-000000000080', 'Paystack captured ₦45M for INV-FAPMS-001', 'System', now() - interval '12 days'),
  ('f4700000-0000-4000-8000-000000000121', 'expense.submitted', 'expense',
   'f4700000-0000-4000-8000-0000000000e0', 'Expense EXP-FAPMS-001 submitted for approval', 'Engr. Ngozi Eze', now() - interval '2 days'),
  ('f4700000-0000-4000-8000-000000000122', 'invoice.overdue', 'invoice',
   'f4700000-0000-4000-8000-000000000061', 'INV-FAPMS-002 marked overdue', 'Finance Bot', now() - interval '1 day')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.finance_notifications (id, title, body, severity, category) VALUES
  ('f4700000-0000-4000-8000-000000000128', 'Overdue invoice alert', 'INV-FAPMS-002 is 21+ days past due (₦18.5M).', 'warning', 'ar'),
  ('f4700000-0000-4000-8000-000000000129', 'Expense approval needed', 'Two expenses await finance approval.', 'info', 'approvals'),
  ('f4700000-0000-4000-8000-00000000012a', 'Budget watch', 'Construction Costs variance +8.6% vs plan.', 'warning', 'budgets')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.tax_transactions (
  id, tax_id, invoice_id, payment_id, taxable_amount, tax_amount, rate_pct, status
) VALUES (
  'f4700000-0000-4000-8000-000000000130',
  'f4700000-0000-4000-8000-000000000040',
  'f4700000-0000-4000-8000-000000000060',
  'f4700000-0000-4000-8000-000000000080',
  41860465.12, 3139534.88, 7.5, 'recorded'
) ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.chart_of_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.accounting_periods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journal_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journal_entry_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoice_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.finance_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.finance_installment_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.finance_installment_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bank_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bank_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bank_reconciliations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.budgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.budget_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.budget_variances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.finance_taxes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tax_rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tax_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.accounts_receivable ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.accounts_payable ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.financial_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.financial_statements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commission_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_financial_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.finance_activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.finance_notifications ENABLE ROW LEVEL SECURITY;

-- Helper policies: read via finance.read / domain slug; write via finance.write / domain

DROP POLICY IF EXISTS chart_of_accounts_select ON public.chart_of_accounts;
DROP POLICY IF EXISTS chart_of_accounts_write ON public.chart_of_accounts;
CREATE POLICY chart_of_accounts_select ON public.chart_of_accounts FOR SELECT
  USING (public.has_permission('finance.read', auth.uid()) OR public.has_permission('finance.ledger', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY chart_of_accounts_write ON public.chart_of_accounts FOR ALL
  USING (public.has_permission('finance.ledger', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('finance.ledger', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS accounting_periods_select ON public.accounting_periods;
DROP POLICY IF EXISTS accounting_periods_write ON public.accounting_periods;
CREATE POLICY accounting_periods_select ON public.accounting_periods FOR SELECT
  USING (public.has_permission('finance.read', auth.uid()) OR public.has_permission('finance.ledger', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY accounting_periods_write ON public.accounting_periods FOR ALL
  USING (public.has_permission('finance.ledger', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('finance.ledger', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS journal_entries_select ON public.journal_entries;
DROP POLICY IF EXISTS journal_entries_write ON public.journal_entries;
CREATE POLICY journal_entries_select ON public.journal_entries FOR SELECT
  USING (public.has_permission('finance.read', auth.uid()) OR public.has_permission('finance.ledger', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY journal_entries_write ON public.journal_entries FOR ALL
  USING (public.has_permission('finance.ledger', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('finance.ledger', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS journal_entry_lines_select ON public.journal_entry_lines;
DROP POLICY IF EXISTS journal_entry_lines_write ON public.journal_entry_lines;
CREATE POLICY journal_entry_lines_select ON public.journal_entry_lines FOR SELECT
  USING (public.has_permission('finance.read', auth.uid()) OR public.has_permission('finance.ledger', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY journal_entry_lines_write ON public.journal_entry_lines FOR ALL
  USING (public.has_permission('finance.ledger', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('finance.ledger', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS invoice_items_select ON public.invoice_items;
DROP POLICY IF EXISTS invoice_items_write ON public.invoice_items;
CREATE POLICY invoice_items_select ON public.invoice_items FOR SELECT
  USING (public.has_permission('finance.read', auth.uid()) OR public.has_permission('finance.invoices', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY invoice_items_write ON public.invoice_items FOR ALL
  USING (public.has_permission('finance.invoices', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('finance.invoices', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

-- Enrich policies for legacy invoices (staff finance.*)
DROP POLICY IF EXISTS invoices_finance_select ON public.invoices;
DROP POLICY IF EXISTS invoices_finance_write ON public.invoices;
CREATE POLICY invoices_finance_select ON public.invoices FOR SELECT
  USING (
    public.has_permission('finance.read', auth.uid())
    OR public.has_permission('finance.invoices', auth.uid())
    OR public.has_permission('manage_payments', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY invoices_finance_write ON public.invoices FOR ALL
  USING (
    public.has_permission('finance.invoices', auth.uid())
    OR public.has_permission('finance.write', auth.uid())
    OR public.has_permission('manage_payments', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('finance.invoices', auth.uid())
    OR public.has_permission('finance.write', auth.uid())
    OR public.has_permission('manage_payments', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

DROP POLICY IF EXISTS finance_receipts_select ON public.finance_receipts;
DROP POLICY IF EXISTS finance_receipts_write ON public.finance_receipts;
CREATE POLICY finance_receipts_select ON public.finance_receipts FOR SELECT
  USING (public.has_permission('finance.read', auth.uid()) OR public.has_permission('finance.payments', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY finance_receipts_write ON public.finance_receipts FOR ALL
  USING (public.has_permission('finance.payments', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('finance.payments', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS payment_methods_select ON public.payment_methods;
DROP POLICY IF EXISTS payment_methods_write ON public.payment_methods;
CREATE POLICY payment_methods_select ON public.payment_methods FOR SELECT
  USING (public.has_permission('finance.read', auth.uid()) OR public.has_permission('finance.payments', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY payment_methods_write ON public.payment_methods FOR ALL
  USING (public.has_permission('finance.payments', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('finance.payments', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS payment_transactions_select ON public.payment_transactions;
DROP POLICY IF EXISTS payment_transactions_write ON public.payment_transactions;
CREATE POLICY payment_transactions_select ON public.payment_transactions FOR SELECT
  USING (public.has_permission('finance.read', auth.uid()) OR public.has_permission('finance.payments', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY payment_transactions_write ON public.payment_transactions FOR ALL
  USING (public.has_permission('finance.payments', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('finance.payments', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS finance_installment_plans_select ON public.finance_installment_plans;
DROP POLICY IF EXISTS finance_installment_plans_write ON public.finance_installment_plans;
CREATE POLICY finance_installment_plans_select ON public.finance_installment_plans FOR SELECT
  USING (public.has_permission('finance.read', auth.uid()) OR public.has_permission('finance.payments', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY finance_installment_plans_write ON public.finance_installment_plans FOR ALL
  USING (public.has_permission('finance.payments', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('finance.payments', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS finance_installment_payments_select ON public.finance_installment_payments;
DROP POLICY IF EXISTS finance_installment_payments_write ON public.finance_installment_payments;
CREATE POLICY finance_installment_payments_select ON public.finance_installment_payments FOR SELECT
  USING (public.has_permission('finance.read', auth.uid()) OR public.has_permission('finance.payments', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY finance_installment_payments_write ON public.finance_installment_payments FOR ALL
  USING (public.has_permission('finance.payments', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('finance.payments', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS bank_accounts_select ON public.bank_accounts;
DROP POLICY IF EXISTS bank_accounts_write ON public.bank_accounts;
CREATE POLICY bank_accounts_select ON public.bank_accounts FOR SELECT
  USING (public.has_permission('finance.read', auth.uid()) OR public.has_permission('finance.banking', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY bank_accounts_write ON public.bank_accounts FOR ALL
  USING (public.has_permission('finance.banking', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('finance.banking', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS bank_transactions_select ON public.bank_transactions;
DROP POLICY IF EXISTS bank_transactions_write ON public.bank_transactions;
CREATE POLICY bank_transactions_select ON public.bank_transactions FOR SELECT
  USING (public.has_permission('finance.read', auth.uid()) OR public.has_permission('finance.banking', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY bank_transactions_write ON public.bank_transactions FOR ALL
  USING (public.has_permission('finance.banking', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('finance.banking', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS bank_reconciliations_select ON public.bank_reconciliations;
DROP POLICY IF EXISTS bank_reconciliations_write ON public.bank_reconciliations;
CREATE POLICY bank_reconciliations_select ON public.bank_reconciliations FOR SELECT
  USING (public.has_permission('finance.read', auth.uid()) OR public.has_permission('finance.banking', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY bank_reconciliations_write ON public.bank_reconciliations FOR ALL
  USING (public.has_permission('finance.banking', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('finance.banking', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS expense_categories_select ON public.expense_categories;
DROP POLICY IF EXISTS expense_categories_write ON public.expense_categories;
CREATE POLICY expense_categories_select ON public.expense_categories FOR SELECT
  USING (public.has_permission('finance.read', auth.uid()) OR public.has_permission('finance.expenses', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY expense_categories_write ON public.expense_categories FOR ALL
  USING (public.has_permission('finance.expenses', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('finance.expenses', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS expenses_select ON public.expenses;
DROP POLICY IF EXISTS expenses_write ON public.expenses;
CREATE POLICY expenses_select ON public.expenses FOR SELECT
  USING (public.has_permission('finance.read', auth.uid()) OR public.has_permission('finance.expenses', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY expenses_write ON public.expenses FOR ALL
  USING (
    public.has_permission('finance.expenses', auth.uid())
    OR public.has_permission('finance.approvals', auth.uid())
    OR public.has_permission('finance.write', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('finance.expenses', auth.uid())
    OR public.has_permission('finance.approvals', auth.uid())
    OR public.has_permission('finance.write', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

DROP POLICY IF EXISTS budgets_select ON public.budgets;
DROP POLICY IF EXISTS budgets_write ON public.budgets;
CREATE POLICY budgets_select ON public.budgets FOR SELECT
  USING (public.has_permission('finance.read', auth.uid()) OR public.has_permission('finance.budgets', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY budgets_write ON public.budgets FOR ALL
  USING (public.has_permission('finance.budgets', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('finance.budgets', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS budget_lines_select ON public.budget_lines;
DROP POLICY IF EXISTS budget_lines_write ON public.budget_lines;
CREATE POLICY budget_lines_select ON public.budget_lines FOR SELECT
  USING (public.has_permission('finance.read', auth.uid()) OR public.has_permission('finance.budgets', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY budget_lines_write ON public.budget_lines FOR ALL
  USING (public.has_permission('finance.budgets', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('finance.budgets', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS budget_variances_select ON public.budget_variances;
DROP POLICY IF EXISTS budget_variances_write ON public.budget_variances;
CREATE POLICY budget_variances_select ON public.budget_variances FOR SELECT
  USING (public.has_permission('finance.read', auth.uid()) OR public.has_permission('finance.budgets', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY budget_variances_write ON public.budget_variances FOR ALL
  USING (public.has_permission('finance.budgets', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('finance.budgets', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS finance_taxes_select ON public.finance_taxes;
DROP POLICY IF EXISTS finance_taxes_write ON public.finance_taxes;
CREATE POLICY finance_taxes_select ON public.finance_taxes FOR SELECT
  USING (public.has_permission('finance.read', auth.uid()) OR public.has_permission('finance.tax', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY finance_taxes_write ON public.finance_taxes FOR ALL
  USING (public.has_permission('finance.tax', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('finance.tax', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS tax_rates_select ON public.tax_rates;
DROP POLICY IF EXISTS tax_rates_write ON public.tax_rates;
CREATE POLICY tax_rates_select ON public.tax_rates FOR SELECT
  USING (public.has_permission('finance.read', auth.uid()) OR public.has_permission('finance.tax', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY tax_rates_write ON public.tax_rates FOR ALL
  USING (public.has_permission('finance.tax', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('finance.tax', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS tax_transactions_select ON public.tax_transactions;
DROP POLICY IF EXISTS tax_transactions_write ON public.tax_transactions;
CREATE POLICY tax_transactions_select ON public.tax_transactions FOR SELECT
  USING (public.has_permission('finance.read', auth.uid()) OR public.has_permission('finance.tax', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY tax_transactions_write ON public.tax_transactions FOR ALL
  USING (public.has_permission('finance.tax', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('finance.tax', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS accounts_receivable_select ON public.accounts_receivable;
DROP POLICY IF EXISTS accounts_receivable_write ON public.accounts_receivable;
CREATE POLICY accounts_receivable_select ON public.accounts_receivable FOR SELECT
  USING (public.has_permission('finance.read', auth.uid()) OR public.has_permission('finance.analytics', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY accounts_receivable_write ON public.accounts_receivable FOR ALL
  USING (public.has_permission('finance.write', auth.uid()) OR public.has_permission('finance.invoices', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('finance.write', auth.uid()) OR public.has_permission('finance.invoices', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS accounts_payable_select ON public.accounts_payable;
DROP POLICY IF EXISTS accounts_payable_write ON public.accounts_payable;
CREATE POLICY accounts_payable_select ON public.accounts_payable FOR SELECT
  USING (public.has_permission('finance.read', auth.uid()) OR public.has_permission('finance.analytics', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY accounts_payable_write ON public.accounts_payable FOR ALL
  USING (public.has_permission('finance.write', auth.uid()) OR public.has_permission('finance.expenses', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('finance.write', auth.uid()) OR public.has_permission('finance.expenses', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS financial_reports_select ON public.financial_reports;
DROP POLICY IF EXISTS financial_reports_write ON public.financial_reports;
CREATE POLICY financial_reports_select ON public.financial_reports FOR SELECT
  USING (public.has_permission('finance.read', auth.uid()) OR public.has_permission('finance.analytics', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY financial_reports_write ON public.financial_reports FOR ALL
  USING (public.has_permission('finance.analytics', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('finance.analytics', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS financial_statements_select ON public.financial_statements;
DROP POLICY IF EXISTS financial_statements_write ON public.financial_statements;
CREATE POLICY financial_statements_select ON public.financial_statements FOR SELECT
  USING (public.has_permission('finance.read', auth.uid()) OR public.has_permission('finance.analytics', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY financial_statements_write ON public.financial_statements FOR ALL
  USING (public.has_permission('finance.analytics', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('finance.analytics', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS commission_payments_select ON public.commission_payments;
DROP POLICY IF EXISTS commission_payments_write ON public.commission_payments;
CREATE POLICY commission_payments_select ON public.commission_payments FOR SELECT
  USING (public.has_permission('finance.read', auth.uid()) OR public.has_permission('finance.payments', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY commission_payments_write ON public.commission_payments FOR ALL
  USING (
    public.has_permission('finance.payments', auth.uid())
    OR public.has_permission('finance.approvals', auth.uid())
    OR public.has_permission('finance.write', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('finance.payments', auth.uid())
    OR public.has_permission('finance.approvals', auth.uid())
    OR public.has_permission('finance.write', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

DROP POLICY IF EXISTS investor_financial_accounts_select ON public.investor_financial_accounts;
DROP POLICY IF EXISTS investor_financial_accounts_write ON public.investor_financial_accounts;
CREATE POLICY investor_financial_accounts_select ON public.investor_financial_accounts FOR SELECT
  USING (public.has_permission('finance.read', auth.uid()) OR public.has_permission('finance.ledger', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY investor_financial_accounts_write ON public.investor_financial_accounts FOR ALL
  USING (public.has_permission('finance.ledger', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('finance.ledger', auth.uid()) OR public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS finance_activity_logs_select ON public.finance_activity_logs;
DROP POLICY IF EXISTS finance_activity_logs_write ON public.finance_activity_logs;
CREATE POLICY finance_activity_logs_select ON public.finance_activity_logs FOR SELECT
  USING (public.has_permission('finance.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY finance_activity_logs_write ON public.finance_activity_logs FOR ALL
  USING (public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS finance_notifications_select ON public.finance_notifications;
DROP POLICY IF EXISTS finance_notifications_write ON public.finance_notifications;
CREATE POLICY finance_notifications_select ON public.finance_notifications FOR SELECT
  USING (public.has_permission('finance.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY finance_notifications_write ON public.finance_notifications FOR ALL
  USING (public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('finance.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

-- Payments: add finance.* SELECT/ALL alongside existing manage_payments policies
DROP POLICY IF EXISTS payments_finance_select ON public.payments;
DROP POLICY IF EXISTS payments_finance_write ON public.payments;
CREATE POLICY payments_finance_select ON public.payments FOR SELECT
  USING (
    public.has_permission('finance.read', auth.uid())
    OR public.has_permission('finance.payments', auth.uid())
    OR public.has_permission('manage_payments', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY payments_finance_write ON public.payments FOR ALL
  USING (
    public.has_permission('finance.payments', auth.uid())
    OR public.has_permission('finance.write', auth.uid())
    OR public.has_permission('manage_payments', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('finance.payments', auth.uid())
    OR public.has_permission('finance.write', auth.uid())
    OR public.has_permission('manage_payments', auth.uid())
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
    'invoices',
    'payments',
    'payment_transactions',
    'expenses',
    'budgets',
    'bank_transactions',
    'journal_entries',
    'finance_activity_logs',
    'finance_notifications'
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

-- Status: APPLIED remotely 2026-07-14 (chunked apply_migration p1–p3b).
