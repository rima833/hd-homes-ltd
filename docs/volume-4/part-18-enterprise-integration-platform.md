# Volume 4 — Part 18: Enterprise Integration Platform, API Gateway, Workflow Orchestration & Event-Driven Architecture (EIP)

Integration Command Center for HD Homes admins — API gateway, workflow orchestration (enriching EOC), domain events, queues, webhooks, connectors, security, monitoring, config, analytics, and AI insights.

Admin feature lives under `lib/features/eip/`.

## Status

| Layer | Status |
|-------|--------|
| Domain models + demo dataset | Done |
| EipService (Supabase selects + demo fallback) | Done |
| Riverpod snapshot / Realtime / UI controller | Done |
| `/dashboard/integrations` Integration Command Center | Done |
| SQL + RLS + new tables + EOC workflow enrich | **LOCAL ONLY — await approve** |
| Full production gateway / broker / secret vault | Phase 2 |

Canonical migration:

`supabase/migrations/20260714290000_enterprise_integration_platform.sql`

Header: **LOCAL ONLY — await approve**. Do **not** apply remotely until approved.

Part 17 EAIH SQL is **APPLIED**. Volume 4 continues Parts 19–25 — wait for approve before Part 19.

## Architecture

```text
IntegrationCommandCenterPage
        ↓
eipSnapshotProvider + eipControllerProvider
        ↓
EipService ──► Supabase (api_services, workflow_definitions (enriched),
               workflow_tasks / approvals, domain_events, message_queues,
               webhook_*, integration_connectors, health checks,
               integration_ai_insights, …)
        ↓            └─ demo fallback when offline / empty / missing tables
Widgets (KPI · APIs · Workflows · Events · Queues · Webhooks · Connectors · Ops)
```

## Schema approach

- **Route**: `/dashboard/integrations` → `IntegrationCommandCenterPage`.
- **Enrich only** (never DROP/recreate) EOC tables:
  `workflow_definitions`, `workflow_instances`
  (EOC already has `workflow_steps`, `workflow_conditions`, `workflow_actions`).
- **Do not recreate** thin logs: `api_logs`, `integration_logs`
  (prompt names: `api_usage_logs`, `integration_activity_logs`).
- **CREATE NEW** workflow extensions: `workflow_versions`, `workflow_tasks`,
  `workflow_approvals`, `workflow_execution_logs`.
- **CREATE NEW** platform tables: API gateway, events, queues, webhooks,
  connectors (encrypt-ready credentials), registry/flags/config, reports,
  activity, notifications, AI insights.
- Credentials store `encrypted_payload jsonb` + `key_ref text` (no plaintext secrets in seeds).
- Seed UUIDs are hex-only (`a180…`).
- AI seeds / Flutter insights use advisory disclaimer:
  **AI-generated — editable / advisory**.
- Storage bucket: `integration-logs`.

## Routes

| Path | Surface |
|------|---------|
| `/dashboard/integrations` | IntegrationCommandCenterPage — **wired** |
| `/dashboard/ai` | AiCommandCenterPage — **unchanged** (Part 17) |
| `/dashboard/eoc` | EocMissionControlPage — **unchanged** (Part 10) |
| `/dashboard/analytics` | BiCommandCenterPage — **unchanged** (Part 16) |

## Enterprise features (Phase 1)

1. **Enterprise Integration Command Center™** — overview + activity  
2. **Intelligent Workflow Automation™** — enriched EOC defs + tasks/approvals  
3. **Enterprise Event Intelligence™** — domain events + subscriptions  
4. **Universal Connector Framework™** — paystack / email / maps stubs  
5. **Digital Operations Control Tower™** — health + registry + ops briefing  

## Code map

```text
lib/features/eip/
  domain/entities/eip_models.dart
  domain/services/eip_service.dart
  presentation/providers/eip_controller.dart
  presentation/pages/integration_command_center_page.dart

lib/core/router/shell_routes.dart          # wires /dashboard/integrations
lib/core/constants/permissions.dart        # integration.* slugs
lib/core/constants/route_paths.dart        # dashboardIntegrations
lib/core/navigation/navigation_config.dart # Integrations after AI Hub
supabase/migrations/20260714290000_enterprise_integration_platform.sql
```

## Permissions (after SQL apply)

- `integration.read`, `integration.write`, `integration.apis`, `integration.workflows`
- `integration.events`, `integration.webhooks`, `integration.queues`, `integration.connectors`
- `integration.security`, `integration.monitoring`, `integration.ai`, `integration.admin`

Role grants:

- `super_admin` / `admin` — all
- `finance` — read, apis, workflows, monitoring
- `construction_manager` — read, workflows, events, monitoring
- `sales_team` — read, webhooks, events
- `marketing` — read, webhooks, connectors

## Tabs

Overview · APIs · Workflows · Events · Queues · Webhooks · Connectors · Security · Monitoring · Config · Analytics · AI

## Tests

`test/eip_platform_test.dart` — demo snapshot, KPI labels, AI disclaimer, register coverage, offline service, ops briefing, signals, tab contract (no state-in-build).

## Next

Await approve to apply SQL remotely. Do **not** start Part 19 until approved.
