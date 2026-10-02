-- Live work queues, investor ownership, and relationship tasks.
BEGIN;

DROP POLICY IF EXISTS investor_tasks_write ON public.investor_tasks;
DROP POLICY IF EXISTS investor_tasks_staff_write ON public.investor_tasks;
CREATE POLICY investor_tasks_staff_write ON public.investor_tasks
  FOR ALL TO authenticated
  USING (
    public.has_permission('investors.tasks', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('investors.tasks', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

CREATE OR REPLACE FUNCTION public.admin_get_investor_work_queues()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_can_read boolean;
  v_can_kyc boolean;
  v_can_payments boolean;
  v_can_tasks boolean;
BEGIN
  v_can_read := public.has_permission('investors.read', auth.uid())
    OR public.has_role('super_admin', auth.uid());
  IF NOT v_can_read THEN RAISE EXCEPTION 'not authorized'; END IF;
  v_can_kyc := public.has_permission('investors.kyc', auth.uid())
    OR public.has_role('super_admin', auth.uid());
  v_can_payments := public.has_permission('investors.payments', auth.uid())
    OR public.has_role('super_admin', auth.uid());
  v_can_tasks := public.has_permission('investors.tasks', auth.uid())
    OR public.has_role('super_admin', auth.uid());

  RETURN jsonb_build_object(
    'unassigned', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', i.id, 'investor_id', i.id, 'title', i.full_name,
        'subtitle', concat_ws(' · ', i.investor_code, i.email),
        'status', i.lifecycle_status, 'created_at', i.created_at
      ) ORDER BY i.created_at)
      FROM (
        SELECT * FROM public.investors
        WHERE assigned_staff_id IS NULL
          AND COALESCE(is_deleted, false) = false
        ORDER BY created_at LIMIT 50
      ) i
    ), '[]'::jsonb),
    'kyc', CASE WHEN v_can_kyc THEN COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', i.id, 'investor_id', i.id, 'title', i.full_name,
        'subtitle', concat_ws(' · ', i.investor_code, i.email),
        'status', i.kyc_status, 'created_at', i.created_at
      ) ORDER BY i.created_at)
      FROM (
        SELECT * FROM public.investors
        WHERE kyc_status NOT IN ('approved', 'partially_approved')
          AND COALESCE(is_deleted, false) = false
        ORDER BY created_at LIMIT 50
      ) i
    ), '[]'::jsonb) ELSE '[]'::jsonb END,
    'payments', CASE WHEN v_can_payments THEN COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', p.id, 'investor_id', p.investor_id,
        'title', COALESCE(i.full_name, i.investor_code),
        'subtitle', COALESCE(p.bank_reference, p.provider_reference),
        'status', p.status, 'amount', p.amount, 'currency', p.currency,
        'created_at', p.created_at
      ) ORDER BY p.created_at)
      FROM (
        SELECT * FROM public.investor_payment_intents
        WHERE status IN (
          'pending', 'submitted', 'awaiting_confirmation',
          'pending_verification', 'info_requested'
        ) AND COALESCE(is_deleted, false) = false
        ORDER BY created_at LIMIT 50
      ) p
      JOIN public.investors i ON i.id = p.investor_id
    ), '[]'::jsonb) ELSE '[]'::jsonb END,
    'tasks', CASE WHEN v_can_tasks THEN COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', t.id, 'investor_id', t.investor_id, 'title', t.title,
        'subtitle', COALESCE(i.full_name, i.investor_code),
        'status', t.status, 'priority', t.priority, 'due_at', t.due_at,
        'created_at', t.created_at
      ) ORDER BY t.due_at NULLS LAST, t.created_at)
      FROM (
        SELECT * FROM public.investor_tasks
        WHERE status IN ('open', 'in_progress')
        ORDER BY due_at NULLS LAST, created_at LIMIT 100
      ) t
      JOIN public.investors i ON i.id = t.investor_id
    ), '[]'::jsonb) ELSE '[]'::jsonb END,
    'stale', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', q.id, 'investor_id', q.id, 'title', q.full_name,
        'subtitle', CASE WHEN q.last_activity_at IS NULL
          THEN 'No recorded activity'
          ELSE 'Last activity ' || q.last_activity_at::date::text END,
        'status', q.lifecycle_status, 'created_at', q.created_at
      ) ORDER BY q.last_activity_at NULLS FIRST)
      FROM (
        SELECT i.*, max(a.occurred_at) AS last_activity_at
        FROM public.investors i
        LEFT JOIN public.investor_activity_logs a ON a.investor_id = i.id
        WHERE COALESCE(i.is_deleted, false) = false
          AND i.lifecycle_status NOT IN ('suspended', 'churned')
        GROUP BY i.id
        HAVING max(a.occurred_at) IS NULL
          OR max(a.occurred_at) < now() - interval '30 days'
        ORDER BY last_activity_at NULLS FIRST LIMIT 50
      ) q
    ), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_list_investor_managers()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', p.id,
    'name', COALESCE(
      NULLIF(trim(concat_ws(' ', p.first_name, p.last_name)), ''),
      p.email
    ),
    'email', p.email
  ) ORDER BY p.first_name, p.last_name, p.email), '[]'::jsonb)
  FROM public.profiles p
  WHERE COALESCE(p.is_deleted, false) = false
    AND EXISTS (
      SELECT 1 FROM public.user_roles ur
      JOIN public.roles r ON r.id = ur.role_id
      WHERE ur.user_id = p.id
        AND COALESCE(ur.is_deleted, false) = false
        AND r.slug NOT IN ('client', 'investor')
    )
    AND (
      public.has_permission('investors.assign', auth.uid())
      OR public.has_role('super_admin', auth.uid())
    );
$$;

CREATE OR REPLACE FUNCTION public.admin_assign_investor_owner(
  p_investor_id uuid,
  p_staff_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_previous uuid;
BEGIN
  IF NOT (
    public.has_permission('investors.assign', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN RAISE EXCEPTION 'not authorized'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = p_staff_id AND COALESCE(p.is_deleted, false) = false
      AND EXISTS (
        SELECT 1 FROM public.user_roles ur
        JOIN public.roles r ON r.id = ur.role_id
        WHERE ur.user_id = p.id
          AND COALESCE(ur.is_deleted, false) = false
          AND r.slug NOT IN ('client', 'investor')
      )
  ) THEN RAISE EXCEPTION 'staff_not_found'; END IF;
  SELECT assigned_staff_id INTO v_previous
  FROM public.investors
  WHERE id = p_investor_id AND COALESCE(is_deleted, false) = false
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'investor_not_found'; END IF;
  UPDATE public.investors
  SET assigned_staff_id = p_staff_id, updated_at = now(),
      updated_by = auth.uid()
  WHERE id = p_investor_id;
  INSERT INTO public.investor_activity_logs (
    investor_id, event_type, title, payload, actor_id, occurred_at
  ) VALUES (
    p_investor_id, 'owner_assigned', 'Relationship owner assigned',
    jsonb_build_object('from', v_previous, 'to', p_staff_id),
    auth.uid(), now()
  );
  RETURN p_staff_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_save_investor_task(
  p_investor_id uuid,
  p_title text,
  p_task_type text DEFAULT 'follow_up',
  p_priority text DEFAULT 'medium',
  p_due_at timestamptz DEFAULT NULL,
  p_assigned_to uuid DEFAULT NULL,
  p_task_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_title text := NULLIF(trim(COALESCE(p_title, '')), '');
  v_priority text := lower(trim(COALESCE(p_priority, 'medium')));
BEGIN
  IF NOT (
    public.has_permission('investors.tasks', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN RAISE EXCEPTION 'not authorized'; END IF;
  IF v_title IS NULL THEN RAISE EXCEPTION 'title_required'; END IF;
  IF v_priority NOT IN ('low', 'medium', 'high', 'urgent') THEN
    RAISE EXCEPTION 'invalid_priority';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.investors
    WHERE id = p_investor_id AND COALESCE(is_deleted, false) = false
  ) THEN RAISE EXCEPTION 'investor_not_found'; END IF;

  IF p_task_id IS NULL THEN
    INSERT INTO public.investor_tasks (
      investor_id, title, task_type, priority, status, due_at,
      assigned_to, created_by, metadata
    ) VALUES (
      p_investor_id, v_title,
      lower(trim(COALESCE(p_task_type, 'follow_up'))),
      v_priority, 'open', p_due_at, COALESCE(p_assigned_to, auth.uid()),
      auth.uid(), jsonb_build_object('source', 'investor_command_center')
    ) RETURNING id INTO v_id;
  ELSE
    UPDATE public.investor_tasks
    SET title = v_title,
        task_type = lower(trim(COALESCE(p_task_type, task_type))),
        priority = v_priority,
        due_at = p_due_at,
        assigned_to = COALESCE(p_assigned_to, assigned_to),
        updated_at = now()
    WHERE id = p_task_id AND investor_id = p_investor_id
    RETURNING id INTO v_id;
    IF v_id IS NULL THEN RAISE EXCEPTION 'task_not_found'; END IF;
  END IF;

  INSERT INTO public.investor_activity_logs (
    investor_id, event_type, title, payload, actor_id, occurred_at
  ) VALUES (
    p_investor_id, 'task_saved', 'Relationship task saved',
    jsonb_build_object('task_id', v_id, 'priority', v_priority),
    auth.uid(), now()
  );
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_investor_task_status(
  p_task_id uuid,
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_investor_id uuid;
  v_previous text;
  v_status text := lower(trim(COALESCE(p_status, '')));
BEGIN
  IF NOT (
    public.has_permission('investors.tasks', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN RAISE EXCEPTION 'not authorized'; END IF;
  IF v_status NOT IN ('open', 'in_progress', 'done', 'cancelled') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;
  SELECT investor_id, status INTO v_investor_id, v_previous
  FROM public.investor_tasks WHERE id = p_task_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'task_not_found'; END IF;
  IF v_previous IN ('done', 'cancelled') AND v_status <> v_previous THEN
    RAISE EXCEPTION 'terminal_task_status';
  END IF;
  UPDATE public.investor_tasks
  SET status = v_status, updated_at = now()
  WHERE id = p_task_id;
  INSERT INTO public.investor_activity_logs (
    investor_id, event_type, title, payload, actor_id, occurred_at
  ) VALUES (
    v_investor_id, 'task_status_changed', 'Relationship task updated',
    jsonb_build_object(
      'task_id', p_task_id, 'from', v_previous, 'to', v_status
    ),
    auth.uid(), now()
  );
  RETURN p_task_id;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_get_investor_work_queues() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_list_investor_managers() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_assign_investor_owner(uuid, uuid)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_save_investor_task(
  uuid, text, text, text, timestamptz, uuid, uuid
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_set_investor_task_status(uuid, text)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_get_investor_work_queues()
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_investor_managers()
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_assign_investor_owner(uuid, uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_save_investor_task(
  uuid, text, text, text, timestamptz, uuid, uuid
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_investor_task_status(uuid, text)
  TO authenticated;

DROP TRIGGER IF EXISTS trg_investor_tasks_command_event
  ON public.investor_tasks;
CREATE TRIGGER trg_investor_tasks_command_event
  AFTER INSERT OR UPDATE OR DELETE ON public.investor_tasks
  FOR EACH ROW EXECUTE FUNCTION public.emit_investor_command_event();
DROP TRIGGER IF EXISTS trg_investor_payment_intents_command_event
  ON public.investor_payment_intents;
CREATE TRIGGER trg_investor_payment_intents_command_event
  AFTER INSERT OR UPDATE OR DELETE ON public.investor_payment_intents
  FOR EACH ROW EXECUTE FUNCTION public.emit_investor_command_event();

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['investor_tasks', 'investor_payment_intents']
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND schemaname = 'public'
        AND tablename = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE %I', t);
    END IF;
  END LOOP;
END $$;
COMMIT;
