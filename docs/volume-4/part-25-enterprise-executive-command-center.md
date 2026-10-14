# Volume 4 — Part 25: Enterprise Executive Command Center, AI Business Intelligence, Strategic Decision Support & Digital Twin Platform (ECC)

**Volume 4 finale.** CEO cockpit, enterprise digital twin, strategic KPIs, portfolio management, board portal, predictive scenarios, and AI executive advisory — unifying Signals from Volumes 1–4 without replacing earlier command centers.

## Status

| Layer | Status |
|---|---|
| Domain models + demo snapshot | Done |
| Supabase service + offline fallback | Done |
| Riverpod controller + Realtime invalidation | Done |
| `/dashboard/ecc` command center | Done |
| SQL, permissions, RLS, storage, seeds | **APPLIED** remotely (2026-07-21) |

Canonical migration: `supabase/migrations/20260714360000_enterprise_executive_command_center.sql`

## Architecture

`EccCommandCenterPage` → ECC Riverpod providers → `EccService` → Supabase with per-table demo fallback.

The command center has 12 tabs: Overview, Cockpit, KPIs, Strategy, Portfolios, Health, Predictive, Board, Digital Twin, Decisions, Alerts, and AI.

Phase 1 enterprise surfaces:

1. CEO Digital Cockpit™
2. Enterprise Digital Twin™
3. Strategic Intelligence Engine™
4. Board Intelligence Portal™
5. Enterprise Performance Observatory™

## Collision-safe schema

Enriched with `ALTER TABLE … ADD COLUMN IF NOT EXISTS` only:

- Part 1: `executive_dashboards`, `executive_reports`, `business_health_scores`
- Part 10: `executive_scorecards`, `predictive_models`, `predictive_forecasts`
- Part 15: `board_meetings`
- Part 23: `strategic_objectives`, `executive_kpis`

ECC does **not** recreate:

- `dashboard_widgets` (personalization), bare `board_*` GRCA tables, EPM `scenario_models` / `board_reports`
- `/dashboard`, `/dashboard/eoc`, `/dashboard/analytics`, `/dashboard/epm`, `/dashboard/grc`, `/dashboard/egrc`

New tables (all `ecc_*`): `ecc_dashboard_widgets`, `ecc_kpi_definitions`, `ecc_strategic_initiatives`, `ecc_initiative_milestones`, `ecc_enterprise_portfolios`, `ecc_portfolio_items`, `ecc_portfolio_metrics`, `ecc_health_scores`, `ecc_alerts`, `ecc_board_members`, `ecc_board_documents`, `ecc_decision_support_models`, `ecc_scenario_simulations`, `ecc_digital_twin_entities`, `ecc_digital_twin_relationships`, `ecc_activity_logs`, `ecc_notifications`, `ecc_ai_insights`.

Private storage bucket: `ecc-artifacts`.

Realtime: `ecc_kpi_definitions`, `ecc_strategic_initiatives`, `ecc_health_scores`, `ecc_alerts`, `ecc_board_documents`, `ecc_notifications`.

## Permissions

`ecc.read`, `ecc.write`, `ecc.dashboards`, `ecc.kpis`, `ecc.strategy`, `ecc.portfolios`, `ecc.health`, `ecc.predictive`, `ecc.board`, `ecc.decisions`, `ecc.scenarios`, `ecc.twins`, `ecc.ai`, `ecc.admin`.

Role grants:

- `super_admin`, `admin`: all
- `finance`: read, kpis, health, predictive, portfolios, board, ai
- `construction_manager`: read, kpis, portfolios, health, twins
- `sales_team`: read, kpis, predictive
- `marketing`: read, kpis, ai

RLS calls `has_permission('slug', auth.uid())` with the slug first.

## Route note

`/dashboard/ecc` → ECC Command Center. Do **not** replace `/dashboard` (Part 1 home), `/dashboard/eoc`, or `/dashboard/analytics`.

## Verification

`test/ecc_platform_test.dart` covers demo surfaces, KPI strip, advisory AI output, alert/twin/board register data, offline service fallback, briefing/signals, and the 12-tab controller contract.

## Volume 4 complete

With Part 25 SQL applied, **Volume 4 — Admin Dashboard & Business Management** is complete (Flutter + remote SQL).

## Next

SQL applied and verified. Next phase: **Volume 5 — Artificial Intelligence, Automation & Smart PropTech Ecosystem**.
