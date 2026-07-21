-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.ai_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_models ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_model_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_training_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_predictions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_copilots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_prompt_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_embeddings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_vector_indexes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_search_queries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_search_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_knowledge_graph_nodes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_knowledge_graph_edges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_workflow_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_automation_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_model_monitoring ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_drift_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_governance_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_hub_insights ENABLE ROW LEVEL SECURITY;

-- Helper: slug FIRST in has_permission

DROP POLICY IF EXISTS ai_services_select ON public.ai_services;
DROP POLICY IF EXISTS ai_services_write ON public.ai_services;
CREATE POLICY ai_services_select ON public.ai_services FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_services_write ON public.ai_services FOR ALL
  USING (public.has_permission('aihub.write', auth.uid()) OR public.has_permission('aihub.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.write', auth.uid()) OR public.has_permission('aihub.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_models_select ON public.ai_models;
DROP POLICY IF EXISTS ai_models_write ON public.ai_models;
CREATE POLICY ai_models_select ON public.ai_models FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.models', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_models_write ON public.ai_models FOR ALL
  USING (public.has_permission('aihub.models', auth.uid()) OR public.has_permission('aihub.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.models', auth.uid()) OR public.has_permission('aihub.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_model_versions_select ON public.ai_model_versions;
DROP POLICY IF EXISTS ai_model_versions_write ON public.ai_model_versions;
CREATE POLICY ai_model_versions_select ON public.ai_model_versions FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.models', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_model_versions_write ON public.ai_model_versions FOR ALL
  USING (public.has_permission('aihub.models', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.models', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_training_jobs_select ON public.ai_training_jobs;
DROP POLICY IF EXISTS ai_training_jobs_write ON public.ai_training_jobs;
CREATE POLICY ai_training_jobs_select ON public.ai_training_jobs FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.models', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_training_jobs_write ON public.ai_training_jobs FOR ALL
  USING (public.has_permission('aihub.models', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.models', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_predictions_select ON public.ai_predictions;
DROP POLICY IF EXISTS ai_predictions_write ON public.ai_predictions;
CREATE POLICY ai_predictions_select ON public.ai_predictions FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.predictions', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_predictions_write ON public.ai_predictions FOR ALL
  USING (public.has_permission('aihub.predictions', auth.uid()) OR public.has_permission('aihub.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.predictions', auth.uid()) OR public.has_permission('aihub.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_copilots_select ON public.ai_copilots;
DROP POLICY IF EXISTS ai_copilots_write ON public.ai_copilots;
CREATE POLICY ai_copilots_select ON public.ai_copilots FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.copilots', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_copilots_write ON public.ai_copilots FOR ALL
  USING (public.has_permission('aihub.copilots', auth.uid()) OR public.has_permission('aihub.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.copilots', auth.uid()) OR public.has_permission('aihub.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_prompt_versions_select ON public.ai_prompt_versions;
DROP POLICY IF EXISTS ai_prompt_versions_write ON public.ai_prompt_versions;
CREATE POLICY ai_prompt_versions_select ON public.ai_prompt_versions FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.copilots', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_prompt_versions_write ON public.ai_prompt_versions FOR ALL
  USING (public.has_permission('aihub.copilots', auth.uid()) OR public.has_permission('aihub.approvals', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.copilots', auth.uid()) OR public.has_permission('aihub.approvals', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_embeddings_select ON public.ai_embeddings;
DROP POLICY IF EXISTS ai_embeddings_write ON public.ai_embeddings;
CREATE POLICY ai_embeddings_select ON public.ai_embeddings FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.rag', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_embeddings_write ON public.ai_embeddings FOR ALL
  USING (public.has_permission('aihub.rag', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.rag', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_vector_indexes_select ON public.ai_vector_indexes;
DROP POLICY IF EXISTS ai_vector_indexes_write ON public.ai_vector_indexes;
CREATE POLICY ai_vector_indexes_select ON public.ai_vector_indexes FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.rag', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_vector_indexes_write ON public.ai_vector_indexes FOR ALL
  USING (public.has_permission('aihub.rag', auth.uid()) OR public.has_permission('aihub.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.rag', auth.uid()) OR public.has_permission('aihub.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_search_queries_select ON public.ai_search_queries;
DROP POLICY IF EXISTS ai_search_queries_write ON public.ai_search_queries;
CREATE POLICY ai_search_queries_select ON public.ai_search_queries FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.search', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_search_queries_write ON public.ai_search_queries FOR ALL
  USING (public.has_permission('aihub.search', auth.uid()) OR public.has_permission('aihub.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.search', auth.uid()) OR public.has_permission('aihub.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_search_results_select ON public.ai_search_results;
DROP POLICY IF EXISTS ai_search_results_write ON public.ai_search_results;
CREATE POLICY ai_search_results_select ON public.ai_search_results FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.search', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_search_results_write ON public.ai_search_results FOR ALL
  USING (public.has_permission('aihub.search', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.search', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_knowledge_graph_nodes_select ON public.ai_knowledge_graph_nodes;
DROP POLICY IF EXISTS ai_knowledge_graph_nodes_write ON public.ai_knowledge_graph_nodes;
CREATE POLICY ai_knowledge_graph_nodes_select ON public.ai_knowledge_graph_nodes FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.rag', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_knowledge_graph_nodes_write ON public.ai_knowledge_graph_nodes FOR ALL
  USING (public.has_permission('aihub.rag', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.rag', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_knowledge_graph_edges_select ON public.ai_knowledge_graph_edges;
DROP POLICY IF EXISTS ai_knowledge_graph_edges_write ON public.ai_knowledge_graph_edges;
CREATE POLICY ai_knowledge_graph_edges_select ON public.ai_knowledge_graph_edges FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.rag', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_knowledge_graph_edges_write ON public.ai_knowledge_graph_edges FOR ALL
  USING (public.has_permission('aihub.rag', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.rag', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_workflow_rules_select ON public.ai_workflow_rules;
DROP POLICY IF EXISTS ai_workflow_rules_write ON public.ai_workflow_rules;
CREATE POLICY ai_workflow_rules_select ON public.ai_workflow_rules FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.automation', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_workflow_rules_write ON public.ai_workflow_rules FOR ALL
  USING (public.has_permission('aihub.automation', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.automation', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_automation_jobs_select ON public.ai_automation_jobs;
DROP POLICY IF EXISTS ai_automation_jobs_write ON public.ai_automation_jobs;
CREATE POLICY ai_automation_jobs_select ON public.ai_automation_jobs FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.automation', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_automation_jobs_write ON public.ai_automation_jobs FOR ALL
  USING (public.has_permission('aihub.automation', auth.uid()) OR public.has_permission('aihub.approvals', auth.uid()) OR public.has_permission('aihub.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.automation', auth.uid()) OR public.has_permission('aihub.approvals', auth.uid()) OR public.has_permission('aihub.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_model_monitoring_select ON public.ai_model_monitoring;
DROP POLICY IF EXISTS ai_model_monitoring_write ON public.ai_model_monitoring;
CREATE POLICY ai_model_monitoring_select ON public.ai_model_monitoring FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.observability', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_model_monitoring_write ON public.ai_model_monitoring FOR ALL
  USING (public.has_permission('aihub.observability', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.observability', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_drift_reports_select ON public.ai_drift_reports;
DROP POLICY IF EXISTS ai_drift_reports_write ON public.ai_drift_reports;
CREATE POLICY ai_drift_reports_select ON public.ai_drift_reports FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.observability', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_drift_reports_write ON public.ai_drift_reports FOR ALL
  USING (public.has_permission('aihub.observability', auth.uid()) OR public.has_permission('aihub.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.observability', auth.uid()) OR public.has_permission('aihub.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_governance_policies_select ON public.ai_governance_policies;
DROP POLICY IF EXISTS ai_governance_policies_write ON public.ai_governance_policies;
CREATE POLICY ai_governance_policies_select ON public.ai_governance_policies FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.governance', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_governance_policies_write ON public.ai_governance_policies FOR ALL
  USING (public.has_permission('aihub.governance', auth.uid()) OR public.has_permission('aihub.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.governance', auth.uid()) OR public.has_permission('aihub.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_activity_logs_select ON public.ai_activity_logs;
DROP POLICY IF EXISTS ai_activity_logs_write ON public.ai_activity_logs;
CREATE POLICY ai_activity_logs_select ON public.ai_activity_logs FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.observability', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_activity_logs_write ON public.ai_activity_logs FOR ALL
  USING (public.has_permission('aihub.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_notifications_select ON public.ai_notifications;
DROP POLICY IF EXISTS ai_notifications_write ON public.ai_notifications;
CREATE POLICY ai_notifications_select ON public.ai_notifications FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_notifications_write ON public.ai_notifications FOR ALL
  USING (public.has_permission('aihub.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ai_hub_insights_select ON public.ai_hub_insights;
DROP POLICY IF EXISTS ai_hub_insights_write ON public.ai_hub_insights;
CREATE POLICY ai_hub_insights_select ON public.ai_hub_insights FOR SELECT
  USING (public.has_permission('aihub.read', auth.uid()) OR public.has_permission('aihub.analytics', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ai_hub_insights_write ON public.ai_hub_insights FOR ALL
  USING (public.has_permission('aihub.write', auth.uid()) OR public.has_permission('aihub.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('aihub.write', auth.uid()) OR public.has_permission('aihub.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));
