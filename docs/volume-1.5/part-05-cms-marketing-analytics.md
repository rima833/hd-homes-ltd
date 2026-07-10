# Volume 1.5 – Part 5

# CMS, Marketing, Website Content & Analytics

**Status:** Draft — awaiting approval before any migration work.

**Depends on:** [Part 1](./part-01-philosophy-and-core-schema.md) · [Part 2](./part-02-property-estate-architecture.md)

> Part 6 of Volume 1.5 is still to come. This document is not the final blueprint volume.

---

## Module Overview

This module powers everything the public sees. It is an **Enterprise Headless CMS + Marketing Automation Platform** — not a basic content system.

| Surface | Capability |
|---------|------------|
| Public Website | Dynamic pages, hero sliders, navigation, footer |
| Homepage Builder | Drag-and-drop sections (Visual Page Builder) |
| Blog & News | Categories, tags, comments, scheduled publishing |
| Careers | Job listings and applications |
| Gallery | Albums with images, video, drone, 360° |
| Team | Leadership and staff profiles |
| Marketing | Campaigns, newsletter, promotions, landing pages |
| SEO | Per-page metadata, schema.org, robots |
| Analytics | Traffic, conversions, lead attribution |
| AI | Content generation tools (future-ready) |

**Goal:** Marketing team manages nearly every website aspect without developer assistance.

---

## Table Catalog

Part 5 defines **45+ tables** across CMS, marketing, media, analytics, and enterprise enhancements.

### Website CMS

| # | Table | Purpose |
|---|-------|---------|
| 1 | `pages` | All website pages |
| 2 | `page_sections` | Reusable page blocks (page builder) |
| 3 | `hero_sliders` | Homepage/marketing hero banners |
| 4 | `navigation_menus` | Header/footer nav items |
| 5 | `footer_config` | Editable footer (JSONB sections) |
| 6 | `services` | Business service listings |
| 7 | `team_members` | Employee profiles |
| 8 | `testimonials` | Client feedback |
| 9 | `faqs` | FAQ entries |
| 10 | `gallery_albums` | Media collections |
| 11 | `gallery_media` | Album media items |

### Blog

| # | Table | Purpose |
|---|-------|---------|
| 12 | `blog_categories` | Blog categories |
| 13 | `blog_posts` | Blog articles |
| 14 | `blog_tags` | Tag catalog |
| 15 | `blog_post_tags` | Post ↔ tag M2M |
| 16 | `blog_comments` | Moderated comments |

### Careers

| # | Table | Purpose |
|---|-------|---------|
| 17 | `careers` | Job openings |
| 18 | `job_applications` | Applicant submissions |

### Marketing

| # | Table | Purpose |
|---|-------|---------|
| 19 | `newsletter_subscribers` | Email subscribers |
| 20 | `email_campaigns` | Marketing email campaigns |
| 21 | `email_templates` | Reusable email templates |
| 22 | `landing_pages` | Dedicated campaign pages |
| 23 | `promotions` | Active promos and offers |
| 24 | `lead_attribution` | Lead source tracking |

### Media & SEO

| # | Table | Purpose |
|---|-------|---------|
| 25 | `media_library` | Central asset manager (extends Part 1 `media`) |
| 26 | `seo_metadata` | Polymorphic SEO per entity |

### Analytics

| # | Table | Purpose |
|---|-------|---------|
| 27 | `analytics_sessions` | Visitor sessions |
| 28 | `analytics_page_views` | Page view events |
| 29 | `analytics_events` | Custom conversion events |
| 30 | `marketing_reports` | Generated report metadata |

### Enterprise Enhancements

| # | Table | Purpose |
|---|-------|---------|
| 31 | `campaign_performance` | Campaign KPI aggregates |
| 32 | `ab_tests` | A/B test definitions |
| 33 | `ab_test_variants` | Test variations |
| 34 | `ab_test_results` | Engagement/conversion per variant |
| 35 | `personalization_rules` | Dynamic content rules |
| 36 | `ai_content_jobs` | AI generation task queue |
| 37 | `social_media_accounts` | Connected social accounts |
| 38 | `social_post_queue` | Scheduled social posts (future) |

> All tables include Part 1 audit fields unless noted append-only.

---

## Website CMS Tables

### 1. `pages`

**Purpose:** Every website page — dynamically managed, never hardcoded.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `title` | TEXT | NOT NULL | |
| `slug` | TEXT | UNIQUE, NOT NULL | |
| `page_type` | page_type | NOT NULL | Enum |
| `seo_title` | TEXT | | |
| `seo_description` | TEXT | | |
| `featured_image_id` | UUID | FK → media_library | |
| `content` | JSONB | DEFAULT `{}` | Legacy/fallback rich content |
| `status` | content_status | DEFAULT `draft` | Enum |
| `published_at` | TIMESTAMPTZ | | |
| `created_by` | UUID | FK → users | |
| `updated_by` | UUID | FK → users | |
| + audit fields | | | |

**Enum `page_type`:** `home`, `about`, `services`, `properties`, `estates`, `investment`, `gallery`, `blog`, `careers`, `contact`, `faq`, `privacy`, `terms`, `landing_page`, `custom`

**Enum `content_status`:** `draft`, `scheduled`, `published`, `archived`

**Indexes:** `idx_pages_slug`, `idx_pages_type_status (page_type, status)`

---

### 2. `page_sections`

**Purpose:** Reusable blocks for Visual Page Builder. Enables drag-and-drop assembly.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `page_id` | UUID | FK → pages, NOT NULL | |
| `section_type` | section_type | NOT NULL | Enum |
| `layout` | TEXT | DEFAULT `full_width` | `full_width`, `contained`, `split` |
| `display_order` | INT | DEFAULT 0 | |
| `settings_json` | JSONB | NOT NULL | Section-specific config |
| `status` | content_status | DEFAULT `published` | |
| + audit fields | | | |

**Enum `section_type`:** `hero`, `statistics`, `features`, `cta`, `testimonials`, `gallery`, `map`, `property_grid`, `video`, `faq`, `newsletter`, `partners`, `team`, `blog_feed`, `custom_html`, `estate_showcase`

**Example `settings_json` (property_grid):**

```json
{
  "estate_id": "uuid",
  "limit": 6,
  "featured_only": true,
  "columns": 3
}
```

---

### 3. `hero_sliders`

**Purpose:** Multiple hero banners (homepage, landing pages).

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `page_id` | UUID | FK → pages | NULL = global homepage |
| `title` | TEXT | NOT NULL | |
| `subtitle` | TEXT | | |
| `background_media_id` | UUID | FK → media_library | Image or video |
| `button_text` | TEXT | | CTA label |
| `button_link` | TEXT | | CTA URL |
| `overlay_opacity` | NUMERIC(3,2) | DEFAULT 0.4 | 0–1 |
| `display_order` | INT | DEFAULT 0 | |
| `status` | content_status | DEFAULT `published` | |
| + audit fields | | | |

**Supports:** Images, videos, Lottie animations (via media type), 3D backgrounds (future).

---

### 4. `navigation_menus`

**Purpose:** Admin-managed navigation with nesting.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `menu_name` | TEXT | NOT NULL | Display label |
| `menu_location` | menu_location | NOT NULL | Enum |
| `parent_id` | UUID | FK → navigation_menus | Nested items |
| `page_id` | UUID | FK → pages | Internal link |
| `url` | TEXT | | External or override URL |
| `icon` | TEXT | | Lucide icon name |
| `display_order` | INT | DEFAULT 0 | |
| `target` | TEXT | DEFAULT `_self` | `_blank` for external |
| `visibility` | menu_visibility | DEFAULT `public` | Enum |
| `status` | content_status | DEFAULT `published` | |
| + audit fields | | | |

**Enum `menu_location`:** `header`, `footer`, `mobile`, `sidebar`

**Enum `menu_visibility`:** `public`, `authenticated`, `client`, `investor`, `staff`

---

### 5. `footer_config`

**Purpose:** Single-row (or keyed) editable footer configuration.

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `key` | TEXT | UNIQUE — `main_footer` |
| `company_info` | JSONB | Name, tagline, logo_media_id |
| `addresses` | JSONB | `[{label, address, phone}]` |
| `social_links` | JSONB | `[{platform, url}]` |
| `quick_links` | JSONB | `[{label, url}]` |
| `legal_links` | JSONB | Privacy, Terms |
| `newsletter_enabled` | BOOLEAN | DEFAULT true |
| + audit fields | | |

> Replaces scattered `social_links` table with structured footer config. Legacy `social_links` may remain for backward compatibility.

---

### 6. `services`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `title` | TEXT | NOT NULL | |
| `slug` | TEXT | UNIQUE, NOT NULL | |
| `description` | TEXT | | |
| `icon` | TEXT | | |
| `cover_image_id` | UUID | FK → media_library | |
| `featured` | BOOLEAN | DEFAULT false | |
| `display_order` | INT | DEFAULT 0 | |
| `status` | content_status | DEFAULT `published` | |
| + audit fields | | | |

**Seed examples:** Property Sales, Property Development, Construction, Investment Advisory, Facility Management, Property Valuation, Architectural Design, Interior Design, Property Management

---

### 7. `team_members`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `first_name` | TEXT | NOT NULL | |
| `last_name` | TEXT | NOT NULL | |
| `position` | TEXT | NOT NULL | |
| `department` | TEXT | | |
| `biography` | TEXT | | |
| `photo_id` | UUID | FK → media_library | |
| `linkedin_url` | TEXT | | |
| `email` | TEXT | | |
| `phone` | TEXT | | |
| `display_order` | INT | DEFAULT 0 | |
| `status` | content_status | DEFAULT `published` | |
| + audit fields | | | |

**Storage bucket:** `team`

---

### 8. `testimonials`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `client_name` | TEXT | NOT NULL | |
| `client_photo_id` | UUID | FK → media_library | |
| `property_id` | UUID | FK → properties | Optional link |
| `rating` | INT | CHECK 1–5 | |
| `review` | TEXT | NOT NULL | |
| `video_id` | UUID | FK → media_library | Video testimonial |
| `featured` | BOOLEAN | DEFAULT false | |
| `approved` | BOOLEAN | DEFAULT false | Moderation |
| + audit fields | | | |

**Supports:** Text, video, audio (via media type).

---

### 9. `faqs`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `category` | faq_category | NOT NULL | Enum |
| `question` | TEXT | NOT NULL | |
| `answer` | TEXT | NOT NULL | |
| `display_order` | INT | DEFAULT 0 | |
| `status` | content_status | DEFAULT `published` | |
| + audit fields | | | |

**Enum `faq_category`:** `buying`, `investment`, `construction`, `payments`, `legal`, `support`

---

### 10–11. Gallery

#### `gallery_albums`

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `album_name` | TEXT | NOT NULL |
| `slug` | TEXT | UNIQUE |
| `description` | TEXT | |
| `cover_media_id` | UUID | FK → media_library |
| `album_type` | gallery_album_type | Enum |
| `status` | content_status | |
| + audit fields | | |

**Enum `gallery_album_type`:** `completed_projects`, `construction_updates`, `property_showcase`, `events`, `team`, `awards`

#### `gallery_media`

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `gallery_id` | UUID | FK → gallery_albums |
| `media_id` | UUID | FK → media_library |
| `caption` | TEXT | |
| `display_order` | INT | |

**Supports:** Images, videos, drone footage, virtual tours, 360° media.

---

## Blog System

### 12. `blog_categories`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | UUID | PK |
| `name` | TEXT | NOT NULL |
| `slug` | TEXT | UNIQUE, NOT NULL |
| `description` | TEXT | |
| + audit fields | | |

**Examples:** Real Estate, Investment, Construction, Company News, Market Insights, Home Ownership

---

### 13. `blog_posts`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `category_id` | UUID | FK → blog_categories | |
| `author_id` | UUID | FK → users | |
| `title` | TEXT | NOT NULL | |
| `slug` | TEXT | UNIQUE, NOT NULL | |
| `excerpt` | TEXT | | |
| `content` | JSONB | NOT NULL | Rich text blocks |
| `featured_image_id` | UUID | FK → media_library | |
| `reading_time` | INT | | Minutes, auto-calculated |
| `featured` | BOOLEAN | DEFAULT false | |
| `status` | content_status | DEFAULT `draft` | |
| `published_at` | TIMESTAMPTZ | | Scheduled publish |
| `search_vector` | TSVECTOR | | Full-text search |
| + audit fields | | | |

---

### 14–15. `blog_tags` + `blog_post_tags`

**Tags:** Luxury, Investment, Mortgage, Lagos, Abuja, Real Estate Tips

M2M via `blog_post_tags (post_id, tag_id)`.

---

### 16. `blog_comments`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | UUID | PK |
| `blog_id` | UUID | FK → blog_posts, NOT NULL |
| `user_id` | UUID | FK → users |
| `author_name` | TEXT | Guest comments |
| `comment` | TEXT | NOT NULL |
| `approved` | BOOLEAN | DEFAULT false |
| `created_at` | TIMESTAMPTZ | |

**RLS:** Public INSERT; SELECT only `approved = true`.

---

## Careers

### 17. `careers`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `title` | TEXT | NOT NULL | |
| `slug` | TEXT | UNIQUE | |
| `department` | TEXT | | |
| `location` | TEXT | | |
| `employment_type` | TEXT | | `full_time`, `part_time`, `contract` |
| `salary_range` | TEXT | | e.g. `₦500k–₦800k` |
| `description` | JSONB | | Rich content |
| `closing_date` | DATE | | |
| `status` | content_status | DEFAULT `published` | |
| + audit fields | | | |

---

### 18. `job_applications`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `job_id` | UUID | FK → careers, NOT NULL | |
| `applicant_name` | TEXT | NOT NULL | |
| `email` | TEXT | NOT NULL | |
| `phone` | TEXT | | |
| `cv_media_id` | UUID | FK → media_library | |
| `cover_letter` | TEXT | | |
| `status` | application_status | DEFAULT `submitted` | Enum |
| `submitted_at` | TIMESTAMPTZ | DEFAULT now() | |
| + audit fields | | | |

**Enum `application_status`:** `submitted`, `reviewing`, `shortlisted`, `interview`, `offered`, `rejected`, `hired`

**RLS:** HR team + admin; applicants see own submission.

---

## Marketing Tables

### 19. `newsletter_subscribers`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `email` | TEXT | UNIQUE, NOT NULL | |
| `full_name` | TEXT | | |
| `status` | subscriber_status | DEFAULT `active` | Enum |
| `source` | TEXT | | `website`, `landing_page`, `referral` |
| `subscribed_at` | TIMESTAMPTZ | DEFAULT now() | |
| `unsubscribed_at` | TIMESTAMPTZ | | |
| + audit fields | | | |

**Enum `subscriber_status`:** `active`, `unsubscribed`, `bounced`

---

### 20. `email_campaigns`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `campaign_name` | TEXT | NOT NULL | |
| `subject` | TEXT | NOT NULL | |
| `template_id` | UUID | FK → email_templates | |
| `audience_filter` | JSONB | DEFAULT `{}` | Segment rules |
| `scheduled_at` | TIMESTAMPTZ | | |
| `sent_at` | TIMESTAMPTZ | | |
| `status` | campaign_status | DEFAULT `draft` | Enum |
| + audit fields | | | |

**Enum `campaign_status`:** `draft`, `scheduled`, `sending`, `sent`, `failed`, `cancelled`

---

### 21. `email_templates`

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `name` | TEXT | NOT NULL |
| `subject_template` | TEXT | |
| `body_html` | TEXT | |
| `body_json` | JSONB | Block-based template |
| + audit fields | | |

---

### 22. `landing_pages`

**Purpose:** Dedicated marketing pages with independent SEO.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `page_id` | UUID | FK → pages, UNIQUE | Links to `pages` with `page_type = landing_page` |
| `campaign_id` | UUID | FK → email_campaigns | Optional |
| `promotion_id` | UUID | FK → promotions | Optional |
| `conversion_goal` | TEXT | | `lead`, `newsletter`, `inspection` |
| `utm_defaults` | JSONB | DEFAULT `{}` | Default UTM params |
| + audit fields | | | |

**Examples:** New Estate Launch, Investment Campaign, Black Friday, Referral Program, Webinar Registration

---

### 23. `promotions`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `title` | TEXT | NOT NULL | |
| `slug` | TEXT | UNIQUE | |
| `promotion_type` | promotion_type | NOT NULL | Enum |
| `description` | TEXT | | |
| `terms` | TEXT | | |
| `discount_value` | NUMERIC(15,2) | | |
| `discount_percent` | NUMERIC(5,2) | | |
| `starts_at` | TIMESTAMPTZ | | |
| `ends_at` | TIMESTAMPTZ | | |
| `status` | content_status | DEFAULT `published` | |
| + audit fields | | | |

**Enum `promotion_type`:** `discount`, `installment_promo`, `referral_bonus`, `free_documentation`, `holiday_campaign`

**Automation:** Cron archives expired promotions (`ends_at < now()`).

---

### 24. `lead_attribution`

**Purpose:** Track where every lead originated.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `lead_id` | UUID | FK → leads (Part 3) | |
| `source` | attribution_source | NOT NULL | Enum |
| `medium` | TEXT | | `cpc`, `organic`, `email` |
| `campaign` | TEXT | | UTM campaign |
| `content` | TEXT | | UTM content |
| `landing_page_id` | UUID | FK → landing_pages | |
| `referrer_url` | TEXT | | |
| `created_at` | TIMESTAMPTZ | DEFAULT now() | Append-only |

**Enum `attribution_source`:** `google`, `facebook`, `instagram`, `whatsapp`, `referral`, `direct`, `email`, `youtube`, `linkedin`, `tiktok`, `other`

---

## Media Library

### 25. `media_library`

**Purpose:** Central asset manager (extends Part 1 `media` table).

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `file_name` | TEXT | NOT NULL | |
| `alt_text` | TEXT | | Accessibility + AI |
| `tags` | TEXT[] | DEFAULT `{}` | |
| `media_category` | media_category | | Enum |
| `bucket` | TEXT | NOT NULL | |
| `path` | TEXT | NOT NULL | |
| `mime_type` | TEXT | | |
| `size` | BIGINT | | Bytes |
| `width` | INT | | Images |
| `height` | INT | | Images |
| `duration` | INT | | Videos (seconds) |
| `uploaded_by` | UUID | FK → users | |
| + audit fields | | | |

**Enum `media_category`:** `image`, `video`, `pdf`, `floor_plan`, `logo`, `document`, `icon`, `brand_asset`, `lottie`, `audio`

**Storage buckets:** `marketing`, `blog-images`, `gallery`, `logos`, `team`, `downloads`

---

## SEO Management

### 26. `seo_metadata`

**Purpose:** Polymorphic SEO for any entity (pages, blog posts, properties, estates).

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `entity_type` | TEXT | NOT NULL | `page`, `blog_post`, `property`, `estate` |
| `entity_id` | UUID | NOT NULL | |
| `seo_title` | TEXT | | |
| `seo_description` | TEXT | | |
| `keywords` | TEXT[] | | |
| `canonical_url` | TEXT | | |
| `og_image_id` | UUID | FK → media_library | |
| `twitter_card` | TEXT | DEFAULT `summary_large_image` | |
| `structured_data` | JSONB | DEFAULT `{}` | Schema.org JSON-LD |
| `robots` | TEXT | DEFAULT `index, follow` | |
| `is_indexed` | BOOLEAN | DEFAULT true | |
| + audit fields | | | |

**Unique:** `(entity_type, entity_id)`

**Automation:** AI suggests `seo_title` and `seo_description` on publish.

---

## Analytics Tables

### 27. `analytics_sessions`

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `session_id` | TEXT | UNIQUE |
| `user_id` | UUID | FK → users (nullable) |
| `started_at` | TIMESTAMPTZ | |
| `ended_at` | TIMESTAMPTZ | |
| `page_count` | INT | DEFAULT 0 |
| `source` | attribution_source | |
| `medium` | TEXT | |
| `campaign` | TEXT | |
| `device` | TEXT | |
| `browser` | TEXT | |
| `country` | TEXT | |
| `city` | TEXT | |

---

### 28. `analytics_page_views`

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `session_id` | TEXT | FK → analytics_sessions |
| `page_path` | TEXT | NOT NULL |
| `page_title` | TEXT | |
| `entity_type` | TEXT | |
| `entity_id` | UUID | |
| `viewed_at` | TIMESTAMPTZ | |
| `time_on_page` | INT | Seconds |

**Extends live `visitor_statistics` and `property_views` with richer session context.**

---

### 29. `analytics_events`

**Purpose:** Custom conversion events.

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `session_id` | TEXT | |
| `event_name` | TEXT | `inquiry_submit`, `newsletter_signup`, `inspection_book` |
| `entity_type` | TEXT | |
| `entity_id` | UUID | |
| `metadata` | JSONB | |
| `created_at` | TIMESTAMPTZ | |

---

### 30. `marketing_reports`

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `report_type` | marketing_report_type | Enum |
| `title` | TEXT | |
| `period_start` | DATE | |
| `period_end` | DATE | |
| `media_id` | UUID | PDF/Excel export |
| `generated_at` | TIMESTAMPTZ | |

**Enum `marketing_report_type`:** `website_performance`, `seo`, `campaign_roi`, `blog_performance`, `lead_sources`, `newsletter_metrics`, `social_growth`, `engagement`

**Export formats:** PDF, Excel, CSV (via Edge Function).

---

## Enterprise Enhancements

### 31. Visual Page Builder

Implemented via `page_sections` + `settings_json`. Flutter admin renders a drag-and-drop canvas that reorders sections and persists `display_order`.

No additional table required — `page_sections` is the foundation.

---

### 32. `campaign_performance`

**Purpose:** Campaign Performance Hub — unified marketing KPI dashboard.

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `campaign_id` | UUID | FK → email_campaigns or promotions |
| `campaign_type` | TEXT | `email`, `promotion`, `landing_page` |
| `impressions` | INT | DEFAULT 0 |
| `clicks` | INT | DEFAULT 0 |
| `leads_generated` | INT | DEFAULT 0 |
| `cost` | NUMERIC(15,2) | Ad spend if tracked |
| `revenue_attributed` | NUMERIC(15,2) | |
| `conversion_rate` | NUMERIC(5,4) | Computed |
| `cost_per_lead` | NUMERIC(15,2) | Computed |
| `period_date` | DATE | Daily aggregate |
| `updated_at` | TIMESTAMPTZ | |

**Unique:** `(campaign_id, period_date)`

---

### 33–35. A/B Testing Engine

#### `ab_tests`

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `name` | TEXT | NOT NULL |
| `test_type` | ab_test_type | Enum |
| `entity_type` | TEXT | `hero_slider`, `page_section`, `landing_page` |
| `entity_id` | UUID | |
| `status` | TEXT | `running`, `completed`, `paused` |
| `started_at` | TIMESTAMPTZ | |
| `ended_at` | TIMESTAMPTZ | |
| `winning_variant_id` | UUID | Auto-selected |

**Enum `ab_test_type`:** `hero_banner`, `headline`, `cta_button`, `property_card`, `landing_page`

#### `ab_test_variants`

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `test_id` | UUID | FK → ab_tests |
| `variant_name` | TEXT | `A`, `B`, `C` |
| `config_json` | JSONB | Variant content/settings |
| `traffic_percent` | INT | DEFAULT 50 |

#### `ab_test_results`

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `variant_id` | UUID | FK → ab_test_variants |
| `impressions` | INT | |
| `clicks` | INT | |
| `conversions` | INT | |
| `period_date` | DATE | |

**Automation:** Edge Function declares winner when statistical significance reached.

---

### 36. `personalization_rules`

**Purpose:** Dynamic Personalization — show different content per visitor segment.

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `name` | TEXT | NOT NULL |
| `priority` | INT | DEFAULT 0 | |
| `conditions` | JSONB | NOT NULL | Rule conditions |
| `actions` | JSONB | NOT NULL | Content overrides |
| `status` | content_status | DEFAULT `published` |
| + audit fields | | |

**Condition examples:**

```json
{
  "visitor_type": "returning",
  "location": "Lagos",
  "interest": "investment",
  "property_type": "duplex"
}
```

**Action examples:** Swap hero slider, reorder property grid, show investment CTA.

---

### 37–38. Social Media Management

#### `social_media_accounts`

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `platform` | social_platform | Enum |
| `account_name` | TEXT | |
| `profile_url` | TEXT | |
| `is_connected` | BOOLEAN | DEFAULT false |
| + audit fields | | |

**Enum `social_platform`:** `facebook`, `instagram`, `linkedin`, `x`, `tiktok`, `youtube`, `threads`

#### `social_post_queue` (future)

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `account_id` | UUID | FK |
| `content` | TEXT | |
| `media_ids` | UUID[] | |
| `scheduled_at` | TIMESTAMPTZ | |
| `posted_at` | TIMESTAMPTZ | |
| `status` | TEXT | `queued`, `posted`, `failed` |

---

### 39. `ai_content_jobs`

**Purpose:** Queue for AI content generation tools.

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `job_type` | ai_content_job_type | Enum |
| `input` | JSONB | Source content/context |
| `output` | JSONB | Generated result |
| `entity_type` | TEXT | Target entity |
| `entity_id` | UUID | |
| `status` | TEXT | `pending`, `completed`, `failed` |
| `requested_by` | UUID | FK → users |
| `completed_at` | TIMESTAMPTZ | |

**Enum `ai_content_job_type`:** `blog_writer`, `seo_optimizer`, `property_description`, `image_alt_text`, `meta_description`, `social_caption`, `email_subject`, `landing_page_assistant`, `topic_suggestion`, `analytics_summary`

---

## Analytics Dashboard Metrics

Computed via views/RPCs (not stored tables):

| Metric | Source |
|--------|--------|
| Visitors | `analytics_sessions` COUNT DISTINCT |
| Page views | `analytics_page_views` COUNT |
| Sessions | `analytics_sessions` COUNT |
| Bounce rate | Sessions with `page_count = 1` |
| Avg time on site | AVG session duration |
| Traffic sources | `analytics_sessions.source` GROUP BY |
| Property views | Part 2 `property_view_history` |
| Inquiry conversion | `analytics_events` WHERE `inquiry_submit` |
| Newsletter growth | `newsletter_subscribers` over time |
| Campaign performance | `campaign_performance` |
| Search keywords | `popular_searches` (live) + analytics |
| Top pages | `analytics_page_views` GROUP BY `page_path` |

---

## Marketing Automation Rules

| Trigger | Action |
|---------|--------|
| Newsletter signup | Welcome email, add to `newsletter_subscribers` |
| New lead (website) | Notify assigned sales agent |
| Campaign scheduled | Edge Function sends at `scheduled_at` |
| Abandoned inquiry (24h) | Reminder email |
| Client birthday | Birthday greeting (from `client_profiles`) |
| New property published | Notify subscribers matching `saved_searches` |
| Client inactive 90 days | Re-engagement campaign |
| Blog scheduled | Publish at `published_at` |
| Promotion expired | Archive status |
| Content published | Regenerate sitemap (Edge Function) |
| Campaign failed | Alert administrators |

---

## Relationship Overview

```text
Pages
│
├── page_sections (Visual Page Builder)
├── seo_metadata
├── hero_sliders
└── landing_pages

Navigation
│
├── navigation_menus (nested)
└── footer_config

Blog
│
├── blog_categories
├── blog_posts → blog_post_tags → blog_tags
├── blog_comments
└── authors (users)

Marketing
│
├── email_campaigns → email_templates
├── newsletter_subscribers
├── promotions
├── lead_attribution
├── campaign_performance
├── ab_tests → ab_test_variants → ab_test_results
└── personalization_rules

Media
│
├── media_library
├── gallery_albums → gallery_media
└── (referenced by all content tables)

Careers
│
├── careers
└── job_applications

Analytics
│
├── analytics_sessions
├── analytics_page_views
├── analytics_events
└── marketing_reports

AI
└── ai_content_jobs
```

---

## Row-Level Security (RLS)

### Public Users

| Access | Rule |
|--------|------|
| Pages, sections, blog, gallery, FAQs, testimonials, services, team | SELECT where `status = 'published'` |
| Newsletter | INSERT only (subscribe) |
| Job applications | INSERT only |
| Blog comments | INSERT; SELECT approved only |
| Analytics | INSERT events (anonymous session) |
| Admin/marketing tables | **No access** |

### Marketing Team

| Access | Rule |
|--------|------|
| All CMS + marketing tables | ALL with `marketing.manage` |
| Analytics | SELECT |
| System settings | **No access** |

### Sales Team

| Access | Rule |
|--------|------|
| Published content | SELECT |
| Lead attribution reports | SELECT |
| Edit CMS | **Denied** |

### HR Team

| Access | Rule |
|--------|------|
| `careers`, `job_applications` | ALL |
| Other CMS | SELECT published only |

### Admins

Full access per permissions.

---

## API Contract (Flutter ↔ Supabase)

| Operation | Table / RPC |
|-----------|-------------|
| Homepage content | `pages` + `page_sections` + `hero_sliders` WHERE `page_type = home` |
| Dynamic page by slug | `pages.select().eq('slug', slug)` + sections |
| Blog listing | `blog_posts` WHERE `status = published` |
| Blog detail | `blog_posts` + `blog_comments` + `seo_metadata` |
| Gallery album | `gallery_albums` + `gallery_media` + media URLs |
| Newsletter subscribe | `newsletter_subscribers.upsert()` |
| Track page view | `analytics_page_views.insert()` |
| Track conversion | `analytics_events.insert()` |
| Marketing dashboard | `rpc('marketing_dashboard_metrics', {period})` |
| Campaign performance | `campaign_performance.select()` |
| A/B variant serve | `rpc('get_ab_variant', {test_id, session_id})` |
| Personalization | `rpc('get_personalized_content', {session_context})` |
| AI generate content | `ai_content_jobs.insert()` → poll status |

---

## Cursor Implementation Checklist

| Step | Action | Status |
|------|--------|--------|
| 1 | Explain business purpose | ✅ This document |
| 2 | Define relationships | ✅ ERD above |
| 3 | Create PostgreSQL schema | ⏳ Awaiting approval |
| 4 | Add indexes and constraints | ✅ Defined above |
| 5 | Enable RLS | ✅ Policy model defined |
| 6 | Create Supabase migration | ⏳ Awaiting approval |
| 7 | Add seed data | ⏳ Part 9 |
| 8 | Document API contracts | ✅ Above |
| 9 | Configure realtime | ⏳ Chat/campaigns where needed |
| 10 | Wait for approval | **← Current step** |

---

## Gap Analysis: Live Schema vs Part 5 Target

| Part 5 Target | Live | Gap |
|---------------|------|-----|
| `pages` with page_type, SEO fields | Basic `pages` (JSONB content) | **Extend** columns |
| `page_sections` | Missing | **New table** (page builder) |
| `hero_sliders` | `hero_sections` (page_key based) | **Restructure** — slider model |
| `navigation_menus` | `menus` + `navigation` (2 tables) | **Consolidate** or extend |
| `footer_config` | Scattered `social_links` | **New table** |
| `services` | Missing | **New table** |
| `team_members` | Missing | **New table** |
| `testimonials` | Exists | **Extend** — media FKs, approved flag |
| `faqs` with categories enum | Basic `faqs` | **Extend** category enum |
| `gallery_albums` + `gallery_media` | `media` only | **New tables** |
| `blog_posts` | `blogs` | **Rename/extend** — reading_time, search_vector |
| `blog_tags` + M2M | Missing | **New tables** |
| `blog_comments` | Missing | **New table** |
| `careers` + `job_applications` | Missing | **New tables** |
| `newsletter_subscribers` | `newsletter` (basic) | **Extend** — full_name, source |
| `email_campaigns` | `campaigns` (generic JSONB) | **Extend/restructure** |
| `email_templates` | Missing | **New table** |
| `landing_pages` | Missing | **New table** |
| `promotions` | Missing | **New table** |
| `lead_attribution` | Missing | **New table** |
| `media_library` | `media` (basic) | **Extend** — tags, category, dimensions |
| `seo_metadata` | `seo` (polymorphic) | **Extend** — OG, robots, schema.org |
| `analytics_sessions` | Missing | **New table** |
| `analytics_page_views` | `visitor_statistics` (aggregated) | **New event-level table** |
| `analytics_events` | Missing | **New table** |
| `campaign_performance` | Missing | **New table** |
| A/B testing tables | Missing | **New tables** |
| `personalization_rules` | Missing | **New table** |
| `ai_content_jobs` | Missing | **New table** |
| `social_media_accounts` | `social_links` (URL only) | **Extend** |
| `banners` | Exists | **May merge** into hero_sliders |

---

## Seed Data (Part 5 scope)

| Data | Notes |
|------|-------|
| Default homepage sections | Hero, statistics, property grid, testimonials, CTA |
| Navigation menu items | Match public shell nav from Volume 1 Part 5 |
| Footer config | Company info from `settings` |
| Blog categories | 6 categories |
| FAQ categories | 6 categories |
| Services | 9 services |
| Sample testimonials | 3 (placeholder) |
| Email templates | Welcome, newsletter, inquiry confirmation |

---

**End of Volume 1.5 – Part 5**

*Awaiting Part 6, then full blueprint approval before migration work.*
