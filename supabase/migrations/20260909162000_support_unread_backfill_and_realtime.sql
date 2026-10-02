-- Backfill unread counters and ensure support realtime publication coverage.

BEGIN;

UPDATE public.client_conversations c
SET client_unread_count = COALESCE((
  SELECT COUNT(*)::integer
  FROM public.client_conversation_messages m
  JOIN public.clients cl ON cl.id = c.client_id
  WHERE m.conversation_id = c.id
    AND m.is_deleted = false
    AND m.read_at IS NULL
    AND m.sender_id IS DISTINCT FROM cl.user_id
), 0),
staff_unread_count = COALESCE((
  SELECT COUNT(*)::integer
  FROM public.client_conversation_messages m
  JOIN public.clients cl ON cl.id = c.client_id
  WHERE m.conversation_id = c.id
    AND m.is_deleted = false
    AND m.read_at IS NULL
    AND m.sender_id = cl.user_id
), 0),
updated_at = now();

UPDATE public.investor_conversations c
SET investor_unread_count = COALESCE((
  SELECT COUNT(*)::integer
  FROM public.investor_conversation_messages m
  JOIN public.investors i ON i.id = c.investor_id
  WHERE m.conversation_id = c.id
    AND COALESCE(m.is_deleted, false) = false
    AND m.read_at IS NULL
    AND m.sender_id IS DISTINCT FROM i.user_id
), 0),
staff_unread_count = COALESCE((
  SELECT COUNT(*)::integer
  FROM public.investor_conversation_messages m
  JOIN public.investors i ON i.id = c.investor_id
  WHERE m.conversation_id = c.id
    AND COALESCE(m.is_deleted, false) = false
    AND m.read_at IS NULL
    AND m.sender_id = i.user_id
), 0),
updated_at = now();

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
    'support_ticket_events'
  ]
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    END IF;
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.support_realtime_unread_smoke()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'ok',
      (SELECT COUNT(*) = 10 FROM pg_publication_tables
       WHERE pubname = 'supabase_realtime' AND schemaname = 'public'
         AND tablename IN (
           'tickets','ticket_messages','live_chat_sessions','live_chat_messages',
           'client_conversations','client_conversation_messages',
           'investor_conversations','investor_conversation_messages',
           'support_agents','support_ticket_events'
         ))
      AND EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema='public' AND table_name='client_conversations'
          AND column_name='client_unread_count'
      ),
    'checked_at', now()
  );
$$;

REVOKE ALL ON FUNCTION public.support_realtime_unread_smoke() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.support_realtime_unread_smoke() TO authenticated;

COMMIT;
