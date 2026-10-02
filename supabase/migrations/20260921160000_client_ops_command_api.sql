-- Client Ops Command Center — admin RPCs (list, KPIs, queues, 360, assign owner).
-- Mirrors IMP desk patterns against crm_clients + linked portal clients.

BEGIN;

CREATE OR REPLACE FUNCTION public.admin_list_clients(
  p_search text DEFAULT NULL,
  p_relationship_status text DEFAULT NULL,
  p_customer_type text DEFAULT NULL,
  p_assigned_staff_id uuid DEFAULT NULL,
  p_unassigned_only boolean DEFAULT false,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_limit integer := least(greatest(COALESCE(p_limit, 50), 1), 100);
  v_offset integer := greatest(COALESCE(p_offset, 0), 0);
  v_search text := NULLIF(trim(COALESCE(p_search, '')), '');
  v_total bigint;
  v_items jsonb;
BEGIN
  IF NOT (
    public.has_permission('crm.read', auth.uid())
    OR public.has_permission('manage_crm', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  SELECT count(*) INTO v_total
  FROM public.crm_clients c
  WHERE (
      v_search IS NULL
      OR c.full_name ILIKE '%' || v_search || '%'
      OR c.email ILIKE '%' || v_search || '%'
      OR c.phone ILIKE '%' || v_search || '%'
      OR c.whatsapp ILIKE '%' || v_search || '%'
      OR c.client_code ILIKE '%' || v_search || '%'
      OR c.company ILIKE '%' || v_search || '%'
    )
    AND (
      p_relationship_status IS NULL
      OR c.relationship_status = p_relationship_status
    )
    AND (p_customer_type IS NULL OR c.customer_type = p_customer_type)
    AND (
      p_assigned_staff_id IS NULL
      OR c.assigned_staff_id = p_assigned_staff_id
    )
    AND (
      NOT COALESCE(p_unassigned_only, false)
      OR c.assigned_staff_id IS NULL
    );

  SELECT COALESCE(jsonb_agg(row_data ORDER BY sort_name, sort_id), '[]'::jsonb)
    INTO v_items
  FROM (
    SELECT
      jsonb_build_object(
        'id', c.id,
        'client_code', c.client_code,
        'full_name', c.full_name,
        'email', c.email,
        'phone', c.phone,
        'whatsapp', c.whatsapp,
        'customer_type', c.customer_type,
        'relationship_status', c.relationship_status,
        'assigned_staff_id', c.assigned_staff_id,
        'assigned_staff_name', NULLIF(trim(concat_ws(' ', staff.first_name, staff.last_name)), ''),
        'profile_id', c.profile_id,
        'portal_client_id', portal.id,
        'portal_status', portal.status,
        'has_portal', portal.id IS NOT NULL,
        'company', c.company,
        'budget_min', c.budget_min,
        'budget_max', c.budget_max,
        'preferred_locations', c.preferred_locations,
        'health_score', c.health_score,
        'health_label', c.health_label,
        'lead_score', c.lead_score,
        'open_leads', (
          SELECT count(*)::int FROM public.crm_leads l
          WHERE l.client_id = c.id
            AND l.status NOT IN ('won', 'lost', 'closed', 'converted')
        ),
        'open_tasks', (
          SELECT count(*)::int FROM public.crm_tasks t
          WHERE t.client_id = c.id
            AND t.status IN ('open', 'pending', 'in_progress')
        ),
        'pending_applications', (
          SELECT count(*)::int
          FROM public.client_property_applications a
          WHERE portal.id IS NOT NULL
            AND a.client_id = portal.id
            AND COALESCE(a.is_deleted, false) = false
            AND a.status IN ('pending', 'submitted', 'under_review', 'info_requested')
        ),
        'created_at', c.created_at,
        'updated_at', c.updated_at
      ) AS row_data,
      lower(COALESCE(c.full_name, c.client_code, '')) AS sort_name,
      c.id AS sort_id
    FROM public.crm_clients c
    LEFT JOIN public.profiles staff
      ON staff.id = c.assigned_staff_id
     AND COALESCE(staff.is_deleted, false) = false
    LEFT JOIN LATERAL (
      SELECT pc.id, pc.status
      FROM public.clients pc
      WHERE c.profile_id IS NOT NULL
        AND pc.user_id = c.profile_id
        AND COALESCE(pc.is_deleted, false) = false
      ORDER BY pc.created_at DESC
      LIMIT 1
    ) portal ON true
    WHERE (
        v_search IS NULL
        OR c.full_name ILIKE '%' || v_search || '%'
        OR c.email ILIKE '%' || v_search || '%'
        OR c.phone ILIKE '%' || v_search || '%'
        OR c.whatsapp ILIKE '%' || v_search || '%'
        OR c.client_code ILIKE '%' || v_search || '%'
        OR c.company ILIKE '%' || v_search || '%'
      )
      AND (
        p_relationship_status IS NULL
        OR c.relationship_status = p_relationship_status
      )
      AND (p_customer_type IS NULL OR c.customer_type = p_customer_type)
      AND (
        p_assigned_staff_id IS NULL
        OR c.assigned_staff_id = p_assigned_staff_id
      )
      AND (
        NOT COALESCE(p_unassigned_only, false)
        OR c.assigned_staff_id IS NULL
      )
    ORDER BY lower(COALESCE(c.full_name, c.client_code, '')), c.id
    LIMIT v_limit OFFSET v_offset
  ) q;

  RETURN jsonb_build_object(
    'items', v_items,
    'total', v_total,
    'limit', v_limit,
    'offset', v_offset,
    'has_more', (v_offset + v_limit) < v_total
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_get_client_desk_kpis()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT (
    public.has_permission('crm.read', auth.uid())
    OR public.has_permission('manage_crm', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  RETURN jsonb_build_object(
    'total_clients', (
      SELECT count(*)::int FROM public.crm_clients
    ),
    'active_buyers', (
      SELECT count(*)::int FROM public.crm_clients
      WHERE relationship_status IN ('active_buyer', 'vip', 'investor')
    ),
    'leads', (
      SELECT count(*)::int FROM public.crm_clients
      WHERE relationship_status = 'lead'
    ),
    'unassigned', (
      SELECT count(*)::int FROM public.crm_clients
      WHERE assigned_staff_id IS NULL
    ),
    'portal_linked', (
      SELECT count(*)::int
      FROM public.crm_clients c
      WHERE c.profile_id IS NOT NULL
        AND EXISTS (
          SELECT 1 FROM public.clients pc
          WHERE pc.user_id = c.profile_id
            AND COALESCE(pc.is_deleted, false) = false
        )
    ),
    'open_leads', (
      SELECT count(*)::int FROM public.crm_leads
      WHERE status NOT IN ('won', 'lost', 'closed', 'converted')
    ),
    'pending_applications', (
      SELECT count(*)::int
      FROM public.client_property_applications a
      WHERE COALESCE(a.is_deleted, false) = false
        AND a.status IN ('pending', 'submitted', 'under_review', 'info_requested')
    ),
    'pending_payments', (
      SELECT count(*)::int
      FROM public.client_payment_intents p
      WHERE COALESCE(p.is_deleted, false) = false
        AND p.status IN (
          'pending', 'submitted', 'awaiting_confirmation',
          'pending_verification', 'info_requested'
        )
    ),
    'overdue_tasks', (
      SELECT count(*)::int
      FROM public.crm_tasks t
      WHERE t.status IN ('open', 'pending', 'in_progress')
        AND t.due_at IS NOT NULL
        AND t.due_at < now()
    ),
    'generated_at', now()
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_get_client_work_queues()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT (
    public.has_permission('crm.read', auth.uid())
    OR public.has_permission('manage_crm', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  RETURN jsonb_build_object(
    'unassigned', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', c.id,
        'client_id', c.id,
        'title', c.full_name,
        'subtitle', concat_ws(' · ', c.client_code, c.email),
        'status', c.relationship_status,
        'created_at', c.created_at
      ) ORDER BY c.created_at)
      FROM (
        SELECT * FROM public.crm_clients
        WHERE assigned_staff_id IS NULL
        ORDER BY created_at
        LIMIT 50
      ) c
    ), '[]'::jsonb),
    'follow_ups', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', l.id,
        'client_id', l.client_id,
        'title', COALESCE(cc.full_name, l.title),
        'subtitle', concat_ws(' · ', l.title, l.preferred_location),
        'status', l.status,
        'priority', l.priority,
        'due_at', l.next_follow_up_at,
        'created_at', l.created_at
      ) ORDER BY l.next_follow_up_at NULLS LAST)
      FROM (
        SELECT * FROM public.crm_leads
        WHERE status NOT IN ('won', 'lost', 'closed', 'converted')
          AND (
            next_follow_up_at IS NULL
            OR next_follow_up_at <= now() + interval '7 days'
          )
        ORDER BY next_follow_up_at NULLS FIRST, created_at
        LIMIT 50
      ) l
      LEFT JOIN public.crm_clients cc ON cc.id = l.client_id
    ), '[]'::jsonb),
    'tasks', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', t.id,
        'client_id', t.client_id,
        'title', t.title,
        'subtitle', COALESCE(cc.full_name, cc.client_code),
        'status', t.status,
        'priority', t.priority,
        'due_at', t.due_at,
        'created_at', t.created_at
      ) ORDER BY t.due_at NULLS LAST)
      FROM (
        SELECT * FROM public.crm_tasks
        WHERE status IN ('open', 'pending', 'in_progress')
        ORDER BY due_at NULLS LAST, created_at
        LIMIT 50
      ) t
      LEFT JOIN public.crm_clients cc ON cc.id = t.client_id
    ), '[]'::jsonb),
    'applications', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', a.id,
        'client_id', crm.id,
        'portal_client_id', a.client_id,
        'title', COALESCE(crm.full_name, pc.client_code, 'Application'),
        'subtitle', concat_ws(' · ', a.status, a.payment_plan),
        'status', a.status,
        'amount', a.amount_offered,
        'created_at', a.created_at
      ) ORDER BY a.created_at DESC)
      FROM (
        SELECT * FROM public.client_property_applications
        WHERE COALESCE(is_deleted, false) = false
          AND status IN ('pending', 'submitted', 'under_review', 'info_requested')
        ORDER BY created_at DESC
        LIMIT 50
      ) a
      LEFT JOIN public.clients pc ON pc.id = a.client_id
      LEFT JOIN LATERAL (
        SELECT c.id, c.full_name
        FROM public.crm_clients c
        WHERE pc.user_id IS NOT NULL
          AND c.profile_id = pc.user_id
        ORDER BY c.updated_at DESC NULLS LAST
        LIMIT 1
      ) crm ON true
    ), '[]'::jsonb),
    'payments', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', p.id,
        'client_id', crm.id,
        'portal_client_id', p.client_id,
        'title', COALESCE(crm.full_name, pc.client_code, 'Payment'),
        'subtitle', COALESCE(
          p.payment_reference, p.bank_reference, p.provider_reference
        ),
        'status', p.status,
        'amount', p.amount,
        'currency', p.currency,
        'created_at', p.created_at
      ) ORDER BY p.created_at DESC)
      FROM (
        SELECT * FROM public.client_payment_intents
        WHERE COALESCE(is_deleted, false) = false
          AND status IN (
            'pending', 'submitted', 'awaiting_confirmation',
            'pending_verification', 'info_requested'
          )
        ORDER BY created_at DESC
        LIMIT 50
      ) p
      LEFT JOIN public.clients pc ON pc.id = p.client_id
      LEFT JOIN LATERAL (
        SELECT c.id, c.full_name
        FROM public.crm_clients c
        WHERE pc.user_id IS NOT NULL
          AND c.profile_id = pc.user_id
        ORDER BY c.updated_at DESC NULLS LAST
        LIMIT 1
      ) crm ON true
    ), '[]'::jsonb),
    'stale', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', c.id,
        'client_id', c.id,
        'title', c.full_name,
        'subtitle', concat_ws(' · ', c.client_code, c.relationship_status),
        'status', c.relationship_status,
        'created_at', c.updated_at
      ) ORDER BY c.updated_at)
      FROM (
        SELECT * FROM public.crm_clients
        WHERE updated_at < now() - interval '30 days'
          AND relationship_status NOT IN ('won', 'lost', 'inactive')
        ORDER BY updated_at
        LIMIT 50
      ) c
    ), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_get_client_360(p_client_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_client jsonb;
  v_portal_id uuid;
BEGIN
  IF NOT (
    public.has_permission('crm.read', auth.uid())
    OR public.has_permission('manage_crm', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  SELECT
    jsonb_build_object(
      'id', c.id,
      'client_code', c.client_code,
      'full_name', c.full_name,
      'email', c.email,
      'phone', c.phone,
      'whatsapp', c.whatsapp,
      'customer_type', c.customer_type,
      'relationship_status', c.relationship_status,
      'assigned_staff_id', c.assigned_staff_id,
      'assigned_staff_name', NULLIF(trim(concat_ws(' ', staff.first_name, staff.last_name)), ''),
      'profile_id', c.profile_id,
      'nationality', c.nationality,
      'preferred_language', c.preferred_language,
      'occupation', c.occupation,
      'company', c.company,
      'industry', c.industry,
      'budget_min', c.budget_min,
      'budget_max', c.budget_max,
      'preferred_locations', c.preferred_locations,
      'health_score', c.health_score,
      'health_label', c.health_label,
      'lead_score', c.lead_score,
      'ai_summary', c.ai_summary,
      'marketing_consent', c.marketing_consent,
      'metadata', c.metadata,
      'created_at', c.created_at,
      'updated_at', c.updated_at
    ),
    portal.id
  INTO v_client, v_portal_id
  FROM public.crm_clients c
  LEFT JOIN public.profiles staff
    ON staff.id = c.assigned_staff_id
   AND COALESCE(staff.is_deleted, false) = false
  LEFT JOIN LATERAL (
    SELECT pc.id
    FROM public.clients pc
    WHERE c.profile_id IS NOT NULL
      AND pc.user_id = c.profile_id
      AND COALESCE(pc.is_deleted, false) = false
    ORDER BY pc.created_at DESC
    LIMIT 1
  ) portal ON true
  WHERE c.id = p_client_id;

  IF v_client IS NULL THEN
    RAISE EXCEPTION 'client_not_found';
  END IF;

  RETURN v_client || jsonb_build_object(
    'portal_client_id', v_portal_id,
    'has_portal', v_portal_id IS NOT NULL,
    'leads', COALESCE((
      SELECT jsonb_agg(to_jsonb(l) ORDER BY l.created_at DESC)
      FROM public.crm_leads l
      WHERE l.client_id = p_client_id
    ), '[]'::jsonb),
    'tasks', COALESCE((
      SELECT jsonb_agg(to_jsonb(t) ORDER BY t.due_at NULLS LAST, t.created_at DESC)
      FROM public.crm_tasks t
      WHERE t.client_id = p_client_id
    ), '[]'::jsonb),
    'applications', CASE WHEN v_portal_id IS NULL THEN '[]'::jsonb ELSE COALESCE((
      SELECT jsonb_agg(to_jsonb(a) ORDER BY a.created_at DESC)
      FROM public.client_property_applications a
      WHERE a.client_id = v_portal_id
        AND COALESCE(a.is_deleted, false) = false
    ), '[]'::jsonb) END,
    'payments', CASE WHEN v_portal_id IS NULL THEN '[]'::jsonb ELSE COALESCE((
      SELECT jsonb_agg(to_jsonb(p) ORDER BY p.created_at DESC)
      FROM (
        SELECT * FROM public.client_payment_intents
        WHERE client_id = v_portal_id
          AND COALESCE(is_deleted, false) = false
        ORDER BY created_at DESC
        LIMIT 100
      ) p
    ), '[]'::jsonb) END
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_assign_client_owner(
  p_client_id uuid,
  p_staff_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT (
    public.has_permission('crm.assign', auth.uid())
    OR public.has_permission('crm.write', auth.uid())
    OR public.has_permission('manage_crm', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = p_staff_id
      AND COALESCE(p.is_deleted, false) = false
      AND EXISTS (
        SELECT 1
        FROM public.user_roles ur
        JOIN public.roles r ON r.id = ur.role_id
        WHERE ur.user_id = p.id
          AND COALESCE(ur.is_deleted, false) = false
          AND r.slug NOT IN ('client', 'investor')
      )
  ) THEN
    RAISE EXCEPTION 'staff_not_found';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.crm_clients WHERE id = p_client_id
  ) THEN
    RAISE EXCEPTION 'client_not_found';
  END IF;

  UPDATE public.crm_clients
  SET
    assigned_staff_id = p_staff_id,
    updated_at = now()
  WHERE id = p_client_id;

  RETURN p_staff_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_list_client_managers()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT (
    public.has_permission('crm.read', auth.uid())
    OR public.has_permission('manage_crm', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'id', p.id,
      'name', COALESCE(
        NULLIF(trim(concat_ws(' ', p.first_name, p.last_name)), ''),
        p.email,
        'Staff'
      ),
      'email', p.email
    ) ORDER BY lower(COALESCE(
      NULLIF(trim(concat_ws(' ', p.first_name, p.last_name)), ''),
      p.email,
      ''
    )))
    FROM public.profiles p
    WHERE COALESCE(p.is_deleted, false) = false
      AND EXISTS (
        SELECT 1
        FROM public.user_roles ur
        JOIN public.roles r ON r.id = ur.role_id
        WHERE ur.user_id = p.id
          AND COALESCE(ur.is_deleted, false) = false
          AND r.slug NOT IN ('client', 'investor')
      )
  ), '[]'::jsonb);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_clients(
  text, text, text, uuid, boolean, integer, integer
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_get_client_desk_kpis() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_get_client_work_queues() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_get_client_360(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_assign_client_owner(uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_list_client_managers() FROM PUBLIC;

REVOKE ALL ON FUNCTION public.admin_list_clients(
  text, text, text, uuid, boolean, integer, integer
) FROM anon;
REVOKE ALL ON FUNCTION public.admin_get_client_desk_kpis() FROM anon;
REVOKE ALL ON FUNCTION public.admin_get_client_work_queues() FROM anon;
REVOKE ALL ON FUNCTION public.admin_get_client_360(uuid) FROM anon;
REVOKE ALL ON FUNCTION public.admin_assign_client_owner(uuid, uuid) FROM anon;
REVOKE ALL ON FUNCTION public.admin_list_client_managers() FROM anon;

GRANT EXECUTE ON FUNCTION public.admin_list_clients(
  text, text, text, uuid, boolean, integer, integer
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_client_desk_kpis() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_client_work_queues() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_client_360(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_assign_client_owner(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_client_managers() TO authenticated;

COMMIT;
