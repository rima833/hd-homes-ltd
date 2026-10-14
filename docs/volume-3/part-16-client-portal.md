# Volume 3 — Part 16: Client Portal (Production)

Complete buyer portal for HD Homes clients — properties, payments, documents,
construction, inspections, messaging, support, referrals, and settings.

## Status

| Layer | Status |
|-------|--------|
| Domain models + `ClientService` | Done |
| Riverpod providers + Realtime | **Phase B done** — filtered / debounced hub + live chip |
| Portal modules (UI) | Done |
| Route wiring (`/client/*`) | Done |
| Loading chrome (skeletons) | **Phase A done** — matches investor portal pattern |
| Buying tools + More hub | **Phase C done** |
| Site realtime publication | **Hardened 2026-09-04** (`20260904190000_site_realtime_publication_hardening`) |
| SQL + RLS (`20260714380000_client_portal_platform.sql`) | **APPLIED** remotely 2026-07-22 (`client_portal_p1_schema` / `p2_rls` / `p3_seeds`) |

## Architecture

```text
ClientDashboardPage (+ 11 modules)
        ↓
client*Provider (Riverpod FutureProviders)
        ↓
ClientService ──► Supabase (client_properties, payments, installments,
               client_documents, inspections, client_conversations,
               client_timeline, tickets, favorite_items, client_preferences)
        ↓
PortalShell + clientNav sidebar
```

Feature code: `lib/features/client/`

## Routes

| Path | Module |
|------|--------|
| `/client` | Dashboard |
| `/client/properties` | My Properties |
| `/client/properties/:id` | Property detail |
| `/client/applications` | Applications |
| `/client/tools` | Buying tools (payment plans + how buying works) |
| `/client/saved` | Saved Properties |
| `/client/payments` | Payments |
| `/client/documents` | Documents |
| `/client/construction` | Construction Updates |
| `/client/inspections` | Inspection Booking |
| `/client/consultations` | Consultations |
| `/client/messages` | Messages |
| `/client/notifications` | Notifications |
| `/client/support` | Support Center |
| `/client/referrals` | Referral Program |
| `/client/settings` | Settings |
| `/client/more` | Mobile More hub |

## Access

- Public registration creates a **client** role (`/register`).
- On first portal visit, `ClientService.ensureClient()` creates a `clients` row.
- RLS ensures clients only see their own data (`client_id_for_user()`).
- Staff use `/dashboard/clients` — not the client portal.

## Payments

Phase 1 creates `client_payment_intents` (Paystack / Flutterwave / bank transfer).
Full gateway checkout + webhooks are Phase 2 after launch infrastructure.

## Client buy flow

1. Browse marketplace / save favorites  
2. Model payment plans on `/client/tools`  
3. Submit application (+ documents)  
4. Staff approve → DB allocates `client_properties`  
5. Fund via bank-transfer intent; finance confirms  
6. Documents / construction / inspections update live  

Mobile secondary modules live under **More** (`/client/more`).

## Realtime

`clientPortalRealtimeProvider` (shell hub):

- Auth-bound channel `client-portal-{userId}`
- Filters `client_id` / `user_id` where columns exist
- 350ms debounce + bucketed provider invalidation
- `ClientRealtimeConnection` live chip in header + dashboard
- Event snackbars for payment / application / document / message updates
- Payment-engine tables merged into the same channel (no dual-channel storm)

## Verification

```bash
flutter test test/client_portal_test.dart
dart analyze lib/features/client lib/core/router/shell_routes.dart
```

Sign in as a client user → `/client` → verify all sidebar modules load.

## Next

Step 2: **Investor Portal** (tailored for portfolio/ROI — not a copy of client).
