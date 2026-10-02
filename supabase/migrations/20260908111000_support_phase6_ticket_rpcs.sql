-- Phase 6: validated ticket creation and lifecycle mutations.
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
    OR public.has_role('super_admin', v_uid)
    OR public.is_staff();
  v_owner := CASE WHEN v_staff THEN p_customer_user_id ELSE v_uid END;

  IF v_owner IS NOT NULL THEN
    SELECT * INTO v_profile FROM public.profiles WHERE id = v_owner;
    IF NOT FOUND THEN RAISE EXCEPTION 'customer profile not found'; END IF;
  END IF;

  v_type := COALESCE(p_customer_type, CASE
    WHEN v_owner IS NULL THEN 'website_visitor'
    WHEN EXISTS (
      SELECT 1 FROM public.investors i WHERE i.user_id = v_owner
    ) THEN 'investor' ELSE 'client' END);
  IF v_type NOT IN ('website_visitor', 'client', 'investor') THEN
    RAISE EXCEPTION 'invalid customer type';
  END IF;
  IF v_type <> 'website_visitor' AND v_owner IS NULL THEN
    RAISE EXCEPTION 'client and investor tickets require a user';
  END IF;

  INSERT INTO public.tickets (
    user_id, subject, description, priority, status, channel, source,
    customer_type, customer_name, customer_email, customer_phone,
    category_id, property_id, estate_id, created_by
  )
  VALUES (
    v_owner, btrim(p_subject), btrim(p_description), p_priority, 'new',
    COALESCE(NULLIF(btrim(p_channel), ''), 'portal'),
    COALESCE(NULLIF(btrim(p_source), ''), 'portal'), v_type,
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
  IF NOT (
    public.has_permission('support.tickets', v_uid)
    OR public.has_permission('support.write', v_uid)
    OR public.has_permission('manage_tickets', v_uid)
    OR public.has_role('super_admin', v_uid)
    OR public.is_staff()
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
  IF p_assignment_action = 'assign' AND p_assigned_to IS NULL THEN
    RAISE EXCEPTION 'assignee required';
  END IF;

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
        || jsonb_build_object('admin_notes', p_admin_notes) END,
    updated_by = v_uid
  WHERE t.id = p_ticket_id
  RETURNING * INTO v_ticket;
  IF NOT FOUND THEN RAISE EXCEPTION 'ticket not found'; END IF;
  RETURN to_jsonb(v_ticket);
END;
$$;

CREATE OR REPLACE FUNCTION public.customer_transition_support_ticket(
  p_ticket_id uuid,
  p_action text
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
  SELECT * INTO v_ticket FROM public.tickets
  WHERE id = p_ticket_id AND user_id = v_uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ticket not found'; END IF;

  IF p_action = 'confirm_resolution' THEN
    IF v_ticket.status <> 'resolved' THEN
      RAISE EXCEPTION 'only resolved tickets can be confirmed';
    END IF;
    UPDATE public.tickets SET status = 'closed',
      resolution_confirmed_at = now(), updated_by = v_uid
    WHERE id = p_ticket_id RETURNING * INTO v_ticket;
  ELSIF p_action = 'close' THEN
    IF v_ticket.status = 'closed' THEN RETURN to_jsonb(v_ticket); END IF;
    UPDATE public.tickets SET status = 'closed', updated_by = v_uid
    WHERE id = p_ticket_id RETURNING * INTO v_ticket;
  ELSIF p_action = 'reopen' THEN
    IF v_ticket.status NOT IN ('resolved', 'closed') THEN
      RAISE EXCEPTION 'only resolved or closed tickets can be reopened';
    END IF;
    UPDATE public.tickets SET status = 'open', reopened_at = now(),
      resolution_confirmed_at = NULL, updated_by = v_uid
    WHERE id = p_ticket_id RETURNING * INTO v_ticket;
  ELSE
    RAISE EXCEPTION 'invalid action';
  END IF;
  RETURN to_jsonb(v_ticket);
END;
$$;

-- Force authenticated ticket writes through validated RPCs.
REVOKE ALL ON TABLE public.tickets FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON TABLE public.tickets FROM authenticated;
GRANT SELECT ON TABLE public.tickets TO authenticated;

REVOKE ALL ON FUNCTION public.create_support_ticket(
  text, text, text, text, uuid, uuid, text, text, uuid, text, text, text
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_support_ticket(
  text, text, text, text, uuid, uuid, text, text, uuid, text, text, text
) TO authenticated;
REVOKE ALL ON FUNCTION public.manage_support_ticket(
  uuid, text, text, text, uuid, uuid, uuid, uuid, uuid, text
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.manage_support_ticket(
  uuid, text, text, text, uuid, uuid, uuid, uuid, uuid, text
) TO authenticated;
REVOKE ALL ON FUNCTION public.customer_transition_support_ticket(uuid, text)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.customer_transition_support_ticket(uuid, text)
  TO authenticated;
