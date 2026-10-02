-- HD Homes Support Phase 5 — realtime publication and filtered-update hardening.
--
-- RLS still controls which rows each subscriber can receive. REPLICA IDENTITY
-- FULL ensures row filters continue to work for UPDATE/DELETE delivery.

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'tickets',
    'ticket_messages',
    'live_chat_sessions',
    'live_chat_messages',
    'client_conversations',
    'client_conversation_messages',
    'investor_conversations',
    'investor_conversation_messages',
    'support_agents',
    'support_assignments',
    'support_notifications',
    'support_ticket_events',
    'support_ticket_links',
    'support_settings',
    'support_operating_hours',
    'support_holidays',
    'support_quick_replies',
    'support_assignment_rules',
    'support_escalations',
    'support_knowledge_articles',
    'support_activity_logs'
  ]
  LOOP
    IF to_regclass('public.' || t) IS NOT NULL THEN
      IF NOT EXISTS (
        SELECT 1
        FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
          AND schemaname = 'public'
          AND tablename = t
      ) THEN
        EXECUTE format(
          'ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',
          t
        );
      END IF;

      EXECUTE format('ALTER TABLE public.%I REPLICA IDENTITY FULL', t);
    END IF;
  END LOOP;
END $$;

COMMENT ON TABLE public.support_ticket_events IS
  'Append-oriented ticket lifecycle timeline; delivered through RLS-filtered Supabase Realtime.';
COMMENT ON TABLE public.support_ticket_links IS
  'RLS-protected links from tickets to existing platform records; realtime-enabled for the selected-ticket context panel.';
