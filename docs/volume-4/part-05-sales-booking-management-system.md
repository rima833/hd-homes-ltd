# Volume 4 — Part 5: Sales & Booking Management System (SBMS)

Sales Command Center™ for HD Homes admins — pipeline, reservations, bookings, quotes, Digital Deal Room, contracts, commissions, handovers, approvals, and AI Sales Assistant™.

Admin feature lives under `lib/features/sbms/`.

## Status

| Layer | Status |
|-------|--------|
| Domain models + demo dataset | Done |
| SbmsService (Supabase selects + demo fallback) | Done |
| Riverpod snapshot / Realtime / UI controller | Done |
| `/dashboard/sales` Sales Command Center™ | Done |
| SQL + RLS + `sales_*` tables | **APPLIED** remotely (2026-07-14) |
| Full e-sign / payment gateway rails | Phase 2 |

Local migration (canonical; applied remotely as chunked `sales_booking_management_p1`–`p3`):

`supabase/migrations/20260714160000_sales_booking_management_system.sql`

## Architecture

```text
SalesCommandCenterPage
        ↓
sbmsSnapshotProvider + sbmsControllerProvider
        ↓
SbmsService ──► Supabase (sales_orders, sales_reservations, sales_bookings,
               sales_quotes, sales_contracts, sales_commissions,
               sales_installments, sales_discount_requests, …)
        ↓            └─ demo fallback when offline / empty / missing tables
Widgets (KPI · Pipeline · Reservations · Bookings · Quotes · Deal Room · …)
```

## Routes

| Path | Surface |
|------|---------|
| `/dashboard/sales` | Sales Command Center™ (admin / staff) — **new** |

## Enterprise features (Phase 1)

1. **Sales Command Center™** — revenue ticker, Live/Demo badge, Deal Room CTA  
2. **KPI strip** — Total Sales, Today/Month Revenue, Pending Reservations, Active Negotiations, Contracts Awaiting Signature, Installments Due, Pipeline Value  
3. **Pipeline board** — enquiry → closed_won / closed_lost  
4. **Reservations** — draft / reserved / confirmed / expired / converted (expiring-soon highlighting)  
5. **Bookings** — inspection · office · virtual_tour · site_visit · investment_consultation  
6. **Quotes + negotiation timeline**  
7. **Digital Deal Room stub** — selected deal workspace  
8. **Commissions + installments**  
9. **Handovers checklist** + approvals queue  
10. **Leaderboard snapshot** + **AI Sales Assistant™** + Smart Deal Intelligence™  

## Code map

```text
lib/features/sbms/
  domain/entities/sbms_models.dart
  domain/services/sbms_service.dart
  presentation/providers/sbms_controller.dart
  presentation/pages/sales_command_center_page.dart

lib/core/router/shell_routes.dart          # wires admin sales → Sales Command Center
lib/core/constants/route_paths.dart        # RoutePaths.dashboardSales
lib/core/navigation/navigation_config.dart # adminNav Sales item
lib/core/constants/permissions.dart        # sales.* slugs
supabase/migrations/20260714160000_sales_booking_management_system.sql
```

## Permissions (after SQL apply)

- `sales.read`
- `sales.write`
- `sales.reservations`
- `sales.bookings`
- `sales.quotes`
- `sales.contracts`
- `sales.commissions`
- `sales.approvals`
- `sales.analytics`
- `sales.ai`

Grants: `super_admin` / `admin` all; `sales_team` most including approvals (Phase 1); `finance` read/commissions/analytics/approvals; `marketing` read/analytics/ai.

## Schema notes

- Creates `sales_*` domain tables; **reuses** foundational `payments` (optional `sales_order_id` / `sales_installment_id` links).
- **`sales_commissions`** is the SBMS commission ledger — legacy `public.commissions` left unchanged.
- Reservation status: `draft|reserved|confirmed|expired|cancelled|converted`.
- Booking types: `inspection|office|virtual_tour|site_visit|investment_consultation`.
- Commission status: `earned|pending|approved|paid|cancelled`.
- Demo seeds link optionally to CRM clients (`a1000000-…`) and `victoria-crest-unit-4` when present.
- Quote/forecast rows include estimate disclaimers.
- RLS via `has_permission('slug', auth.uid())` (slug first).
- Realtime on: reservations, bookings, orders, quotes, contracts, installments, commissions, discount_requests, activity_logs.

## Tests

```bash
flutter test test/sbms_platform_test.dart
dart analyze lib/features/sbms
```

## Approval gate

Part 5 SBMS SQL has been **applied remotely**. Open `/dashboard/sales` signed in as admin/sales/finance to load live data.

## Next

**Volume 4 — Part 6: [Construction & Project Management System](./part-06-construction-project-management-system.md)** — land development, contractors, budgets, milestones, and delivery (**SQL LOCAL ONLY — await approve**).
