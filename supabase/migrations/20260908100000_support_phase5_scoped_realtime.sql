-- Denormalized ownership keys for narrow, RLS-protected Realtime filters.
-- Source relationships remain authoritative; triggers populate these keys.

ALTER TABLE public.ticket_messages
  ADD COLUMN IF NOT EXISTS owner_user_id uuid
    REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.client_conversation_messages
  ADD COLUMN IF NOT EXISTS client_id uuid
    REFERENCES public.clients(id) ON DELETE CASCADE;
ALTER TABLE public.investor_conversation_messages
  ADD COLUMN IF NOT EXISTS investor_id uuid
    REFERENCES public.investors(id) ON DELETE CASCADE;

UPDATE public.ticket_messages m
SET owner_user_id = t.user_id
FROM public.tickets t
WHERE t.id = m.ticket_id
  AND m.owner_user_id IS DISTINCT FROM t.user_id;

UPDATE public.client_conversation_messages m
SET client_id = c.client_id
FROM public.client_conversations c
WHERE c.id = m.conversation_id
  AND m.client_id IS DISTINCT FROM c.client_id;

UPDATE public.investor_conversation_messages m
SET investor_id = c.investor_id
FROM public.investor_conversations c
WHERE c.id = m.conversation_id
  AND m.investor_id IS DISTINCT FROM c.investor_id;

CREATE INDEX IF NOT EXISTS idx_ticket_messages_owner_created
  ON public.ticket_messages (owner_user_id, created_at DESC)
  WHERE owner_user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_client_messages_client_created
  ON public.client_conversation_messages (client_id, created_at DESC)
  WHERE client_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_investor_messages_investor_created
  ON public.investor_conversation_messages (investor_id, created_at DESC)
  WHERE investor_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.set_support_message_realtime_scope()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_TABLE_NAME = 'ticket_messages' THEN
    SELECT t.user_id INTO NEW.owner_user_id
    FROM public.tickets t
    WHERE t.id = NEW.ticket_id;
  ELSIF TG_TABLE_NAME = 'client_conversation_messages' THEN
    SELECT c.client_id INTO NEW.client_id
    FROM public.client_conversations c
    WHERE c.id = NEW.conversation_id;
  ELSIF TG_TABLE_NAME = 'investor_conversation_messages' THEN
    SELECT c.investor_id INTO NEW.investor_id
    FROM public.investor_conversations c
    WHERE c.id = NEW.conversation_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_ticket_messages_realtime_scope
  ON public.ticket_messages;
CREATE TRIGGER trg_ticket_messages_realtime_scope
BEFORE INSERT OR UPDATE OF ticket_id ON public.ticket_messages
FOR EACH ROW EXECUTE FUNCTION public.set_support_message_realtime_scope();

DROP TRIGGER IF EXISTS trg_client_messages_realtime_scope
  ON public.client_conversation_messages;
CREATE TRIGGER trg_client_messages_realtime_scope
BEFORE INSERT OR UPDATE OF conversation_id
ON public.client_conversation_messages
FOR EACH ROW EXECUTE FUNCTION public.set_support_message_realtime_scope();

DROP TRIGGER IF EXISTS trg_investor_messages_realtime_scope
  ON public.investor_conversation_messages;
CREATE TRIGGER trg_investor_messages_realtime_scope
BEFORE INSERT OR UPDATE OF conversation_id
ON public.investor_conversation_messages
FOR EACH ROW EXECUTE FUNCTION public.set_support_message_realtime_scope();

ALTER TABLE public.ticket_messages REPLICA IDENTITY FULL;
ALTER TABLE public.client_conversation_messages REPLICA IDENTITY FULL;
ALTER TABLE public.investor_conversation_messages REPLICA IDENTITY FULL;
