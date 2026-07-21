-- Volume 4 Part 8 — Enterprise Marketing, CMS & Digital Experience Platform (DXP)
-- Status: APPLIED remotely 2026-07-14 (chunked p1–p3).
--
-- Approach:
--   • Do NOT DROP/recreate pages, banners, blogs, blog_categories, media, seo,
--     campaigns, communication_campaigns, newsletter, crm_campaign_memberships.
--   • Enrich pages / blogs / media / seo / campaigns via ALTER ADD COLUMN IF NOT EXISTS.
--   • Prefer NEW DXP tables (landing_pages, cms_*, email_campaigns, forms, …).
--   • Campaigns choice: ENRICH existing public.campaigns (thin) + channel children
--     (email_campaigns / sms_campaigns / whatsapp_campaigns / push_campaigns)
--     rather than a duplicate marketing_campaigns catalog.
--   • Personalization: use dxp_personalization_rules (Volume 3 personalization_* exists).
--   • Seed UUIDs hex-only (0-9a-f), prefix d480….
--   • Permissions: slug, name, description, module only — NO action column.
--   • RLS: has_permission('slug', auth.uid()) — slug FIRST.

BEGIN;

-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- Seeds (hex UUIDs only)
-- ---------------------------------------------------------------------------
INSERT INTO public.cms_templates (id, name, slug, description, layout_json) VALUES
  ('d4800000-0000-4000-8000-000000000001', 'Hero + CTA', 'hero-cta', 'Full-bleed hero with primary CTA',
   '{"regions":["hero","cta","footer"]}'::jsonb),
  ('d4800000-0000-4000-8000-000000000002', 'Property Showcase', 'property-showcase', 'Grid of featured units',
   '{"regions":["hero","gallery","specs","cta"]}'::jsonb)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.media_folders (id, name, slug, description) VALUES
  ('d4800000-0000-4000-8000-000000000010', 'Campaign Assets', 'campaign-assets', 'Shared creative for omnichannel campaigns')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.blog_authors (id, display_name, slug, bio) VALUES
  ('d4800000-0000-4000-8000-000000000020', 'HD Homes Editorial', 'hd-homes-editorial',
   'Official editorial voice for HD Homes Ltd.')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.blog_tags (id, name, slug) VALUES
  ('d4800000-0000-4000-8000-000000000021', 'Lekki Living', 'lekki-living'),
  ('d4800000-0000-4000-8000-000000000022', 'Investment Tips', 'investment-tips')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.landing_pages (
  id, title, slug, headline, subheadline, cta_label, cta_url, template_id,
  status, is_published, published_at, conversion_goal, seo_score, content
) VALUES
  (
    'd4800000-0000-4000-8000-000000000030',
    'Lekki Waterfront Launch',
    'lekki-waterfront-launch',
    'Own waterfront living in Lekki',
    'Limited villa allotments with smart financing.',
    'Book inspection',
    '/contact',
    'd4800000-0000-4000-8000-000000000001',
    'published',
    true,
    now() - interval '3 days',
    'inspection_booking',
    86.0,
    '{"sections":["hero","amenities","cta"]}'::jsonb
  ),
  (
    'd4800000-0000-4000-8000-000000000031',
    'Investor Open Day',
    'investor-open-day',
    'Investor Open Day — Ajah corridor',
    'Private briefing for qualified partners.',
    'Reserve seat',
    '/investment',
    'd4800000-0000-4000-8000-000000000001',
    'draft',
    false,
    NULL,
    'rsvp',
    62.0,
    '{"sections":["hero","agenda","form"]}'::jsonb
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.landing_page_versions (
  id, landing_page_id, version_number, title, content, change_summary
) VALUES
  (
    'd4800000-0000-4000-8000-000000000032',
    'd4800000-0000-4000-8000-000000000030',
    1,
    'Lekki Waterfront Launch',
    '{"headline":"Own waterfront living in Lekki"}'::jsonb,
    'Initial published cut'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.cms_sections (
  id, landing_page_id, section_key, section_type, title, content, sort_order
) VALUES
  (
    'd4800000-0000-4000-8000-000000000033',
    'd4800000-0000-4000-8000-000000000030',
    'hero',
    'hero',
    'Hero',
    '{"eyebrow":"New release","body":"Waterfront villas"}'::jsonb,
    0
  )
ON CONFLICT (id) DO NOTHING;

-- Draft blog seed (insert if slug free)
INSERT INTO public.blogs (
  id, title, slug, excerpt, content, is_published, status, featured,
  reading_time_minutes, seo_score, blog_author_id, metadata
) VALUES
  (
    'd4800000-0000-4000-8000-000000000040',
    'Why Lekki still leads coastal demand',
    'why-lekki-still-leads-coastal-demand',
    'A market note for buyers evaluating waterfront inventory.',
    '{"blocks":[{"type":"paragraph","text":"Draft — AI-assisted outline for editorial review."}]}'::jsonb,
    false,
    'draft',
    false,
    6,
    58.0,
    'd4800000-0000-4000-8000-000000000020',
    '{"ai_generated":true,"editable":true,"label":"AI-generated — editable"}'::jsonb
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.blog_tag_links (blog_id, tag_id) VALUES
  ('d4800000-0000-4000-8000-000000000040', 'd4800000-0000-4000-8000-000000000021')
ON CONFLICT DO NOTHING;

INSERT INTO public.audience_segments (id, name, slug, description, estimated_size, rules) VALUES
  (
    'd4800000-0000-4000-8000-000000000050',
    'Warm inspection leads',
    'warm-inspection-leads',
    'Leads who requested property inspection in last 30 days',
    420,
    '{"source":"forms","window_days":30}'::jsonb
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.campaigns (
  id, name, channel, content, starts_at, ends_at, status,
  campaign_code, objective, budget_amount, primary_channel, conversion_goal,
  audience_segment_id, metrics, metadata
) VALUES
  (
    'd4800000-0000-4000-8000-000000000060',
    'Q3 Waterfront Awareness',
    'omni',
    '{"theme":"lekki-waterfront"}'::jsonb,
    now() - interval '7 days',
    now() + interval '45 days',
    'active',
    'CAMP-Q3-WF',
    'awareness',
    8500000,
    'email',
    'inspection_booking',
    'd4800000-0000-4000-8000-000000000050',
    '{"impressions":128400,"clicks":4120,"conversions":186}'::jsonb,
    '{}'::jsonb
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.campaign_audiences (id, campaign_id, segment_id, channel, member_count) VALUES
  (
    'd4800000-0000-4000-8000-000000000061',
    'd4800000-0000-4000-8000-000000000060',
    'd4800000-0000-4000-8000-000000000050',
    'email',
    420
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.email_templates (id, name, slug, subject, body_html) VALUES
  (
    'd4800000-0000-4000-8000-000000000070',
    'Inspection invite',
    'inspection-invite',
    'Your private Lekki waterfront tour',
    '<p>Join us for a guided inspection this weekend.</p>'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.email_campaigns (
  id, campaign_id, template_id, name, subject, status, open_rate, click_rate, sent_at
) VALUES
  (
    'd4800000-0000-4000-8000-000000000071',
    'd4800000-0000-4000-8000-000000000060',
    'd4800000-0000-4000-8000-000000000070',
    'Waterfront email wave 1',
    'Your private Lekki waterfront tour',
    'sent',
    38.5,
    6.2,
    now() - interval '2 days'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.sms_campaigns (
  id, campaign_id, name, message_body, status, delivery_rate, sent_at
) VALUES
  (
    'd4800000-0000-4000-8000-000000000072',
    'd4800000-0000-4000-8000-000000000060',
    'SMS reminder — weekend tour',
    'HD Homes: Reminder — Lekki waterfront inspection this Saturday 11am. Reply YES to confirm.',
    'sent',
    94.0,
    now() - interval '1 day'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.whatsapp_campaigns (
  id, campaign_id, name, template_name, message_body, status, read_rate, sent_at
) VALUES
  (
    'd4800000-0000-4000-8000-000000000073',
    'd4800000-0000-4000-8000-000000000060',
    'WhatsApp nurture — brochure',
    'brochure_share_v1',
    'Here is the Lekki waterfront brochure and financing flyer.',
    'scheduled',
    0,
    NULL
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.forms (id, name, slug, description, fields, success_message, submission_count) VALUES
  (
    'd4800000-0000-4000-8000-000000000080',
    'Inspection request',
    'inspection-request',
    'Capture name, phone, preferred unit type',
    '[{"name":"full_name","type":"text","required":true},{"name":"phone","type":"tel","required":true},{"name":"unit_interest","type":"select"}]'::jsonb,
    'Thanks — our sales team will confirm your slot.',
    2
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.form_submissions (id, form_id, payload, email, phone, source_path, status, submitted_at) VALUES
  (
    'd4800000-0000-4000-8000-000000000081',
    'd4800000-0000-4000-8000-000000000080',
    '{"full_name":"Tunde Adebayo","unit_interest":"3-bed"}'::jsonb,
    'tunde@example.com',
    '+2348011110001',
    '/landing/lekki-waterfront-launch',
    'new',
    now() - interval '6 hours'
  ),
  (
    'd4800000-0000-4000-8000-000000000082',
    'd4800000-0000-4000-8000-000000000080',
    '{"full_name":"Ngozi Ike","unit_interest":"penthouse"}'::jsonb,
    'ngozi@example.com',
    '+2348022220002',
    '/landing/lekki-waterfront-launch',
    'contacted',
    now() - interval '1 day'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.seo_metadata (
  id, entity_type, entity_id, path, meta_title, meta_description, health_score, issue_count, issues, last_audit_at
) VALUES
  (
    'd4800000-0000-4000-8000-000000000090',
    'landing_page',
    'd4800000-0000-4000-8000-000000000030',
    '/landing/lekki-waterfront-launch',
    'Lekki Waterfront Homes | HD Homes',
    'Explore limited waterfront villas with smart financing from HD Homes.',
    86.0,
    1,
    '[{"code":"og_image_missing","severity":"info"}]'::jsonb,
    now() - interval '12 hours'
  ),
  (
    'd4800000-0000-4000-8000-000000000091',
    'blog',
    'd4800000-0000-4000-8000-000000000040',
    '/blog/why-lekki-still-leads-coastal-demand',
    'Why Lekki still leads coastal demand',
    'Draft SEO stub — expand meta description before publish.',
    58.0,
    2,
    '[{"code":"meta_short","severity":"warning"},{"code":"draft_noindex","severity":"info"}]'::jsonb,
    now() - interval '2 hours'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.redirects (id, from_path, to_path, status_code, notes) VALUES
  (
    'd4800000-0000-4000-8000-0000000000a0',
    '/old-lekki-launch',
    '/landing/lekki-waterfront-launch',
    301,
    'Legacy campaign URL'
  ),
  (
    'd4800000-0000-4000-8000-0000000000a1',
    '/promo/q2',
    '/landing/investor-open-day',
    302,
    'Temporary Q2 promo hop'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ab_tests (
  id, name, slug, hypothesis, entity_type, entity_id,
  variant_a, variant_b, status, traffic_split, primary_metric, metadata
) VALUES
  (
    'd4800000-0000-4000-8000-0000000000b0',
    'CTA copy — Book vs Reserve',
    'cta-book-vs-reserve',
    '“Book inspection” will convert higher than “Reserve a tour” on waterfront LP.',
    'landing_page',
    'd4800000-0000-4000-8000-000000000030',
    '{"cta":"Book inspection"}'::jsonb,
    '{"cta":"Reserve a tour"}'::jsonb,
    'running',
    50,
    'conversion_rate',
    '{"ai_generated":false}'::jsonb
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.content_calendar (
  id, title, channel, content_type, scheduled_for, status, owner_label, related_entity_type, related_entity_id, notes
) VALUES
  (
    'd4800000-0000-4000-8000-0000000000c0',
    'Publish Lekki coastal demand draft',
    'blog',
    'post',
    now() + interval '3 days',
    'planned',
    'Editorial',
    'blog',
    'd4800000-0000-4000-8000-000000000040',
    'Human edit required — AI outline present'
  ),
  (
    'd4800000-0000-4000-8000-0000000000c1',
    'WhatsApp brochure nurture send',
    'whatsapp',
    'campaign',
    now() + interval '1 day',
    'scheduled',
    'Marketing Ops',
    'whatsapp_campaign',
    'd4800000-0000-4000-8000-000000000073',
    NULL
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.dxp_personalization_rules (
  id, name, slug, target_entity_type, target_entity_id, conditions, actions, priority
) VALUES
  (
    'd4800000-0000-4000-8000-0000000000d0',
    'Investor-intent hero swap',
    'investor-intent-hero',
    'landing_page',
    'd4800000-0000-4000-8000-000000000031',
    '{"utm_campaign":"investor"}'::jsonb,
    '{"hero_variant":"investor_open_day"}'::jsonb,
    10
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.marketing_analytics (
  id, metric_key, metric_label, metric_value, unit, period_start, period_end, dimensions
) VALUES
  ('d4800000-0000-4000-8000-0000000000e0', 'sessions', 'Sessions', 28420, 'count', CURRENT_DATE - 30, CURRENT_DATE, '{"channel":"organic"}'::jsonb),
  ('d4800000-0000-4000-8000-0000000000e1', 'leads', 'Form leads', 186, 'count', CURRENT_DATE - 30, CURRENT_DATE, '{"source":"landing"}'::jsonb),
  ('d4800000-0000-4000-8000-0000000000e2', 'conversion_rate', 'Conversion rate', 3.4, 'percent', CURRENT_DATE - 30, CURRENT_DATE, '{}'::jsonb),
  ('d4800000-0000-4000-8000-0000000000e3', 'funnel_awareness', 'Funnel — Awareness', 128400, 'count', CURRENT_DATE - 30, CURRENT_DATE, '{"stage":"awareness"}'::jsonb),
  ('d4800000-0000-4000-8000-0000000000e4', 'funnel_consideration', 'Funnel — Consideration', 4120, 'count', CURRENT_DATE - 30, CURRENT_DATE, '{"stage":"consideration"}'::jsonb),
  ('d4800000-0000-4000-8000-0000000000e5', 'funnel_conversion', 'Funnel — Conversion', 186, 'count', CURRENT_DATE - 30, CURRENT_DATE, '{"stage":"conversion"}'::jsonb)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.marketing_activity_logs (id, action, summary, actor_label, entity_type, entity_id, occurred_at) VALUES
  (
    'd4800000-0000-4000-8000-0000000000f0',
    'landing.published',
    'Published Lekki Waterfront Launch landing page',
    'Marketing Ops',
    'landing_page',
    'd4800000-0000-4000-8000-000000000030',
    now() - interval '3 days'
  ),
  (
    'd4800000-0000-4000-8000-0000000000f1',
    'campaign.email.sent',
    'Sent Waterfront email wave 1',
    'System',
    'email_campaign',
    'd4800000-0000-4000-8000-000000000071',
    now() - interval '2 days'
  ),
  (
    'd4800000-0000-4000-8000-0000000000f2',
    'form.submission',
    'New inspection request from Tunde Adebayo',
    'Public web',
    'form_submission',
    'd4800000-0000-4000-8000-000000000081',
    now() - interval '6 hours'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.marketing_notifications (id, title, body, severity, category) VALUES
  (
    'd4800000-0000-4000-8000-0000000000f8',
    'SEO watch — draft blog',
    'Draft blog meta score is 58 — expand description before publish.',
    'warning',
    'seo'
  ),
  (
    'd4800000-0000-4000-8000-0000000000f9',
    'Form spike',
    'Two inspection submissions in the last day on waterfront LP.',
    'info',
    'forms'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.social_accounts (id, platform, handle, display_name, is_connected) VALUES
  ('d4800000-0000-4000-8000-000000000100', 'instagram', '@hdhomesng', 'HD Homes Nigeria', true)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.cms_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cms_page_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cms_sections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.landing_pages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.landing_page_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blog_authors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blog_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blog_tag_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.media_folders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.seo_metadata ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.redirects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audience_segments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.campaign_audiences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sms_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whatsapp_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.push_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.forms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.form_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dxp_personalization_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ab_tests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_calendar ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.social_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.social_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketing_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketing_activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketing_notifications ENABLE ROW LEVEL SECURITY;

-- Helper macro style: read / write policies per table

DROP POLICY IF EXISTS cms_templates_select ON public.cms_templates;
DROP POLICY IF EXISTS cms_templates_write ON public.cms_templates;
CREATE POLICY cms_templates_select ON public.cms_templates FOR SELECT
  USING (public.has_permission('marketing.read', auth.uid()) OR public.has_permission('marketing.cms', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY cms_templates_write ON public.cms_templates FOR ALL
  USING (public.has_permission('marketing.cms', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.cms', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS cms_page_versions_select ON public.cms_page_versions;
DROP POLICY IF EXISTS cms_page_versions_write ON public.cms_page_versions;
CREATE POLICY cms_page_versions_select ON public.cms_page_versions FOR SELECT
  USING (public.has_permission('marketing.read', auth.uid()) OR public.has_permission('marketing.cms', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY cms_page_versions_write ON public.cms_page_versions FOR ALL
  USING (public.has_permission('marketing.cms', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.cms', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS cms_sections_select ON public.cms_sections;
DROP POLICY IF EXISTS cms_sections_write ON public.cms_sections;
CREATE POLICY cms_sections_select ON public.cms_sections FOR SELECT
  USING (public.has_permission('marketing.read', auth.uid()) OR public.has_permission('marketing.cms', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY cms_sections_write ON public.cms_sections FOR ALL
  USING (public.has_permission('marketing.cms', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.cms', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS landing_pages_select ON public.landing_pages;
DROP POLICY IF EXISTS landing_pages_write ON public.landing_pages;
CREATE POLICY landing_pages_select ON public.landing_pages FOR SELECT
  USING (
    is_published = true
    OR public.has_permission('marketing.read', auth.uid())
    OR public.has_permission('marketing.cms', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY landing_pages_write ON public.landing_pages FOR ALL
  USING (
    public.has_permission('marketing.cms', auth.uid())
    OR public.has_permission('marketing.publish', auth.uid())
    OR public.has_permission('marketing.write', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('marketing.cms', auth.uid())
    OR public.has_permission('marketing.publish', auth.uid())
    OR public.has_permission('marketing.write', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

DROP POLICY IF EXISTS landing_page_versions_select ON public.landing_page_versions;
DROP POLICY IF EXISTS landing_page_versions_write ON public.landing_page_versions;
CREATE POLICY landing_page_versions_select ON public.landing_page_versions FOR SELECT
  USING (public.has_permission('marketing.read', auth.uid()) OR public.has_permission('marketing.cms', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY landing_page_versions_write ON public.landing_page_versions FOR ALL
  USING (public.has_permission('marketing.cms', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.cms', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS blog_authors_select ON public.blog_authors;
DROP POLICY IF EXISTS blog_authors_write ON public.blog_authors;
CREATE POLICY blog_authors_select ON public.blog_authors FOR SELECT
  USING (true);
CREATE POLICY blog_authors_write ON public.blog_authors FOR ALL
  USING (public.has_permission('marketing.cms', auth.uid()) OR public.has_permission('manage_blog', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.cms', auth.uid()) OR public.has_permission('manage_blog', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS blog_tags_select ON public.blog_tags;
DROP POLICY IF EXISTS blog_tags_write ON public.blog_tags;
CREATE POLICY blog_tags_select ON public.blog_tags FOR SELECT USING (true);
CREATE POLICY blog_tags_write ON public.blog_tags FOR ALL
  USING (public.has_permission('marketing.cms', auth.uid()) OR public.has_permission('manage_blog', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.cms', auth.uid()) OR public.has_permission('manage_blog', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS blog_tag_links_select ON public.blog_tag_links;
DROP POLICY IF EXISTS blog_tag_links_write ON public.blog_tag_links;
CREATE POLICY blog_tag_links_select ON public.blog_tag_links FOR SELECT USING (true);
CREATE POLICY blog_tag_links_write ON public.blog_tag_links FOR ALL
  USING (public.has_permission('marketing.cms', auth.uid()) OR public.has_permission('manage_blog', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.cms', auth.uid()) OR public.has_permission('manage_blog', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS media_folders_select ON public.media_folders;
DROP POLICY IF EXISTS media_folders_write ON public.media_folders;
CREATE POLICY media_folders_select ON public.media_folders FOR SELECT
  USING (public.has_permission('marketing.read', auth.uid()) OR public.has_permission('marketing.media', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY media_folders_write ON public.media_folders FOR ALL
  USING (public.has_permission('marketing.media', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.media', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS seo_metadata_select ON public.seo_metadata;
DROP POLICY IF EXISTS seo_metadata_write ON public.seo_metadata;
CREATE POLICY seo_metadata_select ON public.seo_metadata FOR SELECT
  USING (public.has_permission('marketing.read', auth.uid()) OR public.has_permission('marketing.seo', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY seo_metadata_write ON public.seo_metadata FOR ALL
  USING (public.has_permission('marketing.seo', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.seo', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS redirects_select ON public.redirects;
DROP POLICY IF EXISTS redirects_write ON public.redirects;
CREATE POLICY redirects_select ON public.redirects FOR SELECT
  USING (public.has_permission('marketing.read', auth.uid()) OR public.has_permission('marketing.seo', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY redirects_write ON public.redirects FOR ALL
  USING (public.has_permission('marketing.seo', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.seo', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS audience_segments_select ON public.audience_segments;
DROP POLICY IF EXISTS audience_segments_write ON public.audience_segments;
CREATE POLICY audience_segments_select ON public.audience_segments FOR SELECT
  USING (public.has_permission('marketing.read', auth.uid()) OR public.has_permission('marketing.campaigns', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY audience_segments_write ON public.audience_segments FOR ALL
  USING (public.has_permission('marketing.campaigns', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.campaigns', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS campaign_audiences_select ON public.campaign_audiences;
DROP POLICY IF EXISTS campaign_audiences_write ON public.campaign_audiences;
CREATE POLICY campaign_audiences_select ON public.campaign_audiences FOR SELECT
  USING (public.has_permission('marketing.read', auth.uid()) OR public.has_permission('marketing.campaigns', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY campaign_audiences_write ON public.campaign_audiences FOR ALL
  USING (public.has_permission('marketing.campaigns', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.campaigns', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS email_templates_select ON public.email_templates;
DROP POLICY IF EXISTS email_templates_write ON public.email_templates;
CREATE POLICY email_templates_select ON public.email_templates FOR SELECT
  USING (public.has_permission('marketing.read', auth.uid()) OR public.has_permission('marketing.campaigns', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY email_templates_write ON public.email_templates FOR ALL
  USING (public.has_permission('marketing.campaigns', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.campaigns', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS email_campaigns_select ON public.email_campaigns;
DROP POLICY IF EXISTS email_campaigns_write ON public.email_campaigns;
CREATE POLICY email_campaigns_select ON public.email_campaigns FOR SELECT
  USING (public.has_permission('marketing.read', auth.uid()) OR public.has_permission('marketing.campaigns', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY email_campaigns_write ON public.email_campaigns FOR ALL
  USING (public.has_permission('marketing.campaigns', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.campaigns', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS sms_campaigns_select ON public.sms_campaigns;
DROP POLICY IF EXISTS sms_campaigns_write ON public.sms_campaigns;
CREATE POLICY sms_campaigns_select ON public.sms_campaigns FOR SELECT
  USING (public.has_permission('marketing.read', auth.uid()) OR public.has_permission('marketing.campaigns', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY sms_campaigns_write ON public.sms_campaigns FOR ALL
  USING (public.has_permission('marketing.campaigns', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.campaigns', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS whatsapp_campaigns_select ON public.whatsapp_campaigns;
DROP POLICY IF EXISTS whatsapp_campaigns_write ON public.whatsapp_campaigns;
CREATE POLICY whatsapp_campaigns_select ON public.whatsapp_campaigns FOR SELECT
  USING (public.has_permission('marketing.read', auth.uid()) OR public.has_permission('marketing.campaigns', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY whatsapp_campaigns_write ON public.whatsapp_campaigns FOR ALL
  USING (public.has_permission('marketing.campaigns', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.campaigns', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS push_campaigns_select ON public.push_campaigns;
DROP POLICY IF EXISTS push_campaigns_write ON public.push_campaigns;
CREATE POLICY push_campaigns_select ON public.push_campaigns FOR SELECT
  USING (public.has_permission('marketing.read', auth.uid()) OR public.has_permission('marketing.campaigns', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY push_campaigns_write ON public.push_campaigns FOR ALL
  USING (public.has_permission('marketing.campaigns', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.campaigns', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS forms_select ON public.forms;
DROP POLICY IF EXISTS forms_write ON public.forms;
CREATE POLICY forms_select ON public.forms FOR SELECT
  USING (
    is_active = true
    OR public.has_permission('marketing.read', auth.uid())
    OR public.has_permission('marketing.forms', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY forms_write ON public.forms FOR ALL
  USING (public.has_permission('marketing.forms', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.forms', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS form_submissions_select ON public.form_submissions;
DROP POLICY IF EXISTS form_submissions_insert ON public.form_submissions;
DROP POLICY IF EXISTS form_submissions_write ON public.form_submissions;
CREATE POLICY form_submissions_select ON public.form_submissions FOR SELECT
  USING (public.has_permission('marketing.read', auth.uid()) OR public.has_permission('marketing.forms', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY form_submissions_insert ON public.form_submissions FOR INSERT
  WITH CHECK (true);
CREATE POLICY form_submissions_write ON public.form_submissions FOR UPDATE
  USING (public.has_permission('marketing.forms', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.forms', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS dxp_personalization_rules_select ON public.dxp_personalization_rules;
DROP POLICY IF EXISTS dxp_personalization_rules_write ON public.dxp_personalization_rules;
CREATE POLICY dxp_personalization_rules_select ON public.dxp_personalization_rules FOR SELECT
  USING (public.has_permission('marketing.read', auth.uid()) OR public.has_permission('marketing.cms', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY dxp_personalization_rules_write ON public.dxp_personalization_rules FOR ALL
  USING (public.has_permission('marketing.cms', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.cms', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ab_tests_select ON public.ab_tests;
DROP POLICY IF EXISTS ab_tests_write ON public.ab_tests;
CREATE POLICY ab_tests_select ON public.ab_tests FOR SELECT
  USING (public.has_permission('marketing.read', auth.uid()) OR public.has_permission('marketing.analytics', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ab_tests_write ON public.ab_tests FOR ALL
  USING (public.has_permission('marketing.analytics', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.analytics', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS content_calendar_select ON public.content_calendar;
DROP POLICY IF EXISTS content_calendar_write ON public.content_calendar;
CREATE POLICY content_calendar_select ON public.content_calendar FOR SELECT
  USING (public.has_permission('marketing.read', auth.uid()) OR public.has_permission('marketing.cms', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY content_calendar_write ON public.content_calendar FOR ALL
  USING (public.has_permission('marketing.cms', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.cms', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS social_accounts_select ON public.social_accounts;
DROP POLICY IF EXISTS social_accounts_write ON public.social_accounts;
CREATE POLICY social_accounts_select ON public.social_accounts FOR SELECT
  USING (public.has_permission('marketing.read', auth.uid()) OR public.has_permission('marketing.social', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY social_accounts_write ON public.social_accounts FOR ALL
  USING (public.has_permission('marketing.social', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.social', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS social_posts_select ON public.social_posts;
DROP POLICY IF EXISTS social_posts_write ON public.social_posts;
CREATE POLICY social_posts_select ON public.social_posts FOR SELECT
  USING (public.has_permission('marketing.read', auth.uid()) OR public.has_permission('marketing.social', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY social_posts_write ON public.social_posts FOR ALL
  USING (public.has_permission('marketing.social', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.social', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS marketing_analytics_select ON public.marketing_analytics;
DROP POLICY IF EXISTS marketing_analytics_write ON public.marketing_analytics;
CREATE POLICY marketing_analytics_select ON public.marketing_analytics FOR SELECT
  USING (public.has_permission('marketing.read', auth.uid()) OR public.has_permission('marketing.analytics', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY marketing_analytics_write ON public.marketing_analytics FOR ALL
  USING (public.has_permission('marketing.analytics', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.analytics', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS marketing_activity_logs_select ON public.marketing_activity_logs;
DROP POLICY IF EXISTS marketing_activity_logs_write ON public.marketing_activity_logs;
CREATE POLICY marketing_activity_logs_select ON public.marketing_activity_logs FOR SELECT
  USING (public.has_permission('marketing.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY marketing_activity_logs_write ON public.marketing_activity_logs FOR ALL
  USING (public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS marketing_notifications_select ON public.marketing_notifications;
DROP POLICY IF EXISTS marketing_notifications_write ON public.marketing_notifications;
CREATE POLICY marketing_notifications_select ON public.marketing_notifications FOR SELECT
  USING (public.has_permission('marketing.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY marketing_notifications_write ON public.marketing_notifications FOR ALL
  USING (public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

-- Enrichment policies on legacy campaigns / seo / pages for marketing.* staff
DROP POLICY IF EXISTS campaigns_marketing_select ON public.campaigns;
DROP POLICY IF EXISTS campaigns_marketing_write ON public.campaigns;
CREATE POLICY campaigns_marketing_select ON public.campaigns FOR SELECT
  USING (
    public.has_permission('marketing.read', auth.uid())
    OR public.has_permission('marketing.campaigns', auth.uid())
    OR public.has_permission('manage_marketing', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY campaigns_marketing_write ON public.campaigns FOR ALL
  USING (
    public.has_permission('marketing.campaigns', auth.uid())
    OR public.has_permission('marketing.write', auth.uid())
    OR public.has_permission('manage_marketing', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('marketing.campaigns', auth.uid())
    OR public.has_permission('marketing.write', auth.uid())
    OR public.has_permission('manage_marketing', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

-- Grants
GRANT SELECT, INSERT, UPDATE, DELETE ON public.cms_templates TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.cms_page_versions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.cms_sections TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.landing_pages TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.landing_page_versions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.blog_authors TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.blog_tags TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.blog_tag_links TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.media_folders TO authenticated;
GRANT SELECT ON public.media_library TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.seo_metadata TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.redirects TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.audience_segments TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.campaign_audiences TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.email_templates TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.email_campaigns TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.sms_campaigns TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.whatsapp_campaigns TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.push_campaigns TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.forms TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.form_submissions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.dxp_personalization_rules TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.ab_tests TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.content_calendar TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.social_accounts TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.social_posts TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.marketing_analytics TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.marketing_activity_logs TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.marketing_notifications TO authenticated;

-- Public anon can insert form submissions + read published landing pages (via RLS)
GRANT SELECT ON public.landing_pages TO anon;
GRANT SELECT ON public.forms TO anon;
GRANT INSERT ON public.form_submissions TO anon;
GRANT SELECT ON public.blog_authors TO anon;
GRANT SELECT ON public.blog_tags TO anon;
GRANT SELECT ON public.blog_tag_links TO anon;

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'landing_pages',
    'forms',
    'form_submissions',
    'campaigns',
    'email_campaigns',
    'content_calendar',
    'marketing_activity_logs',
    'blogs'
  ]
  LOOP
    BEGIN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    EXCEPTION WHEN duplicate_object THEN
      NULL;
    END;
  END LOOP;
END $$;

COMMIT;

-- Status: LOCAL ONLY — await approve before remote apply.

-- Status: APPLIED remotely 2026-07-14 (chunked apply_migration p1–p3).
