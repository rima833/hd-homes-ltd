-- Specs + narrative fields used by the public featured property detail page.
ALTER TABLE public.properties
  ADD COLUMN IF NOT EXISTS kitchens numeric(4,1),
  ADD COLUMN IF NOT EXISTS year_built text,
  ADD COLUMN IF NOT EXISTS power_supply text,
  ADD COLUMN IF NOT EXISTS water_supply text,
  ADD COLUMN IF NOT EXISTS internet_connectivity text,
  ADD COLUMN IF NOT EXISTS estate_name text,
  ADD COLUMN IF NOT EXISTS architectural_concept text,
  ADD COLUMN IF NOT EXISTS investment_potential text;
