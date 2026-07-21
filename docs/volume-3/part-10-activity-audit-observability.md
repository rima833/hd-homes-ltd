# Volume 3 — Part 10: Activity Logs, Audit Trails & System Monitoring

Enterprise Observability & Audit Platform — centralized Event Bus, immutable audit trails, activity timelines, security alerting, and Executive Command Center.

## Status

| Layer | Status |
|-------|--------|
| Domain (severity, categories, Event Bus™, anomaly helpers) | Done |
| `AuditService` (sole write path + RPC fallback) | Done |
| Activity Timeline UI | Done |
| Observability Command Center | Done |
| Realtime invalidation providers | Done |
| SQL + realtime publication | **Applied** as `activity_audit_observability` (2026-07-13) |

Local file: `supabase/migrations/20260713180000_activity_audit_observability.sql`

## Architecture

```text
Business module
  → Enterprise Event Bus™
  → AuditService.publish()
  → publish_audit_event (Postgres)
      → audit_logs (immutable)
      → activity_logs (user timeline)
      → change_history
      → system_alerts (severity ≥ warning)
      → compliance_vault (high-value / immutable flag)
      → security_events (security / auth categories)
  → Supabase Realtime → Command Center / Timeline
```

Feature modules must **not** insert into audit tables directly.

## Routes

| Path | Purpose |
|------|---------|
| `/account/activity` | Personal Activity Timeline |
| `/dashboard/activity-logs` | Observability / Executive Command Center |

Also linked from Profile Center and Security Center.

## Enterprise features

1. **Enterprise Event Bus™** — fan-out to audit, notifications, analytics, AI, workflow subscribers  
2. **Executive Command Center** — activity, alerts, health, security score  
3. **Intelligent Anomaly Detection** — future-ready flags (no auto-block)  
4. **Immutable Compliance Vault™** — `compliance_vault` + mutation triggers  
5. **Operational Intelligence** — metrics / health / retention schemas  

## Existing tables reused

- `audit_logs` — extended with severity, correlation, old/new values, etc.  
- `security_events` — mirrored for security/auth categories  
- `user_activity` — fallback write if `activity_logs` missing  

## Tests

```bash
flutter test test/observability_platform_test.dart
```

## Approval gate

Part 10 SQL is applied. **Part 11 — Organization, Teams & Staff Management** is implemented in-app; apply its SQL only after approval.
