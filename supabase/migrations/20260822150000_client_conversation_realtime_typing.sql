-- Client portal messaging: typing indicators, read receipts, preview text

ALTER TABLE public.client_conversations
  ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS last_message_preview text;

CREATE OR REPLACE FUNCTION public.client_conversation_on_message()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.client_conversations
  SET
    last_message_at = NEW.created_at,
    last_message_preview = left(NEW.body, 120),
    updated_at = now()
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_client_conversation_message ON public.client_conversation_messages;
CREATE TRIGGER trg_client_conversation_message
AFTER INSERT ON public.client_conversation_messages
FOR EACH ROW EXECUTE FUNCTION public.client_conversation_on_message();

CREATE OR REPLACE FUNCTION public.client_conversation_set_typing(
  p_conversation_id uuid,
  p_is_typing boolean,
  p_actor text DEFAULT 'client'
)
RETURNS public.client_conversations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.client_conversations;
  v_actor text := lower(trim(COALESCE(p_actor, 'client')));
  v_key text;
  v_value jsonb;
BEGIN
  IF v_actor NOT IN ('client', 'staff') THEN
    v_actor := 'client';
  END IF;

  SELECT * INTO v_row
  FROM public.client_conversations
  WHERE id = p_conversation_id
    AND is_deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'conversation not found';
  END IF;

  IF v_actor = 'client' THEN
    IF v_row.client_id IS DISTINCT FROM public.client_id_for_user(auth.uid()) THEN
      RAISE EXCEPTION 'not allowed';
    END IF;
  ELSE
    IF auth.uid() IS NULL OR NOT public.is_staff(auth.uid()) THEN
      RAISE EXCEPTION 'staff only';
    END IF;
  END IF;

  v_key := v_actor || '_typing_at';
  v_value := CASE
    WHEN COALESCE(p_is_typing, false) THEN to_jsonb(now())
    ELSE 'null'::jsonb
  END;

  UPDATE public.client_conversations
  SET
    metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(v_key, v_value),
    updated_at = now()
  WHERE id = p_conversation_id
  RETURNING * INTO v_row;

  RETURN v_row;
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
BEGIN
  SELECT client_id INTO v_client_id
  FROM public.client_conversations
  WHERE id = p_conversation_id AND is_deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'conversation not found';
  END IF;

  IF v_client_id IS DISTINCT FROM public.client_id_for_user(auth.uid())
     AND NOT public.is_staff(auth.uid()) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  UPDATE public.client_conversation_messages
  SET read_at = now(), updated_at = now()
  WHERE conversation_id = p_conversation_id
    AND is_deleted = false
    AND read_at IS NULL
    AND sender_id IS DISTINCT FROM auth.uid();

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.client_conversation_set_typing(uuid, boolean, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.client_conversation_mark_read(uuid)
  TO authenticated;
