-- Allow Support desk staff to read/reply investor portal conversations
-- (Portal Messages unifies client + investor threads).

CREATE OR REPLACE FUNCTION public.can_staff_portal_message_investors(p_uid uuid DEFAULT auth.uid())
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT
    p_uid IS NOT NULL
    AND (
      public.has_role('super_admin', p_uid)
      OR public.has_permission('investors.communicate', p_uid)
      OR public.has_permission('support.write', p_uid)
      OR public.has_permission('support.inbox', p_uid)
    );
$$;

DROP POLICY IF EXISTS investor_conversations_staff_all ON public.investor_conversations;
CREATE POLICY investor_conversations_staff_all ON public.investor_conversations
  FOR ALL
  USING (public.can_staff_portal_message_investors(auth.uid()))
  WITH CHECK (public.can_staff_portal_message_investors(auth.uid()));

DROP POLICY IF EXISTS investor_messages_staff_all ON public.investor_conversation_messages;
CREATE POLICY investor_messages_staff_all ON public.investor_conversation_messages
  FOR ALL
  USING (public.can_staff_portal_message_investors(auth.uid()))
  WITH CHECK (public.can_staff_portal_message_investors(auth.uid()));

CREATE OR REPLACE FUNCTION public.investor_conversation_mark_read(p_conversation_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  v_is_staff := public.can_staff_portal_message_investors(auth.uid());

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
$function$;

CREATE OR REPLACE FUNCTION public.investor_conversation_send_message(
  p_conversation_id uuid,
  p_body text,
  p_attachments jsonb DEFAULT '[]'::jsonb,
  p_client_message_id text DEFAULT NULL::text
)
 RETURNS investor_conversation_messages
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  v_is_staff := public.can_staff_portal_message_investors(v_uid);
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
    conversation_id, sender_id, body, attachments, client_message_id, created_by
  )
  VALUES (
    p_conversation_id, v_uid, v_body, v_attachments,
    NULLIF(btrim(COALESCE(p_client_message_id, '')), ''), v_uid
  )
  RETURNING * INTO v_msg;

  RETURN v_msg;
END;
$function$;
