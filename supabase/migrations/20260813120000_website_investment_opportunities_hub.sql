-- Extend website investment opportunities for hub cards (location, ROI label, extra statuses).

ALTER TABLE public.website_investment_opportunities
  ADD COLUMN IF NOT EXISTS location text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS city text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS roi_label text NOT NULL DEFAULT '';

ALTER TABLE public.website_investment_opportunities
  DROP CONSTRAINT IF EXISTS website_investment_opportunities_opportunity_status_check;

ALTER TABLE public.website_investment_opportunities
  ADD CONSTRAINT website_investment_opportunities_opportunity_status_check
  CHECK (opportunity_status IN (
    'open', 'limited', 'closing_soon', 'coming_soon', 'closed', 'sold_out'
  ));

CREATE INDEX IF NOT EXISTS website_investment_opps_featured_sort_idx
  ON public.website_investment_opportunities (is_featured DESC, sort_order)
  WHERE COALESCE(is_deleted, false) = false AND status = 'active';

UPDATE public.website_investment_opportunities
SET location = CASE slug
      WHEN 'horizon-gardens-fund' THEN 'Lekki, Lagos'
      WHEN 'lagos-commercial-yield' THEN 'Lagos Island'
      ELSE location
    END,
    city = CASE slug
      WHEN 'horizon-gardens-fund' THEN 'Lagos'
      WHEN 'lagos-commercial-yield' THEN 'Lagos'
      ELSE city
    END,
    investment_type = CASE slug
      WHEN 'horizon-gardens-fund' THEN 'Off-Plan'
      WHEN 'lagos-commercial-yield' THEN 'Commercial'
      ELSE investment_type
    END,
    type_label = CASE slug
      WHEN 'horizon-gardens-fund' THEN 'Off-Plan'
      WHEN 'lagos-commercial-yield' THEN 'Commercial'
      ELSE type_label
    END
WHERE COALESCE(is_deleted, false) = false
  AND slug IN ('horizon-gardens-fund', 'lagos-commercial-yield');

INSERT INTO public.website_investment_opportunities (
  project_name, slug, short_description, full_description,
  investment_type, type_label, location, city,
  roi_min, roi_max, roi_label, duration, risk_level, growth_potential,
  minimum_investment, target_amount, amount_raised, progress_pct,
  opportunity_status, is_featured, cta_label, sort_order, status,
  cover_image_url
)
SELECT * FROM (VALUES
  (
    'Horizon Gardens — Phase 1',
    'horizon-gardens-phase-1',
    'Flagship lifestyle estate with strong rental demand and capital appreciation.',
    'A carefully phased residential estate in Lekki designed for capital growth and rental demand. Transparent reporting, escrow-backed milestones, and institutional-grade delivery.',
    'Off-Plan', 'Off-Plan', 'Lekki, Lagos', 'Lagos',
    18::numeric, 22::numeric, '', '3–5 years', 'Moderate', 'High',
    '₦15M', '₦2.5B', '₦1.8B', 72::numeric,
    'open', true, 'View Opportunity', 5, 'active',
    'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?auto=format&fit=crop&w=1400&q=80'
  ),
  (
    'Emerald Heights Estate',
    'emerald-heights-estate',
    'Premium Abuja development in a high-growth government corridor.',
    'Capital-growth estate in Abuja with strong long-term appreciation outlook and structured investor reporting.',
    'Capital Growth', 'Capital Growth', 'Abuja, FCT', 'Abuja',
    15::numeric, 18::numeric, '', '4–6 years', 'Low–Moderate', 'High',
    '₦20M', '₦1.8B', '₦920M', 51::numeric,
    'open', true, 'View Opportunity', 8, 'active',
    'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=1400&q=80'
  ),
  (
    'Lekki Rental Income Fund',
    'lekki-rental-income-fund',
    'Stabilized rental portfolio with quarterly distributions.',
    'Income-focused residential and mixed-use assets along the Lekki corridor, structured for recurring distributions.',
    'Rental Income', 'Rental Income', 'Lekki Corridor', 'Lagos',
    12::numeric, 14::numeric, 'yield', 'Ongoing', 'Low', 'Moderate',
    '₦10M', '₦1.2B', '₦980M', 82::numeric,
    'limited', false, 'View Opportunity', 15, 'active',
    'https://images.unsplash.com/photo-1560518883-ce09059eeffa?auto=format&fit=crop&w=1400&q=80'
  ),
  (
    'Green Valley Land Banking',
    'green-valley-land-banking',
    'Strategic land parcels in emerging growth corridors.',
    'Land banking product targeting emerging Port Harcourt growth corridors with medium-term capital appreciation.',
    'Land Banking', 'Land Banking', 'Port Harcourt', 'Port Harcourt',
    20::numeric, 25::numeric, '', '2–4 years', 'Moderate–High', 'High',
    '₦8M', '₦800M', '₦240M', 30::numeric,
    'open', false, 'View Opportunity', 18, 'active',
    'https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=1400&q=80'
  )
) AS v(
  project_name, slug, short_description, full_description,
  investment_type, type_label, location, city,
  roi_min, roi_max, roi_label, duration, risk_level, growth_potential,
  minimum_investment, target_amount, amount_raised, progress_pct,
  opportunity_status, is_featured, cta_label, sort_order, status,
  cover_image_url
)
WHERE NOT EXISTS (
  SELECT 1 FROM public.website_investment_opportunities e
  WHERE e.slug = v.slug AND COALESCE(e.is_deleted, false) = false
);

DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.website_investment_opportunities;
  EXCEPTION WHEN duplicate_object THEN
    NULL;
  END;
END $$;
