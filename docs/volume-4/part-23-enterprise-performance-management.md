# Volume 4 — Part 23: Enterprise Performance Management, Financial Planning, Budgeting, Forecasting & Executive Reporting Platform (EPM)

Unified budgeting, rolling forecasts, treasury visibility, capital allocation, scenario modeling, executive KPIs, and AI performance advisory for HD Homes.

## Status

| Layer | Status |
|---|---|
| Domain models + demo snapshot | Done |
| Supabase service + offline fallback | Done |
| Riverpod controller + Realtime invalidation | Done |
| `/dashboard/epm` command center | Done |
| SQL, permissions, RLS, storage, seeds | **APPLIED** remotely (2026-07-21) |

Canonical migration: `supabase/migrations/20260714340000_enterprise_performance_management_platform.sql`

## Architecture

`EpmCommandCenterPage` → EPM Riverpod providers → `EpmService` → Supabase with per-table demo fallback.

The command center has 12 tabs: Overview, Budgets, Planning, Forecasts, Treasury, Cash Flow, Capital, Scenarios, KPIs, Performance, Board, and AI.

Phase 1 enterprise surfaces:

1. Financial Intelligence Center™
2. Forecasting Engine™
3. Capital Allocation™
4. Scenario Studio™
5. Board Intelligence™

## Collision-safe schema

Enriched with `ALTER TABLE … ADD COLUMN IF NOT EXISTS` only:

- `budgets` (FAPMS) — `epm_surface`, `hub_metadata`
- `financial_reports` (FAPMS) — `epm_surface`, `hub_metadata`

EPM does **not** recreate:

- FAPMS `budgets` / `budget_lines` / `budget_variances` (uses `budget_cycles`, `budget_versions`, `budget_items`, `budget_approvals`)
- GRCA `board_meetings` / `board_resolutions` / `board_votes` (uses `board_reports`)
- `/dashboard/finance` FinanceCommandCenterPage

New tables: `budget_cycles`, `budget_versions`, `budget_items`, `budget_approvals`, `financial_plans`, `financial_plan_versions`, `forecast_models`, `forecast_results`, `treasury_accounts`, `treasury_transactions`, `cash_flow_snapshots`, `cash_flow_forecasts`, `capital_projects`, `capital_allocations`, `capital_roi`, `financial_consolidations`, `scenario_models`, `scenario_results`, `executive_kpis`, `strategic_objectives`, `corporate_performance_metrics`, `board_reports`, `financial_risk_indicators`, `epm_activity_logs`, `epm_notifications`, `epm_ai_insights`.

Private storage bucket: `epm-artifacts`.

Realtime: `budget_approvals`, `forecast_results`, `treasury_transactions`, `cash_flow_snapshots`, `executive_kpis`, `epm_notifications`.

## Permissions

`epm.read`, `epm.write`, `epm.budgets`, `epm.planning`, `epm.forecasts`, `epm.treasury`, `epm.cashflow`, `epm.capital`, `epm.scenarios`, `epm.kpis`, `epm.performance`, `epm.board`, `epm.ai`, `epm.admin`.

Role grants:

- `super_admin`, `admin`: all
- `finance`: read, write, budgets, planning, forecasts, treasury, cashflow, capital, kpis, performance, board, ai
- `construction_manager`: read, capital, budgets
- `sales_team`: read, forecasts, kpis
- `marketing`: read, budgets, forecasts

RLS calls `has_permission('slug', auth.uid())` with the slug first.

## Route note

`/dashboard/epm` → EPM Command Center. Do **not** replace `/dashboard/finance` or `/dashboard/analytics`.

## Verification

`test/epm_platform_test.dart` covers demo surfaces, KPI strip, advisory AI output, budget/forecast/capital register data, offline service fallback, briefing/signals, and the 12-tab controller contract.

## Next

SQL applied and verified. Part 24 EGRC SQL is **APPLIED**. Part 25 ECC SQL is **APPLIED**. **Volume 4 is complete.**
