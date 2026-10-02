-- Website Support, Careers applications, and Partnership requests.
-- Reuses public.tickets + public.career_jobs. Adds applications, partnership
-- tables, CMS settings, private storage, RPCs, RLS, and realtime.

-- ---------------------------------------------------------------------------
-- Permissions
-- ---------------------------------------------------------------------------
INSERT INTO public.permissions (slug, name, description, module)
SELECT 'partnerships.view', 'View partnerships', 'View website partnership requests', 'website'
WHERE NOT EXISTS (SELECT 1 FROM public.permissions WHERE slug = 'partnerships.view');

INSERT INTO public.permissions (slug, name, description, module)
SELECT 'partnerships.manage', 'Manage partnerships', 'Update partnership requests and documents', 'website'
WHERE NOT EXISTS (SELECT 1 FROM public.permissions WHERE slug = 'partnerships.manage');

INSERT INTO public.permissions (slug, name, description, module)
SELECT 'partnerships.settings', 'Partnership settings', 'Configure partnership form types and settings', 'website'
WHERE NOT EXISTS (SELECT 1 FROM public.permissions WHERE slug = 'partnerships.settings');

INSERT INTO public.permissions (slug, name, description, module)
SELECT 'careers.applications', 'Career applications', 'View and manage career applications', 'website'
WHERE NOT EXISTS (SELECT 1 FROM public.permissions WHERE slug = 'careers.applications');

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE r.slug IN ('super_admin', 'admin')
  AND p.slug IN (
    'partnerships.view', 'partnerships.manage', 'partnerships.settings',
    'careers.applications'
  )
ON CONFLICT DO NOTHING;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE r.slug IN ('marketing', 'sales_team')
  AND p.slug IN ('partnerships.view', 'partnerships.manage', 'careers.applications')
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Support form CMS
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.website_support_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  is_enabled boolean NOT NULL DEFAULT true,
  confirmation_title text NOT NULL DEFAULT 'Ticket submitted',
  confirmation_message text NOT NULL DEFAULT
    'Thank you. Our support team has received your ticket and will get back to you shortly.',
  default_priority text NOT NULL DEFAULT 'normal',
  disabled_message text NOT NULL DEFAULT
    'Support submissions are temporarily unavailable. Please try again later or email us directly.',
  contact_phone text,
  contact_email text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.website_support_settings (id)
SELECT gen_random_uuid()
WHERE NOT EXISTS (SELECT 1 FROM public.website_support_settings LIMIT 1);

CREATE TABLE IF NOT EXISTS public.website_support_types (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  sort_order int NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.website_support_types (name, slug, sort_order)
VALUES
  ('Complaint', 'complaint', 10),
  ('Feedback', 'feedback', 20),
  ('Suggestion', 'suggestion', 30),
  ('Technical Issue', 'technical-issue', 40),
  ('Account Issue', 'account-issue', 50),
  ('Investment Support', 'investment-support', 60),
  ('Investor Portal', 'investor-portal', 70),
  ('Payment Issue', 'payment-issue', 80),
  ('Other', 'other', 90)
ON CONFLICT (slug) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Careers: extra job fields + application settings + applications
-- ---------------------------------------------------------------------------
ALTER TABLE public.career_jobs
  ADD COLUMN IF NOT EXISTS requirements text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS application_deadline timestamptz;

ALTER TABLE public.careers_settings
  ADD COLUMN IF NOT EXISTS applications_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS application_confirmation_title text NOT NULL DEFAULT 'Application received',
  ADD COLUMN IF NOT EXISTS application_confirmation_message text NOT NULL DEFAULT
    'Thank you for applying. Our recruitment team will review your application and contact you if there is a suitable opportunity.',
  ADD COLUMN IF NOT EXISTS allowed_cv_extensions text[] NOT NULL DEFAULT ARRAY['pdf','doc','docx'],
  ADD COLUMN IF NOT EXISTS max_cv_bytes int NOT NULL DEFAULT 5242880,
  ADD COLUMN IF NOT EXISTS allow_general_application boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS applications_disabled_message text NOT NULL DEFAULT
    'Career applications are temporarily closed. Please check back soon.';

CREATE TABLE IF NOT EXISTS public.career_applications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference_number text NOT NULL UNIQUE,
  job_id uuid REFERENCES public.career_jobs(id) ON DELETE SET NULL,
  position_title text NOT NULL DEFAULT '',
  full_name text NOT NULL,
  email text NOT NULL,
  phone text,
  preferred_location text,
  linkedin_url text,
  cover_letter text,
  cv_path text,
  cv_file_name text,
  cv_mime_type text,
  cv_size_bytes int,
  status text NOT NULL DEFAULT 'new'
    CHECK (status IN (
      'new','reviewing','shortlisted','interview','assessment',
      'offer','hired','rejected','withdrawn','archived'
    )),
  assigned_to uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  admin_notes text,
  source text NOT NULL DEFAULT 'public_web',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS career_applications_status_idx
  ON public.career_applications (status, created_at DESC);
CREATE INDEX IF NOT EXISTS career_applications_job_idx
  ON public.career_applications (job_id);
CREATE INDEX IF NOT EXISTS career_applications_email_idx
  ON public.career_applications (email);

CREATE TABLE IF NOT EXISTS public.career_application_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id uuid NOT NULL REFERENCES public.career_applications(id) ON DELETE CASCADE,
  author_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  author_label text,
  body text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.career_application_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id uuid NOT NULL REFERENCES public.career_applications(id) ON DELETE CASCADE,
  from_status text,
  to_status text NOT NULL,
  changed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  reason text,
  changed_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Partnerships
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.partnership_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  is_enabled boolean NOT NULL DEFAULT true,
  confirmation_title text NOT NULL DEFAULT 'Partnership request received',
  confirmation_message text NOT NULL DEFAULT
    'Thank you. Our partnerships team will review your proposal and get in touch.',
  disabled_message text NOT NULL DEFAULT
    'Partnership requests are temporarily unavailable. Please email us directly.',
  allowed_doc_extensions text[] NOT NULL DEFAULT ARRAY['pdf','doc','docx'],
  max_doc_bytes int NOT NULL DEFAULT 10485760,
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.partnership_settings (id)
SELECT gen_random_uuid()
WHERE NOT EXISTS (SELECT 1 FROM public.partnership_settings LIMIT 1);

CREATE TABLE IF NOT EXISTS public.partnership_types (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  sort_order int NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.partnership_types (name, slug, sort_order)
VALUES
  ('Joint Venture', 'joint-venture', 10),
  ('Development Partnership', 'development', 20),
  ('Land Partnership', 'land', 30),
  ('Strategic Partnership', 'strategic', 40),
  ('Investment Partnership', 'investment', 50),
  ('Corporate Partnership', 'corporate', 60),
  ('Supplier/Vendor', 'supplier-vendor', 70),
  ('Other', 'other', 80)
ON CONFLICT (slug) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.partnership_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference_number text NOT NULL UNIQUE,
  company_name text NOT NULL,
  contact_person text NOT NULL,
  email text NOT NULL,
  phone text NOT NULL,
  type_id uuid REFERENCES public.partnership_types(id) ON DELETE SET NULL,
  type_name text,
  proposal_summary text,
  documents jsonb NOT NULL DEFAULT '[]'::jsonb,
  status text NOT NULL DEFAULT 'new'
    CHECK (status IN (
      'new','under_review','contacted','negotiation','approved','declined','closed','archived'
    )),
  priority text NOT NULL DEFAULT 'normal'
    CHECK (priority IN ('low','normal','high','urgent')),
  assigned_to uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  admin_notes text,
  source text NOT NULL DEFAULT 'public_web',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS partnership_requests_status_idx
  ON public.partnership_requests (status, created_at DESC);
CREATE INDEX IF NOT EXISTS partnership_requests_email_idx
  ON public.partnership_requests (email);

CREATE TABLE IF NOT EXISTS public.partnership_request_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES public.partnership_requests(id) ON DELETE CASCADE,
  author_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  author_label text,
  body text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.partnership_request_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES public.partnership_requests(id) ON DELETE CASCADE,
  from_status text,
  to_status text NOT NULL,
  changed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  reason text,
  changed_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.website_form_outbox (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  channel text NOT NULL DEFAULT 'email',
  recipient text NOT NULL,
  template_slug text NOT NULL,
  title text NOT NULL,
  body text NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'queued',
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Private storage
-- ---------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'website-private',
  'website-private',
  false,
  10485760,
  ARRAY[
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  ]
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS website_private_public_upload ON storage.objects;
CREATE POLICY website_private_public_upload ON storage.objects
  FOR INSERT TO anon, authenticated
  WITH CHECK (
    bucket_id = 'website-private'
    AND (
      name LIKE 'careers/inbox/%'
      OR name LIKE 'partnerships/inbox/%'
    )
  );

DROP POLICY IF EXISTS website_private_staff_read ON storage.objects;
CREATE POLICY website_private_staff_read ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'website-private'
    AND (
      public.has_permission('careers.applications', auth.uid())
      OR public.has_permission('manage_marketing', auth.uid())
      OR public.has_permission('partnerships.manage', auth.uid())
      OR public.has_permission('partnerships.view', auth.uid())
      OR public.has_role('super_admin', auth.uid())
      OR public.has_role('admin', auth.uid())
      OR public.is_staff()
    )
  );

DROP POLICY IF EXISTS website_private_staff_write ON storage.objects;
CREATE POLICY website_private_staff_write ON storage.objects
  FOR ALL TO authenticated
  USING (
    bucket_id = 'website-private'
    AND (
      public.has_permission('careers.applications', auth.uid())
      OR public.has_permission('manage_marketing', auth.uid())
      OR public.has_permission('partnerships.manage', auth.uid())
      OR public.has_role('super_admin', auth.uid())
      OR public.has_role('admin', auth.uid())
      OR public.is_staff()
    )
  )
  WITH CHECK (
    bucket_id = 'website-private'
    AND (
      public.has_permission('careers.applications', auth.uid())
      OR public.has_permission('manage_marketing', auth.uid())
      OR public.has_permission('partnerships.manage', auth.uid())
      OR public.has_role('super_admin', auth.uid())
      OR public.has_role('admin', auth.uid())
      OR public.is_staff()
    )
  );

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.website_support_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.website_support_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.career_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.career_application_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.career_application_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partnership_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partnership_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partnership_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partnership_request_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partnership_request_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.website_form_outbox ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS website_support_settings_public_read ON public.website_support_settings;
CREATE POLICY website_support_settings_public_read ON public.website_support_settings
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS website_support_types_public_read ON public.website_support_types;
CREATE POLICY website_support_types_public_read ON public.website_support_types
  FOR SELECT TO anon, authenticated USING (is_active = true);

DROP POLICY IF EXISTS website_support_settings_admin ON public.website_support_settings;
CREATE POLICY website_support_settings_admin ON public.website_support_settings
  FOR ALL TO authenticated
  USING (
    public.has_permission('support.write', auth.uid())
    OR public.has_permission('manage_marketing', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR public.has_role('admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('support.write', auth.uid())
    OR public.has_permission('manage_marketing', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR public.has_role('admin', auth.uid())
  );

DROP POLICY IF EXISTS website_support_types_admin ON public.website_support_types;
CREATE POLICY website_support_types_admin ON public.website_support_types
  FOR ALL TO authenticated
  USING (
    public.has_permission('support.write', auth.uid())
    OR public.has_permission('manage_marketing', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR public.has_role('admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('support.write', auth.uid())
    OR public.has_permission('manage_marketing', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR public.has_role('admin', auth.uid())
  );

DROP POLICY IF EXISTS career_jobs_public_read ON public.career_jobs;
CREATE POLICY career_jobs_public_read ON public.career_jobs
  FOR SELECT USING (
    is_deleted = false
    AND status = 'active'
    AND (application_deadline IS NULL OR application_deadline > now())
  );

DROP POLICY IF EXISTS career_applications_staff ON public.career_applications;
CREATE POLICY career_applications_staff ON public.career_applications
  FOR ALL TO authenticated
  USING (
    public.has_permission('careers.applications', auth.uid())
    OR public.has_permission('manage_marketing', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR public.has_role('admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('careers.applications', auth.uid())
    OR public.has_permission('manage_marketing', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR public.has_role('admin', auth.uid())
  );

DROP POLICY IF EXISTS career_application_notes_staff ON public.career_application_notes;
CREATE POLICY career_application_notes_staff ON public.career_application_notes
  FOR ALL TO authenticated
  USING (
    public.has_permission('careers.applications', auth.uid())
    OR public.has_permission('manage_marketing', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR public.has_role('admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('careers.applications', auth.uid())
    OR public.has_permission('manage_marketing', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR public.has_role('admin', auth.uid())
  );

DROP POLICY IF EXISTS career_application_history_staff ON public.career_application_history;
CREATE POLICY career_application_history_staff ON public.career_application_history
  FOR SELECT TO authenticated
  USING (
    public.has_permission('careers.applications', auth.uid())
    OR public.has_permission('manage_marketing', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR public.has_role('admin', auth.uid())
  );

DROP POLICY IF EXISTS partnership_settings_public_read ON public.partnership_settings;
CREATE POLICY partnership_settings_public_read ON public.partnership_settings
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS partnership_types_public_read ON public.partnership_types;
CREATE POLICY partnership_types_public_read ON public.partnership_types
  FOR SELECT TO anon, authenticated USING (is_active = true);

DROP POLICY IF EXISTS partnership_settings_admin ON public.partnership_settings;
CREATE POLICY partnership_settings_admin ON public.partnership_settings
  FOR ALL TO authenticated
  USING (
    public.has_permission('partnerships.settings', auth.uid())
    OR public.has_permission('manage_marketing', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR public.has_role('admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('partnerships.settings', auth.uid())
    OR public.has_permission('manage_marketing', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR public.has_role('admin', auth.uid())
  );

DROP POLICY IF EXISTS partnership_types_admin ON public.partnership_types;
CREATE POLICY partnership_types_admin ON public.partnership_types
  FOR ALL TO authenticated
  USING (
    public.has_permission('partnerships.settings', auth.uid())
    OR public.has_permission('manage_marketing', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR public.has_role('admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('partnerships.settings', auth.uid())
    OR public.has_permission('manage_marketing', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR public.has_role('admin', auth.uid())
  );

DROP POLICY IF EXISTS partnership_requests_staff ON public.partnership_requests;
CREATE POLICY partnership_requests_staff ON public.partnership_requests
  FOR ALL TO authenticated
  USING (
    public.has_permission('partnerships.view', auth.uid())
    OR public.has_permission('partnerships.manage', auth.uid())
    OR public.has_permission('manage_marketing', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR public.has_role('admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('partnerships.manage', auth.uid())
    OR public.has_permission('manage_marketing', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR public.has_role('admin', auth.uid())
  );

DROP POLICY IF EXISTS partnership_request_notes_staff ON public.partnership_request_notes;
CREATE POLICY partnership_request_notes_staff ON public.partnership_request_notes
  FOR ALL TO authenticated
  USING (
    public.has_permission('partnerships.view', auth.uid())
    OR public.has_permission('partnerships.manage', auth.uid())
    OR public.has_permission('manage_marketing', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR public.has_role('admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('partnerships.manage', auth.uid())
    OR public.has_permission('manage_marketing', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR public.has_role('admin', auth.uid())
  );

DROP POLICY IF EXISTS partnership_request_history_staff ON public.partnership_request_history;
CREATE POLICY partnership_request_history_staff ON public.partnership_request_history
  FOR SELECT TO authenticated
  USING (
    public.has_permission('partnerships.view', auth.uid())
    OR public.has_permission('partnerships.manage', auth.uid())
    OR public.has_permission('manage_marketing', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR public.has_role('admin', auth.uid())
  );

DROP POLICY IF EXISTS website_form_outbox_staff ON public.website_form_outbox;
CREATE POLICY website_form_outbox_staff ON public.website_form_outbox
  FOR SELECT TO authenticated
  USING (
    public.has_role('super_admin', auth.uid())
    OR public.has_role('admin', auth.uid())
    OR public.is_staff()
  );

-- No public SELECT/UPDATE on submissions. Public writes go through RPCs only.

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.tickets;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.website_support_settings;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.website_support_types;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.career_applications;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.partnership_settings;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.partnership_types;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.partnership_requests;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._website_notify_staff(
  p_permission text,
  p_title text,
  p_body text,
  p_action_url text DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.notifications (
    user_id, title, body, category, type, priority, action_url, metadata
  )
  SELECT DISTINCT ur.user_id, p_title, p_body, 'website', 'information', 'normal',
         p_action_url, p_metadata
  FROM public.user_roles ur
  JOIN public.role_permissions rp ON rp.role_id = ur.role_id
  JOIN public.permissions p ON p.id = rp.permission_id
  WHERE p.slug = p_permission
    AND COALESCE(ur.is_deleted, false) = false
  ON CONFLICT DO NOTHING;
EXCEPTION WHEN OTHERS THEN
  -- Never fail a public submission because of notification delivery.
  NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public._website_queue_email(
  p_recipient text,
  p_template text,
  p_title text,
  p_body text,
  p_payload jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_recipient IS NULL OR position('@' in p_recipient) = 0 THEN
    RETURN;
  END IF;
  INSERT INTO public.website_form_outbox (
    recipient, template_slug, title, body, payload
  ) VALUES (
    lower(p_recipient), p_template, p_title, p_body, p_payload
  );
EXCEPTION WHEN OTHERS THEN
  NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public._website_ref(p_prefix text)
RETURNS text
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN p_prefix || to_char(now() AT TIME ZONE 'Africa/Lagos', 'YYYYMMDD')
         || '-' || lpad((floor(random() * 9000) + 1000)::int::text, 4, '0');
END;
$$;

-- ---------------------------------------------------------------------------
-- Public submit RPCs
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.submit_website_support_ticket(
  p_full_name text,
  p_email text,
  p_type_id uuid,
  p_details text,
  p_source text DEFAULT 'public_web'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_name text := NULLIF(trim(COALESCE(p_full_name, '')), '');
  v_email text := lower(NULLIF(trim(COALESCE(p_email, '')), ''));
  v_details text := NULLIF(trim(COALESCE(p_details, '')), '');
  v_settings public.website_support_settings%ROWTYPE;
  v_type public.website_support_types%ROWTYPE;
  v_ref text;
  v_id uuid;
  v_priority text;
BEGIN
  SELECT * INTO v_settings FROM public.website_support_settings ORDER BY updated_at DESC LIMIT 1;
  IF NOT FOUND OR v_settings.is_enabled = false THEN
    RAISE EXCEPTION 'support_disabled: Support submissions are temporarily unavailable.';
  END IF;

  IF v_name IS NULL OR length(v_name) < 2 THEN
    RAISE EXCEPTION 'name required';
  END IF;
  IF v_email IS NULL OR v_email !~* '^[^@]+@[^@]+\.[^@]+$' THEN
    RAISE EXCEPTION 'valid email required';
  END IF;
  IF v_details IS NULL OR length(v_details) < 10 THEN
    RAISE EXCEPTION 'details required';
  END IF;
  IF length(v_details) > 1000 THEN
    RAISE EXCEPTION 'details too long';
  END IF;

  SELECT * INTO v_type
  FROM public.website_support_types
  WHERE id = p_type_id AND is_active = true;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'invalid type';
  END IF;

  v_priority := COALESCE(NULLIF(v_settings.default_priority, ''), 'normal');
  IF v_priority NOT IN ('low','normal','high','urgent') THEN
    v_priority := 'normal';
  END IF;

  FOR i IN 1..6 LOOP
    v_ref := public._website_ref('HD-ST-');
    BEGIN
      INSERT INTO public.tickets (
        subject, description, ticket_number, priority, status, channel,
        customer_name, customer_email, subcategory, metadata
      ) VALUES (
        v_type.name,
        v_details,
        v_ref,
        v_priority,
        'new',
        'website',
        v_name,
        v_email,
        v_type.slug,
        jsonb_build_object(
          'source', COALESCE(NULLIF(p_source, ''), 'public_web'),
          'page', '/contact',
          'type_id', v_type.id,
          'type_name', v_type.name
        )
      )
      RETURNING id INTO v_id;
      EXIT;
    EXCEPTION WHEN unique_violation THEN
      v_id := NULL;
    END;
  END LOOP;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'could not create ticket';
  END IF;

  PERFORM public._website_notify_staff(
    'support.tickets',
    'New support ticket ' || v_ref,
    v_name || ' submitted a ' || v_type.name || ' ticket.',
    '/dashboard/website/support',
    jsonb_build_object('ticket_id', v_id, 'reference', v_ref)
  );

  PERFORM public._website_queue_email(
    v_email,
    'support_ticket_received',
    'We received your support ticket ' || v_ref,
    COALESCE(v_settings.confirmation_message, 'Our team will get back to you shortly.'),
    jsonb_build_object('ticket_id', v_id, 'reference', v_ref)
  );

  RETURN jsonb_build_object(
    'ok', true,
    'id', v_id,
    'reference', v_ref,
    'confirmation_title', v_settings.confirmation_title,
    'confirmation_message', v_settings.confirmation_message
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_career_application(
  p_full_name text,
  p_email text,
  p_phone text DEFAULT NULL,
  p_job_id uuid DEFAULT NULL,
  p_preferred_location text DEFAULT NULL,
  p_linkedin_url text DEFAULT NULL,
  p_cover_letter text DEFAULT NULL,
  p_cv_path text DEFAULT NULL,
  p_cv_file_name text DEFAULT NULL,
  p_cv_mime text DEFAULT NULL,
  p_cv_size int DEFAULT NULL,
  p_source text DEFAULT 'public_web'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_name text := NULLIF(trim(COALESCE(p_full_name, '')), '');
  v_email text := lower(NULLIF(trim(COALESCE(p_email, '')), ''));
  v_settings public.careers_settings%ROWTYPE;
  v_job public.career_jobs%ROWTYPE;
  v_title text := 'General application';
  v_ref text;
  v_id uuid;
  v_cover text := NULLIF(trim(COALESCE(p_cover_letter, '')), '');
  v_path text := NULLIF(trim(COALESCE(p_cv_path, '')), '');
BEGIN
  SELECT * INTO v_settings FROM public.careers_settings ORDER BY updated_at DESC LIMIT 1;
  IF FOUND AND COALESCE(v_settings.applications_enabled, true) = false THEN
    RAISE EXCEPTION 'careers_disabled: Career applications are temporarily closed.';
  END IF;

  IF v_name IS NULL OR length(v_name) < 2 THEN
    RAISE EXCEPTION 'name required';
  END IF;
  IF v_email IS NULL OR v_email !~* '^[^@]+@[^@]+\.[^@]+$' THEN
    RAISE EXCEPTION 'valid email required';
  END IF;
  IF v_cover IS NOT NULL AND length(v_cover) > 1000 THEN
    RAISE EXCEPTION 'cover letter too long';
  END IF;
  IF v_path IS NOT NULL AND v_path NOT LIKE 'careers/inbox/%' THEN
    RAISE EXCEPTION 'invalid cv path';
  END IF;

  IF p_job_id IS NOT NULL THEN
    SELECT * INTO v_job
    FROM public.career_jobs
    WHERE id = p_job_id
      AND COALESCE(is_deleted, false) = false
      AND status = 'active'
      AND (application_deadline IS NULL OR application_deadline > now());
    IF NOT FOUND THEN
      RAISE EXCEPTION 'invalid position';
    END IF;
    v_title := v_job.title;
  ELSIF FOUND AND COALESCE(v_settings.allow_general_application, true) = false THEN
    RAISE EXCEPTION 'position required';
  END IF;

  FOR i IN 1..6 LOOP
    v_ref := public._website_ref('HD-CA-');
    BEGIN
      INSERT INTO public.career_applications (
        reference_number, job_id, position_title, full_name, email, phone,
        preferred_location, linkedin_url, cover_letter,
        cv_path, cv_file_name, cv_mime_type, cv_size_bytes,
        status, source
      ) VALUES (
        v_ref, p_job_id, v_title, v_name, v_email,
        NULLIF(trim(COALESCE(p_phone, '')), ''),
        NULLIF(trim(COALESCE(p_preferred_location, '')), ''),
        NULLIF(trim(COALESCE(p_linkedin_url, '')), ''),
        v_cover, v_path, p_cv_file_name, p_cv_mime, p_cv_size,
        'new', COALESCE(NULLIF(p_source, ''), 'public_web')
      )
      RETURNING id INTO v_id;
      EXIT;
    EXCEPTION WHEN unique_violation THEN
      v_id := NULL;
    END;
  END LOOP;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'could not create application';
  END IF;

  INSERT INTO public.career_application_history (application_id, from_status, to_status, reason)
  VALUES (v_id, NULL, 'new', 'Public website submission');

  PERFORM public._website_notify_staff(
    'careers.applications',
    'New career application ' || v_ref,
    v_name || ' applied for ' || v_title || '.',
    '/dashboard/website/careers',
    jsonb_build_object('application_id', v_id, 'reference', v_ref)
  );

  PERFORM public._website_queue_email(
    v_email,
    'career_application_received',
    COALESCE(v_settings.application_confirmation_title, 'Application received') || ' ' || v_ref,
    COALESCE(v_settings.application_confirmation_message, 'Thank you for applying.'),
    jsonb_build_object('application_id', v_id, 'reference', v_ref)
  );

  RETURN jsonb_build_object(
    'ok', true,
    'id', v_id,
    'reference', v_ref,
    'confirmation_title', COALESCE(v_settings.application_confirmation_title, 'Application received'),
    'confirmation_message', COALESCE(v_settings.application_confirmation_message, 'Thank you for applying.')
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_partnership_request(
  p_company_name text,
  p_contact_person text,
  p_email text,
  p_phone text,
  p_type_id uuid,
  p_proposal text DEFAULT NULL,
  p_documents jsonb DEFAULT '[]'::jsonb,
  p_source text DEFAULT 'public_web'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_company text := NULLIF(trim(COALESCE(p_company_name, '')), '');
  v_person text := NULLIF(trim(COALESCE(p_contact_person, '')), '');
  v_email text := lower(NULLIF(trim(COALESCE(p_email, '')), ''));
  v_phone text := NULLIF(trim(COALESCE(p_phone, '')), '');
  v_proposal text := NULLIF(trim(COALESCE(p_proposal, '')), '');
  v_settings public.partnership_settings%ROWTYPE;
  v_type public.partnership_types%ROWTYPE;
  v_ref text;
  v_id uuid;
  v_docs jsonb := COALESCE(p_documents, '[]'::jsonb);
BEGIN
  SELECT * INTO v_settings FROM public.partnership_settings ORDER BY updated_at DESC LIMIT 1;
  IF NOT FOUND OR v_settings.is_enabled = false THEN
    RAISE EXCEPTION 'partnerships_disabled: Partnership requests are temporarily unavailable.';
  END IF;

  IF v_company IS NULL OR length(v_company) < 2 THEN
    RAISE EXCEPTION 'company name required';
  END IF;
  IF v_person IS NULL OR length(v_person) < 2 THEN
    RAISE EXCEPTION 'contact person required';
  END IF;
  IF v_email IS NULL OR v_email !~* '^[^@]+@[^@]+\.[^@]+$' THEN
    RAISE EXCEPTION 'valid email required';
  END IF;
  IF v_phone IS NULL OR length(regexp_replace(v_phone, '\D', '', 'g')) < 10 THEN
    RAISE EXCEPTION 'valid phone required';
  END IF;
  IF v_proposal IS NOT NULL AND length(v_proposal) > 1500 THEN
    RAISE EXCEPTION 'proposal too long';
  END IF;

  SELECT * INTO v_type
  FROM public.partnership_types
  WHERE id = p_type_id AND is_active = true;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'invalid partnership type';
  END IF;

  IF jsonb_typeof(v_docs) <> 'array' THEN
    v_docs := '[]'::jsonb;
  END IF;

  FOR i IN 1..6 LOOP
    v_ref := public._website_ref('HD-PR-');
    BEGIN
      INSERT INTO public.partnership_requests (
        reference_number, company_name, contact_person, email, phone,
        type_id, type_name, proposal_summary, documents, status, priority, source
      ) VALUES (
        v_ref, v_company, v_person, v_email, v_phone,
        v_type.id, v_type.name, v_proposal, v_docs, 'new', 'normal',
        COALESCE(NULLIF(p_source, ''), 'public_web')
      )
      RETURNING id INTO v_id;
      EXIT;
    EXCEPTION WHEN unique_violation THEN
      v_id := NULL;
    END;
  END LOOP;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'could not create partnership request';
  END IF;

  INSERT INTO public.partnership_request_history (request_id, from_status, to_status, reason)
  VALUES (v_id, NULL, 'new', 'Public website submission');

  PERFORM public._website_notify_staff(
    'partnerships.view',
    'New partnership request ' || v_ref,
    v_company || ' submitted a ' || v_type.name || ' proposal.',
    '/dashboard/website/partnerships',
    jsonb_build_object('request_id', v_id, 'reference', v_ref)
  );

  PERFORM public._website_queue_email(
    v_email,
    'partnership_request_received',
    COALESCE(v_settings.confirmation_title, 'Partnership request received') || ' ' || v_ref,
    COALESCE(v_settings.confirmation_message, 'Our team will be in touch.'),
    jsonb_build_object('request_id', v_id, 'reference', v_ref)
  );

  RETURN jsonb_build_object(
    'ok', true,
    'id', v_id,
    'reference', v_ref,
    'confirmation_title', v_settings.confirmation_title,
    'confirmation_message', v_settings.confirmation_message
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- Admin update RPCs
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_update_website_ticket(
  p_ticket_id uuid,
  p_status text DEFAULT NULL,
  p_priority text DEFAULT NULL,
  p_assigned_to uuid DEFAULT NULL,
  p_admin_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_row public.tickets%ROWTYPE;
BEGIN
  IF NOT (
    public.has_permission('support.tickets', v_uid)
    OR public.has_permission('support.write', v_uid)
    OR public.has_permission('manage_tickets', v_uid)
    OR public.has_role('super_admin', v_uid)
    OR public.is_staff()
  ) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT * INTO v_row FROM public.tickets WHERE id = p_ticket_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ticket not found'; END IF;

  IF p_status IS NOT NULL AND p_status NOT IN (
    'new','open','in_progress','waiting_for_customer','resolved','closed'
  ) THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  IF p_priority IS NOT NULL AND p_priority NOT IN ('low','normal','high','urgent') THEN
    RAISE EXCEPTION 'invalid priority';
  END IF;

  UPDATE public.tickets
  SET status = COALESCE(p_status, status),
      priority = COALESCE(p_priority, priority),
      assigned_to = COALESCE(p_assigned_to, assigned_to),
      resolved_at = CASE WHEN COALESCE(p_status, status) = 'resolved' THEN COALESCE(resolved_at, now()) ELSE resolved_at END,
      closed_at = CASE WHEN COALESCE(p_status, status) = 'closed' THEN COALESCE(closed_at, now()) ELSE closed_at END,
      metadata = CASE
        WHEN p_admin_notes IS NOT NULL THEN
          COALESCE(metadata, '{}'::jsonb) || jsonb_build_object('admin_notes', p_admin_notes)
        ELSE metadata
      END,
      updated_at = now(),
      updated_by = v_uid
  WHERE id = p_ticket_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_update_career_application(
  p_application_id uuid,
  p_status text DEFAULT NULL,
  p_assigned_to uuid DEFAULT NULL,
  p_admin_notes text DEFAULT NULL,
  p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_old text;
BEGIN
  IF NOT (
    public.has_permission('careers.applications', v_uid)
    OR public.has_permission('manage_marketing', v_uid)
    OR public.has_role('super_admin', v_uid)
    OR public.has_role('admin', v_uid)
  ) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT status INTO v_old FROM public.career_applications WHERE id = p_application_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'application not found'; END IF;

  IF p_status IS NOT NULL AND p_status NOT IN (
    'new','reviewing','shortlisted','interview','assessment','offer','hired','rejected','withdrawn','archived'
  ) THEN
    RAISE EXCEPTION 'invalid status';
  END IF;

  UPDATE public.career_applications
  SET status = COALESCE(p_status, status),
      assigned_to = COALESCE(p_assigned_to, assigned_to),
      admin_notes = COALESCE(p_admin_notes, admin_notes),
      updated_at = now()
  WHERE id = p_application_id;

  IF p_status IS NOT NULL AND p_status IS DISTINCT FROM v_old THEN
    INSERT INTO public.career_application_history (
      application_id, from_status, to_status, changed_by, reason
    ) VALUES (p_application_id, v_old, p_status, v_uid, p_reason);
  END IF;

  RETURN jsonb_build_object('ok', true, 'from', v_old, 'to', COALESCE(p_status, v_old));
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_update_partnership_request(
  p_request_id uuid,
  p_status text DEFAULT NULL,
  p_priority text DEFAULT NULL,
  p_assigned_to uuid DEFAULT NULL,
  p_admin_notes text DEFAULT NULL,
  p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_old text;
BEGIN
  IF NOT (
    public.has_permission('partnerships.manage', v_uid)
    OR public.has_permission('manage_marketing', v_uid)
    OR public.has_role('super_admin', v_uid)
    OR public.has_role('admin', v_uid)
  ) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT status INTO v_old FROM public.partnership_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'request not found'; END IF;

  IF p_status IS NOT NULL AND p_status NOT IN (
    'new','under_review','contacted','negotiation','approved','declined','closed','archived'
  ) THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  IF p_priority IS NOT NULL AND p_priority NOT IN ('low','normal','high','urgent') THEN
    RAISE EXCEPTION 'invalid priority';
  END IF;

  UPDATE public.partnership_requests
  SET status = COALESCE(p_status, status),
      priority = COALESCE(p_priority, priority),
      assigned_to = COALESCE(p_assigned_to, assigned_to),
      admin_notes = COALESCE(p_admin_notes, admin_notes),
      updated_at = now()
  WHERE id = p_request_id;

  IF p_status IS NOT NULL AND p_status IS DISTINCT FROM v_old THEN
    INSERT INTO public.partnership_request_history (
      request_id, from_status, to_status, changed_by, reason
    ) VALUES (p_request_id, v_old, p_status, v_uid, p_reason);
  END IF;

  RETURN jsonb_build_object('ok', true, 'from', v_old, 'to', COALESCE(p_status, v_old));
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_website_support_ticket(text, text, uuid, text, text)
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.submit_career_application(text, text, text, uuid, text, text, text, text, text, text, int, text)
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.submit_partnership_request(text, text, text, text, uuid, text, jsonb, text)
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_website_ticket(uuid, text, text, uuid, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_career_application(uuid, text, uuid, text, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_partnership_request(uuid, text, text, uuid, text, text)
  TO authenticated;

-- Public writes go through SECURITY DEFINER RPCs only.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON
  public.career_applications,
  public.career_application_notes,
  public.career_application_history,
  public.partnership_requests,
  public.partnership_request_notes,
  public.partnership_request_history,
  public.website_form_outbox,
  public.website_support_settings,
  public.website_support_types,
  public.partnership_settings,
  public.partnership_types
FROM anon;

GRANT SELECT ON
  public.website_support_settings,
  public.website_support_types,
  public.partnership_settings,
  public.partnership_types
TO anon, authenticated;
