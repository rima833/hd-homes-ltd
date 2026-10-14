# Volume 4 — Part 22: Enterprise Customer Experience (CX), Omnichannel Engagement, Loyalty & Personalization Platform (ECXP)

Unified customer 360°, journey orchestration, omnichannel engagement, personalization, loyalty, health scoring, and AI CX assistance for HD Homes.

## Status

| Layer | Status |
|---|---|
| Domain models + demo snapshot | Done |
| Supabase service + offline fallback | Done |
| Riverpod controller + Realtime invalidation | Done |
| `/dashboard/cx` command center | Done |
| SQL, permissions, RLS, storage, seeds | **APPLIED** remotely (2026-07-21) |

Canonical migration: `supabase/migrations/20260714330000_enterprise_customer_experience_platform.sql`

## Architecture

`CxCommandCenterPage` → ECXP Riverpod providers → `EcxpService` → Supabase with per-table demo fallback.

The command center has 12 tabs: Overview, Journeys, Omnichannel, Personalization, Loyalty, Success, Health, Feedback, Segments, Analytics, Referrals, and AI.

Phase 1 enterprise surfaces:

1. Customer Experience Intelligence Center™
2. AI Personalization Engine™
3. Omnichannel Engagement Hub™
4. Customer Loyalty & Advocacy Platform™
5. Executive Customer Experience Center™

## Collision-safe schema

Enriched with `ALTER TABLE … ADD COLUMN IF NOT EXISTS` only:

- `customer_feedback` — `title`, `category`, `status`, `severity`, `cx_surface`, `summary`, `hub_metadata`, `updated_at`
- `personalization_profiles` — `cx_surface`, `engagement_score`, `budget_band`, `preferred_channel`, `hub_metadata`

ECXP does **not** recreate:

- CSHOP `csat_surveys` / `nps_surveys` (uses `customer_surveys` + `survey_responses`)
- CRM `crm_referrals` / `crm_segments` (uses `customer_referrals` / `customer_segments`)
- DXP `dxp_personalization_rules` (uses `personalization_rules`)
- `/dashboard/personalization` PersonalizationAnalyticsPage

New tables include customer 360 profiles, touchpoints, timelines, channels, journeys/steps/executions, recommendation history, loyalty programs/tiers/points/rewards, health scores, success plans/tasks, segments, surveys/responses, reviews, sentiment, journey analytics, CX reports, activity logs, notifications, and `cx_ai_insights`.

Private storage bucket: `cx-artifacts`.

Realtime: `customer_touchpoints`, `journey_executions`, `loyalty_points`, `customer_health_scores`, `cx_activity_logs`, `cx_notifications`.

## Permissions

`cx.read`, `cx.write`, `cx.journeys`, `cx.omnichannel`, `cx.personalization`, `cx.loyalty`, `cx.success`, `cx.health`, `cx.feedback`, `cx.segments`, `cx.analytics`, `cx.ai`, `cx.admin`.

Role grants:

- `super_admin`, `admin`: all
- `finance`: read, analytics, health
- `sales_team`: read, journeys, loyalty, success
- `marketing`: read, personalization, segments, loyalty, feedback
- `construction_manager`: read, success

RLS calls `has_permission('slug', auth.uid())` with the slug first.

## Route note

`/dashboard/cx` → CX Command Center. Do **not** replace `/dashboard/personalization` or `/dashboard/support`.

## Verification

`test/ecxp_platform_test.dart` covers demo surfaces, KPI strip, advisory AI output, health/referral register data, offline service fallback, briefing/signals, and the 12-tab controller contract.

## Next

SQL applied and verified. Volume 4 continues through Parts 24–25. Part 23 EPM SQL is **APPLIED**.
