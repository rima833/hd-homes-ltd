# AI Deferment — Pre-Launch Platform Simplification

> **AI capabilities have been intentionally deferred until Phase 2 (Post-Launch
> AI Upgrade). The platform architecture remains fully AI-ready, allowing AI
> modules to be integrated later without major architectural changes.**

Status: Flutter layer complete · SQL **APPLIED** remotely 2026-07-21 (`ai_deferment_phase2`).

---

## 1. What changed

### Single kill switch

All AI UI is gated behind one compile-time flag:

- `lib/core/config/ai_features.dart` → `kAiFeaturesEnabled = false`

Flipping it to `true` restores every AI surface without touching business
logic. No models, services, controllers, enums, or tests were deleted — the
entire AI codebase stays dormant and compiles, ready for Version 2.

### Hidden / disabled surfaces (flag off)

| Surface | Behaviour in Version 1 |
|---|---|
| AI Hub (`/dashboard/ai`, Part 17 EAIH) | Route unregistered, nav item hidden |
| AI Workspace (`/account/ai`) + profile link | Route unregistered, link hidden |
| AI Concierge floating chat (public site) | Not mounted |
| Command-center **AI tabs** (~22 modules: EOC, CRM, PMS, IMP, SBMS, CPMS, FAPMS, DXP, HCM, CSHOP, DDCMS, PVISCM, EAFMS, GRCA, BIADW, EIP, ESP, EDP, EDWP, ECXP, EPM, EGRC, ECC) | Tab chip hidden; content unreachable |
| In-page `_AiAssistantPanel` (CRM, IMP, SBMS, PMS) | Not rendered |
| Overview briefings | AI disclaimer line stripped from displayed text |
| Executive dashboard AI assistant button / AI insight cards | Hidden |
| Public-site AI marketing labels (AI Recommend, AI SEARCH, AI MATCHING, AI GUIDE, AI ADVISOR, AI-powered SEO copy) | Renamed to neutral enterprise wording (Recommended, Smart Search, Featured, …) — these features were already rule-based |

### What still works (unchanged)

Authentication/RBAC/RLS, all business dashboards, KPIs, charts, reports,
standard notifications (in-app / email / SMS / push), keyword search + filters
+ sorting + pagination, saved preferences / favorites / recently viewed,
manual document upload and review, rule-based workflow approvals, audit logs,
MFA, backups.

## 2. AI-ready extension points

`lib/core/engines/engines.dart` defines the Phase 2 plug-in interfaces and the
Version 1 rule-based defaults:

| Interface | Version 1 default | Phase 2 replacement |
|---|---|---|
| `RecommendationEngine` | `RuleBasedRecommendationEngine` | AI recommendation engine |
| `SearchEngine` | `KeywordSearchEngine` | Semantic search |
| `ForecastEngine` | `TrendForecastEngine` (historical trend) | AI forecasting |
| `ContentGenerator` | `StandardReportGenerator` | LLM content generation |
| `DocumentAnalyzer` | `ManualDocumentReview` | OCR / contract analysis |
| `DecisionSupport` | `RuleBasedDecisionSupport` | AI decision support |
| `AssistantEngine` | `DisabledAssistantEngine` | AI assistants / chatbot |
| `NotificationEngine` | `StandardNotificationEngine` | Intelligent notifications |
| `WorkflowEngine` | `ManualWorkflowEngine` | AI approvals / routing |

AI modules inject behind these interfaces without changing business logic.

## 3. Database

`supabase/migrations/20260714370000_ai_deferment_phase2.sql` — **APPLIED**
remotely 2026-07-21 as migration name `ai_deferment_phase2`.

**Dropped — AI infrastructure only**

- Volume 3 AI workspace (12): `ai_conversations`, `ai_messages`, `ai_sessions`,
  `ai_prompt_templates`, `ai_knowledge_sources`, `ai_feedback`,
  `ai_usage_logs`, `ai_recommendations`, `ai_context_cache`,
  `ai_provider_settings`, `ai_rate_limits`, `ai_audit_logs`
- Part 17 AI Hub (21): `ai_services`, `ai_models`, `ai_model_versions`,
  `ai_training_jobs`, `ai_predictions`, `ai_copilots`, `ai_prompt_versions`,
  `ai_embeddings`, `ai_vector_indexes`, `ai_search_queries`,
  `ai_search_results`, `ai_knowledge_graph_nodes`, `ai_knowledge_graph_edges`,
  `ai_workflow_rules`, `ai_automation_jobs`, `ai_model_monitoring`,
  `ai_drift_reports`, `ai_governance_policies`, `ai_activity_logs`,
  `ai_notifications`, `ai_hub_insights`
- Stray infra: `ai_prompts` (EOC), `analytics_ai_conversations` (BIADW)
- `aihub.*` permissions (14) + role grants; `eoc_ai_brief` widget seed

**Kept — untouched**

- Every business table, ID, relationship, constraint
- Per-module advisory tables (`*_ai_insights`, `ai_executive_insights`,
  `ai_security_events`) — retained as generic advisory/annotation storage and
  Phase 2 re-attachment points; UI no longer labels them as AI
- Module `<module>.ai` permission slugs — reserved for Phase 2
- `ai-artifacts` storage bucket — retained (Supabase blocks direct
  `storage.objects` DELETE via `protect_delete`; unused while AI is deferred)

## 4. Phase 2 re-enablement checklist

1. Flip `kAiFeaturesEnabled` to `true`.
2. Re-run AI infrastructure migrations (Volume 3 workspace + Part 17 hub) or a
   consolidated Phase 2 schema.
3. Provide AI-backed implementations of the `core/engines` interfaces.
4. Re-seed `aihub.*` permissions and the `ai-artifacts` bucket.
5. QA the AI Hub, AI workspace, concierge, and per-module AI tabs.
