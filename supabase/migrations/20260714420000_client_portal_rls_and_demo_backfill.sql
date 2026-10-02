-- Client portal: harden ensure_client_record + backfill demo data for empty accounts
-- APPLIED remotely 2026-07-22 as client_portal_rls_and_demo_backfill
-- (See remote migration history for canonical applied SQL.)

CREATE OR REPLACE FUNCTION public.ensure_client_record()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE
  uid uuid := auth.uid();
  row public.clients;
  code text;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

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
