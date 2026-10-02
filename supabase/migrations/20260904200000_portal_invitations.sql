-- Portal invitations: grant Client / Investor portal access via invite link
-- (no shared passwords). Links CRM clients / IMP investors on accept.

BEGIN;

CREATE TABLE IF NOT EXISTS public.portal_invitations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL,
  role_slug TEXT NOT NULL
    CHECK (role_slug IN ('client', 'investor')),
  first_name TEXT,
  last_name TEXT,
  phone TEXT,
  crm_client_id UUID REFERENCES public.crm_clients(id) ON DELETE SET NULL,
  investor_id UUID REFERENCES public.investors(id) ON DELETE SET NULL,
  invited_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  token TEXT,
  token_hash TEXT,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'accepted', 'revoked', 'expired')),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '14 days'),
  accepted_at TIMESTAMPTZ,
  accepted_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  revoked_at TIMESTAMPTZ,
  revoked_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_portal_invitations_email
  ON public.portal_invitations (lower(email));
CREATE INDEX IF NOT EXISTS idx_portal_invitations_status
  ON public.portal_invitations (status, expires_at);
CREATE UNIQUE INDEX IF NOT EXISTS idx_portal_invitations_token_hash
  ON public.portal_invitations (token_hash)
  WHERE token_hash IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_portal_invitations_crm_client
  ON public.portal_invitations (crm_client_id)
  WHERE crm_client_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_portal_invitations_investor
  ON public.portal_invitations (investor_id)
  WHERE investor_id IS NOT NULL;

ALTER TABLE public.portal_invitations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS portal_invitations_select ON public.portal_invitations;
CREATE POLICY portal_invitations_select ON public.portal_invitations
  FOR SELECT TO authenticated
  USING (
    public.has_permission('manage_users')
    OR public.has_permission('manage_crm')
    OR public.has_permission('crm.write')
    OR public.has_permission('investors.write')
    OR invited_by = auth.uid()
    OR lower(email) = lower(COALESCE(auth.jwt() ->> 'email', ''))
  );

DROP POLICY IF EXISTS portal_invitations_manage ON public.portal_invitations;
CREATE POLICY portal_invitations_manage ON public.portal_invitations
  FOR ALL TO authenticated
  USING (
    public.has_permission('manage_users')
    OR public.has_permission('manage_crm')
    OR public.has_permission('crm.write')
    OR public.has_permission('investors.write')
  )
  WITH CHECK (
    public.has_permission('manage_users')
    OR public.has_permission('manage_crm')
    OR public.has_permission('crm.write')
    OR public.has_permission('investors.write')
  );

CREATE OR REPLACE FUNCTION public.portal_invite_can_assign(
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

  IF public.has_permission('manage_users', p_actor)
     OR public.has_role('super_admin', p_actor)
     OR public.has_role('admin', p_actor) THEN
    RETURN p_role_slug IN ('client', 'investor');
  END IF;

  IF p_role_slug = 'client' THEN
    RETURN public.has_permission('manage_crm', p_actor)
      OR public.has_permission('crm.write', p_actor);
  END IF;

  IF p_role_slug = 'investor' THEN
    RETURN public.has_permission('investors.write', p_actor);
  END IF;

  RETURN false;
END;
$$;

CREATE OR REPLACE FUNCTION public.portal_invite_lookup(p_token TEXT)
RETURNS public.portal_invitations
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v public.portal_invitations%ROWTYPE;
  v_hash TEXT := public.staff_invite_token_hash(p_token);
BEGIN
  IF p_token IS NULL OR length(trim(p_token)) = 0 THEN
    RETURN v;
  END IF;

  SELECT * INTO v
  FROM public.portal_invitations
  WHERE token_hash = v_hash
     OR token = trim(p_token)
  LIMIT 1;

  RETURN v;
END;
$$;

CREATE OR REPLACE FUNCTION public._apply_portal_role_to_user(
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
  IF p_role_slug NOT IN ('client', 'investor') THEN
    RAISE EXCEPTION 'invalid_portal_role:%', p_role_slug;
  END IF;

  SELECT id INTO v_role_id
  FROM public.roles
  WHERE slug = p_role_slug
    AND coalesce(is_deleted, false) = false
  LIMIT 1;

  IF v_role_id IS NULL THEN
    RAISE EXCEPTION 'role_not_found:%', p_role_slug;
  END IF;

  INSERT INTO public.user_roles (user_id, role_id, is_primary, created_by, updated_by)
  VALUES (
    p_user_id,
    v_role_id,
    NOT EXISTS (
      SELECT 1 FROM public.user_roles ur
      WHERE ur.user_id = p_user_id
        AND coalesce(ur.is_deleted, false) = false
        AND coalesce(ur.status, 'active') = 'active'
        AND ur.is_primary = true
    ),
    p_actor,
    p_actor
  )
  ON CONFLICT (user_id, role_id) DO UPDATE
    SET is_deleted = false,
        status = 'active',
        updated_at = now(),
        updated_by = EXCLUDED.updated_by,
        is_primary = CASE
          WHEN public.user_roles.is_primary THEN true
          ELSE EXCLUDED.is_primary
        END;
END;
$$;

CREATE OR REPLACE FUNCTION public._link_portal_invite_targets(
  p_user_id UUID,
  p_invite public.portal_invitations,
  p_actor UUID DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_client_id UUID;
  v_code TEXT;
  v_investor_id UUID;
  v_existing_uid UUID;
  v_first TEXT := coalesce(nullif(trim(p_invite.first_name), ''), split_part(p_invite.email, '@', 1));
  v_last TEXT := coalesce(nullif(trim(p_invite.last_name), ''), '');
BEGIN
  IF p_invite.role_slug = 'client' THEN
    SELECT id INTO v_client_id
    FROM public.clients
    WHERE user_id = p_user_id
      AND coalesce(is_deleted, false) = false
    LIMIT 1;

    IF v_client_id IS NULL THEN
      v_code := 'CLT-' || upper(substring(replace(p_user_id::text, '-', ''), 1, 8));
      INSERT INTO public.clients (user_id, client_code, status)
      VALUES (p_user_id, v_code, 'active')
      ON CONFLICT (user_id) DO UPDATE
        SET is_deleted = false, status = 'active', updated_at = now()
      RETURNING id INTO v_client_id;
    END IF;

    IF p_invite.crm_client_id IS NOT NULL THEN
      UPDATE public.crm_clients
      SET profile_id = p_user_id,
          email = coalesce(email, p_invite.email),
          phone = coalesce(phone, p_invite.phone),
          updated_at = now()
      WHERE id = p_invite.crm_client_id
        AND (profile_id IS NULL OR profile_id = p_user_id);
    ELSE
      UPDATE public.crm_clients
      SET profile_id = p_user_id, updated_at = now()
      WHERE lower(email) = lower(p_invite.email)
        AND profile_id IS NULL;
    END IF;
  END IF;

  IF p_invite.role_slug = 'investor' THEN
    v_investor_id := p_invite.investor_id;

    IF v_investor_id IS NULL THEN
      SELECT id INTO v_investor_id
      FROM public.investors
      WHERE lower(email) = lower(p_invite.email)
        AND coalesce(is_deleted, false) = false
        AND user_id IS NULL
      ORDER BY updated_at DESC NULLS LAST
      LIMIT 1;
    END IF;

    IF v_investor_id IS NOT NULL THEN
      SELECT user_id INTO v_existing_uid
      FROM public.investors
      WHERE id = v_investor_id;

      IF v_existing_uid IS NOT NULL AND v_existing_uid <> p_user_id THEN
        RAISE EXCEPTION 'investor_already_linked';
      END IF;

      UPDATE public.investors
      SET user_id = p_user_id,
          email = coalesce(email, p_invite.email),
          phone = coalesce(phone, p_invite.phone),
          full_name = coalesce(
            nullif(trim(full_name), ''),
            nullif(trim(v_first || ' ' || v_last), ''),
            full_name
          ),
          lifecycle_status = CASE
            WHEN lifecycle_status IN ('prospect', 'onboarding') THEN 'active'
            ELSE lifecycle_status
          END,
          updated_at = now(),
          updated_by = coalesce(p_actor, p_user_id)
      WHERE id = v_investor_id;
    ELSE
      v_code := 'INV-' || upper(substring(replace(p_user_id::text, '-', ''), 1, 8));
      INSERT INTO public.investors (
        user_id, investor_code, full_name, email, phone, status, lifecycle_status, kyc_status
      ) VALUES (
        p_user_id,
        v_code,
        nullif(trim(v_first || ' ' || v_last), ''),
        p_invite.email,
        p_invite.phone,
        'active',
        'active',
        'pending'
      )
      ON CONFLICT (user_id) DO UPDATE
        SET email = coalesce(public.investors.email, EXCLUDED.email),
            phone = coalesce(public.investors.phone, EXCLUDED.phone),
            is_deleted = false,
            updated_at = now();
    END IF;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_invite_portal_user(
  p_email TEXT,
  p_role_slug TEXT,
  p_first_name TEXT DEFAULT NULL,
  p_last_name TEXT DEFAULT NULL,
  p_phone TEXT DEFAULT NULL,
  p_crm_client_id UUID DEFAULT NULL,
  p_investor_id UUID DEFAULT NULL
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
  v_existing UUID;
  v_invite public.portal_invitations%ROWTYPE;
  v_crm UUID := p_crm_client_id;
  v_inv UUID := p_investor_id;
  v_crm_email TEXT;
  v_inv_email TEXT;
  v_first TEXT;
  v_last TEXT;
  v_linked UUID;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF v_email IS NULL OR position('@' in v_email) = 0 THEN
    RAISE EXCEPTION 'invalid_email';
  END IF;
  IF v_role NOT IN ('client', 'investor') THEN
    RAISE EXCEPTION 'invalid_portal_role:%', v_role;
  END IF;
  IF NOT public.portal_invite_can_assign(v_role, v_actor) THEN
    RAISE EXCEPTION 'forbidden_role_assignment:%', v_role;
  END IF;

  IF v_role = 'client' AND v_inv IS NOT NULL THEN
    RAISE EXCEPTION 'investor_id_not_allowed_for_client';
  END IF;
  IF v_role = 'investor' AND v_crm IS NOT NULL THEN
    RAISE EXCEPTION 'crm_client_id_not_allowed_for_investor';
  END IF;

  IF v_crm IS NOT NULL THEN
    SELECT lower(email),
           nullif(split_part(coalesce(full_name, ''), ' ', 1), ''),
           nullif(trim(substr(coalesce(full_name, ''), greatest(strpos(coalesce(full_name, ''), ' '), 1) + 1)), ''),
           profile_id
    INTO v_crm_email, v_first, v_last, v_linked
    FROM public.crm_clients
    WHERE id = v_crm;

    IF NOT FOUND THEN RAISE EXCEPTION 'crm_client_not_found'; END IF;
    IF v_linked IS NOT NULL THEN
      RAISE EXCEPTION 'crm_client_already_has_portal';
    END IF;
    IF v_crm_email IS NOT NULL AND v_crm_email <> v_email THEN
      RAISE EXCEPTION 'invite_email_mismatch_crm';
    END IF;
    IF v_crm_email IS NULL THEN
      UPDATE public.crm_clients SET email = v_email, updated_at = now() WHERE id = v_crm;
    END IF;
  END IF;

  IF v_inv IS NOT NULL THEN
    SELECT lower(email),
           nullif(split_part(coalesce(full_name, ''), ' ', 1), ''),
           nullif(trim(substr(coalesce(full_name, ''), greatest(strpos(coalesce(full_name, ''), ' '), 1) + 1)), ''),
           user_id
    INTO v_inv_email, v_first, v_last, v_linked
    FROM public.investors
    WHERE id = v_inv AND coalesce(is_deleted, false) = false;

    IF NOT FOUND THEN RAISE EXCEPTION 'investor_not_found'; END IF;
    IF v_linked IS NOT NULL THEN
      RAISE EXCEPTION 'investor_already_has_portal';
    END IF;
    IF v_inv_email IS NOT NULL AND v_inv_email <> v_email THEN
      RAISE EXCEPTION 'invite_email_mismatch_investor';
    END IF;
    IF v_inv_email IS NULL THEN
      UPDATE public.investors SET email = v_email, updated_at = now() WHERE id = v_inv;
    END IF;
  END IF;

  UPDATE public.portal_invitations
  SET status = 'revoked',
      revoked_at = now(),
      revoked_by = v_actor,
      updated_at = now(),
      token = NULL
  WHERE lower(email) = v_email
    AND status = 'pending';

  v_token := encode(gen_random_bytes(24), 'hex');
  v_hash := public.staff_invite_token_hash(v_token);

  INSERT INTO public.portal_invitations (
    email, role_slug, first_name, last_name, phone,
    crm_client_id, investor_id, invited_by,
    token, token_hash, status
  ) VALUES (
    v_email,
    v_role,
    coalesce(nullif(trim(p_first_name), ''), v_first),
    coalesce(nullif(trim(p_last_name), ''), v_last),
    nullif(trim(p_phone), ''),
    v_crm,
    v_inv,
    v_actor,
    NULL,
    v_hash,
    'pending'
  )
  RETURNING * INTO v_invite;

  SELECT id INTO v_existing FROM auth.users WHERE lower(email) = v_email LIMIT 1;
  IF v_existing IS NOT NULL THEN
    PERFORM public._apply_portal_role_to_user(v_existing, v_role, v_actor);
    PERFORM public._link_portal_invite_targets(v_existing, v_invite, v_actor);
    UPDATE public.portal_invitations
    SET status = 'accepted',
        accepted_at = now(),
        accepted_user_id = v_existing,
        updated_at = now()
    WHERE id = v_invite.id
    RETURNING * INTO v_invite;
  END IF;

  INSERT INTO public.audit_logs (user_id, action, module, entity_type, entity_id, metadata)
  VALUES (
    v_actor, 'portal.invite', 'people', 'portal_invitation', v_invite.id::text,
    jsonb_build_object(
      'email', v_email,
      'role_slug', v_role,
      'crm_client_id', v_crm,
      'investor_id', v_inv,
      'status', v_invite.status
    )
  );

  RETURN jsonb_build_object(
    'id', v_invite.id,
    'email', v_invite.email,
    'role_slug', v_invite.role_slug,
    'token', CASE WHEN v_invite.status = 'pending' THEN v_token ELSE NULL END,
    'status', v_invite.status,
    'crm_client_id', v_invite.crm_client_id,
    'investor_id', v_invite.investor_id,
    'expires_at', v_invite.expires_at,
    'accepted_user_id', v_invite.accepted_user_id,
    'already_had_account', v_existing IS NOT NULL,
    'first_name', v_invite.first_name,
    'last_name', v_invite.last_name
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_reveal_portal_invite_token(p_invite_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v public.portal_invitations%ROWTYPE;
  v_token TEXT;
  v_hash TEXT;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;

  SELECT * INTO v FROM public.portal_invitations WHERE id = p_invite_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'invite_not_found'; END IF;
  IF NOT public.portal_invite_can_assign(v.role_slug, v_actor) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF v.status <> 'pending' OR v.expires_at < now() THEN
    RAISE EXCEPTION 'invite_not_pending';
  END IF;

  v_token := encode(gen_random_bytes(24), 'hex');
  v_hash := public.staff_invite_token_hash(v_token);

  UPDATE public.portal_invitations
  SET token = NULL, token_hash = v_hash, updated_at = now()
  WHERE id = v.id;

  INSERT INTO public.audit_logs (user_id, action, module, entity_type, entity_id, metadata)
  VALUES (
    v_actor, 'portal.invite_token_reveal', 'people', 'portal_invitation', v.id::text,
    jsonb_build_object('email', v.email, 'role_slug', v.role_slug)
  );

  RETURN jsonb_build_object(
    'id', v.id,
    'email', v.email,
    'role_slug', v.role_slug,
    'token', v_token,
    'expires_at', v.expires_at
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_revoke_portal_invite(p_invite_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v public.portal_invitations%ROWTYPE;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;

  SELECT * INTO v FROM public.portal_invitations WHERE id = p_invite_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'invite_not_found'; END IF;
  IF NOT public.portal_invite_can_assign(v.role_slug, v_actor) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.portal_invitations
  SET status = 'revoked',
      revoked_at = now(),
      revoked_by = v_actor,
      token = NULL,
      updated_at = now()
  WHERE id = p_invite_id
  RETURNING * INTO v;

  RETURN jsonb_build_object('ok', true, 'id', v.id, 'status', v.status);
END;
$$;

CREATE OR REPLACE FUNCTION public.preview_portal_invitation(p_token TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v public.portal_invitations%ROWTYPE;
BEGIN
  v := public.portal_invite_lookup(p_token);
  IF v.id IS NULL THEN
    RETURN NULL;
  END IF;

  IF v.status <> 'pending' OR v.expires_at < now() THEN
    RETURN jsonb_build_object(
      'valid', false,
      'kind', 'portal',
      'status', CASE WHEN v.expires_at < now() THEN 'expired' ELSE v.status END,
      'email', v.email,
      'role_slug', v.role_slug
    );
  END IF;

  RETURN jsonb_build_object(
    'valid', true,
    'kind', 'portal',
    'status', v.status,
    'email', v.email,
    'role_slug', v.role_slug,
    'first_name', v.first_name,
    'last_name', v.last_name,
    'expires_at', v.expires_at
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.accept_portal_invitation(p_token TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user UUID := auth.uid();
  v public.portal_invitations%ROWTYPE;
  v_email TEXT;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;

  v := public.portal_invite_lookup(p_token);
  IF v.id IS NULL THEN RAISE EXCEPTION 'invite_not_found'; END IF;

  IF v.status = 'accepted' AND v.accepted_user_id = v_user THEN
    RETURN jsonb_build_object('ok', true, 'already_accepted', true, 'role_slug', v.role_slug);
  END IF;

  IF v.status <> 'pending' THEN
    RAISE EXCEPTION 'invite_not_pending:%', v.status;
  END IF;

  IF v.expires_at < now() THEN
    UPDATE public.portal_invitations
    SET status = 'expired', updated_at = now()
    WHERE id = v.id;
    RAISE EXCEPTION 'invite_expired';
  END IF;

  SELECT lower(email) INTO v_email FROM auth.users WHERE id = v_user;
  IF v_email IS DISTINCT FROM lower(v.email) THEN
    RAISE EXCEPTION 'invite_email_mismatch';
  END IF;

  PERFORM public._apply_portal_role_to_user(v_user, v.role_slug, v_user);
  PERFORM public._link_portal_invite_targets(v_user, v, v_user);

  UPDATE public.portal_invitations
  SET status = 'accepted',
      accepted_at = now(),
      accepted_user_id = v_user,
      updated_at = now()
  WHERE id = v.id;

  INSERT INTO public.audit_logs (user_id, action, module, entity_type, entity_id, metadata)
  VALUES (
    v_user, 'portal.invite_accepted', 'people', 'portal_invitation', v.id::text,
    jsonb_build_object('role_slug', v.role_slug)
  );

  RETURN jsonb_build_object('ok', true, 'role_slug', v.role_slug);
END;
$$;

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
  portal_rec public.portal_invitations%ROWTYPE;
  staff_hit BOOLEAN := false;
  portal_hit BOOLEAN := false;
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
      staff_hit := true;
    ELSE
      SELECT * INTO invite_rec FROM public.staff_invitations WHERE false;
      portal_rec := public.portal_invite_lookup(invite_token);
      IF portal_rec.id IS NOT NULL
         AND portal_rec.status = 'pending'
         AND portal_rec.expires_at >= now()
         AND lower(portal_rec.email) = lower(NEW.email) THEN
        role_slug := portal_rec.role_slug;
        account_type := portal_rec.role_slug;
        portal_hit := true;
      ELSE
        SELECT * INTO portal_rec FROM public.portal_invitations WHERE false;
      END IF;
    END IF;
  END IF;

  INSERT INTO public.profiles (
    id, email, first_name, last_name, phone, country, state, city, account_status
  ) VALUES (
    NEW.id, NEW.email,
    COALESCE(
      NEW.raw_user_meta_data ->> 'first_name',
      CASE WHEN staff_hit THEN invite_rec.first_name
           WHEN portal_hit THEN portal_rec.first_name
           ELSE NULL END
    ),
    COALESCE(
      NEW.raw_user_meta_data ->> 'last_name',
      CASE WHEN staff_hit THEN invite_rec.last_name
           WHEN portal_hit THEN portal_rec.last_name
           ELSE NULL END
    ),
    COALESCE(
      NEW.raw_user_meta_data ->> 'phone',
      CASE WHEN staff_hit THEN invite_rec.phone
           WHEN portal_hit THEN portal_rec.phone
           ELSE NULL END
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
      SET is_primary = true, is_deleted = false, status = 'active';
  END IF;

  IF staff_hit THEN
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
  ELSIF portal_hit THEN
    PERFORM public._link_portal_invite_targets(NEW.id, portal_rec, NEW.id);
    UPDATE public.portal_invitations
    SET status = 'accepted',
        accepted_at = now(),
        accepted_user_id = NEW.id,
        updated_at = now()
    WHERE id = portal_rec.id;
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
    jsonb_build_object(
      'source', 'handle_new_user',
      'staff_invite', staff_hit,
      'portal_invite', portal_hit
    )
  );

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.portal_invite_lookup(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.portal_invite_can_assign(TEXT, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._apply_portal_role_to_user(UUID, TEXT, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._link_portal_invite_targets(UUID, public.portal_invitations, UUID) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.admin_invite_portal_user(TEXT, TEXT, TEXT, TEXT, TEXT, UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reveal_portal_invite_token(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_revoke_portal_invite(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.preview_portal_invitation(TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.accept_portal_invitation(TEXT) TO authenticated;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'portal_invitations'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.portal_invitations;
  END IF;
EXCEPTION WHEN others THEN
  NULL;
END $$;

COMMIT;
