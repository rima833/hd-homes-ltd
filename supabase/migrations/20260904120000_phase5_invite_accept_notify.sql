-- Phase 5 — notify inviter when a staff invitation is accepted
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

GRANT EXECUTE ON FUNCTION public.accept_staff_invitation(text) TO authenticated;
