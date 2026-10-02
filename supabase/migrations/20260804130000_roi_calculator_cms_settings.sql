-- ROI calculator CMS settings (singleton)
CREATE TABLE IF NOT EXISTS public.roi_calculator_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  is_enabled BOOLEAN NOT NULL DEFAULT true,
  overline TEXT NOT NULL DEFAULT 'INVESTOR TOOLS',
  title TEXT NOT NULL DEFAULT 'ROI calculator',
  subtitle TEXT NOT NULL DEFAULT 'Project returns on your HD Homes investment.',
  inputs_title TEXT NOT NULL DEFAULT 'Investment inputs',
  inputs_subtitle TEXT NOT NULL DEFAULT 'Adjust the values to see your projected returns.',
  results_title TEXT NOT NULL DEFAULT 'Projected returns',
  info_text TEXT NOT NULL DEFAULT 'Adjust the inputs to see your projected returns in real time.',
  disclaimer_text TEXT NOT NULL DEFAULT 'Estimated values based on current investment assumptions. Returns are projections and not guaranteed.',
  cta_label TEXT NOT NULL DEFAULT 'Explore Investments',
  cta_path TEXT NOT NULL DEFAULT '/investments',
  currency_symbol TEXT NOT NULL DEFAULT '₦',
  currency_code TEXT NOT NULL DEFAULT 'NGN',
  compounding_method TEXT NOT NULL DEFAULT 'compound',
  amount_min NUMERIC NOT NULL DEFAULT 1000000,
  amount_max NUMERIC NOT NULL DEFAULT 100000000,
  amount_default NUMERIC NOT NULL DEFAULT 5000000,
  growth_min NUMERIC NOT NULL DEFAULT 1,
  growth_max NUMERIC NOT NULL DEFAULT 30,
  growth_default NUMERIC NOT NULL DEFAULT 15,
  years_min NUMERIC NOT NULL DEFAULT 1,
  years_max NUMERIC NOT NULL DEFAULT 10,
  years_default NUMERIC NOT NULL DEFAULT 3,
  show_chart BOOLEAN NOT NULL DEFAULT true,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT roi_calculator_compounding_chk
    CHECK (compounding_method IN ('compound', 'simple'))
);

ALTER TABLE public.roi_calculator_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS roi_calculator_settings_public_read ON public.roi_calculator_settings;
CREATE POLICY roi_calculator_settings_public_read ON public.roi_calculator_settings
  FOR SELECT USING (true);

DROP POLICY IF EXISTS roi_calculator_settings_staff ON public.roi_calculator_settings;
CREATE POLICY roi_calculator_settings_staff ON public.roi_calculator_settings
  FOR ALL USING (public.has_permission('manage_marketing'))
  WITH CHECK (public.has_permission('manage_marketing'));

INSERT INTO public.roi_calculator_settings (
  overline, title, subtitle, inputs_title, inputs_subtitle, results_title,
  info_text, disclaimer_text, cta_label, cta_path,
  currency_symbol, currency_code, compounding_method,
  amount_min, amount_max, amount_default,
  growth_min, growth_max, growth_default,
  years_min, years_max, years_default, show_chart, is_enabled
)
SELECT
  'INVESTOR TOOLS',
  'ROI calculator',
  'Project returns on your HD Homes investment.',
  'Investment inputs',
  'Adjust the values to see your projected returns.',
  'Projected returns',
  'Adjust the inputs to see your projected returns in real time.',
  'Estimated values based on current investment assumptions. Returns are projections and not guaranteed.',
  'Explore Investments',
  '/investments',
  '₦',
  'NGN',
  'compound',
  1000000,
  100000000,
  5000000,
  1,
  30,
  15,
  1,
  10,
  3,
  true,
  true
WHERE NOT EXISTS (SELECT 1 FROM public.roi_calculator_settings LIMIT 1);
