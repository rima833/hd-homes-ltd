# Volume 4 — Part 2: Enterprise Property Management System (PMS)

Property Command Center™ for HD Homes admins — inventory, estate digital twin, lifecycle timeline, inspections, publish approvals, AI assistant, and creation wizard.

## Status

| Layer | Status |
|-------|--------|
| Domain models + Victoria Crest demo dataset | Done |
| PmsService (Supabase selects + demo fallback) | Done |
| Riverpod snapshot / Realtime / UI controller | Done |
| `/dashboard/properties` Property Command Center™ | Done |
| 8-step Property Creation Wizard | Done (local queue until SQL) |
| SQL + RLS + PMS tables | **APPLIED** remotely (2026-07-14) |
| Media / document upload persistence | Stub notes in wizard |
| Bulk publish / archive | Placeholder snackbars |

Local migration (canonical; applied remotely as chunked `property_management_system_p1`–`p6`):

`supabase/migrations/20260714130000_property_management_system.sql`

## Architecture

```text
PropertyCommandCenterPage
        ↓
pmsSnapshotProvider + pmsControllerProvider
        ↓
PmsService ──► Supabase (properties, inspections, lifecycle, approvals, scores, estates)
        ↓            └─ demo fallback when offline / empty / missing columns
Widgets (KPI · Inventory · Twin · Intelligence · Lifecycle · Approvals · Wizard)
```

Public marketplace at `lib/features/properties/` is unchanged. Admin PMS lives under `lib/features/pms/`.

## Routes

| Path | Surface |
|------|---------|
| `/dashboard/properties` | Property Command Center™ (admin only) |
| `/properties` | Public marketplace (untouched) |

## Enterprise features (Phase 1)

1. **Property Command Center™** — live inventory ticker, Create Property CTA, Live/Demo badge  
2. **Inventory KPIs** — Available, Reserved, Sold, Under Contract, Avg Performance Score, Pipeline Value  
3. **Estate Digital Twin™** — Victoria Crest counts + hierarchy breadcrumb  
4. **Smart Inventory Intelligence™** — AI detection bullets  
5. **Property Lifecycle Timeline™** — recent events  
6. **Inspections + Approval queue**  
7. **AI Property Assistant™** — summary / pricing / SEO stubs  
8. **Property Creation Wizard** — 8 steps; finish message: Queued — apply PMS SQL for persistence  

## Code map

```text
lib/features/pms/
  domain/entities/pms_models.dart
  domain/services/pms_service.dart
  presentation/providers/pms_controller.dart
  presentation/pages/property_command_center_page.dart

lib/core/router/shell_routes.dart          # wires admin properties → PMS
lib/core/constants/permissions.dart        # properties.* slugs
```

## Permissions (after SQL apply)

- `properties.read`
- `properties.write`
- `properties.approve`
- `properties.media`
- `properties.documents`
- `properties.pricing`
- `properties.inspections`
- `properties.ownership`
- `properties.analytics`
- `properties.bulk`
- `properties.ai`

## Tests

```bash
flutter test test/pms_platform_test.dart
```

## Approval gate

Part 2 SQL has been **applied remotely**. Flutter falls back to demo data only when offline or selects fail.

## Next

**Volume 4 — Part 3: Client Relationship Management (CRM)** — see [part-03-client-relationship-management.md](./part-03-client-relationship-management.md).
