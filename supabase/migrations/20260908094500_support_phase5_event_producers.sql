-- HD Homes Support Phase 5 follow-up:
-- database-authoritative event production, parent-row synchronization,
-- notifications, and complete realtime diagnostics.

-- ---------------------------------------------------------------------------
-- Parent message summaries used by realtime queues
-- ---------------------------------------------------------------------------
ALTER TABLE public.live_chat_sessions
  ADD COLUMN IF NOT EXISTS last_message_at timestamptz,
  ADD COLUMN IF NOT EXISTS last_message_preview text,
  ADD COLUMN IF NOT EXISTS message_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS visitor_unread_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS agent_unread_count integer NOT NULL DEFAULT 0;

ALTER TABLE public.investor_conversations
  ADD COLUMN IF NOT EXISTS last_message_preview text,
  ADD COLUMN IF NOT EXISTS investor_unread_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS staff_unread_count integer NOT NULL DEFAULT 0;

UPDATE public.live_chat_sessions s
SET
  last_message_at = x.last_message_at,
  last_message_preview = x.last_message_preview,
  message_count = x.message_count
FROM (
  SELECT
    m.session_id,
    max(m.created_at) AS last_message_at,
    (
      array_agg(left(m.body, 160) ORDER BY m.created_at DESC)
    )[1] AS last_message_preview,
    count(*)::integer AS message_count
  FROM public.live_chat_messages m
  GROUP BY m.session_id
) x
WHERE x.session_id = s.id
  AND (
    s.last_message_at IS DISTINCT FROM x.last_message_at
    OR s.message_count IS DISTINCT FROM x.message_count
  );

-- ---------------------------------------------------------------------------
-- Ticket events and support/customer notification producers
-- ---------------------------------------------------------------------------
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
  SELECT p.id, COALESCE(p.full_name, p.email, 'Staff')
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

DROP TRIGGER IF EXISTS trg_support_ticket_events ON public.tickets;
CREATE TRIGGER trg_support_ticket_events
AFTER INSERT OR UPDATE OF assigned_to, status, priority
ON public.tickets
FOR EACH ROW EXECUTE FUNCTION public.support_ticket_on_change();

CREATE OR REPLACE FUNCTION public.support_ticket_message_on_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ticket public.tickets;
  v_sender_type text;
  v_is_customer boolean;
  v_actor uuid;
  v_prior_messages integer;
BEGIN
  SELECT * INTO v_ticket
  FROM public.tickets
  WHERE id = NEW.ticket_id;

  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  SELECT p.id INTO v_actor
  FROM public.profiles p
  WHERE p.id = NEW.sender_id;

  v_sender_type := lower(COALESCE(
    NULLIF(NEW.sender_type, ''),
    CASE
      WHEN NEW.sender_id IS NOT NULL AND NEW.sender_id = v_ticket.user_id
        THEN 'customer'
      ELSE 'agent'
    END
  ));
  v_is_customer := v_sender_type IN (
    'customer', 'client', 'investor', 'visitor', 'user'
  );

  SELECT count(*)::integer INTO v_prior_messages
  FROM public.ticket_messages m
  WHERE m.ticket_id = NEW.ticket_id
    AND m.id <> NEW.id
    AND COALESCE(m.is_deleted, false) = false;

  IF COALESCE(NEW.is_internal, false) THEN
    INSERT INTO public.support_ticket_events (
      ticket_id, actor_id, actor_label, action, is_internal, metadata
    )
    VALUES (
      NEW.ticket_id, v_actor, NEW.sender_name, 'internal_note_created', true,
      jsonb_build_object('message_id', NEW.id)
    );
  ELSIF v_is_customer THEN
    UPDATE public.tickets
    SET
      last_customer_response_at = NEW.created_at,
      waiting_since = NULL
    WHERE id = NEW.ticket_id;

    INSERT INTO public.support_ticket_events (
      ticket_id, actor_id, actor_label, action, is_internal, metadata
    )
    VALUES (
      NEW.ticket_id, v_actor,
      COALESCE(NEW.sender_name, v_ticket.customer_name, 'Customer'),
      'customer_replied', false,
      jsonb_build_object('message_id', NEW.id, 'channel', NEW.channel)
    );

    IF v_prior_messages > 0 THEN
      INSERT INTO public.support_notifications (
        title, body, severity, audience, ticket_id, metadata
      )
      VALUES (
        'Customer replied · ' || COALESCE(v_ticket.ticket_number, ''),
        left(NEW.message, 240),
        CASE WHEN lower(v_ticket.priority) = 'urgent' THEN 'critical' ELSE 'info' END,
        'agents',
        NEW.ticket_id,
        jsonb_build_object('event', 'customer_replied', 'message_id', NEW.id)
      );
    END IF;
  ELSE
    UPDATE public.tickets
    SET
      first_response_at = COALESCE(first_response_at, NEW.created_at),
      last_agent_response_at = NEW.created_at
    WHERE id = NEW.ticket_id;

    INSERT INTO public.support_ticket_events (
      ticket_id, actor_id, actor_label, action, is_internal, metadata
    )
    VALUES (
      NEW.ticket_id, v_actor, COALESCE(NEW.sender_name, 'Support'),
      'agent_replied', false,
      jsonb_build_object('message_id', NEW.id, 'channel', NEW.channel)
    );

    IF v_ticket.user_id IS NOT NULL THEN
      INSERT INTO public.notifications (
        user_id, title, body, category, type, priority,
        action_url, metadata
      )
      VALUES (
        v_ticket.user_id,
        'HD Homes Support replied',
        left(NEW.message, 240),
        'support',
        'information',
        CASE WHEN lower(v_ticket.priority) = 'urgent' THEN 'high' ELSE 'normal' END,
        CASE
          WHEN v_ticket.customer_type = 'investor'
            OR v_ticket.channel = 'investor_portal'
            THEN '/investor/support'
          ELSE '/client/support'
        END,
        jsonb_build_object(
          'event', 'agent_replied',
          'ticket_id', NEW.ticket_id,
          'ticket_number', v_ticket.ticket_number,
          'message_id', NEW.id
        )
      );
    END IF;
  END IF;

  IF NEW.attachments IS NOT NULL
    AND jsonb_typeof(NEW.attachments) = 'array'
    AND jsonb_array_length(NEW.attachments) > 0
  THEN
    INSERT INTO public.support_ticket_events (
      ticket_id, actor_id, actor_label, action, is_internal, metadata
    )
    VALUES (
      NEW.ticket_id, v_actor, NEW.sender_name, 'attachment_added',
      COALESCE(NEW.is_internal, false),
      jsonb_build_object(
        'message_id', NEW.id,
        'attachment_count', jsonb_array_length(NEW.attachments)
      )
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_support_ticket_message_event
ON public.ticket_messages;
CREATE TRIGGER trg_support_ticket_message_event
AFTER INSERT ON public.ticket_messages
FOR EACH ROW EXECUTE FUNCTION public.support_ticket_message_on_insert();

-- ---------------------------------------------------------------------------
-- Live-chat and investor-message parent synchronization
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.support_live_chat_message_on_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_session public.live_chat_sessions;
  v_from_visitor boolean;
BEGIN
  v_from_visitor := lower(NEW.sender_type) IN (
    'visitor', 'customer', 'client', 'investor', 'user'
  );

  UPDATE public.live_chat_sessions
  SET
    last_message_at = NEW.created_at,
    last_message_preview = left(NEW.body, 160),
    message_count = message_count + 1,
    visitor_unread_count = visitor_unread_count +
      CASE WHEN v_from_visitor THEN 0 ELSE 1 END,
    agent_unread_count = agent_unread_count +
      CASE WHEN v_from_visitor THEN 1 ELSE 0 END,
    updated_at = now()
  WHERE id = NEW.session_id
  RETURNING * INTO v_session;

  IF v_from_visitor THEN
    INSERT INTO public.support_notifications (
      title, body, severity, audience, ticket_id, metadata
    )
    VALUES (
      'New live chat message',
      left(NEW.body, 240),
      'info',
      'agents',
      v_session.ticket_id,
      jsonb_build_object(
        'event', 'live_chat_message',
        'session_id', NEW.session_id,
        'message_id', NEW.id
      )
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_support_live_chat_message
ON public.live_chat_messages;
CREATE TRIGGER trg_support_live_chat_message
AFTER INSERT ON public.live_chat_messages
FOR EACH ROW EXECUTE FUNCTION public.support_live_chat_message_on_insert();

CREATE OR REPLACE FUNCTION public.support_investor_message_on_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_investor_user_id uuid;
  v_from_investor boolean;
BEGIN
  SELECT i.user_id INTO v_investor_user_id
  FROM public.investor_conversations c
  JOIN public.investors i ON i.id = c.investor_id
  WHERE c.id = NEW.conversation_id;

  v_from_investor := NEW.sender_id = v_investor_user_id;

  UPDATE public.investor_conversations
  SET
    last_message_at = NEW.created_at,
    last_message_preview = left(NEW.body, 160),
    investor_unread_count = investor_unread_count +
      CASE WHEN v_from_investor THEN 0 ELSE 1 END,
    staff_unread_count = staff_unread_count +
      CASE WHEN v_from_investor THEN 1 ELSE 0 END,
    updated_at = now()
  WHERE id = NEW.conversation_id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_support_investor_message
ON public.investor_conversation_messages;
CREATE TRIGGER trg_support_investor_message
AFTER INSERT ON public.investor_conversation_messages
FOR EACH ROW EXECUTE FUNCTION public.support_investor_message_on_insert();

-- ---------------------------------------------------------------------------
-- Complete publication coverage and diagnostics
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'notifications',
    'investor_notifications',
    'whatsapp_messages',
    'whatsapp_conversations',
    'support_email_threads',
    'support_email_messages'
  ]
  LOOP
    IF to_regclass('public.' || t) IS NOT NULL THEN
      IF NOT EXISTS (
        SELECT 1
        FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
          AND schemaname = 'public'
          AND tablename = t
      ) THEN
        EXECUTE format(
          'ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',
          t
        );
      END IF;
      EXECUTE format('ALTER TABLE public.%I REPLICA IDENTITY FULL', t);
    END IF;
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.support_realtime_healthcheck()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH expected(tablename) AS (
    SELECT unnest(ARRAY[
      'tickets', 'ticket_messages', 'live_chat_sessions',
      'live_chat_messages', 'client_conversations',
      'client_conversation_messages', 'investor_conversations',
      'investor_conversation_messages', 'support_agents',
      'support_assignments', 'support_notifications',
      'support_ticket_events', 'support_ticket_links', 'support_settings',
      'support_operating_hours', 'support_holidays',
      'support_quick_replies', 'support_assignment_rules',
      'support_escalations', 'support_knowledge_articles',
      'support_activity_logs', 'notifications', 'investor_notifications',
      'whatsapp_messages', 'whatsapp_conversations',
      'support_email_threads'
    ])
  ),
  existing AS (
    SELECT e.tablename
    FROM expected e
    WHERE to_regclass('public.' || e.tablename) IS NOT NULL
  ),
  unhealthy AS (
    SELECT e.tablename
    FROM existing e
    LEFT JOIN pg_publication_tables p
      ON p.pubname = 'supabase_realtime'
      AND p.schemaname = 'public'
      AND p.tablename = e.tablename
    LEFT JOIN pg_class c
      ON c.oid = to_regclass('public.' || e.tablename)
    WHERE p.tablename IS NULL OR c.relreplident <> 'f'
  )
  SELECT jsonb_build_object(
    'healthy', NOT EXISTS (SELECT 1 FROM unhealthy),
    'checked_tables', (SELECT count(*) FROM existing),
    'unhealthy_tables',
      COALESCE((SELECT jsonb_agg(tablename ORDER BY tablename) FROM unhealthy),
               '[]'::jsonb)
  );
$$;

REVOKE ALL ON FUNCTION public.support_realtime_healthcheck() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.support_realtime_healthcheck()
TO authenticated;
