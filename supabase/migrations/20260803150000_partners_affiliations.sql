-- Shared Partners & Affiliations for homepage + about
CREATE TABLE IF NOT EXISTS public.partners (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT '',
  tagline TEXT NOT NULL DEFAULT '',
  logo_url TEXT,
  icon_name TEXT NOT NULL DEFAULT 'building',
  sort_order INT NOT NULL DEFAULT 0,
  show_on_home BOOLEAN NOT NULL DEFAULT true,
  show_on_about BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS partners_sort_idx
  ON public.partners (sort_order)
  WHERE COALESCE(is_deleted, false) = false;

ALTER TABLE public.partners ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS partners_public_read ON public.partners;
CREATE POLICY partners_public_read ON public.partners
  FOR SELECT USING (is_deleted = false AND status = 'active');

DROP POLICY IF EXISTS partners_staff ON public.partners;
CREATE POLICY partners_staff ON public.partners
  FOR ALL USING (public.has_permission('manage_marketing'))
  WITH CHECK (public.has_permission('manage_marketing'));

INSERT INTO public.partners (name, category, tagline, icon_name, sort_order, show_on_home, show_on_about, status)
SELECT * FROM (VALUES
  ('FirstBank', 'Banking', 'Since 1894', 'landmark', 10, true, true, 'active'),
  ('GTBank', 'Banking', '', 'landmark', 20, true, true, 'active'),
  ('BuildRight Contractors', 'Construction', '', 'hardHat', 30, true, true, 'active'),
  ('NIESV', 'Professional Body', '', 'shield', 40, true, true, 'active'),
  ('Lagos State Ministry', 'Government', '', 'badge', 50, true, true, 'active'),
  ('SurveyPro Ltd', 'Surveying', '', 'compass', 60, true, true, 'active'),
  ('CAC Registered', 'Government', '', 'badge', 70, true, false, 'active')
) AS v(name, category, tagline, icon_name, sort_order, show_on_home, show_on_about, status)
WHERE NOT EXISTS (
  SELECT 1 FROM public.partners WHERE COALESCE(is_deleted, false) = false
);
