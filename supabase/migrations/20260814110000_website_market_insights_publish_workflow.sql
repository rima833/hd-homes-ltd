-- Align website_market_insights with publish workflow (draft / published / archived).
-- Drop the legacy status check BEFORE rewriting 'active' → 'published'.

ALTER TABLE public.website_market_insights
  ADD COLUMN IF NOT EXISTS is_published BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS published_at TIMESTAMPTZ;

ALTER TABLE public.website_market_insights
  DROP CONSTRAINT IF EXISTS website_market_insights_status_check;

UPDATE public.website_market_insights
SET
  status = 'published',
  is_published = true,
  published_at = COALESCE(published_at, updated_at, now())
WHERE COALESCE(is_deleted, false) = false
  AND status IN ('active', 'published');

UPDATE public.website_market_insights
SET
  is_published = false
WHERE status IN ('draft', 'archived')
   OR COALESCE(is_deleted, false) = true;

ALTER TABLE public.website_market_insights
  ADD CONSTRAINT website_market_insights_status_check
  CHECK (status IN ('draft', 'published', 'archived'));

ALTER TABLE public.website_market_insights
  ALTER COLUMN status SET DEFAULT 'draft';

DROP INDEX IF EXISTS website_market_insights_published_idx;

CREATE INDEX IF NOT EXISTS website_market_insights_published_idx
  ON public.website_market_insights (sort_order ASC, updated_at DESC)
  WHERE COALESCE(is_deleted, false) = false
    AND is_published = true
    AND status = 'published';

CREATE INDEX IF NOT EXISTS website_market_insights_status_idx
  ON public.website_market_insights (status, is_published);

CREATE INDEX IF NOT EXISTS website_market_insights_category_idx
  ON public.website_market_insights (category);

DROP POLICY IF EXISTS website_market_insights_public_read
  ON public.website_market_insights;

CREATE POLICY website_market_insights_public_read
  ON public.website_market_insights
  FOR SELECT USING (
    COALESCE(is_deleted, false) = false
    AND is_published = true
    AND status = 'published'
  );
