-- Client portal bootstrap v2: jsonb RPC + profile ensure + backfill missing clients
-- Fixes PostgREST composite parsing issues and RLS failures on direct INSERT fallback.

DROP FUNCTION IF EXISTS public.ensure_client_record();

CREATE OR REPLACE FUNCTION public.ensure_client_record()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid uuid := auth.uid();
  row public.clients;
  code text;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- clients.user_id FK references profiles(id)
  INSERT INTO public.profiles (id, email, account_status, status)
  SELECT
    u.id,
    COALESCE(u.email, u.id::text || '@users.local'),
    CASE
      WHEN u.email_confirmed_at IS NOT NULL THEN 'active'::public.account_status
      ELSE 'pending_verification'::public.account_status
    END,
    'active'
  FROM auth.users u
  WHERE u.id = uid
  ON CONFLICT (id) DO NOTHING;

  SELECT * INTO row
  FROM public.clients
  WHERE user_id = uid AND is_deleted = false
  LIMIT 1;

  IF FOUND THEN
    RETURN to_jsonb(row);
  END IF;

  code := 'CLT-' || upper(substring(replace(uid::text, '-', ''), 1, 8));

  INSERT INTO public.clients (user_id, client_code, status)
  VALUES (uid, code, 'active')
  ON CONFLICT (user_id) DO UPDATE
    SET updated_at = now(),
        is_deleted = false,
        status = 'active'
  RETURNING * INTO row;

  INSERT INTO public.client_preferences (client_id, preferences, status)
  VALUES (row.id, '{}'::jsonb, 'active')
  ON CONFLICT (client_id) DO NOTHING;

  RETURN to_jsonb(row);
END;
$$;

REVOKE ALL ON FUNCTION public.ensure_client_record() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ensure_client_record() TO authenticated;

-- Backfill client rows for portal roles that never got a clients record.
INSERT INTO public.clients (user_id, client_code, status)
SELECT
  p.id,
  'CLT-' || upper(substring(replace(p.id::text, '-', ''), 1, 8)),
  'active'
FROM public.profiles p
INNER JOIN public.user_roles ur
  ON ur.user_id = p.id AND ur.is_deleted = false
INNER JOIN public.roles r
  ON r.id = ur.role_id AND r.slug IN ('client', 'investor')
LEFT JOIN public.clients c
  ON c.user_id = p.id AND c.is_deleted = false
WHERE c.id IS NULL
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO public.client_preferences (client_id, preferences, status)
SELECT c.id, '{}'::jsonb, 'active'
FROM public.clients c
LEFT JOIN public.client_preferences cp ON cp.client_id = c.id
WHERE cp.id IS NULL;
