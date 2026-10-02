-- Office locations for About (and reusable public surfaces)
CREATE TABLE IF NOT EXISTS public.office_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  office_type TEXT NOT NULL DEFAULT 'Office',
  address TEXT NOT NULL DEFAULT '',
  phone TEXT NOT NULL DEFAULT '',
  email TEXT NOT NULL DEFAULT '',
  hours TEXT NOT NULL DEFAULT '',
  map_url TEXT NOT NULL DEFAULT 'https://maps.google.com',
  appointment_path TEXT NOT NULL DEFAULT '/book-inspection',
  map_label TEXT NOT NULL DEFAULT 'View Map',
  appointment_label TEXT NOT NULL DEFAULT 'Book Appointment',
  sort_order INT NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id)
);

CREATE INDEX IF NOT EXISTS office_locations_sort_idx
  ON public.office_locations (sort_order)
  WHERE COALESCE(is_deleted, false) = false;

ALTER TABLE public.office_locations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS office_locations_public_read ON public.office_locations;
CREATE POLICY office_locations_public_read ON public.office_locations
  FOR SELECT USING (is_deleted = false AND status = 'active');

DROP POLICY IF EXISTS office_locations_staff ON public.office_locations;
CREATE POLICY office_locations_staff ON public.office_locations
  FOR ALL USING (public.has_permission('manage_marketing'))
  WITH CHECK (public.has_permission('manage_marketing'));

INSERT INTO public.office_locations (
  name, office_type, address, phone, email, hours, map_url, sort_order, status
)
SELECT * FROM (VALUES
  (
    'Head Office',
    'Head Office',
    'Lekki Phase 1, Lagos, Nigeria',
    '+234 800 HD HOMES',
    'info@hdhomes.ng',
    'Mon–Fri 8:00–18:00',
    'https://maps.google.com',
    10,
    'active'
  ),
  (
    'Abuja Regional Office',
    'Regional Office',
    'Central Business District, Abuja',
    '+234 800 HD HOMES',
    'abuja@hdhomes.ng',
    'Mon–Fri 8:00–17:00',
    'https://maps.google.com',
    20,
    'active'
  ),
  (
    'Port Harcourt Sales Office',
    'Sales Office',
    'GRA Phase 2, Port Harcourt',
    '+234 800 HD HOMES',
    'ph@hdhomes.ng',
    'Mon–Sat 9:00–17:00',
    'https://maps.google.com',
    30,
    'active'
  )
) AS v(name, office_type, address, phone, email, hours, map_url, sort_order, status)
WHERE NOT EXISTS (
  SELECT 1 FROM public.office_locations WHERE COALESCE(is_deleted, false) = false
);
