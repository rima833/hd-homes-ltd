-- Notify clients and investors when a construction update is published.

CREATE OR REPLACE FUNCTION public.construction_publish_update(p_update_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_upd public.construction_progress_updates%ROWTYPE;
  v_cp public.construction_projects%ROWTYPE;
  v_legacy uuid;
  v_legacy_update uuid;
  v_slug text;
  v_phase_idx int;
  v_phases jsonb;
  v_gallery jsonb := '[]'::jsonb;
  v_cover text;
  v_expected text;
  v_media record;
  v_title text;
  v_body text;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;
  IF NOT (
    public.has_permission('construction.write', v_uid)
    OR public.has_permission('construction.projects', v_uid)
    OR public.has_permission('manage_construction', v_uid)
    OR public.has_role('super_admin', v_uid)
    OR public.has_role('admin', v_uid)
  ) THEN
    RAISE EXCEPTION 'insufficient permissions';
  END IF;

  SELECT * INTO v_upd FROM public.construction_progress_updates WHERE id = p_update_id AND COALESCE(is_deleted, false) = false;
  IF NOT FOUND THEN RAISE EXCEPTION 'update not found'; END IF;

  SELECT * INTO v_cp FROM public.construction_projects WHERE id = v_upd.project_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'project not found'; END IF;

  UPDATE public.construction_progress_updates
  SET status = 'published', is_published = true, published_at = now(), updated_by = v_uid, updated_at = now()
  WHERE id = p_update_id
  RETURNING * INTO v_upd;

  IF v_upd.progress_pct IS NOT NULL THEN
    UPDATE public.construction_projects
    SET progress_pct = v_upd.progress_pct, updated_at = now()
    WHERE id = v_cp.id
    RETURNING * INTO v_cp;
  END IF;

  v_slug := COALESCE(v_cp.slug, public.construction_project_slug(v_cp.project_code, v_cp.name, v_cp.id));
  v_expected := COALESCE(to_char(v_cp.target_end_date, 'Mon YYYY'), 'On programme');
  v_phase_idx := LEAST(5, GREATEST(0, floor(v_cp.progress_pct / 20.0)::int));
  v_title := 'Construction update';
  v_body := v_cp.name || ' — ' || COALESCE(v_upd.short_description, v_upd.title);

  SELECT COALESCE(jsonb_agg(pm.name ORDER BY pm.due_date NULLS LAST, pm.created_at), '[]'::jsonb)
  INTO v_phases
  FROM public.project_milestones pm
  WHERE pm.project_id = v_cp.id;

  IF jsonb_array_length(v_phases) = 0 THEN
    v_phases := '["Planning","Foundation","Structure","Roofing","Finishing","Completed"]'::jsonb;
  END IF;

  SELECT file_url INTO v_cover
  FROM public.construction_update_media
  WHERE update_id = p_update_id AND COALESCE(is_deleted, false) = false AND media_type = 'image'
  ORDER BY display_order
  LIMIT 1;

  SELECT COALESCE(jsonb_agg(file_url ORDER BY display_order), '[]'::jsonb)
  INTO v_gallery
  FROM public.construction_update_media
  WHERE update_id = p_update_id AND COALESCE(is_deleted, false) = false AND media_type = 'image';

  IF 'public' = ANY(v_upd.visibility) OR v_cp.is_published_public THEN
    INSERT INTO public.website_construction_updates (
      project_name, slug, status_update, expected_completion,
      progress_pct, current_phase_index, phases, cover_image_url, gallery_image_urls,
      sort_order, status, is_deleted
    ) VALUES (
      v_cp.name, v_slug,
      COALESCE(v_upd.short_description, v_upd.title),
      v_expected, v_cp.progress_pct, v_phase_idx, v_phases,
      COALESCE(v_cover, v_cp.cover_image_url), v_gallery,
      10, 'active', false
    )
    ON CONFLICT (slug) DO UPDATE SET
      project_name = EXCLUDED.project_name,
      status_update = EXCLUDED.status_update,
      expected_completion = EXCLUDED.expected_completion,
      progress_pct = EXCLUDED.progress_pct,
      current_phase_index = EXCLUDED.current_phase_index,
      phases = EXCLUDED.phases,
      cover_image_url = COALESCE(EXCLUDED.cover_image_url, public.website_construction_updates.cover_image_url),
      gallery_image_urls = CASE WHEN jsonb_array_length(EXCLUDED.gallery_image_urls) > 0 THEN EXCLUDED.gallery_image_urls ELSE public.website_construction_updates.gallery_image_urls END,
      status = 'active', is_deleted = false, updated_at = now();
  END IF;

  IF 'clients' = ANY(v_upd.visibility) OR 'investors' = ANY(v_upd.visibility) THEN
    v_legacy := public.construction_sync_legacy_project(v_cp.id);

    INSERT INTO public.construction_updates (
      project_id, title, description, completion_percent, update_date, status, is_deleted
    ) VALUES (
      v_legacy,
      v_upd.title,
      COALESCE(v_upd.description, v_upd.short_description),
      COALESCE(v_upd.progress_pct, v_cp.progress_pct),
      v_upd.update_date,
      'active', false
    )
    RETURNING id INTO v_legacy_update;

    FOR v_media IN
      SELECT file_url, caption FROM public.construction_update_media
      WHERE update_id = p_update_id AND COALESCE(is_deleted, false) = false
      ORDER BY display_order
    LOOP
      IF v_media.file_url IS NOT NULL AND trim(v_media.file_url) <> '' THEN
        INSERT INTO public.construction_photos (update_id, url, caption, created_by, updated_by)
        VALUES (v_legacy_update, v_media.file_url, v_media.caption, v_uid, v_uid);
      END IF;
    END LOOP;

    DELETE FROM public.milestones WHERE project_id = v_legacy;
    INSERT INTO public.milestones (project_id, name, description, target_date, completed_at, sort_order, status, is_deleted)
    SELECT
      v_legacy,
      pm.name,
      pm.notes,
      pm.due_date::date,
      pm.completed_at,
      row_number() OVER (ORDER BY pm.due_date NULLS LAST, pm.created_at) - 1,
      CASE pm.status WHEN 'completed' THEN 'completed' WHEN 'in_progress' THEN 'in_progress' ELSE 'pending' END,
      false
    FROM public.project_milestones pm
    WHERE pm.project_id = v_cp.id;
  END IF;

  IF 'clients' = ANY(v_upd.visibility) AND v_cp.property_id IS NOT NULL THEN
    INSERT INTO public.notifications (
      user_id, title, body, channel, category, type, priority,
      action_url, metadata, is_read, delivery_status
    )
    SELECT DISTINCT
      c.user_id,
      v_title,
      v_body,
      'in_app',
      'construction',
      'information',
      'normal',
      '/client/construction',
      jsonb_build_object('update_id', p_update_id, 'project_id', v_cp.id, 'slug', v_slug),
      false,
      'delivered'
    FROM public.clients c
    JOIN public.client_properties cprop ON cprop.client_id = c.id
    WHERE cprop.property_id = v_cp.property_id
      AND COALESCE(cprop.is_deleted, false) = false
      AND c.user_id IS NOT NULL
      AND COALESCE(c.is_deleted, false) = false;
  END IF;

  IF 'investors' = ANY(v_upd.visibility) AND v_cp.property_id IS NOT NULL THEN
    INSERT INTO public.investor_notifications (investor_id, channel, title, body, is_read, sent_at, metadata)
    SELECT DISTINCT
      inv.id,
      'in_app',
      v_title,
      v_body,
      false,
      now(),
      jsonb_build_object(
        'update_id', p_update_id,
        'project_id', v_cp.id,
        'slug', v_slug,
        'category', 'construction',
        'route', '/investor/construction'
      )
    FROM public.investors inv
    JOIN public.investor_portfolios ip ON ip.investor_id = inv.id
    JOIN public.portfolio_holdings h ON h.portfolio_id = ip.id
    WHERE h.property_id = v_cp.property_id
      AND COALESCE(inv.is_deleted, false) = false;
  END IF;

  INSERT INTO public.project_activity_logs (project_id, event_type, title, description, actor_label, metadata)
  VALUES (
    v_cp.id, 'publish_update', 'Published construction update', v_upd.title, 'Construction Desk',
    jsonb_build_object('update_id', p_update_id, 'visibility', v_upd.visibility)
  );

  RETURN jsonb_build_object(
    'update_id', p_update_id,
    'project_id', v_cp.id,
    'slug', v_slug,
    'legacy_project_id', v_legacy
  );
END;
$$;
