-- Live chat: visitor attachments + typing indicators.
-- Extends send_visitor for attachments; adds typing RPC; public live-chat storage.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'live-chat',
  'live-chat',
  true,
  20971520,
  ARRAY[
    'image/jpeg','image/png','image/webp','image/gif',
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'text/plain',
    'video/mp4','video/webm'
  ]
)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS live_chat_storage_read ON storage.objects;
CREATE POLICY live_chat_storage_read ON storage.objects
  FOR SELECT
  USING (bucket_id = 'live-chat');

DROP POLICY IF EXISTS live_chat_storage_visitor_upload ON storage.objects;
CREATE POLICY live_chat_storage_visitor_upload ON storage.objects
  FOR INSERT TO anon, authenticated
  WITH CHECK (
    bucket_id = 'live-chat'
    AND (storage.foldername(name))[1] = 'visitor'
  );

CREATE OR REPLACE FUNCTION public.live_chat_send_visitor(
  p_session_id uuid,
  p_visitor_key text,
  p_body text DEFAULT '',
  p_sender_name text DEFAULT NULL,
  p_attachments jsonb DEFAULT '[]'::jsonb,
  p_message_type text DEFAULT 'text'
)
RETURNS public.live_chat_messages
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_session public.live_chat_sessions;
  v_msg public.live_chat_messages;
  v_body text := trim(COALESCE(p_body, ''));
  v_attachments jsonb := COALESCE(p_attachments, '[]'::jsonb);
  v_type text := COALESCE(NULLIF(trim(p_message_type), ''), 'text');
BEGIN
  IF v_body = '' AND (jsonb_typeof(v_attachments) <> 'array' OR jsonb_array_length(v_attachments) = 0) THEN
    RAISE EXCEPTION 'message body or attachments required';
  END IF;

  IF v_body = '' THEN
    v_body := 'Shared a file';
    IF v_type = 'text' THEN
      v_type := 'file';
    END IF;
  END IF;

  SELECT * INTO v_session
  FROM public.live_chat_sessions
  WHERE id = p_session_id
    AND visitor_key = trim(p_visitor_key)
    AND status IN ('waiting', 'active', 'queued');

  IF NOT FOUND THEN
    RAISE EXCEPTION 'session not found or closed';
  END IF;

  -- Clear visitor typing on send.
  UPDATE public.live_chat_sessions
  SET metadata = COALESCE(metadata, '{}'::jsonb)
    || jsonb_build_object('visitor_typing_at', NULL)
  WHERE id = v_session.id;

  INSERT INTO public.live_chat_messages (
    session_id, sender_type, sender_name, body, message_type, attachments, metadata
  ) VALUES (
    v_session.id,
    'customer',
    COALESCE(NULLIF(trim(COALESCE(p_sender_name, '')), ''), v_session.customer_name, 'Visitor'),
    v_body,
    v_type,
    v_attachments,
    jsonb_build_object('visitor_key', trim(p_visitor_key))
  )
  RETURNING * INTO v_msg;

  RETURN v_msg;
END;
$$;

GRANT EXECUTE ON FUNCTION public.live_chat_send_visitor(uuid, text, text, text, jsonb, text)
  TO anon, authenticated;

-- Keep older 4-arg signature callable (Postgres overloads).
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
BEGIN
  RETURN public.live_chat_send_visitor(
    p_session_id,
    p_visitor_key,
    p_body,
    p_sender_name,
    '[]'::jsonb,
    'text'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.live_chat_send_visitor(uuid, text, text, text)
  TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.live_chat_set_typing(
  p_session_id uuid,
  p_visitor_key text,
  p_is_typing boolean,
  p_actor text DEFAULT 'visitor'
)
RETURNS public.live_chat_sessions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_session public.live_chat_sessions;
  v_actor text := lower(trim(COALESCE(p_actor, 'visitor')));
  v_key text;
  v_value jsonb;
BEGIN
  IF v_actor NOT IN ('visitor', 'agent') THEN
    v_actor := 'visitor';
  END IF;
  v_key := v_actor || '_typing_at';
  v_value := CASE
    WHEN COALESCE(p_is_typing, false) THEN to_jsonb(now())
    ELSE 'null'::jsonb
  END;

  IF v_actor = 'visitor' THEN
    SELECT * INTO v_session
    FROM public.live_chat_sessions
    WHERE id = p_session_id
      AND visitor_key = trim(p_visitor_key)
      AND status IN ('waiting', 'active', 'queued');
    IF NOT FOUND THEN
      RAISE EXCEPTION 'session not found or closed';
    END IF;
  ELSE
    -- Agents must be authenticated staff.
    IF auth.uid() IS NULL THEN
      RAISE EXCEPTION 'authentication required';
    END IF;
    SELECT * INTO v_session
    FROM public.live_chat_sessions
    WHERE id = p_session_id
      AND status IN ('waiting', 'active', 'queued');
    IF NOT FOUND THEN
      RAISE EXCEPTION 'session not found or closed';
    END IF;
  END IF;

  UPDATE public.live_chat_sessions
  SET metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(v_key, v_value)
  WHERE id = v_session.id
  RETURNING * INTO v_session;

  RETURN v_session;
END;
$$;

GRANT EXECUTE ON FUNCTION public.live_chat_set_typing(uuid, text, boolean, text)
  TO anon, authenticated;
