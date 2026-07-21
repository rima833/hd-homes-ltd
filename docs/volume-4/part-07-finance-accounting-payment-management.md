# Volume 4 — Part 7: Enterprise Finance, Accounting & Payment Management System (FAPMS)

Finance Command Center™ for HD Homes admins — GL / COA, journals, invoices, gateway payments, banking, budgets, expenses, AR/AP aging, Cash Flow Engine™, Audit Intelligence, Budget Intelligence™, and CFO Workspace™ stubs.

Admin feature lives under `lib/features/fapms/` (named to avoid clash with generic “finance” helpers).

## Status

| Layer | Status |
|-------|--------|
| Domain models + demo dataset | Done |
| FapmsService (Supabase selects + demo fallback) | Done |
| Riverpod snapshot / Realtime / UI controller | Done |
| `/dashboard/finance` Finance Command Center™ | Done |
| SQL + RLS + FAPMS tables | **APPLIED** remotely (2026-07-14) |
| Full gateway webhooks / multi-entity consolidation | Phase 2 |

Local migration (canonical; applied remotely as chunked `finance_accounting_payment_p1`–`p3b`):

`supabase/migrations/20260714180000_finance_accounting_payment_management.sql`

## Architecture

```text
FinanceCommandCenterPage
        ↓
fapmsSnapshotProvider + fapmsControllerProvider
        ↓
FapmsService ──► Supabase (invoices, payment_transactions, expenses, budgets,
               bank_accounts, bank_transactions, journal_entries,
               accounts_receivable, accounts_payable, finance_activity_logs, …)
        ↓            └─ demo fallback when offline / empty / missing tables
Widgets (KPI · Cash Flow Engine · Audit · AR/AP · Invoices · Payments · Banking · Budgets · CFO)
```

## Schema approach

- **Do not recreate** legacy `payments`, `commissions`, `sales_installments`, `sales_payment_plans`.
- **Enrich** `payments` and thin legacy `invoices` via `ALTER … ADD COLUMN IF NOT EXISTS`.
- Prefer **`finance_receipts`** over legacy `receipts` (keeps file-stub receipts table undisturbed).
- **`chart_of_accounts`** is the primary COA catalog; **`general_ledger_accounts`** is a compatibility **VIEW**.
- FAPMS installment bridge: `finance_installment_plans` / `finance_installment_payments` with optional FKs to sales tables.
- Commission **payout** ledger: `commission_payments` (legacy `commissions` untouched).
- Seed UUIDs are hex-only (`f4700000-…`).

## Routes

| Path | Surface |
|------|---------|
| `/dashboard/finance` | Finance Command Center™ (admin / staff) — **wired** |

## Enterprise features (Phase 1)

1. **Finance Command Center™** — KPI ticker, Live/Demo badge, Cash Flow + CFO CTAs  
2. **KPI strip** — Cash, Open AR/AP, Overdue Invoices, Gateway Captured, Pending Approvals, Invoice Volume, Collections Health  
3. **Cash Flow Engine™** — 90-day projection points with **PROJECTION** disclaimer  
4. **Audit Intelligence** — activity timeline + finance notifications  
5. **Ledger · AR · AP · Invoices · Payments · Banking**  
6. **Budget Intelligence™** — lines + variances  
7. **Expenses · Approvals**  
8. **CFO Workspace™** — AI briefing stub + anomaly detection stub  

## Code map

```text
lib/features/fapms/
  domain/entities/fapms_models.dart
  domain/services/fapms_service.dart
  presentation/providers/fapms_controller.dart
  presentation/pages/finance_command_center_page.dart

lib/core/router/shell_routes.dart          # wires admin finance → Finance Command Center
lib/core/constants/permissions.dart        # finance.* slugs (+ managePayments legacy)
supabase/migrations/20260714180000_finance_accounting_payment_management.sql
```

## Permissions (after SQL apply)

- `finance.read`
- `finance.write`
- `finance.ledger`
- `finance.invoices`
- `finance.payments`
- `finance.banking`
- `finance.budgets`
- `finance.expenses`
- `finance.approvals`
- `finance.analytics`
- `finance.ai`
- `finance.tax`

Grants: `super_admin` / `admin` all; `finance` all `finance.*`; `sales_team` read/invoices/payments/analytics; `construction_manager` read/expenses/budgets/analytics; `marketing` read/analytics/ai.

## Schema notes

- COA types: `asset|liability|equity|revenue|expense`.
- Journal status: `draft|posted|void`.
- Invoice statuses enriched in UI: draft/sent/paid/overdue/… (legacy text column).
- Realtime on: invoices, payments, payment_transactions, expenses, budgets, bank_transactions, journal_entries, finance_activity_logs, finance_notifications.
- RLS via `has_permission('slug', auth.uid())` (slug first).
- Riverpod: **never read `state` inside `Notifier.build()`** — ticker armed from initial return value only.

## Tests

```bash
flutter test test/fapms_platform_test.dart
dart analyze lib/features/fapms
```

## Approval gate

Part 7 FAPMS SQL has been **applied remotely**. Open `/dashboard/finance` signed in as admin/finance to load live data.

## Next

**Volume 4 — Part 8: Marketing, CMS & Digital Experience Platform** — [part-08-marketing-cms-digital-experience.md](./part-08-marketing-cms-digital-experience.md) (Phase 1 complete · SQL LOCAL ONLY — await approve).
