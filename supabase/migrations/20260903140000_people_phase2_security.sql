-- Phase 2: People / Staff / Roles security hardening
-- Reuses existing tables. No destructive drops.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------------------------------------------------------------------------
-- 1) Schema extensions
-- ---------------------------------------------------------------------------
ALTER TABLE public.user_roles
  ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS assigned_by UUID REFERENCES auth.users(id);

ALTER TABLE public.staff_invitations
  ADD COLUMN IF NOT EXISTS token_hash TEXT;

ALTER TABLE public.employees
  ADD COLUMN IF NOT EXISTS deactivated_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS deactivated_by UUID REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS deactivation_reason TEXT;

-- Backfill invitation hashes (keep plaintext token for existing accept links).
UPDATE public.staff_invitations
SET token_hash = encode(digest(token, 'sha256'), 'hex')
WHERE token_hash IS NULL
  AND token IS NOT NULL
  AND length(token) > 0;

CREATE UNIQUE INDEX IF NOT EXISTS idx_staff_invitations_token_hash
  ON public.staff_invitations (token_hash)
  WHERE token_hash IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_employees_employment_status
  ON public.employees (employment_status)
  WHERE coalesce(is_deleted, false) = false;

CREATE INDEX IF NOT EXISTS idx_employees_department_active
  ON public.employees (department_id)
  WHERE coalesce(is_deleted, false) = false;

CREATE INDEX IF NOT EXISTS idx_employees_email_lower
  ON public.employees (lower(email))
  WHERE email IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_employees_user_id
  ON public.employees (user_id)
  WHERE user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_staff_invitations_status_expires
  ON public.staff_invitations (status, expires_at);

CREATE INDEX IF NOT EXISTS idx_user_roles_active_user
  ON public.user_roles (user_id)
  WHERE coalesce(is_deleted, false) = false
    AND coalesce(status, 'active') = 'active';

CREATE INDEX IF NOT EXISTS idx_departments_status
  ON public.departments (status);

CREATE INDEX IF NOT EXISTS idx_teams_department
  ON public.teams (department_id);

-- Soft employment status guard (allow known values only).
DO $$
BEGIN
  ALTER TABLE public.employees
    DROP CONSTRAINT IF EXISTS employees_employment_status_check;
  ALTER TABLE public.employees
    ADD CONSTRAINT employees_employment_status_check
    CHECK (
      employment_status = ANY (ARRAY[
        'active','confirmed','probation','on_leave','remote',
        'suspended','inactive','resigned','terminated','retired','pending'
      ])
    );
EXCEPTION
  WHEN others THEN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- 2) Helper: hash invite tokens
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.staff_invite_token_hash(p_token TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT encode(digest(trim(p_token), 'sha256'), 'hex');
$$;

CREATE OR REPLACE FUNCTION public.staff_invite_lookup(p_token TEXT)
RETURNS public.staff_invitations
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v public.staff_invitations%ROWTYPE;
  v_hash TEXT := public.staff_invite_token_hash(p_token);
BEGIN
  SELECT * INTO v
  FROM public.staff_invitations
  WHERE token_hash = v_hash
     OR token = trim(p_token)
  ORDER BY created_at DESC
  LIMIT 1;
  RETURN v;
END;
$$;

-- ---------------------------------------------------------------------------
-- 3) Harden invite create / preview / accept to maintain hash
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_invite_staff(
  p_email TEXT,
  p_role_slug TEXT,
  p_first_name TEXT DEFAULT NULL,
  p_last_name TEXT DEFAULT NULL,
  p_phone TEXT DEFAULT NULL,
  p_department_id UUID DEFAULT NULL,
  p_team_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_email TEXT := lower(trim(p_email));
  v_role TEXT := lower(trim(p_role_slug));
  v_token TEXT;
  v_hash TEXT;
  v_employee_id UUID;
  v_code TEXT;
  v_existing UUID;
  v_invite public.staff_invitations%ROWTYPE;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF v_email IS NULL OR position('@' in v_email) = 0 THEN
    RAISE EXCEPTION 'invalid_email';
  END IF;

  IF NOT public.staff_invite_can_assign(v_role, v_actor) THEN
    RAISE EXCEPTION 'forbidden_role_assignment:%', v_role;
  END IF;

  UPDATE public.staff_invitations
  SET status = 'revoked', updated_at = now()
  WHERE lower(email) = v_email
    AND status = 'pending';

  v_token := encode(gen_random_bytes(24), 'hex');
  v_hash := public.staff_invite_token_hash(v_token);

  SELECT id INTO v_employee_id
  FROM public.employees
  WHERE lower(coalesce(email, work_email, '')) = v_email
    AND coalesce(is_deleted, false) = false
  LIMIT 1;

  IF v_employee_id IS NULL THEN
    SELECT 'HDH-EMP-' || lpad(
      (coalesce(max(
        NULLIF(regexp_replace(employee_code, '\D', '', 'g'), '')::int
      ), 0) + 1)::text,
      4,
      '0'
    )
    INTO v_code
    FROM public.employees;

    INSERT INTO public.employees (
      employee_code, first_name, last_name, email, work_email, phone,
      department_id, team_id, role_slug, employment_status, created_by
    ) VALUES (
      coalesce(v_code, 'HDH-EMP-0001'),
      coalesce(nullif(trim(p_first_name), ''), split_part(v_email, '@', 1)),
      coalesce(nullif(trim(p_last_name), ''), 'Staff'),
      v_email, v_email, nullif(trim(p_phone), ''),
      p_department_id, p_team_id, v_role, 'probation', v_actor
    )
    RETURNING id INTO v_employee_id;
  ELSE
    UPDATE public.employees
    SET role_slug = v_role,
        department_id = coalesce(p_department_id, department_id),
        team_id = coalesce(p_team_id, team_id),
        first_name = coalesce(nullif(trim(p_first_name), ''), first_name),
        last_name = coalesce(nullif(trim(p_last_name), ''), last_name),
        phone = coalesce(nullif(trim(p_phone), ''), phone),
        updated_at = now(),
        updated_by = v_actor
    WHERE id = v_employee_id;
  END IF;

  INSERT INTO public.staff_invitations (
    email, role_slug, first_name, last_name, phone,
    department_id, team_id, employee_id, invited_by,
    token, token_hash, status
  ) VALUES (
    v_email, v_role,
    nullif(trim(p_first_name), ''), nullif(trim(p_last_name), ''),
    nullif(trim(p_phone), ''),
    p_department_id, p_team_id, v_employee_id, v_actor,
    v_token, v_hash, 'pending'
  )
  RETURNING * INTO v_invite;

  SELECT id INTO v_existing
  FROM auth.users
  WHERE lower(email) = v_email
  LIMIT 1;

  IF v_existing IS NOT NULL THEN
    PERFORM public._apply_staff_role_to_user(v_existing, v_role, v_actor);

    UPDATE public.employees
    SET user_id = v_existing,
        employment_status = 'active',
        updated_at = now(),
        updated_by = v_actor
    WHERE id = v_employee_id;

    UPDATE public.staff_invitations
    SET status = 'accepted',
        accepted_at = now(),
        accepted_user_id = v_existing,
        updated_at = now()
    WHERE id = v_invite.id
    RETURNING * INTO v_invite;
  END IF;

  INSERT INTO public.audit_logs (user_id, action, module, entity_type, entity_id, metadata)
  VALUES (
    v_actor, 'staff.invite', 'people', 'staff_invitation', v_invite.id::text,
    jsonb_build_object(
      'email', v_email,
      'role_slug', v_role,
      'employee_id', v_employee_id,
      'status', v_invite.status
    )
  );

  RETURN jsonb_build_object(
    'id', v_invite.id,
    'email', v_invite.email,
    'role_slug', v_invite.role_slug,
    'token', v_token,
    'status', v_invite.status,
    'employee_id', v_invite.employee_id,
    'expires_at', v_invite.expires_at,
    'accepted_user_id', v_invite.accepted_user_id,
    'already_had_account', v_existing IS NOT NULL
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.preview_staff_invitation(p_token TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v public.staff_invitations%ROWTYPE;
BEGIN
  v := public.staff_invite_lookup(p_token);
  IF v.id IS NULL THEN
    RETURN NULL;
  END IF;

  IF v.status <> 'pending' OR v.expires_at < now() THEN
    RETURN jsonb_build_object(
      'valid', false,
      'status', CASE WHEN v.expires_at < now() THEN 'expired' ELSE v.status END,
      'email', v.email,
      'role_slug', v.role_slug
    );
  END IF;

  RETURN jsonb_build_object(
    'valid', true,
    'status', v.status,
    'email', v.email,
    'role_slug', v.role_slug,
    'first_name', v.first_name,
    'last_name', v.last_name,
    'expires_at', v.expires_at
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.accept_staff_invitation(p_token TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user UUID := auth.uid();
  v public.staff_invitations%ROWTYPE;
  v_email TEXT;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  v := public.staff_invite_lookup(p_token);
  IF v.id IS NULL THEN
    RAISE EXCEPTION 'invite_not_found';
  END IF;

  IF v.status = 'accepted' AND v.accepted_user_id = v_user THEN
    RETURN jsonb_build_object(
      'ok', true,
      'already_accepted', true,
      'role_slug', v.role_slug
    );
  END IF;

  IF v.status <> 'pending' THEN
    RAISE EXCEPTION 'invite_not_pending:%', v.status;
  END IF;

  IF v.expires_at < now() THEN
    UPDATE public.staff_invitations
    SET status = 'expired', updated_at = now()
    WHERE id = v.id;
    RAISE EXCEPTION 'invite_expired';
  END IF;

  SELECT lower(email) INTO v_email FROM auth.users WHERE id = v_user;
  IF v_email IS DISTINCT FROM lower(v.email) THEN
    RAISE EXCEPTION 'invite_email_mismatch';
  END IF;

  PERFORM public._apply_staff_role_to_user(v_user, v.role_slug, v_user);

  IF v.employee_id IS NOT NULL THEN
    UPDATE public.employees
    SET user_id = v_user,
        role_slug = v.role_slug,
        employment_status = 'active',
        updated_at = now(),
        updated_by = v_user
    WHERE id = v.employee_id;
  END IF;

  UPDATE public.staff_invitations
  SET status = 'accepted',
      accepted_at = now(),
      accepted_user_id = v_user,
      updated_at = now()
  WHERE id = v.id;

  INSERT INTO public.audit_logs (user_id, action, module, entity_type, entity_id, metadata)
  VALUES (
    v_user, 'staff.invite_accepted', 'people', 'staff_invitation', v.id::text,
    jsonb_build_object('role_slug', v.role_slug, 'employee_id', v.employee_id)
  );

  RETURN jsonb_build_object('ok', true, 'role_slug', v.role_slug, 'employee_id', v.employee_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_reveal_staff_invite_token(p_invite_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v public.staff_invitations%ROWTYPE;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;
  IF NOT (
    public.has_permission('manage_users', v_actor)
    OR public.has_permission('manage_staff', v_actor)
    OR public.has_role('super_admin', v_actor)
  ) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT * INTO v FROM public.staff_invitations WHERE id = p_invite_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'invite_not_found';
  END IF;
  IF v.status <> 'pending' OR v.expires_at < now() THEN
    RAISE EXCEPTION 'invite_not_pending';
  END IF;

  RETURN jsonb_build_object(
    'id', v.id,
    'email', v.email,
    'token', v.token,
    'expires_at', v.expires_at
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- 4) Soft deactivate / reactivate staff (preserve history)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_deactivate_employee(
  p_employee_id UUID,
  p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_emp public.employees%ROWTYPE;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF NOT (
    public.has_permission('manage_staff', v_actor)
    OR public.has_permission('manage_organization', v_actor)
    OR public.has_permission('hr.employees', v_actor)
    OR public.has_role('super_admin', v_actor)
    OR public.has_role('admin', v_actor)
  ) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT * INTO v_emp FROM public.employees
  WHERE id = p_employee_id AND coalesce(is_deleted, false) = false;
  IF NOT FOUND THEN RAISE EXCEPTION 'employee_not_found'; END IF;

  UPDATE public.employees
  SET employment_status = 'inactive',
      status = 'inactive',
      deactivated_at = now(),
      deactivated_by = v_actor,
      deactivation_reason = nullif(trim(p_reason), ''),
      updated_at = now(),
      updated_by = v_actor
  WHERE id = p_employee_id;

  IF v_emp.user_id IS NOT NULL THEN
    UPDATE public.user_roles
    SET status = 'inactive',
        is_deleted = true,
        updated_at = now(),
        updated_by = v_actor
    WHERE user_id = v_emp.user_id
      AND coalesce(is_deleted, false) = false;

    UPDATE public.profiles
    SET account_status = 'suspended'::public.account_status,
        updated_at = now(),
        updated_by = v_actor
    WHERE id = v_emp.user_id;
  END IF;

  INSERT INTO public.audit_logs (user_id, action, module, entity_type, entity_id, metadata, old_values, new_values)
  VALUES (
    v_actor, 'staff.deactivate', 'people', 'employee', p_employee_id::text,
    jsonb_build_object('reason', p_reason),
    jsonb_build_object('employment_status', v_emp.employment_status),
    jsonb_build_object('employment_status', 'inactive')
  );

  RETURN jsonb_build_object('ok', true, 'employee_id', p_employee_id, 'status', 'inactive');
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_reactivate_employee(p_employee_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_emp public.employees%ROWTYPE;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF NOT (
    public.has_permission('manage_staff', v_actor)
    OR public.has_permission('manage_organization', v_actor)
    OR public.has_permission('hr.employees', v_actor)
    OR public.has_role('super_admin', v_actor)
    OR public.has_role('admin', v_actor)
  ) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT * INTO v_emp FROM public.employees WHERE id = p_employee_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'employee_not_found'; END IF;

  UPDATE public.employees
  SET employment_status = 'active',
      status = 'active',
      is_deleted = false,
      deactivated_at = NULL,
      deactivated_by = NULL,
      deactivation_reason = NULL,
      updated_at = now(),
      updated_by = v_actor
  WHERE id = p_employee_id;

  IF v_emp.user_id IS NOT NULL AND v_emp.role_slug IS NOT NULL THEN
    PERFORM public._apply_staff_role_to_user(v_emp.user_id, v_emp.role_slug, v_actor);
    UPDATE public.profiles
    SET account_status = 'active'::public.account_status,
        updated_at = now(),
        updated_by = v_actor
    WHERE id = v_emp.user_id;
  END IF;

  INSERT INTO public.audit_logs (user_id, action, module, entity_type, entity_id, metadata)
  VALUES (
    v_actor, 'staff.reactivate', 'people', 'employee', p_employee_id::text,
    jsonb_build_object('role_slug', v_emp.role_slug)
  );

  RETURN jsonb_build_object('ok', true, 'employee_id', p_employee_id, 'status', 'active');
END;
$$;

-- ---------------------------------------------------------------------------
-- 5) RLS alignment (permission-based, preserve existing grants)
-- ---------------------------------------------------------------------------

-- Departments / teams: directory readers need SELECT for enrichment.
DROP POLICY IF EXISTS departments_read ON public.departments;
CREATE POLICY departments_read ON public.departments
  FOR SELECT TO authenticated
  USING (
    public.has_permission('view_organization', auth.uid())
    OR public.has_permission('view_staff_directory', auth.uid())
    OR public.has_permission('manage_staff', auth.uid())
    OR public.has_permission('hr.read', auth.uid())
    OR public.has_permission('hr.employees', auth.uid())
    OR public.has_role('admin', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

DROP POLICY IF EXISTS departments_manage ON public.departments;
CREATE POLICY departments_manage ON public.departments
  FOR ALL TO authenticated
  USING (
    public.has_permission('manage_organization', auth.uid())
    OR public.has_permission('hr.write', auth.uid())
    OR public.has_role('admin', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('manage_organization', auth.uid())
    OR public.has_permission('hr.write', auth.uid())
    OR public.has_role('admin', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

DROP POLICY IF EXISTS teams_read ON public.teams;
CREATE POLICY teams_read ON public.teams
  FOR SELECT TO authenticated
  USING (
    public.has_permission('view_organization', auth.uid())
    OR public.has_permission('view_staff_directory', auth.uid())
    OR public.has_permission('manage_staff', auth.uid())
    OR public.has_permission('hr.read', auth.uid())
    OR public.has_permission('hr.employees', auth.uid())
    OR public.has_role('admin', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

DROP POLICY IF EXISTS teams_manage ON public.teams;
CREATE POLICY teams_manage ON public.teams
  FOR ALL TO authenticated
  USING (
    public.has_permission('manage_organization', auth.uid())
    OR public.has_permission('hr.write', auth.uid())
    OR public.has_role('admin', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('manage_organization', auth.uid())
    OR public.has_permission('hr.write', auth.uid())
    OR public.has_role('admin', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

-- Roles / role_permissions: honor manage_roles permission (not only super_admin role).
DROP POLICY IF EXISTS roles_manage ON public.roles;
CREATE POLICY roles_manage ON public.roles
  FOR ALL TO authenticated
  USING (
    public.has_permission('manage_roles', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('manage_roles', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

DROP POLICY IF EXISTS role_permissions_manage ON public.role_permissions;
CREATE POLICY role_permissions_manage ON public.role_permissions
  FOR ALL TO authenticated
  USING (
    public.has_permission('manage_roles', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('manage_roles', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

-- User roles: manage_users OR manage_roles OR elevated staff admins.
DROP POLICY IF EXISTS user_roles_manage ON public.user_roles;
CREATE POLICY user_roles_manage ON public.user_roles
  FOR ALL TO authenticated
  USING (
    public.has_permission('manage_users', auth.uid())
    OR public.has_permission('manage_roles', auth.uid())
    OR public.has_role('admin', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('manage_users', auth.uid())
    OR public.has_permission('manage_roles', auth.uid())
    OR public.has_role('admin', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

DROP POLICY IF EXISTS user_roles_select ON public.user_roles;
CREATE POLICY user_roles_select ON public.user_roles
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR public.has_permission('manage_users', auth.uid())
    OR public.has_permission('manage_roles', auth.uid())
    OR public.has_permission('view_staff_directory', auth.uid())
    OR public.has_role('admin', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

-- Employees manage WITH CHECK alignment.
DROP POLICY IF EXISTS employees_manage ON public.employees;
CREATE POLICY employees_manage ON public.employees
  FOR ALL TO authenticated
  USING (
    public.has_permission('manage_staff', auth.uid())
    OR public.has_permission('manage_organization', auth.uid())
    OR public.has_role('admin', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('manage_staff', auth.uid())
    OR public.has_permission('manage_organization', auth.uid())
    OR public.has_role('admin', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

-- Staff invitations: include elevated roles.
DROP POLICY IF EXISTS staff_invitations_manage ON public.staff_invitations;
CREATE POLICY staff_invitations_manage ON public.staff_invitations
  FOR ALL TO authenticated
  USING (
    public.has_permission('manage_users', auth.uid())
    OR public.has_permission('manage_staff', auth.uid())
    OR public.has_role('admin', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('manage_users', auth.uid())
    OR public.has_permission('manage_staff', auth.uid())
    OR public.has_role('admin', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

-- ---------------------------------------------------------------------------
-- 6) Signup trigger: honor token OR token_hash
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  default_role_id UUID;
  role_slug TEXT;
  account_type TEXT;
  invite_token TEXT;
  invite_rec public.staff_invitations%ROWTYPE;
BEGIN
  account_type := COALESCE(NEW.raw_user_meta_data ->> 'account_type', 'client');
  invite_token := nullif(trim(NEW.raw_user_meta_data ->> 'invitation_token'), '');

  role_slug := CASE WHEN account_type = 'investor' THEN 'investor' ELSE 'client' END;

  IF invite_token IS NOT NULL THEN
    invite_rec := public.staff_invite_lookup(invite_token);
    IF invite_rec.id IS NOT NULL
       AND invite_rec.status = 'pending'
       AND invite_rec.expires_at >= now()
       AND lower(invite_rec.email) = lower(NEW.email) THEN
      role_slug := invite_rec.role_slug;
      account_type := 'staff';
    ELSE
      SELECT * INTO invite_rec FROM public.staff_invitations WHERE false;
    END IF;
  END IF;

  INSERT INTO public.profiles (
    id, email, first_name, last_name, phone, country, state, city, account_status
  ) VALUES (
    NEW.id, NEW.email,
    COALESCE(NEW.raw_user_meta_data ->> 'first_name', invite_rec.first_name),
    COALESCE(NEW.raw_user_meta_data ->> 'last_name', invite_rec.last_name),
    COALESCE(NEW.raw_user_meta_data ->> 'phone', invite_rec.phone),
    COALESCE(NEW.raw_user_meta_data ->> 'country', 'Nigeria'),
    NEW.raw_user_meta_data ->> 'state',
    NEW.raw_user_meta_data ->> 'city',
    CASE WHEN NEW.email_confirmed_at IS NOT NULL
      THEN 'active'::public.account_status
      ELSE 'pending_verification'::public.account_status
    END
  );

  SELECT id INTO default_role_id
  FROM public.roles
  WHERE slug = role_slug AND coalesce(is_deleted, false) = false
  LIMIT 1;
  IF default_role_id IS NULL THEN
    SELECT id INTO default_role_id
    FROM public.roles
    WHERE slug = 'client' AND coalesce(is_deleted, false) = false
    LIMIT 1;
  END IF;

  IF default_role_id IS NOT NULL THEN
    INSERT INTO public.user_roles (user_id, role_id, is_primary)
    VALUES (NEW.id, default_role_id, true)
    ON CONFLICT (user_id, role_id) DO UPDATE
      SET is_primary = true, is_deleted = false, status = 'active';
  END IF;

  IF invite_rec.id IS NOT NULL THEN
    IF invite_rec.employee_id IS NOT NULL THEN
      UPDATE public.employees SET
        user_id = NEW.id,
        role_slug = invite_rec.role_slug,
        employment_status = 'active',
        first_name = coalesce(invite_rec.first_name, first_name),
        last_name = coalesce(invite_rec.last_name, last_name),
        updated_at = now()
      WHERE id = invite_rec.employee_id;
    END IF;
    UPDATE public.staff_invitations
    SET status = 'accepted',
        accepted_at = now(),
        accepted_user_id = NEW.id,
        updated_at = now()
    WHERE id = invite_rec.id;
  END IF;

  INSERT INTO public.user_preferences (user_id, marketing_opt_in, product_updates_opt_in)
  VALUES (
    NEW.id,
    COALESCE((NEW.raw_user_meta_data ->> 'marketing_opt_in')::boolean, false),
    COALESCE((NEW.raw_user_meta_data ->> 'product_updates_opt_in')::boolean, true)
  )
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO public.notification_preferences (user_id, marketing_email)
  VALUES (
    NEW.id,
    COALESCE((NEW.raw_user_meta_data ->> 'newsletter_opt_in')::boolean, false)
  )
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO public.security_settings (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;

  IF NEW.raw_user_meta_data ? 'terms_version' THEN
    INSERT INTO public.legal_acceptances (user_id, document_type, document_version) VALUES
      (NEW.id, 'terms', NEW.raw_user_meta_data ->> 'terms_version'),
      (NEW.id, 'privacy', COALESCE(NEW.raw_user_meta_data ->> 'privacy_version', 'privacy-v1.0')),
      (NEW.id, 'cookies', COALESCE(NEW.raw_user_meta_data ->> 'cookies_version', 'cookies-v1.0'));
  END IF;

  IF COALESCE(NEW.raw_user_meta_data ->> 'referral_code', '') <> '' THEN
    INSERT INTO public.user_referrals (referred_user_id, referral_code, referrer_user_id)
    SELECT NEW.id, UPPER(NEW.raw_user_meta_data ->> 'referral_code'), rl.owner_user_id
    FROM public.referral_links rl
    WHERE UPPER(rl.code) = UPPER(NEW.raw_user_meta_data ->> 'referral_code')
      AND rl.is_active = true AND rl.is_deleted = false
    ON CONFLICT (referred_user_id) DO NOTHING;
    INSERT INTO public.user_referrals (referred_user_id, referral_code)
    VALUES (NEW.id, UPPER(NEW.raw_user_meta_data ->> 'referral_code'))
    ON CONFLICT (referred_user_id) DO NOTHING;
  END IF;

  INSERT INTO public.registration_events (user_id, event_type, account_type, metadata)
  VALUES (
    NEW.id, 'succeeded', account_type,
    jsonb_build_object('source', 'handle_new_user', 'staff_invite', invite_rec.id IS NOT NULL)
  );

  RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------------
-- 7) Grants
-- ---------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.staff_invite_lookup(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.staff_invite_token_hash(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_reveal_staff_invite_token(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_deactivate_employee(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reactivate_employee(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_invite_staff(TEXT, TEXT, TEXT, TEXT, TEXT, UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.preview_staff_invitation(TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.accept_staff_invitation(TEXT) TO authenticated;
