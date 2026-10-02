-- Careers hub CMS: settings + jobs + benefits + stats + tags
CREATE TABLE IF NOT EXISTS public.careers_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  hero_overline TEXT NOT NULL DEFAULT 'CAREERS',
  hero_title_line1 TEXT NOT NULL DEFAULT 'Build the Future',
  hero_title_line2 TEXT NOT NULL DEFAULT 'With Us',
  hero_body TEXT NOT NULL DEFAULT '',
  hero_image_url TEXT,
  culture_summary TEXT NOT NULL DEFAULT '',
  about_subtitle TEXT NOT NULL DEFAULT 'Build your career while building communities.',
  cta_primary_label TEXT NOT NULL DEFAULT 'View All Careers',
  cta_secondary_label TEXT NOT NULL DEFAULT 'Submit Your CV',
  cv_banner_text TEXT NOT NULL DEFAULT 'Don''t see the right role? Send us your CV and we''ll keep you in mind for future opportunities.',
  cv_banner_cta_label TEXT NOT NULL DEFAULT 'Send Your CV',
  cv_email TEXT NOT NULL DEFAULT 'careers@hdhomes.ng',
  seo_title TEXT,
  seo_description TEXT,
  open_positions_override INT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.career_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  department TEXT NOT NULL DEFAULT '',
  location TEXT NOT NULL DEFAULT '',
  employment_type TEXT NOT NULL DEFAULT 'Full Time',
  summary TEXT NOT NULL DEFAULT '',
  description TEXT NOT NULL DEFAULT '',
  icon_name TEXT NOT NULL DEFAULT 'briefcase',
  apply_url TEXT,
  sort_order INT NOT NULL DEFAULT 0,
  is_featured BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE IF NOT EXISTS public.career_benefits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  icon_name TEXT NOT NULL DEFAULT 'sparkles',
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE IF NOT EXISTS public.career_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  value TEXT NOT NULL,
  label TEXT NOT NULL,
  icon_name TEXT NOT NULL DEFAULT 'briefcase',
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE IF NOT EXISTS public.career_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  label TEXT NOT NULL,
  kind TEXT NOT NULL DEFAULT 'benefit_pill',
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  CONSTRAINT career_tags_kind_chk CHECK (kind IN ('why_work', 'benefit_pill'))
);

CREATE INDEX IF NOT EXISTS career_jobs_sort_idx ON public.career_jobs (sort_order) WHERE COALESCE(is_deleted, false) = false;
CREATE INDEX IF NOT EXISTS career_benefits_sort_idx ON public.career_benefits (sort_order) WHERE COALESCE(is_deleted, false) = false;
CREATE INDEX IF NOT EXISTS career_stats_sort_idx ON public.career_stats (sort_order) WHERE COALESCE(is_deleted, false) = false;
CREATE INDEX IF NOT EXISTS career_tags_sort_idx ON public.career_tags (kind, sort_order) WHERE COALESCE(is_deleted, false) = false;

ALTER TABLE public.careers_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.career_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.career_benefits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.career_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.career_tags ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS careers_settings_public_read ON public.careers_settings;
CREATE POLICY careers_settings_public_read ON public.careers_settings FOR SELECT USING (true);
DROP POLICY IF EXISTS careers_settings_staff ON public.careers_settings;
CREATE POLICY careers_settings_staff ON public.careers_settings FOR ALL USING (public.has_permission('manage_marketing')) WITH CHECK (public.has_permission('manage_marketing'));

DROP POLICY IF EXISTS career_jobs_public_read ON public.career_jobs;
CREATE POLICY career_jobs_public_read ON public.career_jobs FOR SELECT USING (is_deleted = false AND status = 'active');
DROP POLICY IF EXISTS career_jobs_staff ON public.career_jobs;
CREATE POLICY career_jobs_staff ON public.career_jobs FOR ALL USING (public.has_permission('manage_marketing')) WITH CHECK (public.has_permission('manage_marketing'));

DROP POLICY IF EXISTS career_benefits_public_read ON public.career_benefits;
CREATE POLICY career_benefits_public_read ON public.career_benefits FOR SELECT USING (is_deleted = false AND status = 'active');
DROP POLICY IF EXISTS career_benefits_staff ON public.career_benefits;
CREATE POLICY career_benefits_staff ON public.career_benefits FOR ALL USING (public.has_permission('manage_marketing')) WITH CHECK (public.has_permission('manage_marketing'));

DROP POLICY IF EXISTS career_stats_public_read ON public.career_stats;
CREATE POLICY career_stats_public_read ON public.career_stats FOR SELECT USING (is_deleted = false AND status = 'active');
DROP POLICY IF EXISTS career_stats_staff ON public.career_stats;
CREATE POLICY career_stats_staff ON public.career_stats FOR ALL USING (public.has_permission('manage_marketing')) WITH CHECK (public.has_permission('manage_marketing'));

DROP POLICY IF EXISTS career_tags_public_read ON public.career_tags;
CREATE POLICY career_tags_public_read ON public.career_tags FOR SELECT USING (is_deleted = false AND status = 'active');
DROP POLICY IF EXISTS career_tags_staff ON public.career_tags;
CREATE POLICY career_tags_staff ON public.career_tags FOR ALL USING (public.has_permission('manage_marketing')) WITH CHECK (public.has_permission('manage_marketing'));
