-- Seeds (hex-only UUIDs f170…)
-- ---------------------------------------------------------------------------
INSERT INTO public.ai_services (
  id, code, name, service_type, status, owner_label, summary
) VALUES
  (
    'f1700001-0000-4000-8000-000000000001',
    'SVC-INFER-01', 'Enterprise Inference Gateway', 'inference', 'active',
    'AI Platform', 'Primary inference gateway for copilots and predictions.'
  ),
  (
    'f1700001-0000-4000-8000-000000000002',
    'SVC-EMBED-01', 'Embedding & RAG Service', 'embedding', 'active',
    'AI Platform', 'Document and knowledge embeddings for hybrid search.'
  ),
  (
    'f1700001-0000-4000-8000-000000000003',
    'SVC-AUTO-01', 'Automation Orchestrator', 'automation', 'active',
    'Ops Automation', 'Rules-driven enterprise automation jobs.'
  ),
  (
    'f1700001-0000-4000-8000-000000000004',
    'SVC-COP-01', 'Copilot Runtime', 'copilot', 'active',
    'AI Platform', 'Department copilots runtime surface.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_models (
  id, service_id, code, name, model_family, status, provider_label, owner_label, summary
) VALUES
  (
    'f1700002-0000-4000-8000-000000000001',
    'f1700001-0000-4000-8000-000000000001',
    'MDL-LLM-EXEC', 'Executive Decision LLM', 'llm', 'active',
    'localFoundation', 'CEO Office', 'Executive briefing and decision support model.'
  ),
  (
    'f1700002-0000-4000-8000-000000000002',
    'f1700001-0000-4000-8000-000000000001',
    'MDL-FC-SALES', 'Sales Conversion Forecaster', 'forecast', 'active',
    'localFoundation', 'Sales Ops', 'Conversion and pipeline forecast model.'
  ),
  (
    'f1700002-0000-4000-8000-000000000003',
    'f1700001-0000-4000-8000-000000000002',
    'MDL-EMB-01', 'Knowledge Embedding v1', 'embedding', 'active',
    'localFoundation', 'AI Platform', 'Default embedding model for RAG.'
  ),
  (
    'f1700002-0000-4000-8000-000000000004',
    'f1700001-0000-4000-8000-000000000001',
    'MDL-REC-01', 'Next-Best-Action Recommender', 'recommendation', 'active',
    'localFoundation', 'CRM Lead', 'Cross-module recommendation ranker.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_model_versions (
  id, model_id, code, version_label, status, accuracy_pct, latency_ms, summary
) VALUES
  (
    'f1700003-0000-4000-8000-000000000001',
    'f1700002-0000-4000-8000-000000000001',
    'MDL-LLM-EXEC-v1', '1.0.0', 'production', 88.5, 420,
    'Production executive LLM stub.'
  ),
  (
    'f1700003-0000-4000-8000-000000000002',
    'f1700002-0000-4000-8000-000000000002',
    'MDL-FC-SALES-v2', '2.1.0', 'production', 81.2, 180,
    'Sales conversion forecaster production.'
  ),
  (
    'f1700003-0000-4000-8000-000000000003',
    'f1700002-0000-4000-8000-000000000002',
    'MDL-FC-SALES-v3', '3.0.0-rc', 'staging', 84.0, 195,
    'Candidate with improved feature set.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_training_jobs (
  id, model_id, version_id, code, name, status, owner_label, summary, started_at, finished_at
) VALUES
  (
    'f1700004-0000-4000-8000-000000000001',
    'f1700002-0000-4000-8000-000000000002',
    'f1700003-0000-4000-8000-000000000003',
    'TRN-FC-SALES-03', 'Retrain sales forecaster v3', 'success',
    'ML Ops', 'Weekly retrain on last 90 days bookings.',
    now() - interval '2 days', now() - interval '2 days' + interval '45 minutes'
  ),
  (
    'f1700004-0000-4000-8000-000000000002',
    'f1700002-0000-4000-8000-000000000004',
    NULL,
    'TRN-REC-01', 'Refresh recommender features', 'queued',
    'ML Ops', 'Queued feature refresh for next-best-action.',
    NULL, NULL
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_copilots (
  id, slug, name, department, status, model_id, owner_label, summary, capabilities
) VALUES
  (
    'f1700005-0000-4000-8000-000000000001',
    'executive', 'Executive Copilot', 'executive', 'active',
    'f1700002-0000-4000-8000-000000000001', 'CEO Office',
    'Board briefs, KPI narrative, decision packets.',
    ARRAY['briefing','decision','scorecard']
  ),
  (
    'f1700005-0000-4000-8000-000000000002',
    'sales', 'Sales Copilot', 'sales', 'active',
    'f1700002-0000-4000-8000-000000000002', 'Sales Ops',
    'Lead prioritization, follow-up drafts, conversion tips.',
    ARRAY['leads','followup','conversion']
  ),
  (
    'f1700005-0000-4000-8000-000000000003',
    'support', 'Support Copilot', 'support', 'active',
    'f1700002-0000-4000-8000-000000000001', 'CX Lead',
    'Ticket triage and response drafts with approval.',
    ARRAY['triage','draft','escalation']
  ),
  (
    'f1700005-0000-4000-8000-000000000004',
    'construction', 'Construction Copilot', 'construction', 'active',
    'f1700002-0000-4000-8000-000000000001', 'PMO',
    'Delay risk signals and milestone narratives.',
    ARRAY['delay','milestones','risk']
  ),
  (
    'f1700005-0000-4000-8000-000000000005',
    'finance', 'Finance Copilot', 'finance', 'active',
    'f1700002-0000-4000-8000-000000000001', 'CFO Office',
    'Collections watch and cash narrative stubs.',
    ARRAY['collections','cash','budget']
  ),
  (
    'f1700005-0000-4000-8000-000000000006',
    'hr', 'HR Copilot', 'hr', 'active',
    'f1700002-0000-4000-8000-000000000001', 'People Ops',
    'Policy Q&A and workforce insights (advisory).',
    ARRAY['policy','workforce']
  ),
  (
    'f1700005-0000-4000-8000-000000000007',
    'legal', 'Legal Copilot', 'legal', 'active',
    'f1700002-0000-4000-8000-000000000001', 'Legal Counsel',
    'Contract clause assist with mandatory human review.',
    ARRAY['contracts','disclaimer','review']
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_predictions (
  id, model_id, code, title, prediction_type, predicted_value, confidence_pct,
  unit, status, target_module, owner_label, summary, predicted_at
) VALUES
  (
    'f1700006-0000-4000-8000-000000000001',
    'f1700002-0000-4000-8000-000000000002',
    'PRED-CONV-30', 'Conversion next 30 days', 'conversion', 19.4, 82.0,
    'pct', 'active', 'sales', 'Sales Ops',
    'Enterprise prediction stub — conversion outlook.', now() - interval '3 hours'
  ),
  (
    'f1700006-0000-4000-8000-000000000002',
    'f1700002-0000-4000-8000-000000000001',
    'PRED-DELAY-HG', 'Horizon Gardens delay risk', 'delay', 0.34, 76.5,
    'ratio', 'active', 'construction', 'PMO',
    'Elevated delay probability on Block C.', now() - interval '1 day'
  ),
  (
    'f1700006-0000-4000-8000-000000000003',
    'f1700002-0000-4000-8000-000000000001',
    'PRED-CHURN-CRM', 'Warm lead churn risk (top 20)', 'churn', 11.0, 71.0,
    'count', 'active', 'crm', 'CRM Lead',
    'Eleven warm leads show churn risk signals.', now() - interval '6 hours'
  )
ON CONFLICT (id) DO NOTHING;

-- Enrich existing recommendations table with hub seeds (do not recreate table)
INSERT INTO public.ai_recommendations (
  id, user_id, kind, title, body, status, metadata, confidence_pct, copilot_slug, target_module, code
)
SELECT
  v.id,
  (SELECT id FROM public.profiles ORDER BY created_at NULLS LAST LIMIT 1),
  v.kind, v.title, v.body, v.status, v.metadata::jsonb,
  v.confidence_pct, v.copilot_slug, v.target_module, v.code
FROM (VALUES
  (
    'f1700007-0000-4000-8000-000000000001'::uuid,
    'next_best_action',
    'Call top warm leads today',
    'Prioritize 8 warm leads with >70% conversion assist score.',
    'pending_review',
    '{"source":"eaih"}',
    86.0::numeric,
    'sales',
    'sales',
    'REC-SALES-01'
  ),
  (
    'f1700007-0000-4000-8000-000000000002'::uuid,
    'executive_brief',
    'Escalate construction watch to board pack',
    'Include Block C delay risk in weekly executive packet.',
    'pending_review',
    '{"source":"eaih"}',
    79.5::numeric,
    'executive',
    'construction',
    'REC-EXEC-01'
  ),
  (
    'f1700007-0000-4000-8000-000000000003'::uuid,
    'collections',
    'Collections follow-up batch',
    'Queue advisory collections drafts for 5 overdue invoices.',
    'pending_review',
    '{"source":"eaih"}',
    74.0::numeric,
    'finance',
    'finance',
    'REC-FIN-01'
  )
) AS v(id, kind, title, body, status, metadata, confidence_pct, copilot_slug, target_module, code)
WHERE EXISTS (SELECT 1 FROM public.profiles LIMIT 1)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_prompt_versions (
  id, copilot_id, code, version_label, body, status, requires_approval, summary
) VALUES
  (
    'f1700008-0000-4000-8000-000000000001',
    'f1700005-0000-4000-8000-000000000001',
    'PV-EXEC-BRIEF-01', '1.0',
    'Draft an editable executive briefing from KPI and risk signals. Label advisory.',
    'published', false, 'Executive briefing prompt version.'
  ),
  (
    'f1700008-0000-4000-8000-000000000002',
    'f1700005-0000-4000-8000-000000000002',
    'PV-SALES-FOLLOW-01', '1.1',
    'Draft CRM follow-up requiring human review before send.',
    'published', true, 'Sales follow-up with approval gate.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_embeddings (
  id, source_table, source_id, code, content_preview, embedding, embedding_dim, status
) VALUES
  (
    'f1700009-0000-4000-8000-000000000001',
    'ai_knowledge_sources', NULL,
    'EMB-BUY-01', 'Buying process at HD Homes — journey summary.',
    '[0.12,0.04,-0.08,0.33]'::jsonb, 4, 'ready'
  ),
  (
    'f1700009-0000-4000-8000-000000000002',
    'ai_knowledge_sources', NULL,
    'EMB-INV-01', 'Investment products overview — illustrative ROI.',
    '[0.05,-0.11,0.22,0.18]'::jsonb, 4, 'ready'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_vector_indexes (
  id, code, name, index_type, status, dimension, owner_label, summary
) VALUES
  (
    'f170000a-0000-4000-8000-000000000001',
    'VIX-JSONB-01', 'Phase 1 JSONB Embedding Index', 'jsonb_fallback', 'active',
    4, 'AI Platform', 'Fallback index until pgvector is available.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_search_queries (
  id, code, query_text, actor_label, query_mode, result_count, latency_ms, copilot_slug, queried_at
) VALUES
  (
    'f170000b-0000-4000-8000-000000000001',
    'QRY-DELAY-01', 'construction delay risk horizon gardens',
    'PMO', 'hybrid', 3, 95, 'construction', now() - interval '2 hours'
  ),
  (
    'f170000b-0000-4000-8000-000000000002',
    'QRY-CONV-01', 'sales conversion next best actions',
    'Sales Ops', 'rag', 4, 120, 'sales', now() - interval '5 hours'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_search_results (
  id, query_id, rank, title, snippet, score, source_label
) VALUES
  (
    'f170000c-0000-4000-8000-000000000001',
    'f170000b-0000-4000-8000-000000000001',
    1, 'Block C delay signal', 'Elevated weather and supply risk on HG Block C.',
    0.91, 'PRED-DELAY-HG'
  ),
  (
    'f170000c-0000-4000-8000-000000000002',
    'f170000b-0000-4000-8000-000000000002',
    1, 'Warm lead follow-up batch', 'Eight warm leads ranked for today outreach.',
    0.88, 'REC-SALES-01'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_knowledge_graph_nodes (
  id, code, label, node_type, status, summary
) VALUES
  (
    'f170000d-0000-4000-8000-000000000001',
    'KG-EST-HG', 'Horizon Gardens', 'property', 'active',
    'Flagship estate entity in knowledge graph.'
  ),
  (
    'f170000d-0000-4000-8000-000000000002',
    'KG-PROC-BUY', 'Buying Process', 'process', 'active',
    'Discover → enquire → inspect → KYC → offer.'
  ),
  (
    'f170000d-0000-4000-8000-000000000003',
    'KG-DOC-SOP', 'Sales Follow-up SOP', 'document', 'active',
    'Playbook requiring human review of AI drafts.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_knowledge_graph_edges (
  id, code, source_node_id, target_node_id, relation_type, weight, summary
) VALUES
  (
    'f170000e-0000-4000-8000-000000000001',
    'KGE-BUY-HG',
    'f170000d-0000-4000-8000-000000000002',
    'f170000d-0000-4000-8000-000000000001',
    'related', 1.0, 'Buying process applies to Horizon Gardens.'
  ),
  (
    'f170000e-0000-4000-8000-000000000002',
    'KGE-SOP-BUY',
    'f170000d-0000-4000-8000-000000000003',
    'f170000d-0000-4000-8000-000000000002',
    'depends', 0.9, 'SOP governs buying-process follow-ups.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_workflow_rules (
  id, code, name, trigger_event, status, action_label, requires_approval, owner_label, summary
) VALUES
  (
    'f170000f-0000-4000-8000-000000000001',
    'RULE-DELAY-ALERT', 'Construction delay alert',
    'prediction.delay_high', 'active', 'Notify PMO + create draft brief',
    true, 'PMO', 'When delay probability > 0.3, open advisory brief.'
  ),
  (
    'f170000f-0000-4000-8000-000000000002',
    'RULE-LEAD-BATCH', 'Warm lead batch draft',
    'recommendation.sales_batch', 'active', 'Draft CRM follow-ups',
    true, 'Sales Ops', 'Batch next-best-action drafts require approval.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_automation_jobs (
  id, rule_id, code, name, status, owner_label, summary, started_at, finished_at
) VALUES
  (
    'f1700010-0000-4000-8000-000000000001',
    'f170000f-0000-4000-8000-000000000001',
    'AUTO-DELAY-01', 'Delay alert — Horizon Gardens',
    'awaiting_approval', 'PMO',
    'Draft alert ready for human approval.',
    now() - interval '4 hours', NULL
  ),
  (
    'f1700010-0000-4000-8000-000000000002',
    'f170000f-0000-4000-8000-000000000002',
    'AUTO-LEAD-01', 'Warm lead draft batch',
    'success', 'Sales Ops',
    'Eight draft follow-ups staged for review.',
    now() - interval '1 day', now() - interval '1 day' + interval '12 minutes'
  ),
  (
    'f1700010-0000-4000-8000-000000000003',
    NULL,
    'AUTO-DRIFT-01', 'Drift scan — sales forecaster',
    'failed', 'ML Ops',
    'Monitoring job failed on missing feature snapshot.',
    now() - interval '3 days', now() - interval '3 days' + interval '2 minutes'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_model_monitoring (
  id, model_id, code, metric_name, metric_value, status, observed_at, summary
) VALUES
  (
    'f1700011-0000-4000-8000-000000000001',
    'f1700002-0000-4000-8000-000000000002',
    'MON-FC-ACC', 'accuracy_pct', 81.2, 'ok',
    now() - interval '6 hours', 'Sales forecaster accuracy within band.'
  ),
  (
    'f1700011-0000-4000-8000-000000000002',
    'f1700002-0000-4000-8000-000000000002',
    'MON-FC-LAT', 'p95_latency_ms', 240, 'watch',
    now() - interval '2 hours', 'Latency watch — above 200ms target.'
  ),
  (
    'f1700011-0000-4000-8000-000000000003',
    'f1700002-0000-4000-8000-000000000001',
    'MON-LLM-ERR', 'error_rate_pct', 2.4, 'ok',
    now() - interval '1 hour', 'Executive LLM error rate healthy.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_drift_reports (
  id, model_id, code, title, severity, status, drift_score, owner_label, summary, detected_at
) VALUES
  (
    'f1700012-0000-4000-8000-000000000001',
    'f1700002-0000-4000-8000-000000000002',
    'DRIFT-FC-01', 'Feature drift — booking_stage',
    'high', 'open', 0.42, 'ML Ops',
    'Stage distribution shifted after schema change; linked to BI ETL watch.',
    now() - interval '2 days'
  ),
  (
    'f1700012-0000-4000-8000-000000000002',
    'f1700002-0000-4000-8000-000000000004',
    'DRIFT-REC-01', 'Label drift — next-best-action',
    'medium', 'investigating', 0.28, 'CRM Lead',
    'Recommendation acceptance rate down week-over-week.',
    now() - interval '5 days'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_governance_policies (
  id, code, title, policy_area, status, owner_label, summary
) VALUES
  (
    'f1700013-0000-4000-8000-000000000001',
    'POL-RAI-01', 'Responsible AI labeling',
    'responsible_ai', 'active', 'AI Governance',
    'All AI outputs must carry editable / advisory disclaimer.'
  ),
  (
    'f1700013-0000-4000-8000-000000000002',
    'POL-APPR-01', 'Human-in-the-loop approvals',
    'approvals', 'active', 'AI Governance',
    'CRM, legal, and outbound automation require human approval.'
  ),
  (
    'f1700013-0000-4000-8000-000000000003',
    'POL-PRIV-01', 'PII minimization in prompts',
    'privacy', 'active', 'Legal Counsel',
    'Do not embed full client PII in prompt logs.'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_hub_insights (
  id, title, body, insight_type, confidence_pct, editable, disclaimer, status
) VALUES
  (
    'f1700014-0000-4000-8000-000000000001',
    'Executive decision packet focus',
    'Prioritize construction delay watch and conversion mart recovery in this week''s decision pack.',
    'decision', 84.0, true, 'AI-generated — editable / advisory', 'active'
  ),
  (
    'f1700014-0000-4000-8000-000000000002',
    'Automation awaiting approval',
    'AUTO-DELAY-01 holds on approval — PMO should clear or amend before notify blast.',
    'ops', 91.0, true, 'AI-generated — editable / advisory', 'active'
  ),
  (
    'f1700014-0000-4000-8000-000000000003',
    'Model drift linked to BI quality',
    'DRIFT-FC-01 correlates with analytics ETL schema drift — treat forecasts as advisory.',
    'risk', 88.5, true, 'AI-generated — editable / advisory', 'active'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_activity_logs (
  id, action, summary, actor_label, entity_type, entity_id, occurred_at
) VALUES
  (
    'f1700015-0000-4000-8000-000000000001',
    'prediction_created',
    'PRED-CONV-30 conversion outlook published',
    'Sales Ops', 'ai_predictions', 'f1700006-0000-4000-8000-000000000001',
    now() - interval '3 hours'
  ),
  (
    'f1700015-0000-4000-8000-000000000002',
    'automation_awaiting_approval',
    'AUTO-DELAY-01 awaiting PMO approval',
    'Automation', 'ai_automation_jobs', 'f1700010-0000-4000-8000-000000000001',
    now() - interval '4 hours'
  ),
  (
    'f1700015-0000-4000-8000-000000000003',
    'drift_opened',
    'DRIFT-FC-01 opened as high severity',
    'ML Ops', 'ai_drift_reports', 'f1700012-0000-4000-8000-000000000001',
    now() - interval '2 days'
  ),
  (
    'f1700015-0000-4000-8000-000000000004',
    'copilot_activated',
    'Executive Copilot marked active in AI Hub',
    'AI Platform', 'ai_copilots', 'f1700005-0000-4000-8000-000000000001',
    now() - interval '7 days'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ai_notifications (
  id, title, body, severity, status, link_path
) VALUES
  (
    'f1700016-0000-4000-8000-000000000001',
    'Automation awaiting approval',
    'AUTO-DELAY-01 needs PMO review.',
    'warning', 'unread', '/dashboard/ai'
  ),
  (
    'f1700016-0000-4000-8000-000000000002',
    'High drift on sales forecaster',
    'DRIFT-FC-01 opened — treat conversion predictions as advisory.',
    'critical', 'unread', '/dashboard/ai'
  )
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
