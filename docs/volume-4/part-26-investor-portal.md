# Volume 4 — Part 26: Investor Portal (Production)

Complete investor-facing portal for HD Homes — portfolio, analytics, distributions,
construction, reports, documents, messaging, support, referrals, and settings.

Companion to Volume 3 Part 16 (Client Portal) and Volume 4 Part 4 (IMP admin).

## Status

| Layer | Status |
|-------|--------|
| Domain models + `InvestorService` | Done |
| Riverpod providers + Realtime hub | Done |
| Portal modules (UI) | Done (Phases 4–14) |
| Route wiring (`/investor/*`) | Done via `investorShellRoute` + More hub |
| SQL + RLS + admin RPCs | Done (Phases 2–13) |
| E2E contracts + catalog smoke | Done (Phase 15) |
| Demo seeds | Applied — **DB seed data, not Flutter mocks** |

**Phase 1 audit:** [`part-26-investor-portal-phase-1-audit.md`](./part-26-investor-portal-phase-1-audit.md)  
**Phase 2 security:** [`part-26-investor-portal-phase-2-report.md`](./part-26-investor-portal-phase-2-report.md) — **APPLIED** (`20260903120000_investor_portal_phase2_security`)  
**Phase 3 realtime:** [`part-26-investor-portal-phase-3-report.md`](./part-26-investor-portal-phase-3-report.md) — **APPLIED** (`20260903130000_investor_portal_phase3_realtime`)  
**Phase 4 dashboard:** [`part-26-investor-portal-phase-4-report.md`](./part-26-investor-portal-phase-4-report.md) — **DONE**  
**Phase 5 portfolio:** [`part-26-investor-portal-phase-5-report.md`](./part-26-investor-portal-phase-5-report.md) — **DONE**  
**Phase 6 payments:** [`part-26-investor-portal-phase-6-report.md`](./part-26-investor-portal-phase-6-report.md) — **APPLIED** (`20260903140000_investor_portal_phase6_payments`)  
**Phase 7 construction:** [`part-26-investor-portal-phase-7-report.md`](./part-26-investor-portal-phase-7-report.md) — **APPLIED** (`20260903150000_investor_portal_phase7_construction`)  
**Phase 8 documents:** [`part-26-investor-portal-phase-8-report.md`](./part-26-investor-portal-phase-8-report.md) — **APPLIED** (`20260904120000_investor_portal_phase8_documents`)  
**Phase 9 messaging & support:** [`part-26-investor-portal-phase-9-report.md`](./part-26-investor-portal-phase-9-report.md) — **APPLIED** (`20260904130000_investor_portal_phase9_messaging_support`)  
**Phase 10 reports & analytics:** [`part-26-investor-portal-phase-10-report.md`](./part-26-investor-portal-phase-10-report.md) — **APPLIED** (`20260904140000_investor_portal_phase10_analytics`)  
**Phase 11 referrals & KYC:** [`part-26-investor-portal-phase-11-report.md`](./part-26-investor-portal-phase-11-report.md) — **APPLIED** (`20260904150000_investor_portal_phase11_referrals_kyc`)  
**Phase 12 notifications:** [`part-26-investor-portal-phase-12-report.md`](./part-26-investor-portal-phase-12-report.md) — **APPLIED** (`20260904160000_investor_portal_phase12_notifications`)  
**Phase 13 admin integration:** [`part-26-investor-portal-phase-13-report.md`](./part-26-investor-portal-phase-13-report.md) — **APPLIED** (`20260904170000_investor_portal_phase13_admin_integration`)  
**Phase 14 polish:** [`part-26-investor-portal-phase-14-report.md`](./part-26-investor-portal-phase-14-report.md) — **DONE** (More hub, skeletons, a11y)  
**Phase 15 E2E tests:** [`part-26-investor-portal-phase-15-report.md`](./part-26-investor-portal-phase-15-report.md) — **DONE** (`20260904180000_investor_portal_phase15_e2e_smoke`)

**Portal status:** Phases 1–15 complete against the master realtime/UI rewrite brief.

## Architecture

```text
InvestorDashboardPage (+ 11 modules)
        ↓
investor*Provider (Riverpod FutureProviders)
        ↓
InvestorService ──► Supabase (investors, portfolio_holdings, investment_distributions,
               investor_wallets, investor_documents, investor_reports, investor_statements,
               investment_performance, investor_notifications, investor_activity_logs,
               investor_conversations, investor_referral_commissions, tickets)
        ↓
PortalShell + investorNav sidebar + investorBottomNav
```

Feature code: `lib/features/investor/`

## Routes

| Path | Module |
|------|--------|
| `/investor` | Dashboard |
| `/investor/portfolio` | Portfolio holdings |
| `/investor/portfolio/:holdingId` | Holding detail |
| `/investor/analytics` | Investment analytics |
| `/investor/tools` | ROI calculator, payment plans, invest flow |
| `/investor/construction` | Construction progress |
| `/investor/reports` | Reports & statements |
| `/investor/payments` | Wallet & distributions |
| `/investor/documents` | Documents |
| `/investor/referrals` | Referral program |
| `/investor/messages` | Messages |
| `/investor/notifications` | Notifications |
| `/investor/support` | Support center |
| `/investor/settings` | Settings |
| `/investor/more` | Mobile More hub |

## Access

- On first portal visit, `InvestorService.ensureInvestor()` calls `ensure_investor_record()` RPC.
- RLS ensures investors only see their own data (`investor_id_for_user()`).
- Staff use `/dashboard/investors` (IMP Command Center) — not the investor portal.

## Payments

Bank transfer is the live funding path:

1. Investor opens **Payments → Bank transfer**
2. Sees HD Homes receiving account (`investment_receiving_accounts`)
3. Creates an `investor_payment_intents` row with a unique reference
4. Transfers using that reference as narration; finance confirms offline

Card gateways (Paystack / Flutterwave) are deferred.

## Construction

- Interactive Gantt from `milestones`
- Progress updates + photos from `construction_updates` / `construction_photos`
- Drone / site videos from `construction_videos`

## Reports export

Client-side engines in `lib/core/export/export_engine.dart`:

- PDF (`pdf` package)
- Excel (`.xlsx` via `excel` package)
- CSV

Shared via `share_plus`.

## Public “Invest With Us”

- Desktop nav + mobile drawer: signed-in portal users → `/investor`; others → login/`/investment`
- Investment hub CTAs → Investor Portal + Fund via bank transfer
- Portal **Investment tools** (`/investor/tools`) embeds the same CMS ROI + payment calculators and explains the consult → IMP assign → live holding flow

## Client invest flow (not self-serve purchase)

1. Discover property / opportunity (marketplace or `/investment`)
2. Model returns on hub or `/investor/tools`
3. Book consultation → KYC / due diligence
4. Staff assigns holding in IMP (`admin_assign_investor_holding`)
5. Investor funds via bank-transfer intent; finance confirms
6. Portfolio / construction / documents update in realtime

## Verification

```bash
flutter test test/investor_portal_test.dart test/investor_portal_e2e_scenario_test.dart
dart analyze lib/features/investor lib/core/router/shell_routes.dart
# Optional catalog smoke (authenticated SQL):
# select public.investor_portal_phase15_e2e_smoke();
```

Sign in as an investor user → `/investor` → verify all sidebar modules load. On mobile, use **More** for secondary modules.
