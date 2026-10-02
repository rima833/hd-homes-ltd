-- Company statistics for Home + About (circular KPI hub)
CREATE TABLE IF NOT EXISTS public.company_statistics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  value INT NOT NULL DEFAULT 0,
  label TEXT NOT NULL,
  suffix TEXT NOT NULL DEFAULT '',
  description TEXT NOT NULL DEFAULT '',
  icon_name TEXT NOT NULL DEFAULT 'barChart',
  logo_url TEXT,
  placement TEXT NOT NULL DEFAULT 'orbit',
  sort_order INT NOT NULL DEFAULT 0,
  show_on_home BOOLEAN NOT NULL DEFAULT true,
  show_on_about BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  CONSTRAINT company_statistics_placement_chk
    CHECK (placement IN ('orbit', 'summary'))
);

CREATE INDEX IF NOT EXISTS company_statistics_sort_idx
  ON public.company_statistics (placement, sort_order)
  WHERE COALESCE(is_deleted, false) = false;

ALTER TABLE public.company_statistics ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS company_statistics_public_read ON public.company_statistics;
CREATE POLICY company_statistics_public_read ON public.company_statistics
  FOR SELECT USING (is_deleted = false AND status = 'active');

DROP POLICY IF EXISTS company_statistics_staff ON public.company_statistics;
CREATE POLICY company_statistics_staff ON public.company_statistics
  FOR ALL USING (public.has_permission('manage_marketing'))
  WITH CHECK (public.has_permission('manage_marketing'));

INSERT INTO public.company_statistics
  (value, label, suffix, description, icon_name, placement, sort_order, show_on_home, show_on_about, status)
SELECT * FROM (VALUES
  (15, 'Years In Business', '+', '', 'calendar', 'orbit', 10, true, true, 'active'),
  (3200, 'Homes Delivered', '+', '', 'home', 'orbit', 20, true, true, 'active'),
  (48, 'Projects Completed', '', '', 'building', 'orbit', 30, true, true, 'active'),
  (12000, 'Happy Clients', '+', '', 'users', 'orbit', 40, true, true, 'active'),
  (850, 'Investors', '', '', 'trendingUp', 'orbit', 50, true, true, 'active'),
  (18, 'Active Construction', '', '', 'hardHat', 'orbit', 60, true, true, 'active'),
  (120, 'Employees', '', '', 'briefcase', 'orbit', 70, true, true, 'active'),
  (35, 'Partner Organizations', '', '', 'handshake', 'orbit', 80, true, true, 'active'),
  (12, 'Industry Awards', '', '', 'award', 'orbit', 90, true, true, 'active'),
  (15, 'Years of Excellence', '+', 'A decade and a half building trusted communities across Nigeria.', 'shield', 'summary', 10, true, true, 'active'),
  (3200, 'Homes Delivered', '+', 'Quality residences handed over to families and investors nationwide.', 'home', 'summary', 20, true, true, 'active'),
  (12000, 'Happy Clients', '+', 'Homeowners and partners who trust HD Homes every step of the way.', 'heart', 'summary', 30, true, true, 'active')
) AS v(value, label, suffix, description, icon_name, placement, sort_order, show_on_home, show_on_about, status)
WHERE NOT EXISTS (
  SELECT 1 FROM public.company_statistics WHERE COALESCE(is_deleted, false) = false
);
