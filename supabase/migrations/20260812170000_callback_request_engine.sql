-- Callback request engine: departments, priorities, settings, requests, CRM hooks, RLS.

-- ---------------------------------------------------------------------------
-- Settings (singleton)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.callback_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  is_enabled boolean NOT NULL DEFAULT true,
  title text NOT NULL DEFAULT 'Request a Callback',
  subtitle text NOT NULL DEFAULT 'Share your details and our team will call you at a time that works best for you.',
  cta_text text NOT NULL DEFAULT 'Request Callback',
  success_title text NOT NULL DEFAULT 'Callback request received',
  success_message text NOT NULL DEFAULT 'Thank you. Our team has received your request and will contact you shortly.',
  trust_security text NOT NULL DEFAULT 'Your information is 100% secure',
  trust_response text NOT NULL DEFAULT 'Quick response within 24 hours',
  trust_expert text NOT NULL DEFAULT 'Speak with a real expert',
  default_response_hours int NOT NULL DEFAULT 24,
  after_hours_message text NOT NULL DEFAULT 'Callback requests are currently being accepted. Our team will contact you during business hours.',
  show_available_now boolean NOT NULL DEFAULT true,
  timezone text NOT NULL DEFAULT 'Africa/Lagos',
  preferred_time_options text[] NOT NULL DEFAULT ARRAY[
    'Morning (9am–12pm)',
    'Afternoon (12pm–3pm)',
    'Evening (3pm–6pm)',
    'Anytime'
  ],
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.callback_settings (id)
SELECT gen_random_uuid()
WHERE NOT EXISTS (SELECT 1 FROM public.callback_settings LIMIT 1);

CREATE TABLE IF NOT EXISTS public.callback_working_hours (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  weekday int NOT NULL CHECK (weekday BETWEEN 0 AND 6),
  start_time time NOT NULL DEFAULT '09:00',
  end_time time NOT NULL DEFAULT '18:00',
  is_active boolean NOT NULL DEFAULT true,
  UNIQUE (weekday)
);

INSERT INTO public.callback_working_hours (weekday, start_time, end_time, is_active)
VALUES
  (0, '09:00', '18:00', true),
  (1, '09:00', '18:00', true),
  (2, '09:00', '18:00', true),
  (3, '09:00', '18:00', true),
  (4, '09:00', '18:00', true),
  (5, '10:00', '14:00', true),
  (6, '00:00', '00:00', false)
ON CONFLICT (weekday) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Departments & priorities
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.callback_departments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  description text,
  icon text NOT NULL DEFAULT 'briefcase',
  response_hours int NOT NULL DEFAULT 24,
  sort_order int NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.callback_departments (name, slug, description, icon, response_hours, sort_order)
VALUES
  ('Sales', 'sales', 'Property sales and inspections', 'home', 4, 1),
  ('Investment', 'investment', 'Investment opportunities and ROI', 'trending-up', 8, 2),
  ('Legal', 'legal', 'Contracts and documentation', 'scale', 24, 3),
  ('Construction', 'construction', 'Build progress and site queries', 'hard-hat', 24, 4),
  ('Architecture', 'architecture', 'Design and floor plans', 'pen-tool', 24, 5),
  ('Mortgage', 'mortgage', 'Financing and payment plans', 'landmark', 12, 6),
  ('Customer Support', 'customer-support', 'General support and complaints', 'headphones', 8, 7),
  ('Partnership', 'partnership', 'Business partnerships', 'handshake', 48, 8)
ON CONFLICT (slug) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.callback_priorities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  description text,
  response_hours int NOT NULL DEFAULT 24,
  sort_order int NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.callback_priorities (name, slug, description, response_hours, sort_order)
VALUES
  ('Normal', 'normal', 'Standard follow-up', 24, 1),
  ('High', 'high', 'Priority follow-up', 8, 2),
  ('Urgent', 'urgent', 'Immediate attention required', 2, 3)
ON CONFLICT (slug) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Callback requests
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.callback_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference_number text NOT NULL UNIQUE,
  full_name text NOT NULL,
  phone text NOT NULL,
  email text,
  preferred_time text,
  department_id uuid REFERENCES public.callback_departments(id) ON DELETE SET NULL,
  priority_id uuid REFERENCES public.callback_priorities(id) ON DELETE SET NULL,
  reason text NOT NULL,
  status text NOT NULL DEFAULT 'new'
    CHECK (status IN ('new','assigned','contacted','scheduled','completed','cancelled')),
  assigned_to uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  assigned_at timestamptz,
  source text NOT NULL DEFAULT 'public_web',
  notes text,
  admin_notes text,
  visitor_profile_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  crm_client_id uuid,
  lead_id uuid,
  contacted_at timestamptz,
  scheduled_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS callback_requests_status_idx ON public.callback_requests (status);
CREATE INDEX IF NOT EXISTS callback_requests_department_idx ON public.callback_requests (department_id);
CREATE INDEX IF NOT EXISTS callback_requests_priority_idx ON public.callback_requests (priority_id);
CREATE INDEX IF NOT EXISTS callback_requests_assigned_idx ON public.callback_requests (assigned_to);
CREATE INDEX IF NOT EXISTS callback_requests_created_idx ON public.callback_requests (created_at DESC);
CREATE INDEX IF NOT EXISTS callback_requests_phone_idx ON public.callback_requests (phone);
CREATE INDEX IF NOT EXISTS callback_requests_reference_idx ON public.callback_requests (reference_number);

CREATE TABLE IF NOT EXISTS public.callback_status_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  callback_id uuid NOT NULL REFERENCES public.callback_requests(id) ON DELETE CASCADE,
  from_status text,
  to_status text NOT NULL,
  changed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  reason text,
  changed_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS callback_status_history_cb_idx
  ON public.callback_status_history (callback_id, changed_at DESC);

-- ---------------------------------------------------------------------------
-- Permissions
-- ---------------------------------------------------------------------------
INSERT INTO public.permissions (slug, name, description, module)
SELECT 'callbacks.view', 'View callbacks', 'View callback requests', 'crm'
WHERE NOT EXISTS (SELECT 1 FROM public.permissions WHERE slug = 'callbacks.view');

INSERT INTO public.permissions (slug, name, description, module)
SELECT 'callbacks.manage', 'Manage callbacks', 'Assign and update callback requests', 'crm'
WHERE NOT EXISTS (SELECT 1 FROM public.permissions WHERE slug = 'callbacks.manage');

INSERT INTO public.permissions (slug, name, description, module)
SELECT 'callbacks.settings', 'Callback settings', 'Configure callback form and departments', 'crm'
WHERE NOT EXISTS (SELECT 1 FROM public.permissions WHERE slug = 'callbacks.settings');

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE r.slug IN ('super_admin', 'admin')
  AND p.slug IN ('callbacks.view', 'callbacks.manage', 'callbacks.settings')
ON CONFLICT DO NOTHING;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE r.slug IN ('sales_team', 'customer_support')
  AND p.slug IN ('callbacks.view', 'callbacks.manage')
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.callback_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.callback_working_hours ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.callback_departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.callback_priorities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.callback_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.callback_status_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS callback_settings_public_read ON public.callback_settings;
CREATE POLICY callback_settings_public_read ON public.callback_settings
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS callback_hours_public_read ON public.callback_working_hours;
CREATE POLICY callback_hours_public_read ON public.callback_working_hours
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS callback_departments_public_read ON public.callback_departments;
CREATE POLICY callback_departments_public_read ON public.callback_departments
  FOR SELECT TO anon, authenticated USING (is_active = true);

DROP POLICY IF EXISTS callback_priorities_public_read ON public.callback_priorities;
CREATE POLICY callback_priorities_public_read ON public.callback_priorities
  FOR SELECT TO anon, authenticated USING (is_active = true);

DROP POLICY IF EXISTS callback_settings_admin ON public.callback_settings;
CREATE POLICY callback_settings_admin ON public.callback_settings
  FOR ALL TO authenticated
  USING (public.has_permission('callbacks.settings', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('callbacks.settings', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS callback_hours_admin ON public.callback_working_hours;
CREATE POLICY callback_hours_admin ON public.callback_working_hours
  FOR ALL TO authenticated
  USING (public.has_permission('callbacks.settings', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('callbacks.settings', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS callback_departments_admin ON public.callback_departments;
CREATE POLICY callback_departments_admin ON public.callback_departments
  FOR ALL TO authenticated
  USING (public.has_permission('callbacks.settings', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('callbacks.settings', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS callback_priorities_admin ON public.callback_priorities;
CREATE POLICY callback_priorities_admin ON public.callback_priorities
  FOR ALL TO authenticated
  USING (public.has_permission('callbacks.settings', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('callbacks.settings', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS callback_requests_admin ON public.callback_requests;
CREATE POLICY callback_requests_admin ON public.callback_requests
  FOR ALL TO authenticated
  USING (
    public.has_permission('callbacks.view', auth.uid())
    OR public.has_permission('callbacks.manage', auth.uid())
    OR public.has_permission('crm.leads', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('callbacks.manage', auth.uid())
    OR public.has_permission('crm.leads', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

DROP POLICY IF EXISTS callback_history_admin ON public.callback_status_history;
CREATE POLICY callback_history_admin ON public.callback_status_history
  FOR SELECT TO authenticated
  USING (
    public.has_permission('callbacks.view', auth.uid())
    OR public.has_permission('crm.leads', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

-- No public SELECT on callback_requests — create via RPC only.

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.callback_requests;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ---------------------------------------------------------------------------
-- Public submit RPC
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.submit_callback_request(
  p_full_name text,
  p_phone text,
  p_reason text,
  p_preferred_time text DEFAULT NULL,
  p_department_id uuid DEFAULT NULL,
  p_priority_id uuid DEFAULT NULL,
  p_email text DEFAULT NULL,
  p_visitor_profile_id uuid DEFAULT NULL,
  p_source text DEFAULT 'public_web'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_name text := NULLIF(trim(COALESCE(p_full_name, '')), '');
  v_phone text := NULLIF(trim(COALESCE(p_phone, '')), '');
  v_reason text := NULLIF(trim(COALESCE(p_reason, '')), '');
  v_email text := lower(NULLIF(trim(COALESCE(p_email, '')), ''));
  v_enabled boolean;
  v_ref text;
  v_id uuid;
  v_lead_id uuid;
  v_first text;
  v_last text;
  v_space int;
  v_dept_name text;
  v_priority_name text;
  v_response_hours int := 24;
  v_crm_client_id uuid;
  v_crm_lead_id uuid;
  v_stage_id uuid;
  v_settings record;
BEGIN
  SELECT * INTO v_settings FROM public.callback_settings ORDER BY updated_at DESC LIMIT 1;
  IF NOT FOUND OR v_settings.is_enabled = false THEN
    RAISE EXCEPTION 'callback_disabled: Callback requests are temporarily unavailable.';
  END IF;
  v_enabled := true;
  v_response_hours := COALESCE(v_settings.default_response_hours, 24);

  IF v_name IS NULL OR length(v_name) < 2 THEN
    RAISE EXCEPTION 'full name required';
  END IF;
  IF v_phone IS NULL OR length(regexp_replace(v_phone, '\D', '', 'g')) < 10 THEN
    RAISE EXCEPTION 'valid phone required';
  END IF;
  IF v_reason IS NULL OR length(v_reason) < 3 THEN
    RAISE EXCEPTION 'reason required';
  END IF;

  IF p_department_id IS NOT NULL THEN
    SELECT name, response_hours INTO v_dept_name, v_response_hours
    FROM public.callback_departments
    WHERE id = p_department_id AND is_active = true;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'invalid department';
    END IF;
  END IF;

  IF p_priority_id IS NOT NULL THEN
    SELECT name, response_hours INTO v_priority_name, v_response_hours
    FROM public.callback_priorities
    WHERE id = p_priority_id AND is_active = true;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'invalid priority';
    END IF;
  ELSE
    SELECT id, name INTO p_priority_id, v_priority_name
    FROM public.callback_priorities
    WHERE slug = 'normal' AND is_active = true
    LIMIT 1;
  END IF;

  v_space := position(' ' in v_name);
  IF v_space > 0 THEN
    v_first := left(v_name, v_space - 1);
    v_last := trim(substr(v_name, v_space + 1));
  ELSE
    v_first := v_name;
    v_last := '';
  END IF;

  v_ref := 'HD-CB-' || to_char(now() AT TIME ZONE COALESCE(v_settings.timezone, 'Africa/Lagos'), 'YYYYMMDD')
           || '-' || lpad((floor(random() * 9000) + 1000)::int::text, 4, '0');

  INSERT INTO public.leads (
    first_name, last_name, phone, email, source, status, notes
  ) VALUES (
    v_first, v_last, v_phone, v_email, 'request_callback', 'new',
    trim(both E'\n' from concat_ws(E'\n',
      'Ref: ' || v_ref,
      CASE WHEN v_dept_name IS NOT NULL THEN 'Department: ' || v_dept_name END,
      CASE WHEN v_priority_name IS NOT NULL THEN 'Priority: ' || v_priority_name END,
      CASE WHEN p_preferred_time IS NOT NULL THEN 'Preferred time: ' || p_preferred_time END,
      'Reason: ' || v_reason
    ))
  )
  RETURNING id INTO v_lead_id;

  INSERT INTO public.callback_requests (
    reference_number, full_name, phone, email, preferred_time,
    department_id, priority_id, reason, status, source,
    visitor_profile_id, lead_id
  ) VALUES (
    v_ref, v_name, v_phone, v_email, NULLIF(trim(COALESCE(p_preferred_time, '')), ''),
    p_department_id, p_priority_id, v_reason, 'new', COALESCE(NULLIF(p_source, ''), 'public_web'),
    p_visitor_profile_id, v_lead_id
  )
  RETURNING id INTO v_id;

  INSERT INTO public.callback_status_history (callback_id, from_status, to_status, reason)
  VALUES (v_id, NULL, 'new', 'Public website submission');

  -- CRM upsert
  SELECT id INTO v_crm_client_id
  FROM public.crm_clients
  WHERE (v_email IS NOT NULL AND lower(email) = v_email) OR phone = v_phone
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_crm_client_id IS NULL THEN
    INSERT INTO public.crm_clients (
      client_code, full_name, email, phone, customer_type, relationship_status, profile_id
    ) VALUES (
      'CL-' || to_char(now(), 'YYYY') || '-' || lpad((floor(random() * 90000) + 10000)::int::text, 5, '0'),
      v_name, v_email, v_phone, 'guest', 'lead', p_visitor_profile_id
    )
    RETURNING id INTO v_crm_client_id;
  END IF;

  SELECT id INTO v_stage_id
  FROM public.crm_pipeline_stages
  WHERE slug IN ('new', 'qualified', 'contacted')
  ORDER BY CASE slug WHEN 'new' THEN 1 WHEN 'qualified' THEN 2 ELSE 3 END
  LIMIT 1;

  INSERT INTO public.crm_leads (client_id, stage_id, title, status, notes)
  VALUES (
    v_crm_client_id,
    v_stage_id,
    'Callback request — ' || v_ref,
    'open',
    trim(both E'\n' from concat_ws(E'\n',
      CASE WHEN v_dept_name IS NOT NULL THEN 'Department: ' || v_dept_name END,
      CASE WHEN v_priority_name IS NOT NULL THEN 'Priority: ' || v_priority_name END,
      'Reason: ' || v_reason
    ))
  )
  RETURNING id INTO v_crm_lead_id;

  INSERT INTO public.crm_activity_logs (
    client_id, event_type, title, description, payload, occurred_at
  ) VALUES (
    v_crm_client_id,
    'callback_requested',
    'Callback Requested',
    v_name || ' requested a callback (' || v_ref || ')',
    jsonb_build_object(
      'callback_id', v_id,
      'reference', v_ref,
      'lead_id', v_lead_id,
      'crm_lead_id', v_crm_lead_id,
      'department', v_dept_name,
      'priority', v_priority_name
    ),
    now()
  );

  UPDATE public.callback_requests
  SET crm_client_id = v_crm_client_id, updated_at = now()
  WHERE id = v_id;

  RETURN jsonb_build_object(
    'ok', true,
    'reference', v_ref,
    'callback_id', v_id,
    'lead_id', v_lead_id,
    'crm_client_id', v_crm_client_id,
    'department', v_dept_name,
    'priority', v_priority_name,
    'response_hours', v_response_hours
  );
END;
$$;

-- Admin status / assign helper
CREATE OR REPLACE FUNCTION public.admin_update_callback_status(
  p_callback_id uuid,
  p_status text,
  p_reason text DEFAULT NULL,
  p_assigned_to uuid DEFAULT NULL,
  p_scheduled_at timestamptz DEFAULT NULL,
  p_admin_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old text;
  v_uid uuid := auth.uid();
  v_row record;
BEGIN
  IF NOT (
    public.has_permission('callbacks.manage', v_uid)
    OR public.has_permission('crm.leads', v_uid)
    OR public.has_role('super_admin', v_uid)
  ) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF p_status NOT IN ('new','assigned','contacted','scheduled','completed','cancelled') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;

  SELECT * INTO v_row FROM public.callback_requests WHERE id = p_callback_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'callback not found'; END IF;
  v_old := v_row.status;

  UPDATE public.callback_requests
  SET status = p_status,
      assigned_to = COALESCE(p_assigned_to, assigned_to),
      assigned_at = CASE
        WHEN p_assigned_to IS NOT NULL AND assigned_to IS DISTINCT FROM p_assigned_to THEN now()
        WHEN p_status = 'assigned' AND assigned_at IS NULL THEN now()
        ELSE assigned_at
      END,
      contacted_at = CASE WHEN p_status = 'contacted' THEN COALESCE(contacted_at, now()) ELSE contacted_at END,
      scheduled_at = COALESCE(p_scheduled_at, scheduled_at),
      completed_at = CASE WHEN p_status = 'completed' THEN COALESCE(completed_at, now()) ELSE completed_at END,
      admin_notes = COALESCE(p_admin_notes, admin_notes),
      updated_at = now()
  WHERE id = p_callback_id;

  INSERT INTO public.callback_status_history (
    callback_id, from_status, to_status, changed_by, reason
  ) VALUES (p_callback_id, v_old, p_status, v_uid, p_reason);

  RETURN jsonb_build_object('ok', true, 'from', v_old, 'to', p_status);
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_callback_request(
  text, text, text, text, uuid, uuid, text, uuid, text
) TO anon, authenticated;

GRANT EXECUTE ON FUNCTION public.admin_update_callback_status(
  uuid, text, text, uuid, timestamptz, text
) TO authenticated;
