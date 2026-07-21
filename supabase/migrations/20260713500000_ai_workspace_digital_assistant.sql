-- Volume 3 Part 15 — AI Workspace & Digital Assistant Foundation
-- Status: APPLIED remotely as ai_workspace_digital_assistant + ai_workspace_digital_assistant_rls (approved 2026-07-13).
-- Provider-independent AI gateway tables; conversations, prompts, feedback, governance.

-- ---------------------------------------------------------------------------
-- Conversations + messages + sessions
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.ai_conversations (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL DEFAULT 'Conversation',
  assistant_kind TEXT NOT NULL DEFAULT 'general',
  message_count INT NOT NULL DEFAULT 0,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ai_conversations_user
  ON public.ai_conversations (user_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS public.ai_messages (
  id TEXT PRIMARY KEY,
  conversation_id TEXT NOT NULL REFERENCES public.ai_conversations(id) ON DELETE CASCADE,
  role TEXT NOT NULL,
  content TEXT NOT NULL,
  suggested_follow_ups TEXT[] NOT NULL DEFAULT '{}',
  linked_resources JSONB NOT NULL DEFAULT '[]'::jsonb,
  requires_approval BOOLEAN NOT NULL DEFAULT false,
  explanation TEXT,
  prompt_template_slug TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ai_messages_conversation
  ON public.ai_messages (conversation_id, created_at);

CREATE TABLE IF NOT EXISTS public.ai_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  conversation_id TEXT REFERENCES public.ai_conversations(id) ON DELETE SET NULL,
  provider TEXT NOT NULL DEFAULT 'localFoundation',
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at TIMESTAMPTZ,
  extras JSONB NOT NULL DEFAULT '{}'::jsonb
);

-- ---------------------------------------------------------------------------
-- Prompt library, knowledge, recommendations, feedback, usage
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.ai_prompt_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  body TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'general',
  version INT NOT NULL DEFAULT 1,
  requires_approval BOOLEAN NOT NULL DEFAULT false,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.ai_prompt_templates (slug, name, body, category, requires_approval) VALUES
  ('property_summary', 'Property Summary', 'Summarize property fit vs preferences.', 'property', false),
  ('investment_summary', 'Investment Summary', 'Explain ROI informationally with disclaimer.', 'investment', false),
  ('client_follow_up', 'Client Follow-up', 'Draft follow-up requiring human review.', 'crm', true),
  ('marketing_campaign', 'Marketing Campaign', 'Draft campaign copy for review.', 'content', true),
  ('sales_report', 'Sales Report', 'Summarize sales KPIs with report links.', 'report', false),
  ('support_response', 'Support Response', 'Draft support reply; no invented exceptions.', 'support', true),
  ('blog_generator', 'Blog Generator', 'Outline editable blog draft.', 'content', true),
  ('legal_disclaimer', 'Legal Disclaimer', 'Remind outputs are advisory.', 'legal', false)
ON CONFLICT (slug) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.ai_knowledge_sources (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  category TEXT NOT NULL,
  body TEXT NOT NULL,
  keywords TEXT[] NOT NULL DEFAULT '{}',
  permission_slug TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.ai_knowledge_sources (title, category, body, keywords, permission_slug)
SELECT * FROM (VALUES
  ('Buying process at HD Homes', 'sales',
   'Typical journey: discover → enquire → inspect → KYC → offer → payment plan → allocation.',
   ARRAY['buy','process','inspection'], NULL::TEXT),
  ('Investment products overview', 'investment',
   'Investment products include off-plan and completed assets. Projected ROI is illustrative.',
   ARRAY['roi','invest','yield'], NULL::TEXT),
  ('Sales follow-up SOP', 'playbook',
   'Follow up warm leads within 24 hours. Never send AI drafts without review.',
   ARRAY['follow up','lead','crm'], 'manage_crm')
) AS v(title, category, body, keywords, permission_slug)
WHERE NOT EXISTS (
  SELECT 1 FROM public.ai_knowledge_sources k WHERE k.title = v.title
);

CREATE TABLE IF NOT EXISTS public.ai_feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  conversation_id TEXT REFERENCES public.ai_conversations(id) ON DELETE CASCADE,
  message_id TEXT,
  vote TEXT NOT NULL,
  comment TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ai_usage_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  conversation_id TEXT,
  assistant_kind TEXT,
  provider TEXT,
  latency_ms INT,
  tokens_estimated INT,
  blocked BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ai_usage_logs_created
  ON public.ai_usage_logs (created_at DESC);

CREATE TABLE IF NOT EXISTS public.ai_recommendations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  kind TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending_review',
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ai_context_cache (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  cache_key TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  expires_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, cache_key)
);

CREATE TABLE IF NOT EXISTS public.ai_provider_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider TEXT NOT NULL UNIQUE,
  enabled BOOLEAN NOT NULL DEFAULT false,
  is_default BOOLEAN NOT NULL DEFAULT false,
  config JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.ai_provider_settings (provider, enabled, is_default, config) VALUES
  ('localFoundation', true, true, '{"mode":"deterministic"}'::jsonb),
  ('openAi', false, false, '{}'::jsonb),
  ('anthropic', false, false, '{}'::jsonb),
  ('gemini', false, false, '{}'::jsonb),
  ('azureOpenAi', false, false, '{}'::jsonb),
  ('selfHosted', false, false, '{}'::jsonb)
ON CONFLICT (provider) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.ai_rate_limits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  role_slug TEXT,
  assistant_kind TEXT,
  requests_per_hour INT NOT NULL DEFAULT 60,
  enabled BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS public.ai_audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID,
  action TEXT NOT NULL,
  details JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

ALTER TABLE public.ai_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_prompt_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_knowledge_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_usage_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_recommendations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_context_cache ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_provider_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_rate_limits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_audit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ai_conversations_own ON public.ai_conversations;
CREATE POLICY ai_conversations_own ON public.ai_conversations
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS ai_messages_own ON public.ai_messages;
CREATE POLICY ai_messages_own ON public.ai_messages
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.ai_conversations c
      WHERE c.id = conversation_id AND c.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.ai_conversations c
      WHERE c.id = conversation_id AND c.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS ai_sessions_own ON public.ai_sessions;
CREATE POLICY ai_sessions_own ON public.ai_sessions
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS ai_prompt_templates_read ON public.ai_prompt_templates;
CREATE POLICY ai_prompt_templates_read ON public.ai_prompt_templates
  FOR SELECT USING (is_active = true OR public.has_role('admin') OR public.has_role('super_admin'));

DROP POLICY IF EXISTS ai_prompt_templates_admin ON public.ai_prompt_templates;
CREATE POLICY ai_prompt_templates_admin ON public.ai_prompt_templates
  FOR ALL USING (public.has_role('admin') OR public.has_role('super_admin'))
  WITH CHECK (public.has_role('admin') OR public.has_role('super_admin'));

DROP POLICY IF EXISTS ai_knowledge_read ON public.ai_knowledge_sources;
CREATE POLICY ai_knowledge_read ON public.ai_knowledge_sources
  FOR SELECT USING (
    is_active = true AND (
      permission_slug IS NULL
      OR public.has_permission(permission_slug)
      OR public.has_role('admin')
      OR public.has_role('super_admin')
    )
  );

DROP POLICY IF EXISTS ai_knowledge_admin ON public.ai_knowledge_sources;
CREATE POLICY ai_knowledge_admin ON public.ai_knowledge_sources
  FOR ALL USING (public.has_role('admin') OR public.has_role('super_admin'))
  WITH CHECK (public.has_role('admin') OR public.has_role('super_admin'));

DROP POLICY IF EXISTS ai_feedback_own ON public.ai_feedback;
CREATE POLICY ai_feedback_own ON public.ai_feedback
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS ai_usage_own_insert ON public.ai_usage_logs;
CREATE POLICY ai_usage_own_insert ON public.ai_usage_logs
  FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS ai_usage_staff_read ON public.ai_usage_logs;
CREATE POLICY ai_usage_staff_read ON public.ai_usage_logs
  FOR SELECT USING (
    user_id = auth.uid()
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS ai_recommendations_own ON public.ai_recommendations;
CREATE POLICY ai_recommendations_own ON public.ai_recommendations
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS ai_context_cache_own ON public.ai_context_cache;
CREATE POLICY ai_context_cache_own ON public.ai_context_cache
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS ai_provider_settings_staff ON public.ai_provider_settings;
CREATE POLICY ai_provider_settings_staff ON public.ai_provider_settings
  FOR SELECT USING (true);

DROP POLICY IF EXISTS ai_provider_settings_admin ON public.ai_provider_settings;
CREATE POLICY ai_provider_settings_admin ON public.ai_provider_settings
  FOR ALL USING (public.has_role('admin') OR public.has_role('super_admin'))
  WITH CHECK (public.has_role('admin') OR public.has_role('super_admin'));

DROP POLICY IF EXISTS ai_rate_limits_read ON public.ai_rate_limits;
CREATE POLICY ai_rate_limits_read ON public.ai_rate_limits
  FOR SELECT USING (true);

DROP POLICY IF EXISTS ai_audit_staff ON public.ai_audit_logs;
CREATE POLICY ai_audit_staff ON public.ai_audit_logs
  FOR SELECT USING (public.has_role('admin') OR public.has_role('super_admin'));

GRANT SELECT, INSERT, UPDATE, DELETE ON public.ai_conversations TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.ai_messages TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.ai_sessions TO authenticated;
GRANT SELECT ON public.ai_prompt_templates TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.ai_prompt_templates TO authenticated;
GRANT SELECT ON public.ai_knowledge_sources TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.ai_knowledge_sources TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.ai_feedback TO authenticated;
GRANT SELECT, INSERT ON public.ai_usage_logs TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.ai_recommendations TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.ai_context_cache TO authenticated;
GRANT SELECT ON public.ai_provider_settings TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.ai_provider_settings TO authenticated;
GRANT SELECT ON public.ai_rate_limits TO authenticated;
GRANT SELECT ON public.ai_audit_logs TO authenticated;

-- Realtime for live chat sync
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.ai_conversations;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.ai_messages;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
