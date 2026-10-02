-- Live Admin Analytics
-- Replaces BI/search/personalization fixtures with permission-scoped,
-- server-produced operational aggregates.

BEGIN;

-- ---------------------------------------------------------------------------
-- Remove deterministic BI and enterprise-search fixtures only.
-- ---------------------------------------------------------------------------

DELETE FROM public.analytics_activity_logs WHERE id::text LIKE 'e160%';
DELETE FROM public.analytics_notifications WHERE id::text LIKE 'e160%';
DELETE FROM public.analytics_ai_insights WHERE id::text LIKE 'e160%';
DELETE FROM public.analytics_search_history WHERE id::text LIKE 'e160%';
DELETE FROM public.analytics_scheduled_reports WHERE id::text LIKE 'e160%';
DELETE FROM public.analytics_metadata WHERE id::text LIKE 'e160%';
DELETE FROM public.analytics_lineage WHERE id::text LIKE 'e160%';
DELETE FROM public.analytics_data_catalog WHERE id::text LIKE 'e160%';
DELETE FROM public.analytics_quality_issues WHERE id::text LIKE 'e160%';
DELETE FROM public.analytics_data_quality_rules WHERE id::text LIKE 'e160%';
DELETE FROM public.analytics_forecasts WHERE id::text LIKE 'e160%';
DELETE FROM public.analytics_models WHERE id::text LIKE 'e160%';
DELETE FROM public.analytics_scorecards WHERE id::text LIKE 'e160%';
DELETE FROM public.analytics_saved_views WHERE id::text LIKE 'e160%';
DELETE FROM public.analytics_filters WHERE id::text LIKE 'e160%';
DELETE FROM public.analytics_visualizations WHERE id::text LIKE 'e160%';
DELETE FROM public.analytics_dashboard_widgets WHERE id::text LIKE 'e160%';
DELETE FROM public.analytics_dashboards WHERE id::text LIKE 'e160%';
DELETE FROM public.analytics_reports WHERE id::text LIKE 'e160%';
DELETE FROM public.analytics_report_templates WHERE id::text LIKE 'e160%';
DELETE FROM public.analytics_kpi_targets WHERE id::text LIKE 'e160%';
DELETE FROM public.analytics_kpis WHERE id::text LIKE 'e160%';
DELETE FROM public.analytics_pipeline_logs WHERE id::text LIKE 'e160%';
DELETE FROM public.analytics_etl_jobs WHERE id::text LIKE 'e160%';
DELETE FROM public.analytics_fact_tables WHERE id::text LIKE 'e160%';
DELETE FROM public.analytics_dimension_tables WHERE id::text LIKE 'e160%';
DELETE FROM public.analytics_datasets WHERE id::text LIKE 'e160%';
DELETE FROM public.analytics_data_sources WHERE id::text LIKE 'e160%';

DELETE FROM public.search_index
WHERE entity_id IN ('prop-lekki-pearl', 'cmd-create-property');

-- ---------------------------------------------------------------------------
-- Typed, privacy-aware search telemetry.
-- ---------------------------------------------------------------------------

ALTER TABLE public.search_analytics
  ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS normalized_query text,
  ADD COLUMN IF NOT EXISTS mode text NOT NULL DEFAULT 'universal',
  ADD COLUMN IF NOT EXISTS result_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS zero_results boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS latency_ms integer NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_search_analytics_created_at
  ON public.search_analytics (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_search_analytics_query_created
  ON public.search_analytics (normalized_query, created_at DESC)
  WHERE normalized_query IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_search_analytics_mode_created
  ON public.search_analytics (mode, created_at DESC);

DROP POLICY IF EXISTS search_analytics_insert ON public.search_analytics;
DROP POLICY IF EXISTS search_analytics_staff ON public.search_analytics;
CREATE POLICY search_analytics_staff ON public.search_analytics
  FOR SELECT TO authenticated
  USING (
    public.has_permission('analytics.read', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

REVOKE ALL ON public.search_analytics FROM anon, authenticated;
GRANT SELECT ON public.search_analytics TO authenticated;

CREATE OR REPLACE FUNCTION public.redact_search_query(p_query text)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT NULLIF(
    left(
      trim(
        regexp_replace(
          regexp_replace(
            regexp_replace(
              lower(coalesce(p_query, '')),
              '[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}',
              '[email]',
              'g'
            ),
            '(\+?[0-9][0-9 ()-]{7,}[0-9])',
            '[phone]',
            'g'
          ),
          '[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}',
          '[id]',
          'g'
        )
      ),
      120
    ),
    ''
  );
$$;

CREATE OR REPLACE FUNCTION public.record_enterprise_search_event(
  p_query text,
  p_mode text DEFAULT 'universal',
  p_result_count integer DEFAULT 0,
  p_latency_ms integer DEFAULT 0
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_id uuid;
  v_query text;
  v_mode text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  v_query := public.redact_search_query(p_query);
  IF v_query IS NULL THEN
    RAISE EXCEPTION 'Search query is required';
  END IF;
  v_mode := CASE
    WHEN p_mode IN ('universal', 'commands', 'properties', 'people', 'documents')
      THEN p_mode
    ELSE 'universal'
  END;

  INSERT INTO public.search_analytics (
    metric_key,
    metric_value,
    dimensions,
    user_id,
    normalized_query,
    mode,
    result_count,
    zero_results,
    latency_ms
  ) VALUES (
    CASE WHEN greatest(coalesce(p_result_count, 0), 0) = 0
      THEN 'zero_result'
      ELSE 'search'
    END,
    1,
    '{}'::jsonb,
    auth.uid(),
    v_query,
    v_mode,
    greatest(coalesce(p_result_count, 0), 0),
    greatest(coalesce(p_result_count, 0), 0) = 0,
    least(greatest(coalesce(p_latency_ms, 0), 0), 60000)
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.record_enterprise_search_event(text, text, integer, integer)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_enterprise_search_event(text, text, integer, integer)
  TO authenticated;

-- ---------------------------------------------------------------------------
-- Anonymous aggregate personalization counters.
-- ---------------------------------------------------------------------------

ALTER TABLE public.personalization_analytics_daily
  ADD COLUMN IF NOT EXISTS dimension_key text NOT NULL DEFAULT 'all';

ALTER TABLE public.personalization_analytics_daily
  DROP CONSTRAINT IF EXISTS personalization_analytics_daily_metric_date_metric_key_key;
CREATE UNIQUE INDEX IF NOT EXISTS uq_personalization_analytics_daily_dimension
  ON public.personalization_analytics_daily
    (metric_date, metric_key, dimension_key);
CREATE INDEX IF NOT EXISTS idx_personalization_analytics_daily_date
  ON public.personalization_analytics_daily (metric_date DESC, metric_key);

DROP POLICY IF EXISTS personalization_analytics_staff
  ON public.personalization_analytics_daily;
CREATE POLICY personalization_analytics_staff
  ON public.personalization_analytics_daily
  FOR SELECT TO authenticated
  USING (
    public.has_permission('analytics.read', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

REVOKE ALL ON public.personalization_analytics_daily FROM anon, authenticated;
GRANT SELECT ON public.personalization_analytics_daily TO authenticated;

CREATE OR REPLACE FUNCTION public.record_personalization_event(
  p_metric_key text,
  p_dimension_key text DEFAULT 'all',
  p_metric_value numeric DEFAULT 1
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_key text;
  v_dimension text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  v_key := lower(trim(coalesce(p_metric_key, '')));
  IF v_key NOT IN (
    'theme_changed',
    'accessibility_updated',
    'layout_updated',
    'workspace_switched',
    'saved_search_created',
    'favorite_added'
  ) THEN
    RAISE EXCEPTION 'Unsupported personalization metric';
  END IF;
  v_dimension := left(
    regexp_replace(lower(trim(coalesce(p_dimension_key, 'all'))), '[^a-z0-9_-]+', '_', 'g'),
    80
  );
  IF v_dimension = '' THEN v_dimension := 'all'; END IF;

  INSERT INTO public.personalization_analytics_daily (
    metric_date,
    metric_key,
    dimension_key,
    metric_value,
    dimensions
  ) VALUES (
    current_date,
    v_key,
    v_dimension,
    greatest(coalesce(p_metric_value, 1), 0),
    jsonb_build_object('dimension', v_dimension)
  )
  ON CONFLICT (metric_date, metric_key, dimension_key)
  DO UPDATE SET
    metric_value =
      public.personalization_analytics_daily.metric_value + excluded.metric_value,
    dimensions = excluded.dimensions;
END;
$$;

REVOKE ALL ON FUNCTION public.record_personalization_event(text, text, numeric)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_personalization_event(text, text, numeric)
  TO authenticated;

-- ---------------------------------------------------------------------------
-- Permission-scoped aggregate RPCs.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_admin_operational_analytics(
  p_days integer DEFAULT 30
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, auth
AS $$
DECLARE
  v_days integer := least(greatest(coalesce(p_days, 30), 7), 365);
  v_since timestamptz;
  v_month timestamptz := date_trunc('month', now());
  v_result jsonb;
BEGIN
  IF NOT (
    public.has_permission('analytics.read', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN
    RAISE EXCEPTION 'Analytics permission required';
  END IF;
  v_since := date_trunc('day', now()) - make_interval(days => v_days - 1);

  SELECT jsonb_build_object(
    'loaded_at', now(),
    'period_days', v_days,
    'kpis', jsonb_build_array(
      jsonb_build_object('key', 'crm_leads', 'label', 'CRM Leads',
        'value', (SELECT count(*) FROM public.crm_leads), 'unit', 'count'),
      jsonb_build_object('key', 'qualified_leads', 'label', 'Qualified Leads',
        'value', (SELECT count(*) FROM public.crm_leads
          WHERE lower(coalesce(status, '')) LIKE '%qualif%'), 'unit', 'count'),
      jsonb_build_object('key', 'clients', 'label', 'Clients',
        'value', (SELECT count(*) FROM public.clients
          WHERE coalesce(is_deleted, false) = false), 'unit', 'count'),
      jsonb_build_object('key', 'revenue_mtd', 'label', 'Revenue MTD',
        'value', (SELECT coalesce(sum(amount), 0) FROM public.payments
          WHERE coalesce(is_deleted, false) = false
            AND paid_at >= v_month
            AND lower(coalesce(status, '')) IN ('paid','completed','successful','success')),
        'unit', 'currency'),
      jsonb_build_object('key', 'applications', 'label', 'Applications',
        'value', (SELECT count(*) FROM public.client_property_applications
          WHERE coalesce(is_deleted, false) = false), 'unit', 'count'),
      jsonb_build_object('key', 'inspections', 'label', 'Inspections',
        'value', (SELECT count(*) FROM public.property_inspections), 'unit', 'count'),
      jsonb_build_object('key', 'project_progress', 'label', 'Project Progress',
        'value', (SELECT coalesce(avg(progress_pct), 0) FROM public.construction_projects),
        'unit', 'percent'),
      jsonb_build_object('key', 'open_tickets', 'label', 'Open Tickets',
        'value', (SELECT count(*) FROM public.tickets
          WHERE coalesce(is_deleted, false) = false
            AND lower(coalesce(status, '')) NOT IN ('resolved','closed','cancelled')),
        'unit', 'count')
    ),
    'daily_series', (
      SELECT coalesce(jsonb_agg(jsonb_build_object(
        'date', d.day::date,
        'leads', (SELECT count(*) FROM public.crm_leads l
          WHERE coalesce(l.captured_at, l.created_at) >= d.day
            AND coalesce(l.captured_at, l.created_at) < d.day + interval '1 day'),
        'revenue', (SELECT coalesce(sum(p.amount), 0) FROM public.payments p
          WHERE coalesce(p.is_deleted, false) = false
            AND p.paid_at >= d.day AND p.paid_at < d.day + interval '1 day'
            AND lower(coalesce(p.status, '')) IN ('paid','completed','successful','success')),
        'applications', (SELECT count(*) FROM public.client_property_applications a
          WHERE coalesce(a.is_deleted, false) = false
            AND a.created_at >= d.day AND a.created_at < d.day + interval '1 day')
      ) ORDER BY d.day), '[]'::jsonb)
      FROM generate_series(v_since, date_trunc('day', now()), interval '1 day') d(day)
    ),
    'lead_statuses', (
      SELECT coalesce(jsonb_agg(jsonb_build_object(
        'label', status_label, 'value', total
      ) ORDER BY total DESC), '[]'::jsonb)
      FROM (
        SELECT coalesce(nullif(initcap(status), ''), 'Unknown') status_label,
          count(*) total
        FROM public.crm_leads
        GROUP BY 1
      ) s
    ),
    'modules', jsonb_build_array(
      jsonb_build_object('key', 'sales', 'label', 'Sales',
        'value', (SELECT count(*) FROM public.crm_leads),
        'detail', 'Live CRM leads'),
      jsonb_build_object('key', 'finance', 'label', 'Finance',
        'value', (SELECT count(*) FROM public.payments
          WHERE coalesce(is_deleted, false) = false),
        'detail', 'Payment records'),
      jsonb_build_object('key', 'construction', 'label', 'Construction',
        'value', (SELECT count(*) FROM public.construction_projects),
        'detail', 'Active project records'),
      jsonb_build_object('key', 'support', 'label', 'Support',
        'value', (SELECT count(*) FROM public.tickets
          WHERE coalesce(is_deleted, false) = false),
        'detail', 'Support tickets'),
      jsonb_build_object('key', 'properties', 'label', 'Properties',
        'value', (SELECT count(*) FROM public.properties
          WHERE coalesce(is_deleted, false) = false),
        'detail', 'Property inventory'),
      jsonb_build_object('key', 'investors', 'label', 'Investors',
        'value', (SELECT count(*) FROM public.investors
          WHERE coalesce(is_deleted, false) = false),
        'detail', 'Investor records')
    ),
    'recent_activity', (
      SELECT coalesce(jsonb_agg(jsonb_build_object(
        'type', e.event_type,
        'label', e.label,
        'occurred_at', e.occurred_at
      ) ORDER BY e.occurred_at DESC), '[]'::jsonb)
      FROM (
        (SELECT 'lead' event_type, 'Lead captured' label,
          coalesce(captured_at, created_at) occurred_at
          FROM public.crm_leads ORDER BY occurred_at DESC LIMIT 8)
        UNION ALL
        (SELECT 'payment', 'Payment recorded', coalesce(paid_at, created_at)
          FROM public.payments
          WHERE coalesce(is_deleted, false) = false
          ORDER BY coalesce(paid_at, created_at) DESC LIMIT 8)
        UNION ALL
        (SELECT 'application', 'Application submitted', created_at
          FROM public.client_property_applications
          WHERE coalesce(is_deleted, false) = false
          ORDER BY created_at DESC LIMIT 8)
        UNION ALL
        (SELECT 'inspection', 'Inspection booked', created_at
          FROM public.property_inspections ORDER BY created_at DESC LIMIT 8)
      ) e
      WHERE e.occurred_at IS NOT NULL
      ORDER BY e.occurred_at DESC
      LIMIT 12
    )
  ) INTO v_result;
  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_admin_search_analytics(
  p_days integer DEFAULT 30
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, auth
AS $$
DECLARE
  v_days integer := least(greatest(coalesce(p_days, 30), 7), 365);
  v_since timestamptz;
BEGIN
  IF NOT (
    public.has_permission('analytics.read', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN
    RAISE EXCEPTION 'Analytics permission required';
  END IF;
  v_since := date_trunc('day', now()) - make_interval(days => v_days - 1);

  RETURN jsonb_build_object(
    'loaded_at', now(),
    'period_days', v_days,
    'total_searches', (SELECT count(*) FROM public.search_analytics
      WHERE created_at >= v_since),
    'unique_searchers', (SELECT count(DISTINCT user_id) FROM public.search_analytics
      WHERE created_at >= v_since AND user_id IS NOT NULL),
    'zero_result_count', (SELECT count(*) FROM public.search_analytics
      WHERE created_at >= v_since AND zero_results),
    'avg_latency_ms', (SELECT coalesce(avg(latency_ms), 0) FROM public.search_analytics
      WHERE created_at >= v_since),
    'top_terms', (
      SELECT coalesce(jsonb_agg(jsonb_build_object(
        'label', normalized_query, 'count', total
      ) ORDER BY total DESC), '[]'::jsonb)
      FROM (
        SELECT normalized_query, count(*) total
        FROM public.search_analytics
        WHERE created_at >= v_since AND normalized_query IS NOT NULL
        GROUP BY normalized_query
        ORDER BY total DESC, normalized_query
        LIMIT 10
      ) q
    ),
    'zero_result_terms', (
      SELECT coalesce(jsonb_agg(jsonb_build_object(
        'label', normalized_query, 'count', total
      ) ORDER BY total DESC), '[]'::jsonb)
      FROM (
        SELECT normalized_query, count(*) total
        FROM public.search_analytics
        WHERE created_at >= v_since AND zero_results
          AND normalized_query IS NOT NULL
        GROUP BY normalized_query
        ORDER BY total DESC, normalized_query
        LIMIT 10
      ) q
    ),
    'popular_modes', (
      SELECT coalesce(jsonb_agg(jsonb_build_object(
        'label', mode, 'count', total
      ) ORDER BY total DESC), '[]'::jsonb)
      FROM (
        SELECT mode, count(*) total
        FROM public.search_analytics
        WHERE created_at >= v_since
        GROUP BY mode
        ORDER BY total DESC
      ) q
    ),
    'daily_series', (
      SELECT coalesce(jsonb_agg(jsonb_build_object(
        'date', d.day::date,
        'searches', (SELECT count(*) FROM public.search_analytics s
          WHERE s.created_at >= d.day AND s.created_at < d.day + interval '1 day'),
        'zero_results', (SELECT count(*) FROM public.search_analytics s
          WHERE s.created_at >= d.day AND s.created_at < d.day + interval '1 day'
            AND s.zero_results)
      ) ORDER BY d.day), '[]'::jsonb)
      FROM generate_series(v_since, date_trunc('day', now()), interval '1 day') d(day)
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_admin_personalization_analytics(
  p_days integer DEFAULT 30
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, auth
AS $$
DECLARE
  v_days integer := least(greatest(coalesce(p_days, 30), 7), 365);
  v_since date := current_date - (v_days - 1);
  v_users numeric := (SELECT count(*) FROM public.user_preferences);
BEGIN
  IF NOT (
    public.has_permission('analytics.read', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN
    RAISE EXCEPTION 'Analytics permission required';
  END IF;

  RETURN jsonb_build_object(
    'loaded_at', now(),
    'period_days', v_days,
    'preference_profiles', v_users,
    'accessibility_adoption_pct', CASE WHEN v_users <= 0 THEN 0 ELSE
      round(100 * (
        SELECT count(*) FROM public.accessibility_settings
        WHERE coalesce(high_contrast, false)
          OR coalesce(reduced_motion, false)
          OR coalesce(larger_fonts, false)
          OR coalesce(keyboard_navigation, false)
          OR coalesce(screen_reader_optimized, false)
          OR coalesce(focus_highlighting, false)
          OR coalesce(font_scale, 1) > 1
      ) / v_users, 1) END,
    'saved_searches', (SELECT count(*) FROM public.saved_searches),
    'favorites', (SELECT count(*) FROM public.favorite_items),
    'dashboard_layouts', (SELECT count(*) FROM public.dashboard_layouts),
    'workspace_switches_today', (
      SELECT coalesce(sum(metric_value), 0)
      FROM public.personalization_analytics_daily
      WHERE metric_date = current_date AND metric_key = 'workspace_switched'
    ),
    'theme_distribution', (
      SELECT coalesce(jsonb_agg(jsonb_build_object(
        'label', theme_label, 'count', total
      ) ORDER BY total DESC), '[]'::jsonb)
      FROM (
        SELECT coalesce(nullif(initcap(theme), ''), 'System') theme_label,
          count(*) total
        FROM public.user_preferences
        GROUP BY 1
        ORDER BY total DESC
      ) q
    ),
    'events_by_type', (
      SELECT coalesce(jsonb_agg(jsonb_build_object(
        'label', metric_key, 'count', total
      ) ORDER BY total DESC), '[]'::jsonb)
      FROM (
        SELECT metric_key, sum(metric_value) total
        FROM public.personalization_analytics_daily
        WHERE metric_date >= v_since
        GROUP BY metric_key
        ORDER BY total DESC
      ) q
    ),
    'daily_series', (
      SELECT coalesce(jsonb_agg(jsonb_build_object(
        'date', d.day,
        'events', (
          SELECT coalesce(sum(metric_value), 0)
          FROM public.personalization_analytics_daily p
          WHERE p.metric_date = d.day
        )
      ) ORDER BY d.day), '[]'::jsonb)
      FROM generate_series(v_since, current_date, interval '1 day') d(day)
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_admin_operational_analytics(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_admin_search_analytics(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_admin_personalization_analytics(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_admin_operational_analytics(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_admin_search_analytics(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_admin_personalization_analytics(integer) TO authenticated;

-- ---------------------------------------------------------------------------
-- Realtime and bounded retention.
-- ---------------------------------------------------------------------------

DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.search_analytics;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.personalization_analytics_daily;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
END $$;

ALTER TABLE public.search_analytics REPLICA IDENTITY FULL;
ALTER TABLE public.personalization_analytics_daily REPLICA IDENTITY FULL;

CREATE OR REPLACE FUNCTION public.prune_admin_analytics_telemetry(
  p_search_days integer DEFAULT 180,
  p_personalization_days integer DEFAULT 400
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_search integer;
  v_personalization integer;
BEGIN
  IF NOT (
    public.has_permission('analytics.admin', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN
    RAISE EXCEPTION 'Analytics admin permission required';
  END IF;
  DELETE FROM public.search_analytics
  WHERE created_at < now() - make_interval(days => greatest(p_search_days, 30));
  GET DIAGNOSTICS v_search = ROW_COUNT;
  DELETE FROM public.personalization_analytics_daily
  WHERE metric_date < current_date - greatest(p_personalization_days, 90);
  GET DIAGNOSTICS v_personalization = ROW_COUNT;
  RETURN jsonb_build_object(
    'search_deleted', v_search,
    'personalization_deleted', v_personalization
  );
END;
$$;

REVOKE ALL ON FUNCTION public.prune_admin_analytics_telemetry(integer, integer)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.prune_admin_analytics_telemetry(integer, integer)
  TO authenticated;

COMMIT;
