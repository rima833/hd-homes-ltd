-- Staff live-chat attachments: storage path `agent/` + send_agent overload.

DROP POLICY IF EXISTS live_chat_storage_agent_upload ON storage.objects;
CREATE POLICY live_chat_storage_agent_upload ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'live-chat'
    AND (storage.foldername(name))[1] = 'agent'
    AND (
      public.has_permission('support.chat', auth.uid())
      OR public.has_permission('support.write', auth.uid())
      OR public.has_role('super_admin', auth.uid())
    )
  );

CREATE OR REPLACE FUNCTION public.live_chat_send_agent(
  p_session_id uuid,
  p_body text,
  p_sender_name text,
  p_attachments jsonb,
  p_message_type text
)
RETURNS public.live_chat_messages
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_msg public.live_chat_messages;
  v_uid uuid := auth.uid();
  v_body text := trim(COALESCE(p_body, ''));
  v_attachments jsonb := COALESCE(p_attachments, '[]'::jsonb);
  v_type text := COALESCE(NULLIF(trim(p_message_type), ''), 'text');
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

  IF v_body = '' AND (jsonb_typeof(v_attachments) <> 'array' OR jsonb_array_length(v_attachments) = 0) THEN
    RAISE EXCEPTION 'message body or attachments required';
  END IF;

  IF v_body = '' THEN
    v_body := 'Shared a file';
    IF v_type = 'text' THEN
      v_type := 'file';
    END IF;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.live_chat_sessions
    WHERE id = p_session_id AND status IN ('waiting', 'active', 'queued')
  ) THEN
    RAISE EXCEPTION 'session not found or closed';
  END IF;

  UPDATE public.live_chat_sessions
  SET
    status = CASE WHEN status = 'waiting' THEN 'active' ELSE status END,
    metadata = COALESCE(metadata, '{}'::jsonb)
      || jsonb_build_object('agent_typing_at', NULL)
  WHERE id = p_session_id;

  INSERT INTO public.live_chat_messages (
    session_id, sender_type, sender_name, body, message_type, attachments
  ) VALUES (
    p_session_id,
    'agent',
    COALESCE(NULLIF(trim(COALESCE(p_sender_name, '')), ''), 'Agent'),
    v_body,
    v_type,
    v_attachments
  )
  RETURNING * INTO v_msg;

  RETURN v_msg;
END;
$$;

GRANT EXECUTE ON FUNCTION public.live_chat_send_agent(uuid, text, text, jsonb, text)
  TO authenticated;

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
BEGIN
  RETURN public.live_chat_send_agent(
    p_session_id,
    p_body,
    p_sender_name,
    '[]'::jsonb,
    'text'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.live_chat_send_agent(uuid, text, text)
  TO authenticated;
