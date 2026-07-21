# Volume 4 — Part 16: Enterprise BI, Advanced Analytics & Data Warehouse (BIADW)

BI Command Center for HD Homes admins — data warehouse sources/marts, ETL pipelines, analytics KPIs, dashboards, reports, forecasts, scorecards, data quality, governance/lineage, and AI Executive Briefing™.

Admin feature lives under `lib/features/biadw/`.

## Status

| Layer | Status |
|-------|--------|
| Domain models + demo dataset | Done |
| BiadwService (Supabase selects + demo fallback) | Done |
| Riverpod snapshot / Realtime / UI controller | Done |
| `/dashboard/analytics` BI Command Center | Done |
| SQL + RLS + `analytics_*` tables | **APPLIED** remotely 2026-07-15 |
| Full warehouse / semantic layer / ML Ops | Phase 2 |

Local migration (canonical; **do not apply remote** until approved):

`supabase/migrations/20260714270000_enterprise_bi_analytics_data_warehouse.sql`

Header: **APPLIED** remotely (chunked `enterprise_bi_analytics_warehouse_p1–p3`). Ready for Part 17.

## Architecture

```text
BiCommandCenterPage
        ↓
biadwSnapshotProvider + biadwControllerProvider
        ↓
BiadwService ──► Supabase (analytics_data_sources, analytics_datasets,
               analytics_etl_*, analytics_kpis, analytics_dashboards,
               analytics_reports, analytics_forecasts, analytics_scorecards,
               analytics_quality_*, analytics_lineage, analytics_ai_*)
        ↓            └─ demo fallback when offline / empty / missing tables
Widgets (KPI · Warehouse · ETL · Forecasts · Quality · Scorecards · AI)
```

## Schema approach

- **Route** wires existing `/dashboard/analytics` → `BiCommandCenterPage`.
- `/dashboard/reports` left as-is; Part 1 `/dashboard` ExecutiveDashboardPage unchanged.
- `/dashboard/eoc` EOC Mission Control unchanged.
- **Do not recreate/drop**:
  `kpi_snapshots`, `executive_dashboards`, `executive_metrics`,
  `dashboard_preferences`, `ai_executive_insights`, `dashboard_layouts`,
  `dashboard_widgets`, `eoc_dashboards`, `eoc_dashboard_widgets`,
  `enterprise_kpis`, `enterprise_kpi_definitions`, `enterprise_kpi_targets`,
  `predictive_models`, `predictive_forecasts`, `executive_scorecards`,
  `executive_scorecard_metrics`, `ai_conversations`.
- Free names used exclusively: `analytics_*` prefix.
- Optional non-destructive `ALTER … ADD COLUMN analytics_kpi_id` on
  `enterprise_kpis` / `kpi_snapshots` when those tables exist.
- Seed UUIDs are hex-only (`e160…`).
- AI seeds / Flutter insights use advisory disclaimer:
  **AI-generated — editable / advisory**.
- Storage bucket: `analytics-exports`.

## Routes

| Path | Surface |
|------|---------|
| `/dashboard/analytics` | BiCommandCenterPage — BI Command Center — **wired** |
| `/dashboard` | ExecutiveDashboardPage — **unchanged** (Part 1) |
| `/dashboard/eoc` | EocMissionControlPage — **unchanged** (Part 10) |
| `/dashboard/reports` | Existing reports placeholder — unchanged for now |

## Enterprise features (Phase 1)

1. **Enterprise Intelligence Hub™** — overview + activity  
2. **AI Executive Briefing™** — advisory AI insights  
3. **Enterprise Forecast Engine™** — forecasts with confidence  
4. **Data Quality & Governance Center™** — rules, issues, lineage  
5. **Board & Executive Intelligence Center™** — CEO/CFO scorecards  

## Code map

```text
lib/features/biadw/
  domain/entities/biadw_models.dart
  domain/services/biadw_service.dart
  presentation/providers/biadw_controller.dart
  presentation/pages/bi_command_center_page.dart

lib/core/router/shell_routes.dart          # wires admin analytics → BiCommandCenterPage
lib/core/constants/permissions.dart        # analytics.* slugs
lib/core/constants/route_paths.dart        # dashboardAnalytics (existing)
lib/core/navigation/navigation_config.dart # Analytics nav item (existing)
supabase/migrations/20260714270000_enterprise_bi_analytics_data_warehouse.sql
```

## Permissions (after SQL apply)

- `analytics.read`, `analytics.write`, `analytics.warehouse`, `analytics.etl`
- `analytics.kpis`, `analytics.dashboards`, `analytics.reports`, `analytics.forecasts`
- `analytics.governance`, `analytics.quality`, `analytics.ai`, `analytics.schedule`, `analytics.admin`

Grants: `super_admin` / `admin` all; `finance` read/kpis/dashboards/reports/forecasts; `construction_manager` / `sales_team` / `marketing` read/dashboards/reports/kpis.

## Schema notes

- Realtime on: `analytics_kpis`, `analytics_dashboards`, `analytics_etl_jobs`,
  `analytics_quality_issues`, `analytics_activity_logs`, `analytics_notifications`.
- RLS via `has_permission('slug', auth.uid())` (slug first).
- Riverpod: **never read `state` inside `Notifier.build()`** — ticker armed from initial return value only.

## Tests

```bash
flutter test test/biadw_platform_test.dart
```

## Volume 4 continuity

Part 17 (EAIH) is built — SQL **APPLIED** (2026-07-21). Parts **18–25** remain planned. Part 16 SQL is **APPLIED**.
