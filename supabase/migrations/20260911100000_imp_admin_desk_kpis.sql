-- Server-side Investor Operations desk KPIs (full book, not client limit-100).
CREATE OR REPLACE FUNCTION public.admin_get_investor_desk_kpis()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_can_read boolean;
BEGIN
  v_can_read := public.has_permission('investors.read', auth.uid())
    OR public.has_role('super_admin', auth.uid());
  IF NOT v_can_read THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  RETURN jsonb_build_object(
    'total_investors', (
      SELECT count(*)::int
      FROM public.investors i
      WHERE coalesce(i.is_deleted, false) = false
        AND coalesce(i.metadata->>'demo', '') <> 'true'
    ),
    'active_investors', (
      SELECT count(*)::int
      FROM public.investors i
      WHERE coalesce(i.is_deleted, false) = false
        AND coalesce(i.metadata->>'demo', '') <> 'true'
        AND i.lifecycle_status IN ('active', 'vip', 'onboarding')
    ),
    'total_aum', (
      SELECT coalesce(sum(i.aum), 0)::numeric
      FROM public.investors i
      WHERE coalesce(i.is_deleted, false) = false
        AND coalesce(i.metadata->>'demo', '') <> 'true'
    ),
    'capital_raised', (
      SELECT coalesce(sum(o.amount_raised), 0)::numeric
      FROM public.investment_opportunities o
      WHERE coalesce(o.metadata->>'demo', '') <> 'true'
    ),
    'upcoming_distributions', (
      SELECT coalesce(sum(d.amount), 0)::numeric
      FROM public.investment_distributions d
      WHERE d.status IN ('scheduled', 'processing')
        AND coalesce(d.metadata->>'demo', '') <> 'true'
    ),
    'pending_payments', (
      SELECT count(*)::int
      FROM public.investor_payment_intents p
      WHERE coalesce(p.is_deleted, false) = false
        AND p.status IN ('pending', 'awaiting_confirmation')
    ),
    'kyc_pending', (
      SELECT count(*)::int
      FROM public.investors i
      WHERE coalesce(i.is_deleted, false) = false
        AND coalesce(i.metadata->>'demo', '') <> 'true'
        AND i.kyc_status IN (
          'pending',
          'in_progress',
          'awaiting_documents',
          'under_review',
          'needs_resubmission'
        )
    ),
    'overdue_actions', (
      SELECT (
        (
          SELECT count(*)::int
          FROM public.investor_tasks t
          WHERE t.status IN ('open', 'pending', 'in_progress')
            AND t.due_at IS NOT NULL
            AND t.due_at < now()
        )
        +
        (
          SELECT count(*)::int
          FROM public.investor_payment_intents p
          WHERE coalesce(p.is_deleted, false) = false
            AND p.status IN ('pending', 'awaiting_confirmation')
            AND p.created_at < now() - interval '7 days'
        )
      )
    ),
    'open_opportunities', (
      SELECT count(*)::int
      FROM public.investment_opportunities o
      WHERE o.status = 'open'
        AND coalesce(o.metadata->>'demo', '') <> 'true'
    ),
    'generated_at', now()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_get_investor_desk_kpis() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_get_investor_desk_kpis() FROM anon;
GRANT EXECUTE ON FUNCTION public.admin_get_investor_desk_kpis() TO authenticated;
