-- IMP: include construction update media thumbs for admin 360,
-- and revoke anon EXECUTE on investor admin SECURITY DEFINER RPCs.

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
        'published_at', u.published_at,
        'media', coalesce((
          SELECT jsonb_agg(jsonb_build_object(
            'id', m.id,
            'media_type', coalesce(m.media_type, 'image'),
            'file_url', coalesce(med.secure_url, m.file_url),
            'thumbnail_url', coalesce(
              nullif(m.thumbnail_url, ''),
              med.thumbnail_url,
              med.secure_url,
              m.file_url
            )
          ) ORDER BY coalesce(m.display_order, 0), m.created_at)
          FROM public.construction_update_media m
          LEFT JOIN public.media med ON med.id = m.media_id
          WHERE m.update_id = u.id
            AND coalesce(m.is_deleted, false) = false
        ), '[]'::jsonb)
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

-- Hygiene: staff-only DEFINER RPCs must not be executable by anon.
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT p.oid,
           format(
             '%I.%I(%s)',
             n.nspname,
             p.proname,
             pg_get_function_identity_arguments(p.oid)
           ) AS signature
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND (
        p.proname LIKE 'admin\_%investor%' ESCAPE '\'
        OR p.proname LIKE 'admin\_%investment%' ESCAPE '\'
        OR p.proname = 'admin_link_website_investment_opportunity'
        OR p.proname = 'admin_publish_document_to_investor'
      )
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC', r.signature);
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM anon', r.signature);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', r.signature);
  END LOOP;
END;
$$;
