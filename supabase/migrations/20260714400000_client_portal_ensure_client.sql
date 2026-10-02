-- Client portal bootstrap: ensure_client_record() + clients self-update RLS
-- APPLIED remotely 2026-07-22 as client_portal_ensure_client

CREATE OR REPLACE FUNCTION public.ensure_client_record()
RETURNS public.clients
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

  SELECT * INTO row
  FROM public.clients
  WHERE user_id = uid AND is_deleted = false
  LIMIT 1;

  IF FOUND THEN
    RETURN row;
  END IF;

  code := 'CLT-' || upper(substring(replace(uid::text, '-', ''), 1, 8));

  INSERT INTO public.clients (user_id, client_code, status)
  VALUES (uid, code, 'active')
  ON CONFLICT (user_id) DO UPDATE
    SET updated_at = now()
  RETURNING * INTO row;

  RETURN row;
END;
$$;

REVOKE ALL ON FUNCTION public.ensure_client_record() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ensure_client_record() TO authenticated;

DROP POLICY IF EXISTS clients_self_insert ON public.clients;
CREATE POLICY clients_self_insert ON public.clients
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS clients_self_update ON public.clients;
CREATE POLICY clients_self_update ON public.clients
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
