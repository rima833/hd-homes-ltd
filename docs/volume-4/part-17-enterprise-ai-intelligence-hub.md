# Volume 4 — Part 17: Enterprise AI Intelligence Hub, Machine Learning & Decision Support (EAIH)

AI Command Center for HD Homes admins — enterprise copilots, model registry, predictions, recommendations, AI search/RAG, knowledge graph stubs, automation, decision intelligence, governance/trust, and observability.

Admin feature lives under `lib/features/eaih/`.

## Status

| Layer | Status |
|-------|--------|
| Domain models + demo dataset | Done |
| EaihService (Supabase selects + demo fallback) | Done |
| Riverpod snapshot / Realtime / UI controller | Done |
| `/dashboard/ai` AI Command Center | Done |
| SQL + RLS + new hub tables + Volume 3 enrich | **APPLIED** remotely 2026-07-21 |
| Full ML Ops / vector production / multi-provider routing | Phase 2 |

Canonical migration:

`supabase/migrations/20260714280000_enterprise_ai_intelligence_hub.sql`

Header: **APPLIED** remotely 2026-07-21 (chunked `enterprise_ai_intelligence_hub_p1_schema` / `p2_seeds` / `p3_rls`). Ready for Part 18.

Part 16 BIADW SQL is **APPLIED**.

## Architecture

```text
AiCommandCenterPage
        ↓
eaihSnapshotProvider + eaihControllerProvider
        ↓
EaihService ──► Supabase (ai_services, ai_models, ai_copilots,
               ai_predictions, ai_recommendations (enriched),
               ai_search_*, ai_knowledge_graph_*, ai_automation_*,
               ai_governance_policies, ai_hub_insights, …)
        ↓            └─ demo fallback when offline / empty / missing tables
Widgets (KPI · Copilots · Models · Predictions · Automation · Decision · Governance)
```

## Schema approach

- **Route** wires existing `/dashboard/ai` (`RoutePaths.aiGovernance`) → `AiCommandCenterPage`.
- Governance UI becomes a **tab** inside the Command Center (not a separate admin page for this route).
- `/account/ai` personal AI workspace — **unchanged**.
- **Enrich only** (never DROP/recreate) Volume 3 AI tables:
  `ai_conversations`, `ai_messages`, `ai_sessions`, `ai_prompt_templates`,
  `ai_knowledge_sources`, `ai_feedback`, `ai_usage_logs`, `ai_recommendations`,
  `ai_context_cache`, `ai_provider_settings`, `ai_rate_limits`, `ai_audit_logs`.
- **Do not recreate**: `ai_prompts` (EOC), `ai_executive_insights` (Part 1),
  module `*_ai_insights`, `analytics_ai_conversations`.
- **CREATE NEW**: `ai_services`, `ai_models`, `ai_model_versions`, `ai_training_jobs`,
  `ai_predictions`, `ai_copilots`, `ai_prompt_versions`, `ai_embeddings`,
  `ai_vector_indexes`, `ai_search_queries`, `ai_search_results`,
  `ai_knowledge_graph_nodes`, `ai_knowledge_graph_edges`, `ai_workflow_rules`,
  `ai_automation_jobs`, `ai_model_monitoring`, `ai_drift_reports`,
  `ai_governance_policies`, `ai_activity_logs`, `ai_notifications`, `ai_hub_insights`.
- pgvector optional; Phase 1 stores `embedding jsonb` (+ optional `embedding_vector` if extension loads).
- Seed UUIDs are hex-only (`f170…`).
- AI seeds / Flutter insights use advisory disclaimer:
  **AI-generated — editable / advisory**.
- Storage bucket: `ai-artifacts`.

## Routes

| Path | Surface |
|------|---------|
| `/dashboard/ai` | AiCommandCenterPage — AI Command Center — **wired** |
| `/account/ai` | AiWorkspacePage — **unchanged** (personal) |
| `/dashboard/analytics` | BiCommandCenterPage — **unchanged** (Part 16) |
| `/dashboard/eoc` | EocMissionControlPage — **unchanged** (Part 10) |

## Enterprise features (Phase 1)

1. **Enterprise AI Operating System™** — overview + activity  
2. **HD Homes Knowledge Intelligence™** — knowledge graph stubs + search  
3. **Executive Decision Intelligence™** — advisory decision briefing + hub insights  
4. **Intelligent Enterprise Automation™** — rules + automation jobs  
5. **Responsible AI & Trust Center™** — governance policies (tab)

## Code map

```text
lib/features/eaih/
  domain/entities/eaih_models.dart
  domain/services/eaih_service.dart
  presentation/providers/eaih_controller.dart
  presentation/pages/ai_command_center_page.dart

lib/core/router/shell_routes.dart          # wires admin /dashboard/ai → AiCommandCenterPage
lib/core/constants/permissions.dart        # aihub.* slugs
lib/core/constants/route_paths.dart        # aiGovernance (existing)
lib/core/navigation/navigation_config.dart # AI Hub nav item
supabase/migrations/20260714280000_enterprise_ai_intelligence_hub.sql
```

## Permissions (after SQL apply)

- `aihub.read`, `aihub.write`, `aihub.copilots`, `aihub.models`
- `aihub.predictions`, `aihub.recommendations`, `aihub.search`, `aihub.rag`
- `aihub.automation`, `aihub.governance`, `aihub.observability`
- `aihub.approvals`, `aihub.analytics`, `aihub.admin`

Grants: `super_admin` / `admin` all; `finance` read/copilots/predictions/analytics;
`construction_manager` read/copilots/predictions;
`sales_team` / `marketing` read/copilots/recommendations/search.

## Schema notes

- Realtime on: `ai_predictions`, `ai_recommendations`, `ai_automation_jobs`,
  `ai_model_monitoring`, `ai_activity_logs`, `ai_notifications`, `ai_conversations`.
- RLS via `has_permission('slug', auth.uid())` (slug first).
- Riverpod: **never read `state` inside `Notifier.build()`** — ticker armed from initial return value only.

## Tests

```bash
flutter test test/eaih_platform_test.dart
```

## Volume 4 continuity

Parts **18–25** remain planned. Part 17 SQL is **APPLIED** remotely (2026-07-21) — Part 18 can start when ready.
