-- Staff invite E2E: Super Admin assigns Admin; Admin invites department staff.
-- Invite token flows through register (?invite=) metadata or accept RPC after login.

BEGIN;

-- ---------------------------------------------------------------------------
-- staff_invitations
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.staff_invitations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL,
  role_slug TEXT NOT NULL,
  first_name TEXT,
  last_name TEXT,
  phone TEXT,
  department_id UUID REFERENCES public.departments(id) ON DELETE SET NULL,
  team_id UUID REFERENCES public.teams(id) ON DELETE SET NULL,
  employee_id UUID REFERENCES public.employees(id) ON DELETE SET NULL,
  invited_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  token TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'accepted', 'revoked', 'expired')),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '14 days'),
  accepted_at TIMESTAMPTZ,
  accepted_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT staff_invitations_role_check CHECK (
    role_slug IN (
      'admin',
      'sales_team',
      'finance',
      'marketing',
      'construction_manager'
    )
  )
);

CREATE INDEX IF NOT EXISTS idx_staff_invitations_email
  ON public.staff_invitations (lower(email));
CREATE INDEX IF NOT EXISTS idx_staff_invitations_status
  ON public.staff_invitations (status);
CREATE INDEX IF NOT EXISTS idx_staff_invitations_token
  ON public.staff_invitations (token);

ALTER TABLE public.staff_invitations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS staff_invitations_select ON public.staff_invitations;
CREATE POLICY staff_invitations_select ON public.staff_invitations
  FOR SELECT TO authenticated
  USING (
    public.has_permission('manage_users')
    OR public.has_permission('manage_staff')
    OR invited_by = auth.uid()
    OR lower(email) = lower(COALESCE(auth.jwt() ->> 'email', ''))
  );

DROP POLICY IF EXISTS staff_invitations_manage ON public.staff_invitations;
CREATE POLICY staff_invitations_manage ON public.staff_invitations
  FOR ALL TO authenticated
  USING (
    public.has_permission('manage_users')
    OR public.has_permission('manage_staff')
  )
  WITH CHECK (
    public.has_permission('manage_users')
    OR public.has_permission('manage_staff')
  );

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.staff_invite_can_assign(
  p_role_slug TEXT,
  p_actor UUID DEFAULT auth.uid()
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_actor IS NULL THEN
    RETURN false;
  END IF;

  IF NOT (
    public.has_permission('manage_users', p_actor)
    OR public.has_permission('manage_staff', p_actor)
  ) THEN
    RETURN false;
  END IF;

  IF p_role_slug = 'admin' THEN
    RETURN public.has_role('super_admin', p_actor);
  END IF;

  IF p_role_slug IN (
    'sales_team', 'finance', 'marketing', 'construction_manager'
  ) THEN
    RETURN public.has_role('super_admin', p_actor)
      OR public.has_role('admin', p_actor);
  END IF;

  RETURN false;
END;
$$;

CREATE OR REPLACE FUNCTION public._apply_staff_role_to_user(
  p_user_id UUID,
  p_role_slug TEXT,
  p_actor UUID DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role_id UUID;
BEGIN
  SELECT id INTO v_role_id
  FROM public.roles
  WHERE slug = p_role_slug
    AND coalesce(is_deleted, false) = false
  LIMIT 1;

  IF v_role_id IS NULL THEN
    RAISE EXCEPTION 'role_not_found:%', p_role_slug;
  END IF;

  -- Demote existing primary roles
  UPDATE public.user_roles
  SET is_primary = false,
      updated_at = now(),
      updated_by = p_actor
  WHERE user_id = p_user_id
    AND is_primary = true
    AND coalesce(is_deleted, false) = false;

  INSERT INTO public.user_roles (user_id, role_id, is_primary, created_by, updated_by)
  VALUES (p_user_id, v_role_id, true, p_actor, p_actor)
  ON CONFLICT (user_id, role_id) DO UPDATE
    SET is_primary = true,
        is_deleted = false,
        status = 'active',
        updated_at = now(),
        updated_by = EXCLUDED.updated_by;
END;
$$;

-- ---------------------------------------------------------------------------
-- Create invite
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

  -- Revoke prior pending invites for same email
  UPDATE public.staff_invitations
  SET status = 'revoked',
      updated_at = now()
  WHERE lower(email) = v_email
    AND status = 'pending';

  v_token := encode(gen_random_bytes(24), 'hex');

  -- Create employee shell if needed
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
      employee_code,
      first_name,
      last_name,
      email,
      work_email,
      phone,
      department_id,
      team_id,
      role_slug,
      employment_status,
      created_by
    ) VALUES (
      coalesce(v_code, 'HDH-EMP-0001'),
      coalesce(nullif(trim(p_first_name), ''), split_part(v_email, '@', 1)),
      coalesce(nullif(trim(p_last_name), ''), 'Staff'),
      v_email,
      v_email,
      nullif(trim(p_phone), ''),
      p_department_id,
      p_team_id,
      v_role,
      'probation',
      v_actor
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
    email,
    role_slug,
    first_name,
    last_name,
    phone,
    department_id,
    team_id,
    employee_id,
    invited_by,
    token,
    status
  ) VALUES (
    v_email,
    v_role,
    nullif(trim(p_first_name), ''),
    nullif(trim(p_last_name), ''),
    nullif(trim(p_phone), ''),
    p_department_id,
    p_team_id,
    v_employee_id,
    v_actor,
    v_token,
    'pending'
  )
  RETURNING * INTO v_invite;

  -- If auth user already exists, assign role immediately and mark accepted
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

  RETURN jsonb_build_object(
    'id', v_invite.id,
    'email', v_invite.email,
    'role_slug', v_invite.role_slug,
    'token', v_invite.token,
    'status', v_invite.status,
    'employee_id', v_invite.employee_id,
    'expires_at', v_invite.expires_at,
    'accepted_user_id', v_invite.accepted_user_id,
    'already_had_account', v_existing IS NOT NULL
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_revoke_staff_invite(p_invite_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;
  IF NOT (
    public.has_permission('manage_users')
    OR public.has_permission('manage_staff')
  ) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.staff_invitations
  SET status = 'revoked',
      updated_at = now()
  WHERE id = p_invite_id
    AND status = 'pending';
END;
$$;

-- Public preview (safe fields only)
CREATE OR REPLACE FUNCTION public.preview_staff_invitation(p_token TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v public.staff_invitations%ROWTYPE;
BEGIN
  SELECT * INTO v
  FROM public.staff_invitations
  WHERE token = trim(p_token)
  LIMIT 1;

  IF NOT FOUND THEN
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

  SELECT * INTO v
  FROM public.staff_invitations
  WHERE token = trim(p_token)
  LIMIT 1;

  IF NOT FOUND THEN
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
        updated_at = now()
    WHERE id = v.employee_id;
  END IF;

  UPDATE public.staff_invitations
  SET status = 'accepted',
      accepted_at = now(),
      accepted_user_id = v_user,
      updated_at = now()
  WHERE id = v.id;

  RETURN jsonb_build_object(
    'ok', true,
    'role_slug', v.role_slug,
    'employee_id', v.employee_id
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- Signup trigger: honor invitation_token
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

  role_slug := CASE
    WHEN account_type = 'investor' THEN 'investor'
    ELSE 'client'
  END;

  IF invite_token IS NOT NULL THEN
    SELECT * INTO invite_rec
    FROM public.staff_invitations
    WHERE token = invite_token
      AND status = 'pending'
      AND expires_at >= now()
      AND lower(email) = lower(NEW.email)
    LIMIT 1;

    IF FOUND THEN
      role_slug := invite_rec.role_slug;
      account_type := 'staff';
    END IF;
  END IF;

  INSERT INTO public.profiles (
    id, email, first_name, last_name, phone, country, state, city, account_status
  )
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(
      NEW.raw_user_meta_data ->> 'first_name',
      invite_rec.first_name
    ),
    COALESCE(
      NEW.raw_user_meta_data ->> 'last_name',
      invite_rec.last_name
    ),
    COALESCE(
      NEW.raw_user_meta_data ->> 'phone',
      invite_rec.phone
    ),
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
      SET is_primary = true,
          is_deleted = false,
          status = 'active';
  END IF;

  IF invite_rec.id IS NOT NULL THEN
    IF invite_rec.employee_id IS NOT NULL THEN
      UPDATE public.employees
      SET user_id = NEW.id,
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

  INSERT INTO public.user_preferences (
    user_id, marketing_opt_in, product_updates_opt_in
  ) VALUES (
    NEW.id,
    COALESCE((NEW.raw_user_meta_data ->> 'marketing_opt_in')::boolean, false),
    COALESCE((NEW.raw_user_meta_data ->> 'product_updates_opt_in')::boolean, true)
  )
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO public.notification_preferences (
    user_id, marketing_email
  ) VALUES (
    NEW.id,
    COALESCE((NEW.raw_user_meta_data ->> 'newsletter_opt_in')::boolean, false)
  )
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO public.security_settings (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;

  IF NEW.raw_user_meta_data ? 'terms_version' THEN
    INSERT INTO public.legal_acceptances (user_id, document_type, document_version)
    VALUES
      (NEW.id, 'terms', NEW.raw_user_meta_data ->> 'terms_version'),
      (NEW.id, 'privacy', COALESCE(NEW.raw_user_meta_data ->> 'privacy_version', 'privacy-v1.0')),
      (NEW.id, 'cookies', COALESCE(NEW.raw_user_meta_data ->> 'cookies_version', 'cookies-v1.0'));
  END IF;

  IF COALESCE(NEW.raw_user_meta_data ->> 'referral_code', '') <> '' THEN
    INSERT INTO public.user_referrals (referred_user_id, referral_code, referrer_user_id)
    SELECT
      NEW.id,
      UPPER(NEW.raw_user_meta_data ->> 'referral_code'),
      rl.owner_user_id
    FROM public.referral_links rl
    WHERE UPPER(rl.code) = UPPER(NEW.raw_user_meta_data ->> 'referral_code')
      AND rl.is_active = true
      AND rl.is_deleted = false
    ON CONFLICT (referred_user_id) DO NOTHING;

    INSERT INTO public.user_referrals (referred_user_id, referral_code)
    VALUES (NEW.id, UPPER(NEW.raw_user_meta_data ->> 'referral_code'))
    ON CONFLICT (referred_user_id) DO NOTHING;
  END IF;

  INSERT INTO public.registration_events (user_id, event_type, account_type, metadata)
  VALUES (
    NEW.id,
    'succeeded',
    account_type,
    jsonb_build_object(
      'source', 'handle_new_user',
      'staff_invite', invite_rec.id IS NOT NULL
    )
  );

  RETURN NEW;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_invite_staff(TEXT, TEXT, TEXT, TEXT, TEXT, UUID, UUID)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_revoke_staff_invite(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.preview_staff_invitation(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.accept_staff_invitation(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_invite_can_assign(TEXT, UUID) TO authenticated;

-- Realtime
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.staff_invitations;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

COMMIT;
