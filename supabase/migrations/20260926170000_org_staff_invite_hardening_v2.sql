-- Harden invite RPCs, expire stale invites, align dual status fields.

REVOKE EXECUTE ON FUNCTION public.admin_resend_staff_invite(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_resend_staff_invite(uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.queue_transactional_email(text, text, uuid, jsonb, uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.queue_transactional_email(text, text, uuid, jsonb, uuid, jsonb) TO authenticated, service_role;

UPDATE public.staff_invitations
SET status = 'expired', updated_at = now()
WHERE status = 'pending'
  AND expires_at IS NOT NULL
  AND expires_at < now();

UPDATE public.employees
SET status = CASE
  WHEN employment_status IN ('invited', 'onboarding', 'pending') THEN 'pending'
  WHEN employment_status IN ('inactive', 'suspended', 'terminated', 'resigned', 'retired', 'archived') THEN 'inactive'
  ELSE 'active'
END
WHERE coalesce(is_deleted, false) = false;

UPDATE public.employees e
SET employment_status = 'archived',
    status = 'inactive',
    updated_at = now()
WHERE coalesce(e.is_deleted, false) = false
  AND e.user_id IS NULL
  AND e.email IS NOT NULL
  AND EXISTS (
    SELECT 1 FROM public.employees newer
    WHERE lower(coalesce(newer.email, '')) = lower(coalesce(e.email, ''))
      AND newer.id <> e.id
      AND newer.user_id IS NOT NULL
      AND coalesce(newer.is_deleted, false) = false
  );
