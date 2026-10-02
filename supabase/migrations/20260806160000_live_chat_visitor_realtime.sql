-- Visitor ↔ admin realtime live chat (public web widget + Support console).
-- Adds visitor_key, anon RPCs, and realtime on sessions.
-- Note: anon table SELECT is intentionally not granted; visitors use RPCs only
-- (see 20260806161000_live_chat_visitor_rpc_only.sql).

ALTER TABLE public.live_chat_sessions
  ADD COLUMN IF NOT EXISTS visitor_key text;

CREATE INDEX IF NOT EXISTS idx_live_chat_sessions_visitor_key
  ON public.live_chat_sessions (visitor_key)
  WHERE visitor_key IS NOT NULL AND status IN ('waiting', 'active', 'queued');

CREATE INDEX IF NOT EXISTS idx_live_chat_sessions_status
  ON public.live_chat_sessions (status, started_at DESC);

-- ---------------------------------------------------------------------------
-- RPCs (SECURITY DEFINER) — public visitors never get open table writes
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.live_chat_start(
  p_visitor_key text,
  p_customer_name text DEFAULT NULL,
  p_customer_email text DEFAULT NULL
)
RETURNS public.live_chat_sessions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_session public.live_chat_sessions;
  v_code text;
BEGIN
  IF p_visitor_key IS NULL OR length(trim(p_visitor_key)) < 12 THEN
    RAISE EXCEPTION 'visitor_key required';
  END IF;

  SELECT * INTO v_session
  FROM public.live_chat_sessions
  WHERE visitor_key = trim(p_visitor_key)
    AND status IN ('waiting', 'active', 'queued')
  ORDER BY started_at DESC
  LIMIT 1;

  IF FOUND THEN
    UPDATE public.live_chat_sessions
    SET
      customer_name = COALESCE(NULLIF(trim(p_customer_name), ''), customer_name),
      customer_email = COALESCE(NULLIF(trim(p_customer_email), ''), customer_email)
    WHERE id = v_session.id
    RETURNING * INTO v_session;
    RETURN v_session;
  END IF;

  v_code := 'LC-' || to_char(now(), 'YYYY') || '-' ||
            lpad((floor(random() * 9000) + 1000)::int::text, 4, '0');

  INSERT INTO public.live_chat_sessions (
    session_code,
    visitor_key,
    customer_name,
    customer_email,
    status,
    channel,
    metadata
  ) VALUES (
    v_code,
    trim(p_visitor_key),
    NULLIF(trim(COALESCE(p_customer_name, '')), ''),
    NULLIF(trim(COALESCE(p_customer_email, '')), ''),
    'waiting',
    'web',
    jsonb_build_object('source', 'public_widget')
  )
  RETURNING * INTO v_session;

  INSERT INTO public.live_chat_messages (
    session_id, sender_type, sender_name, body
  ) VALUES (
    v_session.id,
    'system',
    'HD Homes',
    'Thanks for chatting with HD Homes. An agent will be with you shortly.'
  );

  RETURN v_session;
END;
$$;

CREATE OR REPLACE FUNCTION public.live_chat_send_visitor(
  p_session_id uuid,
  p_visitor_key text,
  p_body text,
  p_sender_name text DEFAULT NULL
)
RETURNS public.live_chat_messages
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_session public.live_chat_sessions;
  v_msg public.live_chat_messages;
BEGIN
  IF p_body IS NULL OR length(trim(p_body)) = 0 THEN
    RAISE EXCEPTION 'message body required';
  END IF;

  SELECT * INTO v_session
  FROM public.live_chat_sessions
  WHERE id = p_session_id
    AND visitor_key = trim(p_visitor_key)
    AND status IN ('waiting', 'active', 'queued');

  IF NOT FOUND THEN
    RAISE EXCEPTION 'session not found or closed';
  END IF;

  INSERT INTO public.live_chat_messages (
    session_id, sender_type, sender_name, body, metadata
  ) VALUES (
    v_session.id,
    'customer',
    COALESCE(NULLIF(trim(COALESCE(p_sender_name, '')), ''), v_session.customer_name, 'Visitor'),
    trim(p_body),
    jsonb_build_object('visitor_key', trim(p_visitor_key))
  )
  RETURNING * INTO v_msg;

  RETURN v_msg;
END;
$$;

CREATE OR REPLACE FUNCTION public.live_chat_list_messages(
  p_session_id uuid,
  p_visitor_key text
)
RETURNS SETOF public.live_chat_messages
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.live_chat_sessions
    WHERE id = p_session_id AND visitor_key = trim(p_visitor_key)
  ) THEN
    RAISE EXCEPTION 'session not found';
  END IF;

  RETURN QUERY
  SELECT m.*
  FROM public.live_chat_messages m
  WHERE m.session_id = p_session_id
  ORDER BY m.created_at ASC;
END;
$$;

CREATE OR REPLACE FUNCTION public.live_chat_send_agent(
  p_session_id uuid,
  p_body text,
  p_sender_name text DEFAULT 'Agent'
)
RETURNS public.live_chat_messages
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_msg public.live_chat_messages;
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;

  IF NOT (
    public.has_permission('support.chat', v_uid)
    OR public.has_permission('support.write', v_uid)
    OR public.has_role('super_admin', v_uid)
  ) THEN
    RAISE EXCEPTION 'insufficient permissions';
  END IF;

  IF p_body IS NULL OR length(trim(p_body)) = 0 THEN
    RAISE EXCEPTION 'message body required';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.live_chat_sessions
    WHERE id = p_session_id AND status IN ('waiting', 'active', 'queued')
  ) THEN
    RAISE EXCEPTION 'session not found or closed';
  END IF;

  UPDATE public.live_chat_sessions
  SET status = CASE WHEN status = 'waiting' THEN 'active' ELSE status END
  WHERE id = p_session_id;

  INSERT INTO public.live_chat_messages (
    session_id, sender_type, sender_name, body
  ) VALUES (
    p_session_id,
    'agent',
    COALESCE(NULLIF(trim(COALESCE(p_sender_name, '')), ''), 'Agent'),
    trim(p_body)
  )
  RETURNING * INTO v_msg;

  RETURN v_msg;
END;
$$;

CREATE OR REPLACE FUNCTION public.live_chat_end_session(
  p_session_id uuid,
  p_visitor_key text DEFAULT NULL
)
RETURNS public.live_chat_sessions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_session public.live_chat_sessions;
  v_uid uuid := auth.uid();
  v_staff boolean := false;
BEGIN
  IF v_uid IS NOT NULL THEN
    v_staff := (
      public.has_permission('support.chat', v_uid)
      OR public.has_permission('support.write', v_uid)
      OR public.has_role('super_admin', v_uid)
    );
  END IF;

  IF v_staff THEN
    UPDATE public.live_chat_sessions
    SET status = 'ended', ended_at = now()
    WHERE id = p_session_id
    RETURNING * INTO v_session;
  ELSE
    IF p_visitor_key IS NULL THEN
      RAISE EXCEPTION 'visitor_key required';
    END IF;
    UPDATE public.live_chat_sessions
    SET status = 'ended', ended_at = now()
    WHERE id = p_session_id AND visitor_key = trim(p_visitor_key)
    RETURNING * INTO v_session;
  END IF;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'session not found';
  END IF;

  INSERT INTO public.live_chat_messages (
    session_id, sender_type, sender_name, body
  ) VALUES (
    p_session_id, 'system', 'HD Homes', 'This chat has ended. Thank you for contacting HD Homes.'
  );

  RETURN v_session;
END;
$$;

GRANT EXECUTE ON FUNCTION public.live_chat_start(text, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.live_chat_send_visitor(uuid, text, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.live_chat_list_messages(uuid, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.live_chat_send_agent(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.live_chat_end_session(uuid, text) TO anon, authenticated;

-- Visitors never get open table SELECT (privacy). Use RPCs only.
-- Admin/authenticated keep existing support.chat RLS policies.

-- Realtime: include sessions so admin sees new waiting chats instantly
DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.live_chat_sessions;
  EXCEPTION
    WHEN duplicate_object THEN NULL;
    WHEN undefined_object THEN NULL;
  END;
END $$;
