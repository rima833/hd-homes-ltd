-- Investor portal: bank-transfer payment intents, receiving accounts,
-- construction milestones / photos / drone videos seed.

CREATE TABLE IF NOT EXISTS public.investment_receiving_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bank_name TEXT NOT NULL,
  account_name TEXT NOT NULL,
  account_number TEXT NOT NULL,
  sort_code TEXT,
  currency TEXT NOT NULL DEFAULT 'NGN',
  instructions TEXT,
  is_primary BOOLEAN NOT NULL DEFAULT false,
  is_active BOOLEAN NOT NULL DEFAULT true,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE IF NOT EXISTS public.investor_payment_intents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id UUID NOT NULL REFERENCES public.investors(id) ON DELETE CASCADE,
  amount NUMERIC(15,2) NOT NULL,
  currency TEXT NOT NULL DEFAULT 'NGN',
  provider TEXT NOT NULL DEFAULT 'bank_transfer',
  provider_reference TEXT,
  bank_reference TEXT,
  receiving_account_id UUID REFERENCES public.investment_receiving_accounts(id),
  notes TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  paid_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'pending',
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  CONSTRAINT investor_payment_intents_provider_check
    CHECK (provider = ANY (ARRAY['bank_transfer'::text, 'wallet'::text, 'other'::text])),
  CONSTRAINT investor_payment_intents_status_check
    CHECK (status = ANY (ARRAY['pending'::text, 'awaiting_confirmation'::text, 'confirmed'::text, 'failed'::text, 'cancelled'::text]))
);

CREATE INDEX IF NOT EXISTS idx_investor_payment_intents_investor
  ON public.investor_payment_intents(investor_id, created_at DESC);

ALTER TABLE public.investment_receiving_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_payment_intents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS investment_receiving_accounts_read ON public.investment_receiving_accounts;
CREATE POLICY investment_receiving_accounts_read ON public.investment_receiving_accounts
  FOR SELECT TO authenticated
  USING (is_active = true AND COALESCE(is_deleted, false) = false);

DROP POLICY IF EXISTS investor_payment_intents_own ON public.investor_payment_intents;
CREATE POLICY investor_payment_intents_own ON public.investor_payment_intents
  FOR ALL TO authenticated
  USING (investor_id = public.investor_id_for_user(auth.uid()) OR public.is_staff())
  WITH CHECK (investor_id = public.investor_id_for_user(auth.uid()) OR public.is_staff());

GRANT SELECT ON public.investment_receiving_accounts TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.investor_payment_intents TO authenticated;
