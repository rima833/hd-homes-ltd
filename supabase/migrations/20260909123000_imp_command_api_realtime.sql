-- Paginated command API and scoped investor event stream.
BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_command_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  investor_id uuid REFERENCES public.investors(id) ON DELETE CASCADE,
  aggregate_type text NOT NULL,
  aggregate_id uuid,
  event_type text NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  actor_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  occurred_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_investor_command_events_investor
  ON public.investor_command_events(investor_id, id DESC);
CREATE INDEX IF NOT EXISTS idx_investor_command_events_aggregate
  ON public.investor_command_events(aggregate_type, aggregate_id, id DESC);

ALTER TABLE public.investor_command_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY investor_command_events_owner_select
  ON public.investor_command_events FOR SELECT TO authenticated
  USING (investor_id = public.investor_id_for_user(auth.uid()));
CREATE POLICY investor_command_events_staff_select
  ON public.investor_command_events FOR SELECT TO authenticated
  USING (
    public.has_permission('investors.read', auth.uid())
    OR public.has_permission('investors.audit', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
GRANT SELECT ON public.investor_command_events TO authenticated;

CREATE OR REPLACE FUNCTION public.emit_investor_command_event()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row jsonb := CASE WHEN TG_OP = 'DELETE' THEN to_jsonb(OLD)
    ELSE to_jsonb(NEW) END;
  v_id uuid;
  v_investor_id uuid;
BEGIN
  v_id := NULLIF(v_row->>'id', '')::uuid;
  v_investor_id := NULLIF(v_row->>'investor_id', '')::uuid;
  IF TG_TABLE_NAME = 'investors' THEN
    v_investor_id := v_id;
  ELSIF TG_TABLE_NAME = 'portfolio_holdings' THEN
    SELECT p.investor_id INTO v_investor_id
    FROM public.investor_portfolios p
    WHERE p.id = NULLIF(v_row->>'portfolio_id', '')::uuid;
  END IF;
  INSERT INTO public.investor_command_events (
    investor_id, aggregate_type, aggregate_id, event_type,
    payload, actor_id, occurred_at
  ) VALUES (
    v_investor_id, TG_TABLE_NAME, v_id, lower(TG_OP),
    jsonb_build_object(
      'status', v_row->>'status',
      'updated_at', COALESCE(v_row->>'updated_at', v_row->>'created_at')
    ),
    auth.uid(), now()
  );
  RETURN COALESCE(NEW, OLD);
END;
$$;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'investors', 'investment_commitments', 'investment_distributions',
    'investor_wallets', 'investor_notifications', 'investor_kyc_documents',
    'investment_transactions', 'portfolio_holdings'
  ] LOOP
    EXECUTE format(
      'DROP TRIGGER IF EXISTS trg_%I_command_event ON public.%I', t, t
    );
    EXECUTE format(
      'CREATE TRIGGER trg_%I_command_event
       AFTER INSERT OR UPDATE OR DELETE ON public.%I
       FOR EACH ROW EXECUTE FUNCTION public.emit_investor_command_event()',
      t, t
    );
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.admin_list_investors(
  p_search text DEFAULT NULL,
  p_investor_type text DEFAULT NULL,
  p_lifecycle_status text DEFAULT NULL,
  p_kyc_status text DEFAULT NULL,
  p_assigned_staff_id uuid DEFAULT NULL,
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
    public.has_permission('investors.read', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN RAISE EXCEPTION 'not authorized'; END IF;

  SELECT count(*) INTO v_total
  FROM public.investors i
  WHERE COALESCE(i.is_deleted, false) = false
    AND (
      v_search IS NULL OR i.full_name ILIKE '%' || v_search || '%'
      OR i.email ILIKE '%' || v_search || '%'
      OR i.phone ILIKE '%' || v_search || '%'
      OR i.investor_code ILIKE '%' || v_search || '%'
      OR i.company ILIKE '%' || v_search || '%'
    )
    AND (p_investor_type IS NULL OR i.investor_type = p_investor_type)
    AND (p_lifecycle_status IS NULL OR i.lifecycle_status = p_lifecycle_status)
    AND (p_kyc_status IS NULL OR i.kyc_status = p_kyc_status)
    AND (
      p_assigned_staff_id IS NULL
      OR i.assigned_staff_id = p_assigned_staff_id
    );

  SELECT COALESCE(jsonb_agg(row_data ORDER BY sort_name, sort_id), '[]'::jsonb)
    INTO v_items
  FROM (
    SELECT
      to_jsonb(i) || jsonb_build_object(
        'tags', COALESCE((
          SELECT jsonb_agg(t.name ORDER BY t.name)
          FROM public.investor_tag_assignments a
          JOIN public.investor_tags t ON t.id = a.tag_id
          WHERE a.investor_id = i.id
        ), '[]'::jsonb),
        'open_alerts', (
          SELECT count(*) FROM public.investor_alerts a
          WHERE a.investor_id = i.id AND a.status = 'open'
        ),
        'last_activity_at', (
          SELECT max(a.occurred_at) FROM public.investor_activity_logs a
          WHERE a.investor_id = i.id
        )
      ) AS row_data,
      lower(COALESCE(i.full_name, i.investor_code, '')) AS sort_name,
      i.id AS sort_id
    FROM public.investors i
    WHERE COALESCE(i.is_deleted, false) = false
      AND (
        v_search IS NULL OR i.full_name ILIKE '%' || v_search || '%'
        OR i.email ILIKE '%' || v_search || '%'
        OR i.phone ILIKE '%' || v_search || '%'
        OR i.investor_code ILIKE '%' || v_search || '%'
        OR i.company ILIKE '%' || v_search || '%'
      )
      AND (p_investor_type IS NULL OR i.investor_type = p_investor_type)
      AND (
        p_lifecycle_status IS NULL
        OR i.lifecycle_status = p_lifecycle_status
      )
      AND (p_kyc_status IS NULL OR i.kyc_status = p_kyc_status)
      AND (
        p_assigned_staff_id IS NULL
        OR i.assigned_staff_id = p_assigned_staff_id
      )
    ORDER BY sort_name, sort_id
    LIMIT v_limit OFFSET v_offset
  ) page;

  RETURN jsonb_build_object(
    'items', v_items, 'total', v_total, 'limit', v_limit,
    'offset', v_offset, 'has_more', v_offset + v_limit < v_total
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_get_investor_360(p_investor_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_investor jsonb;
BEGIN
  IF NOT (
    public.has_permission('investors.read', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN RAISE EXCEPTION 'not authorized'; END IF;
  SELECT to_jsonb(i) INTO v_investor FROM public.investors i
  WHERE i.id = p_investor_id AND COALESCE(i.is_deleted, false) = false;
  IF v_investor IS NULL THEN RAISE EXCEPTION 'investor_not_found'; END IF;

  RETURN v_investor || jsonb_build_object(
    'portfolios', COALESCE((
      SELECT jsonb_agg(to_jsonb(p) ORDER BY p.created_at)
      FROM public.investor_portfolios p
      WHERE p.investor_id = p_investor_id
    ), '[]'::jsonb),
    'holdings', COALESCE((
      SELECT jsonb_agg(to_jsonb(h) ORDER BY h.created_at DESC)
      FROM public.portfolio_holdings h
      JOIN public.investor_portfolios p ON p.id = h.portfolio_id
      WHERE p.investor_id = p_investor_id
    ), '[]'::jsonb),
    'commitments', COALESCE((
      SELECT jsonb_agg(to_jsonb(c) ORDER BY c.committed_at DESC)
      FROM public.investment_commitments c
      WHERE c.investor_id = p_investor_id
    ), '[]'::jsonb),
    'distributions', COALESCE((
      SELECT jsonb_agg(to_jsonb(d) ORDER BY d.created_at DESC)
      FROM public.investment_distributions d
      WHERE d.investor_id = p_investor_id
    ), '[]'::jsonb),
    'wallets', COALESCE((
      SELECT jsonb_agg(to_jsonb(w) ORDER BY w.created_at)
      FROM public.investor_wallets w
      WHERE w.investor_id = p_investor_id
    ), '[]'::jsonb),
    'ledger', COALESCE((
      SELECT jsonb_agg(to_jsonb(t) ORDER BY t.posted_at DESC)
      FROM (
        SELECT * FROM public.investment_transactions
        WHERE investor_id = p_investor_id
        ORDER BY posted_at DESC LIMIT 200
      ) t
    ), '[]'::jsonb),
    'kyc_documents', COALESCE((
      SELECT jsonb_agg(to_jsonb(k) ORDER BY k.created_at DESC)
      FROM public.investor_kyc_documents k
      WHERE k.investor_id = p_investor_id
    ), '[]'::jsonb),
    'documents', COALESCE((
      SELECT jsonb_agg(to_jsonb(d) ORDER BY d.created_at DESC)
      FROM public.investor_documents d
      WHERE d.investor_id = p_investor_id
    ), '[]'::jsonb),
    'activities', COALESCE((
      SELECT jsonb_agg(to_jsonb(a) ORDER BY a.occurred_at DESC)
      FROM (
        SELECT * FROM public.investor_activity_logs
        WHERE investor_id = p_investor_id
        ORDER BY occurred_at DESC LIMIT 200
      ) a
    ), '[]'::jsonb)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_investors(
  text, text, text, text, uuid, integer, integer
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_get_investor_360(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_list_investors(
  text, text, text, text, uuid, integer, integer
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_investor_360(uuid) TO authenticated;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public'
      AND tablename = 'investor_command_events'
  ) THEN
    ALTER PUBLICATION supabase_realtime
      ADD TABLE public.investor_command_events;
  END IF;
END $$;
COMMIT;
