# Volume 4 — Part 24: Enterprise Governance, Risk Management, Compliance (GRC), Internal Audit & Business Continuity Platform (EGRC)

Executive governance, enterprise risk, compliance, controls, internal audit, remediation, BCM, and operational resilience for HD Homes — layered on Part 15 GRCA without replacing it.

## Status

| Layer | Status |
|---|---|
| Domain models + demo snapshot | Done |
| Supabase service + offline fallback | Done |
| Riverpod controller + Realtime invalidation | Done |
| `/dashboard/egrc` command center | Done |
| SQL, permissions, RLS, storage, seeds | **APPLIED** remotely (2026-07-21) |

Canonical migration: `supabase/migrations/20260714350000_enterprise_grc_platform.sql`

## Architecture

`EgrcCommandCenterPage` → EGRC Riverpod providers → `EgrcService` → Supabase with per-table demo fallback (reads enriched GRCA tables + new gap tables).

The command center has 12 tabs: Overview, Governance, Risks, Compliance, Policies, Controls, Audit, Remediation, BCM, Resilience, Obligations, and AI.

Phase 1 enterprise surfaces:

1. Executive Governance Intelligence Center™
2. Intelligent Enterprise Risk Engine™
3. Enterprise Compliance Command Center™
4. Digital Internal Audit Platform™
5. Enterprise Resilience Center™

## Collision-safe schema

Enriched with `ALTER TABLE … ADD COLUMN IF NOT EXISTS` only:

- `risk_register`, `corporate_policies`, `audit_findings`, `corrective_actions`, `business_continuity_plans`, `compliance_requirements`, `grc_reports` — `egrc_surface`, `hub_metadata`

EGRC does **not** recreate:

- Part 15 GRCA risk / policy / audit / BCM / board / `grc_*` tables
- ESP `resilience_assessments` / `disaster_recovery_tests` (uses `operational_resilience_scores` + `bcm_continuity_tests`)
- `/dashboard/grc` GrcCommandCenterPage
- `/dashboard/compliance` KycCompliancePage

New tables: `governance_structures`, `governance_committees`, `governance_meetings`, `governance_decisions`, `internal_controls`, `control_assessments`, `compliance_evidence`, `preventive_actions`, `bcm_continuity_tests`, `regulatory_obligations`, `operational_resilience_scores`, `egrc_activity_logs`, `egrc_notifications`, `egrc_ai_insights`.

Private storage bucket: `egrc-artifacts`.

Realtime: `governance_decisions`, `internal_controls`, `preventive_actions`, `bcm_continuity_tests`, `regulatory_obligations`, `egrc_notifications`.

## Permissions

`egrc.read`, `egrc.write`, `egrc.governance`, `egrc.risks`, `egrc.compliance`, `egrc.policies`, `egrc.controls`, `egrc.audit`, `egrc.remediation`, `egrc.bcm`, `egrc.resilience`, `egrc.obligations`, `egrc.ai`, `egrc.admin`.

Role grants:

- `super_admin`, `admin`: all
- `finance`: read, risks, compliance, controls, audit, remediation, ai
- `construction_manager`: read, risks, bcm, resilience, remediation
- `sales_team`: read, policies
- `marketing`: read, policies, compliance

RLS calls `has_permission('slug', auth.uid())` with the slug first.

## Route note

`/dashboard/egrc` → EGRC Command Center. Do **not** replace `/dashboard/grc` or `/dashboard/compliance`.

## Verification

`test/egrc_platform_test.dart` covers demo surfaces, KPI strip, advisory AI output, control/remediation/BCM register data, offline service fallback, briefing/signals, and the 12-tab controller contract.

## Next

SQL applied and verified. Part 25 ECC SQL is **APPLIED**. **Volume 4 is complete.**
