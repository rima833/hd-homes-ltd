-- Website Services CMS: categories + catalog + case studies
CREATE TABLE IF NOT EXISTS public.website_service_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  description TEXT NOT NULL DEFAULT '',
  icon_name TEXT NOT NULL DEFAULT 'briefcase',
  sort_order INT NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.website_service_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  short_description TEXT NOT NULL DEFAULT '',
  category_slug TEXT NOT NULL DEFAULT 'professional-services',
  icon_name TEXT NOT NULL DEFAULT 'briefcase',
  key_benefits JSONB NOT NULL DEFAULT '[]'::jsonb,
  badges JSONB NOT NULL DEFAULT '[]'::jsonb,
  is_featured BOOLEAN NOT NULL DEFAULT false,
  sort_order INT NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.website_service_case_studies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client TEXT NOT NULL,
  service_label TEXT NOT NULL DEFAULT '',
  challenge TEXT NOT NULL DEFAULT '',
  solution TEXT NOT NULL DEFAULT '',
  results TEXT NOT NULL DEFAULT '',
  service_slug TEXT NOT NULL DEFAULT '',
  is_featured BOOLEAN NOT NULL DEFAULT true,
  sort_order INT NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS website_service_categories_sort_idx
  ON public.website_service_categories (sort_order)
  WHERE COALESCE(is_deleted, false) = false;
CREATE INDEX IF NOT EXISTS website_service_items_sort_idx
  ON public.website_service_items (sort_order)
  WHERE COALESCE(is_deleted, false) = false;
CREATE INDEX IF NOT EXISTS website_service_items_featured_idx
  ON public.website_service_items (is_featured)
  WHERE COALESCE(is_deleted, false) = false AND status = 'active';
CREATE INDEX IF NOT EXISTS website_service_case_studies_sort_idx
  ON public.website_service_case_studies (sort_order)
  WHERE COALESCE(is_deleted, false) = false;

ALTER TABLE public.website_service_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.website_service_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.website_service_case_studies ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS website_service_categories_public_read ON public.website_service_categories;
CREATE POLICY website_service_categories_public_read ON public.website_service_categories
  FOR SELECT USING (is_deleted = false AND status = 'active');
DROP POLICY IF EXISTS website_service_categories_staff ON public.website_service_categories;
CREATE POLICY website_service_categories_staff ON public.website_service_categories
  FOR ALL USING (public.has_permission('manage_marketing'))
  WITH CHECK (public.has_permission('manage_marketing'));

DROP POLICY IF EXISTS website_service_items_public_read ON public.website_service_items;
CREATE POLICY website_service_items_public_read ON public.website_service_items
  FOR SELECT USING (is_deleted = false AND status = 'active');
DROP POLICY IF EXISTS website_service_items_staff ON public.website_service_items;
CREATE POLICY website_service_items_staff ON public.website_service_items
  FOR ALL USING (public.has_permission('manage_marketing'))
  WITH CHECK (public.has_permission('manage_marketing'));

DROP POLICY IF EXISTS website_service_case_studies_public_read ON public.website_service_case_studies;
CREATE POLICY website_service_case_studies_public_read ON public.website_service_case_studies
  FOR SELECT USING (is_deleted = false AND status = 'active');
DROP POLICY IF EXISTS website_service_case_studies_staff ON public.website_service_case_studies;
CREATE POLICY website_service_case_studies_staff ON public.website_service_case_studies
  FOR ALL USING (public.has_permission('manage_marketing'))
  WITH CHECK (public.has_permission('manage_marketing'));

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.website_service_categories;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.website_service_items;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.website_service_case_studies;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
