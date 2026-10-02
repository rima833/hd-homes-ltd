-- Shared Awards & Certifications for homepage + about
CREATE TABLE IF NOT EXISTS public.awards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  issuer TEXT NOT NULL DEFAULT '',
  year TEXT NOT NULL DEFAULT '',
  description TEXT NOT NULL DEFAULT '',
  verification_url TEXT,
  icon_name TEXT NOT NULL DEFAULT 'award',
  sort_order INT NOT NULL DEFAULT 0,
  is_featured BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS awards_sort_idx
  ON public.awards (sort_order)
  WHERE COALESCE(is_deleted, false) = false;

ALTER TABLE public.awards ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS awards_public_read ON public.awards;
CREATE POLICY awards_public_read ON public.awards
  FOR SELECT USING (is_deleted = false AND status = 'active');

DROP POLICY IF EXISTS awards_staff ON public.awards;
CREATE POLICY awards_staff ON public.awards
  FOR ALL USING (public.has_permission('manage_marketing'))
  WITH CHECK (public.has_permission('manage_marketing'));

INSERT INTO public.awards (title, issuer, year, description, icon_name, sort_order, is_featured, status)
SELECT * FROM (VALUES
  ('Excellence in Housing Development', 'Nigeria Property Awards', '2025',
   'Recognised for quality delivery and client satisfaction.', 'award', 10, true, 'active'),
  ('Best Customer Experience', 'PropTech Nigeria', '2024',
   'PropTech innovation in client engagement.', 'star', 20, true, 'active'),
  ('CAC Corporate Registration', 'Corporate Affairs Commission', '2011',
   'Fully registered corporate entity.', 'badge', 30, false, 'active')
) AS v(title, issuer, year, description, icon_name, sort_order, is_featured, status)
WHERE NOT EXISTS (
  SELECT 1 FROM public.awards WHERE COALESCE(is_deleted, false) = false
);
