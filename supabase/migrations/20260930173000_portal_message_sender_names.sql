-- Store the sender's profile name on portal messages so clients,
-- investors, and staff see who replied (admin or staff).

ALTER TABLE public.client_conversation_messages
  ADD COLUMN IF NOT EXISTS sender_name text;

ALTER TABLE public.investor_conversation_messages
  ADD COLUMN IF NOT EXISTS sender_name text;

CREATE OR REPLACE FUNCTION public.stamp_conversation_sender_name()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_name text;
BEGIN
  IF NEW.sender_name IS NOT NULL AND btrim(NEW.sender_name) <> '' THEN
    RETURN NEW;
  END IF;
  SELECT COALESCE(
           NULLIF(btrim(concat_ws(' ', p.first_name, p.last_name)), ''),
           NULLIF(btrim(p.preferred_name), ''),
           NULLIF(btrim(p.email), '')
         )
    INTO v_name
  FROM public.profiles p
  WHERE p.id = NEW.sender_id;
  NEW.sender_name := v_name;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS client_messages_stamp_sender_name
  ON public.client_conversation_messages;
CREATE TRIGGER client_messages_stamp_sender_name
  BEFORE INSERT ON public.client_conversation_messages
  FOR EACH ROW
  EXECUTE FUNCTION public.stamp_conversation_sender_name();

DROP TRIGGER IF EXISTS investor_messages_stamp_sender_name
  ON public.investor_conversation_messages;
CREATE TRIGGER investor_messages_stamp_sender_name
  BEFORE INSERT ON public.investor_conversation_messages
  FOR EACH ROW
  EXECUTE FUNCTION public.stamp_conversation_sender_name();

UPDATE public.client_conversation_messages m
SET sender_name = COALESCE(
  NULLIF(btrim(concat_ws(' ', p.first_name, p.last_name)), ''),
  NULLIF(btrim(p.preferred_name), ''),
  NULLIF(btrim(p.email), '')
)
FROM public.profiles p
WHERE p.id = m.sender_id
  AND (m.sender_name IS NULL OR btrim(m.sender_name) = '');

UPDATE public.investor_conversation_messages m
SET sender_name = COALESCE(
  NULLIF(btrim(concat_ws(' ', p.first_name, p.last_name)), ''),
  NULLIF(btrim(p.preferred_name), ''),
  NULLIF(btrim(p.email), '')
)
FROM public.profiles p
WHERE p.id = m.sender_id
  AND (m.sender_name IS NULL OR btrim(m.sender_name) = '');
