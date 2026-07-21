-- Volume 4 Part 11 — Customer Support, Help Desk & Omnichannel Communication Platform (CSHOP)
-- Status: APPLIED remotely 2026-07-15 (chunked customer_support_omnichannel_p1–p3).
--
-- Approach:
--   • NEVER recreate public.tickets or public.ticket_messages
--     (exist in 20260710110003_domain_operations.sql).
--   • ENRICH via ALTER TABLE … ADD COLUMN IF NOT EXISTS only.
--   • public.chat_messages (simple DM) stays — do NOT drop.
--     NEW live_chat_sessions + live_chat_messages for omnichannel live chat.
--   • EOC Part 10 knowledge_articles remains — CSHOP uses
--     support_knowledge_categories / support_knowledge_articles /
--     support_knowledge_versions only.
--   • Optional VIEW public.support_tickets → enriched public.tickets.
--   • Seed UUIDs hex-only (0-9a-f), prefixed f110….
--   • RLS: has_permission('slug', auth.uid()) — slug FIRST.
--   • Permissions: slug, name, description, module only (no action column).
--
-- Volume 4 continues Parts 12–25 after this part is approved.

BEGIN;

-- ---------------------------------------------------------------------------
-- Permissions
-- ---------------------------------------------------------------------------
INSERT INTO public.permissions (slug, name, description, module) VALUES
  ('support.read', 'View Support', 'View Customer Support Command Center', 'support'),
  ('support.write', 'Manage Support', 'Create and edit support records', 'support'),
  ('support.tickets', 'Support Tickets', 'Manage help-desk tickets and case details', 'support'),
  ('support.inbox', 'Support Inbox', 'Unified multi-channel conversation inbox', 'support'),
  ('support.chat', 'Live Chat', 'Manage omnichannel live chat sessions', 'support'),
  ('support.email', 'Support Email', 'Manage support email threads', 'support'),
  ('support.whatsapp', 'WhatsApp Support', 'Manage WhatsApp conversations', 'support'),
  ('support.knowledge', 'Support Knowledge', 'Manage CSHOP knowledge base articles', 'support'),
  ('support.sla', 'Support SLA', 'Manage SLAs and compliance', 'support'),
  ('support.escalations', 'Support Escalations', 'Manage escalations and routing', 'support'),
  ('support.analytics', 'Support Analytics', 'View support KPIs and analytics', 'support'),
  ('support.ai', 'Support AI', 'Use AI resolution intelligence tools', 'support'),
  ('support.reports', 'Support Reports', 'Generate and view support reports', 'support')
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  module = EXCLUDED.module,
  updated_at = now();

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE p.slug LIKE 'support.%'
  AND (
    r.slug IN ('super_admin', 'admin')
    OR (r.slug = 'sales_team' AND p.slug IN (
      'support.read', 'support.tickets', 'support.inbox', 'support.knowledge'
    ))
    OR (r.slug = 'finance' AND p.slug IN (
      'support.read', 'support.analytics', 'support.reports'
    ))
    OR (r.slug = 'construction_manager' AND p.slug IN (
      'support.read', 'support.tickets'
    ))
    OR (r.slug = 'marketing' AND p.slug IN (
      'support.read', 'support.analytics'
    ))
  )
ON CONFLICT DO NOTHING;

-- Keep legacy manage_tickets aligned for support-facing roles
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE p.slug = 'manage_tickets'
  AND r.slug IN ('super_admin', 'admin', 'sales_team')
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- ENRICH existing tickets (do NOT recreate)
-- ---------------------------------------------------------------------------
ALTER TABLE public.tickets
  ADD COLUMN IF NOT EXISTS ticket_number text,
  ADD COLUMN IF NOT EXISTS description text,
  ADD COLUMN IF NOT EXISTS category_id uuid,
  ADD COLUMN IF NOT EXISTS subcategory text,
  ADD COLUMN IF NOT EXISTS channel text DEFAULT 'portal',
  ADD COLUMN IF NOT EXISTS customer_id uuid,
  ADD COLUMN IF NOT EXISTS customer_name text,
  ADD COLUMN IF NOT EXISTS customer_email text,
  ADD COLUMN IF NOT EXISTS customer_phone text,
  ADD COLUMN IF NOT EXISTS property_id uuid,
  ADD COLUMN IF NOT EXISTS booking_id uuid,
  ADD COLUMN IF NOT EXISTS team_id uuid,
  ADD COLUMN IF NOT EXISTS queue_id uuid,
  ADD COLUMN IF NOT EXISTS sla_id uuid,
  ADD COLUMN IF NOT EXISTS priority_id uuid,
  ADD COLUMN IF NOT EXISTS status_id uuid,
  ADD COLUMN IF NOT EXISTS first_response_at timestamptz,
  ADD COLUMN IF NOT EXISTS resolved_at timestamptz,
  ADD COLUMN IF NOT EXISTS closed_at timestamptz,
  ADD COLUMN IF NOT EXISTS sla_due_at timestamptz,
  ADD COLUMN IF NOT EXISTS sla_breached boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS csat_score numeric,
  ADD COLUMN IF NOT EXISTS tags text[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}'::jsonb;

CREATE UNIQUE INDEX IF NOT EXISTS idx_tickets_ticket_number
  ON public.tickets (ticket_number) WHERE ticket_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_tickets_channel ON public.tickets (channel);
CREATE INDEX IF NOT EXISTS idx_tickets_status ON public.tickets (status);
CREATE INDEX IF NOT EXISTS idx_tickets_team ON public.tickets (team_id);

-- ---------------------------------------------------------------------------
-- ENRICH existing ticket_messages (do NOT recreate)
-- ---------------------------------------------------------------------------
ALTER TABLE public.ticket_messages
  ADD COLUMN IF NOT EXISTS channel text DEFAULT 'portal',
  ADD COLUMN IF NOT EXISTS message_type text DEFAULT 'reply',
  ADD COLUMN IF NOT EXISTS attachments jsonb DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS sender_type text DEFAULT 'customer',
  ADD COLUMN IF NOT EXISTS sender_name text,
  ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}'::jsonb;

-- ---------------------------------------------------------------------------
-- Lookup + org tables
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.support_teams (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  description text,
  org_department_slug text DEFAULT 'customer_support',
  is_active boolean NOT NULL DEFAULT true,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.support_agents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id uuid REFERENCES public.support_teams(id) ON DELETE SET NULL,
  profile_id uuid,
  display_name text NOT NULL,
  email text,
  role_title text DEFAULT 'Agent',
  status text NOT NULL DEFAULT 'available'
    CHECK (status IN ('available','busy','away','offline')),
  max_concurrent int NOT NULL DEFAULT 5,
  is_active boolean NOT NULL DEFAULT true,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.support_skills (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  description text,
  category text NOT NULL DEFAULT 'general',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.support_agent_skills (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id uuid NOT NULL REFERENCES public.support_agents(id) ON DELETE CASCADE,
  skill_id uuid NOT NULL REFERENCES public.support_skills(id) ON DELETE CASCADE,
  proficiency int NOT NULL DEFAULT 3 CHECK (proficiency BETWEEN 1 AND 5),
  UNIQUE (agent_id, skill_id)
);

CREATE TABLE IF NOT EXISTS public.support_queues (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id uuid REFERENCES public.support_teams(id) ON DELETE SET NULL,
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  channel text NOT NULL DEFAULT 'omni',
  priority_weight int NOT NULL DEFAULT 100,
  is_active boolean NOT NULL DEFAULT true,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.support_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  description text,
  parent_id uuid REFERENCES public.support_categories(id) ON DELETE SET NULL,
  sort_order int NOT NULL DEFAULT 100,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.support_priorities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  rank int NOT NULL DEFAULT 50,
  color text DEFAULT '#6B7280',
  response_mins int,
  resolve_mins int,
  is_active boolean NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS public.support_statuses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  category text NOT NULL DEFAULT 'open'
    CHECK (category IN ('open','pending','resolved','closed')),
  is_terminal boolean NOT NULL DEFAULT false,
  sort_order int NOT NULL DEFAULT 100,
  is_active boolean NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS public.support_slas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  channel text NOT NULL DEFAULT 'omni',
  priority_slug text,
  first_response_mins int NOT NULL DEFAULT 60,
  resolve_mins int NOT NULL DEFAULT 1440,
  business_hours_only boolean NOT NULL DEFAULT true,
  is_active boolean NOT NULL DEFAULT true,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.support_escalations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id uuid REFERENCES public.tickets(id) ON DELETE CASCADE,
  level int NOT NULL DEFAULT 1,
  reason text,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','acknowledged','resolved','cancelled')),
  escalated_to text,
  escalated_by text,
  due_at timestamptz,
  resolved_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.support_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id uuid NOT NULL REFERENCES public.tickets(id) ON DELETE CASCADE,
  agent_id uuid REFERENCES public.support_agents(id) ON DELETE SET NULL,
  team_id uuid REFERENCES public.support_teams(id) ON DELETE SET NULL,
  assigned_by text,
  reason text,
  is_active boolean NOT NULL DEFAULT true,
  assigned_at timestamptz NOT NULL DEFAULT now(),
  unassigned_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS public.support_ticket_attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id uuid NOT NULL REFERENCES public.tickets(id) ON DELETE CASCADE,
  message_id uuid REFERENCES public.ticket_messages(id) ON DELETE SET NULL,
  file_name text NOT NULL,
  file_url text,
  mime_type text,
  file_size int,
  uploaded_by text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.support_ticket_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id uuid NOT NULL REFERENCES public.tickets(id) ON DELETE CASCADE,
  author_label text,
  body text NOT NULL,
  is_internal boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Omnichannel live chat (separate from chat_messages DM)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.live_chat_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_code text NOT NULL UNIQUE,
  ticket_id uuid REFERENCES public.tickets(id) ON DELETE SET NULL,
  customer_name text,
  customer_email text,
  agent_id uuid REFERENCES public.support_agents(id) ON DELETE SET NULL,
  queue_id uuid REFERENCES public.support_queues(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'waiting'
    CHECK (status IN ('waiting','active','queued','ended','abandoned')),
  channel text NOT NULL DEFAULT 'web',
  started_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz,
  csat_score numeric,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS public.live_chat_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES public.live_chat_sessions(id) ON DELETE CASCADE,
  sender_type text NOT NULL DEFAULT 'customer'
    CHECK (sender_type IN ('customer','agent','system','bot')),
  sender_name text,
  body text NOT NULL,
  message_type text NOT NULL DEFAULT 'text',
  attachments jsonb NOT NULL DEFAULT '[]'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_live_chat_messages_session
  ON public.live_chat_messages (session_id, created_at);

-- ---------------------------------------------------------------------------
-- Email + WhatsApp
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.support_email_threads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id uuid REFERENCES public.tickets(id) ON DELETE SET NULL,
  subject text NOT NULL,
  counterpart_email text,
  status text NOT NULL DEFAULT 'open',
  last_message_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.support_email_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_id uuid NOT NULL REFERENCES public.support_email_threads(id) ON DELETE CASCADE,
  direction text NOT NULL DEFAULT 'inbound'
    CHECK (direction IN ('inbound','outbound')),
  from_address text,
  to_address text,
  body text NOT NULL,
  html_body text,
  message_id_header text,
  attachments jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.whatsapp_conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id uuid REFERENCES public.tickets(id) ON DELETE SET NULL,
  phone_e164 text NOT NULL,
  customer_name text,
  agent_id uuid REFERENCES public.support_agents(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','pending','closed')),
  last_message_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.whatsapp_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES public.whatsapp_conversations(id) ON DELETE CASCADE,
  direction text NOT NULL DEFAULT 'inbound'
    CHECK (direction IN ('inbound','outbound')),
  body text NOT NULL,
  message_type text NOT NULL DEFAULT 'text',
  media_url text,
  status text NOT NULL DEFAULT 'delivered',
  provider_message_id text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_whatsapp_messages_conv
  ON public.whatsapp_messages (conversation_id, created_at);

-- ---------------------------------------------------------------------------
-- CSHOP Knowledge Base (NOT EOC knowledge_articles)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.support_knowledge_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  description text,
  sort_order int NOT NULL DEFAULT 100,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.support_knowledge_articles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id uuid REFERENCES public.support_knowledge_categories(id) ON DELETE SET NULL,
  slug text NOT NULL UNIQUE,
  title text NOT NULL,
  summary text,
  body text NOT NULL,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','published','archived')),
  tags text[] NOT NULL DEFAULT '{}',
  view_count int NOT NULL DEFAULT 0,
  helpful_count int NOT NULL DEFAULT 0,
  authored_by text,
  published_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.support_knowledge_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  article_id uuid NOT NULL REFERENCES public.support_knowledge_articles(id) ON DELETE CASCADE,
  version_no int NOT NULL DEFAULT 1,
  title text NOT NULL,
  body text NOT NULL,
  change_summary text,
  edited_by text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (article_id, version_no)
);

-- ---------------------------------------------------------------------------
-- Feedback / CSAT / NPS
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.customer_feedback (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id uuid REFERENCES public.tickets(id) ON DELETE SET NULL,
  channel text NOT NULL DEFAULT 'portal',
  customer_name text,
  rating int CHECK (rating BETWEEN 1 AND 5),
  comment text,
  sentiment text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.csat_surveys (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id uuid REFERENCES public.tickets(id) ON DELETE SET NULL,
  score int NOT NULL CHECK (score BETWEEN 1 AND 5),
  comment text,
  channel text NOT NULL DEFAULT 'post_resolve',
  customer_name text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.nps_surveys (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  score int NOT NULL CHECK (score BETWEEN 0 AND 10),
  comment text,
  customer_name text,
  segment text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Reports, activity, notifications, call center stub
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.support_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  title text NOT NULL,
  report_type text NOT NULL DEFAULT 'ops',
  status text NOT NULL DEFAULT 'ready',
  generated_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS public.support_activity_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  action text NOT NULL,
  summary text NOT NULL,
  actor_label text,
  ticket_id uuid REFERENCES public.tickets(id) ON DELETE SET NULL,
  channel text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.support_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  body text,
  severity text NOT NULL DEFAULT 'info',
  audience text NOT NULL DEFAULT 'agents',
  is_read boolean NOT NULL DEFAULT false,
  ticket_id uuid REFERENCES public.tickets(id) ON DELETE SET NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.call_center_calls (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  call_sid text,
  ticket_id uuid REFERENCES public.tickets(id) ON DELETE SET NULL,
  direction text NOT NULL DEFAULT 'inbound',
  from_number text,
  to_number text,
  duration_secs int,
  status text NOT NULL DEFAULT 'completed',
  recording_url text,
  agent_id uuid REFERENCES public.support_agents(id) ON DELETE SET NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  started_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz
);

CREATE TABLE IF NOT EXISTS public.support_ai_insights (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  body text NOT NULL,
  category text NOT NULL DEFAULT 'ops',
  confidence_pct numeric,
  is_editable boolean NOT NULL DEFAULT true,
  disclaimer text NOT NULL DEFAULT
    'AI-generated — editable / advisory. Support AI outputs are drafts for human review.',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Optional API clarity view over enriched tickets
CREATE OR REPLACE VIEW public.support_tickets AS
  SELECT * FROM public.tickets WHERE COALESCE(is_deleted, false) = false;

-- FK links from tickets to new lookup tables (safe if already present)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'tickets_category_id_fkey'
  ) THEN
    ALTER TABLE public.tickets
      ADD CONSTRAINT tickets_category_id_fkey
      FOREIGN KEY (category_id) REFERENCES public.support_categories(id) ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'tickets_team_id_fkey'
  ) THEN
    ALTER TABLE public.tickets
      ADD CONSTRAINT tickets_team_id_fkey
      FOREIGN KEY (team_id) REFERENCES public.support_teams(id) ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'tickets_queue_id_fkey'
  ) THEN
    ALTER TABLE public.tickets
      ADD CONSTRAINT tickets_queue_id_fkey
      FOREIGN KEY (queue_id) REFERENCES public.support_queues(id) ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'tickets_sla_id_fkey'
  ) THEN
    ALTER TABLE public.tickets
      ADD CONSTRAINT tickets_sla_id_fkey
      FOREIGN KEY (sla_id) REFERENCES public.support_slas(id) ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'tickets_priority_id_fkey'
  ) THEN
    ALTER TABLE public.tickets
      ADD CONSTRAINT tickets_priority_id_fkey
      FOREIGN KEY (priority_id) REFERENCES public.support_priorities(id) ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'tickets_status_id_fkey'
  ) THEN
    ALTER TABLE public.tickets
      ADD CONSTRAINT tickets_status_id_fkey
      FOREIGN KEY (status_id) REFERENCES public.support_statuses(id) ON DELETE SET NULL;
  END IF;
EXCEPTION WHEN others THEN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- Seeds (f110… hex-only)
-- ---------------------------------------------------------------------------
INSERT INTO public.support_teams (id, name, slug, description, org_department_slug) VALUES
  ('f1100001-0000-4000-8000-000000000001', 'Customer Support', 'customer_support',
   'Primary client care / service recovery — maps org department customer_support', 'customer_support'),
  ('f1100001-0000-4000-8000-000000000002', 'Sales Care Desk', 'sales_care',
   'Pre-sale and reservation follow-ups', 'customer_support'),
  ('f1100001-0000-4000-8000-000000000003', 'Technical Ops Desk', 'tech_ops',
   'Portal, payment, and document issues', 'customer_support')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.support_queues (id, team_id, name, slug, channel, priority_weight) VALUES
  ('f1100002-0000-4000-8000-000000000001', 'f1100001-0000-4000-8000-000000000001',
   'General Inbox', 'general-inbox', 'omni', 100),
  ('f1100002-0000-4000-8000-000000000002', 'f1100001-0000-4000-8000-000000000001',
   'Live Chat Queue', 'live-chat', 'chat', 80),
  ('f1100002-0000-4000-8000-000000000003', 'f1100001-0000-4000-8000-000000000001',
   'WhatsApp Priority', 'whatsapp-priority', 'whatsapp', 60),
  ('f1100002-0000-4000-8000-000000000004', 'f1100001-0000-4000-8000-000000000003',
   'Email Billing', 'email-billing', 'email', 70)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.support_categories (id, slug, name, description, sort_order) VALUES
  ('f1100003-0000-4000-8000-000000000001', 'billing', 'Billing & Payments', 'Invoices, receipts, installments', 10),
  ('f1100003-0000-4000-8000-000000000002', 'booking', 'Bookings & Reservations', 'Holds, inspections, allocation', 20),
  ('f1100003-0000-4000-8000-000000000003', 'documents', 'Documents & Title', 'Agreements, C of O, KYC docs', 30),
  ('f1100003-0000-4000-8000-000000000004', 'construction', 'Construction Updates', 'Site progress and snags', 40),
  ('f1100003-0000-4000-8000-000000000005', 'portal', 'Portal / Technical', 'Login, MFA, app issues', 50),
  ('f1100003-0000-4000-8000-000000000006', 'general', 'General Inquiry', 'Other customer questions', 60)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.support_priorities (id, slug, name, rank, color, response_mins, resolve_mins) VALUES
  ('f1100004-0000-4000-8000-000000000001', 'low', 'Low', 10, '#9CA3AF', 480, 4320),
  ('f1100004-0000-4000-8000-000000000002', 'normal', 'Normal', 30, '#3B82F6', 120, 1440),
  ('f1100004-0000-4000-8000-000000000003', 'high', 'High', 60, '#F59E0B', 30, 480),
  ('f1100004-0000-4000-8000-000000000004', 'urgent', 'Urgent', 90, '#EF4444', 15, 120)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.support_statuses (id, slug, name, category, is_terminal, sort_order) VALUES
  ('f1100005-0000-4000-8000-000000000001', 'open', 'Open', 'open', false, 10),
  ('f1100005-0000-4000-8000-000000000002', 'in_progress', 'In Progress', 'open', false, 20),
  ('f1100005-0000-4000-8000-000000000003', 'pending_customer', 'Pending Customer', 'pending', false, 30),
  ('f1100005-0000-4000-8000-000000000004', 'escalated', 'Escalated', 'open', false, 40),
  ('f1100005-0000-4000-8000-000000000005', 'resolved', 'Resolved', 'resolved', true, 50),
  ('f1100005-0000-4000-8000-000000000006', 'closed', 'Closed', 'closed', true, 60)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.support_slas (id, code, name, channel, priority_slug, first_response_mins, resolve_mins) VALUES
  ('f1100006-0000-4000-8000-000000000001', 'SLA-OMNI-NORMAL', 'Omni Normal', 'omni', 'normal', 120, 1440),
  ('f1100006-0000-4000-8000-000000000002', 'SLA-CHAT-HIGH', 'Live Chat High', 'chat', 'high', 5, 240),
  ('f1100006-0000-4000-8000-000000000003', 'SLA-WA-URGENT', 'WhatsApp Urgent', 'whatsapp', 'urgent', 15, 120),
  ('f1100006-0000-4000-8000-000000000004', 'SLA-EMAIL-BILLING', 'Email Billing', 'email', 'high', 60, 480)
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.support_skills (id, slug, name, description, category) VALUES
  ('f1100007-0000-4000-8000-000000000001', 'billing', 'Billing', 'Payment and invoice fluency', 'finance'),
  ('f1100007-0000-4000-8000-000000000002', 'sales', 'Sales Care', 'Reservations and offer follow-up', 'sales'),
  ('f1100007-0000-4000-8000-000000000003', 'documents', 'Document Ops', 'Title and agreement handling', 'legal'),
  ('f1100007-0000-4000-8000-000000000004', 'multilingual', 'Multilingual EN/YO', 'English + Yoruba customer care', 'language'),
  ('f1100007-0000-4000-8000-000000000005', 'live_chat', 'Live Chat', 'Real-time web chat', 'channel')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.support_agents (id, team_id, display_name, email, role_title, status, max_concurrent) VALUES
  ('f1100008-0000-4000-8000-000000000001', 'f1100001-0000-4000-8000-000000000001',
   'Adaeze Okonkwo', 'adaeze.support@hdhomes.demo', 'Senior Agent', 'available', 6),
  ('f1100008-0000-4000-8000-000000000002', 'f1100001-0000-4000-8000-000000000001',
   'Chinedu Bello', 'chinedu.support@hdhomes.demo', 'Agent', 'busy', 5),
  ('f1100008-0000-4000-8000-000000000003', 'f1100001-0000-4000-8000-000000000002',
   'Fatima Yusuf', 'fatima.salescare@hdhomes.demo', 'Sales Care Lead', 'available', 8),
  ('f1100008-0000-4000-8000-000000000004', 'f1100001-0000-4000-8000-000000000003',
   'Ibrahim Ade', 'ibrahim.tech@hdhomes.demo', 'Tech Desk', 'away', 4)
ON CONFLICT DO NOTHING;

INSERT INTO public.support_agent_skills (id, agent_id, skill_id, proficiency) VALUES
  ('f1100009-0000-4000-8000-000000000001', 'f1100008-0000-4000-8000-000000000001',
   'f1100007-0000-4000-8000-000000000001', 5),
  ('f1100009-0000-4000-8000-000000000002', 'f1100008-0000-4000-8000-000000000001',
   'f1100007-0000-4000-8000-000000000005', 4),
  ('f1100009-0000-4000-8000-000000000003', 'f1100008-0000-4000-8000-000000000002',
   'f1100007-0000-4000-8000-000000000003', 4),
  ('f1100009-0000-4000-8000-000000000004', 'f1100008-0000-4000-8000-000000000003',
   'f1100007-0000-4000-8000-000000000002', 5),
  ('f1100009-0000-4000-8000-000000000005', 'f1100008-0000-4000-8000-000000000004',
   'f1100007-0000-4000-8000-000000000005', 5)
ON CONFLICT DO NOTHING;

-- Demo tickets across channels (enrich INSERT into existing tickets)
INSERT INTO public.tickets (
  id, subject, description, ticket_number, priority, status, channel,
  category_id, subcategory, customer_name, customer_email, customer_phone,
  team_id, queue_id, sla_id, priority_id, status_id,
  assigned_to, first_response_at, sla_due_at, sla_breached, csat_score, tags, metadata
) VALUES
  ('f110000a-0000-4000-8000-000000000001',
   'Installment receipt not reflecting',
   'Client paid June installment via Paystack; receipt missing in portal.',
   'HD-T-2026-1101', 'high', 'in_progress', 'email',
   'f1100003-0000-4000-8000-000000000001', 'receipts',
   'Ngozi Adeyemi', 'ngozi.adeyemi@example.com', '+2348011001101',
   'f1100001-0000-4000-8000-000000000001', 'f1100002-0000-4000-8000-000000000004',
   'f1100006-0000-4000-8000-000000000004', 'f1100004-0000-4000-8000-000000000003',
   'f1100005-0000-4000-8000-000000000002',
   NULL, now() - interval '40 minutes', now() + interval '7 hours', false, NULL,
   ARRAY['billing','paystack'], '{"demo":true}'::jsonb),
  ('f110000a-0000-4000-8000-000000000002',
   'WhatsApp: Plot allocation clarification',
   'Customer requesting Block B plot map and allocation letter timeline.',
   'HD-T-2026-1102', 'urgent', 'escalated', 'whatsapp',
   'f1100003-0000-4000-8000-000000000002', 'allocation',
   'Tunde Bakare', 'tunde.bakare@example.com', '+2348022002202',
   'f1100001-0000-4000-8000-000000000001', 'f1100002-0000-4000-8000-000000000003',
   'f1100006-0000-4000-8000-000000000003', 'f1100004-0000-4000-8000-000000000004',
   'f1100005-0000-4000-8000-000000000004',
   NULL, now() - interval '2 hours', now() - interval '30 minutes', true, NULL,
   ARRAY['whatsapp','allocation','sla_breach'], '{"demo":true,"breach":true}'::jsonb),
  ('f110000a-0000-4000-8000-000000000003',
   'Live chat: Cannot upload KYC PDF',
   'Portal rejects PDF larger than expected; client stuck at verification.',
   'HD-T-2026-1103', 'high', 'open', 'chat',
   'f1100003-0000-4000-8000-000000000005', 'kyc_upload',
   'Amaka Obi', 'amaka.obi@example.com', '+2348033003303',
   'f1100001-0000-4000-8000-000000000003', 'f1100002-0000-4000-8000-000000000002',
   'f1100006-0000-4000-8000-000000000002', 'f1100004-0000-4000-8000-000000000003',
   'f1100005-0000-4000-8000-000000000001',
   NULL, NULL, now() + interval '3 hours', false, NULL,
   ARRAY['chat','kyc','portal'], '{"demo":true}'::jsonb),
  ('f110000a-0000-4000-8000-000000000004',
   'Construction snag — bathroom tiling',
   'Client reported uneven tiling in Unit C-12 Lekki Phase 2.',
   'HD-T-2026-1104', 'normal', 'pending_customer', 'portal',
   'f1100003-0000-4000-8000-000000000004', 'snags',
   'Emeka Nwosu', 'emeka.nwosu@example.com', '+2348044004404',
   'f1100001-0000-4000-8000-000000000001', 'f1100002-0000-4000-8000-000000000001',
   'f1100006-0000-4000-8000-000000000001', 'f1100004-0000-4000-8000-000000000002',
   'f1100005-0000-4000-8000-000000000003',
   NULL, now() - interval '1 day', now() + interval '12 hours', false, NULL,
   ARRAY['construction','snag'], '{"demo":true}'::jsonb),
  ('f110000a-0000-4000-8000-000000000005',
   'Title deed soft copy request',
   'Investor asked for soft-copy offer letter and payment schedule PDF.',
   'HD-T-2026-1105', 'normal', 'resolved', 'email',
   'f1100003-0000-4000-8000-000000000003', 'title',
   'Hadiza Danladi', 'hadiza.danladi@example.com', '+2348055005505',
   'f1100001-0000-4000-8000-000000000001', 'f1100002-0000-4000-8000-000000000004',
   'f1100006-0000-4000-8000-000000000001', 'f1100004-0000-4000-8000-000000000002',
   'f1100005-0000-4000-8000-000000000005',
   NULL, now() - interval '2 days', now() - interval '1 day', false, 5,
   ARRAY['documents','resolved'], '{"demo":true}'::jsonb)
ON CONFLICT (id) DO NOTHING;

UPDATE public.tickets SET resolved_at = now() - interval '18 hours'
WHERE id = 'f110000a-0000-4000-8000-000000000005' AND resolved_at IS NULL;

INSERT INTO public.ticket_messages (
  id, ticket_id, message, is_internal, channel, message_type, sender_type, sender_name
) VALUES
  ('f110000b-0000-4000-8000-000000000001', 'f110000a-0000-4000-8000-000000000001',
   'Payment reference PAY-88211 should appear under My Payments.', false,
   'email', 'reply', 'customer', 'Ngozi Adeyemi'),
  ('f110000b-0000-4000-8000-000000000002', 'f110000a-0000-4000-8000-000000000001',
   'Checking Paystack webhook lag; will re-sync receipt within the hour.', false,
   'email', 'reply', 'agent', 'Adaeze Okonkwo'),
  ('f110000b-0000-4000-8000-000000000003', 'f110000a-0000-4000-8000-000000000002',
   'Escalating to Sales Care for allocation SLA breach.', true,
   'whatsapp', 'note', 'system', 'Routing Engine'),
  ('f110000b-0000-4000-8000-000000000004', 'f110000a-0000-4000-8000-000000000003',
   'Hi — uploads fail at ~8MB. Can you accept compressed PDF?', false,
   'chat', 'reply', 'customer', 'Amaka Obi')
ON CONFLICT DO NOTHING;

INSERT INTO public.support_escalations (
  id, ticket_id, level, reason, status, escalated_to, escalated_by, due_at
) VALUES
  ('f110000c-0000-4000-8000-000000000001', 'f110000a-0000-4000-8000-000000000002',
   2, 'SLA first-response breach on WhatsApp urgent allocation case',
   'open', 'Sales Care Lead', 'Routing Engine', now() + interval '1 hour'),
  ('f110000c-0000-4000-8000-000000000002', 'f110000a-0000-4000-8000-000000000001',
   1, 'Billing sync delay beyond email billing resolve window risk',
   'acknowledged', 'Tech Ops Desk', 'Adaeze Okonkwo', now() + interval '3 hours')
ON CONFLICT DO NOTHING;

INSERT INTO public.support_assignments (
  id, ticket_id, agent_id, team_id, assigned_by, reason
) VALUES
  ('f110000d-0000-4000-8000-000000000001', 'f110000a-0000-4000-8000-000000000001',
   'f1100008-0000-4000-8000-000000000001', 'f1100001-0000-4000-8000-000000000001',
   'Intelligent Case Routing™', 'Billing skill match'),
  ('f110000d-0000-4000-8000-000000000002', 'f110000a-0000-4000-8000-000000000002',
   'f1100008-0000-4000-8000-000000000003', 'f1100001-0000-4000-8000-000000000002',
   'Intelligent Case Routing™', 'Sales care + SLA breach'),
  ('f110000d-0000-4000-8000-000000000003', 'f110000a-0000-4000-8000-000000000003',
   'f1100008-0000-4000-8000-000000000004', 'f1100001-0000-4000-8000-000000000003',
   'Intelligent Case Routing™', 'Portal / KYC skill')
ON CONFLICT DO NOTHING;

INSERT INTO public.support_ticket_notes (id, ticket_id, author_label, body, is_internal) VALUES
  ('f110000e-0000-4000-8000-000000000001', 'f110000a-0000-4000-8000-000000000002',
   'Fatima Yusuf', 'Customer expects plot map PDF today; looping construction CAD.', true),
  ('f110000e-0000-4000-8000-000000000002', 'f110000a-0000-4000-8000-000000000004',
   'Chinedu Bello', 'Awaiting site photo confirmation from client.', true)
ON CONFLICT DO NOTHING;

INSERT INTO public.live_chat_sessions (
  id, session_code, ticket_id, customer_name, customer_email, agent_id, queue_id, status, channel, started_at
) VALUES
  ('f110000f-0000-4000-8000-000000000001', 'LC-2026-441',
   'f110000a-0000-4000-8000-000000000003', 'Amaka Obi', 'amaka.obi@example.com',
   'f1100008-0000-4000-8000-000000000004', 'f1100002-0000-4000-8000-000000000002',
   'active', 'web', now() - interval '12 minutes'),
  ('f110000f-0000-4000-8000-000000000002', 'LC-2026-442',
   NULL, 'Visitor — Lekki brochure', NULL,
   NULL, 'f1100002-0000-4000-8000-000000000002',
   'waiting', 'web', now() - interval '2 minutes')
ON CONFLICT (session_code) DO NOTHING;

INSERT INTO public.live_chat_messages (id, session_id, sender_type, sender_name, body) VALUES
  ('f1100010-0000-4000-8000-000000000001', 'f110000f-0000-4000-8000-000000000001',
   'customer', 'Amaka Obi', 'Hi — KYC upload keeps failing at 8MB.'),
  ('f1100010-0000-4000-8000-000000000002', 'f110000f-0000-4000-8000-000000000001',
   'agent', 'Ibrahim Ade', 'Sorry about that. Try compressing under 5MB or email docs@hdhomes.demo.'),
  ('f1100010-0000-4000-8000-000000000003', 'f110000f-0000-4000-8000-000000000001',
   'bot', 'HD Assist', 'Suggested article: How to upload KYC documents.'),
  ('f1100010-0000-4000-8000-000000000004', 'f110000f-0000-4000-8000-000000000002',
   'system', 'Queue', 'Waiting for next available agent…')
ON CONFLICT DO NOTHING;

INSERT INTO public.support_email_threads (
  id, ticket_id, subject, counterpart_email, status, last_message_at
) VALUES
  ('f1100011-0000-4000-8000-000000000001', 'f110000a-0000-4000-8000-000000000001',
   'Installment receipt not reflecting', 'ngozi.adeyemi@example.com', 'open', now() - interval '35 minutes'),
  ('f1100011-0000-4000-8000-000000000002', 'f110000a-0000-4000-8000-000000000005',
   'Title deed soft copy request', 'hadiza.danladi@example.com', 'closed', now() - interval '18 hours')
ON CONFLICT DO NOTHING;

INSERT INTO public.support_email_messages (id, thread_id, direction, from_address, to_address, body) VALUES
  ('f1100012-0000-4000-8000-000000000001', 'f1100011-0000-4000-8000-000000000001',
   'inbound', 'ngozi.adeyemi@example.com', 'support@hdhomes.demo',
   'Payment reference PAY-88211 should appear under My Payments.'),
  ('f1100012-0000-4000-8000-000000000002', 'f1100011-0000-4000-8000-000000000001',
   'outbound', 'support@hdhomes.demo', 'ngozi.adeyemi@example.com',
   'We are re-syncing your Paystack receipt — ETA under 60 minutes.')
ON CONFLICT DO NOTHING;

INSERT INTO public.whatsapp_conversations (
  id, ticket_id, phone_e164, customer_name, agent_id, status, last_message_at
) VALUES
  ('f1100013-0000-4000-8000-000000000001', 'f110000a-0000-4000-8000-000000000002',
   '+2348022002202', 'Tunde Bakare', 'f1100008-0000-4000-8000-000000000003',
   'open', now() - interval '20 minutes')
ON CONFLICT DO NOTHING;

INSERT INTO public.whatsapp_messages (id, conversation_id, direction, body, status) VALUES
  ('f1100014-0000-4000-8000-000000000001', 'f1100013-0000-4000-8000-000000000001',
   'inbound', 'Please send Block B plot map today. Allocation letter overdue.', 'delivered'),
  ('f1100014-0000-4000-8000-000000000002', 'f1100013-0000-4000-8000-000000000001',
   'outbound', 'Acknowledged — escalated to Sales Care. Sharing map PDF shortly.', 'delivered')
ON CONFLICT DO NOTHING;

INSERT INTO public.support_knowledge_categories (id, slug, name, description, sort_order) VALUES
  ('f1100015-0000-4000-8000-000000000001', 'getting-started', 'Getting Started', 'Portal and onboarding', 10),
  ('f1100015-0000-4000-8000-000000000002', 'payments', 'Payments', 'Receipts and installments', 20),
  ('f1100015-0000-4000-8000-000000000003', 'documents', 'Documents', 'KYC and title FAQs', 30),
  ('f1100015-0000-4000-8000-000000000004', 'agents', 'Agent Playbooks', 'Internal macros and SLAs', 40)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.support_knowledge_articles (
  id, category_id, slug, title, summary, body, status, tags, view_count, helpful_count, authored_by, published_at
) VALUES
  ('f1100016-0000-4000-8000-000000000001', 'f1100015-0000-4000-8000-000000000002',
   'paystack-receipt-sync', 'Paystack receipt sync delays',
   'When payments succeed but portal receipts lag.',
   'Paystack webhooks may lag up to 30 minutes. Agents should check Finance reconciliation then force re-sync from FAPMS.',
   'published', ARRAY['billing','paystack'], 42, 11, 'Adaeze Okonkwo', now() - interval '10 days'),
  ('f1100016-0000-4000-8000-000000000002', 'f1100015-0000-4000-8000-000000000003',
   'kyc-upload-limits', 'How to upload KYC documents',
   'File size and format guidance for clients.',
   'Accepted formats: PDF/JPG/PNG under 5MB. Compress large scans or email docs@hdhomes.demo for assisted upload.',
   'published', ARRAY['kyc','portal'], 88, 27, 'Ibrahim Ade', now() - interval '5 days'),
  ('f1100016-0000-4000-8000-000000000003', 'f1100015-0000-4000-8000-000000000004',
   'whatsapp-sla-playbook', 'WhatsApp urgent SLA playbook',
   'Internal first-response and escalation guide.',
   'Urgent WhatsApp: first response 15m; resolve 2h. Breach → auto-escalate to Sales Care Lead.',
   'published', ARRAY['sla','whatsapp','agents'], 31, 9, 'Fatima Yusuf', now() - interval '3 days')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.support_knowledge_versions (id, article_id, version_no, title, body, change_summary, edited_by) VALUES
  ('f1100017-0000-4000-8000-000000000001', 'f1100016-0000-4000-8000-000000000002',
   1, 'How to upload KYC documents',
   'Accepted formats: PDF/JPG/PNG under 5MB.', 'Initial publish', 'Ibrahim Ade'),
  ('f1100017-0000-4000-8000-000000000002', 'f1100016-0000-4000-8000-000000000002',
   2, 'How to upload KYC documents',
   'Accepted formats: PDF/JPG/PNG under 5MB. Compress large scans or email docs@hdhomes.demo for assisted upload.',
   'Added assisted email path', 'Ibrahim Ade')
ON CONFLICT DO NOTHING;

INSERT INTO public.customer_feedback (id, ticket_id, channel, customer_name, rating, comment, sentiment) VALUES
  ('f1100018-0000-4000-8000-000000000001', 'f110000a-0000-4000-8000-000000000005',
   'email', 'Hadiza Danladi', 5, 'Documents arrived same day — excellent.', 'positive'),
  ('f1100018-0000-4000-8000-000000000002', 'f110000a-0000-4000-8000-000000000004',
   'portal', 'Emeka Nwosu', 3, 'Still waiting on tiling fix photos.', 'neutral')
ON CONFLICT DO NOTHING;

INSERT INTO public.csat_surveys (id, ticket_id, score, comment, channel, customer_name) VALUES
  ('f1100019-0000-4000-8000-000000000001', 'f110000a-0000-4000-8000-000000000005',
   5, 'Fast and clear', 'post_resolve', 'Hadiza Danladi'),
  ('f1100019-0000-4000-8000-000000000002', 'f110000a-0000-4000-8000-000000000001',
   4, 'Waiting on sync but agent was helpful', 'email', 'Ngozi Adeyemi')
ON CONFLICT DO NOTHING;

INSERT INTO public.nps_surveys (id, score, comment, customer_name, segment) VALUES
  ('f110001a-0000-4000-8000-000000000001', 9, 'Would recommend HD Homes after-sales care', 'Hadiza Danladi', 'investor'),
  ('f110001a-0000-4000-8000-000000000002', 7, 'Good overall; allocation delays hurt', 'Tunde Bakare', 'client'),
  ('f110001a-0000-4000-8000-000000000003', 4, 'Portal upload friction is frustrating', 'Amaka Obi', 'client')
ON CONFLICT DO NOTHING;

INSERT INTO public.support_reports (id, code, title, report_type, status) VALUES
  ('f110001b-0000-4000-8000-000000000001', 'RPT-SUP-DAILY', 'Support Daily Ops Pack', 'ops', 'ready'),
  ('f110001b-0000-4000-8000-000000000002', 'RPT-SUP-CSAT', 'CSAT / NPS Weekly', 'cx', 'ready')
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.support_activity_logs (id, action, summary, actor_label, ticket_id, channel) VALUES
  ('f110001c-0000-4000-8000-000000000001', 'ticket.opened', 'Ticket HD-T-2026-1103 opened via live chat',
   'System', 'f110000a-0000-4000-8000-000000000003', 'chat'),
  ('f110001c-0000-4000-8000-000000000002', 'sla.breached', 'WhatsApp urgent SLA breached on HD-T-2026-1102',
   'SLA Engine', 'f110000a-0000-4000-8000-000000000002', 'whatsapp'),
  ('f110001c-0000-4000-8000-000000000003', 'escalation.opened', 'Level-2 escalation to Sales Care Lead',
   'Routing Engine', 'f110000a-0000-4000-8000-000000000002', 'whatsapp'),
  ('f110001c-0000-4000-8000-000000000004', 'chat.assigned', 'Live chat LC-2026-441 assigned to Ibrahim Ade',
   'Queue', 'f110000a-0000-4000-8000-000000000003', 'chat')
ON CONFLICT DO NOTHING;

INSERT INTO public.support_notifications (id, title, body, severity, audience, ticket_id) VALUES
  ('f110001d-0000-4000-8000-000000000001', 'SLA breach — WhatsApp urgent',
   'HD-T-2026-1102 first response overdue', 'critical', 'agents',
   'f110000a-0000-4000-8000-000000000002'),
  ('f110001d-0000-4000-8000-000000000002', 'New live chat waiting',
   'LC-2026-442 waiting in Live Chat Queue', 'warning', 'agents', NULL)
ON CONFLICT DO NOTHING;

INSERT INTO public.call_center_calls (
  id, call_sid, ticket_id, direction, from_number, to_number, duration_secs, status, agent_id, started_at, ended_at
) VALUES
  ('f110001e-0000-4000-8000-000000000001', 'CA-DEMO-1101',
   'f110000a-0000-4000-8000-000000000004', 'inbound', '+2348044004404', '+234700HDHOMES',
   312, 'completed', 'f1100008-0000-4000-8000-000000000002',
   now() - interval '6 hours', now() - interval '6 hours' + interval '312 seconds')
ON CONFLICT DO NOTHING;

INSERT INTO public.support_ai_insights (id, title, body, category, confidence_pct) VALUES
  ('f110001f-0000-4000-8000-000000000001',
   'Allocation SLA pattern',
   'WhatsApp allocation tickets are driving the majority of urgent breaches this week. Suggest pre-emptive plot-map macros for Sales Care.',
   'sla', 78),
  ('f110001f-0000-4000-8000-000000000002',
   'KYC upload friction',
   'Live chat + portal tickets cluster on PDF size limits. Publish clearer client guidance and raise soft limit to 8MB (advisory).',
   'portal', 71),
  ('f110001f-0000-4000-8000-000000000003',
   'CSAT uplift opportunity',
   'Resolved document cases score highest CSAT — reuse same-day email macros for billing receipt sync closures.',
   'cx', 66)
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.support_teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_agents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_skills ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_agent_skills ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_queues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_priorities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_statuses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_slas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_escalations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_ticket_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_ticket_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_chat_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_email_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_email_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whatsapp_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whatsapp_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_knowledge_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_knowledge_articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_knowledge_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.csat_surveys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nps_surveys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.call_center_calls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_ai_insights ENABLE ROW LEVEL SECURITY;

-- Staff policies on enriched tickets (additive)
DROP POLICY IF EXISTS tickets_support_select ON public.tickets;
DROP POLICY IF EXISTS tickets_support_write ON public.tickets;
CREATE POLICY tickets_support_select ON public.tickets FOR SELECT
  USING (
    public.has_permission('support.read', auth.uid())
    OR public.has_permission('support.tickets', auth.uid())
    OR public.has_permission('manage_tickets', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR user_id = auth.uid()
    OR public.is_staff()
  );
CREATE POLICY tickets_support_write ON public.tickets FOR ALL
  USING (
    public.has_permission('support.tickets', auth.uid())
    OR public.has_permission('support.write', auth.uid())
    OR public.has_permission('manage_tickets', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR public.is_staff()
  )
  WITH CHECK (
    public.has_permission('support.tickets', auth.uid())
    OR public.has_permission('support.write', auth.uid())
    OR public.has_permission('manage_tickets', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR public.is_staff()
  );

DROP POLICY IF EXISTS ticket_messages_support_select ON public.ticket_messages;
DROP POLICY IF EXISTS ticket_messages_support_write ON public.ticket_messages;
CREATE POLICY ticket_messages_support_select ON public.ticket_messages FOR SELECT
  USING (
    public.has_permission('support.read', auth.uid())
    OR public.has_permission('support.tickets', auth.uid())
    OR public.has_permission('manage_tickets', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR public.is_staff()
    OR EXISTS (
      SELECT 1 FROM public.tickets t
      WHERE t.id = ticket_id AND t.user_id = auth.uid()
    )
  );
CREATE POLICY ticket_messages_support_write ON public.ticket_messages FOR ALL
  USING (
    public.has_permission('support.tickets', auth.uid())
    OR public.has_permission('support.write', auth.uid())
    OR public.has_permission('manage_tickets', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR public.is_staff()
  )
  WITH CHECK (
    public.has_permission('support.tickets', auth.uid())
    OR public.has_permission('support.write', auth.uid())
    OR public.has_permission('manage_tickets', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR public.is_staff()
  );

-- Macro: read/write helpers applied per table
DROP POLICY IF EXISTS support_teams_select ON public.support_teams;
DROP POLICY IF EXISTS support_teams_write ON public.support_teams;
CREATE POLICY support_teams_select ON public.support_teams FOR SELECT
  USING (public.has_permission('support.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY support_teams_write ON public.support_teams FOR ALL
  USING (public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS support_agents_select ON public.support_agents;
DROP POLICY IF EXISTS support_agents_write ON public.support_agents;
CREATE POLICY support_agents_select ON public.support_agents FOR SELECT
  USING (public.has_permission('support.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY support_agents_write ON public.support_agents FOR ALL
  USING (public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS support_skills_select ON public.support_skills;
DROP POLICY IF EXISTS support_skills_write ON public.support_skills;
CREATE POLICY support_skills_select ON public.support_skills FOR SELECT
  USING (public.has_permission('support.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY support_skills_write ON public.support_skills FOR ALL
  USING (public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS support_agent_skills_select ON public.support_agent_skills;
DROP POLICY IF EXISTS support_agent_skills_write ON public.support_agent_skills;
CREATE POLICY support_agent_skills_select ON public.support_agent_skills FOR SELECT
  USING (public.has_permission('support.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY support_agent_skills_write ON public.support_agent_skills FOR ALL
  USING (public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS support_queues_select ON public.support_queues;
DROP POLICY IF EXISTS support_queues_write ON public.support_queues;
CREATE POLICY support_queues_select ON public.support_queues FOR SELECT
  USING (public.has_permission('support.read', auth.uid()) OR public.has_permission('support.inbox', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY support_queues_write ON public.support_queues FOR ALL
  USING (public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS support_categories_select ON public.support_categories;
DROP POLICY IF EXISTS support_categories_write ON public.support_categories;
CREATE POLICY support_categories_select ON public.support_categories FOR SELECT
  USING (public.has_permission('support.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY support_categories_write ON public.support_categories FOR ALL
  USING (public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS support_priorities_select ON public.support_priorities;
DROP POLICY IF EXISTS support_priorities_write ON public.support_priorities;
CREATE POLICY support_priorities_select ON public.support_priorities FOR SELECT
  USING (public.has_permission('support.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY support_priorities_write ON public.support_priorities FOR ALL
  USING (public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS support_statuses_select ON public.support_statuses;
DROP POLICY IF EXISTS support_statuses_write ON public.support_statuses;
CREATE POLICY support_statuses_select ON public.support_statuses FOR SELECT
  USING (public.has_permission('support.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY support_statuses_write ON public.support_statuses FOR ALL
  USING (public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS support_slas_select ON public.support_slas;
DROP POLICY IF EXISTS support_slas_write ON public.support_slas;
CREATE POLICY support_slas_select ON public.support_slas FOR SELECT
  USING (public.has_permission('support.sla', auth.uid()) OR public.has_permission('support.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY support_slas_write ON public.support_slas FOR ALL
  USING (public.has_permission('support.sla', auth.uid()) OR public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('support.sla', auth.uid()) OR public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS support_escalations_select ON public.support_escalations;
DROP POLICY IF EXISTS support_escalations_write ON public.support_escalations;
CREATE POLICY support_escalations_select ON public.support_escalations FOR SELECT
  USING (public.has_permission('support.escalations', auth.uid()) OR public.has_permission('support.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY support_escalations_write ON public.support_escalations FOR ALL
  USING (public.has_permission('support.escalations', auth.uid()) OR public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('support.escalations', auth.uid()) OR public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS support_assignments_select ON public.support_assignments;
DROP POLICY IF EXISTS support_assignments_write ON public.support_assignments;
CREATE POLICY support_assignments_select ON public.support_assignments FOR SELECT
  USING (public.has_permission('support.tickets', auth.uid()) OR public.has_permission('support.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY support_assignments_write ON public.support_assignments FOR ALL
  USING (public.has_permission('support.tickets', auth.uid()) OR public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('support.tickets', auth.uid()) OR public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS support_ticket_attachments_select ON public.support_ticket_attachments;
DROP POLICY IF EXISTS support_ticket_attachments_write ON public.support_ticket_attachments;
CREATE POLICY support_ticket_attachments_select ON public.support_ticket_attachments FOR SELECT
  USING (public.has_permission('support.tickets', auth.uid()) OR public.has_permission('support.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY support_ticket_attachments_write ON public.support_ticket_attachments FOR ALL
  USING (public.has_permission('support.tickets', auth.uid()) OR public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('support.tickets', auth.uid()) OR public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS support_ticket_notes_select ON public.support_ticket_notes;
DROP POLICY IF EXISTS support_ticket_notes_write ON public.support_ticket_notes;
CREATE POLICY support_ticket_notes_select ON public.support_ticket_notes FOR SELECT
  USING (public.has_permission('support.tickets', auth.uid()) OR public.has_permission('support.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY support_ticket_notes_write ON public.support_ticket_notes FOR ALL
  USING (public.has_permission('support.tickets', auth.uid()) OR public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('support.tickets', auth.uid()) OR public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS live_chat_sessions_select ON public.live_chat_sessions;
DROP POLICY IF EXISTS live_chat_sessions_write ON public.live_chat_sessions;
CREATE POLICY live_chat_sessions_select ON public.live_chat_sessions FOR SELECT
  USING (public.has_permission('support.chat', auth.uid()) OR public.has_permission('support.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY live_chat_sessions_write ON public.live_chat_sessions FOR ALL
  USING (public.has_permission('support.chat', auth.uid()) OR public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('support.chat', auth.uid()) OR public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS live_chat_messages_select ON public.live_chat_messages;
DROP POLICY IF EXISTS live_chat_messages_write ON public.live_chat_messages;
CREATE POLICY live_chat_messages_select ON public.live_chat_messages FOR SELECT
  USING (public.has_permission('support.chat', auth.uid()) OR public.has_permission('support.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY live_chat_messages_write ON public.live_chat_messages FOR ALL
  USING (public.has_permission('support.chat', auth.uid()) OR public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('support.chat', auth.uid()) OR public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS support_email_threads_select ON public.support_email_threads;
DROP POLICY IF EXISTS support_email_threads_write ON public.support_email_threads;
CREATE POLICY support_email_threads_select ON public.support_email_threads FOR SELECT
  USING (public.has_permission('support.email', auth.uid()) OR public.has_permission('support.inbox', auth.uid()) OR public.has_permission('support.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY support_email_threads_write ON public.support_email_threads FOR ALL
  USING (public.has_permission('support.email', auth.uid()) OR public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('support.email', auth.uid()) OR public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS support_email_messages_select ON public.support_email_messages;
DROP POLICY IF EXISTS support_email_messages_write ON public.support_email_messages;
CREATE POLICY support_email_messages_select ON public.support_email_messages FOR SELECT
  USING (public.has_permission('support.email', auth.uid()) OR public.has_permission('support.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY support_email_messages_write ON public.support_email_messages FOR ALL
  USING (public.has_permission('support.email', auth.uid()) OR public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('support.email', auth.uid()) OR public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS whatsapp_conversations_select ON public.whatsapp_conversations;
DROP POLICY IF EXISTS whatsapp_conversations_write ON public.whatsapp_conversations;
CREATE POLICY whatsapp_conversations_select ON public.whatsapp_conversations FOR SELECT
  USING (public.has_permission('support.whatsapp', auth.uid()) OR public.has_permission('support.inbox', auth.uid()) OR public.has_permission('support.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY whatsapp_conversations_write ON public.whatsapp_conversations FOR ALL
  USING (public.has_permission('support.whatsapp', auth.uid()) OR public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('support.whatsapp', auth.uid()) OR public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS whatsapp_messages_select ON public.whatsapp_messages;
DROP POLICY IF EXISTS whatsapp_messages_write ON public.whatsapp_messages;
CREATE POLICY whatsapp_messages_select ON public.whatsapp_messages FOR SELECT
  USING (public.has_permission('support.whatsapp', auth.uid()) OR public.has_permission('support.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY whatsapp_messages_write ON public.whatsapp_messages FOR ALL
  USING (public.has_permission('support.whatsapp', auth.uid()) OR public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('support.whatsapp', auth.uid()) OR public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS support_knowledge_categories_select ON public.support_knowledge_categories;
DROP POLICY IF EXISTS support_knowledge_categories_write ON public.support_knowledge_categories;
CREATE POLICY support_knowledge_categories_select ON public.support_knowledge_categories FOR SELECT
  USING (public.has_permission('support.knowledge', auth.uid()) OR public.has_permission('support.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY support_knowledge_categories_write ON public.support_knowledge_categories FOR ALL
  USING (public.has_permission('support.knowledge', auth.uid()) OR public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('support.knowledge', auth.uid()) OR public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS support_knowledge_articles_select ON public.support_knowledge_articles;
DROP POLICY IF EXISTS support_knowledge_articles_write ON public.support_knowledge_articles;
CREATE POLICY support_knowledge_articles_select ON public.support_knowledge_articles FOR SELECT
  USING (public.has_permission('support.knowledge', auth.uid()) OR public.has_permission('support.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY support_knowledge_articles_write ON public.support_knowledge_articles FOR ALL
  USING (public.has_permission('support.knowledge', auth.uid()) OR public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('support.knowledge', auth.uid()) OR public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS support_knowledge_versions_select ON public.support_knowledge_versions;
DROP POLICY IF EXISTS support_knowledge_versions_write ON public.support_knowledge_versions;
CREATE POLICY support_knowledge_versions_select ON public.support_knowledge_versions FOR SELECT
  USING (public.has_permission('support.knowledge', auth.uid()) OR public.has_permission('support.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY support_knowledge_versions_write ON public.support_knowledge_versions FOR ALL
  USING (public.has_permission('support.knowledge', auth.uid()) OR public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('support.knowledge', auth.uid()) OR public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS customer_feedback_select ON public.customer_feedback;
DROP POLICY IF EXISTS customer_feedback_write ON public.customer_feedback;
CREATE POLICY customer_feedback_select ON public.customer_feedback FOR SELECT
  USING (public.has_permission('support.analytics', auth.uid()) OR public.has_permission('support.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY customer_feedback_write ON public.customer_feedback FOR ALL
  USING (public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS csat_surveys_select ON public.csat_surveys;
DROP POLICY IF EXISTS csat_surveys_write ON public.csat_surveys;
CREATE POLICY csat_surveys_select ON public.csat_surveys FOR SELECT
  USING (public.has_permission('support.analytics', auth.uid()) OR public.has_permission('support.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY csat_surveys_write ON public.csat_surveys FOR ALL
  USING (public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS nps_surveys_select ON public.nps_surveys;
DROP POLICY IF EXISTS nps_surveys_write ON public.nps_surveys;
CREATE POLICY nps_surveys_select ON public.nps_surveys FOR SELECT
  USING (public.has_permission('support.analytics', auth.uid()) OR public.has_permission('support.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY nps_surveys_write ON public.nps_surveys FOR ALL
  USING (public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS support_reports_select ON public.support_reports;
DROP POLICY IF EXISTS support_reports_write ON public.support_reports;
CREATE POLICY support_reports_select ON public.support_reports FOR SELECT
  USING (public.has_permission('support.reports', auth.uid()) OR public.has_permission('support.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY support_reports_write ON public.support_reports FOR ALL
  USING (public.has_permission('support.reports', auth.uid()) OR public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('support.reports', auth.uid()) OR public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS support_activity_logs_select ON public.support_activity_logs;
DROP POLICY IF EXISTS support_activity_logs_write ON public.support_activity_logs;
CREATE POLICY support_activity_logs_select ON public.support_activity_logs FOR SELECT
  USING (public.has_permission('support.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY support_activity_logs_write ON public.support_activity_logs FOR ALL
  USING (public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS support_notifications_select ON public.support_notifications;
DROP POLICY IF EXISTS support_notifications_write ON public.support_notifications;
CREATE POLICY support_notifications_select ON public.support_notifications FOR SELECT
  USING (public.has_permission('support.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY support_notifications_write ON public.support_notifications FOR ALL
  USING (public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS call_center_calls_select ON public.call_center_calls;
DROP POLICY IF EXISTS call_center_calls_write ON public.call_center_calls;
CREATE POLICY call_center_calls_select ON public.call_center_calls FOR SELECT
  USING (public.has_permission('support.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY call_center_calls_write ON public.call_center_calls FOR ALL
  USING (public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS support_ai_insights_select ON public.support_ai_insights;
DROP POLICY IF EXISTS support_ai_insights_write ON public.support_ai_insights;
CREATE POLICY support_ai_insights_select ON public.support_ai_insights FOR SELECT
  USING (public.has_permission('support.ai', auth.uid()) OR public.has_permission('support.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY support_ai_insights_write ON public.support_ai_insights FOR ALL
  USING (public.has_permission('support.ai', auth.uid()) OR public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('support.ai', auth.uid()) OR public.has_permission('support.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE ON
  public.support_teams,
  public.support_agents,
  public.support_skills,
  public.support_agent_skills,
  public.support_queues,
  public.support_categories,
  public.support_priorities,
  public.support_statuses,
  public.support_slas,
  public.support_escalations,
  public.support_assignments,
  public.support_ticket_attachments,
  public.support_ticket_notes,
  public.live_chat_sessions,
  public.live_chat_messages,
  public.support_email_threads,
  public.support_email_messages,
  public.whatsapp_conversations,
  public.whatsapp_messages,
  public.support_knowledge_categories,
  public.support_knowledge_articles,
  public.support_knowledge_versions,
  public.customer_feedback,
  public.csat_surveys,
  public.nps_surveys,
  public.support_reports,
  public.support_activity_logs,
  public.support_notifications,
  public.call_center_calls,
  public.support_ai_insights
TO authenticated;

GRANT SELECT ON public.support_tickets TO authenticated;

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'tickets',
    'live_chat_messages',
    'support_activity_logs',
    'support_notifications',
    'whatsapp_messages'
  ]
  LOOP
    BEGIN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    EXCEPTION
      WHEN duplicate_object THEN NULL;
      WHEN undefined_object THEN NULL;
    END;
  END LOOP;
END $$;

COMMIT;
