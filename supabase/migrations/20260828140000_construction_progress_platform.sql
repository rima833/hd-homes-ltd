-- Unified construction progress platform: single source of truth anchored on construction_projects.

-- ---------------------------------------------------------------------------
-- Extend canonical project table
-- ---------------------------------------------------------------------------
ALTER TABLE public.construction_projects
  ADD COLUMN IF NOT EXISTS slug text,
  ADD COLUMN IF NOT EXISTS cover_image_url text,
  ADD COLUMN IF NOT EXISTS is_featured boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_published_public boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS schedule_status text NOT NULL DEFAULT 'on_track'
    CHECK (schedule_status IN ('on_track','ahead','at_risk','delayed')),
  ADD COLUMN IF NOT EXISTS legacy_project_id uuid REFERENCES public.projects(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS delay_reason text,
  ADD COLUMN IF NOT EXISTS delay_public_message text;

CREATE UNIQUE INDEX IF NOT EXISTS construction_projects_slug_uidx
  ON public.construction_projects (slug)
  WHERE slug IS NOT NULL AND slug <> '';

UPDATE public.construction_projects
SET slug = lower(regexp_replace(COALESCE(NULLIF(project_code, ''), name), '[^a-zA-Z0-9]+', '-', 'g'))
WHERE slug IS NULL OR slug = '';

UPDATE public.construction_projects
SET slug = replace(id::text, '-', '')
WHERE slug IS NULL OR trim(slug) = '';

-- ---------------------------------------------------------------------------
-- Unified construction updates (admin source of truth for feed items)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.construction_progress_updates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES public.construction_projects(id) ON DELETE CASCADE,
  phase_id uuid REFERENCES public.project_phases(id) ON DELETE SET NULL,
  milestone_id uuid REFERENCES public.project_milestones(id) ON DELETE SET NULL,
  title text NOT NULL,
  short_description text,
  description text,
  progress_pct numeric(5,2),
  update_date date NOT NULL DEFAULT CURRENT_DATE,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','published','archived')),
  visibility text[] NOT NULL DEFAULT ARRAY['internal']::text[],
  is_published boolean NOT NULL DEFAULT false,
  published_at timestamptz,
  internal_notes text,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  updated_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  is_deleted boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT construction_progress_updates_visibility_chk CHECK (
    visibility <@ ARRAY['public','clients','investors','internal']::text[]
  )
);

CREATE INDEX IF NOT EXISTS construction_progress_updates_project_idx
  ON public.construction_progress_updates (project_id, update_date DESC)
  WHERE COALESCE(is_deleted, false) = false;

CREATE INDEX IF NOT EXISTS construction_progress_updates_published_idx
  ON public.construction_progress_updates (published_at DESC)
  WHERE is_published = true AND COALESCE(is_deleted, false) = false;

-- ---------------------------------------------------------------------------
-- Media per update
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.construction_update_media (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  update_id uuid NOT NULL REFERENCES public.construction_progress_updates(id) ON DELETE CASCADE,
  project_id uuid NOT NULL REFERENCES public.construction_projects(id) ON DELETE CASCADE,
  media_type text NOT NULL DEFAULT 'image'
    CHECK (media_type IN ('image','video')),
  file_url text NOT NULL,
  thumbnail_url text,
  caption text,
  display_order int NOT NULL DEFAULT 0,
  uploaded_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  is_deleted boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS construction_update_media_update_idx
  ON public.construction_update_media (update_id, display_order)
  WHERE COALESCE(is_deleted, false) = false;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.construction_project_slug(p_code text, p_name text, p_id uuid)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT COALESCE(
    NULLIF(trim(both '-' from lower(regexp_replace(COALESCE(NULLIF(trim(p_code), ''), trim(p_name)), '[^a-zA-Z0-9]+', '-', 'g'))), ''),
    replace(p_id::text, '-', '')
  );
$$;

CREATE OR REPLACE FUNCTION public.construction_sync_legacy_project(p_project_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cp public.construction_projects%ROWTYPE;
  v_legacy uuid;
BEGIN
  SELECT * INTO v_cp FROM public.construction_projects WHERE id = p_project_id;
  IF NOT FOUND THEN RETURN NULL; END IF;

  IF v_cp.legacy_project_id IS NOT NULL THEN
    UPDATE public.projects
    SET
      name = v_cp.name,
      completion_percent = v_cp.progress_pct,
      property_id = COALESCE(property_id, v_cp.property_id),
      estate_id = COALESCE(estate_id, v_cp.estate_id),
      expected_end_date = v_cp.target_end_date,
      status = CASE WHEN v_cp.status = 'completed' THEN 'completed' ELSE 'active' END,
      updated_at = now()
    WHERE id = v_cp.legacy_project_id;
    RETURN v_cp.legacy_project_id;
  END IF;

  SELECT id INTO v_legacy
  FROM public.projects
  WHERE COALESCE(is_deleted, false) = false
    AND (
      (v_cp.property_id IS NOT NULL AND property_id = v_cp.property_id)
      OR (v_cp.estate_id IS NOT NULL AND estate_id = v_cp.estate_id)
      OR lower(name) = lower(v_cp.name)
    )
  ORDER BY updated_at DESC NULLS LAST
  LIMIT 1;

  IF v_legacy IS NULL THEN
    INSERT INTO public.projects (name, property_id, estate_id, completion_percent, status, is_deleted)
    VALUES (v_cp.name, v_cp.property_id, v_cp.estate_id, v_cp.progress_pct, 'active', false)
    RETURNING id INTO v_legacy;
  END IF;

  UPDATE public.construction_projects SET legacy_project_id = v_legacy WHERE id = p_project_id;
  RETURN v_legacy;
END;
$$;

-- Publish a construction progress update to all surfaces
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

    -- Sync milestones to legacy for investor Gantt
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

GRANT EXECUTE ON FUNCTION public.construction_publish_update(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.construction_sync_legacy_project(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- RLS: construction_progress_updates + media
-- ---------------------------------------------------------------------------
ALTER TABLE public.construction_progress_updates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.construction_update_media ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS construction_progress_updates_staff ON public.construction_progress_updates;
CREATE POLICY construction_progress_updates_staff ON public.construction_progress_updates FOR ALL
  USING (
    public.has_permission('construction.write', auth.uid())
    OR public.has_permission('construction.projects', auth.uid())
    OR public.has_permission('manage_construction', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR public.has_role('admin', auth.uid())
  )
  WITH CHECK (true);

DROP POLICY IF EXISTS construction_progress_updates_public_read ON public.construction_progress_updates;
CREATE POLICY construction_progress_updates_public_read ON public.construction_progress_updates FOR SELECT
  USING (
    is_published = true
    AND COALESCE(is_deleted, false) = false
    AND 'public' = ANY(visibility)
  );

DROP POLICY IF EXISTS construction_progress_updates_client_read ON public.construction_progress_updates;
CREATE POLICY construction_progress_updates_client_read ON public.construction_progress_updates FOR SELECT
  USING (
    is_published = true
    AND COALESCE(is_deleted, false) = false
    AND 'clients' = ANY(visibility)
    AND EXISTS (
      SELECT 1 FROM public.construction_projects cp
      JOIN public.client_properties cprop ON cprop.property_id = cp.property_id
      JOIN public.clients c ON c.id = cprop.client_id
      WHERE cp.id = construction_progress_updates.project_id
        AND c.user_id = auth.uid()
        AND COALESCE(cprop.is_deleted, false) = false
    )
  );

DROP POLICY IF EXISTS construction_progress_updates_investor_read ON public.construction_progress_updates;
CREATE POLICY construction_progress_updates_investor_read ON public.construction_progress_updates FOR SELECT
  USING (
    is_published = true
    AND COALESCE(is_deleted, false) = false
    AND 'investors' = ANY(visibility)
    AND EXISTS (
      SELECT 1 FROM public.construction_projects cp
      JOIN public.portfolio_holdings h ON h.property_id = cp.property_id
      JOIN public.investor_portfolios ip ON ip.id = h.portfolio_id
      JOIN public.investors inv ON inv.id = ip.investor_id
      WHERE cp.id = construction_progress_updates.project_id
        AND inv.user_id = auth.uid()
        AND COALESCE(inv.is_deleted, false) = false
    )
  );

DROP POLICY IF EXISTS construction_update_media_staff ON public.construction_update_media;
CREATE POLICY construction_update_media_staff ON public.construction_update_media FOR ALL
  USING (
    public.has_permission('construction.write', auth.uid())
    OR public.has_permission('manage_construction', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (true);

DROP POLICY IF EXISTS construction_update_media_public_read ON public.construction_update_media;
CREATE POLICY construction_update_media_public_read ON public.construction_update_media FOR SELECT
  USING (
    COALESCE(is_deleted, false) = false
    AND EXISTS (
      SELECT 1 FROM public.construction_progress_updates u
      WHERE u.id = construction_update_media.update_id
        AND u.is_published = true
        AND COALESCE(u.is_deleted, false) = false
        AND 'public' = ANY(u.visibility)
    )
  );

-- Public read on published construction projects
DROP POLICY IF EXISTS construction_projects_public_read ON public.construction_projects;
CREATE POLICY construction_projects_public_read ON public.construction_projects FOR SELECT
  USING (is_published_public = true);

-- Tighten legacy media RLS (replace world-readable)
DROP POLICY IF EXISTS construction_photos_read ON public.construction_photos;
CREATE POLICY construction_photos_read ON public.construction_photos FOR SELECT
  USING (
    public.has_permission('manage_construction', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR public.has_role('admin', auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.construction_updates cu
      JOIN public.projects p ON p.id = cu.project_id
      JOIN public.client_properties cp ON cp.property_id = p.property_id
      JOIN public.clients c ON c.id = cp.client_id
      WHERE cu.id = construction_photos.update_id AND c.user_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.construction_updates cu
      JOIN public.projects p ON p.id = cu.project_id
      JOIN public.portfolio_holdings h ON h.property_id = p.property_id
      JOIN public.investor_portfolios ip ON ip.id = h.portfolio_id
      JOIN public.investors inv ON inv.id = ip.investor_id
      WHERE cu.id = construction_photos.update_id AND inv.user_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.construction_progress_updates u
      JOIN public.construction_update_media m ON m.update_id = u.id
      WHERE m.file_url = construction_photos.url
        AND u.is_published = true AND 'public' = ANY(u.visibility)
    )
  );

-- Realtime
DO $$
BEGIN
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.construction_progress_updates; EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.construction_update_media; EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;
