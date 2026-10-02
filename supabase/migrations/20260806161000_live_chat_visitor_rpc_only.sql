-- Tighten visitor live chat: remove broad anon SELECT (privacy).
-- Visitors use SECURITY DEFINER RPCs; optional poll for new messages.

DROP POLICY IF EXISTS live_chat_messages_anon_select ON public.live_chat_messages;
DROP POLICY IF EXISTS live_chat_sessions_anon_select ON public.live_chat_sessions;

REVOKE SELECT ON public.live_chat_messages FROM anon;
REVOKE SELECT ON public.live_chat_sessions FROM anon;

CREATE OR REPLACE FUNCTION public.live_chat_get_session(
  p_session_id uuid,
  p_visitor_key text
)
RETURNS public.live_chat_sessions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_session public.live_chat_sessions;
BEGIN
  SELECT * INTO v_session
  FROM public.live_chat_sessions
  WHERE id = p_session_id
    AND visitor_key = trim(p_visitor_key);

  IF NOT FOUND THEN
    RAISE EXCEPTION 'session not found';
  END IF;

  RETURN v_session;
END;
$$;

GRANT EXECUTE ON FUNCTION public.live_chat_get_session(uuid, text) TO anon, authenticated;
