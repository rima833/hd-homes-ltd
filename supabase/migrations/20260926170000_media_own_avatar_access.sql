-- Allow portal users to manage their own avatar media rows and set cover.
-- Clients/investors were blocked by staff-only media RLS and set_entity_cover_media.

DROP POLICY IF EXISTS media_own_avatar ON public.media;
CREATE POLICY media_own_avatar ON public.media
  FOR ALL
  USING (
    entity_type = 'user'
    AND entity_id = auth.uid()
    AND is_deleted = false
  )
  WITH CHECK (
    entity_type = 'user'
    AND entity_id = auth.uid()
  );

CREATE OR REPLACE FUNCTION public.set_entity_cover_media(
  p_entity_type TEXT,
  p_entity_id UUID,
  p_media_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT (
    public.has_permission('marketing.media')
    OR public.has_permission('manage_marketing')
    OR public.has_permission('edit_property')
    OR public.is_staff()
    OR (
      p_entity_type = 'user'
      AND p_entity_id = auth.uid()
    )
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  UPDATE public.media
  SET is_cover = false, updated_at = now()
  WHERE entity_type = p_entity_type
    AND entity_id = p_entity_id
    AND is_deleted = false;

  UPDATE public.media
  SET is_cover = true, updated_at = now()
  WHERE id = p_media_id
    AND entity_type = p_entity_type
    AND entity_id = p_entity_id
    AND is_deleted = false;
END;
$$;

-- Own-avatar soft-delete: also allow entity owner (not only uploaded_by).
CREATE OR REPLACE FUNCTION public.soft_delete_media(p_media_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT (
    public.has_permission('marketing.media')
    OR public.has_permission('manage_marketing')
    OR public.has_permission('edit_property')
    OR public.has_permission('manage_construction')
    OR public.is_staff()
    OR EXISTS (
      SELECT 1 FROM public.media m
      WHERE m.id = p_media_id
        AND (
          m.uploaded_by = auth.uid()
          OR (m.entity_type = 'user' AND m.entity_id = auth.uid())
        )
    )
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  UPDATE public.media
  SET
    is_deleted = true,
    is_active = false,
    deleted_at = now(),
    updated_at = now()
  WHERE id = p_media_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_entity_cover_media(TEXT, UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.soft_delete_media(UUID) TO authenticated;
