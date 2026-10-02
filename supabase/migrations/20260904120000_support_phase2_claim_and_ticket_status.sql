-- Support Phase 2: live chat claim/assign + auto-claim on agent reply,
-- ticket status slug aliases, unique support_agents.profile_id.

-- ---------------------------------------------------------------------------
-- Agents: one row per staff profile
-- ---------------------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS support_agents_profile_id_uidx
  ON public.support_agents (profile_id)
  WHERE profile_id IS NOT NULL;

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

  SELECT id INTO v_agent_id
  FROM public.support_agents
  WHERE profile_id = v_uid
  LIMIT 1;

  IF v_agent_id IS NOT NULL THEN
    UPDATE public.support_agents
    SET status = 'available',
        is_active = true,
        updated_at = now()
    WHERE id = v_agent_id;
    RETURN v_agent_id;
  END IF;

  SELECT
    COALESCE(NULLIF(trim(full_name), ''), NULLIF(trim(email), ''), 'Agent'),
    email
  INTO v_name, v_email
  FROM public.profiles
  WHERE id = v_uid;

  INSERT INTO public.support_agents (
    profile_id, display_name, email, role_title, status, is_active, metadata
  ) VALUES (
    v_uid,
    COALESCE(v_name, 'Agent'),
    v_email,
    'Agent',
    'available',
    true,
    jsonb_build_object('source', 'auto_ensure')
  )
  RETURNING id INTO v_agent_id;

  RETURN v_agent_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.ensure_my_support_agent() TO authenticated;

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

  IF NOT (
    public.has_permission('support.chat', v_uid)
    OR public.has_permission('support.write', v_uid)
    OR public.has_role('super_admin', v_uid)
  ) THEN
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

GRANT EXECUTE ON FUNCTION public.live_chat_claim_session(uuid) TO authenticated;

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

  IF NOT (
    public.has_permission('support.chat', v_uid)
    OR public.has_permission('support.write', v_uid)
    OR public.has_role('super_admin', v_uid)
  ) THEN
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

GRANT EXECUTE ON FUNCTION public.live_chat_assign_session(uuid, uuid) TO authenticated;

-- Auto-claim on first agent reply (attachments overload).
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
  v_agent_id uuid;
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

  v_agent_id := public.ensure_my_support_agent();

  UPDATE public.live_chat_sessions
  SET
    agent_id = COALESCE(agent_id, v_agent_id),
    status = CASE WHEN status IN ('waiting', 'queued') THEN 'active' ELSE status END,
    metadata = COALESCE(metadata, '{}'::jsonb)
      || jsonb_build_object('agent_typing_at', NULL),
    updated_at = now()
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

-- Ticket status: accept both waiting_for_customer and pending_customer.
CREATE OR REPLACE FUNCTION public.admin_update_website_ticket(
  p_ticket_id uuid,
  p_status text DEFAULT NULL,
  p_priority text DEFAULT NULL,
  p_assigned_to uuid DEFAULT NULL,
  p_admin_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_row public.tickets%ROWTYPE;
  v_status text := p_status;
BEGIN
  IF NOT (
    public.has_permission('support.tickets', v_uid)
    OR public.has_permission('support.write', v_uid)
    OR public.has_permission('manage_tickets', v_uid)
    OR public.has_role('super_admin', v_uid)
    OR public.is_staff()
  ) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT * INTO v_row FROM public.tickets WHERE id = p_ticket_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ticket not found'; END IF;

  IF v_status = 'pending_customer' THEN
    v_status := 'waiting_for_customer';
  END IF;

  IF v_status IS NOT NULL AND v_status NOT IN (
    'new','open','in_progress','waiting_for_customer','resolved','closed','escalated'
  ) THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  IF p_priority IS NOT NULL AND p_priority NOT IN ('low','normal','high','urgent') THEN
    RAISE EXCEPTION 'invalid priority';
  END IF;

  UPDATE public.tickets
  SET status = COALESCE(v_status, status),
      priority = COALESCE(p_priority, priority),
      assigned_to = COALESCE(p_assigned_to, assigned_to),
      first_response_at = CASE
        WHEN first_response_at IS NULL AND v_status IN ('in_progress', 'waiting_for_customer')
          THEN now()
        ELSE first_response_at
      END,
      resolved_at = CASE WHEN COALESCE(v_status, status) = 'resolved' THEN COALESCE(resolved_at, now()) ELSE resolved_at END,
      closed_at = CASE WHEN COALESCE(v_status, status) = 'closed' THEN COALESCE(closed_at, now()) ELSE closed_at END,
      metadata = CASE
        WHEN p_admin_notes IS NOT NULL THEN
          COALESCE(metadata, '{}'::jsonb) || jsonb_build_object('admin_notes', p_admin_notes)
        ELSE metadata
      END,
      updated_at = now(),
      updated_by = v_uid
  WHERE id = p_ticket_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;
