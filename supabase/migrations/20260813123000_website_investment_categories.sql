-- Admin-managed investment category filters for the public hub.

CREATE TABLE IF NOT EXISTS public.website_investment_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  icon TEXT NOT NULL DEFAULT 'building2',
  display_order INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT website_investment_categories_slug_unique UNIQUE (slug)
);

CREATE INDEX IF NOT EXISTS website_investment_categories_order_idx
  ON public.website_investment_categories (display_order)
  WHERE COALESCE(is_deleted, false) = false;

ALTER TABLE public.website_investment_categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS website_investment_categories_public_read
  ON public.website_investment_categories;
CREATE POLICY website_investment_categories_public_read
  ON public.website_investment_categories
  FOR SELECT USING (
    COALESCE(is_deleted, false) = false AND is_active = true
  );

DROP POLICY IF EXISTS website_investment_categories_staff
  ON public.website_investment_categories;
CREATE POLICY website_investment_categories_staff
  ON public.website_investment_categories
  FOR ALL USING (public.has_permission('manage_marketing'))
  WITH CHECK (public.has_permission('manage_marketing'));

INSERT INTO public.website_investment_categories (name, slug, icon, display_order)
SELECT * FROM (VALUES
  ('Off-Plan', 'off-plan', 'building2', 10),
  ('Rental Income', 'rental-income', 'lineChart', 20),
  ('Capital Growth', 'capital-growth', 'package', 30),
  ('Commercial', 'commercial', 'building', 40),
  ('Land Banking', 'land-banking', 'map', 50),
  ('Fractional', 'fractional', 'splitSquareVertical', 60)
) AS v(name, slug, icon, display_order)
WHERE NOT EXISTS (
  SELECT 1 FROM public.website_investment_categories e
  WHERE e.slug = v.slug AND COALESCE(e.is_deleted, false) = false
);

ALTER TABLE public.website_investment_opportunities
  ADD COLUMN IF NOT EXISTS category_id UUID
    REFERENCES public.website_investment_categories(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS secondary_cta_label TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS secondary_cta_link TEXT,
  ADD COLUMN IF NOT EXISTS show_progress BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS meta_title TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS meta_description TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS opening_date DATE,
  ADD COLUMN IF NOT EXISTS closing_date DATE;

UPDATE public.website_investment_opportunities o
SET category_id = c.id
FROM public.website_investment_categories c
WHERE o.category_id IS NULL
  AND COALESCE(o.is_deleted, false) = false
  AND (
    lower(regexp_replace(coalesce(o.type_label, ''), '[^a-zA-Z0-9]+', '-', 'g')) = c.slug
    OR lower(regexp_replace(coalesce(o.investment_type, ''), '[^a-zA-Z0-9]+', '-', 'g')) = c.slug
    OR (c.slug = 'commercial' AND o.investment_type ILIKE '%commercial%')
    OR (c.slug = 'off-plan' AND (o.investment_type ILIKE '%off-plan%' OR o.investment_type ILIKE '%off plan%' OR o.slug ILIKE '%horizon%'))
    OR (c.slug = 'rental-income' AND o.investment_type ILIKE '%rental%')
    OR (c.slug = 'capital-growth' AND o.investment_type ILIKE '%capital%')
    OR (c.slug = 'land-banking' AND o.investment_type ILIKE '%land%')
    OR (c.slug = 'fractional' AND o.investment_type ILIKE '%fractional%')
  );

CREATE INDEX IF NOT EXISTS website_investment_opps_category_idx
  ON public.website_investment_opportunities (category_id)
  WHERE COALESCE(is_deleted, false) = false;

DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.website_investment_categories;
  EXCEPTION WHEN duplicate_object THEN
    NULL;
  END;
END $$;
