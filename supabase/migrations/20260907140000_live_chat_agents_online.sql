-- Public read of whether any support agent is currently present for Live Chat.
CREATE OR REPLACE FUNCTION public.live_chat_agents_online()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'online',
    EXISTS (
      SELECT 1
      FROM public.support_agents a
      WHERE a.is_active IS TRUE
        AND lower(COALESCE(a.status, '')) IN ('available', 'busy')
        AND a.last_seen_at IS NOT NULL
        AND a.last_seen_at > (now() - interval '2 minutes')
    ),
    'agents_present',
    (
      SELECT COUNT(*)::int
      FROM public.support_agents a
      WHERE a.is_active IS TRUE
        AND lower(COALESCE(a.status, '')) IN ('available', 'busy')
        AND a.last_seen_at IS NOT NULL
        AND a.last_seen_at > (now() - interval '2 minutes')
    )
  );
$$;

GRANT EXECUTE ON FUNCTION public.live_chat_agents_online() TO anon, authenticated;
