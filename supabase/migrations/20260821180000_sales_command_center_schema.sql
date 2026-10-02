-- Sales Command Center schema extensions (applied remotely as sales_command_center_schema_v1)
-- + consultation dual-write (consultation_crm_dual_write)

ALTER TABLE public.crm_leads
  ADD COLUMN IF NOT EXISTS property_id uuid REFERENCES public.properties(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS last_contacted_at timestamptz,
  ADD COLUMN IF NOT EXISTS next_follow_up_at timestamptz,
  ADD COLUMN IF NOT EXISTS preferred_location text,
  ADD COLUMN IF NOT EXISTS interest_summary text,
  ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;

UPDATE public.crm_pipeline_stages
SET name = 'Inspection Scheduled', updated_at = now()
WHERE slug = 'site_visit';

INSERT INTO public.crm_pipeline_stages (slug, name, sort_order, probability_pct, is_active)
SELECT v.slug, v.name, v.sort_order, v.probability_pct, true
FROM (VALUES
  ('property_matched', 'Property Matched', 35, 45.00),
  ('inspection_completed', 'Inspection Completed', 45, 60.00),
  ('application', 'Application', 55, 75.00),
  ('payment_pending', 'Payment Pending', 58, 85.00)
) AS v(slug, name, sort_order, probability_pct)
WHERE NOT EXISTS (
  SELECT 1 FROM public.crm_pipeline_stages s WHERE s.slug = v.slug
);
