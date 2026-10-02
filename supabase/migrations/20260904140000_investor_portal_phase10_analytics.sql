-- Phase 10 — Investor analytics snapshot (trusted aggregates + date window)

CREATE OR REPLACE FUNCTION public.investor_analytics_snapshot(
  p_investor_id uuid,
  p_months int DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_ok boolean;
  v_since date;
  v_portfolio_value numeric := 0;
  v_cost_basis numeric := 0;
  v_distributions_paid numeric := 0;
  v_distributions_pending numeric := 0;
  v_latest jsonb;
  v_series jsonb := '[]'::jsonb;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM public.investors i
    WHERE i.id = p_investor_id
      AND COALESCE(i.is_deleted, false) = false
      AND (
        i.user_id = auth.uid()
        OR public.is_staff()
        OR public.has_role('super_admin', auth.uid())
      )
  ) INTO v_ok;

  IF NOT COALESCE(v_ok, false) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  IF p_months IS NOT NULL AND p_months > 0 THEN
    v_since := (CURRENT_DATE - make_interval(months => p_months))::date;
  END IF;

  SELECT
    COALESCE(SUM(h.current_value), 0),
    COALESCE(SUM(h.cost_basis), 0)
  INTO v_portfolio_value, v_cost_basis
  FROM public.portfolio_holdings h
  JOIN public.investor_portfolios ip ON ip.id = h.portfolio_id
  WHERE ip.investor_id = p_investor_id;

  SELECT
    COALESCE(SUM(d.amount) FILTER (
      WHERE d.status IN ('paid', 'completed', 'distributed')
    ), 0),
    COALESCE(SUM(d.amount) FILTER (
      WHERE d.status IN ('pending', 'scheduled', 'processing')
    ), 0)
  INTO v_distributions_paid, v_distributions_pending
  FROM public.investment_distributions d
  WHERE d.investor_id = p_investor_id
    AND (
      v_since IS NULL
      OR COALESCE(d.paid_at::date, d.scheduled_at::date, d.created_at::date)
         >= v_since
    );

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', p.id,
        'as_of_date', p.as_of_date,
        'nav', p.nav,
        'twr_pct', p.twr_pct,
        'irr_pct', p.irr_pct,
        'yield_pct', p.yield_pct,
        'currency', p.currency
      )
      ORDER BY p.as_of_date ASC
    ),
    '[]'::jsonb
  )
  INTO v_series
  FROM public.investment_performance p
  WHERE p.investor_id = p_investor_id
    AND (v_since IS NULL OR p.as_of_date >= v_since);

  SELECT to_jsonb(x)
  INTO v_latest
  FROM (
    SELECT id, as_of_date, nav, twr_pct, irr_pct, yield_pct, currency
    FROM public.investment_performance
    WHERE investor_id = p_investor_id
      AND (v_since IS NULL OR as_of_date >= v_since)
    ORDER BY as_of_date DESC
    LIMIT 1
  ) x;

  RETURN jsonb_build_object(
    'investor_id', p_investor_id,
    'months', p_months,
    'since', v_since,
    'portfolio_value', v_portfolio_value,
    'cost_basis', v_cost_basis,
    'unrealized_pnl', v_portfolio_value - v_cost_basis,
    'roi_pct', CASE
      WHEN v_cost_basis > 0
        THEN ROUND(((v_portfolio_value - v_cost_basis) / v_cost_basis) * 100, 2)
      ELSE 0
    END,
    'distributions_paid', v_distributions_paid,
    'distributions_pending', v_distributions_pending,
    'total_return_pct', CASE
      WHEN v_cost_basis > 0
        THEN ROUND(
          ((v_portfolio_value - v_cost_basis + v_distributions_paid) / v_cost_basis) * 100,
          2
        )
      ELSE 0
    END,
    'latest', COALESCE(v_latest, '{}'::jsonb),
    'series', v_series,
    'generated_at', now()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.investor_analytics_snapshot(uuid, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.investor_analytics_snapshot(uuid, int) TO authenticated;

COMMENT ON FUNCTION public.investor_analytics_snapshot(uuid, int) IS
  'Trusted investor analytics aggregates with optional month window (Phase 10).';
