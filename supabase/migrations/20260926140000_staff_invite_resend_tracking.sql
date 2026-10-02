-- Track staff invite resends without creating duplicate invitation rows.
ALTER TABLE public.staff_invitations
  ADD COLUMN IF NOT EXISTS resend_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_sent_at timestamptz;

UPDATE public.staff_invitations
SET last_sent_at = coalesce(last_sent_at, created_at)
WHERE last_sent_at IS NULL;

CREATE OR REPLACE FUNCTION public.admin_resend_staff_invite(p_invite_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v public.staff_invitations%ROWTYPE;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;
  IF NOT (
    public.has_permission('manage_users', v_actor)
    OR public.has_permission('manage_staff', v_actor)
    OR public.has_permission('people.invite', v_actor)
    OR public.has_permission('people.manage', v_actor)
    OR public.has_role('super_admin', v_actor)
    OR public.has_role('admin', v_actor)
  ) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT * INTO v FROM public.staff_invitations WHERE id = p_invite_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'invite_not_found';
  END IF;
  IF v.status IN ('accepted', 'revoked', 'cancelled') THEN
    RAISE EXCEPTION 'invite_not_resendable';
  END IF;
  IF v.expires_at IS NOT NULL AND v.expires_at < now() THEN
    UPDATE public.staff_invitations SET status = 'expired', updated_at = now() WHERE id = v.id;
    RAISE EXCEPTION 'invite_expired';
  END IF;

  UPDATE public.staff_invitations
  SET resend_count = coalesce(resend_count, 0) + 1,
      last_sent_at = now(),
      status = CASE WHEN status = 'expired' THEN 'pending' ELSE status END,
      updated_at = now()
  WHERE id = v.id
  RETURNING * INTO v;

  INSERT INTO public.audit_logs (user_id, action, module, entity_type, entity_id, metadata)
  VALUES (
    v_actor, 'staff.invitation_resent', 'people', 'staff_invitation', v.id::text,
    jsonb_build_object('email', v.email, 'resend_count', v.resend_count)
  );

  RETURN jsonb_build_object(
    'id', v.id,
    'email', v.email,
    'role_slug', v.role_slug,
    'first_name', v.first_name,
    'status', v.status,
    'resend_count', v.resend_count,
    'last_sent_at', v.last_sent_at,
    'expires_at', v.expires_at
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_resend_staff_invite(uuid) TO authenticated;
