# Volume 4 — Part 6: Enterprise Construction & Project Management System (CPMS)

Construction Command Center™ for HD Homes admins — projects, milestones, tasks, procurement, budgets, quality, safety, site diaries, Digital Construction Twin™ stubs, and Smart Progress Intelligence™.

Admin feature lives under `lib/features/cpms/`.

## Status

| Layer | Status |
|-------|--------|
| Domain models + 3-project demo dataset | Done |
| CpmsService (Supabase selects + demo fallback) | Done |
| Riverpod snapshot / Realtime / UI controller | Done |
| `/dashboard/construction` Construction Command Center™ | Done |
| SQL + RLS + CPMS tables | **APPLIED** remotely (2026-07-14) |
| Client `/client/construction` · Investor `/investor/construction` | Unchanged (stubs) |
| Full Gantt / BIM / field mobile sync | Phase 2 |

Local migration (canonical; applied remotely as chunked `construction_project_management_p1`–`p3`):

`supabase/migrations/20260714170000_construction_project_management_system.sql`

## Architecture

```text
ConstructionCommandCenterPage
        ↓
cpmsSnapshotProvider + cpmsControllerProvider
        ↓
CpmsService ──► Supabase (construction_projects, project_milestones, project_tasks,
               project_contractors, project_budget_lines, project_change_orders,
               project_quality_checks, project_defects, project_safety_incidents,
               project_site_diaries, project_activity_logs, project_notifications, …)
        ↓            └─ demo fallback when offline / empty / missing tables
Widgets (KPI · War Room · Twin · Procurement · Budget · Quality · Safety · Diary · AI · Wizard)
```

## Schema approach

**Preferred & implemented:** create a new CPMS hierarchy rooted at `construction_projects` (optional FKs to `estates` / `properties`). Leave legacy thin `projects` + `construction_updates` / photos / videos alone so client/investor portals are not disturbed.

## Routes

| Path | Surface |
|------|---------|
| `/dashboard/construction` | Construction Command Center™ (admin / staff) — **wired** |
| `/client/construction` | Client portal stub — **unchanged** |
| `/investor/construction` | Investor portal stub — **unchanged** |

## Enterprise features (Phase 1)

1. **Construction Command Center™** — KPI ticker, Live/Demo badge, War Room + Wizard CTAs  
2. **KPI strip** — Active Projects, Avg Progress, Delayed Sites, Open Milestones, Blocked Tasks, Pending COs, Open Defects, Open Safety, Portfolio Budget  
3. **War Room** — delayed sites, pending change orders, open safety  
4. **Digital Construction Twin™ stub** — selected project panel + AI progress summary  
5. **Milestones · Tasks · Procurement · Contractors · Change Orders**  
6. **Budget Control** + pending CO impact  
7. **Quality & Defect Intelligence** + inspections  
8. **Safety · Risk Register · Site Diaries**  
9. **Smart Progress Intelligence™** + forecast disclaimer  
10. **Project Creation Wizard** — 7 steps (Basics → Schedule → Budget → Phases → Milestones → Contractors → Review)  

## Code map

```text
lib/features/cpms/
  domain/entities/cpms_models.dart
  domain/services/cpms_service.dart
  presentation/providers/cpms_controller.dart
  presentation/pages/construction_command_center_page.dart

lib/core/router/shell_routes.dart          # wires admin construction → Construction Command Center
lib/core/constants/permissions.dart        # construction.* slugs (+ manageConstruction legacy)
supabase/migrations/20260714170000_construction_project_management_system.sql
```

## Permissions (after SQL apply)

- `construction.read`
- `construction.write`
- `construction.projects`
- `construction.milestones`
- `construction.tasks`
- `construction.procurement`
- `construction.budget`
- `construction.quality`
- `construction.safety`
- `construction.analytics`
- `construction.ai`
- `construction.approvals`

Grants: `super_admin` / `admin` all; `construction_manager` full operational set; `finance` read/budget/analytics/approvals; `sales_team` read/analytics; `marketing` read/ai.

## Schema notes

- Project status: `draft|planning|approved|active|on_hold|completed|archived`.
- Milestone status: `planned|in_progress|completed|delayed|cancelled`.
- Task status: `todo|in_progress|blocked|done|cancelled`.
- Risk severity: `low|medium|high|critical`.
- Forecast rows include confidence + disclaimer language.
- Demo seeds optionally link Victoria Crest estate / property when present.
- Seed UUIDs are hex-only (`c1000000-…`).
- RLS via `has_permission('slug', auth.uid())` (slug first).
- Realtime on: construction_projects, project_milestones, project_tasks, project_change_orders, project_safety_incidents, project_site_diaries, project_activity_logs.

## Tests

```bash
flutter test test/cpms_platform_test.dart
dart analyze lib/features/cpms
```

## Approval gate

Part 6 CPMS SQL has been **applied remotely**. Open `/dashboard/construction` as admin/construction_manager to load live data.

## Next

**Volume 4 — Part 7: Finance, Accounting & Payment Management System (FAPMS)** — see [part-07-finance-accounting-payment-management.md](./part-07-finance-accounting-payment-management.md). SQL is **LOCAL ONLY** until approved; Part 8 waits on that gate.
