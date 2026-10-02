-- Roles follow-up: Approvals workflows write path (policies + access requests).

-- ---------------------------------------------------------------------------
-- RLS: approval_policies manage + access_requests write
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS approval_policies_staff ON public.approval_policies;
CREATE POLICY approval_policies_staff ON public.approval_policies
  FOR SELECT USING (
    public.can_manage_rbac()
    OR public.has_permission('manage_roles')
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS approval_policies_manage ON public.approval_policies;
CREATE POLICY approval_policies_manage ON public.approval_policies
  FOR ALL USING (public.can_manage_rbac())
  WITH CHECK (public.can_manage_rbac());

DROP POLICY IF EXISTS access_requests_own ON public.access_requests;
CREATE POLICY access_requests_own ON public.access_requests
  FOR SELECT USING (
    requester_id = auth.uid()
    OR public.can_manage_rbac()
    OR public.has_permission('manage_roles')
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS access_requests_insert ON public.access_requests;
CREATE POLICY access_requests_insert ON public.access_requests
  FOR INSERT WITH CHECK (
    requester_id = auth.uid()
    AND status = 'pending'
  );

DROP POLICY IF EXISTS access_requests_review ON public.access_requests;
CREATE POLICY access_requests_review ON public.access_requests
  FOR UPDATE USING (
    public.can_manage_rbac()
    OR public.has_permission('manage_roles')
    OR public.has_role('super_admin')
  )
  WITH CHECK (
    public.can_manage_rbac()
    OR public.has_permission('manage_roles')
    OR public.has_role('super_admin')
  );

-- ---------------------------------------------------------------------------
-- RPCs
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.set_approval_policy_enabled(
  p_policy_id uuid,
  p_enabled boolean
)
RETURNS public.approval_policies
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.approval_policies;
BEGIN
  IF NOT public.can_manage_rbac() THEN
    RAISE EXCEPTION 'insufficient permissions';
  END IF;

  UPDATE public.approval_policies
  SET
    enabled = COALESCE(p_enabled, enabled),
    updated_at = now()
  WHERE id = p_policy_id
  RETURNING * INTO v_row;

  IF v_row.id IS NULL THEN
    RAISE EXCEPTION 'approval policy not found';
  END IF;

  INSERT INTO public.permission_audit (
    actor_id, action, old_values, new_values, reason
  ) VALUES (
    auth.uid(),
    'approval_policy_toggled',
    jsonb_build_object('policy_id', p_policy_id),
    jsonb_build_object('enabled', v_row.enabled, 'action_type', v_row.action_type),
    v_row.name
  );

  RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_approval_policy_enabled(uuid, boolean) TO authenticated;

CREATE OR REPLACE FUNCTION public.create_access_request(
  p_reason text,
  p_permission_slug text DEFAULT NULL,
  p_role_slug text DEFAULT NULL
)
RETURNS public.access_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_reason text := trim(COALESCE(p_reason, ''));
  v_perm text := NULLIF(trim(COALESCE(p_permission_slug, '')), '');
  v_role text := NULLIF(trim(COALESCE(p_role_slug, '')), '');
  v_row public.access_requests;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;

  IF v_reason = '' THEN
    RAISE EXCEPTION 'reason is required';
  END IF;

  IF v_perm IS NULL AND v_role IS NULL THEN
    RAISE EXCEPTION 'permission_slug or role_slug is required';
  END IF;

  IF v_role IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.roles r
    WHERE r.slug = v_role AND COALESCE(r.is_deleted, false) = false
  ) THEN
    RAISE EXCEPTION 'role not found';
  END IF;

  IF v_perm IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.permissions p WHERE p.slug = v_perm
  ) THEN
    RAISE EXCEPTION 'permission not found';
  END IF;

  INSERT INTO public.access_requests (
    requester_id, permission_slug, role_slug, reason, status
  ) VALUES (
    v_uid, v_perm, v_role, v_reason, 'pending'
  )
  RETURNING * INTO v_row;

  INSERT INTO public.permission_audit (
    actor_id, action, permission_slug, role_slug, new_values, reason
  ) VALUES (
    v_uid,
    'access_request_created',
    v_perm,
    v_role,
    jsonb_build_object('request_id', v_row.id),
    v_reason
  );

  RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_access_request(text, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.review_access_request(
  p_request_id uuid,
  p_approve boolean,
  p_note text DEFAULT NULL
)
RETURNS public.access_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_row public.access_requests;
  v_role_id uuid;
  v_status text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;

  IF NOT (
    public.can_manage_rbac()
    OR public.has_permission('manage_roles')
    OR public.has_role('super_admin')
  ) THEN
    RAISE EXCEPTION 'insufficient permissions';
  END IF;

  SELECT * INTO v_row
  FROM public.access_requests
  WHERE id = p_request_id
  FOR UPDATE;

  IF v_row.id IS NULL THEN
    RAISE EXCEPTION 'access request not found';
  END IF;

  IF v_row.status <> 'pending' THEN
    RAISE EXCEPTION 'access request already reviewed';
  END IF;

  v_status := CASE WHEN COALESCE(p_approve, false) THEN 'approved' ELSE 'denied' END;

  IF v_status = 'approved' AND v_row.role_slug IS NOT NULL THEN
    SELECT id INTO v_role_id
    FROM public.roles
    WHERE slug = v_row.role_slug
      AND COALESCE(is_deleted, false) = false
    LIMIT 1;

    IF v_role_id IS NULL THEN
      RAISE EXCEPTION 'requested role no longer exists';
    END IF;

    INSERT INTO public.user_roles (user_id, role_id)
    VALUES (v_row.requester_id, v_role_id)
    ON CONFLICT (user_id, role_id) DO UPDATE
    SET
      is_deleted = false,
      status = 'active',
      updated_at = now();
  END IF;

  IF v_status = 'approved' AND v_row.permission_slug IS NOT NULL THEN
    INSERT INTO public.user_permissions (user_id, permission_id, granted)
    SELECT v_row.requester_id, p.id, true
    FROM public.permissions p
    WHERE p.slug = v_row.permission_slug
    ON CONFLICT (user_id, permission_id) DO UPDATE
    SET
      granted = true,
      is_deleted = false,
      status = 'active',
      updated_at = now();
  END IF;

  UPDATE public.access_requests
  SET
    status = v_status,
    reviewed_by = v_uid,
    reviewed_at = now()
  WHERE id = p_request_id
  RETURNING * INTO v_row;

  INSERT INTO public.permission_audit (
    actor_id,
    target_user_id,
    action,
    permission_slug,
    role_slug,
    new_values,
    reason
  ) VALUES (
    v_uid,
    v_row.requester_id,
    CASE WHEN v_status = 'approved' THEN 'access_request_approved' ELSE 'access_request_denied' END,
    v_row.permission_slug,
    v_row.role_slug,
    jsonb_build_object('request_id', v_row.id, 'status', v_status),
    NULLIF(trim(COALESCE(p_note, '')), '')
  );

  RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION public.review_access_request(uuid, boolean, text) TO authenticated;

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['approval_policies', 'access_requests']
  LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = t
    ) THEN
      EXECUTE format(
        'ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',
        t
      );
    END IF;
  END LOOP;
END $$;
