# Volume 4 — Part 15: Enterprise GRC, Internal Audit & Legal (GRCA)

GRC Command Center for HD Homes admins — governance frameworks, enterprise risk register, compliance, corporate policies, internal audit, legal cases, ethics/whistleblower (restricted), board meetings, BCM, regulatory calendar, analytics, and GRC Intelligence™.

Admin feature lives under `lib/features/grca/`.

## Status

| Layer | Status |
|-------|--------|
| Domain models + demo dataset | Done |
| GrcaService (Supabase selects + demo fallback) | Done |
| Riverpod snapshot / Realtime / UI controller | Done |
| `/dashboard/grc` GRC Command Center | Done |
| SQL + RLS + GRCA tables | **APPLIED** remotely 2026-07-15 |
| Full GRC / e-discovery / BCM engines | Phase 2 |

Local migration (canonical; applied remotely 2026-07-15):

`supabase/migrations/20260714260000_enterprise_grc_audit_legal_management.sql`

Header: **APPLIED** remotely (chunked `enterprise_grc_audit_legal_p1–p3`). Ready for Part 16.

## Architecture

```text
GrcCommandCenterPage
        ↓
grcaSnapshotProvider + grcaControllerProvider
        ↓
GrcaService ──► Supabase (risk_register, compliance_*, corporate_policies,
               audit_*, legal_*, ethics_*, board_*, BCM, grc_*)
        ↓            └─ demo fallback when offline / empty / missing tables
Widgets (KPI · Risks · Compliance · Audit · Legal · Board · BCM · AI)
```

## Schema approach

- **Route** is `/dashboard/grc` — **never** collide with KYC `/dashboard/compliance`
  (`KycCompliancePage` remains unchanged).
- **Do not recreate/drop**:
  `compliance_vault`, `compliance_reports`, `audit_logs`, `ai_audit_logs`,
  `eoc_audit_events`, `legal_acceptances`, `policy_rules`,
  `project_risk_register`, `meeting_records`.
- Free names used: `risk_register`, `corporate_policies`, `grc_reports`,
  `board_meetings`, `grc_activity_logs` (not `audit_logs` / `compliance_reports`).
- Seed UUIDs are hex-only (`d150…`).
- AI seeds / Flutter insights use advisory disclaimer:
  **AI-generated — editable / advisory**.
- Storage bucket: `grc-documents`.
- Ethics/whistleblower tables require `grc.ethics` or `grc.investigations`
  (stricter than `grc.read`).

## Routes

| Path | Surface |
|------|---------|
| `/dashboard/grc` | GrcCommandCenterPage — GRC Command Center — **wired** |
| `/dashboard/compliance` | KycCompliancePage — **unchanged** (KYC) |

## Enterprise features (Phase 1)

1. **Enterprise Governance Command Center™** — overview + activity  
2. **Intelligent Enterprise Risk Engine™** — risk register & treatments  
3. **Smart Compliance Intelligence™** — frameworks, reviews, calendar  
4. **Executive Legal & Audit Intelligence™** — cases + findings  
5. **Enterprise Resilience Center™** — BCM / BIA  

## Code map

```text
lib/features/grca/
  domain/entities/grca_models.dart
  domain/services/grca_service.dart
  presentation/providers/grca_controller.dart
  presentation/pages/grc_command_center_page.dart

lib/core/router/shell_routes.dart          # wires admin grc → GrcCommandCenterPage
lib/core/constants/permissions.dart        # grc.* slugs
lib/core/constants/route_paths.dart        # dashboardGrc
supabase/migrations/20260714260000_enterprise_grc_audit_legal_management.sql
```

## Permissions (after SQL apply)

- `grc.read`, `grc.write`, `grc.risks`, `grc.compliance`, `grc.policies`
- `grc.audit`, `grc.legal`, `grc.ethics`, `grc.investigations`
- `grc.board`, `grc.bcm`, `grc.approvals`, `grc.analytics`, `grc.ai`, `grc.reports`

Grants: `super_admin` / `admin` all; `finance` read/risks/compliance/audit/analytics/reports/approvals; `construction_manager` read/risks/compliance/bcm; `sales_team` read/policies; `marketing` read/policies.

## Schema notes

- Realtime on: `risk_register`, `audit_findings`, `ethics_reports`,
  `regulatory_calendar`, `legal_cases`, `grc_activity_logs`, `grc_notifications`.
- RLS via `has_permission('slug', auth.uid())` (slug first).
- Riverpod: **never read `state` inside `Notifier.build()`** — ticker armed from initial return value only.

## Tests

```bash
flutter test test/grca_platform_test.dart
```

## Volume 4 continuity

Parts **16–25** remain planned. Part 15 SQL is applied — ready for Part 16 master prompt.
