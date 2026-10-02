-- Support channel write hardening:
-- * revoke anonymous grants on messaging tables
-- * keep unread counters authoritative on parent rows
-- * expose atomic send/mark-read RPCs for portal + ticket channels
-- * tighten ticket message mutation policies

BEGIN;

-- ---------------------------------------------------------------------------
-- Grants: messaging tables are never public.
-- ---------------------------------------------------------------------------
REVOKE ALL ON TABLE public.client_conversations FROM anon;
REVOKE ALL ON TABLE public.client_conversation_messages FROM anon;
REVOKE ALL ON TABLE public.investor_conversations FROM anon;
REVOKE ALL ON TABLE public.investor_conversation_messages FROM anon;
REVOKE ALL ON TABLE public.ticket_messages FROM anon;
REVOKE ALL ON TABLE public.live_chat_sessions FROM anon;
REVOKE ALL ON TABLE public.live_chat_messages FROM anon;

ALTER TABLE public.client_conversations
  ADD COLUMN IF NOT EXISTS client_unread_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS staff_unread_count integer NOT NULL DEFAULT 0;

CREATE OR REPLACE FUNCTION public.client_conversation_on_message()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_owner uuid;
  v_from_client boolean := false;
BEGIN
  SELECT c.user_id
  INTO v_owner
  FROM public.client_conversations cc
  JOIN public.clients c ON c.id = cc.client_id
  WHERE cc.id = NEW.conversation_id;

  v_from_client := (v_owner IS NOT NULL AND NEW.sender_id = v_owner);

  UPDATE public.client_conversations
  SET
    last_message_at = NEW.created_at,
    last_message_preview = left(NEW.body, 120),
    client_unread_count = client_unread_count + CASE WHEN v_from_client THEN 0 ELSE 1 END,
    staff_unread_count = staff_unread_count + CASE WHEN v_from_client THEN 1 ELSE 0 END,
    updated_at = now()
  WHERE id = NEW.conversation_id;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.client_conversation_mark_read(
  p_conversation_id uuid
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_client_id uuid;
  v_count integer;
  v_is_owner boolean;
  v_is_staff boolean;
BEGIN
  SELECT client_id INTO v_client_id
  FROM public.client_conversations
  WHERE id = p_conversation_id AND is_deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'conversation not found';
  END IF;

  v_is_owner := v_client_id IS NOT DISTINCT FROM public.client_id_for_user(auth.uid());
  v_is_staff := public.is_staff(auth.uid());

  IF NOT v_is_owner AND NOT v_is_staff THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  UPDATE public.client_conversation_messages
  SET read_at = now(),
      delivery_status = 'read',
      updated_at = now()
  WHERE conversation_id = p_conversation_id
    AND is_deleted = false
    AND read_at IS NULL
    AND sender_id IS DISTINCT FROM auth.uid();

  GET DIAGNOSTICS v_count = ROW_COUNT;

  UPDATE public.client_conversations
  SET
    client_unread_count = CASE WHEN v_is_owner THEN 0 ELSE client_unread_count END,
    staff_unread_count = CASE WHEN v_is_staff AND NOT v_is_owner THEN 0 ELSE staff_unread_count END,
    updated_at = now()
  WHERE id = p_conversation_id;

  RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.client_conversation_send_message(
  p_conversation_id uuid,
  p_body text,
  p_attachments jsonb DEFAULT '[]'::jsonb,
  p_client_message_id text DEFAULT NULL
)
RETURNS public.client_conversation_messages
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_conv public.client_conversations;
  v_msg public.client_conversation_messages;
  v_body text := btrim(COALESCE(p_body, ''));
  v_attachments jsonb := COALESCE(p_attachments, '[]'::jsonb);
  v_is_owner boolean;
  v_is_staff boolean;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;
  IF jsonb_typeof(v_attachments) <> 'array' THEN
    RAISE EXCEPTION 'attachments must be an array';
  END IF;
  IF v_body = '' AND jsonb_array_length(v_attachments) = 0 THEN
    RAISE EXCEPTION 'message body or attachments required';
  END IF;
  IF v_body = '' THEN
    v_body := 'Shared a file';
  END IF;

  SELECT * INTO v_conv
  FROM public.client_conversations
  WHERE id = p_conversation_id
    AND is_deleted = false
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'conversation not found';
  END IF;
  IF v_conv.status <> 'open' THEN
    RAISE EXCEPTION 'conversation is closed';
  END IF;

  v_is_owner := v_conv.client_id IS NOT DISTINCT FROM public.client_id_for_user(v_uid);
  v_is_staff := public.is_staff(v_uid);
  IF NOT v_is_owner AND NOT v_is_staff THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  IF p_client_message_id IS NOT NULL THEN
    SELECT *
    INTO v_msg
    FROM public.client_conversation_messages
    WHERE conversation_id = p_conversation_id
      AND client_message_id = p_client_message_id
    LIMIT 1;
    IF FOUND THEN
      RETURN v_msg;
    END IF;
  END IF;

  INSERT INTO public.client_conversation_messages (
    conversation_id,
    sender_id,
    body,
    attachments,
    client_message_id,
    created_by
  )
  VALUES (
    p_conversation_id,
    v_uid,
    v_body,
    v_attachments,
    NULLIF(btrim(COALESCE(p_client_message_id, '')), ''),
    v_uid
  )
  RETURNING * INTO v_msg;

  UPDATE public.client_conversations
  SET metadata = COALESCE(metadata, '{}'::jsonb)
      || jsonb_build_object(
        CASE WHEN v_is_owner THEN 'client_typing_at' ELSE 'staff_typing_at' END,
        NULL
      ),
      updated_at = now()
  WHERE id = p_conversation_id;

  RETURN v_msg;
END;
$$;

CREATE OR REPLACE FUNCTION public.investor_conversation_send_message(
  p_conversation_id uuid,
  p_body text,
  p_attachments jsonb DEFAULT '[]'::jsonb,
  p_client_message_id text DEFAULT NULL
)
RETURNS public.investor_conversation_messages
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_conv public.investor_conversations;
  v_msg public.investor_conversation_messages;
  v_body text := btrim(COALESCE(p_body, ''));
  v_attachments jsonb := COALESCE(p_attachments, '[]'::jsonb);
  v_is_owner boolean;
  v_is_staff boolean;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;
  IF jsonb_typeof(v_attachments) <> 'array' THEN
    RAISE EXCEPTION 'attachments must be an array';
  END IF;
  IF v_body = '' AND jsonb_array_length(v_attachments) = 0 THEN
    RAISE EXCEPTION 'message body or attachments required';
  END IF;
  IF v_body = '' THEN
    v_body := 'Shared a file';
  END IF;

  SELECT * INTO v_conv
  FROM public.investor_conversations
  WHERE id = p_conversation_id
    AND COALESCE(is_deleted, false) = false
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'conversation not found';
  END IF;
  IF v_conv.status <> 'open' THEN
    RAISE EXCEPTION 'conversation is closed';
  END IF;

  v_is_owner := v_conv.investor_id IS NOT DISTINCT FROM public.investor_id_for_user(v_uid);
  v_is_staff := public.has_permission('investors.communicate', v_uid)
    OR public.has_role('super_admin', v_uid);
  IF NOT v_is_owner AND NOT v_is_staff THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  IF p_client_message_id IS NOT NULL THEN
    SELECT *
    INTO v_msg
    FROM public.investor_conversation_messages
    WHERE conversation_id = p_conversation_id
      AND client_message_id = p_client_message_id
    LIMIT 1;
    IF FOUND THEN
      RETURN v_msg;
    END IF;
  END IF;

  INSERT INTO public.investor_conversation_messages (
    conversation_id,
    sender_id,
    body,
    attachments,
    client_message_id,
    created_by
  )
  VALUES (
    p_conversation_id,
    v_uid,
    v_body,
    v_attachments,
    NULLIF(btrim(COALESCE(p_client_message_id, '')), ''),
    v_uid
  )
  RETURNING * INTO v_msg;

  RETURN v_msg;
END;
$$;

CREATE OR REPLACE FUNCTION public.investor_conversation_mark_read(
  p_conversation_id uuid
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_investor_id uuid;
  v_count integer;
  v_is_owner boolean;
  v_is_staff boolean;
BEGIN
  SELECT investor_id INTO v_investor_id
  FROM public.investor_conversations
  WHERE id = p_conversation_id
    AND COALESCE(is_deleted, false) = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'conversation not found';
  END IF;

  v_is_owner := v_investor_id IS NOT DISTINCT FROM public.investor_id_for_user(auth.uid());
  v_is_staff := public.has_permission('investors.communicate', auth.uid())
    OR public.has_role('super_admin', auth.uid());

  IF NOT v_is_owner AND NOT v_is_staff THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  UPDATE public.investor_conversation_messages
  SET read_at = now(),
      delivery_status = 'read',
      updated_at = now()
  WHERE conversation_id = p_conversation_id
    AND COALESCE(is_deleted, false) = false
    AND read_at IS NULL
    AND sender_id IS DISTINCT FROM auth.uid();

  GET DIAGNOSTICS v_count = ROW_COUNT;

  UPDATE public.investor_conversations
  SET
    investor_unread_count = CASE WHEN v_is_owner THEN 0 ELSE investor_unread_count END,
    staff_unread_count = CASE WHEN v_is_staff AND NOT v_is_owner THEN 0 ELSE staff_unread_count END,
    updated_at = now()
  WHERE id = p_conversation_id;

  RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.support_ticket_send_message(
  p_ticket_id uuid,
  p_message text,
  p_is_internal boolean DEFAULT false,
  p_attachments jsonb DEFAULT '[]'::jsonb,
  p_channel text DEFAULT NULL,
  p_message_type text DEFAULT NULL,
  p_sender_name text DEFAULT NULL,
  p_client_message_id text DEFAULT NULL
)
RETURNS public.ticket_messages
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_ticket public.tickets;
  v_msg public.ticket_messages;
  v_body text := btrim(COALESCE(p_message, ''));
  v_attachments jsonb := COALESCE(p_attachments, '[]'::jsonb);
  v_staff boolean;
  v_sender_type text;
  v_sender_name text;
  v_channel text;
  v_message_type text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;
  IF jsonb_typeof(v_attachments) <> 'array' THEN
    RAISE EXCEPTION 'attachments must be an array';
  END IF;
  IF v_body = '' AND jsonb_array_length(v_attachments) = 0 THEN
    RAISE EXCEPTION 'message body or attachments required';
  END IF;
  IF v_body = '' THEN
    v_body := 'Shared a file';
  END IF;

  SELECT * INTO v_ticket
  FROM public.tickets
  WHERE id = p_ticket_id
    AND COALESCE(is_deleted, false) = false
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'ticket not found';
  END IF;

  v_staff := public.has_permission('support.tickets', v_uid)
    OR public.has_permission('support.write', v_uid)
    OR public.has_permission('manage_tickets', v_uid)
    OR public.has_role('super_admin', v_uid);

  IF NOT v_staff AND v_ticket.user_id IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION 'not allowed';
  END IF;
  IF NOT v_staff AND COALESCE(p_is_internal, false) THEN
    RAISE EXCEPTION 'customers cannot write internal notes';
  END IF;
  IF v_ticket.status = 'closed' AND NOT v_staff THEN
    RAISE EXCEPTION 'closed tickets cannot receive customer replies';
  END IF;

  SELECT COALESCE(
           NULLIF(btrim(p.preferred_name), ''),
           NULLIF(btrim(concat_ws(' ', p.first_name, p.last_name)), ''),
           p.email,
           'User'
         )
  INTO v_sender_name
  FROM public.profiles p
  WHERE p.id = v_uid;

  v_sender_type := CASE WHEN v_staff THEN 'agent' ELSE 'customer' END;
  v_sender_name := COALESCE(
    NULLIF(btrim(COALESCE(p_sender_name, '')), ''),
    v_sender_name,
    CASE WHEN v_staff THEN 'Agent' ELSE COALESCE(v_ticket.customer_name, 'Customer') END
  );
  v_channel := COALESCE(
    NULLIF(btrim(COALESCE(p_channel, '')), ''),
    v_ticket.channel,
    'portal'
  );
  v_message_type := COALESCE(
    NULLIF(btrim(COALESCE(p_message_type, '')), ''),
    CASE
      WHEN COALESCE(p_is_internal, false) THEN 'note'
      WHEN jsonb_array_length(v_attachments) > 0 AND v_body = 'Shared a file' THEN 'attachment'
      ELSE 'reply'
    END
  );

  IF p_client_message_id IS NOT NULL THEN
    SELECT *
    INTO v_msg
    FROM public.ticket_messages
    WHERE ticket_id = p_ticket_id
      AND client_message_id = p_client_message_id
    LIMIT 1;
    IF FOUND THEN
      RETURN v_msg;
    END IF;
  END IF;

  INSERT INTO public.ticket_messages (
    ticket_id,
    sender_id,
    sender_type,
    sender_name,
    message_type,
    channel,
    message,
    attachments,
    is_internal,
    client_message_id,
    created_by
  )
  VALUES (
    p_ticket_id,
    v_uid,
    v_sender_type,
    v_sender_name,
    v_message_type,
    v_channel,
    v_body,
    v_attachments,
    COALESCE(p_is_internal, false),
    NULLIF(btrim(COALESCE(p_client_message_id, '')), ''),
    v_uid
  )
  RETURNING * INTO v_msg;

  RETURN v_msg;
END;
$$;

-- ---------------------------------------------------------------------------
-- Ticket message policies: append-only for owners/staff; no broad ALL writes.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS ticket_messages_support_write ON public.ticket_messages;
DROP POLICY IF EXISTS ticket_messages_insert ON public.ticket_messages;
DROP POLICY IF EXISTS ticket_messages_own ON public.ticket_messages;

CREATE POLICY ticket_messages_support_insert
ON public.ticket_messages
FOR INSERT TO authenticated
WITH CHECK (
  sender_id = auth.uid()
  AND (
    public.has_permission('support.tickets', auth.uid())
    OR public.has_permission('support.write', auth.uid())
    OR public.has_permission('manage_tickets', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
);

-- Investor conversation owners may no longer mutate assignment/status via RLS.
DROP POLICY IF EXISTS investor_conversations_owner_update
  ON public.investor_conversations;
CREATE POLICY investor_conversations_owner_update
ON public.investor_conversations
FOR UPDATE TO authenticated
USING (investor_id = public.investor_id_for_user(auth.uid()))
WITH CHECK (
  investor_id = public.investor_id_for_user(auth.uid())
  AND assigned_staff_id IS NULL
  AND status = 'open'
  AND COALESCE(is_deleted, false) = false
);

-- Prefer mark-read RPC; keep limited owner UPDATE for read receipts only.
DROP POLICY IF EXISTS investor_messages_owner_update
  ON public.investor_conversation_messages;
CREATE POLICY investor_messages_owner_update
ON public.investor_conversation_messages
FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.investor_conversations c
    WHERE c.id = conversation_id
      AND c.investor_id = public.investor_id_for_user(auth.uid())
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.investor_conversations c
    WHERE c.id = conversation_id
      AND c.investor_id = public.investor_id_for_user(auth.uid())
  )
);

REVOKE ALL ON FUNCTION public.client_conversation_send_message(uuid, text, jsonb, text)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.investor_conversation_send_message(uuid, text, jsonb, text)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.investor_conversation_mark_read(uuid)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.support_ticket_send_message(
  uuid, text, boolean, jsonb, text, text, text, text
) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.client_conversation_mark_read(uuid)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.client_conversation_set_typing(uuid, boolean, text)
  FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.client_conversation_send_message(uuid, text, jsonb, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.investor_conversation_send_message(uuid, text, jsonb, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.investor_conversation_mark_read(uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.support_ticket_send_message(
  uuid, text, boolean, jsonb, text, text, text, text
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.client_conversation_mark_read(uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.client_conversation_set_typing(uuid, boolean, text)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.support_channel_write_smoke()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'ok',
      NOT has_table_privilege('anon', 'public.client_conversation_messages', 'INSERT')
      AND NOT has_table_privilege('anon', 'public.investor_conversation_messages', 'INSERT')
      AND NOT has_table_privilege('anon', 'public.ticket_messages', 'INSERT')
      AND has_function_privilege(
        'authenticated',
        'public.client_conversation_send_message(uuid,text,jsonb,text)',
        'EXECUTE'
      )
      AND has_function_privilege(
        'authenticated',
        'public.investor_conversation_send_message(uuid,text,jsonb,text)',
        'EXECUTE'
      )
      AND has_function_privilege(
        'authenticated',
        'public.support_ticket_send_message(uuid,text,boolean,jsonb,text,text,text,text)',
        'EXECUTE'
      )
      AND NOT has_function_privilege(
        'anon',
        'public.support_ticket_send_message(uuid,text,boolean,jsonb,text,text,text,text)',
        'EXECUTE'
      ),
    'checked_at', now()
  );
$$;

REVOKE ALL ON FUNCTION public.support_channel_write_smoke() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.support_channel_write_smoke() TO authenticated;

COMMIT;
