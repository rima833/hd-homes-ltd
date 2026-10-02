-- Staff desks that can open Support / Live Chat must be able to reply.
-- The previous gate only allowed support.chat, support.write, or super_admin,
-- so construction, finance, and marketing could read chats and then fail to send.

CREATE OR REPLACE FUNCTION public.can_operate_support_desk(
  target_user_id uuid DEFAULT auth.uid()
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT target_user_id IS NOT NULL
    AND (
      public.is_staff(target_user_id)
      OR public.has_permission('support.chat', target_user_id)
      OR public.has_permission('support.write', target_user_id)
      OR public.has_permission('support.tickets', target_user_id)
      OR public.has_permission('manage_tickets', target_user_id)
    );
$$;

REVOKE ALL ON FUNCTION public.can_operate_support_desk(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_operate_support_desk(uuid) TO authenticated, service_role;

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

  IF NOT public.can_operate_support_desk(v_uid) THEN
    RAISE EXCEPTION 'insufficient permissions';
  END IF;

  SELECT
    COALESCE(
      NULLIF(btrim(concat_ws(' ', p.first_name, p.last_name)), ''),
      NULLIF(btrim(p.preferred_name), ''),
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
      NULLIF(btrim(concat_ws(' ', p.first_name, p.last_name)), ''),
      NULLIF(btrim(p.preferred_name), ''),
      NULLIF(btrim(p.email), ''),
      a.display_name
    ),
    updated_at = now()
FROM public.profiles p
WHERE a.profile_id = p.id
  AND COALESCE(p.is_deleted, false) = false
  AND a.display_name IS DISTINCT FROM COALESCE(
      NULLIF(btrim(concat_ws(' ', p.first_name, p.last_name)), ''),
      NULLIF(btrim(p.preferred_name), ''),
      NULLIF(btrim(p.email), ''),
      a.display_name
    );

CREATE OR REPLACE FUNCTION public.live_chat_send_agent(
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
  IF NOT public.can_operate_support_desk(v_uid) THEN
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

  v_agent_name := COALESCE(
    NULLIF(btrim(COALESCE(p_sender_name, '')), ''),
    NULLIF(btrim(COALESCE(v_agent_name, '')), ''),
    'Agent'
  );

  IF NULLIF(btrim(COALESCE(p_sender_name, '')), '') IS NOT NULL THEN
    UPDATE public.support_agents
    SET display_name = btrim(p_sender_name),
        updated_at = now()
    WHERE id = v_agent_id;
  END IF;

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
    v_agent_name,
    v_body,
    v_type,
    v_attachments
  )
  RETURNING * INTO v_msg;

  RETURN v_msg;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_my_support_agent_presence(p_status text)
RETURNS public.support_agents
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_agent_id uuid;
  v_status text := lower(trim(COALESCE(p_status, 'available')));
  v_row public.support_agents;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;

  IF v_status NOT IN ('available', 'busy', 'away', 'offline') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;

  IF NOT public.can_operate_support_desk(v_uid) THEN
    RAISE EXCEPTION 'insufficient permissions for support presence';
  END IF;

  v_agent_id := public.ensure_my_support_agent();

  UPDATE public.support_agents
  SET
    status = v_status,
    last_seen_at = CASE
      WHEN v_status IN ('available', 'busy') THEN now()
      ELSE last_seen_at
    END,
    updated_at = now()
  WHERE id = v_agent_id
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.heartbeat_my_support_agent()
RETURNS public.support_agents
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_agent_id uuid;
  v_row public.support_agents;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;

  IF NOT public.can_operate_support_desk(v_uid) THEN
    RAISE EXCEPTION 'insufficient permissions for support presence';
  END IF;

  v_agent_id := public.ensure_my_support_agent();

  UPDATE public.support_agents
  SET
    status = CASE
      WHEN status IN ('offline', 'away') THEN 'available'
      ELSE status
    END,
    last_seen_at = now(),
    updated_at = now()
  WHERE id = v_agent_id
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.live_chat_claim_session(p_session_id uuid)
RETURNS public.live_chat_sessions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_agent_id uuid;
  v_row public.live_chat_sessions;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;

  IF NOT public.can_operate_support_desk(v_uid) THEN
    RAISE EXCEPTION 'insufficient permissions';
  END IF;

  v_agent_id := public.ensure_my_support_agent();

  SELECT * INTO v_row
  FROM public.live_chat_sessions
  WHERE id = p_session_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'session not found';
  END IF;

  IF v_row.status NOT IN ('waiting', 'active', 'queued') THEN
    RAISE EXCEPTION 'session closed';
  END IF;

  IF v_row.agent_id IS NOT NULL AND v_row.agent_id <> v_agent_id THEN
    RAISE EXCEPTION 'session already claimed';
  END IF;

  UPDATE public.live_chat_sessions
  SET
    agent_id = v_agent_id,
    status = CASE WHEN status IN ('waiting', 'queued') THEN 'active' ELSE status END,
    metadata = COALESCE(metadata, '{}'::jsonb)
      || jsonb_build_object(
        'claimed_by', v_uid,
        'claimed_at', now()
      ),
    updated_at = now()
  WHERE id = p_session_id
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.live_chat_assign_session(
  p_session_id uuid,
  p_agent_id uuid
)
RETURNS public.live_chat_sessions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_row public.live_chat_sessions;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;

  IF NOT public.can_operate_support_desk(v_uid) THEN
    RAISE EXCEPTION 'insufficient permissions';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.support_agents
    WHERE id = p_agent_id AND is_active = true
  ) THEN
    RAISE EXCEPTION 'agent not found';
  END IF;

  UPDATE public.live_chat_sessions
  SET
    agent_id = p_agent_id,
    status = CASE WHEN status IN ('waiting', 'queued') THEN 'active' ELSE status END,
    metadata = COALESCE(metadata, '{}'::jsonb)
      || jsonb_build_object(
        'assigned_by', v_uid,
        'assigned_at', now()
      ),
    updated_at = now()
  WHERE id = p_session_id
    AND status IN ('waiting', 'active', 'queued')
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'session not found or closed';
  END IF;

  RETURN v_row;
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
    v_staff := public.can_operate_support_desk(v_uid);
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

DROP POLICY IF EXISTS live_chat_messages_write ON public.live_chat_messages;
CREATE POLICY live_chat_messages_write ON public.live_chat_messages
  FOR ALL
  USING (public.can_operate_support_desk(auth.uid()))
  WITH CHECK (public.can_operate_support_desk(auth.uid()));

DROP POLICY IF EXISTS live_chat_sessions_write ON public.live_chat_sessions;
CREATE POLICY live_chat_sessions_write ON public.live_chat_sessions
  FOR ALL
  USING (public.can_operate_support_desk(auth.uid()))
  WITH CHECK (public.can_operate_support_desk(auth.uid()));

DROP POLICY IF EXISTS live_chat_storage_agent_upload ON storage.objects;
CREATE POLICY live_chat_storage_agent_upload ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'live-chat'
    AND (storage.foldername(name))[1] = 'agent'
    AND public.can_operate_support_desk(auth.uid())
  );
