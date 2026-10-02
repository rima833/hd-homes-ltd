-- Allow ticket agents and super_admin to register live-chat presence.
CREATE OR REPLACE FUNCTION public.set_my_support_agent_presence(p_status text)
RETURNS public.support_agents
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_agent_id uuid;
  v_status text := lower(trim(COALESCE(p_status, 'available')));
  v_row public.support_agents;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;

  IF v_status NOT IN ('available', 'busy', 'away', 'offline') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;

  IF NOT (
    public.has_permission('support.chat', v_uid)
    OR public.has_permission('support.write', v_uid)
    OR public.has_permission('support.tickets', v_uid)
    OR public.has_role('super_admin', v_uid)
  ) THEN
    RAISE EXCEPTION 'insufficient permissions for support presence';
  END IF;

  v_agent_id := public.ensure_my_support_agent();

  UPDATE public.support_agents
  SET
    status = v_status,
    last_seen_at = CASE
      WHEN v_status IN ('available', 'busy') THEN now()
      ELSE last_seen_at
    END,
    updated_at = now()
  WHERE id = v_agent_id
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.heartbeat_my_support_agent()
RETURNS public.support_agents
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_agent_id uuid;
  v_row public.support_agents;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;

  IF NOT (
    public.has_permission('support.chat', v_uid)
    OR public.has_permission('support.write', v_uid)
    OR public.has_permission('support.tickets', v_uid)
    OR public.has_role('super_admin', v_uid)
  ) THEN
    RAISE EXCEPTION 'insufficient permissions for support presence';
  END IF;

  v_agent_id := public.ensure_my_support_agent();

  UPDATE public.support_agents
  SET
    status = CASE
      WHEN status IN ('offline', 'away') THEN 'available'
      ELSE status
    END,
    last_seen_at = now(),
    updated_at = now()
  WHERE id = v_agent_id
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;
