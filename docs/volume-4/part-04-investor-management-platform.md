# Volume 4 — Part 4: Investor Management Platform (IMP)

Investor Command Center™ for HD Homes admins — capital raise, portfolios, distributions, KYC reviews, 360° investor workspace, and AI Investment Assistant™.

Admin feature lives under `lib/features/imp/` (folder name chosen to avoid clashing with the public `/investor` portal stubs).

## Status

| Layer | Status |
|-------|--------|
| Domain models + VIP / corporate / first-time demo dataset | Done |
| ImpService (Supabase selects + demo fallback) | Done |
| Riverpod snapshot / Realtime / UI controller | Done |
| `/dashboard/investors` Investor Command Center™ | Done |
| SQL + RLS + IMP tables | **APPLIED** remotely (2026-07-14) |
| Public `/investor` portal self-service | Unchanged (Phase 2) |
| Full statement PDF / bank rail payouts | Phase 2 |

Local migration (canonical; applied remotely as chunked `investor_management_platform_p1`–`p3`):

`supabase/migrations/20260714150000_investor_management_platform.sql`

## Architecture

```text
InvestorCommandCenterPage
        ↓
impSnapshotProvider + impControllerProvider
        ↓
ImpService ──► Supabase (investors, investment_opportunities, investment_commitments,
               investor_portfolios, portfolio_holdings, investment_distributions,
               investor_wallets, investor_activity_logs, investor_alerts, …)
        ↓            └─ demo fallback when offline / empty / missing tables
Widgets (KPI · Investors · Capital Raise · Portfolio · Distributions · Alerts · AI · 360°)
```

Public marketplace and `/investor` portal remain untouched. Admin IMP wires only `/dashboard/investors`.

## Routes

| Path | Surface |
|------|---------|
| `/dashboard/investors` | Investor Command Center™ (admin / staff) |
| `/investor/*` | Public investor portal stubs — **unchanged** |

## Enterprise features (Phase 1)

1. **Investor Command Center™** — AUM ticker, Live/Demo badge, 360° Investor CTA  
2. **KPI strip** — AUM, Active Investors, Capital Raised, Upcoming Payouts, Avg Investment, Open Opportunities  
3. **Capital Raise Manager™** — opportunity cards with **projected return estimates** + disclaimer  
4. **Portfolio Intelligence** — holdings + wallets stub  
5. **Distributions queue** — scheduled / paid  
6. **Alerts + activity timeline**  
7. **AI Investment Assistant™** + portfolio summary stub  
8. **360° Investor Workspace** — profile, tags, KYC, holdings, payouts, AI summary  

## Code map

```text
lib/features/imp/
  domain/entities/imp_models.dart
  domain/services/imp_service.dart
  presentation/providers/imp_controller.dart
  presentation/pages/investor_command_center_page.dart

lib/core/router/shell_routes.dart          # wires admin investors → Investor Command Center
lib/core/constants/permissions.dart        # investors.* slugs
supabase/migrations/20260714150000_investor_management_platform.sql
```

## Permissions (after SQL apply)

- `investors.read`
- `investors.write`
- `investors.opportunities`
- `investors.portfolio`
- `investors.distributions`
- `investors.documents`
- `investors.analytics`
- `investors.ai`
- `investors.assign`
- `investors.kyc`

Grants: `super_admin` / `admin` all; `sales_team` read/write/opportunities/assign/analytics/ai/distributions; `finance` read/portfolio/distributions/analytics/documents; `marketing` read+ai; `investor` role `investors.read` only (self-service later).

## Schema notes

- Extends foundational `investors` / `investment_transactions` tables; adds IMP enrichment tables (`investor_profiles`, `investor_portfolios`, `investment_opportunities`, …).
- Opportunity status: `open|closed|fully_funded|suspended|completed`.
- `return_disclaimer` defaults to estimate language (projected returns are not guarantees).
- KYC statuses align with Volume 3 identity enums.
- RLS via `has_permission('slug', auth.uid())` (slug first).
- Realtime on: investors, opportunities, commitments, distributions, wallets, activity_logs, alerts.

## Tests

```bash
flutter test test/imp_platform_test.dart
dart analyze lib/features/imp
```

## Approval gate

Part 4 IMP SQL has been **applied remotely**. Open `/dashboard/investors` signed in as admin/finance/sales to load live data.

## Next

**Volume 4 — Part 5: [Sales & Booking Management System](./part-05-sales-booking-management-system.md)** — reservations, quotations, contracts, commissions, and deal execution (**SQL LOCAL ONLY — await approve**).
