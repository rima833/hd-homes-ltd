-- Phase 6 hardening: least-privilege ticket RPCs and complete lifecycle events.

CREATE OR REPLACE FUNCTION public.create_support_ticket(
  p_subject text,
  p_description text,
  p_priority text DEFAULT 'normal',
  p_customer_type text DEFAULT NULL,
  p_category_id uuid DEFAULT NULL,
  p_property_id uuid DEFAULT NULL,
  p_source text DEFAULT 'portal',
  p_channel text DEFAULT 'portal',
  p_customer_user_id uuid DEFAULT NULL,
  p_customer_name text DEFAULT NULL,
  p_customer_email text DEFAULT NULL,
  p_customer_phone text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_staff boolean;
  v_owner uuid;
  v_type text;
  v_source text;
  v_channel text;
  v_profile public.profiles;
  v_ticket public.tickets;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;
  IF length(btrim(COALESCE(p_subject, ''))) < 3 THEN
    RAISE EXCEPTION 'subject must contain at least 3 characters';
  END IF;
  IF length(btrim(COALESCE(p_description, ''))) < 10 THEN
    RAISE EXCEPTION 'description must contain at least 10 characters';
  END IF;
  IF p_priority NOT IN ('low', 'normal', 'high', 'urgent') THEN
    RAISE EXCEPTION 'invalid priority';
  END IF;

  v_staff := public.has_permission('support.tickets', v_uid)
    OR public.has_permission('support.write', v_uid)
    OR public.has_permission('manage_tickets', v_uid)
    OR public.has_role('super_admin', v_uid);
  v_owner := CASE WHEN v_staff THEN p_customer_user_id ELSE v_uid END;

  IF v_owner IS NOT NULL THEN
    SELECT * INTO v_profile FROM public.profiles WHERE id = v_owner;
    IF NOT FOUND THEN RAISE EXCEPTION 'customer profile not found'; END IF;
  END IF;

  IF v_staff THEN
    v_type := COALESCE(p_customer_type, CASE
      WHEN v_owner IS NULL THEN 'website_visitor'
      WHEN EXISTS (
        SELECT 1 FROM public.investors i WHERE i.user_id = v_owner
      ) THEN 'investor' ELSE 'client' END);
    v_source := COALESCE(NULLIF(btrim(p_source), ''), 'admin');
    v_channel := COALESCE(NULLIF(btrim(p_channel), ''), 'portal');
  ELSE
    v_type := CASE WHEN EXISTS (
      SELECT 1 FROM public.investors i WHERE i.user_id = v_uid
    ) THEN 'investor' ELSE 'client' END;
    v_source := CASE WHEN v_type = 'investor'
      THEN 'investor_portal' ELSE 'client_portal' END;
    v_channel := v_source;
  END IF;

  IF v_type NOT IN ('website_visitor', 'client', 'investor') THEN
    RAISE EXCEPTION 'invalid customer type';
  END IF;
  IF v_type <> 'website_visitor' AND v_owner IS NULL THEN
    RAISE EXCEPTION 'client and investor tickets require a user';
  END IF;
  IF v_type = 'investor' AND NOT EXISTS (
    SELECT 1 FROM public.investors i WHERE i.user_id = v_owner
  ) THEN
    RAISE EXCEPTION 'selected account is not an investor';
  END IF;
  IF v_type = 'website_visitor' AND (
    length(btrim(COALESCE(p_customer_name, ''))) < 2
    OR (
      position('@' IN COALESCE(p_customer_email, '')) = 0
      AND length(btrim(COALESCE(p_customer_phone, ''))) < 7
    )
  ) THEN
    RAISE EXCEPTION 'visitor name and email or phone are required';
  END IF;
  IF p_category_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.support_categories c
    WHERE c.id = p_category_id AND c.is_active IS TRUE
  ) THEN
    RAISE EXCEPTION 'invalid or inactive category';
  END IF;

  INSERT INTO public.tickets (
    user_id, subject, description, priority, status, channel, source,
    customer_type, customer_name, customer_email, customer_phone,
    category_id, property_id, estate_id, created_by
  )
  VALUES (
    v_owner, btrim(p_subject), btrim(p_description), p_priority, 'new',
    v_channel, v_source, v_type,
    COALESCE(
      NULLIF(btrim(p_customer_name), ''),
      NULLIF(btrim(v_profile.preferred_name), ''),
      NULLIF(btrim(concat_ws(' ', v_profile.first_name, v_profile.last_name)), '')
    ),
    COALESCE(NULLIF(lower(btrim(p_customer_email)), ''), v_profile.email),
    COALESCE(NULLIF(btrim(p_customer_phone), ''), v_profile.phone),
    p_category_id, p_property_id,
    (SELECT p.estate_id FROM public.properties p WHERE p.id = p_property_id),
    v_uid
  )
  RETURNING * INTO v_ticket;

  IF NOT v_staff THEN
    INSERT INTO public.ticket_messages (
      ticket_id, sender_id, sender_type, sender_name, message_type,
      channel, message, is_internal, created_by
    )
    VALUES (
      v_ticket.id, v_uid, 'customer', v_ticket.customer_name, 'note',
      v_ticket.channel, v_ticket.description, false, v_uid
    );
  END IF;
  RETURN to_jsonb(v_ticket);
END;
$$;

CREATE OR REPLACE FUNCTION public.manage_support_ticket(
  p_ticket_id uuid,
  p_status text DEFAULT NULL,
  p_priority text DEFAULT NULL,
  p_assignment_action text DEFAULT 'keep',
  p_assigned_to uuid DEFAULT NULL,
  p_category_id uuid DEFAULT NULL,
  p_team_id uuid DEFAULT NULL,
  p_queue_id uuid DEFAULT NULL,
  p_property_id uuid DEFAULT NULL,
  p_admin_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_ticket public.tickets;
BEGIN
  IF v_uid IS NULL OR NOT (
    public.has_permission('support.tickets', v_uid)
    OR public.has_permission('support.write', v_uid)
    OR public.has_permission('manage_tickets', v_uid)
    OR public.has_role('super_admin', v_uid)
  ) THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status IS NOT NULL AND p_status NOT IN (
    'new', 'open', 'in_progress', 'waiting_for_customer',
    'waiting_for_hd_homes', 'escalated', 'resolved', 'closed'
  ) THEN RAISE EXCEPTION 'invalid status'; END IF;
  IF p_priority IS NOT NULL
    AND p_priority NOT IN ('low', 'normal', 'high', 'urgent')
  THEN RAISE EXCEPTION 'invalid priority'; END IF;
  IF p_assignment_action NOT IN ('keep', 'assign', 'unassign') THEN
    RAISE EXCEPTION 'invalid assignment action';
  END IF;
  IF p_assignment_action = 'assign' AND (
    p_assigned_to IS NULL OR NOT (
      public.has_permission('support.tickets', p_assigned_to)
      OR public.has_permission('support.write', p_assigned_to)
      OR public.has_permission('manage_tickets', p_assigned_to)
      OR public.has_role('super_admin', p_assigned_to)
    )
  ) THEN
    RAISE EXCEPTION 'assignee must be an authorized support agent';
  END IF;
  IF p_category_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.support_categories c
    WHERE c.id = p_category_id AND c.is_active IS TRUE
  ) THEN RAISE EXCEPTION 'invalid or inactive category'; END IF;

  UPDATE public.tickets t SET
    status = COALESCE(p_status, t.status),
    priority = COALESCE(p_priority, t.priority),
    assigned_to = CASE p_assignment_action
      WHEN 'assign' THEN p_assigned_to
      WHEN 'unassign' THEN NULL
      ELSE t.assigned_to END,
    category_id = COALESCE(p_category_id, t.category_id),
    team_id = COALESCE(p_team_id, t.team_id),
    queue_id = COALESCE(p_queue_id, t.queue_id),
    property_id = COALESCE(p_property_id, t.property_id),
    estate_id = CASE WHEN p_property_id IS NULL THEN t.estate_id
      ELSE (SELECT p.estate_id FROM public.properties p
            WHERE p.id = p_property_id) END,
    metadata = CASE WHEN p_admin_notes IS NULL THEN t.metadata
      ELSE COALESCE(t.metadata, '{}'::jsonb)
        || jsonb_build_object('admin_notes', btrim(p_admin_notes)) END,
    updated_by = v_uid
  WHERE t.id = p_ticket_id
  RETURNING * INTO v_ticket;
  IF NOT FOUND THEN RAISE EXCEPTION 'ticket not found'; END IF;
  RETURN to_jsonb(v_ticket);
END;
$$;

CREATE OR REPLACE FUNCTION public.record_resolution_confirmation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor uuid;
  v_label text;
BEGIN
  IF OLD.resolution_confirmed_at IS NULL
    AND NEW.resolution_confirmed_at IS NOT NULL
  THEN
    SELECT
      p.id,
      COALESCE(
        NULLIF(btrim(p.preferred_name), ''),
        NULLIF(btrim(concat_ws(' ', p.first_name, p.last_name)), ''),
        p.email,
        'Customer'
      )
    INTO v_actor, v_label
    FROM public.profiles p
    WHERE p.id = auth.uid();

    INSERT INTO public.support_ticket_events (
      ticket_id, actor_id, actor_label, action, is_internal, metadata
    )
    VALUES (
      NEW.id, v_actor, COALESCE(v_label, NEW.customer_name, 'Customer'),
      'resolution_confirmed', false,
      jsonb_build_object('confirmed_at', NEW.resolution_confirmed_at)
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_ticket_resolution_confirmation ON public.tickets;
CREATE TRIGGER trg_ticket_resolution_confirmation
AFTER UPDATE OF resolution_confirmed_at ON public.tickets
FOR EACH ROW EXECUTE FUNCTION public.record_resolution_confirmation();
