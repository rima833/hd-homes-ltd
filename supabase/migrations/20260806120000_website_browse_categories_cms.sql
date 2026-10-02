-- Marketing CMS: Browse by Category cards (Home + Properties marketplace)
CREATE TABLE IF NOT EXISTS public.website_browse_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  label TEXT NOT NULL,
  filter_key TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  icon_name TEXT NOT NULL DEFAULT 'home',
  image_url TEXT,
  is_featured BOOLEAN NOT NULL DEFAULT false,
  sort_order INT NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  UNIQUE (filter_key)
);

CREATE INDEX IF NOT EXISTS website_browse_categories_sort_idx
  ON public.website_browse_categories (sort_order)
  WHERE COALESCE(is_deleted, false) = false;

ALTER TABLE public.website_browse_categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS website_browse_categories_public_read
  ON public.website_browse_categories;
CREATE POLICY website_browse_categories_public_read
  ON public.website_browse_categories
  FOR SELECT USING (
    COALESCE(is_deleted, false) = false AND status = 'active'
  );

DROP POLICY IF EXISTS website_browse_categories_staff
  ON public.website_browse_categories;
CREATE POLICY website_browse_categories_staff
  ON public.website_browse_categories
  FOR ALL USING (public.has_permission('manage_marketing'))
  WITH CHECK (public.has_permission('manage_marketing'));

INSERT INTO public.website_browse_categories (
  label, filter_key, description, icon_name, image_url, is_featured, sort_order, status
)
SELECT * FROM (VALUES
  (
    'Luxury Homes', 'luxury',
    'Premium residences crafted for elegance, comfort, and a lifestyle like no other.',
    'crown',
    'https://images.unsplash.com/photo-1613490493576-7fde63acd811?auto=format&fit=crop&w=1400&q=80',
    true, 10, 'active'
  ),
  (
    'Affordable Homes', 'affordable',
    'Quality homes designed for every budget.',
    'home',
    'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=900&q=80',
    false, 20, 'active'
  ),
  (
    'Family Homes', 'family',
    'Spacious living for growing households.',
    'users',
    'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?auto=format&fit=crop&w=900&q=80',
    false, 30, 'active'
  ),
  (
    'Commercial', 'commercial',
    'Offices, retail, and mixed-use spaces.',
    'building',
    'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=900&q=80',
    false, 40, 'active'
  ),
  (
    'Land', 'land',
    'Verified plots in high-growth corridors.',
    'map',
    'https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=900&q=80',
    false, 50, 'active'
  ),
  (
    'Investment', 'investment',
    'Structured opportunities with strong ROI.',
    'trending',
    'https://images.unsplash.com/photo-1560518883-ce09059eeffa?auto=format&fit=crop&w=900&q=80',
    false, 60, 'active'
  ),
  (
    'New Launches', 'new',
    'Fresh releases and off-plan estates.',
    'sparkles',
    'https://images.unsplash.com/photo-1600047509807-ba8f99d36b7f?auto=format&fit=crop&w=900&q=80',
    false, 70, 'active'
  )
) AS v(label, filter_key, description, icon_name, image_url, is_featured, sort_order, status)
WHERE NOT EXISTS (
  SELECT 1 FROM public.website_browse_categories c WHERE c.filter_key = v.filter_key
);
