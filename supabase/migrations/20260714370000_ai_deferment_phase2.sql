-- ============================================================================
-- HD HOMES ENTERPRISE PLATFORM — AI DEFERMENT (PRE-LAUNCH VERSION)
-- ============================================================================
-- AI capabilities have been intentionally deferred until Phase 2
-- (Post-Launch AI Upgrade). The platform architecture remains fully
-- AI-ready, allowing AI modules to be integrated later without major
-- architectural changes.
--
-- WHAT THIS MIGRATION DOES
--   1. Drops AI *infrastructure* tables only:
--      - Volume 3 AI workspace / digital assistant (12 tables)
--      - Part 17 Enterprise AI Intelligence Hub (21 tables)
--      - EOC ai_prompts, BIADW analytics_ai_conversations
--   2. Removes the `aihub.*` permission slugs (14) and their role grants.
--   3. Removes the unplaced `eoc_ai_brief` dashboard widget seed.
--   4. Removes the `ai-artifacts` storage bucket.
--
-- WHAT THIS MIGRATION DOES **NOT** TOUCH (deliberately kept)
--   - Every business table, ID, relationship and constraint.
--   - Per-module advisory tables (*_ai_insights, ai_executive_insights,
--     ai_security_events): retained as rule-based advisory/annotation
--     storage; the UI no longer labels them as AI. They are the Phase 2
--     re-attachment points.
--   - Module `<module>.ai` permission slugs: reserved for Phase 2
--     re-enablement (harmless while the AI UI is feature-flagged off).
--   - Audit logs, access logs, RBAC, RLS, MFA, notifications.
--
-- Phase 2 restores the dropped infrastructure via new migrations and by
-- flipping `kAiFeaturesEnabled` in lib/core/config/ai_features.dart.
-- ============================================================================

-- ── 1. Part 17: Enterprise AI Intelligence Hub infrastructure ──────────────
DROP TABLE IF EXISTS public.ai_hub_insights CASCADE;
DROP TABLE IF EXISTS public.ai_notifications CASCADE;
DROP TABLE IF EXISTS public.ai_activity_logs CASCADE;
DROP TABLE IF EXISTS public.ai_governance_policies CASCADE;
DROP TABLE IF EXISTS public.ai_drift_reports CASCADE;
DROP TABLE IF EXISTS public.ai_model_monitoring CASCADE;
DROP TABLE IF EXISTS public.ai_automation_jobs CASCADE;
DROP TABLE IF EXISTS public.ai_workflow_rules CASCADE;
DROP TABLE IF EXISTS public.ai_knowledge_graph_edges CASCADE;
DROP TABLE IF EXISTS public.ai_knowledge_graph_nodes CASCADE;
DROP TABLE IF EXISTS public.ai_search_results CASCADE;
DROP TABLE IF EXISTS public.ai_search_queries CASCADE;
DROP TABLE IF EXISTS public.ai_vector_indexes CASCADE;
DROP TABLE IF EXISTS public.ai_embeddings CASCADE;
DROP TABLE IF EXISTS public.ai_prompt_versions CASCADE;
DROP TABLE IF EXISTS public.ai_copilots CASCADE;
DROP TABLE IF EXISTS public.ai_predictions CASCADE;
DROP TABLE IF EXISTS public.ai_training_jobs CASCADE;
DROP TABLE IF EXISTS public.ai_model_versions CASCADE;
DROP TABLE IF EXISTS public.ai_models CASCADE;
DROP TABLE IF EXISTS public.ai_services CASCADE;

-- ── 2. Volume 3: AI workspace / digital assistant infrastructure ───────────
DROP TABLE IF EXISTS public.ai_audit_logs CASCADE;
DROP TABLE IF EXISTS public.ai_rate_limits CASCADE;
DROP TABLE IF EXISTS public.ai_provider_settings CASCADE;
DROP TABLE IF EXISTS public.ai_context_cache CASCADE;
DROP TABLE IF EXISTS public.ai_recommendations CASCADE;
DROP TABLE IF EXISTS public.ai_usage_logs CASCADE;
DROP TABLE IF EXISTS public.ai_feedback CASCADE;
DROP TABLE IF EXISTS public.ai_knowledge_sources CASCADE;
DROP TABLE IF EXISTS public.ai_prompt_templates CASCADE;
DROP TABLE IF EXISTS public.ai_sessions CASCADE;
DROP TABLE IF EXISTS public.ai_messages CASCADE;
DROP TABLE IF EXISTS public.ai_conversations CASCADE;

-- ── 3. Stray AI infrastructure from other parts ─────────────────────────────
DROP TABLE IF EXISTS public.ai_prompts CASCADE;                 -- EOC prompt library
DROP TABLE IF EXISTS public.analytics_ai_conversations CASCADE; -- BIADW conversational analytics

-- ── 4. AI Hub permissions (aihub.*) ─────────────────────────────────────────
DELETE FROM public.role_permissions
WHERE permission_id IN (
  SELECT id FROM public.permissions WHERE slug LIKE 'aihub.%'
);
DELETE FROM public.permissions WHERE slug LIKE 'aihub.%';

-- ── 5. EOC AI briefing widget seed (unplaced) ───────────────────────────────
DELETE FROM public.eoc_dashboard_layouts
WHERE widget_id IN (
  SELECT id FROM public.eoc_dashboard_widgets WHERE slug = 'eoc_ai_brief'
);
DELETE FROM public.eoc_dashboard_widgets WHERE slug = 'eoc_ai_brief';

-- ── 6. AI artifacts storage bucket ──────────────────────────────────────────
-- SKIPPED on remote apply (2026-07-21): Supabase blocks direct DELETE from
-- storage.objects / storage.buckets via protect_delete(). The empty
-- `ai-artifacts` bucket may remain; it is unused while AI is deferred.
-- Phase 2 can reuse it or delete via the Storage API / Dashboard.

-- ============================================================================
-- STATUS: APPLIED remotely 2026-07-21 as `ai_deferment_phase2`
-- (tables + aihub.* permissions + eoc_ai_brief removed; bucket retained).
-- Platform operates with zero AI dependencies; AI-ready for Phase 2.
-- ============================================================================
