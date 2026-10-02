-- Marketing CMS: homepage construction progress cards
CREATE TABLE IF NOT EXISTS public.website_construction_updates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  status_update TEXT NOT NULL DEFAULT '',
  expected_completion TEXT NOT NULL DEFAULT '',
  progress_pct NUMERIC(5,2) NOT NULL DEFAULT 0,
  current_phase_index INT NOT NULL DEFAULT 0,
  phases JSONB NOT NULL DEFAULT
    '["Planning","Foundation","Structure","Roofing","Finishing","Completed"]'::jsonb,
  cover_image_url TEXT,
  cta_label TEXT NOT NULL DEFAULT 'View Progress',
  cta_link TEXT,
  sort_order INT NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id)
);

CREATE INDEX IF NOT EXISTS website_construction_updates_sort_idx
  ON public.website_construction_updates (sort_order)
  WHERE COALESCE(is_deleted, false) = false;

ALTER TABLE public.website_construction_updates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS website_construction_updates_public_read
  ON public.website_construction_updates;
CREATE POLICY website_construction_updates_public_read
  ON public.website_construction_updates
  FOR SELECT USING (
    COALESCE(is_deleted, false) = false AND status = 'active'
  );

DROP POLICY IF EXISTS website_construction_updates_staff
  ON public.website_construction_updates;
CREATE POLICY website_construction_updates_staff
  ON public.website_construction_updates
  FOR ALL USING (public.has_permission('manage_marketing'))
  WITH CHECK (public.has_permission('manage_marketing'));

INSERT INTO public.website_construction_updates (
  project_name, slug, status_update, expected_completion,
  progress_pct, current_phase_index, cta_label, sort_order, status
)
SELECT * FROM (VALUES
  (
    'Horizon Gardens Phase II',
    'horizon-gardens-phase-ii',
    'Roofing and external finishes in progress',
    'Q4 2026',
    72::numeric,
    4,
    'View Progress',
    10,
    'active'
  ),
  (
    'Emerald Heights',
    'emerald-heights',
    'Structural work completed on Block C',
    'Q2 2027',
    45::numeric,
    2,
    'View Progress',
    20,
    'active'
  )
) AS v(
  project_name, slug, status_update, expected_completion,
  progress_pct, current_phase_index, cta_label, sort_order, status
)
WHERE NOT EXISTS (
  SELECT 1 FROM public.website_construction_updates
  WHERE COALESCE(is_deleted, false) = false
);
