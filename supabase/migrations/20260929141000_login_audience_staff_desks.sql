-- Login welcome copy: name the staff desk the person will open
-- (Sales, Construction, Finance, Marketing), not only Admin / Client / Investor.

CREATE OR REPLACE FUNCTION public.login_email_audience(p_email text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email text := lower(btrim(coalesce(p_email, '')));
  v_user_id uuid;
  v_slugs text[];
  v_primary text;
  v_audience text;
BEGIN
  IF v_email = '' OR position('@' in v_email) = 0 OR length(v_email) < 5 THEN
    RETURN jsonb_build_object('found', false, 'audience', null);
  END IF;

  SELECT p.id
  INTO v_user_id
  FROM public.profiles p
  WHERE lower(p.email) = v_email
    AND coalesce(p.is_deleted, false) = false
  LIMIT 1;

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('found', false, 'audience', null);
  END IF;

  SELECT coalesce(array_agg(r.slug), '{}'::text[])
  INTO v_slugs
  FROM public.user_roles ur
  JOIN public.roles r ON r.id = ur.role_id
  WHERE ur.user_id = v_user_id
    AND coalesce(ur.is_deleted, false) = false
    AND coalesce(r.is_deleted, false) = false
    AND coalesce(ur.status, 'active') IN ('active', 'Active')
    AND (ur.expires_at IS NULL OR ur.expires_at > now());

  SELECT r.slug
  INTO v_primary
  FROM public.user_roles ur
  JOIN public.roles r ON r.id = ur.role_id
  WHERE ur.user_id = v_user_id
    AND coalesce(ur.is_primary, false) = true
    AND coalesce(ur.is_deleted, false) = false
    AND coalesce(r.is_deleted, false) = false
    AND coalesce(ur.status, 'active') IN ('active', 'Active')
    AND (ur.expires_at IS NULL OR ur.expires_at > now())
  LIMIT 1;

  v_audience := CASE v_primary
    WHEN 'super_admin' THEN 'admin'
    WHEN 'admin' THEN 'admin'
    WHEN 'sales_team' THEN 'sales'
    WHEN 'construction_manager' THEN 'construction'
    WHEN 'finance' THEN 'finance'
    WHEN 'marketing' THEN 'marketing'
    WHEN 'investor' THEN 'investor'
    WHEN 'client' THEN 'client'
    ELSE NULL
  END;

  IF v_audience IS NULL THEN
    IF 'super_admin' = ANY (v_slugs) OR 'admin' = ANY (v_slugs) THEN
      v_audience := 'admin';
    ELSIF 'sales_team' = ANY (v_slugs) THEN
      v_audience := 'sales';
    ELSIF 'construction_manager' = ANY (v_slugs) THEN
      v_audience := 'construction';
    ELSIF 'finance' = ANY (v_slugs) THEN
      v_audience := 'finance';
    ELSIF 'marketing' = ANY (v_slugs) THEN
      v_audience := 'marketing';
    ELSIF 'investor' = ANY (v_slugs) THEN
      v_audience := 'investor';
    ELSIF 'client' = ANY (v_slugs) THEN
      v_audience := 'client';
    ELSIF EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.id = v_user_id
        AND p.employee_id IS NOT NULL
    ) THEN
      v_audience := 'staff';
    ELSE
      v_audience := 'client';
    END IF;
  END IF;

  RETURN jsonb_build_object('found', true, 'audience', v_audience);
END;
$$;

COMMENT ON FUNCTION public.login_email_audience(text) IS
  'Returns the login audience for welcome copy: admin, sales, construction, finance, marketing, staff, investor, or client.';
