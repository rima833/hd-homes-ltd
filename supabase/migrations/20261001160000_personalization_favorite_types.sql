-- Aggregate favorite item types for the admin personalization page.
-- Counts stay anonymous; no user or item identity is returned.

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
    'favorite_types', (
      SELECT coalesce(jsonb_agg(jsonb_build_object(
        'label', item_type, 'count', total
      ) ORDER BY total DESC), '[]'::jsonb)
      FROM (
        SELECT coalesce(nullif(item_type, ''), 'unknown') item_type,
          count(*) total
        FROM public.favorite_items
        GROUP BY 1
        ORDER BY total DESC
        LIMIT 8
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
