-- Portal-linked clients are a real directory filter. Drop the previous
-- overload so PostgREST does not treat the two signatures as ambiguous.
DROP FUNCTION IF EXISTS public.admin_list_clients(text, text, text, uuid, boolean, integer, integer);

CREATE OR REPLACE FUNCTION public.admin_list_clients(
  p_search text DEFAULT NULL,
  p_relationship_status text DEFAULT NULL,
  p_customer_type text DEFAULT NULL,
  p_assigned_staff_id uuid DEFAULT NULL,
  p_unassigned_only boolean DEFAULT false,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0,
  p_portal_only boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_limit integer := least(greatest(COALESCE(p_limit, 50), 1), 100);
  v_offset integer := greatest(COALESCE(p_offset, 0), 0);
  v_search text := NULLIF(trim(COALESCE(p_search, '')), '');
  v_portal boolean := COALESCE(p_portal_only, false);
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
    AND (p_relationship_status IS NULL OR c.relationship_status = p_relationship_status)
    AND (p_customer_type IS NULL OR c.customer_type = p_customer_type)
    AND (p_assigned_staff_id IS NULL OR c.assigned_staff_id = p_assigned_staff_id)
    AND (NOT COALESCE(p_unassigned_only, false) OR c.assigned_staff_id IS NULL)
    AND (
      NOT v_portal
      OR EXISTS (
        SELECT 1 FROM public.clients pc
        WHERE c.profile_id IS NOT NULL
          AND pc.user_id = c.profile_id
          AND COALESCE(pc.is_deleted, false) = false
      )
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
          WHERE l.client_id = c.id AND l.status NOT IN ('won', 'lost', 'closed', 'converted')
        ),
        'open_tasks', (
          SELECT count(*)::int FROM public.crm_tasks t
          WHERE t.client_id = c.id AND t.status IN ('open', 'pending', 'in_progress')
        ),
        'pending_applications', (
          SELECT count(*)::int FROM public.client_property_applications a
          WHERE portal.id IS NOT NULL AND a.client_id = portal.id
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
      ON staff.id = c.assigned_staff_id AND COALESCE(staff.is_deleted, false) = false
    LEFT JOIN LATERAL (
      SELECT pc.id, pc.status FROM public.clients pc
      WHERE c.profile_id IS NOT NULL AND pc.user_id = c.profile_id
        AND COALESCE(pc.is_deleted, false) = false
      ORDER BY pc.created_at DESC LIMIT 1
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
      AND (p_relationship_status IS NULL OR c.relationship_status = p_relationship_status)
      AND (p_customer_type IS NULL OR c.customer_type = p_customer_type)
      AND (p_assigned_staff_id IS NULL OR c.assigned_staff_id = p_assigned_staff_id)
      AND (NOT COALESCE(p_unassigned_only, false) OR c.assigned_staff_id IS NULL)
      AND (NOT v_portal OR portal.id IS NOT NULL)
    ORDER BY lower(COALESCE(c.full_name, c.client_code, '')), c.id
    LIMIT v_limit OFFSET v_offset
  ) q;

  RETURN jsonb_build_object(
    'items', v_items, 'total', v_total, 'limit', v_limit, 'offset', v_offset,
    'has_more', (v_offset + v_limit) < v_total
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.admin_list_clients(text, text, text, uuid, boolean, integer, integer, boolean) TO authenticated, service_role;
