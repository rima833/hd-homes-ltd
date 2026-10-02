-- Digital Company Profile (About section) — singleton CMS + trust KPIs
CREATE TABLE IF NOT EXISTS public.digital_company_profile (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  overline TEXT NOT NULL DEFAULT 'COMPANY PROFILE',
  title TEXT NOT NULL DEFAULT 'Digital company profile',
  subtitle TEXT NOT NULL DEFAULT
    'Interactive overview of our history, projects, leadership, and investment opportunities.',
  card_title TEXT NOT NULL DEFAULT 'Interactive Company Profile',
  card_description TEXT NOT NULL DEFAULT
    'Explore who we are, what we do, and the impact we create through innovation and excellence.',
  features JSONB NOT NULL DEFAULT '[]'::jsonb,
  cta_label TEXT NOT NULL DEFAULT 'View Digital Profile',
  view_url TEXT NOT NULL DEFAULT '#',
  mockup_image_url TEXT,
  pdf_label TEXT NOT NULL DEFAULT 'Download PDF',
  pdf_url TEXT NOT NULL DEFAULT '#',
  pdf_meta TEXT NOT NULL DEFAULT '18 MB | Updated May 20, 2025',
  brochure_label TEXT NOT NULL DEFAULT 'Download Brochure',
  brochure_url TEXT NOT NULL DEFAULT '#',
  brochure_meta TEXT NOT NULL DEFAULT '12 MB | Updated May 20, 2025',
  trust_message TEXT NOT NULL DEFAULT
    'Trusted by thousands of clients and investors across Nigeria and beyond.',
  -- Trust bar KPIs (editable in the same admin screen)
  years_value INT NOT NULL DEFAULT 15,
  years_suffix TEXT NOT NULL DEFAULT '+',
  years_label TEXT NOT NULL DEFAULT 'Years Experience',
  homes_value INT NOT NULL DEFAULT 3200,
  homes_suffix TEXT NOT NULL DEFAULT '+',
  homes_label TEXT NOT NULL DEFAULT 'Homes Delivered',
  clients_value INT NOT NULL DEFAULT 12000,
  clients_suffix TEXT NOT NULL DEFAULT '+',
  clients_label TEXT NOT NULL DEFAULT 'Happy Clients',
  projects_value INT NOT NULL DEFAULT 48,
  projects_suffix TEXT NOT NULL DEFAULT '',
  projects_label TEXT NOT NULL DEFAULT 'Projects Completed',
  status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id)
);

ALTER TABLE public.digital_company_profile ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS digital_company_profile_public_read
  ON public.digital_company_profile;
CREATE POLICY digital_company_profile_public_read
  ON public.digital_company_profile
  FOR SELECT USING (status = 'active');

DROP POLICY IF EXISTS digital_company_profile_staff
  ON public.digital_company_profile;
CREATE POLICY digital_company_profile_staff
  ON public.digital_company_profile
  FOR ALL USING (public.has_permission('manage_marketing'))
  WITH CHECK (public.has_permission('manage_marketing'));

INSERT INTO public.digital_company_profile (
  overline,
  title,
  subtitle,
  card_title,
  card_description,
  features,
  cta_label,
  view_url,
  pdf_label,
  pdf_url,
  pdf_meta,
  brochure_label,
  brochure_url,
  brochure_meta,
  trust_message,
  years_value, years_suffix, years_label,
  homes_value, homes_suffix, homes_label,
  clients_value, clients_suffix, clients_label,
  projects_value, projects_suffix, projects_label,
  status
)
SELECT
  'COMPANY PROFILE',
  'Digital company profile',
  'Interactive overview of our history, projects, leadership, and investment opportunities.',
  'Interactive Company Profile',
  'Explore who we are, what we do, and the impact we create through innovation and excellence.',
  '[
    "Company History",
    "Investment Portfolio",
    "Completed Projects",
    "Certifications",
    "Executive Leadership",
    "Core Values"
  ]'::jsonb,
  'View Digital Profile',
  '#',
  'Download PDF',
  '#',
  '18 MB | Updated May 20, 2025',
  'Download Brochure',
  '#',
  '12 MB | Updated May 20, 2025',
  'Trusted by thousands of clients and investors across Nigeria and beyond.',
  15, '+', 'Years Experience',
  3200, '+', 'Homes Delivered',
  12000, '+', 'Happy Clients',
  48, '', 'Projects Completed',
  'active'
WHERE NOT EXISTS (SELECT 1 FROM public.digital_company_profile);
