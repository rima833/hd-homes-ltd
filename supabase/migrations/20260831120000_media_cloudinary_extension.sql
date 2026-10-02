-- Extend public.media for Cloudinary + polymorphic entity linking.
-- Does NOT drop or replace existing columns/tables/buckets.

ALTER TABLE public.media
  ADD COLUMN IF NOT EXISTS entity_type TEXT,
  ADD COLUMN IF NOT EXISTS entity_id UUID,
  ADD COLUMN IF NOT EXISTS storage_provider TEXT NOT NULL DEFAULT 'supabase',
  ADD COLUMN IF NOT EXISTS cloudinary_public_id TEXT,
  ADD COLUMN IF NOT EXISTS resource_type TEXT,
  ADD COLUMN IF NOT EXISTS secure_url TEXT,
  ADD COLUMN IF NOT EXISTS thumbnail_url TEXT,
  ADD COLUMN IF NOT EXISTS original_filename TEXT,
  ADD COLUMN IF NOT EXISTS duration NUMERIC,
  ADD COLUMN IF NOT EXISTS folder TEXT,
  ADD COLUMN IF NOT EXISTS sort_order INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_cover BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_published BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS uploaded_by UUID REFERENCES auth.users(id);

UPDATE public.media
SET storage_provider = 'supabase'
WHERE storage_provider IS NULL OR storage_provider = '';

CREATE INDEX IF NOT EXISTS idx_media_entity ON public.media (entity_type, entity_id)
  WHERE is_deleted = false;

CREATE INDEX IF NOT EXISTS idx_media_cloudinary_public_id ON public.media (cloudinary_public_id)
  WHERE cloudinary_public_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_media_storage_provider ON public.media (storage_provider);

-- Bridge FKs (optional; legacy url columns remain)
ALTER TABLE public.property_images
  ADD COLUMN IF NOT EXISTS media_id UUID REFERENCES public.media(id) ON DELETE SET NULL;

ALTER TABLE public.estate_images
  ADD COLUMN IF NOT EXISTS media_id UUID REFERENCES public.media(id) ON DELETE SET NULL;

ALTER TABLE public.construction_update_media
  ADD COLUMN IF NOT EXISTS media_id UUID REFERENCES public.media(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_property_images_media_id ON public.property_images (media_id);
CREATE INDEX IF NOT EXISTS idx_estate_images_media_id ON public.estate_images (media_id);
CREATE INDEX IF NOT EXISTS idx_construction_update_media_media_id
  ON public.construction_update_media (media_id);

-- Enriched media library view (backward compatible)
CREATE OR REPLACE VIEW public.media_library AS
SELECT
  m.id,
  m.title,
  m.file_url,
  m.file_type,
  m.mime_type,
  m.file_size,
  m.alt_text,
  m.folder_id,
  f.name AS folder_name,
  m.width,
  m.height,
  m.tags,
  m.status,
  m.is_deleted,
  m.created_at,
  m.updated_at,
  m.entity_type,
  m.entity_id,
  m.storage_provider,
  m.cloudinary_public_id,
  m.resource_type,
  m.secure_url,
  m.thumbnail_url,
  m.original_filename,
  m.duration,
  m.folder,
  m.sort_order,
  m.is_cover,
  m.is_published,
  m.is_active,
  m.uploaded_by,
  COALESCE(NULLIF(m.secure_url, ''), m.file_url) AS delivery_url
FROM public.media m
LEFT JOIN public.media_folders f ON f.id = m.folder_id
WHERE m.is_deleted = false;

GRANT SELECT ON public.media_library TO authenticated;
GRANT SELECT ON public.media_library TO anon;

-- Reorder helper
CREATE OR REPLACE FUNCTION public.reorder_entity_media(
  p_entity_type TEXT,
  p_entity_id UUID,
  p_ordered_ids UUID[]
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  i INT;
BEGIN
  IF NOT (
    public.has_permission('marketing.media')
    OR public.has_permission('manage_marketing')
    OR public.has_permission('edit_property')
    OR public.is_staff()
    OR public.has_permission('manage_construction')
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  FOR i IN 1 .. COALESCE(array_length(p_ordered_ids, 1), 0) LOOP
    UPDATE public.media
    SET sort_order = i - 1, updated_at = now()
    WHERE id = p_ordered_ids[i]
      AND entity_type = p_entity_type
      AND entity_id = p_entity_id
      AND is_deleted = false;
  END LOOP;
END;
$$;

-- Set cover helper
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

-- Tighten anonymous read: published + active public media only.
-- Staff policies unchanged via media_staff.
DROP POLICY IF EXISTS media_public_read ON public.media;
CREATE POLICY media_public_read ON public.media
  FOR SELECT
  USING (
    is_deleted = false
    AND COALESCE(is_active, true) = true
    AND COALESCE(is_published, true) = true
  );

-- Staff retain full access
DROP POLICY IF EXISTS media_staff ON public.media;
CREATE POLICY media_staff ON public.media
  FOR ALL
  USING (
    public.has_permission('manage_marketing')
    OR public.has_permission('marketing.media')
    OR public.has_permission('marketing.write')
    OR public.has_permission('marketing.cms')
    OR public.is_staff()
  )
  WITH CHECK (
    public.has_permission('manage_marketing')
    OR public.has_permission('marketing.media')
    OR public.has_permission('marketing.write')
    OR public.has_permission('marketing.cms')
    OR public.is_staff()
  );

-- Realtime publication (idempotent)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'media'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.media;
  END IF;
END $$;
