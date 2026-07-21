# Volume 4 — Part 3: Client Relationship Management (CRM)

CRM Command Center™ for HD Homes admins — leads, pipeline, tasks, appointments, 360° customer view, relationship graph stub, and AI CRM Assistant™.

## Status

| Layer | Status |
|-------|--------|
| Domain models + VIP / buyer / investor demo dataset | Done |
| CrmService (Supabase selects + demo fallback) | Done |
| Riverpod snapshot / Realtime / UI controller | Done |
| `/dashboard/crm` CRM Command Center™ | Done |
| SQL + RLS + CRM tables | **APPLIED** remotely (2026-07-14) |
| Full omnichannel send / document upload | Phase 2 |
| Client self-service read-own access | Skipped for Phase 1 (staff-only) |

Local migration (canonical; applied remotely as chunked `client_relationship_management_p1`–`p4`):

`supabase/migrations/20260714140000_client_relationship_management.sql`

## Architecture

```text
CrmCommandCenterPage
        ↓
crmSnapshotProvider + crmControllerProvider
        ↓
CrmService ──► Supabase (crm_clients, crm_leads, crm_tasks, crm_appointments, crm_activity_logs, …)
        ↓            └─ demo fallback when offline / empty / missing tables
Widgets (KPI · Pipeline · Leads · Tasks · Appointments · Timeline · AI · Graph · 360°)
```

Public marketplace and PMS remain untouched. Admin CRM lives under `lib/features/crm/`.

## Routes

| Path | Surface |
|------|---------|
| `/dashboard/crm` | CRM Command Center™ (admin / staff) |

## Enterprise features (Phase 1)

1. **CRM Command Center™** — live ticker, 360° Customer View CTA, Live/Demo badge  
2. **KPI strip** — New Leads, Pipeline Value, Conversion Rate, Tasks Due, Avg Health, Hot Leads  
3. **Pipeline board** — kanban-ish stage counts with probability  
4. **Leads / Tasks / Appointments / Timeline**  
5. **AI CRM Assistant™** + Lead Intelligence™ bullets  
6. **Relationship Graph** — network label stub  
7. **360° Customer View** — profile, prefs, health, AI summary, recent timeline  

## Code map

```text
lib/features/crm/
  domain/entities/crm_models.dart
  domain/services/crm_service.dart
  presentation/providers/crm_controller.dart
  presentation/pages/crm_command_center_page.dart

lib/core/router/shell_routes.dart          # wires admin crm → CRM Command Center
lib/core/constants/permissions.dart        # crm.* slugs
```

## Permissions (after SQL apply)

- `crm.read`
- `crm.write`
- `crm.leads`
- `crm.pipeline`
- `crm.tasks`
- `crm.communications`
- `crm.documents`
- `crm.analytics`
- `crm.ai`
- `crm.assign`

Grants: `super_admin` / `admin` all; `sales_team` most; `marketing` read+leads+comms+ai; `finance` read+analytics. Client/investor: none in Phase 1.

## Tests

```bash
flutter test test/crm_platform_test.dart
dart analyze lib/features/crm
```

## Approval gate

Part 3 CRM SQL has been **applied remotely**. Open `/dashboard/crm` while signed in as admin/sales to load live data (demo fallback only if offline or RLS blocks).

## Next

**Volume 4 — Part 4: Investor Management Platform** — see [part-04-investor-management-platform.md](./part-04-investor-management-platform.md). Phase 1 Flutter complete; SQL **LOCAL ONLY — await approve** before Part 5.
