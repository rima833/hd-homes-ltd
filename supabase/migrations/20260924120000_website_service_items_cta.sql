-- Admin-controllable Learn More destinations for public service cards.
ALTER TABLE public.website_service_items
  ADD COLUMN IF NOT EXISTS cta_label text NOT NULL DEFAULT 'Learn More',
  ADD COLUMN IF NOT EXISTS cta_href text;

COMMENT ON COLUMN public.website_service_items.cta_label IS
  'Button label on public service cards';
COMMENT ON COLUMN public.website_service_items.cta_href IS
  'Optional override path/URL for Learn More. Empty = /services/{slug}';
