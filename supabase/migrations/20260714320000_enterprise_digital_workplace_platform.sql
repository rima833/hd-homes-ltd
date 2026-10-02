-- APPLIED remotely (2026-07-21) via MCP chunks: edwp_p1a, edwp_p1b, edwp_p2, edwp_p3
-- Volume 4 Part 21 — Enterprise Communication, Collaboration, Knowledge Management
-- & Digital Workplace Platform (EDWP)
-- ENRICHES knowledge_articles in place. Never recreates it.
-- Does NOT recreate tasks, chat_messages, announcement_posts, hr_announcements,
-- support_knowledge_*, meeting_records, or board_meetings.
-- Does NOT replace /dashboard/communications (Volume 3 AdminCommunicationPage).
-- Permissions use (slug, name, description, module); has_permission slug is FIRST.
-- Seed UUIDs are hex-only d210….

BEGIN;

INSERT INTO public.permissions (slug, name, description, module) VALUES
 ('workplace.read','View Workplace','View Digital Workplace Command Center','workplace'),
 ('workplace.write','Manage Workplace','Create and update workplace records','workplace'),
 ('workplace.messaging','Messaging','Manage direct and group messaging','workplace'),
 ('workplace.announcements','Announcements','Manage workplace announcements','workplace'),
 ('workplace.workspaces','Workspaces','Manage collaboration workspaces','workplace'),
 ('workplace.tasks','Collaborative Tasks','Manage collaborative tasks','workplace'),
 ('workplace.calendar','Calendar','Manage calendars and events','workplace'),
 ('workplace.meetings','Meetings','Manage meetings, agendas, and minutes','workplace'),
 ('workplace.knowledge','Knowledge','Manage knowledge base articles','workplace'),
 ('workplace.wiki','Wiki','Manage enterprise wiki pages','workplace'),
 ('workplace.communities','Communities','Manage employee communities','workplace'),
 ('workplace.search','Workplace Search','Use enterprise workplace search','workplace'),
 ('workplace.ai','Workplace AI','View workplace AI insights','workplace'),
 ('workplace.analytics','Workplace Analytics','View productivity analytics','workplace'),
 ('workplace.admin','Workplace Administration','Administer the Digital Workplace Platform','workplace')
ON CONFLICT (slug) DO UPDATE SET
 name=EXCLUDED.name, description=EXCLUDED.description, module=EXCLUDED.module, updated_at=now();

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM public.roles r CROSS JOIN public.permissions p
WHERE p.slug LIKE 'workplace.%' AND (
 r.slug IN ('super_admin','admin')
 OR (r.slug='finance' AND p.slug IN ('workplace.read','workplace.analytics','workplace.meetings'))
 OR (r.slug='construction_manager' AND p.slug IN ('workplace.read','workplace.workspaces','workplace.tasks'))
 OR (r.slug='sales_team' AND p.slug IN ('workplace.read','workplace.messaging','workplace.tasks'))
 OR (r.slug='marketing' AND p.slug IN ('workplace.read','workplace.announcements','workplace.communities'))
) ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS public.workplace_profiles (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
 display_name text NOT NULL, title_label text, department_label text,
 status text NOT NULL DEFAULT 'active', timezone text DEFAULT 'Africa/Lagos',
 summary text, preferences jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.workplace_status (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
 status_label text NOT NULL DEFAULT 'available',
 status text NOT NULL DEFAULT 'active', message text,
 until_at timestamptz, metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.group_conversations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'group', conversation_type text NOT NULL DEFAULT 'team',
 status text NOT NULL DEFAULT 'active', owner_label text, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.direct_messages (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), conversation_id uuid REFERENCES public.group_conversations(id) ON DELETE SET NULL,
 title text NOT NULL, category text NOT NULL DEFAULT 'message',
 sender_label text, recipient_label text, body text,
 status text NOT NULL DEFAULT 'sent', severity text NOT NULL DEFAULT 'info',
 is_pinned boolean NOT NULL DEFAULT false, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 occurred_at timestamptz NOT NULL DEFAULT now(),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.conversation_members (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 conversation_id uuid NOT NULL REFERENCES public.group_conversations(id) ON DELETE CASCADE,
 member_label text NOT NULL, role_label text NOT NULL DEFAULT 'member',
 status text NOT NULL DEFAULT 'active', summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.message_reactions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 message_id uuid NOT NULL REFERENCES public.direct_messages(id) ON DELETE CASCADE,
 reactor_label text, reaction text NOT NULL DEFAULT '👍',
 status text NOT NULL DEFAULT 'active',
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.message_attachments (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 message_id uuid NOT NULL REFERENCES public.direct_messages(id) ON DELETE CASCADE,
 name text NOT NULL, storage_path text, mime_type text,
 status text NOT NULL DEFAULT 'ready', summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.workplace_announcements (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'announcement', announcement_type text NOT NULL DEFAULT 'company',
 status text NOT NULL DEFAULT 'draft', severity text NOT NULL DEFAULT 'info',
 audience text NOT NULL DEFAULT 'all_employees', author_label text, body text, summary text,
 published_at timestamptz, metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.announcement_reads (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 announcement_id uuid NOT NULL REFERENCES public.workplace_announcements(id) ON DELETE CASCADE,
 reader_label text NOT NULL, status text NOT NULL DEFAULT 'read',
 read_at timestamptz NOT NULL DEFAULT now(),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.collaboration_workspaces (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, name text NOT NULL,
 category text NOT NULL DEFAULT 'workspace', workspace_type text NOT NULL DEFAULT 'project',
 status text NOT NULL DEFAULT 'active', owner_label text, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.workspace_members (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 workspace_id uuid NOT NULL REFERENCES public.collaboration_workspaces(id) ON DELETE CASCADE,
 member_label text NOT NULL, role_label text NOT NULL DEFAULT 'member',
 status text NOT NULL DEFAULT 'active', summary text,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.workspace_activity (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 workspace_id uuid REFERENCES public.collaboration_workspaces(id) ON DELETE CASCADE,
 title text NOT NULL, category text NOT NULL DEFAULT 'activity',
 status text NOT NULL DEFAULT 'recorded', actor_label text, summary text,
 occurred_at timestamptz NOT NULL DEFAULT now(),
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.collaborative_tasks (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'task', priority text NOT NULL DEFAULT 'medium',
 status text NOT NULL DEFAULT 'open', severity text NOT NULL DEFAULT 'info',
 owner_label text, workspace_id uuid REFERENCES public.collaboration_workspaces(id) ON DELETE SET NULL,
 due_at timestamptz, summary text, metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.task_comments (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 task_id uuid NOT NULL REFERENCES public.collaborative_tasks(id) ON DELETE CASCADE,
 author_label text, body text NOT NULL, status text NOT NULL DEFAULT 'posted',
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.task_checklists (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 task_id uuid NOT NULL REFERENCES public.collaborative_tasks(id) ON DELETE CASCADE,
 title text NOT NULL, is_done boolean NOT NULL DEFAULT false,
 status text NOT NULL DEFAULT 'open', item_order int NOT NULL DEFAULT 1,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.calendars (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, name text NOT NULL,
 category text NOT NULL DEFAULT 'calendar', calendar_type text NOT NULL DEFAULT 'personal',
 status text NOT NULL DEFAULT 'active', owner_label text, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.calendar_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 calendar_id uuid REFERENCES public.calendars(id) ON DELETE CASCADE,
 code text UNIQUE, title text NOT NULL, category text NOT NULL DEFAULT 'event',
 status text NOT NULL DEFAULT 'scheduled', severity text NOT NULL DEFAULT 'info',
 starts_at timestamptz, ends_at timestamptz, location_label text, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.meeting_rooms (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, name text NOT NULL,
 category text NOT NULL DEFAULT 'room', capacity int DEFAULT 8,
 status text NOT NULL DEFAULT 'available', location_label text, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.meetings (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'meeting', status text NOT NULL DEFAULT 'scheduled',
 severity text NOT NULL DEFAULT 'info', organizer_label text,
 room_id uuid REFERENCES public.meeting_rooms(id) ON DELETE SET NULL,
 scheduled_at timestamptz, ends_at timestamptz, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.meeting_agendas (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 meeting_id uuid NOT NULL REFERENCES public.meetings(id) ON DELETE CASCADE,
 title text NOT NULL, item_order int NOT NULL DEFAULT 1,
 status text NOT NULL DEFAULT 'planned', summary text,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.meeting_minutes (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 meeting_id uuid NOT NULL REFERENCES public.meetings(id) ON DELETE CASCADE,
 title text NOT NULL, body text, status text NOT NULL DEFAULT 'draft',
 author_label text, summary text,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.meeting_action_items (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 meeting_id uuid NOT NULL REFERENCES public.meetings(id) ON DELETE CASCADE,
 title text NOT NULL, owner_label text, status text NOT NULL DEFAULT 'open',
 due_at timestamptz, summary text,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.knowledge_categories (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, name text NOT NULL,
 category text NOT NULL DEFAULT 'knowledge', status text NOT NULL DEFAULT 'active',
 parent_id uuid REFERENCES public.knowledge_categories(id) ON DELETE SET NULL,
 summary text, metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

-- Existing Volume 3/support knowledge_articles: enrich only — never DROP/recreate.
ALTER TABLE public.knowledge_articles
 ADD COLUMN IF NOT EXISTS workplace_surface text,
 ADD COLUMN IF NOT EXISTS category_id uuid REFERENCES public.knowledge_categories(id) ON DELETE SET NULL,
 ADD COLUMN IF NOT EXISTS owner_label text,
 ADD COLUMN IF NOT EXISTS version_label text DEFAULT '1.0',
 ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb;

CREATE TABLE IF NOT EXISTS public.knowledge_versions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 article_id uuid NOT NULL REFERENCES public.knowledge_articles(id) ON DELETE CASCADE,
 version_label text NOT NULL, title text NOT NULL, body text,
 status text NOT NULL DEFAULT 'published', author_label text, summary text,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.wiki_pages (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 slug text UNIQUE, category text NOT NULL DEFAULT 'wiki',
 status text NOT NULL DEFAULT 'draft', owner_label text, body text, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.wiki_revisions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 page_id uuid NOT NULL REFERENCES public.wiki_pages(id) ON DELETE CASCADE,
 title text NOT NULL, body text, revision_no int NOT NULL DEFAULT 1,
 status text NOT NULL DEFAULT 'published', author_label text, summary text,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.employee_communities (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, name text NOT NULL,
 category text NOT NULL DEFAULT 'community', community_type text NOT NULL DEFAULT 'interest',
 status text NOT NULL DEFAULT 'active', owner_label text, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.community_posts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 community_id uuid NOT NULL REFERENCES public.employee_communities(id) ON DELETE CASCADE,
 title text NOT NULL, category text NOT NULL DEFAULT 'post',
 status text NOT NULL DEFAULT 'published', author_label text, body text, summary text,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.community_comments (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 post_id uuid NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
 author_label text, body text NOT NULL, status text NOT NULL DEFAULT 'posted',
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.workplace_search_history (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 query_text text NOT NULL, category text NOT NULL DEFAULT 'search',
 status text NOT NULL DEFAULT 'recorded', actor_label text, result_count int DEFAULT 0,
 summary text, metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 occurred_at timestamptz NOT NULL DEFAULT now(),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.workplace_productivity_metrics (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 metric_key text NOT NULL, category text NOT NULL DEFAULT 'productivity',
 status text NOT NULL DEFAULT 'ok', value numeric, unit text DEFAULT 'count',
 summary text, series jsonb NOT NULL DEFAULT '[]'::jsonb,
 recorded_at timestamptz NOT NULL DEFAULT now(),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.workplace_activity_logs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), action text NOT NULL, title text NOT NULL,
 category text NOT NULL DEFAULT 'workplace', actor_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
 actor_label text, entity_type text, entity_id uuid, severity text NOT NULL DEFAULT 'info',
 status text NOT NULL DEFAULT 'recorded', summary text, metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 occurred_at timestamptz NOT NULL DEFAULT now(),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.workplace_notifications (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), recipient_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
 title text NOT NULL, category text NOT NULL DEFAULT 'workplace', channel text NOT NULL DEFAULT 'in_app',
 severity text NOT NULL DEFAULT 'info', status text NOT NULL DEFAULT 'unread', body text,
 read_at timestamptz, metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.workplace_ai_insights (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 body text NOT NULL, category text NOT NULL DEFAULT 'workplace', insight_type text NOT NULL,
 confidence_pct numeric(5,2), status text NOT NULL DEFAULT 'active', editable boolean NOT NULL DEFAULT true,
 disclaimer text NOT NULL DEFAULT 'AI-generated — editable / advisory',
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_direct_messages_status ON public.direct_messages(status, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_workplace_announcements_status ON public.workplace_announcements(status, published_at DESC);
CREATE INDEX IF NOT EXISTS idx_collaborative_tasks_status ON public.collaborative_tasks(status, due_at);
CREATE INDEX IF NOT EXISTS idx_meetings_status ON public.meetings(status, scheduled_at DESC);
CREATE INDEX IF NOT EXISTS idx_wiki_pages_status ON public.wiki_pages(status, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_employee_communities_status ON public.employee_communities(status, created_at DESC);

INSERT INTO storage.buckets (id,name,public) VALUES ('workplace-artifacts','workplace-artifacts',false)
ON CONFLICT (id) DO NOTHING;

DO $$ BEGIN
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.direct_messages; EXCEPTION WHEN duplicate_object THEN NULL; END;
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.workplace_announcements; EXCEPTION WHEN duplicate_object THEN NULL; END;
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.collaborative_tasks; EXCEPTION WHEN duplicate_object THEN NULL; END;
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.meetings; EXCEPTION WHEN duplicate_object THEN NULL; END;
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.workplace_activity_logs; EXCEPTION WHEN duplicate_object THEN NULL; END;
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.workplace_notifications; EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

DO $$
DECLARE t text;
BEGIN
 FOREACH t IN ARRAY ARRAY[
  'workplace_profiles','workplace_status','group_conversations','direct_messages',
  'conversation_members','message_reactions','message_attachments',
  'workplace_announcements','announcement_reads',
  'collaboration_workspaces','workspace_members','workspace_activity',
  'collaborative_tasks','task_comments','task_checklists',
  'calendars','calendar_events','meeting_rooms','meetings',
  'meeting_agendas','meeting_minutes','meeting_action_items',
  'knowledge_categories','knowledge_versions','wiki_pages','wiki_revisions',
  'employee_communities','community_posts','community_comments',
  'workplace_search_history','workplace_productivity_metrics',
  'workplace_activity_logs','workplace_notifications','workplace_ai_insights'
 ] LOOP
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
  EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_select', t);
  EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_write', t);
  EXECUTE format(
   'CREATE POLICY %I ON public.%I FOR SELECT USING (public.has_permission(''workplace.read'', auth.uid()) OR public.has_permission(''workplace.admin'', auth.uid()) OR public.has_role(''super_admin'', auth.uid()))',
   t || '_select', t
  );
  EXECUTE format(
   'CREATE POLICY %I ON public.%I FOR ALL USING (public.has_permission(''workplace.write'', auth.uid()) OR public.has_permission(''workplace.admin'', auth.uid()) OR public.has_role(''super_admin'', auth.uid())) WITH CHECK (public.has_permission(''workplace.write'', auth.uid()) OR public.has_permission(''workplace.admin'', auth.uid()) OR public.has_role(''super_admin'', auth.uid()))',
   t || '_write', t
  );
 END LOOP;
END $$;

GRANT SELECT, INSERT, UPDATE, DELETE ON
 public.workplace_profiles, public.workplace_status, public.group_conversations, public.direct_messages,
 public.conversation_members, public.message_reactions, public.message_attachments,
 public.workplace_announcements, public.announcement_reads,
 public.collaboration_workspaces, public.workspace_members, public.workspace_activity,
 public.collaborative_tasks, public.task_comments, public.task_checklists,
 public.calendars, public.calendar_events, public.meeting_rooms, public.meetings,
 public.meeting_agendas, public.meeting_minutes, public.meeting_action_items,
 public.knowledge_categories, public.knowledge_versions, public.wiki_pages, public.wiki_revisions,
 public.employee_communities, public.community_posts, public.community_comments,
 public.workplace_search_history, public.workplace_productivity_metrics,
 public.workplace_activity_logs, public.workplace_notifications, public.workplace_ai_insights
TO authenticated;

-- Phase 1 demo seeds (hex-only d210…).
INSERT INTO public.workplace_profiles (id,display_name,title_label,department_label,status,summary) VALUES
 ('d2100001-0000-4000-8000-000000000001','Amina Okonkwo','Platform Lead','Engineering','active','Digital workplace owner'),
 ('d2100001-0000-4000-8000-000000000002','Chidi Eze','SRE Lead','Operations','active','Incident and meeting ops')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.workplace_status (id,status_label,status,message) VALUES
 ('d2100001-0000-4000-8000-000000000003','available','active','Open for collaboration')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.group_conversations (id,code,title,conversation_type,status,owner_label,summary) VALUES
 ('d2100002-0000-4000-8000-000000000001','CONV-ENG','Engineering Standup','department','active','Platform Engineering','Daily engineering coordination')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.conversation_members (id,conversation_id,member_label,role_label,status) VALUES
 ('d2100002-0000-4000-8000-000000000002','d2100002-0000-4000-8000-000000000001','Amina Okonkwo','owner','active'),
 ('d2100002-0000-4000-8000-000000000003','d2100002-0000-4000-8000-000000000001','Chidi Eze','member','active')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.direct_messages (id,conversation_id,title,sender_label,recipient_label,body,status,summary) VALUES
 ('d2100003-0000-4000-8000-000000000001','d2100002-0000-4000-8000-000000000001','Staging soak update','Amina Okonkwo','Engineering Standup','Staging deploy is soaking — hold production until CAB.','sent','Pinned ops note'),
 ('d2100003-0000-4000-8000-000000000002','d2100002-0000-4000-8000-000000000001','Room booking confirmed','Chidi Eze','Engineering Standup','Board room reserved for release review at 15:00.','sent','Meeting logistics')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.workplace_announcements (id,code,title,announcement_type,status,severity,audience,author_label,body,summary,published_at) VALUES
 ('d2100004-0000-4000-8000-000000000001','ANN-2026-021','Digital Workplace launch','company','published','info','all_employees','Executive Office','HD Homes Digital Workplace is live for messaging, knowledge, and meetings.','Company-wide launch',now()-interval '2 hours')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.announcement_reads (id,announcement_id,reader_label,status) VALUES
 ('d2100004-0000-4000-8000-000000000002','d2100004-0000-4000-8000-000000000001','Amina Okonkwo','read')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.collaboration_workspaces (id,code,name,workspace_type,status,owner_label,summary) VALUES
 ('d2100005-0000-4000-8000-000000000001','WS-RELEASE','July Release Coordination','project','active','Platform Engineering','Cross-functional release workspace')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.workspace_members (id,workspace_id,member_label,role_label,status) VALUES
 ('d2100005-0000-4000-8000-000000000002','d2100005-0000-4000-8000-000000000001','Amina Okonkwo','lead','active')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.workspace_activity (id,workspace_id,title,actor_label,summary) VALUES
 ('d2100005-0000-4000-8000-000000000003','d2100005-0000-4000-8000-000000000001','Workspace opened for CAB prep','Amina Okonkwo','Members synced')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.collaborative_tasks (id,code,title,priority,status,owner_label,workspace_id,due_at,summary) VALUES
 ('d2100006-0000-4000-8000-000000000001','TSK-WP-01','Prepare release briefing pack','high','in_progress','Amina Okonkwo','d2100005-0000-4000-8000-000000000001',now()+interval '1 day','Include risk and rollback notes'),
 ('d2100006-0000-4000-8000-000000000002','TSK-WP-02','Update construction SOP wiki','medium','open','Chidi Eze','d2100005-0000-4000-8000-000000000001',now()+interval '3 days','Link knowledge article')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.task_comments (id,task_id,author_label,body,status) VALUES
 ('d2100006-0000-4000-8000-000000000003','d2100006-0000-4000-8000-000000000001','Chidi Eze','Add staging latency context to the briefing.','posted')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.task_checklists (id,task_id,title,is_done,status,item_order) VALUES
 ('d2100006-0000-4000-8000-000000000004','d2100006-0000-4000-8000-000000000001','Draft agenda',true,'done',1),
 ('d2100006-0000-4000-8000-000000000005','d2100006-0000-4000-8000-000000000001','Attach rollback runbook',false,'open',2)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.calendars (id,code,name,calendar_type,status,owner_label,summary) VALUES
 ('d2100007-0000-4000-8000-000000000001','CAL-CO','Company Calendar','company','active','Executive Office','Org-wide events'),
 ('d2100007-0000-4000-8000-000000000002','CAL-ENG','Engineering Calendar','department','active','Platform Engineering','Team schedule')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.calendar_events (id,calendar_id,code,title,status,starts_at,ends_at,location_label,summary) VALUES
 ('d2100007-0000-4000-8000-000000000003','d2100007-0000-4000-8000-000000000002','EVT-CAB','CAB release review','scheduled',now()+interval '5 hours',now()+interval '6 hours','Board Room','Production approval gate')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.meeting_rooms (id,code,name,capacity,status,location_label,summary) VALUES
 ('d2100008-0000-4000-8000-000000000001','ROOM-BOARD','Board Room',12,'available','HQ Floor 3','Primary CAB room')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.meetings (id,code,title,status,organizer_label,room_id,scheduled_at,ends_at,summary) VALUES
 ('d2100008-0000-4000-8000-000000000002','MTG-CAB-0721','CAB production approval','scheduled','Release Manager','d2100008-0000-4000-8000-000000000001',now()+interval '5 hours',now()+interval '6 hours','Approve July platform release')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.meeting_agendas (id,meeting_id,title,item_order,status,summary) VALUES
 ('d2100008-0000-4000-8000-000000000003','d2100008-0000-4000-8000-000000000002','Risk and soak review',1,'planned','Staging latency discussion')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.meeting_minutes (id,meeting_id,title,body,status,author_label,summary) VALUES
 ('d2100008-0000-4000-8000-000000000004','d2100008-0000-4000-8000-000000000002','Draft minutes template','Pending live session','draft','Scribe','Auto-prep')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.meeting_action_items (id,meeting_id,title,owner_label,status,due_at,summary) VALUES
 ('d2100008-0000-4000-8000-000000000005','d2100008-0000-4000-8000-000000000002','Confirm rollback owner','Chidi Eze','open',now()+interval '1 day','Pre-CAB action')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.knowledge_categories (id,code,name,status,summary) VALUES
 ('d2100009-0000-4000-8000-000000000001','KC-POL','Policies','active','Company policies'),
 ('d2100009-0000-4000-8000-000000000002','KC-SOP','SOPs','active','Standard operating procedures')
ON CONFLICT (id) DO NOTHING;

UPDATE public.knowledge_articles
SET workplace_surface = COALESCE(workplace_surface, 'digital_workplace'),
    category_id = COALESCE(category_id, 'd2100009-0000-4000-8000-000000000002'),
    owner_label = COALESCE(owner_label, 'Platform Engineering'),
    version_label = COALESCE(version_label, '1.0'),
    hub_metadata = COALESCE(hub_metadata, '{"module":"workplace"}'::jsonb)
WHERE id IN (SELECT id FROM public.knowledge_articles ORDER BY created_at LIMIT 2);

INSERT INTO public.knowledge_versions (id,article_id,version_label,title,body,status,author_label,summary)
SELECT 'd2100009-0000-4000-8000-000000000003', ka.id, '1.0', ka.title, ka.body, 'published', 'Platform Engineering', 'Baseline workplace version'
FROM public.knowledge_articles ka
ORDER BY ka.created_at
LIMIT 1
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.wiki_pages (id,code,title,slug,status,owner_label,body,summary) VALUES
 ('d210000a-0000-4000-8000-000000000001','WIKI-DEPLOY','Deployment Playbook','deployment-playbook','published','Platform Engineering','# Deploy\n\n1. Build\n2. Soak\n3. CAB','Internal wiki playbook')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.wiki_revisions (id,page_id,title,body,revision_no,status,author_label,summary) VALUES
 ('d210000a-0000-4000-8000-000000000002','d210000a-0000-4000-8000-000000000001','Deployment Playbook','# Deploy\n\n1. Build\n2. Soak\n3. CAB',1,'published','Amina Okonkwo','Initial publish')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.employee_communities (id,code,name,community_type,status,owner_label,summary) VALUES
 ('d210000b-0000-4000-8000-000000000001','COM-LEARN','Learning Guild','learning','active','People Ops','Knowledge sharing community')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.community_posts (id,community_id,title,status,author_label,body,summary) VALUES
 ('d210000b-0000-4000-8000-000000000002','d210000b-0000-4000-8000-000000000001','Welcome to the Digital Workplace','published','People Ops','Share tips and playbooks here.','Kickoff post')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.community_comments (id,post_id,author_label,body,status) VALUES
 ('d210000b-0000-4000-8000-000000000003','d210000b-0000-4000-8000-000000000002','Amina Okonkwo','Excited to centralize our SOPs.','posted')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.workplace_search_history (id,query_text,actor_label,result_count,summary) VALUES
 ('d210000c-0000-4000-8000-000000000001','deployment playbook','Amina Okonkwo',3,'Wiki + knowledge hits')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.workplace_productivity_metrics (id,code,title,metric_key,status,value,unit,summary) VALUES
 ('d210000c-0000-4000-8000-000000000002','WPM-TASK-DONE','Task completion rate','task_completion_pct','ok',86,'pct','Last 7 days'),
 ('d210000c-0000-4000-8000-000000000003','WPM-MEET-EFF','Meeting effectiveness','meeting_effectiveness','ok',78,'pct','Action-item follow-through')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.workplace_ai_insights (id,code,title,body,insight_type,confidence_pct) VALUES
 ('d210000d-0000-4000-8000-000000000001','AI-WP-01','Prioritize CAB briefing task before 15:00','Open high-priority task and scheduled CAB meeting overlap — complete briefing pack first.','task',92),
 ('d210000d-0000-4000-8000-000000000002','AI-WP-02','Surface deployment playbook in standup','Recent search and wiki activity suggest pinning the Deployment Playbook in Engineering Standup.','knowledge',88)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.workplace_activity_logs (id,action,title,category,actor_label,entity_type,severity,status,summary) VALUES
 ('d210000e-0000-4000-8000-000000000001','announcement.published','Workplace launch published','announcement','Executive Office','workplace_announcements','info','recorded','ANN-2026-021 live'),
 ('d210000e-0000-4000-8000-000000000002','meeting.scheduled','CAB meeting scheduled','meeting','Release Manager','meetings','info','recorded','MTG-CAB-0721')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.kpi_snapshots (id,metric_key,label,value,previous_value,unit,change_pct,series,period,metadata) VALUES
 ('d210000f-0000-4000-8000-000000000001','workplace_task_completion','Task Completion',86,81,'pct',6.2,'[70,74,78,80,82,84,86]'::jsonb,'daily','{"module":"workplace"}'),
 ('d210000f-0000-4000-8000-000000000002','workplace_engagement','Workspace Engagement',91,88,'pct',3.4,'[80,82,85,87,88,90,91]'::jsonb,'daily','{"module":"workplace"}'),
 ('d210000f-0000-4000-8000-000000000003','workplace_knowledge_usage','Knowledge Usage',74,69,'pct',7.2,'[60,62,65,68,70,72,74]'::jsonb,'daily','{"module":"workplace"}')
ON CONFLICT (id) DO NOTHING;

COMMIT;
