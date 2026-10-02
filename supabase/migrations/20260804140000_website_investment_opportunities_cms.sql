-- Marketing CMS: website investment opportunities (homepage + hub cards)
-- Separate from IMP operational table `investment_opportunities`.
CREATE TABLE IF NOT EXISTS public.website_investment_opportunities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  cover_image_url TEXT,
  gallery_images JSONB NOT NULL DEFAULT '[]'::jsonb,
  short_description TEXT NOT NULL DEFAULT '',
  full_description TEXT NOT NULL DEFAULT '',
  investment_type TEXT NOT NULL DEFAULT 'Real Estate Fund',
  type_label TEXT NOT NULL DEFAULT 'Estate Development',
  roi_min NUMERIC(8,2) NOT NULL DEFAULT 0,
  roi_max NUMERIC(8,2) NOT NULL DEFAULT 0,
  duration TEXT NOT NULL DEFAULT '',
  risk_level TEXT NOT NULL DEFAULT 'Moderate',
  growth_potential TEXT NOT NULL DEFAULT 'High',
  minimum_investment TEXT NOT NULL DEFAULT '',
  target_amount TEXT NOT NULL DEFAULT '',
  amount_raised TEXT NOT NULL DEFAULT '',
  progress_pct NUMERIC(5,2) NOT NULL DEFAULT 0,
  opportunity_status TEXT NOT NULL DEFAULT 'open'
    CHECK (opportunity_status IN ('open', 'closing_soon', 'closed', 'coming_soon')),
  is_featured BOOLEAN NOT NULL DEFAULT false,
  featured_badge TEXT NOT NULL DEFAULT 'Featured',
  demand_badge TEXT,
  cta_label TEXT NOT NULL DEFAULT 'View Opportunity',
  cta_link TEXT,
  sort_order INT NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id)
);

CREATE INDEX IF NOT EXISTS website_investment_opps_sort_idx
  ON public.website_investment_opportunities (sort_order)
  WHERE COALESCE(is_deleted, false) = false;

CREATE INDEX IF NOT EXISTS website_investment_opps_slug_idx
  ON public.website_investment_opportunities (slug)
  WHERE COALESCE(is_deleted, false) = false;

ALTER TABLE public.website_investment_opportunities ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS website_investment_opps_public_read
  ON public.website_investment_opportunities;
CREATE POLICY website_investment_opps_public_read
  ON public.website_investment_opportunities
  FOR SELECT USING (
    COALESCE(is_deleted, false) = false AND status = 'active'
  );

DROP POLICY IF EXISTS website_investment_opps_staff
  ON public.website_investment_opportunities;
CREATE POLICY website_investment_opps_staff
  ON public.website_investment_opportunities
  FOR ALL USING (public.has_permission('manage_marketing'))
  WITH CHECK (public.has_permission('manage_marketing'));

INSERT INTO public.website_investment_opportunities (
  project_name, slug, short_description, full_description,
  investment_type, type_label, roi_min, roi_max, duration,
  risk_level, growth_potential, minimum_investment,
  target_amount, amount_raised, progress_pct, opportunity_status,
  is_featured, featured_badge, demand_badge, cta_label, sort_order, status
)
SELECT * FROM (VALUES
  (
    'Horizon Gardens Fund',
    'horizon-gardens-fund',
    'Premium residential estate investment with strong capital appreciation outlook.',
    'Invest in a carefully structured residential estate fund designed for capital growth and predictable returns. Horizon Gardens combines land banking upside with phased development milestones, transparent reporting, and asset-backed security.',
    'Real Estate Fund',
    'Estate Development',
    18::numeric, 22::numeric, '24 months',
    'Moderate', 'High', '₦5,000,000',
    '₦2.5B', '₦1.8B', 72::numeric, 'open',
    true, 'Featured', NULL, 'View Opportunity', 10, 'active'
  ),
  (
    'Lagos Commercial Yield',
    'lagos-commercial-yield',
    'Income-focused commercial assets in high-footfall Lagos corridors.',
    'A commercial yield product targeting premium retail and mixed-use assets in Lagos. Structured for recurring income with moderate risk and strong long-term growth potential for portfolio diversification.',
    'Commercial Fund',
    'Commercial Asset',
    14::numeric, 18::numeric, '36 months',
    'Moderate', 'High', '₦10,000,000',
    '₦1.2B', '₦980M', 82::numeric, 'closing_soon',
    false, 'Featured', 'High Demand', 'View Opportunity', 20, 'active'
  )
) AS v(
  project_name, slug, short_description, full_description,
  investment_type, type_label, roi_min, roi_max, duration,
  risk_level, growth_potential, minimum_investment,
  target_amount, amount_raised, progress_pct, opportunity_status,
  is_featured, featured_badge, demand_badge, cta_label, sort_order, status
)
WHERE NOT EXISTS (
  SELECT 1 FROM public.website_investment_opportunities
  WHERE COALESCE(is_deleted, false) = false
);
