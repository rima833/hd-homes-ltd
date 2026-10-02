-- Push visitor live-chat updates via Realtime Broadcast (anon cannot SELECT rows).
CREATE OR REPLACE FUNCTION public.live_chat_broadcast_message()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  PERFORM realtime.send(
    jsonb_build_object(
      'op', TG_OP,
      'session_id', NEW.session_id,
      'message_id', NEW.id,
      'sender_type', NEW.sender_type
    ),
    'message',
    'live-chat:' || NEW.session_id::text,
    false
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_live_chat_broadcast_message ON public.live_chat_messages;
CREATE TRIGGER trg_live_chat_broadcast_message
  AFTER INSERT OR UPDATE ON public.live_chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION public.live_chat_broadcast_message();

CREATE OR REPLACE FUNCTION public.live_chat_broadcast_session()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  PERFORM realtime.send(
    jsonb_build_object(
      'op', TG_OP,
      'session_id', NEW.id,
      'status', NEW.status
    ),
    'session',
    'live-chat:' || NEW.id::text,
    false
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_live_chat_broadcast_session ON public.live_chat_sessions;
CREATE TRIGGER trg_live_chat_broadcast_session
  AFTER UPDATE ON public.live_chat_sessions
  FOR EACH ROW
  EXECUTE FUNCTION public.live_chat_broadcast_session();
