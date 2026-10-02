-- Public payment plan calculator CMS
CREATE TABLE IF NOT EXISTS public.calculator_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  overline TEXT NOT NULL DEFAULT 'PAYMENT PLANS',
  title TEXT NOT NULL DEFAULT 'Payment plan calculator',
  subtitle TEXT NOT NULL DEFAULT 'Estimate monthly installments for your dream home.',
  info_text TEXT NOT NULL DEFAULT 'Adjust the values to see how your monthly installment changes in real time.',
  apply_cta_label TEXT NOT NULL DEFAULT 'Apply for Plan',
  price_min NUMERIC NOT NULL DEFAULT 10000000,
  price_max NUMERIC NOT NULL DEFAULT 200000000,
  price_default NUMERIC NOT NULL DEFAULT 50000000,
  trust_items JSONB NOT NULL DEFAULT '[
    {"icon":"shield","label":"Secure Transactions"},
    {"icon":"percent","label":"Flexible Payment"},
    {"icon":"clock","label":"Quick Approval"},
    {"icon":"headset","label":"Dedicated Support"}
  ]'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.calculator_payment_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  is_global BOOLEAN NOT NULL DEFAULT true,
  interest_rate_default NUMERIC NOT NULL DEFAULT 12,
  interest_rate_min NUMERIC NOT NULL DEFAULT 0,
  interest_rate_max NUMERIC NOT NULL DEFAULT 30,
  duration_months_default INT NOT NULL DEFAULT 24,
  duration_months_min INT NOT NULL DEFAULT 6,
  duration_months_max INT NOT NULL DEFAULT 120,
  deposit_percent_min NUMERIC NOT NULL DEFAULT 10,
  deposit_percent_default NUMERIC NOT NULL DEFAULT 20,
  min_deposit_amount NUMERIC NOT NULL DEFAULT 1000000,
  max_deposit_amount NUMERIC,
  calculation_method TEXT NOT NULL DEFAULT 'reducing_balance',
  sort_order INT NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT calculator_payment_plans_method_chk
    CHECK (calculation_method IN ('reducing_balance', 'flat'))
);

CREATE TABLE IF NOT EXISTS public.calculator_plan_properties (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id UUID NOT NULL REFERENCES public.calculator_payment_plans(id) ON DELETE CASCADE,
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (plan_id, property_id)
);

CREATE TABLE IF NOT EXISTS public.calculator_applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id UUID REFERENCES public.calculator_payment_plans(id) ON DELETE SET NULL,
  property_id UUID REFERENCES public.properties(id) ON DELETE SET NULL,
  user_id UUID,
  full_name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT NOT NULL DEFAULT '',
  property_price NUMERIC NOT NULL,
  deposit_amount NUMERIC NOT NULL,
  duration_months INT NOT NULL,
  interest_rate NUMERIC NOT NULL,
  loan_amount NUMERIC NOT NULL,
  monthly_payment NUMERIC NOT NULL,
  total_repayment NUMERIC NOT NULL,
  total_interest NUMERIC NOT NULL,
  status TEXT NOT NULL DEFAULT 'new',
  notes TEXT NOT NULL DEFAULT '',
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS calculator_payment_plans_sort_idx
  ON public.calculator_payment_plans (sort_order)
  WHERE COALESCE(is_deleted, false) = false;
CREATE INDEX IF NOT EXISTS calculator_plan_properties_plan_idx
  ON public.calculator_plan_properties (plan_id);
CREATE INDEX IF NOT EXISTS calculator_plan_properties_property_idx
  ON public.calculator_plan_properties (property_id);
CREATE INDEX IF NOT EXISTS calculator_applications_created_idx
  ON public.calculator_applications (created_at DESC);

ALTER TABLE public.calculator_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.calculator_payment_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.calculator_plan_properties ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.calculator_applications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS calculator_settings_public_read ON public.calculator_settings;
CREATE POLICY calculator_settings_public_read ON public.calculator_settings
  FOR SELECT USING (true);
DROP POLICY IF EXISTS calculator_settings_staff ON public.calculator_settings;
CREATE POLICY calculator_settings_staff ON public.calculator_settings
  FOR ALL USING (public.has_permission('manage_marketing'))
  WITH CHECK (public.has_permission('manage_marketing'));

DROP POLICY IF EXISTS calculator_plans_public_read ON public.calculator_payment_plans;
CREATE POLICY calculator_plans_public_read ON public.calculator_payment_plans
  FOR SELECT USING (is_deleted = false AND status = 'active');
DROP POLICY IF EXISTS calculator_plans_staff ON public.calculator_payment_plans;
CREATE POLICY calculator_plans_staff ON public.calculator_payment_plans
  FOR ALL USING (public.has_permission('manage_marketing'))
  WITH CHECK (public.has_permission('manage_marketing'));

DROP POLICY IF EXISTS calculator_plan_properties_public_read ON public.calculator_plan_properties;
CREATE POLICY calculator_plan_properties_public_read ON public.calculator_plan_properties
  FOR SELECT USING (true);
DROP POLICY IF EXISTS calculator_plan_properties_staff ON public.calculator_plan_properties;
CREATE POLICY calculator_plan_properties_staff ON public.calculator_plan_properties
  FOR ALL USING (public.has_permission('manage_marketing'))
  WITH CHECK (public.has_permission('manage_marketing'));

DROP POLICY IF EXISTS calculator_applications_public_insert ON public.calculator_applications;
CREATE POLICY calculator_applications_public_insert ON public.calculator_applications
  FOR INSERT WITH CHECK (true);
DROP POLICY IF EXISTS calculator_applications_staff ON public.calculator_applications;
CREATE POLICY calculator_applications_staff ON public.calculator_applications
  FOR ALL USING (public.has_permission('manage_marketing'))
  WITH CHECK (public.has_permission('manage_marketing'));

INSERT INTO public.calculator_settings (
  overline, title, subtitle, info_text, apply_cta_label,
  price_min, price_max, price_default
)
SELECT
  'PAYMENT PLANS',
  'Payment plan calculator',
  'Estimate monthly installments for your dream home.',
  'Adjust the values to see how your monthly installment changes in real time.',
  'Apply for Plan',
  10000000, 200000000, 50000000
WHERE NOT EXISTS (SELECT 1 FROM public.calculator_settings);

INSERT INTO public.calculator_payment_plans (
  name, description, is_global,
  interest_rate_default, interest_rate_min, interest_rate_max,
  duration_months_default, duration_months_min, duration_months_max,
  deposit_percent_min, deposit_percent_default, min_deposit_amount,
  calculation_method, sort_order, status
)
SELECT
  'Flexible Home Plan',
  'Standard reducing-balance installment plan for residential purchases.',
  true,
  12, 0, 30,
  24, 6, 120,
  10, 20, 1000000,
  'reducing_balance', 10, 'active'
WHERE NOT EXISTS (
  SELECT 1 FROM public.calculator_payment_plans WHERE is_deleted = false
);
