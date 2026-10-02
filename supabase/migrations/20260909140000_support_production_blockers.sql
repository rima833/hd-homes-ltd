-- Support production blockers:
-- * align support-agent identity with the canonical profiles schema
-- * remove ambiguous legacy live-chat RPC overloads
-- * remove PUBLIC/anon execution from staff-only RPCs

CREATE OR REPLACE FUNCTION public.ensure_my_support_agent()
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_agent_id uuid;
  v_name text;
  v_email text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;

  IF NOT (
    public.has_permission('support.chat', v_uid)
    OR public.has_permission('support.write', v_uid)
    OR public.has_permission('support.tickets', v_uid)
    OR public.has_role('super_admin', v_uid)
  ) THEN
    RAISE EXCEPTION 'insufficient permissions';
  END IF;

  SELECT
    COALESCE(
      NULLIF(btrim(p.preferred_name), ''),
      NULLIF(btrim(concat_ws(' ', p.first_name, p.last_name)), ''),
      NULLIF(btrim(p.email), ''),
      'Agent'
    ),
    p.email
  INTO v_name, v_email
  FROM public.profiles p
  WHERE p.id = v_uid
    AND COALESCE(p.is_deleted, false) = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'active profile required';
  END IF;

  SELECT a.id
  INTO v_agent_id
  FROM public.support_agents a
  WHERE a.profile_id = v_uid
  LIMIT 1;

  IF v_agent_id IS NOT NULL THEN
    UPDATE public.support_agents
    SET display_name = v_name,
        email = v_email,
        is_active = true,
        updated_at = now()
    WHERE id = v_agent_id;
    RETURN v_agent_id;
  END IF;

  INSERT INTO public.support_agents (
    profile_id,
    display_name,
    email,
    role_title,
    status,
    is_active,
    metadata,
    last_seen_at
  )
  VALUES (
    v_uid,
    v_name,
    v_email,
    'Agent',
    'offline',
    true,
    jsonb_build_object('source', 'auto_ensure'),
    NULL
  )
  RETURNING id INTO v_agent_id;

  RETURN v_agent_id;
END;
$$;

UPDATE public.support_agents a
SET display_name = COALESCE(
      NULLIF(btrim(p.preferred_name), ''),
      NULLIF(btrim(concat_ws(' ', p.first_name, p.last_name)), ''),
      NULLIF(btrim(p.email), ''),
      a.display_name
    ),
    email = COALESCE(NULLIF(btrim(p.email), ''), a.email),
    updated_at = now()
FROM public.profiles p
WHERE a.profile_id = p.id
  AND COALESCE(p.is_deleted, false) = false
  AND (
    a.display_name IS DISTINCT FROM COALESCE(
      NULLIF(btrim(p.preferred_name), ''),
      NULLIF(btrim(concat_ws(' ', p.first_name, p.last_name)), ''),
      NULLIF(btrim(p.email), ''),
      a.display_name
    )
    OR a.email IS DISTINCT FROM COALESCE(NULLIF(btrim(p.email), ''), a.email)
  );

-- Replace overlapping overloads with one defaulted canonical signature.
DROP FUNCTION IF EXISTS public.live_chat_send_visitor(uuid, text, text, text);
DROP FUNCTION IF EXISTS public.live_chat_send_visitor(uuid, text, text, text, jsonb, text);

CREATE FUNCTION public.live_chat_send_visitor(
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
  v_body text := btrim(COALESCE(p_body, ''));
  v_key text := btrim(COALESCE(p_visitor_key, ''));
  v_attachments jsonb := COALESCE(p_attachments, '[]'::jsonb);
  v_type text := lower(COALESCE(NULLIF(btrim(p_message_type), ''), 'text'));
BEGIN
  IF length(v_key) < 12 THEN
    RAISE EXCEPTION 'visitor_key required';
  END IF;
  IF jsonb_typeof(v_attachments) <> 'array' THEN
    RAISE EXCEPTION 'attachments must be an array';
  END IF;
  IF jsonb_array_length(v_attachments) > 10 THEN
    RAISE EXCEPTION 'too many attachments';
  END IF;
  IF v_type NOT IN ('text', 'image', 'video', 'file') THEN
    RAISE EXCEPTION 'invalid message type';
  END IF;
  IF v_body = '' AND jsonb_array_length(v_attachments) = 0 THEN
    RAISE EXCEPTION 'message body or attachments required';
  END IF;

  IF v_body = '' THEN
    v_body := 'Shared a file';
    IF v_type = 'text' THEN
      v_type := 'file';
    END IF;
  END IF;

  SELECT *
  INTO v_session
  FROM public.live_chat_sessions
  WHERE id = p_session_id
    AND visitor_key = v_key
    AND status IN ('waiting', 'active', 'queued')
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'session not found or closed';
  END IF;

  UPDATE public.live_chat_sessions
  SET metadata = COALESCE(metadata, '{}'::jsonb)
      || jsonb_build_object('visitor_typing_at', NULL),
      updated_at = now()
  WHERE id = v_session.id;

  INSERT INTO public.live_chat_messages (
    session_id,
    sender_type,
    sender_name,
    body,
    message_type,
    attachments,
    metadata
  )
  VALUES (
    v_session.id,
    'customer',
    COALESCE(NULLIF(btrim(COALESCE(p_sender_name, '')), ''), v_session.customer_name, 'Visitor'),
    v_body,
    v_type,
    v_attachments,
    jsonb_build_object('visitor_key', v_key)
  )
  RETURNING * INTO v_msg;

  RETURN v_msg;
END;
$$;

DROP FUNCTION IF EXISTS public.live_chat_send_agent(uuid, text, text);
DROP FUNCTION IF EXISTS public.live_chat_send_agent(uuid, text, text, jsonb, text);

CREATE FUNCTION public.live_chat_send_agent(
  p_session_id uuid,
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
  v_uid uuid := auth.uid();
  v_msg public.live_chat_messages;
  v_body text := btrim(COALESCE(p_body, ''));
  v_attachments jsonb := COALESCE(p_attachments, '[]'::jsonb);
  v_type text := lower(COALESCE(NULLIF(btrim(p_message_type), ''), 'text'));
  v_agent_id uuid;
  v_agent_name text;
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
  IF jsonb_typeof(v_attachments) <> 'array' THEN
    RAISE EXCEPTION 'attachments must be an array';
  END IF;
  IF jsonb_array_length(v_attachments) > 10 THEN
    RAISE EXCEPTION 'too many attachments';
  END IF;
  IF v_type NOT IN ('text', 'image', 'video', 'file') THEN
    RAISE EXCEPTION 'invalid message type';
  END IF;
  IF v_body = '' AND jsonb_array_length(v_attachments) = 0 THEN
    RAISE EXCEPTION 'message body or attachments required';
  END IF;

  IF v_body = '' THEN
    v_body := 'Shared a file';
    IF v_type = 'text' THEN
      v_type := 'file';
    END IF;
  END IF;

  v_agent_id := public.ensure_my_support_agent();

  SELECT display_name
  INTO v_agent_name
  FROM public.support_agents
  WHERE id = v_agent_id;

  PERFORM 1
  FROM public.live_chat_sessions
  WHERE id = p_session_id
    AND status IN ('waiting', 'active', 'queued')
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'session not found or closed';
  END IF;

  UPDATE public.live_chat_sessions
  SET agent_id = COALESCE(agent_id, v_agent_id),
      status = CASE
        WHEN status IN ('waiting', 'queued') THEN 'active'
        ELSE status
      END,
      metadata = COALESCE(metadata, '{}'::jsonb)
        || jsonb_build_object('agent_typing_at', NULL),
      updated_at = now()
  WHERE id = p_session_id;

  INSERT INTO public.live_chat_messages (
    session_id,
    sender_type,
    sender_name,
    body,
    message_type,
    attachments
  )
  VALUES (
    p_session_id,
    'agent',
    COALESCE(NULLIF(btrim(v_agent_name), ''), 'Agent'),
    v_body,
    v_type,
    v_attachments
  )
  RETURNING * INTO v_msg;

  RETURN v_msg;
END;
$$;

REVOKE ALL ON FUNCTION public.ensure_my_support_agent() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.live_chat_send_agent(uuid, text, text, jsonb, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.live_chat_claim_session(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.live_chat_assign_session(uuid, uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.set_my_support_agent_presence(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.heartbeat_my_support_agent() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.ensure_my_support_agent() TO authenticated;
GRANT EXECUTE ON FUNCTION public.live_chat_send_agent(uuid, text, text, jsonb, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.live_chat_claim_session(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.live_chat_assign_session(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_my_support_agent_presence(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.heartbeat_my_support_agent() TO authenticated;

REVOKE ALL ON FUNCTION public.live_chat_send_visitor(uuid, text, text, text, jsonb, text)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.live_chat_send_visitor(uuid, text, text, text, jsonb, text)
  TO anon, authenticated;
