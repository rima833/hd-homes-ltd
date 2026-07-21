# Volume 4 — Part 9: Enterprise Human Capital Management (HCM)

Workforce Command Center™ for HD Homes admins — employee directory, recruitment pipeline, attendance, leave requests/balances, performance cycles, training, assets, announcements, and AI Talent Intelligence / CHRO workspace stubs.

Admin feature lives under `lib/features/hcm/`. **Organization Hub** at `/dashboard/organization` is unchanged (Volume 3).

## Status

| Layer | Status |
|-------|--------|
| Domain models + demo dataset | Done |
| HcmService (Supabase selects + demo fallback) | Done |
| Riverpod snapshot / Realtime / UI controller | Done |
| `/dashboard/hr` Workforce Command Center™ | Done |
| SQL + RLS + HCM tables | **APPLIED** remotely 2026-07-15 |
| Full payroll run / biometric attendance | Phase 2 |

Local migration (canonical; do **not** apply until approved):

`supabase/migrations/20260714200000_human_capital_management_system.sql`

## Architecture

```text
HrCommandCenterPage
        ↓
hcmSnapshotProvider + hcmControllerProvider
        ↓
HcmService ──► Supabase (employees, job_postings, applicants,
               attendance_records, leave_requests, training_enrollments,
               employee_assets, hr_announcements, hr_activity_logs, …)
        ↓            └─ demo fallback when offline / empty / missing tables
Widgets (KPI · Directory · Recruitment · Attendance · Leave · AI / CHRO)
```

## Schema approach

- **Do not recreate** `departments`, `employees`, `employee_profiles`, `leave_records`, `staff_onboarding`, `organization_settings`, or existing `positions`.
- **Enrich** employees / profiles / leave_records / staff_onboarding via `ALTER … ADD COLUMN IF NOT EXISTS`.
- **Leave:** keep `leave_records`; add `leave_requests` + `leave_balances` and link carefully.
- Seed UUIDs are hex-only (`a910…`).
- AI seeds labelled `ai_generated` / `editable` in metadata; Flutter insights use advisory disclaimer.

## Routes

| Path | Surface |
|------|---------|
| `/dashboard/hr` | Workforce Command Center™ (admin / staff) — **wired** |
| `/dashboard/organization` | OrganizationHubPage (Volume 3) — **kept** |

## Enterprise features (Phase 1)

1. **Workforce Command Center™** — KPI ticker, Live/Demo badge, Talent / CHRO CTAs  
2. **Directory** — enriched employee list  
3. **Recruitment** — vacancies + applicant pipeline  
4. **Attendance · Leave · Performance · Training · Assets · Announcements**  
5. **Talent Intelligence™ / CHRO Workspace** — briefing + signals (AI-generated — editable / advisory)  
6. **Org Intelligence stubs** — activity + HR notifications  

## Code map

```text
lib/features/hcm/
  domain/entities/hcm_models.dart
  domain/services/hcm_service.dart
  presentation/providers/hcm_controller.dart
  presentation/pages/hr_command_center_page.dart

lib/core/router/shell_routes.dart          # wires admin hr → HrCommandCenterPage
lib/core/constants/permissions.dart        # hr.* slugs
lib/core/constants/route_paths.dart        # dashboardHr
supabase/migrations/20260714200000_human_capital_management_system.sql
```

## Permissions (after SQL apply)

- `hr.read`, `hr.write`, `hr.employees`, `hr.recruitment`
- `hr.attendance`, `hr.leave`, `hr.performance`, `hr.payroll`
- `hr.analytics`, `hr.ai`, `hr.approvals`, `hr.assets`

Grants: `super_admin` / `admin` all; `finance` read/payroll/analytics/approvals; `construction_manager` read/attendance/leave; `sales_team` / `marketing` read.

## Schema notes

- Payroll profiles and disciplinary cases gated by `hr.payroll` / `hr.approvals`.
- Realtime on: employees, attendance_records, leave_requests, job_postings, interviews, hr_announcements, hr_activity_logs.
- RLS via `has_permission('slug', auth.uid())` (slug first).
- Riverpod: **never read `state` inside `Notifier.build()`** — ticker armed from initial return value only.

## Tests

```bash
flutter test test/hcm_platform_test.dart
dart analyze lib/features/hcm
```

## Approval gate

Part 9 HCM SQL was **APPLIED** remotely (chunked `human_capital_management_p1–p3`, verified 2026-07-15).

Part 8 DXP SQL may still be pending / partially applied — do **not** apply Part 8 unless already applied / explicitly approved.

## Next

**Volume 4 — Part 10** — await after Part 9 SQL approve. Volume 4 continues through Parts 11–25 after Part 10.
