-- Free-text badge for homepage featured property cards (marketing_status is constrained).
ALTER TABLE public.properties
  ADD COLUMN IF NOT EXISTS homepage_badge text;
