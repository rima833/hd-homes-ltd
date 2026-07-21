# Volume 4 — Part 11: Customer Support, Help Desk & Omnichannel Communication Platform (CSHOP)

Support Command Center for HD Homes admins — tickets, unified inbox, live chat, email, WhatsApp, CSHOP knowledge base, SLAs, escalations, agents, CSAT/NPS, and AI Resolution Intelligence™.

Admin feature lives under `lib/features/cshop/`. Client `/client/support` and investor support stubs are **unchanged**.

## Status

| Layer | Status |
|-------|--------|
| Domain models + demo dataset | Done |
| CshopService (Supabase selects + demo fallback) | Done |
| Riverpod snapshot / Realtime / UI controller | Done |
| `/dashboard/support` Support Command Center | Done |
| SQL + RLS + CSHOP tables | **APPLIED** remotely 2026-07-15 |
| Full telephony / Twilio WhatsApp production | Phase 2 |

Local migration (canonical; do **not** apply until approved):

`supabase/migrations/20260714220000_customer_support_omnichannel_platform.sql`

## Architecture

```text
SupportCommandCenterPage
        ↓
cshopSnapshotProvider + cshopControllerProvider
        ↓
CshopService ──► Supabase (tickets, ticket_messages,
               live_chat_*, whatsapp_*, support_knowledge_*,
               support_slas, support_escalations, …)
        ↓            └─ demo fallback when offline / empty / missing tables
Widgets (KPI · Inbox · Chat · Email · WhatsApp · KB · SLA · AI · Feedback)
```

## Schema approach

- **Do not recreate** `public.tickets` / `public.ticket_messages` (domain_operations).
- **Enrich** those tables via `ALTER … ADD COLUMN IF NOT EXISTS`.
- **Do not drop** `public.chat_messages` (simple DM). New `live_chat_sessions` + `live_chat_messages`.
- **Do not collide** with EOC `knowledge_articles` — CSHOP uses `support_knowledge_*`.
- Optional view `public.support_tickets` → enriched `tickets`.
- Seed UUIDs are hex-only (`f110…`).
- AI seeds / Flutter insights use advisory disclaimer: **AI-generated — editable / advisory**.

## Routes

| Path | Surface |
|------|---------|
| `/dashboard/support` | SupportCommandCenterPage — CSHOP Command Center — **wired** |
| `/client/support` | Client portal stub — **unchanged** |
| `/investor/support` | Investor portal stub — **unchanged** |

## Enterprise features (Phase 1)

1. **Unified Customer Conversation Hub™** — omnichannel inbox + activity  
2. **Intelligent Case Routing™** — agent skills / assignment stubs  
3. **AI Resolution Intelligence™** — briefing + signals (AI-generated — editable / advisory)  
4. **Customer 360° Service Timeline™** — cross-channel timeline stubs  
5. **Executive Customer Experience Center™** — CSAT/NPS + KPI analytics  

## Code map

```text
lib/features/cshop/
  domain/entities/cshop_models.dart
  domain/services/cshop_service.dart
  presentation/providers/cshop_controller.dart
  presentation/pages/support_command_center_page.dart

lib/core/router/shell_routes.dart          # wires admin support → SupportCommandCenterPage
lib/core/constants/permissions.dart        # support.* slugs
lib/core/constants/route_paths.dart        # dashboardSupport
supabase/migrations/20260714220000_customer_support_omnichannel_platform.sql
```

## Permissions (after SQL apply)

- `support.read`, `support.write`, `support.tickets`, `support.inbox`
- `support.chat`, `support.email`, `support.whatsapp`, `support.knowledge`
- `support.sla`, `support.escalations`, `support.analytics`, `support.ai`, `support.reports`

Legacy `manage_tickets` retained and granted alongside modern slugs for admin/sales.

Grants: `super_admin` / `admin` all; `sales_team` read/tickets/inbox/knowledge; `finance` read/analytics/reports; `construction_manager` read/tickets; `marketing` read/analytics.

Team seed slug `customer_support` maps org department concept.

## Schema notes

- Realtime on: `tickets`, `live_chat_messages`, `support_activity_logs`, `support_notifications`, `whatsapp_messages`.
- RLS via `has_permission('slug', auth.uid())` (slug first).
- Riverpod: **never read `state` inside `Notifier.build()`** — ticker armed from initial return value only.

## Tests

```bash
flutter test test/cshop_platform_test.dart
dart analyze lib/features/cshop
```

## Approval gate

Part 11 CSHOP SQL was **APPLIED** remotely (chunked `customer_support_omnichannel_p1–p3`, verified 2026-07-15). Ready for Part 12.

**Volume 4 continues** with Parts **12–25**. Part 12 DDCMS is built; SQL remains LOCAL ONLY until approved. Wait for approve before Part 13.
