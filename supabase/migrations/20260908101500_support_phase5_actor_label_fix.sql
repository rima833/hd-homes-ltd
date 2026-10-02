-- Correct actor labels for the live profiles schema.
CREATE OR REPLACE FUNCTION public.support_ticket_on_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor uuid;
  v_actor_label text;
  v_action text;
BEGIN
  SELECT
    p.id,
    COALESCE(
      NULLIF(btrim(p.preferred_name), ''),
      NULLIF(btrim(concat_ws(' ', p.first_name, p.last_name)), ''),
      p.email,
      'Staff'
    )
  INTO v_actor, v_actor_label
  FROM public.profiles p
  WHERE p.id = auth.uid();

  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.support_ticket_events (
      ticket_id, actor_id, actor_label, action, is_internal, metadata
    )
    VALUES (
      NEW.id,
      v_actor,
      COALESCE(v_actor_label, NEW.customer_name, 'System'),
      'created',
      false,
      jsonb_build_object(
        'ticket_number', NEW.ticket_number,
        'source', COALESCE(NEW.channel, 'unknown')
      )
    );

    INSERT INTO public.support_notifications (
      title, body, severity, audience, ticket_id, metadata
    )
    VALUES (
      'New support ticket ' || COALESCE(NEW.ticket_number, ''),
      NEW.subject,
      CASE WHEN lower(NEW.priority) = 'urgent' THEN 'critical' ELSE 'info' END,
      'agents',
      NEW.id,
      jsonb_build_object('event', 'ticket_created')
    );
    RETURN NEW;
  END IF;

  IF OLD.assigned_to IS DISTINCT FROM NEW.assigned_to THEN
    INSERT INTO public.support_ticket_events (
      ticket_id, actor_id, actor_label, action, is_internal, metadata
    )
    VALUES (
      NEW.id,
      v_actor,
      COALESCE(v_actor_label, 'System'),
      CASE
        WHEN NEW.assigned_to IS NULL THEN 'unassigned'
        WHEN OLD.assigned_to IS NULL THEN 'assigned'
        ELSE 'reassigned'
      END,
      true,
      jsonb_build_object(
        'from_assignee', OLD.assigned_to,
        'to_assignee', NEW.assigned_to
      )
    );
  END IF;

  IF OLD.status IS DISTINCT FROM NEW.status THEN
    v_action := CASE
      WHEN lower(NEW.status) = 'resolved' THEN 'resolved'
      WHEN lower(NEW.status) = 'closed' THEN 'closed'
      WHEN lower(OLD.status) IN ('resolved', 'closed')
        AND lower(NEW.status) NOT IN ('resolved', 'closed') THEN 'reopened'
      ELSE 'status_changed'
    END;
    INSERT INTO public.support_ticket_events (
      ticket_id, actor_id, actor_label, action,
      from_status, to_status, is_internal
    )
    VALUES (
      NEW.id, v_actor, COALESCE(v_actor_label, 'System'), v_action,
      OLD.status, NEW.status, false
    );
  END IF;

  IF OLD.priority IS DISTINCT FROM NEW.priority THEN
    INSERT INTO public.support_ticket_events (
      ticket_id, actor_id, actor_label, action,
      from_priority, to_priority, is_internal
    )
    VALUES (
      NEW.id, v_actor, COALESCE(v_actor_label, 'System'),
      'priority_changed', OLD.priority, NEW.priority, true
    );
  END IF;

  RETURN NEW;
END;
$$;
