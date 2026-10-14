# Volume 4 — Part 20: Enterprise DevOps, Platform Engineering, Infrastructure, Observability & Release Management Platform (EDP)

Enterprise DevOps, platform engineering, infrastructure, observability, release, and change management for HD Homes.

## Status

| Layer | Status |
|---|---|
| Domain models + demo snapshot | Done |
| Supabase service + offline fallback | Done |
| Riverpod controller + Realtime invalidation | Done |
| `/dashboard/platform` command center | Done |
| SQL, permissions, RLS, storage, seeds | **APPLIED** remotely (2026-07-21) |

Canonical migration: `supabase/migrations/20260714310000_enterprise_devops_platform_engineering.sql`

## Architecture

`DevOpsCommandCenterPage` → EDP Riverpod providers → `EdpService` → Supabase with per-table demo fallback.

The command center has 12 tabs: Overview, Environments, Pipelines, Deployments, Releases, Changes, Infrastructure, Observability, Flags, Incidents, Analytics, and AI.

Phase 1 enterprise surfaces:

1. Enterprise Platform Operations Center™
2. Intelligent Release Manager™
3. Smart Infrastructure Intelligence™
4. Engineering Productivity Hub™
5. Enterprise Reliability Center™

## Collision-safe schema

Enriched with `ALTER TABLE … ADD COLUMN IF NOT EXISTS` only:

- `feature_flags` — `platform_surface`, `owner_label`, `hub_metadata`
- `configuration_settings` — `environment_id`, `version`, `hub_metadata`

EDP does **not** recreate EIP `feature_flags` / `configuration_settings`, does **not** touch CRM/Sales pipelines, does **not** use `analytics_pipeline_logs` (uses `pipeline_runs` / `pipeline_stages`), and does **not** create bare `change_requests` (uses `platform_change_requests` + `platform_change_reviews`).

New tables:

- Delivery: `environments`, `deployment_pipelines`, `pipeline_runs`, `pipeline_stages`, `deployments`, `deployment_artifacts`
- Release/change: `releases`, `release_notes`, `release_approvals`, `platform_change_requests`, `platform_change_reviews`
- Infra/config: `infrastructure_resources`, `infrastructure_versions`, `configuration_profiles`, `feature_flag_rules`
- Observability: `observability_metrics`, `application_logs`, `platform_logs`, `performance_metrics`
- Reliability: `incident_operations`, `operational_runbooks`, `service_health`, `service_level_objectives`, `service_level_indicators`, `capacity_forecasts`
- Ops intel: `platform_activity_logs`, `platform_notifications`, `platform_ai_insights`

Private storage bucket: `platform-artifacts`.

Realtime: `pipeline_runs`, `deployments`, `releases`, `service_health`, `platform_activity_logs`, `platform_notifications`.

## Permissions

`platform.read`, `platform.write`, `platform.environments`, `platform.pipelines`, `platform.deployments`, `platform.releases`, `platform.changes`, `platform.infrastructure`, `platform.observability`, `platform.flags`, `platform.incidents`, `platform.ai`, `platform.analytics`, `platform.admin`.

Role grants:

- `super_admin`, `admin`: all
- `finance`: read, analytics, releases
- `construction_manager`: read, observability
- `sales_team`: read
- `marketing`: read, flags

RLS calls `has_permission('slug', auth.uid())` with the slug first.

## Route note

`/dashboard/platform` → DevOps Command Center. Do **not** replace `/dashboard/activity-logs` ObservabilityCommandCenterPage.

## Verification

`test/edp_platform_test.dart` covers demo surfaces, KPI strip, advisory AI output, release/change register data, offline service fallback, briefing/signals, and the 12-tab controller contract.

## Next

SQL applied and verified. Volume 4 continues through Parts 21–25.
