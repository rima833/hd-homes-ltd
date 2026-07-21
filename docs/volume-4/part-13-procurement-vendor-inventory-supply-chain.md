# Volume 4 — Part 13: Procurement, Vendor, Inventory & Supply Chain Management (PVISCM)

Procurement Command Center for HD Homes admins — enterprise vendors, requisitions, RFQs, purchase orders, receiving, inventory, warehouses, logistics, approvals, analytics, and Smart Procurement Intelligence™.

Admin feature lives under `lib/features/pviscm/`.

## Status

| Layer | Status |
|-------|--------|
| Domain models + demo dataset | Done |
| PviscmService (Supabase selects + demo fallback) | Done |
| Riverpod snapshot / Realtime / UI controller | Done |
| `/dashboard/procurement` Procurement Command Center | Done |
| SQL + RLS + PVISCM tables | **APPLIED** remotely 2026-07-15 |
| Full ERP / EDI / carrier integrations | Phase 2 |

Local migration (canonical; do **not** apply until approved):

`supabase/migrations/20260714240000_procurement_vendor_inventory_supply_chain.sql`

## Architecture

```text
ProcurementCommandCenterPage
        ↓
pviscmSnapshotProvider + pviscmControllerProvider
        ↓
PviscmService ──► Supabase (vendors, purchase_requisitions,
               rfqs, purchase_orders, goods_receipts,
               inventory_items, warehouses, logistics_shipments, …)
        ↓            └─ demo fallback when offline / empty / missing tables
Widgets (KPI · Vendors · PRs · RFQs · POs · GRN · Inventory · AI)
```

## Schema approach

- **Do not recreate/drop** CPMS project-scoped tables:
  `project_suppliers`, `project_materials`, `project_inventory_usage`,
  `project_procurement_requests`, `project_purchase_orders`.
- Optional linking columns via `ALTER … ADD COLUMN IF NOT EXISTS`
  (`enterprise_vendor_id`, `enterprise_po_id`, `enterprise_requisition_id`).
- **Do not collide** with EOC `approval_workflows` / `approval_requests` —
  PVISCM uses `procurement_approvals`.
- **Do not collide** with DDCMS `contract_records` —
  PVISCM uses `supplier_contracts`.
- Enterprise `public.purchase_orders` (name was free; distinct from
  `project_purchase_orders`).
- Seed UUIDs are hex-only (`b130…`).
- AI seeds / Flutter insights use advisory disclaimer:
  **AI-generated — editable / advisory**.
- Storage bucket: `vendor-documents`.

## Routes

| Path | Surface |
|------|---------|
| `/dashboard/procurement` | ProcurementCommandCenterPage — PVISCM Command Center — **wired** |

## Enterprise features (Phase 1)

1. **Smart Procurement Command Center™** — PR → RFQ → PO → GRN overview + activity  
2. **Intelligent Supplier Intelligence™** — vendors, ratings, supplier contracts  
3. **Enterprise Inventory Intelligence™** — SKUs, low-stock, batches  
4. **Construction Material Control™** — warehouses + locations  
5. **Executive Procurement Intelligence Center™** — analytics + reports  

## Code map

```text
lib/features/pviscm/
  domain/entities/pviscm_models.dart
  domain/services/pviscm_service.dart
  presentation/providers/pviscm_controller.dart
  presentation/pages/procurement_command_center_page.dart

lib/core/router/shell_routes.dart          # wires admin procurement → ProcurementCommandCenterPage
lib/core/constants/permissions.dart        # procurement.* slugs
lib/core/constants/route_paths.dart        # dashboardProcurement
supabase/migrations/20260714240000_procurement_vendor_inventory_supply_chain.sql
```

## Permissions (after SQL apply)

- `procurement.read`, `procurement.write`, `procurement.vendors`
- `procurement.requisitions`, `procurement.rfq`, `procurement.orders`
- `procurement.receiving`, `procurement.inventory`, `procurement.warehouse`
- `procurement.logistics`, `procurement.approvals`, `procurement.analytics`
- `procurement.ai`, `procurement.reports`

Grants: `super_admin` / `admin` all; `finance` read/orders/approvals/analytics/reports/vendors; `construction_manager` read/requisitions/orders/receiving/inventory/warehouse/vendors; `sales_team` read/requisitions; `marketing` read/requisitions/inventory.

## Schema notes

- Realtime on: `purchase_requisitions`, `purchase_orders`, `goods_receipts`,
  `inventory_transactions`, `procurement_approvals`, `procurement_activity_logs`,
  `procurement_notifications`.
- RLS via `has_permission('slug', auth.uid())` (slug first).
- Riverpod: **never read `state` inside `Notifier.build()`** — ticker armed from initial return value only.

## Tests

```bash
flutter test test/pviscm_platform_test.dart
dart analyze lib/features/pviscm
```

## Approval gate

Part 13 PVISCM SQL was **APPLIED** remotely (chunked `procurement_vendor_inventory_p1–p3`, verified 2026-07-15).

Part 14 EAFMS is built (Phase 1) with SQL **LOCAL ONLY — await approve**.

**Volume 4 continues** with Parts **15–25**. Wait for approve before Part 15.
