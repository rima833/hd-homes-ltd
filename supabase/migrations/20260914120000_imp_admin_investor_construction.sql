-- Admin-readable construction progress for a specific investor (via holdings → properties).
CREATE OR REPLACE FUNCTION public.admin_get_investor_construction(p_investor_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_can boolean;
  v_property_ids uuid[];
BEGIN
  IF p_investor_id IS NULL THEN
    RAISE EXCEPTION 'investor id required';
  END IF;

  v_can := public.has_permission('investors.read', auth.uid())
    OR public.has_permission('construction.read', auth.uid())
    OR public.has_role('super_admin', auth.uid());
  IF NOT v_can THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  SELECT coalesce(array_agg(DISTINCT h.property_id), ARRAY[]::uuid[])
  INTO v_property_ids
  FROM public.portfolio_holdings h
  JOIN public.investor_portfolios p ON p.id = h.portfolio_id
  WHERE p.investor_id = p_investor_id
    AND h.property_id IS NOT NULL
    AND coalesce(h.is_deleted, false) = false;

  IF coalesce(cardinality(v_property_ids), 0) = 0 THEN
    RETURN jsonb_build_object(
      'projects', '[]'::jsonb,
      'updates', '[]'::jsonb,
      'overall_percent', 0
    );
  END IF;

  RETURN jsonb_build_object(
    'projects', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'id', cp.id,
        'name', cp.name,
        'property_id', cp.property_id,
        'progress_pct', coalesce(cp.progress_pct, 0),
        'status', cp.status,
        'schedule_status', cp.schedule_status,
        'target_end_date', cp.target_end_date,
        'cover_image_url', cp.cover_image_url
      ) ORDER BY cp.name)
      FROM public.construction_projects cp
      WHERE cp.property_id = ANY (v_property_ids)
        AND coalesce(cp.is_deleted, false) = false
    ), '[]'::jsonb),
    'updates', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'id', u.id,
        'project_id', u.project_id,
        'project_name', cp.name,
        'title', u.title,
        'short_description', u.short_description,
        'progress_pct', u.progress_pct,
        'published_at', u.published_at
      ) ORDER BY u.published_at DESC NULLS LAST)
      FROM (
        SELECT u.*
        FROM public.construction_progress_updates u
        WHERE u.project_id IN (
          SELECT cp.id
          FROM public.construction_projects cp
          WHERE cp.property_id = ANY (v_property_ids)
            AND coalesce(cp.is_deleted, false) = false
        )
          AND coalesce(u.is_published, false) = true
          AND coalesce(u.is_deleted, false) = false
          AND u.visibility @> ARRAY['investors']::text[]
        ORDER BY u.published_at DESC NULLS LAST
        LIMIT 20
      ) u
      JOIN public.construction_projects cp ON cp.id = u.project_id
    ), '[]'::jsonb),
    'overall_percent', coalesce((
      SELECT round(avg(coalesce(cp.progress_pct, 0))::numeric, 1)
      FROM public.construction_projects cp
      WHERE cp.property_id = ANY (v_property_ids)
        AND coalesce(cp.is_deleted, false) = false
    ), 0)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_get_investor_construction(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_get_investor_construction(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.admin_get_investor_construction(uuid) TO authenticated;
