# Volume 4 — Part 10: Executive Intelligence & Enterprise Operations Center (EOC)

Enterprise Mission Control™ for HD Homes admins — cross-module KPIs, universal search, AI Enterprise Brain, BPA workflows, approvals, alerts/tasks, predictive forecasts, scorecards, knowledge, and audit.

Admin feature lives under `lib/features/eoc/`. **Part 1 Executive Dashboard** at `/dashboard` is unchanged.

## Status

| Layer | Status |
|-------|--------|
| Domain models + demo dataset | Done |
| EocService (Supabase selects + demo fallback) | Done |
| Riverpod snapshot / Realtime / UI controller | Done |
| `/dashboard/eoc` Enterprise Mission Control™ | Done |
| SQL + RLS + EOC tables | **APPLIED** remotely 2026-07-15 |
| Full BPA designer / live LLM copilot | Phase 2 |

Local migration (canonical; do **not** apply until approved):

`supabase/migrations/20260714210000_enterprise_operations_center.sql`

## Architecture

```text
EocMissionControlPage
        ↓
eocSnapshotProvider + eocControllerProvider
        ↓
EocService ──► Supabase (enterprise_kpis, enterprise_alerts,
               approval_requests, workflow_instances, enterprise_tasks,
               predictive_forecasts, executive_scorecards, …)
        ↓            └─ demo fallback when offline / empty / missing tables
Widgets (KPI · Search · AI · Workflows · Approvals · Alerts · Forecasts · Audit)
```

## Schema approach

- **Do not recreate** Part 1 tables (`executive_dashboards`, `kpi_snapshots`, `executive_metrics`, `executive_notifications`, etc.).
- **Enrich** Part 1 dashboards/KPIs/metrics + existing `ai_conversations` via `ALTER … ADD COLUMN IF NOT EXISTS`.
- **New** EOC tables use `eoc_*` / `enterprise_*` names to avoid collisions (`eoc_notifications`, `eoc_audit_events`, `eoc_report_templates`, `eoc_activity_logs`).
- Seed UUIDs are hex-only (`e010…`).
- AI seeds / Flutter insights use advisory disclaimer: **AI-generated — editable / advisory**.

## Routes

| Path | Surface |
|------|---------|
| `/dashboard` | ExecutiveDashboardPage (Volume 4 Part 1) — **kept** |
| `/dashboard/eoc` | EocMissionControlPage — Mission Control / EOC — **wired** |

## Enterprise features (Phase 1)

1. **Enterprise Mission Control™** — KPI ticker, Live/Demo badge, module health mosaic  
2. **AI Enterprise Brain™** — briefing + ops signals (AI-generated — editable / advisory)  
3. **Business Process Automation Studio™** — workflow instances + step stubs  
4. **Predictive Intelligence Engine™** — forecasts with confidence  
5. **Executive Decision Intelligence™** — scorecards + decision logs  

## Code map

```text
lib/features/eoc/
  domain/entities/eoc_models.dart
  domain/services/eoc_service.dart
  presentation/providers/eoc_controller.dart
  presentation/pages/eoc_mission_control_page.dart

lib/core/router/shell_routes.dart          # wires admin eoc → EocMissionControlPage
lib/core/constants/permissions.dart        # eoc.* slugs
lib/core/constants/route_paths.dart        # dashboardEoc
supabase/migrations/20260714210000_enterprise_operations_center.sql
```

## Permissions (after SQL apply)

- `eoc.read`, `eoc.write`, `eoc.kpis`, `eoc.search`, `eoc.ai`
- `eoc.workflows`, `eoc.approvals`, `eoc.alerts`, `eoc.tasks`
- `eoc.meetings`, `eoc.reports`, `eoc.analytics`, `eoc.audit`

Grants: `super_admin` / `admin` all; `finance` read/kpis/approvals/analytics/reports; `sales_team` read/search/tasks; `construction_manager` read/alerts/tasks; `marketing` read/analytics/search.

## Schema notes

- Realtime on: `enterprise_alerts`, `enterprise_tasks`, `approval_requests`, `eoc_activity_logs`, `workflow_instances`, `enterprise_kpis`.
- RLS via `has_permission('slug', auth.uid())` (slug first).
- Riverpod: **never read `state` inside `Notifier.build()`** — ticker armed from initial return value only.

## Tests

```bash
flutter test test/eoc_platform_test.dart
dart analyze lib/features/eoc
```

## Approval gate

Part 10 EOC SQL was **APPLIED** remotely (chunked `enterprise_operations_center_p1–p3`, verified 2026-07-15).

**Volume 4 continues** with Parts **11–25**. Wait for approve before Part 11 — Part 10 is **not** the end of Volume 4.
