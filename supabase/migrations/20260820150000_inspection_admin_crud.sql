-- Admin full CRUD for property inspections (create / update / delete with audit)

CREATE OR REPLACE FUNCTION public.admin_upsert_inspection(
  p_id uuid DEFAULT NULL,
  p_property_id uuid DEFAULT NULL,
  p_scheduled_at timestamptz DEFAULT NULL,
  p_status text DEFAULT 'scheduled',
  p_inspection_type text DEFAULT 'site_visit',
  p_visitor_name text DEFAULT NULL,
  p_visitor_email text DEFAULT NULL,
  p_visitor_phone text DEFAULT NULL,
  p_advisor_id uuid DEFAULT NULL,
  p_preferred_language text DEFAULT NULL,
  p_meeting_url text DEFAULT NULL,
  p_reason text DEFAULT NULL,
  p_clear_advisor boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_id uuid;
  v_old_status text;
  v_old_scheduled timestamptz;
  v_reference text;
  v_estate_id uuid;
BEGIN
  IF NOT (
    public.has_permission('properties.inspections', v_uid)
    OR public.has_role('super_admin', v_uid)
  ) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF p_status NOT IN ('scheduled','confirmed','completed','cancelled','no_show') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;

  IF p_inspection_type NOT IN (
    'site_visit','virtual_tour','open_house','investor_visit','handover'
  ) THEN
    RAISE EXCEPTION 'invalid inspection type';
  END IF;

  IF p_id IS NULL THEN
    IF p_property_id IS NULL OR p_scheduled_at IS NULL THEN
      RAISE EXCEPTION 'property_id and scheduled_at are required';
    END IF;

    BEGIN
      SELECT estate_id INTO v_estate_id
      FROM public.properties
      WHERE id = p_property_id;
    EXCEPTION WHEN undefined_column THEN
      v_estate_id := NULL;
    END;

    v_reference := 'INSP-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));

    INSERT INTO public.property_inspections (
      property_id,
      estate_id,
      scheduled_at,
      status,
      inspection_type,
      visitor_name,
      visitor_email,
      visitor_phone,
      advisor_id,
      preferred_language,
      meeting_url,
      reference,
      created_by,
      completed_at
    ) VALUES (
      p_property_id,
      v_estate_id,
      p_scheduled_at,
      p_status,
      p_inspection_type,
      NULLIF(trim(COALESCE(p_visitor_name, '')), ''),
      NULLIF(trim(COALESCE(p_visitor_email, '')), ''),
      NULLIF(trim(COALESCE(p_visitor_phone, '')), ''),
      p_advisor_id,
      NULLIF(trim(COALESCE(p_preferred_language, '')), ''),
      NULLIF(trim(COALESCE(p_meeting_url, '')), ''),
      v_reference,
      v_uid,
      CASE WHEN p_status = 'completed' THEN now() ELSE NULL END
    )
    RETURNING id INTO v_id;

    INSERT INTO public.inspection_status_history (
      inspection_id, from_status, to_status, changed_by, reason
    ) VALUES (
      v_id, NULL, p_status, v_uid, COALESCE(p_reason, 'Created by admin')
    );

    RETURN jsonb_build_object('ok', true, 'id', v_id, 'reference', v_reference, 'created', true);
  END IF;

  SELECT status, scheduled_at INTO v_old_status, v_old_scheduled
  FROM public.property_inspections
  WHERE id = p_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'inspection not found';
  END IF;

  IF p_property_id IS NOT NULL THEN
    BEGIN
      SELECT estate_id INTO v_estate_id
      FROM public.properties
      WHERE id = p_property_id;
    EXCEPTION WHEN undefined_column THEN
      v_estate_id := NULL;
    END;
  END IF;

  UPDATE public.property_inspections
  SET
    property_id = COALESCE(p_property_id, property_id),
    estate_id = COALESCE(v_estate_id, estate_id),
    scheduled_at = COALESCE(p_scheduled_at, scheduled_at),
    status = COALESCE(p_status, status),
    inspection_type = COALESCE(p_inspection_type, inspection_type),
    visitor_name = CASE
      WHEN p_visitor_name IS NULL THEN visitor_name
      ELSE NULLIF(trim(p_visitor_name), '')
    END,
    visitor_email = CASE
      WHEN p_visitor_email IS NULL THEN visitor_email
      ELSE NULLIF(trim(p_visitor_email), '')
    END,
    visitor_phone = CASE
      WHEN p_visitor_phone IS NULL THEN visitor_phone
      ELSE NULLIF(trim(p_visitor_phone), '')
    END,
    advisor_id = CASE
      WHEN p_clear_advisor THEN NULL
      WHEN p_advisor_id IS NULL THEN advisor_id
      ELSE p_advisor_id
    END,
    preferred_language = CASE
      WHEN p_preferred_language IS NULL THEN preferred_language
      ELSE NULLIF(trim(p_preferred_language), '')
    END,
    meeting_url = CASE
      WHEN p_meeting_url IS NULL THEN meeting_url
      ELSE NULLIF(trim(p_meeting_url), '')
    END,
    completed_at = CASE
      WHEN COALESCE(p_status, status) = 'completed' THEN COALESCE(completed_at, now())
      ELSE completed_at
    END,
    updated_at = now()
  WHERE id = p_id
  RETURNING id INTO v_id;

  IF p_status IS NOT NULL AND p_status IS DISTINCT FROM v_old_status THEN
    INSERT INTO public.inspection_status_history (
      inspection_id, from_status, to_status, changed_by, reason
    ) VALUES (
      v_id, v_old_status, p_status, v_uid, COALESCE(p_reason, 'Updated by admin')
    );
  ELSIF p_scheduled_at IS NOT NULL AND p_scheduled_at IS DISTINCT FROM v_old_scheduled THEN
    INSERT INTO public.inspection_status_history (
      inspection_id, from_status, to_status, changed_by, reason
    ) VALUES (
      v_id, v_old_status, v_old_status, v_uid,
      COALESCE(p_reason, 'Rescheduled by admin')
    );
  END IF;

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'created', false);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_delete_inspection(
  p_inspection_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF NOT (
    public.has_permission('properties.inspections', v_uid)
    OR public.has_role('super_admin', v_uid)
  ) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  DELETE FROM public.property_inspections WHERE id = p_inspection_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'inspection not found';
  END IF;

  RETURN jsonb_build_object('ok', true, 'id', p_inspection_id);
END;
$$;

DROP POLICY IF EXISTS inspection_status_history_admin_write ON public.inspection_status_history;
CREATE POLICY inspection_status_history_admin_write ON public.inspection_status_history
  FOR INSERT TO authenticated
  WITH CHECK (
    public.has_permission('properties.inspections', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

GRANT EXECUTE ON FUNCTION public.admin_upsert_inspection(
  uuid, uuid, timestamptz, text, text, text, text, text, uuid, text, text, text, boolean
) TO authenticated;

GRANT EXECUTE ON FUNCTION public.admin_delete_inspection(uuid) TO authenticated;
