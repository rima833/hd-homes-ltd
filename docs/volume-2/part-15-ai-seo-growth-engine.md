# Volume 2 — Part 15: AI, SEO & Growth Engine

Phase 1 implementation of the invisible intelligence layer powering the HD Homes public website.

> **No public route** — this module is infrastructure under `lib/core/growth/`.

## Architecture

```text
Visitor
  ↓
GrowthRouteTracker (page views)
  ↓
VisitorProfile + Analytics
  ↓
Personalization + Recommendations
  ↓
Lead Scoring + Journey Tracking
  ↓
Marketing Automation + Newsletter + Referrals
  ↓
Business Intelligence + Predictive Insights
  ↓
Admin Dashboard (Volume 3+)
```

## Module map

| # | Module | Location | Phase 1 |
|---|--------|----------|---------|
| 1 | AI Personalization | `personalization/` | Visitor profile + homepage content provider |
| 2 | Property Recommendations | `recommendations/` | Recommended, similar, trending providers |
| 3 | AI Investment Advisor | `ai/investment_advisor.dart` | Rule-based ROI insights |
| 4 | AI Content Assistant | `ai/content_assistant.dart` | Draft generator (human approval required) |
| 5 | AI Search Assistant | Reuses `parseAiSearchQuery()` | NL → filters |
| 6 | AI Chat / Concierge™ | `ai/ai_concierge.dart` + `widgets/ai_concierge_fab.dart` | Floating chat widget |
| 7 | Smart Lead Scoring | `lead_scoring/` | Behavioral + qualification scoring |
| 8 | Customer Journey | `analytics/journey_tracker.dart` | Stage tracking |
| 9 | Marketing Automation | `marketing/automation_engine.dart` | Rule triggers |
| 10 | SEO Engine | `seo/seo_engine.dart` + existing `core/website/seo/` | Sitemap, robots, programmatic helpers |
| 11 | Analytics Platform | `analytics/analytics_service.dart` | In-memory events + summary |
| 12 | Business Intelligence | `analytics/business_intelligence.dart` | Executive snapshot provider |
| 13 | A/B Testing | `marketing/ab_testing.dart` | Variant assignment + exposure events |
| 14 | Campaign Management | `providers/growth_cms_provider.dart` | CMS campaign list |
| 15 | Referral System | `marketing/referral_engine.dart` | Link generation + click tracking |
| 16 | Newsletter | `marketing/newsletter_service.dart` | Wired to `NewsletterBanner` |
| 17–20 | Feedback, Search Console, Performance, Predictive | `predictive_analytics.dart` | Insight providers |

## Wiring

| Integration point | Growth feature |
|-------------------|----------------|
| `shell_routes.dart` | `GrowthRouteTracker` on every public page view |
| `public_shell.dart` | `AiConciergeFab` |
| `cookie_consent_banner.dart` | `consentGateProvider` gates analytics |
| `newsletter_banner.dart` | `subscribeNewsletter()` |
| `lead_routing_provider.dart` | Smart scoring + `trackGrowthLeadSubmitted()` |
| `search_intelligence_provider.dart` | `trackGrowthSearch()` |
| `marketplace_grid_section.dart` | `trackGrowthPropertyView()` |

## Enterprise features

- **HD Homes AI Concierge™** — floating chat with property, investment, and inspection guidance
- **Executive Growth Dashboard** — `executiveGrowthSnapshotProvider`
- **AI Lead Prioritization** — temperature, channel, and contact time recommendations
- **Predictive Market Intelligence** — `predictiveInsightsProvider`
- **No-Code Automation Studio** — `automationRules` in CMS + `triggeredAutomationProvider`

## CMS

`growthHubCmsProvider` — admin-configurable rules, integrations, campaigns, A/B tests (sample data).

## Consent & security

Analytics events respect `consentGateProvider`. Supabase `analytics_events` + RLS deferred to Volume 1.5.

## Third-party integrations

`integrationRegistryProvider` — GA4, GSC, GTM, Meta Pixel, Resend, Termii (status placeholders).

## Tests

`test/growth_engine_test.dart` — AI parse, lead scoring, SEO sitemap, content drafts.

## Volume 2 complete

With Part 15, **Volume 2 (Public Website) is complete**. Next: **Volume 3 — Authentication & User Ecosystem**.
