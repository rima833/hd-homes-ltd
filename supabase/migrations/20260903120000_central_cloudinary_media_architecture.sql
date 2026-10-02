-- Phase 2: Central Cloudinary media architecture
-- Extends public.media + attaches media_id to URL-bearing tables.
-- Does NOT drop Storage buckets or delete legacy files.

ALTER TABLE public.media
  ADD COLUMN IF NOT EXISTS cloudinary_asset_id TEXT,
  ADD COLUMN IF NOT EXISTS format TEXT,
  ADD COLUMN IF NOT EXISTS caption TEXT,
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS is_primary BOOLEAN NOT NULL DEFAULT false;

UPDATE public.media
SET is_primary = COALESCE(is_cover, false)
WHERE is_primary IS DISTINCT FROM COALESCE(is_cover, false);

ALTER TABLE public.media
  ALTER COLUMN storage_provider SET DEFAULT 'cloudinary';

CREATE INDEX IF NOT EXISTS idx_media_entity_type_created
  ON public.media (entity_type, created_at DESC)
  WHERE COALESCE(is_deleted, false) = false;

CREATE INDEX IF NOT EXISTS idx_media_owner_uploaded
  ON public.media (uploaded_by, created_at DESC)
  WHERE COALESCE(is_deleted, false) = false;

ALTER TABLE public.blogs ADD COLUMN IF NOT EXISTS media_id UUID REFERENCES public.media(id) ON DELETE SET NULL;
ALTER TABLE public.banners ADD COLUMN IF NOT EXISTS media_id UUID REFERENCES public.media(id) ON DELETE SET NULL;
ALTER TABLE public.hero_sections ADD COLUMN IF NOT EXISTS media_id UUID REFERENCES public.media(id) ON DELETE SET NULL;
ALTER TABLE public.partners ADD COLUMN IF NOT EXISTS media_id UUID REFERENCES public.media(id) ON DELETE SET NULL;
ALTER TABLE public.testimonials ADD COLUMN IF NOT EXISTS media_id UUID REFERENCES public.media(id) ON DELETE SET NULL;
ALTER TABLE public.employees ADD COLUMN IF NOT EXISTS media_id UUID REFERENCES public.media(id) ON DELETE SET NULL;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS media_id UUID REFERENCES public.media(id) ON DELETE SET NULL;
ALTER TABLE public.office_media ADD COLUMN IF NOT EXISTS media_id UUID REFERENCES public.media(id) ON DELETE SET NULL;
ALTER TABLE public.office_locations ADD COLUMN IF NOT EXISTS media_id UUID REFERENCES public.media(id) ON DELETE SET NULL;
ALTER TABLE public.website_construction_updates ADD COLUMN IF NOT EXISTS media_id UUID REFERENCES public.media(id) ON DELETE SET NULL;
ALTER TABLE public.website_investment_opportunities ADD COLUMN IF NOT EXISTS media_id UUID REFERENCES public.media(id) ON DELETE SET NULL;
ALTER TABLE public.website_market_insights ADD COLUMN IF NOT EXISTS media_id UUID REFERENCES public.media(id) ON DELETE SET NULL;
ALTER TABLE public.website_browse_categories ADD COLUMN IF NOT EXISTS media_id UUID REFERENCES public.media(id) ON DELETE SET NULL;
ALTER TABLE public.digital_company_profile ADD COLUMN IF NOT EXISTS media_id UUID REFERENCES public.media(id) ON DELETE SET NULL;
ALTER TABLE public.seo_metadata ADD COLUMN IF NOT EXISTS media_id UUID REFERENCES public.media(id) ON DELETE SET NULL;
ALTER TABLE public.company_statistics ADD COLUMN IF NOT EXISTS media_id UUID REFERENCES public.media(id) ON DELETE SET NULL;
ALTER TABLE public.construction_projects ADD COLUMN IF NOT EXISTS media_id UUID REFERENCES public.media(id) ON DELETE SET NULL;
ALTER TABLE public.careers_settings ADD COLUMN IF NOT EXISTS media_id UUID REFERENCES public.media(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_blogs_media_id ON public.blogs (media_id);
CREATE INDEX IF NOT EXISTS idx_banners_media_id ON public.banners (media_id);
CREATE INDEX IF NOT EXISTS idx_hero_sections_media_id ON public.hero_sections (media_id);
CREATE INDEX IF NOT EXISTS idx_profiles_media_id ON public.profiles (media_id);
CREATE INDEX IF NOT EXISTS idx_office_media_media_id ON public.office_media (media_id);
CREATE INDEX IF NOT EXISTS idx_website_construction_media_id ON public.website_construction_updates (media_id);

DROP VIEW IF EXISTS public.media_library;
CREATE VIEW public.media_library AS
SELECT
  m.id,
  m.title,
  m.file_url,
  m.file_type,
  m.mime_type,
  m.file_size,
  m.alt_text,
  m.caption,
  m.folder_id,
  f.name AS folder_name,
  m.width,
  m.height,
  m.tags,
  m.status,
  m.is_deleted,
  m.deleted_at,
  m.created_at,
  m.updated_at,
  m.entity_type,
  m.entity_id,
  m.storage_provider,
  m.cloudinary_public_id,
  m.cloudinary_asset_id,
  m.resource_type,
  m.secure_url,
  m.thumbnail_url,
  m.original_filename,
  m.duration,
  m.format,
  m.folder,
  m.sort_order,
  m.is_cover,
  m.is_primary,
  m.is_published,
  m.is_active,
  m.uploaded_by,
  COALESCE(NULLIF(m.secure_url, ''), m.file_url) AS delivery_url
FROM public.media m
LEFT JOIN public.media_folders f ON f.id = m.folder_id
WHERE m.is_deleted = false;

GRANT SELECT ON public.media_library TO authenticated;
GRANT SELECT ON public.media_library TO anon;

CREATE OR REPLACE FUNCTION public.media_sync_primary_cover()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.is_primary = true THEN
      NEW.is_cover := true;
    ELSIF NEW.is_cover = true THEN
      NEW.is_primary := true;
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.is_primary IS DISTINCT FROM OLD.is_primary THEN
    NEW.is_cover := NEW.is_primary;
  ELSIF NEW.is_cover IS DISTINCT FROM OLD.is_cover THEN
    NEW.is_primary := NEW.is_cover;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_media_sync_primary_cover ON public.media;
CREATE TRIGGER trg_media_sync_primary_cover
  BEFORE INSERT OR UPDATE OF is_cover, is_primary ON public.media
  FOR EACH ROW
  EXECUTE FUNCTION public.media_sync_primary_cover();

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
      WHERE m.id = p_media_id AND m.uploaded_by = auth.uid()
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

GRANT EXECUTE ON FUNCTION public.soft_delete_media(UUID) TO authenticated;
