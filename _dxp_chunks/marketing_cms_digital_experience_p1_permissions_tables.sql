-- Permissions
-- ---------------------------------------------------------------------------
INSERT INTO public.permissions (slug, name, description, module) VALUES
  ('marketing.read', 'View Marketing', 'View Marketing Command Center and DXP records', 'marketing'),
  ('marketing.write', 'Manage Marketing', 'Create and edit marketing operational records', 'marketing'),
  ('marketing.cms', 'CMS & Pages', 'Manage CMS pages, sections, templates, and versions', 'marketing'),
  ('marketing.campaigns', 'Campaigns', 'Manage omnichannel marketing campaigns', 'marketing'),
  ('marketing.media', 'Media Library', 'Manage media folders and library assets', 'marketing'),
  ('marketing.seo', 'SEO & Redirects', 'Manage SEO metadata, redirects, and health', 'marketing'),
  ('marketing.forms', 'Forms', 'Manage lead forms and submissions', 'marketing'),
  ('marketing.analytics', 'Marketing Analytics', 'View KPIs, funnels, and marketing reports', 'marketing'),
  ('marketing.ai', 'AI Content Studio', 'Use AI content suggestions and insights', 'marketing'),
  ('marketing.publish', 'Publish Content', 'Publish pages, blogs, and landing experiences', 'marketing'),
  ('marketing.social', 'Social Publishing', 'Manage social accounts and posts', 'marketing')
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  module = EXCLUDED.module,
  updated_at = now();

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE p.slug LIKE 'marketing.%'
  AND (
    r.slug IN ('super_admin', 'admin')
    OR (r.slug = 'marketing' AND p.slug LIKE 'marketing.%')
    OR (r.slug = 'sales_team' AND p.slug IN (
      'marketing.read', 'marketing.forms', 'marketing.analytics', 'marketing.campaigns'
    ))
    OR (r.slug = 'finance' AND p.slug IN (
      'marketing.read', 'marketing.analytics'
    ))
    OR (r.slug = 'construction_manager' AND p.slug IN (
      'marketing.read'
    ))
  )
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Enrich existing tables (do not recreate)
-- ---------------------------------------------------------------------------
ALTER TABLE public.pages
  ADD COLUMN IF NOT EXISTS template_id uuid,
  ADD COLUMN IF NOT EXISTS layout_key text,
  ADD COLUMN IF NOT EXISTS locale text DEFAULT 'en',
  ADD COLUMN IF NOT EXISTS seo_score numeric(5,2),
  ADD COLUMN IF NOT EXISTS unpublished_changes boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}'::jsonb;

ALTER TABLE public.blogs
  ADD COLUMN IF NOT EXISTS reading_time_minutes int,
  ADD COLUMN IF NOT EXISTS seo_score numeric(5,2),
  ADD COLUMN IF NOT EXISTS featured boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS blog_author_id uuid,
  ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}'::jsonb;

ALTER TABLE public.media
  ADD COLUMN IF NOT EXISTS folder_id uuid,
  ADD COLUMN IF NOT EXISTS width int,
  ADD COLUMN IF NOT EXISTS height int,
  ADD COLUMN IF NOT EXISTS tags text[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS checksum text,
  ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}'::jsonb;

ALTER TABLE public.seo
  ADD COLUMN IF NOT EXISTS robots text DEFAULT 'index,follow',
  ADD COLUMN IF NOT EXISTS keywords text[],
  ADD COLUMN IF NOT EXISTS health_score numeric(5,2),
  ADD COLUMN IF NOT EXISTS last_crawled_at timestamptz,
  ADD COLUMN IF NOT EXISTS issues jsonb DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}'::jsonb;

-- Enrich thin campaigns rather than marketing_campaigns duplicate
ALTER TABLE public.campaigns
  ADD COLUMN IF NOT EXISTS campaign_code text,
  ADD COLUMN IF NOT EXISTS objective text,
  ADD COLUMN IF NOT EXISTS budget_amount numeric(16,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS currency text DEFAULT 'NGN',
  ADD COLUMN IF NOT EXISTS audience_segment_id uuid,
  ADD COLUMN IF NOT EXISTS primary_channel text,
  ADD COLUMN IF NOT EXISTS conversion_goal text,
  ADD COLUMN IF NOT EXISTS metrics jsonb DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}'::jsonb;

CREATE UNIQUE INDEX IF NOT EXISTS idx_campaigns_campaign_code
  ON public.campaigns (campaign_code)
  WHERE campaign_code IS NOT NULL;

-- ---------------------------------------------------------------------------
-- CMS: templates, sections, page versions
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.cms_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  description text,
  layout_json jsonb NOT NULL DEFAULT '{}'::jsonb,
  thumbnail_url text,
  is_active boolean NOT NULL DEFAULT true,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.cms_page_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  page_id uuid NOT NULL REFERENCES public.pages(id) ON DELETE CASCADE,
  version_number int NOT NULL DEFAULT 1,
  title text,
  content jsonb NOT NULL DEFAULT '{}'::jsonb,
  change_summary text,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (page_id, version_number)
);

CREATE INDEX IF NOT EXISTS idx_cms_page_versions_page
  ON public.cms_page_versions (page_id, version_number DESC);

CREATE TABLE IF NOT EXISTS public.cms_sections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  page_id uuid REFERENCES public.pages(id) ON DELETE CASCADE,
  landing_page_id uuid,
  section_key text NOT NULL,
  section_type text NOT NULL DEFAULT 'block',
  title text,
  content jsonb NOT NULL DEFAULT '{}'::jsonb,
  sort_order int NOT NULL DEFAULT 0,
  is_visible boolean NOT NULL DEFAULT true,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cms_sections_page ON public.cms_sections (page_id, sort_order);

-- ---------------------------------------------------------------------------
-- Landing pages
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.landing_pages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  slug text NOT NULL UNIQUE,
  headline text,
  subheadline text,
  hero_image_url text,
  cta_label text,
  cta_url text,
  template_id uuid REFERENCES public.cms_templates(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','published','archived','scheduled')),
  is_published boolean NOT NULL DEFAULT false,
  published_at timestamptz,
  conversion_goal text,
  seo_score numeric(5,2),
  content jsonb NOT NULL DEFAULT '{}'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_landing_pages_status ON public.landing_pages (status);

CREATE TABLE IF NOT EXISTS public.landing_page_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  landing_page_id uuid NOT NULL REFERENCES public.landing_pages(id) ON DELETE CASCADE,
  version_number int NOT NULL DEFAULT 1,
  title text,
  content jsonb NOT NULL DEFAULT '{}'::jsonb,
  change_summary text,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (landing_page_id, version_number)
);

-- Late FK for cms_sections.landing_page_id
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'cms_sections_landing_page_id_fkey'
  ) THEN
    ALTER TABLE public.cms_sections
      ADD CONSTRAINT cms_sections_landing_page_id_fkey
      FOREIGN KEY (landing_page_id) REFERENCES public.landing_pages(id) ON DELETE CASCADE;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Blog authors / tags
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.blog_authors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  display_name text NOT NULL,
  slug text NOT NULL UNIQUE,
  bio text,
  avatar_url text,
  profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  is_active boolean NOT NULL DEFAULT true,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'blogs_blog_author_id_fkey'
  ) THEN
    ALTER TABLE public.blogs
      ADD CONSTRAINT blogs_blog_author_id_fkey
      FOREIGN KEY (blog_author_id) REFERENCES public.blog_authors(id) ON DELETE SET NULL;
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.blog_tags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  description text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.blog_tag_links (
  blog_id uuid NOT NULL REFERENCES public.blogs(id) ON DELETE CASCADE,
  tag_id uuid NOT NULL REFERENCES public.blog_tags(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (blog_id, tag_id)
);

-- ---------------------------------------------------------------------------
-- Media folders + optional library view
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.media_folders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  parent_id uuid REFERENCES public.media_folders(id) ON DELETE SET NULL,
  description text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'media_folder_id_fkey'
  ) THEN
    ALTER TABLE public.media
      ADD CONSTRAINT media_folder_id_fkey
      FOREIGN KEY (folder_id) REFERENCES public.media_folders(id) ON DELETE SET NULL;
  END IF;
END $$;

CREATE OR REPLACE VIEW public.media_library AS
SELECT
  m.id,
  m.title,
  m.file_url,
  m.file_type,
  m.mime_type,
  m.file_size,
  m.alt_text,
  m.folder_id,
  f.name AS folder_name,
  m.width,
  m.height,
  m.tags,
  m.status,
  m.is_deleted,
  m.created_at,
  m.updated_at
FROM public.media m
LEFT JOIN public.media_folders f ON f.id = m.folder_id
WHERE m.is_deleted = false;

-- ---------------------------------------------------------------------------
-- SEO metadata health + redirects
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.seo_metadata (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type text NOT NULL,
  entity_id uuid,
  path text,
  meta_title text,
  meta_description text,
  canonical_url text,
  og_image_url text,
  health_score numeric(5,2) DEFAULT 0,
  issue_count int NOT NULL DEFAULT 0,
  issues jsonb NOT NULL DEFAULT '[]'::jsonb,
  last_audit_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_seo_metadata_path ON public.seo_metadata (path);

CREATE TABLE IF NOT EXISTS public.redirects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  from_path text NOT NULL UNIQUE,
  to_path text NOT NULL,
  status_code int NOT NULL DEFAULT 301
    CHECK (status_code IN (301, 302, 307, 308)),
  is_active boolean NOT NULL DEFAULT true,
  hit_count bigint NOT NULL DEFAULT 0,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Audiences / segments (campaign children)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.audience_segments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  description text,
  rules jsonb NOT NULL DEFAULT '{}'::jsonb,
  estimated_size int DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.campaign_audiences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id uuid NOT NULL REFERENCES public.campaigns(id) ON DELETE CASCADE,
  segment_id uuid REFERENCES public.audience_segments(id) ON DELETE SET NULL,
  channel text,
  member_count int DEFAULT 0,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (campaign_id, segment_id, channel)
);

-- ---------------------------------------------------------------------------
-- Channel campaigns (FK campaigns)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.email_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  subject text NOT NULL,
  body_html text,
  body_json jsonb NOT NULL DEFAULT '{}'::jsonb,
  is_active boolean NOT NULL DEFAULT true,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.email_campaigns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id uuid REFERENCES public.campaigns(id) ON DELETE SET NULL,
  template_id uuid REFERENCES public.email_templates(id) ON DELETE SET NULL,
  name text NOT NULL,
  subject text,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','scheduled','sending','sent','paused','cancelled')),
  scheduled_at timestamptz,
  sent_at timestamptz,
  open_rate numeric(5,2) DEFAULT 0,
  click_rate numeric(5,2) DEFAULT 0,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.sms_campaigns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id uuid REFERENCES public.campaigns(id) ON DELETE SET NULL,
  name text NOT NULL,
  message_body text NOT NULL,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','scheduled','sending','sent','paused','cancelled')),
  scheduled_at timestamptz,
  sent_at timestamptz,
  delivery_rate numeric(5,2) DEFAULT 0,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.whatsapp_campaigns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id uuid REFERENCES public.campaigns(id) ON DELETE SET NULL,
  name text NOT NULL,
  template_name text,
  message_body text,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','scheduled','sending','sent','paused','cancelled')),
  scheduled_at timestamptz,
  sent_at timestamptz,
  read_rate numeric(5,2) DEFAULT 0,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.push_campaigns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id uuid REFERENCES public.campaigns(id) ON DELETE SET NULL,
  name text NOT NULL,
  title text,
  body text,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','scheduled','sending','sent','paused','cancelled')),
  scheduled_at timestamptz,
  sent_at timestamptz,
  open_rate numeric(5,2) DEFAULT 0,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Forms
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.forms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  description text,
  fields jsonb NOT NULL DEFAULT '[]'::jsonb,
  success_message text,
  destination_url text,
  is_active boolean NOT NULL DEFAULT true,
  submission_count int NOT NULL DEFAULT 0,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.form_submissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  form_id uuid NOT NULL REFERENCES public.forms(id) ON DELETE CASCADE,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  email text,
  phone text,
  source_path text,
  utm jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'new'
    CHECK (status IN ('new','contacted','qualified','spam','archived')),
  submitted_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_form_submissions_form
  ON public.form_submissions (form_id, submitted_at DESC);

-- ---------------------------------------------------------------------------
-- DXP personalization (avoid clash with Volume 3 personalization_*)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.dxp_personalization_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  target_entity_type text NOT NULL DEFAULT 'landing_page',
  target_entity_id uuid,
  conditions jsonb NOT NULL DEFAULT '{}'::jsonb,
  actions jsonb NOT NULL DEFAULT '{}'::jsonb,
  priority int NOT NULL DEFAULT 100,
  is_active boolean NOT NULL DEFAULT true,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- A/B tests, calendar, social
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ab_tests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  hypothesis text,
  entity_type text NOT NULL DEFAULT 'landing_page',
  entity_id uuid,
  variant_a jsonb NOT NULL DEFAULT '{}'::jsonb,
  variant_b jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','running','paused','completed','archived')),
  traffic_split numeric(5,2) DEFAULT 50,
  primary_metric text DEFAULT 'conversion_rate',
  winner text,
  started_at timestamptz,
  ended_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.content_calendar (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  channel text NOT NULL DEFAULT 'blog',
  content_type text DEFAULT 'post',
  scheduled_for timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'planned'
    CHECK (status IN ('planned','in_progress','scheduled','published','cancelled')),
  owner_label text,
  related_entity_type text,
  related_entity_id uuid,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_content_calendar_scheduled
  ON public.content_calendar (scheduled_for);

CREATE TABLE IF NOT EXISTS public.social_accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  platform text NOT NULL,
  handle text NOT NULL,
  display_name text,
  is_connected boolean NOT NULL DEFAULT false,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (platform, handle)
);

CREATE TABLE IF NOT EXISTS public.social_posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id uuid REFERENCES public.social_accounts(id) ON DELETE SET NULL,
  caption text,
  media_urls text[] DEFAULT '{}',
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','scheduled','published','failed')),
  scheduled_at timestamptz,
  published_at timestamptz,
  engagement jsonb NOT NULL DEFAULT '{}'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Analytics, activity, notifications
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.marketing_analytics (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  metric_key text NOT NULL,
  metric_label text NOT NULL,
  metric_value numeric(16,4) NOT NULL DEFAULT 0,
  unit text DEFAULT 'count',
  period_start date,
  period_end date,
  dimensions jsonb NOT NULL DEFAULT '{}'::jsonb,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_marketing_analytics_key
  ON public.marketing_analytics (metric_key, recorded_at DESC);

CREATE TABLE IF NOT EXISTS public.marketing_activity_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  action text NOT NULL,
  summary text NOT NULL,
  actor_label text,
  entity_type text,
  entity_id uuid,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_marketing_activity_occurred
  ON public.marketing_activity_logs (occurred_at DESC);

CREATE TABLE IF NOT EXISTS public.marketing_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  body text,
  severity text NOT NULL DEFAULT 'info'
    CHECK (severity IN ('info','warning','critical')),
  category text,
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

-- Optional FK for campaigns.audience_segment_id
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'campaigns_audience_segment_id_fkey'
  ) THEN
    ALTER TABLE public.campaigns
      ADD CONSTRAINT campaigns_audience_segment_id_fkey
      FOREIGN KEY (audience_segment_id) REFERENCES public.audience_segments(id) ON DELETE SET NULL;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'pages_template_id_fkey'
  ) THEN
    ALTER TABLE public.pages
      ADD CONSTRAINT pages_template_id_fkey
      FOREIGN KEY (template_id) REFERENCES public.cms_templates(id) ON DELETE SET NULL;
  END IF;
END $$;

