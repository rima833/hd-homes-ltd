# Volume 4 — Part 14: Enterprise Asset, Facilities & Maintenance Management (EAFMS)

Asset Command Center for HD Homes admins — enterprise physical asset register, facilities, maintenance, work orders, inspections, fleet, utilities, warranties, depreciation, analytics, and Asset Intelligence™.

Admin feature lives under `lib/features/eafms/`.

## Status

| Layer | Status |
|-------|--------|
| Domain models + demo dataset | Done |
| EafmsService (Supabase selects + demo fallback) | Done |
| Riverpod snapshot / Realtime / UI controller | Done |
| `/dashboard/assets` Asset Command Center | Done |
| SQL + RLS + EAFMS tables | **APPLIED** remotely 2026-07-15 |
| Full CMMS / IoT / depreciation engines | Phase 2 |

Local migration (canonical; do **not** apply until approved):

`supabase/migrations/20260714250000_enterprise_asset_facilities_maintenance.sql`

## Architecture

```text
AssetCommandCenterPage
        ↓
eafmsSnapshotProvider + eafmsControllerProvider
        ↓
EafmsService ──► Supabase (assets, facilities, work_orders,
               maintenance_*, inspections, fleet_vehicles,
               utility_*, asset_warranties, …)
        ↓            └─ demo fallback when offline / empty / missing tables
Widgets (KPI · Register · Facilities · Maintenance · WOs · AI)
```

## Schema approach

- **Do not recreate/drop** DDCMS tables:
  `digital_assets`, `asset_collections`, `asset_collection_items`,
  `asset_usage_logs`.
- **Do not CREATE/DROP** HCM `employee_assets` — optional
  `ALTER … ADD COLUMN IF NOT EXISTS enterprise_asset_id` only.
- **Do not collide** with PVISCM `warehouses`, `inventory_items`, vendors, POs.
- Physical register uses free name `public.assets`.
- Activity uses `asset_activity_logs` (not `asset_usage_logs`).
- Optional: `work_order_materials.inventory_item_id` → `inventory_items`.
- Seed UUIDs are hex-only (`c140…`).
- AI seeds / Flutter insights use advisory disclaimer:
  **AI-generated — editable / advisory**.
- Storage bucket: `asset-documents`.

## Routes

| Path | Surface |
|------|---------|
| `/dashboard/assets` | AssetCommandCenterPage — EAFMS Command Center — **wired** |

## Enterprise features (Phase 1)

1. **Enterprise Asset Command Center™** — register + activity overview  
2. **Intelligent Predictive Maintenance™** — plans, schedules, due items  
3. **Smart Facility Operations™** — HQ + site facilities / zones  
4. **Construction Equipment Intelligence™** — construction-class assets  
5. **Executive Asset Intelligence Center™** — analytics + reports  

## Code map

```text
lib/features/eafms/
  domain/entities/eafms_models.dart
  domain/services/eafms_service.dart
  presentation/providers/eafms_controller.dart
  presentation/pages/asset_command_center_page.dart

lib/core/router/shell_routes.dart          # wires admin assets → AssetCommandCenterPage
lib/core/constants/permissions.dart        # assets.* slugs
lib/core/constants/route_paths.dart        # dashboardAssets
supabase/migrations/20260714250000_enterprise_asset_facilities_maintenance.sql
```

## Permissions (after SQL apply)

- `assets.read`, `assets.write`, `assets.register`, `assets.assign`
- `assets.maintenance`, `assets.workorders`, `assets.inspections`
- `assets.fleet`, `assets.facilities`, `assets.utilities`
- `assets.depreciation`, `assets.approvals`, `assets.analytics`
- `assets.ai`, `assets.reports`

Grants: `super_admin` / `admin` all; `finance` read/depreciation/analytics/reports/approvals; `construction_manager` read/register/maintenance/workorders/inspections/fleet/facilities; `sales_team` read; `marketing` read/facilities.

## Schema notes

- Realtime on: `assets`, `work_orders`, `maintenance_records`,
  `inspections`, `asset_activity_logs`, `asset_notifications`.
- RLS via `has_permission('slug', auth.uid())` (slug first).
- Riverpod: **never read `state` inside `Notifier.build()`** — ticker armed from initial return value only.

## Tests

```bash
flutter test test/eafms_platform_test.dart
dart analyze lib/features/eafms
```

## Approval gate

Part 14 EAFMS SQL was **APPLIED** remotely (chunked `enterprise_asset_facilities_p1–p3`, verified 2026-07-15). Empty legacy CRM `inspections` was renamed to `legacy_crm_inspections` so EAFMS owns `inspections` (PMS still uses `property_inspections`). Ready for Part 15.

**Volume 4 continues** with Parts **15–25**. Wait for approve before Part 15.
