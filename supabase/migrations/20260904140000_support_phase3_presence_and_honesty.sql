-- Support Phase 3: agent presence + honest escalations + session updated_at.

ALTER TABLE public.support_agents
  ADD COLUMN IF NOT EXISTS last_seen_at timestamptz;

ALTER TABLE public.live_chat_sessions
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

-- Seed escalations are demo desk noise.
UPDATE public.support_escalations
SET metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object('demo', true)
WHERE id IN (
  'f110000c-0000-4000-8000-000000000001',
  'f110000c-0000-4000-8000-000000000002'
);

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
    OR public.has_role('super_admin', v_uid)
  ) THEN
    RAISE EXCEPTION 'insufficient permissions';
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

GRANT EXECUTE ON FUNCTION public.set_my_support_agent_presence(text) TO authenticated;

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
    OR public.has_role('super_admin', v_uid)
  ) THEN
    RAISE EXCEPTION 'insufficient permissions';
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

GRANT EXECUTE ON FUNCTION public.heartbeat_my_support_agent() TO authenticated;

-- Do not force available forever on ensure; presence RPCs own status.
CREATE OR REPLACE FUNCTION public.ensure_my_support_agent()
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_agent_id uuid;
  v_name text;
  v_email text;
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
    RAISE EXCEPTION 'insufficient permissions';
  END IF;

  SELECT id INTO v_agent_id
  FROM public.support_agents
  WHERE profile_id = v_uid
  LIMIT 1;

  IF v_agent_id IS NOT NULL THEN
    UPDATE public.support_agents
    SET is_active = true, updated_at = now()
    WHERE id = v_agent_id;
    RETURN v_agent_id;
  END IF;

  SELECT
    COALESCE(NULLIF(trim(full_name), ''), NULLIF(trim(email), ''), 'Agent'),
    email
  INTO v_name, v_email
  FROM public.profiles
  WHERE id = v_uid;

  INSERT INTO public.support_agents (
    profile_id, display_name, email, role_title, status, is_active, metadata, last_seen_at
  ) VALUES (
    v_uid,
    COALESCE(v_name, 'Agent'),
    v_email,
    'Agent',
    'offline',
    true,
    jsonb_build_object('source', 'auto_ensure'),
    NULL
  )
  RETURNING id INTO v_agent_id;

  RETURN v_agent_id;
END;
$$;

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'support_agents',
    'support_knowledge_articles',
    'support_escalations'
  ]
  LOOP
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
  END LOOP;
END $$;
