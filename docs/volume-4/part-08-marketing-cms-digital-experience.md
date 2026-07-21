# Volume 4 — Part 8: Enterprise Marketing, CMS & Digital Experience Platform (DXP)

Marketing Command Center™ for HD Homes admins — CMS pages/versions, landing experiences, blog enrichment, media library, omnichannel campaigns, forms, SEO health, content calendar, A/B tests, and AI Content Studio stubs.

Admin feature lives under `lib/features/dxp/` (Digital Experience Platform naming).

## Status

| Layer | Status |
|-------|--------|
| Domain models + demo dataset | Done |
| DxpService (Supabase selects + demo fallback) | Done |
| Riverpod snapshot / Realtime / UI controller | Done |
| `/dashboard/marketing` Marketing Command Center™ | Done |
| SQL + RLS + DXP tables | **APPLIED** remotely (verified 2026-07-15) |
| Full visual builder / ESP webhook delivery | Phase 2 |

Local migration (canonical; do **not** apply until approved):

`supabase/migrations/20260714190000_marketing_cms_digital_experience.sql`

## Architecture

```text
MarketingCommandCenterPage
        ↓
dxpSnapshotProvider + dxpControllerProvider
        ↓
DxpService ──► Supabase (landing_pages, pages, blogs, campaigns, form_submissions,
               seo_metadata, content_calendar, ab_tests, media_library,
               marketing_activity_logs, marketing_analytics, …)
        ↓            └─ demo fallback when offline / empty / missing tables
Widgets (KPI · Funnel · Omnichannel · CMS · Blog · Media · SEO · Calendar · AI Studio)
```

## Schema approach

- **Do not recreate** `pages`, `banners`, `blogs`, `blog_categories`, `media`, `seo`, `campaigns`, `communication_campaigns`, `newsletter`, `crm_campaign_memberships`.
- **Enrich** pages / blogs / media / seo / campaigns via `ALTER … ADD COLUMN IF NOT EXISTS`.
- **Campaigns choice:** enrich thin `campaigns` + channel children (`email_campaigns`, `sms_campaigns`, `whatsapp_campaigns`, `push_campaigns`) — **no** duplicate `marketing_campaigns` catalog.
- **Personalization:** `dxp_personalization_rules` (avoids clash with Volume 3 `personalization_*`).
- CMS versions: `cms_page_versions` → `pages(id)`; landing versions → `landing_pages`.
- Blog: enrich `blogs`; add `blog_authors`, `blog_tags`, `blog_tag_links`.
- Media: enrich `media`; add `media_folders`; optional `media_library` view.
- Seed UUIDs are hex-only (`d4800000-…`).
- AI seeds labelled `ai_generated` / `editable` in metadata.

## Routes

| Path | Surface |
|------|---------|
| `/dashboard/marketing` | Marketing Command Center™ (admin / staff) — **wired** |
| `/dashboard/website`, blog, media, banners, seo | Remain placeholders (Command Center is primary) |

Public blog/media under `lib/features/blog` and `lib/features/media` are **unchanged**.

## Enterprise features (Phase 1)

1. **Marketing Command Center™** — KPI ticker, Live/Demo badge, Omnichannel + AI Studio CTAs  
2. **Experience Orchestration** — conversion funnel KPI strip  
3. **Omnichannel Hub** — email / SMS / WhatsApp campaign rows  
4. **CMS / Landing / Blog / Media** — lists + Visual Builder stubs  
5. **Forms · SEO · Calendar · A/B**  
6. **AI Content Studio™** — briefing + conversion signal stubs (AI-generated — editable disclaimer)  
7. **Executive Digital Intelligence** — activity + notifications  

## Code map

```text
lib/features/dxp/
  domain/entities/dxp_models.dart
  domain/services/dxp_service.dart
  presentation/providers/dxp_controller.dart
  presentation/pages/marketing_command_center_page.dart

lib/core/router/shell_routes.dart          # wires admin marketing → Marketing Command Center
lib/core/constants/permissions.dart        # marketing.* slugs (+ manageMarketing legacy)
supabase/migrations/20260714190000_marketing_cms_digital_experience.sql
```

## Permissions (after SQL apply)

- `marketing.read`
- `marketing.write`
- `marketing.cms`
- `marketing.campaigns`
- `marketing.media`
- `marketing.seo`
- `marketing.forms`
- `marketing.analytics`
- `marketing.ai`
- `marketing.publish`
- `marketing.social`

Grants: `super_admin` / `admin` all; `marketing` all `marketing.*`; `sales_team` read/forms/analytics/campaigns; `finance` read/analytics; `construction_manager` read.

## Schema notes

- Landing status: `draft|published|archived|scheduled`.
- Channel campaign status: `draft|scheduled|sending|sent|paused|cancelled`.
- Realtime on: landing_pages, forms, form_submissions, campaigns, email_campaigns, content_calendar, marketing_activity_logs, blogs.
- RLS via `has_permission('slug', auth.uid())` (slug first).
- Riverpod: **never read `state` inside `Notifier.build()`** — ticker armed from initial return value only.

## Tests

```bash
flutter test test/dxp_platform_test.dart
dart analyze lib/features/dxp
```

## Approval gate

Part 8 DXP SQL was applied remotely (verified 2026-07-15). No further approve needed for Part 8.

## Next

**Volume 4 — Part 9** — Enterprise Human Capital Management (HCM) — see [part-09-enterprise-human-capital-management.md](./part-09-enterprise-human-capital-management.md). Await Part 8 SQL approve before remote applies; Part 9 SQL is also LOCAL ONLY until approved.
