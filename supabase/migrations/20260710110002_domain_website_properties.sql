-- Migration 003: Website CMS, Properties, Estates domain tables

-- ===========================================================================
-- WEBSITE CMS
-- ===========================================================================

CREATE TABLE public.pages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  content JSONB NOT NULL DEFAULT '{}'::jsonb,
  meta_title TEXT,
  meta_description TEXT,
  is_published BOOLEAN NOT NULL DEFAULT false,
  published_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.menus (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  location TEXT NOT NULL DEFAULT 'header',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.navigation (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  menu_id UUID NOT NULL REFERENCES public.menus(id) ON DELETE CASCADE,
  parent_id UUID REFERENCES public.navigation(id) ON DELETE CASCADE,
  label TEXT NOT NULL,
  url TEXT,
  page_id UUID REFERENCES public.pages(id),
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.banners (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  subtitle TEXT,
  image_url TEXT,
  link_url TEXT,
  sort_order INT NOT NULL DEFAULT 0,
  starts_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.hero_sections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  page_key TEXT NOT NULL UNIQUE,
  headline TEXT NOT NULL,
  subheadline TEXT,
  cta_label TEXT,
  cta_url TEXT,
  background_url TEXT,
  content JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.testimonials (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_name TEXT NOT NULL,
  client_title TEXT,
  content TEXT NOT NULL,
  rating INT CHECK (rating BETWEEN 1 AND 5),
  avatar_url TEXT,
  is_featured BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.faqs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  question TEXT NOT NULL,
  answer TEXT NOT NULL,
  category TEXT,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.media (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT,
  file_url TEXT NOT NULL,
  file_type TEXT NOT NULL,
  mime_type TEXT,
  file_size BIGINT,
  alt_text TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.downloads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  file_url TEXT NOT NULL,
  category TEXT,
  download_count INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

-- ===========================================================================
-- PROPERTIES
-- ===========================================================================

CREATE TABLE public.property_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.property_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.properties (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  description TEXT,
  category_id UUID REFERENCES public.property_categories(id),
  type_id UUID REFERENCES public.property_types(id),
  estate_id UUID,
  is_featured BOOLEAN NOT NULL DEFAULT false,
  is_published BOOLEAN NOT NULL DEFAULT false,
  published_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'draft',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.property_images (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  url TEXT NOT NULL,
  alt_text TEXT,
  sort_order INT NOT NULL DEFAULT 0,
  is_cover BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.property_videos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  url TEXT NOT NULL,
  title TEXT,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.property_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  file_url TEXT NOT NULL,
  document_type TEXT,
  is_public BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.property_features (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  feature TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.property_amenities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  amenity TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.property_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL UNIQUE REFERENCES public.properties(id) ON DELETE CASCADE,
  address TEXT,
  city TEXT,
  state TEXT,
  country TEXT DEFAULT 'Nigeria',
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.property_pricing (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL UNIQUE REFERENCES public.properties(id) ON DELETE CASCADE,
  price NUMERIC(15,2) NOT NULL,
  currency TEXT NOT NULL DEFAULT 'NGN',
  price_label TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.property_payment_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  initial_deposit_percent NUMERIC(5,2),
  installment_months INT,
  details JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

-- ===========================================================================
-- ESTATES
-- ===========================================================================

CREATE TABLE public.estates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  description TEXT,
  is_published BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

ALTER TABLE public.properties
  ADD CONSTRAINT properties_estate_id_fkey
  FOREIGN KEY (estate_id) REFERENCES public.estates(id);

CREATE TABLE public.estate_phases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  estate_id UUID NOT NULL REFERENCES public.estates(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  phase_number INT,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.estate_masterplans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  estate_id UUID NOT NULL REFERENCES public.estates(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  file_url TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.estate_images (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  estate_id UUID NOT NULL REFERENCES public.estates(id) ON DELETE CASCADE,
  url TEXT NOT NULL,
  alt_text TEXT,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.estate_features (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  estate_id UUID NOT NULL REFERENCES public.estates(id) ON DELETE CASCADE,
  feature TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

-- Indexes
CREATE INDEX idx_properties_slug ON public.properties(slug);
CREATE INDEX idx_properties_published ON public.properties(is_published, is_deleted);
CREATE INDEX idx_estates_slug ON public.estates(slug);
CREATE INDEX idx_property_locations_geo ON public.property_locations(latitude, longitude);

-- RLS: public read for published content; staff manage via permissions
ALTER TABLE public.pages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.menus ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.navigation ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.banners ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hero_sections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.testimonials ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.faqs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.media ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.downloads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.properties ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_videos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_features ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_amenities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_pricing ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_payment_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.estates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.estate_phases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.estate_masterplans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.estate_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.estate_features ENABLE ROW LEVEL SECURITY;

-- Public CMS read policies
CREATE POLICY cms_public_read ON public.pages FOR SELECT USING (is_published = true AND is_deleted = false);
CREATE POLICY cms_staff_all ON public.pages FOR ALL USING (public.has_permission('manage_marketing') OR public.has_role('admin') OR public.has_role('super_admin'));

CREATE POLICY menus_public_read ON public.menus FOR SELECT USING (is_deleted = false);
CREATE POLICY menus_staff ON public.menus FOR ALL USING (public.has_permission('manage_marketing'));

CREATE POLICY nav_public_read ON public.navigation FOR SELECT USING (is_deleted = false);
CREATE POLICY nav_staff ON public.navigation FOR ALL USING (public.has_permission('manage_marketing'));

CREATE POLICY banners_public_read ON public.banners FOR SELECT USING (is_deleted = false AND status = 'active');
CREATE POLICY banners_staff ON public.banners FOR ALL USING (public.has_permission('manage_marketing'));

CREATE POLICY hero_public_read ON public.hero_sections FOR SELECT USING (is_deleted = false);
CREATE POLICY hero_staff ON public.hero_sections FOR ALL USING (public.has_permission('manage_marketing'));

CREATE POLICY testimonials_public_read ON public.testimonials FOR SELECT USING (is_deleted = false);
CREATE POLICY testimonials_staff ON public.testimonials FOR ALL USING (public.has_permission('manage_marketing'));

CREATE POLICY faqs_public_read ON public.faqs FOR SELECT USING (is_deleted = false);
CREATE POLICY faqs_staff ON public.faqs FOR ALL USING (public.has_permission('manage_marketing'));

CREATE POLICY media_public_read ON public.media FOR SELECT USING (is_deleted = false);
CREATE POLICY media_staff ON public.media FOR ALL USING (public.has_permission('manage_marketing'));

CREATE POLICY downloads_public_read ON public.downloads FOR SELECT USING (is_deleted = false);
CREATE POLICY downloads_staff ON public.downloads FOR ALL USING (public.has_permission('manage_marketing'));

-- Properties: guests browse published; staff manage
CREATE POLICY property_categories_public ON public.property_categories FOR SELECT USING (is_deleted = false);
CREATE POLICY property_categories_staff ON public.property_categories FOR ALL USING (public.has_permission('edit_property'));

CREATE POLICY property_types_public ON public.property_types FOR SELECT USING (is_deleted = false);
CREATE POLICY property_types_staff ON public.property_types FOR ALL USING (public.has_permission('edit_property'));

CREATE POLICY properties_public_read ON public.properties FOR SELECT USING (is_published = true AND is_deleted = false);
CREATE POLICY properties_staff ON public.properties FOR ALL USING (
  public.has_permission('create_property')
  OR public.has_permission('edit_property')
  OR public.has_permission('delete_property')
);

CREATE POLICY property_images_public ON public.property_images FOR SELECT USING (is_deleted = false);
CREATE POLICY property_images_staff ON public.property_images FOR ALL USING (public.has_permission('edit_property'));

CREATE POLICY property_videos_public ON public.property_videos FOR SELECT USING (is_deleted = false);
CREATE POLICY property_videos_staff ON public.property_videos FOR ALL USING (public.has_permission('edit_property'));

CREATE POLICY property_docs_public ON public.property_documents FOR SELECT USING (is_public = true AND is_deleted = false);
CREATE POLICY property_docs_staff ON public.property_documents FOR ALL USING (public.has_permission('edit_property'));

CREATE POLICY property_features_public ON public.property_features FOR SELECT USING (is_deleted = false);
CREATE POLICY property_features_staff ON public.property_features FOR ALL USING (public.has_permission('edit_property'));

CREATE POLICY property_amenities_public ON public.property_amenities FOR SELECT USING (is_deleted = false);
CREATE POLICY property_amenities_staff ON public.property_amenities FOR ALL USING (public.has_permission('edit_property'));

CREATE POLICY property_locations_public ON public.property_locations FOR SELECT USING (is_deleted = false);
CREATE POLICY property_locations_staff ON public.property_locations FOR ALL USING (public.has_permission('edit_property'));

CREATE POLICY property_pricing_public ON public.property_pricing FOR SELECT USING (is_deleted = false);
CREATE POLICY property_pricing_staff ON public.property_pricing FOR ALL USING (public.has_permission('edit_property'));

CREATE POLICY property_plans_public ON public.property_payment_plans FOR SELECT USING (is_deleted = false);
CREATE POLICY property_plans_staff ON public.property_payment_plans FOR ALL USING (public.has_permission('edit_property'));

CREATE POLICY estates_public_read ON public.estates FOR SELECT USING (is_published = true AND is_deleted = false);
CREATE POLICY estates_staff ON public.estates FOR ALL USING (public.has_permission('edit_property'));

CREATE POLICY estate_phases_public ON public.estate_phases FOR SELECT USING (is_deleted = false);
CREATE POLICY estate_phases_staff ON public.estate_phases FOR ALL USING (public.has_permission('edit_property'));

CREATE POLICY estate_masterplans_public ON public.estate_masterplans FOR SELECT USING (is_deleted = false);
CREATE POLICY estate_masterplans_staff ON public.estate_masterplans FOR ALL USING (public.has_permission('edit_property'));

CREATE POLICY estate_images_public ON public.estate_images FOR SELECT USING (is_deleted = false);
CREATE POLICY estate_images_staff ON public.estate_images FOR ALL USING (public.has_permission('edit_property'));

CREATE POLICY estate_features_public ON public.estate_features FOR SELECT USING (is_deleted = false);
CREATE POLICY estate_features_staff ON public.estate_features FOR ALL USING (public.has_permission('edit_property'));
