-- CPMS live publish: push construction_projects progress to
-- website_construction_updates + legacy projects/construction_updates.

CREATE OR REPLACE FUNCTION public.cpms_publish_live_progress(
  p_project_id uuid,
  p_progress_pct numeric DEFAULT NULL,
  p_status_update text DEFAULT NULL,
  p_expected_completion text DEFAULT NULL,
  p_cover_image_url text DEFAULT NULL,
  p_publish_website boolean DEFAULT true,
  p_publish_portals boolean DEFAULT true
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_project public.construction_projects%ROWTYPE;
  v_progress numeric;
  v_slug text;
  v_status_update text;
  v_expected text;
  v_phase_idx int;
  v_website_id uuid;
  v_legacy_project_id uuid;
  v_update_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;

  IF NOT (
    public.has_permission('construction.write', v_uid)
    OR public.has_permission('construction.projects', v_uid)
    OR public.has_permission('manage_construction', v_uid)
    OR public.has_role('super_admin', v_uid)
    OR public.has_role('admin', v_uid)
  ) THEN
    RAISE EXCEPTION 'insufficient permissions';
  END IF;

  SELECT * INTO v_project
  FROM public.construction_projects
  WHERE id = p_project_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'construction project not found';
  END IF;

  v_progress := COALESCE(p_progress_pct, v_project.progress_pct, 0);
  IF v_progress < 0 THEN v_progress := 0; END IF;
  IF v_progress > 100 THEN v_progress := 100; END IF;

  UPDATE public.construction_projects
  SET
    progress_pct = v_progress,
    updated_at = now(),
    metadata = COALESCE(metadata, '{}'::jsonb)
      || jsonb_build_object(
        'last_published_at', now(),
        'last_published_by', v_uid
      )
  WHERE id = v_project.id
  RETURNING * INTO v_project;

  v_slug := lower(regexp_replace(COALESCE(NULLIF(v_project.project_code, ''), v_project.name), '[^a-zA-Z0-9]+', '-', 'g'));
  v_slug := trim(both '-' from v_slug);
  IF v_slug = '' THEN
    v_slug := replace(v_project.id::text, '-', '');
  END IF;

  v_status_update := COALESCE(
    NULLIF(trim(p_status_update), ''),
    format('%s is %s%% complete', v_project.name, round(v_progress)::text)
  );
  v_expected := COALESCE(
    NULLIF(trim(p_expected_completion), ''),
    CASE
      WHEN v_project.target_end_date IS NOT NULL THEN to_char(v_project.target_end_date, 'Mon YYYY')
      ELSE 'On programme'
    END
  );
  v_phase_idx := LEAST(5, GREATEST(0, floor(v_progress / 20.0)::int));

  IF COALESCE(p_publish_website, true) THEN
    SELECT id INTO v_website_id
    FROM public.website_construction_updates
    WHERE slug = v_slug AND COALESCE(is_deleted, false) = false
    LIMIT 1;

    IF v_website_id IS NULL THEN
      INSERT INTO public.website_construction_updates (
        project_name, slug, status_update, expected_completion,
        progress_pct, current_phase_index, cover_image_url,
        sort_order, status, is_deleted
      ) VALUES (
        v_project.name,
        v_slug,
        v_status_update,
        v_expected,
        v_progress,
        v_phase_idx,
        p_cover_image_url,
        10,
        'active',
        false
      )
      RETURNING id INTO v_website_id;
    ELSE
      UPDATE public.website_construction_updates
      SET
        project_name = v_project.name,
        status_update = v_status_update,
        expected_completion = v_expected,
        progress_pct = v_progress,
        current_phase_index = v_phase_idx,
        cover_image_url = COALESCE(p_cover_image_url, cover_image_url),
        status = 'active',
        is_deleted = false,
        updated_at = now()
      WHERE id = v_website_id;
    END IF;
  END IF;

  IF COALESCE(p_publish_portals, true) THEN
    -- Prefer legacy project linked by property/estate, else by name.
    SELECT id INTO v_legacy_project_id
    FROM public.projects
    WHERE COALESCE(is_deleted, false) = false
      AND (
        (v_project.property_id IS NOT NULL AND property_id = v_project.property_id)
        OR (v_project.estate_id IS NOT NULL AND estate_id = v_project.estate_id)
        OR lower(name) = lower(v_project.name)
      )
    ORDER BY updated_at DESC NULLS LAST
    LIMIT 1;

    IF v_legacy_project_id IS NULL THEN
      INSERT INTO public.projects (
        name, property_id, estate_id, completion_percent, status, is_deleted
      ) VALUES (
        v_project.name,
        v_project.property_id,
        v_project.estate_id,
        v_progress,
        'active',
        false
      )
      RETURNING id INTO v_legacy_project_id;
    ELSE
      UPDATE public.projects
      SET
        completion_percent = v_progress,
        property_id = COALESCE(property_id, v_project.property_id),
        estate_id = COALESCE(estate_id, v_project.estate_id),
        status = 'active',
        updated_at = now()
      WHERE id = v_legacy_project_id;
    END IF;

    INSERT INTO public.construction_updates (
      project_id, title, description, completion_percent, update_date, status, is_deleted
    ) VALUES (
      v_legacy_project_id,
      v_status_update,
      v_expected,
      v_progress,
      CURRENT_DATE,
      'active',
      false
    )
    RETURNING id INTO v_update_id;
  END IF;

  BEGIN
    INSERT INTO public.project_activity_logs (
      project_id, event_type, title, description, actor_label, metadata
    ) VALUES (
      v_project.id,
      'publish_live',
      format('Published live progress at %s%%', round(v_progress)::text),
      v_status_update,
      'Construction Desk',
      jsonb_build_object(
        'website_id', v_website_id,
        'legacy_project_id', v_legacy_project_id,
        'update_id', v_update_id
      )
    );
  EXCEPTION WHEN OTHERS THEN
    NULL; -- activity log is best-effort
  END;

  RETURN jsonb_build_object(
    'project_id', v_project.id,
    'progress_pct', v_progress,
    'website_update_id', v_website_id,
    'legacy_project_id', v_legacy_project_id,
    'construction_update_id', v_update_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.cpms_publish_live_progress(
  uuid, numeric, text, text, text, boolean, boolean
) TO authenticated;

-- Ensure realtime publication includes portal/public tables used by publish.
DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.website_construction_updates;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.construction_updates;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.construction_projects;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
END $$;
