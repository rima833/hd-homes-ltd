-- Typing indicator parity for investor portal messages
ALTER TABLE public.investor_conversations
  ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;

CREATE OR REPLACE FUNCTION public.investor_conversation_set_typing(
  p_conversation_id uuid,
  p_is_typing boolean,
  p_actor text DEFAULT 'investor'::text
)
RETURNS investor_conversations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_row public.investor_conversations;
  v_actor text := lower(trim(COALESCE(p_actor, 'investor')));
  v_key text;
  v_value jsonb;
BEGIN
  IF v_actor NOT IN ('investor', 'staff') THEN
    v_actor := 'investor';
  END IF;

  SELECT * INTO v_row
  FROM public.investor_conversations
  WHERE id = p_conversation_id
    AND COALESCE(is_deleted, false) = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'conversation not found';
  END IF;

  IF v_actor = 'investor' THEN
    IF v_row.investor_id IS DISTINCT FROM public.investor_id_for_user(auth.uid()) THEN
      RAISE EXCEPTION 'not allowed';
    END IF;
  ELSE
    IF NOT public.can_staff_portal_message_investors(auth.uid()) THEN
      RAISE EXCEPTION 'staff only';
    END IF;
  END IF;

  v_key := v_actor || '_typing_at';
  v_value := CASE
    WHEN COALESCE(p_is_typing, false) THEN to_jsonb(now())
    ELSE 'null'::jsonb
  END;

  UPDATE public.investor_conversations
  SET
    metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(v_key, v_value),
    updated_at = now()
  WHERE id = p_conversation_id
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$function$;
