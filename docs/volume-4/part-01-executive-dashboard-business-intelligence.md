# Volume 4 — Part 1: Executive Dashboard & Business Intelligence

Mission Control Center for HD Homes executives — realtime KPIs, AI insights, activity feed, risk monitor, briefing generator, and strategy workspace.

## Status

| Layer | Status |
|-------|--------|
| Domain models + demo dataset | Done |
| ExecutiveDashboardService | Done (Supabase + demo fallback) |
| Riverpod snapshot / Realtime / UI controller | Done |
| `/dashboard` Mission Control page | Done |
| SQL + RLS + seed KPIs/insights | **APPLIED** remotely (2026-07-14) |
| PDF/Excel export adapters | Stub (queue + summary; files later) |

Local migration:

`supabase/migrations/20260714120000_executive_dashboard_business_intelligence.sql`

## Architecture

```text
ExecutiveDashboardPage
        ↓
executiveDashboardSnapshotProvider
        ↓
ExecutiveDashboardService ──► Supabase (kpi_snapshots, insights, feed, …)
        ↓                         └─ demo fallback when offline / empty
Widgets (KPI · modules · AI · risk · schedule · reports · strategy)
```

## Routes

| Path | Surface |
|------|---------|
| `/dashboard` | Executive Mission Control™ |

## Enterprise features (Phase 1)

1. **Executive Mission Control™** — greeting header, live KPI ticker, presentation mode, auto-refresh  
2. **Predictive BI** — forecast cards with confidence + disclaimer  
3. **Executive Briefing Generator™** — dialog + queued report row  
4. **Operational Risk Monitor** — severity, owner, next action  
5. **Strategy Workspace** — initiative progress bars  

## Code map

```text
lib/features/dashboard/
  domain/entities/executive_dashboard_models.dart
  domain/services/executive_dashboard_service.dart
  presentation/providers/executive_dashboard_controller.dart
  presentation/pages/executive_dashboard_page.dart
```

## Permissions (after SQL apply)

- `view_executive_dashboard`
- `customize_dashboard`
- `generate_executive_reports`
- `view_business_health`

Also reuses `manage_reports` and module permissions for quick actions.

## Tests

```bash
flutter test test/executive_dashboard_platform_test.dart
```

## Approval gate

Reply **approve** to apply the Part 1 SQL migration remotely.

## Next

**Volume 4 — Part 2: Property Management System (PMS)**
