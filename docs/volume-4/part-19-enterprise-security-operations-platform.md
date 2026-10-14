# Volume 4 — Part 19: Enterprise Security Operations Platform (ESP)

Enterprise SOC, IAM, cybersecurity, privacy, secrets, backup, disaster recovery, analytics, and AI security for HD Homes.

## Status

| Layer | Status |
|---|---|
| Domain models + demo snapshot | Done |
| Supabase service + offline fallback | Done |
| Riverpod controller + Realtime invalidation | Done |
| `/dashboard/security` command center | Done |
| SQL, permissions, RLS, storage, seeds | **APPLIED** remotely 2026-07-21 |

Canonical migration: `supabase/migrations/20260714300000_enterprise_security_operations_platform.sql`

## Architecture

`SecurityCommandCenterPage` → ESP Riverpod providers → `EspService` → Supabase with per-table demo fallback.

The command center has 12 tabs: Overview, IAM, MFA, Threats, Incidents, Audit, Privacy, Secrets, Backup, DR, Analytics, and AI.

Phase 1 enterprise surfaces:

1. Enterprise Security Command Center™
2. Intelligent Threat Intelligence Engine™
3. Adaptive Identity & Trust Platform™
4. Enterprise Privacy & Data Protection Center™
5. Digital Resilience & Recovery Center™

## Collision-safe schema

Enriched with `ALTER TABLE … ADD COLUMN IF NOT EXISTS` only:

- `user_sessions`, `trusted_devices`, `security_events`
- `mfa_settings`, `mfa_policies`
- `audit_logs`

ESP reuses `roles`, `permissions`, `role_permissions`, and `profiles`. It does not create parallel security role/user tables. MFA methods enrich `mfa_settings`; MFA recovery remains in the existing `backup_codes`. Disaster-recovery backups use `backup_jobs` and `backup_history`. ESP retention uses `security_retention_policies`, leaving DDCMS `retention_policies` unchanged.

New tables:

- SOC: `security_alerts`, `threat_detections`, `security_incidents`, `incident_evidence`
- Cryptography: `encryption_policies`, `key_management`, `secrets_registry`
- Privacy: `privacy_consents`, `privacy_requests`, `security_retention_policies`
- Recovery: `backup_jobs`, `backup_history`, `disaster_recovery_plans`, `disaster_recovery_tests`, `resilience_assessments`
- Intelligence/operations: `ai_security_events`, `security_reports`, `security_activity_logs`, `security_notifications`, `security_ai_insights`

Private storage bucket: `security-evidence`.

## Permissions

`security.read`, `security.write`, `security.iam`, `security.mfa`, `security.threats`, `security.incidents`, `security.audit`, `security.privacy`, `security.secrets`, `security.backup`, `security.dr`, `security.ai`, `security.analytics`, `security.admin`.

Role grants:

- `super_admin`, `admin`: all
- `finance`: read, audit, privacy, analytics
- `construction_manager`: read, incidents
- `sales_team`: read
- `marketing`: read, privacy

RLS calls `has_permission('slug', auth.uid())` with the slug first.

## Verification

`test/esp_platform_test.dart` covers demo surfaces, posture KPIs, advisory AI output, SOC register data, offline service fallback, briefing/signals, and the 12-tab controller contract.

## Next

Part 20 is next. Keep this migration local until the parent applies it after approval; Volume 4 continues through Parts 20–25.
