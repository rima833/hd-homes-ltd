-- Real-time popular property searches: upsert RPC + public list helper.
-- Popular chips on the homepage should only reflect actual user searches.

CREATE UNIQUE INDEX IF NOT EXISTS uq_popular_searches_term_lower
  ON public.popular_searches (lower(search_term))
  WHERE coalesce(is_deleted, false) = false;

CREATE OR REPLACE FUNCTION public.record_popular_search(p_search_term text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_raw text := btrim(coalesce(p_search_term, ''));
  v_key text;
BEGIN
  IF length(v_raw) < 2 OR length(v_raw) > 80 THEN
    RETURN;
  END IF;

  v_key := lower(v_raw);
  IF v_key IN ('null', 'undefined', 'all', 'search', 'n/a', '-') THEN
    RETURN;
  END IF;

  UPDATE public.popular_searches AS ps
  SET
    search_count = ps.search_count + 1,
    last_searched_at = now(),
    updated_at = now(),
    -- Keep a nicer display casing when the stored term looks like a key.
    search_term = CASE
      WHEN ps.search_term = v_key THEN v_raw
      ELSE ps.search_term
    END
  WHERE lower(ps.search_term) = v_key
    AND coalesce(ps.is_deleted, false) = false;

  IF NOT FOUND THEN
    INSERT INTO public.popular_searches (search_term, search_count, last_searched_at)
    VALUES (v_raw, 1, now());
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_popular_searches(p_limit integer DEFAULT 8)
RETURNS TABLE (
  search_term text,
  search_count integer,
  last_searched_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT
    ps.search_term,
    ps.search_count,
    ps.last_searched_at
  FROM public.popular_searches ps
  WHERE coalesce(ps.is_deleted, false) = false
    AND coalesce(ps.status, 'active') = 'active'
    AND ps.search_count > 0
  ORDER BY ps.search_count DESC, ps.last_searched_at DESC NULLS LAST
  LIMIT greatest(1, least(coalesce(p_limit, 8), 24));
$$;

REVOKE ALL ON FUNCTION public.record_popular_search(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.list_popular_searches(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_popular_search(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.list_popular_searches(integer) TO anon, authenticated;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'popular_searches'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.popular_searches;
  END IF;
END;
$$;

COMMENT ON FUNCTION public.record_popular_search(text) IS
  'Increments popular property search terms from public marketplace / home search.';
COMMENT ON FUNCTION public.list_popular_searches(integer) IS
  'Top popular property search terms for public chips (no placeholders).';
