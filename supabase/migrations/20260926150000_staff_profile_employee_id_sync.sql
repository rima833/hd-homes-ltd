-- Link profiles.employee_id when staff invite is accepted / auth user is created.
-- Backfill existing linked employees.

CREATE OR REPLACE FUNCTION public.accept_staff_invitation(p_token text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_user UUID := auth.uid();
  v public.staff_invitations%ROWTYPE;
  v_email TEXT;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  v := public.staff_invite_lookup(p_token);
  IF v.id IS NULL THEN RAISE EXCEPTION 'invite_not_found'; END IF;
  IF v.status = 'accepted' AND v.accepted_user_id = v_user THEN
    RETURN jsonb_build_object('ok', true, 'already_accepted', true, 'role_slug', v.role_slug);
  END IF;
  IF v.status <> 'pending' THEN RAISE EXCEPTION 'invite_not_pending:%', v.status; END IF;
  IF v.expires_at < now() THEN
    UPDATE public.staff_invitations SET status = 'expired', updated_at = now() WHERE id = v.id;
    RAISE EXCEPTION 'invite_expired';
  END IF;
  SELECT lower(email) INTO v_email FROM auth.users WHERE id = v_user;
  IF v_email IS DISTINCT FROM lower(v.email) THEN RAISE EXCEPTION 'invite_email_mismatch'; END IF;
  PERFORM public._apply_staff_role_to_user(v_user, v.role_slug, v_user);
  IF v.employee_id IS NOT NULL THEN
    UPDATE public.employees SET user_id = v_user, role_slug = v.role_slug,
      employment_status = 'active', updated_at = now(), updated_by = v_user
    WHERE id = v.employee_id;
    UPDATE public.profiles
    SET employee_id = v.employee_id, updated_at = now()
    WHERE id = v_user;
  END IF;
  UPDATE public.staff_invitations SET status = 'accepted', accepted_at = now(),
    accepted_user_id = v_user, updated_at = now(), token = NULL WHERE id = v.id;

  INSERT INTO public.audit_logs (user_id, action, module, entity_type, entity_id, metadata)
  VALUES (v_user, 'staff.invite_accepted', 'people', 'staff_invitation', v.id::text,
    jsonb_build_object('role_slug', v.role_slug, 'employee_id', v.employee_id));

  IF v.invited_by IS NOT NULL THEN
    BEGIN
      INSERT INTO public.notifications (
        user_id, title, body, channel, category, type, priority,
        action_url, metadata, status, delivery_status
      ) VALUES (
        v.invited_by,
        'Staff invite accepted',
        format('%s accepted the %s invite.', v.email, replace(v.role_slug, '_', ' ')),
        'in_app',
        'people',
        'staff_invite_accepted',
        'normal',
        '/dashboard/users',
        jsonb_build_object('invite_id', v.id, 'email', v.email, 'role_slug', v.role_slug),
        'active',
        'delivered'
      );
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END IF;

  RETURN jsonb_build_object('ok', true, 'role_slug', v.role_slug, 'employee_id', v.employee_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
    id, email, first_name, last_name, phone, country, state, city, account_status,
    employee_id
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
    END,
    CASE WHEN staff_hit THEN invite_rec.employee_id ELSE NULL END
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
      UPDATE public.profiles
      SET employee_id = invite_rec.employee_id, updated_at = now()
      WHERE id = NEW.id;
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
$function$;

-- Backfill profiles already linked via employees.user_id
UPDATE public.profiles p
SET employee_id = e.id,
    updated_at = now()
FROM public.employees e
WHERE e.user_id = p.id
  AND p.employee_id IS NULL
  AND coalesce(e.is_deleted, false) = false;
