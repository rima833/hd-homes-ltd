-- Website market insights CMS (investment hub + realtime)
CREATE TABLE IF NOT EXISTS public.website_market_insights (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  value TEXT NOT NULL DEFAULT '',
  trend TEXT NOT NULL DEFAULT '',
  summary TEXT NOT NULL DEFAULT '',
  location TEXT NOT NULL DEFAULT '',
  category TEXT NOT NULL DEFAULT '',
  icon TEXT NOT NULL DEFAULT 'trendingUp',
  source TEXT NOT NULL DEFAULT '',
  source_url TEXT,
  cover_image_url TEXT,
  visual_type TEXT NOT NULL DEFAULT 'line_chart'
    CHECK (visual_type IN ('line_chart', 'bar_chart', 'gauge', 'image')),
  trend_direction TEXT NOT NULL DEFAULT 'up'
    CHECK (trend_direction IN ('up', 'down', 'neutral')),
  is_featured BOOLEAN NOT NULL DEFAULT false,
  sort_order INT NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'published', 'archived')),
  is_published BOOLEAN NOT NULL DEFAULT false,
  published_at TIMESTAMPTZ,
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id)
);

CREATE INDEX IF NOT EXISTS website_market_insights_published_idx
  ON public.website_market_insights (sort_order ASC, updated_at DESC)
  WHERE is_deleted = false AND is_published = true AND status = 'published';

ALTER TABLE public.website_market_insights ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS website_market_insights_public_read
  ON public.website_market_insights;
CREATE POLICY website_market_insights_public_read
  ON public.website_market_insights
  FOR SELECT USING (
    COALESCE(is_deleted, false) = false
    AND is_published = true
    AND status = 'published'
  );

DROP POLICY IF EXISTS website_market_insights_staff
  ON public.website_market_insights;
CREATE POLICY website_market_insights_staff
  ON public.website_market_insights
  FOR ALL USING (public.has_permission('manage_marketing'))
  WITH CHECK (public.has_permission('manage_marketing'));

INSERT INTO public.website_market_insights (
  title, value, trend, summary, location, category, icon,
  source, visual_type, trend_direction, is_featured, sort_order,
  status, is_published, published_at
) VALUES
  (
    'Lekki corridor demand',
    '+18% YoY',
    'RISING',
    'Strong buyer and rental demand driven by infrastructure expansion.',
    'Lekki, Lagos',
    'Demand',
    'trendingUp',
    'HD Homes Research',
    'line_chart',
    'up',
    true,
    10,
    'published',
    true,
    now()
  ),
  (
    'Abuja premium segment',
    '+12% YoY',
    'STABLE GROWTH',
    'Government relocation and diaspora investment sustaining prices.',
    'Abuja, FCT',
    'Premium',
    'building2',
    'HD Homes Research',
    'image',
    'up',
    true,
    20,
    'published',
    true,
    now()
  ),
  (
    'Off-plan momentum',
    '+22% Quarterly',
    'ACCELERATING',
    'Early investors in HD Homes estates historically outperform market.',
    'National',
    'Off-plan',
    'barChart',
    'HD Homes Research',
    'bar_chart',
    'up',
    false,
    30,
    'published',
    true,
    now()
  ),
  (
    'Rental yield — Lagos',
    '8–12%',
    'STABLE',
    'Institutional rental demand in gated estates remains strong.',
    'Lagos',
    'Yield',
    'percent',
    'HD Homes Research',
    'gauge',
    'neutral',
    false,
    40,
    'published',
    true,
    now()
  )
ON CONFLICT DO NOTHING;

DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.website_market_insights;
  EXCEPTION WHEN duplicate_object THEN
    NULL;
  END;
END $$;
