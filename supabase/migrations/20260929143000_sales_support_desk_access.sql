-- Sales is the customer-support desk. Invited sales staff get the same
-- ticket and live-chat write access as the support tools already allow
-- for support.tickets holders.

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
JOIN public.permissions p
  ON p.slug IN ('support.write', 'support.chat')
WHERE r.slug = 'sales_team'
  AND COALESCE(r.is_deleted, false) = false
  AND NOT EXISTS (
    SELECT 1
    FROM public.role_permissions rp
    WHERE rp.role_id = r.id
      AND rp.permission_id = p.id
      AND COALESCE(rp.is_deleted, false) = false
  );
