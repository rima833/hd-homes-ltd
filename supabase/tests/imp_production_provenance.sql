-- Read-only production provenance and integrity report.
-- This test deliberately does not delete untagged or ambiguous records.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.investors
    WHERE COALESCE(metadata->>'demo', 'false') = 'true'
  ) THEN
    RAISE EXCEPTION 'demo_marked_investors_present';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.investment_opportunities
    WHERE COALESCE(metadata->>'demo', 'false') = 'true'
  ) THEN
    RAISE EXCEPTION 'demo_marked_opportunities_present';
  END IF;
  IF EXISTS (
    SELECT 1
    FROM public.investment_distributions d
    LEFT JOIN public.investors i ON i.id = d.investor_id
    WHERE i.id IS NULL OR COALESCE(i.is_deleted, false) = true
  ) THEN
    RAISE EXCEPTION 'orphan_or_archived_investor_distribution_present';
  END IF;
  IF EXISTS (
    SELECT 1
    FROM public.portfolio_holdings h
    LEFT JOIN public.investor_portfolios p ON p.id = h.portfolio_id
    WHERE p.id IS NULL
  ) THEN
    RAISE EXCEPTION 'orphan_portfolio_holding_present';
  END IF;
END $$;

SELECT jsonb_build_object(
  'investors', (SELECT count(*) FROM public.investors),
  'unassigned_investors', (
    SELECT count(*) FROM public.investors
    WHERE assigned_staff_id IS NULL AND COALESCE(is_deleted, false) = false
  ),
  'opportunities', (
    SELECT count(*) FROM public.investment_opportunities
  ),
  'commitments', (SELECT count(*) FROM public.investment_commitments),
  'holdings', (SELECT count(*) FROM public.portfolio_holdings),
  'distributions_without_opportunity', (
    SELECT count(*) FROM public.investment_distributions
    WHERE opportunity_id IS NULL
  ),
  'unspecified_investor_provenance', (
    SELECT count(*) FROM public.investors
    WHERE NOT (COALESCE(metadata, '{}'::jsonb) ? 'source')
  )
) AS imp_provenance_report;
