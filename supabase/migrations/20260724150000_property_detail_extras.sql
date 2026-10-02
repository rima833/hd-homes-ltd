-- Rich public property-detail sections (tours, docs, plans, nearby, FAQs, etc.).
ALTER TABLE public.properties
  ADD COLUMN IF NOT EXISTS detail_extras jsonb NOT NULL DEFAULT '{}'::jsonb;
