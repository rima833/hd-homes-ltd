-- Client Journey steps + journey benefit cards (About "Our client journey")
CREATE TABLE IF NOT EXISTS public.client_journey_steps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  timeline TEXT NOT NULL DEFAULT '',
  icon_name TEXT NOT NULL DEFAULT 'circle',
  sort_order INT NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id)
);

CREATE INDEX IF NOT EXISTS client_journey_steps_sort_idx
  ON public.client_journey_steps (sort_order)
  WHERE COALESCE(is_deleted, false) = false;

ALTER TABLE public.client_journey_steps ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS client_journey_steps_public_read ON public.client_journey_steps;
CREATE POLICY client_journey_steps_public_read ON public.client_journey_steps
  FOR SELECT USING (is_deleted = false AND status = 'active');

DROP POLICY IF EXISTS client_journey_steps_staff ON public.client_journey_steps;
CREATE POLICY client_journey_steps_staff ON public.client_journey_steps
  FOR ALL USING (public.has_permission('manage_marketing'))
  WITH CHECK (public.has_permission('manage_marketing'));

CREATE TABLE IF NOT EXISTS public.journey_benefits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  icon_name TEXT NOT NULL DEFAULT 'shield',
  sort_order INT NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id)
);

CREATE INDEX IF NOT EXISTS journey_benefits_sort_idx
  ON public.journey_benefits (sort_order)
  WHERE COALESCE(is_deleted, false) = false;

ALTER TABLE public.journey_benefits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS journey_benefits_public_read ON public.journey_benefits;
CREATE POLICY journey_benefits_public_read ON public.journey_benefits
  FOR SELECT USING (is_deleted = false AND status = 'active');

DROP POLICY IF EXISTS journey_benefits_staff ON public.journey_benefits;
CREATE POLICY journey_benefits_staff ON public.journey_benefits
  FOR ALL USING (public.has_permission('manage_marketing'))
  WITH CHECK (public.has_permission('manage_marketing'));

INSERT INTO public.client_journey_steps (title, description, timeline, icon_name, sort_order, status)
SELECT * FROM (VALUES
  ('Inquiry', 'Reach out via web, phone, or visit our sales office.', 'Day 1', 'message', 10, 'active'),
  ('Consultation', 'Personalised needs assessment with our advisors.', '1-3 Days', 'users', 20, 'active'),
  ('Property Selection', 'Choose from available units, estates, or investment products.', '1-2 Weeks', 'search', 30, 'active'),
  ('Site Inspection', 'Tour the property or development site.', 'Scheduled', 'map_pin', 40, 'active'),
  ('Documentation', 'Transparent contracts and verified title documents.', '1-2 Weeks', 'file', 50, 'active'),
  ('Payment', 'Flexible plans aligned to your budget.', 'Ongoing', 'wallet', 60, 'active'),
  ('Construction', 'Regular progress updates and milestone tracking.', 'Project-dependent', 'hard_hat', 70, 'active'),
  ('Handover', 'Quality-checked delivery with full documentation.', 'On completion', 'key', 80, 'active'),
  ('After-Sales Support', 'Dedicated support for maintenance and referrals.', 'Lifetime', 'headphones', 90, 'active')
) AS v(title, description, timeline, icon_name, sort_order, status)
WHERE NOT EXISTS (
  SELECT 1 FROM public.client_journey_steps WHERE COALESCE(is_deleted, false) = false
);

INSERT INTO public.journey_benefits (title, description, icon_name, sort_order, status)
SELECT * FROM (VALUES
  ('Transparent Process', 'Clear communication at every step.', 'shield', 10, 'active'),
  ('Client First', 'Your goals drive everything we do.', 'award', 20, 'active'),
  ('On-Time Delivery', 'Committed to timelines and quality.', 'target', 30, 'active'),
  ('Lifetime Support', 'We''re with you, always.', 'heart', 40, 'active')
) AS v(title, description, icon_name, sort_order, status)
WHERE NOT EXISTS (
  SELECT 1 FROM public.journey_benefits WHERE COALESCE(is_deleted, false) = false
);
