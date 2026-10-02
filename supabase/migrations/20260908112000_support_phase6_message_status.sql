-- Message-driven lifecycle transitions remain database-authoritative.
CREATE OR REPLACE FUNCTION public.sync_ticket_status_from_message()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ticket public.tickets;
  v_sender_type text;
  v_customer boolean;
BEGIN
  IF COALESCE(NEW.is_internal, false) THEN RETURN NEW; END IF;
  SELECT * INTO v_ticket FROM public.tickets WHERE id = NEW.ticket_id;
  IF NOT FOUND THEN RETURN NEW; END IF;
  v_sender_type := lower(COALESCE(NULLIF(NEW.sender_type, ''), CASE
    WHEN NEW.sender_id = v_ticket.user_id THEN 'customer' ELSE 'agent' END));
  v_customer := v_sender_type IN (
    'customer', 'client', 'investor', 'visitor', 'user'
  );

  IF v_customer AND v_ticket.status IN (
    'waiting_for_customer', 'resolved', 'closed'
  ) THEN
    UPDATE public.tickets SET
      status = 'open',
      reopened_at = CASE WHEN v_ticket.status IN ('resolved', 'closed')
        THEN now() ELSE reopened_at END,
      resolution_confirmed_at = NULL
    WHERE id = NEW.ticket_id;
  ELSIF NOT v_customer AND v_ticket.status IN ('new', 'open') THEN
    UPDATE public.tickets SET status = 'in_progress'
    WHERE id = NEW.ticket_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_support_ticket_message_status
  ON public.ticket_messages;
CREATE TRIGGER trg_support_ticket_message_status
AFTER INSERT ON public.ticket_messages
FOR EACH ROW EXECUTE FUNCTION public.sync_ticket_status_from_message();
