# Volume 4 — Part 12: Document, Digital Asset & Contract Management System (DDCMS)

Document Command Center for HD Homes admins — enterprise repository, contracts, e-signatures, DAM, OCR, sharing, retention, analytics, and Smart Document Intelligence™.

Admin feature lives under `lib/features/ddcms/`. Client `/client/documents` and investor `/investor/documents` portal stubs are **unchanged**.

## Status

| Layer | Status |
|-------|--------|
| Domain models + demo dataset | Done |
| DdcmsService (Supabase selects + demo fallback) | Done |
| Riverpod snapshot / Realtime / UI controller | Done |
| `/dashboard/documents` Document Command Center | Done |
| SQL + RLS + DDCMS tables | **APPLIED** remotely 2026-07-15 |
| Full e-sign vendor / OCR production pipeline | Phase 2 |

Local migration (canonical; do **not** apply until approved):

`supabase/migrations/20260714230000_document_digital_asset_contract_management.sql`

## Architecture

```text
DocumentCommandCenterPage
        ↓
ddcmsSnapshotProvider + ddcmsControllerProvider
        ↓
DdcmsService ──► Supabase (documents, document_folders,
               contract_records, signature_requests,
               digital_assets, ocr_processing_jobs, …)
        ↓            └─ demo fallback when offline / empty / missing tables
Widgets (KPI · Repository · Contracts · DAM · OCR · AI · Compliance)
```

## Schema approach

- **Do not recreate/drop** module-specific docs: `property_documents`, `client_documents`, `crm_documents`, `investor_documents`, `employee_documents`, `applicant_documents`, `project_documents`, `kyc_documents`, `document_reviews` (KYC), `sales_documents`.
- **New enterprise tables** under DDCMS (including `public.documents` — name was free).
- **Do not collide** with EOC `workflow_steps` — DDCMS uses `document_workflows` + `document_workflow_steps`.
- Seed UUIDs are hex-only (`d120…`).
- AI seeds / Flutter insights use advisory disclaimer: **AI-generated — editable / advisory**.
- Storage buckets: `enterprise-documents`, `digital-assets`.

## Routes

| Path | Surface |
|------|---------|
| `/dashboard/documents` | DocumentCommandCenterPage — DDCMS Command Center — **wired** |
| `/client/documents` | Client portal stub — **unchanged** |
| `/investor/documents` | Investor portal stub — **unchanged** |

## Enterprise features (Phase 1)

1. **Enterprise Knowledge Vault™** — folders + repository + activity  
2. **Intelligent Contract Center™** — contracts, parties, milestones stubs  
3. **Smart Document Intelligence™** — briefing + signals (AI-generated — editable / advisory)  
4. **Secure Collaboration Workspace™** — shares + access levels  
5. **Executive Records & Compliance Center™** — retention + archival + approvals  

## Code map

```text
lib/features/ddcms/
  domain/entities/ddcms_models.dart
  domain/services/ddcms_service.dart
  presentation/providers/ddcms_controller.dart
  presentation/pages/document_command_center_page.dart

lib/core/router/shell_routes.dart          # wires admin documents → DocumentCommandCenterPage
lib/core/constants/permissions.dart        # documents.* slugs
lib/core/constants/route_paths.dart        # dashboardDocuments
supabase/migrations/20260714230000_document_digital_asset_contract_management.sql
```

## Permissions (after SQL apply)

- `documents.read`, `documents.write`, `documents.upload`, `documents.approve`
- `documents.contracts`, `documents.signatures`, `documents.dam`, `documents.share`
- `documents.archive`, `documents.retention`, `documents.ai`, `documents.analytics`
- `documents.reports`, `documents.admin`

Grants: `super_admin` / `admin` all; `finance` read/contracts/approve/analytics/reports/archive; `sales_team` read/upload/share; `construction_manager` read/upload/approve/contracts; `marketing` read/upload/dam/share. Command Center is staff-only (portal reuse Phase 2).

## Schema notes

- Realtime on: `documents`, `document_approvals`, `signature_requests`, `ocr_processing_jobs`, `document_activity_logs`, `document_notifications`.
- RLS via `has_permission('slug', auth.uid())` (slug first).
- Riverpod: **never read `state` inside `Notifier.build()`** — ticker armed from initial return value only.

## Tests

```bash
flutter test test/ddcms_platform_test.dart
dart analyze lib/features/ddcms
```

## Approval gate

Part 12 DDCMS SQL was **APPLIED** remotely (chunked `document_digital_asset_contract_p1–p3`, verified 2026-07-15). Ready for Part 13.

**Volume 4 continues** with Parts **14–25**. Wait for approve before Part 14.
