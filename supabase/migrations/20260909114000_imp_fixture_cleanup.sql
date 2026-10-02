-- Remove the exact untagged fixture graph introduced by the former portal
-- backfill. No fuzzy name/email matching is used.

BEGIN;

CREATE TEMP TABLE imp_fixture_investors ON COMMIT DROP AS
SELECT DISTINCT i.id
FROM public.investors i
JOIN public.investor_portfolios p ON p.investor_id = i.id
JOIN public.investor_wallets w ON w.investor_id = i.id
WHERE i.user_id IS NOT NULL
  AND p.name = 'Primary Portfolio'
  AND p.total_value = 85000000
  AND p.total_cost = 70000000
  AND w.available_balance = 2500000
  AND w.pending_balance = 500000
  AND EXISTS (
    SELECT 1 FROM public.investment_distributions d
    WHERE d.investor_id = i.id
      AND d.reference IN ('DIV-DEMO-001', 'DIV-DEMO-002')
  );

DROP TRIGGER IF EXISTS trg_investor_activity_immutable
  ON public.investor_activity_logs;

DELETE FROM public.investor_activity_logs
WHERE investor_id IN (SELECT id FROM imp_fixture_investors)
  AND (
    (event_type = 'distribution' AND title = 'Dividend paid'
      AND description = '₦750,000 credited to wallet.')
    OR (event_type = 'holding' AND title = 'Portfolio valuation updated'
      AND description = 'Mark-to-market increased by ₦2.1M.')
    OR (event_type = 'document' AND title = 'Statement available'
      AND description = 'Q1 2026 statement is ready for download.')
  );

CREATE TRIGGER trg_investor_activity_immutable
  BEFORE UPDATE OR DELETE ON public.investor_activity_logs
  FOR EACH ROW EXECUTE FUNCTION public.guard_investor_activity_immutable();

DELETE FROM public.investor_notifications
WHERE investor_id IN (SELECT id FROM imp_fixture_investors)
  AND (
    (title = 'Dividend scheduled'
      AND body = 'Your next dividend is scheduled in 15 days.')
    OR (title = 'Construction update'
      AND body = 'Foundation works completed on Lekki Phase 2.')
  );

DELETE FROM public.investor_documents
WHERE investor_id IN (SELECT id FROM imp_fixture_investors)
  AND file_url IN (
    'https://hdhomes.ng/docs/investor-agreement.pdf',
    'https://hdhomes.ng/docs/investor-statement.pdf',
    'https://hdhomes.ng/docs/investor-tax.pdf'
  );

DELETE FROM public.investor_reports
WHERE investor_id IN (SELECT id FROM imp_fixture_investors)
  AND file_url = 'https://hdhomes.ng/docs/investor-report.pdf'
  AND period_label = 'Mar 2026';

DELETE FROM public.investor_statements
WHERE investor_id IN (SELECT id FROM imp_fixture_investors)
  AND file_url = 'https://hdhomes.ng/docs/investor-q1.pdf'
  AND period_label = 'Q1 2026'
  AND opening_balance = 70000000
  AND closing_balance = 85000000;

DELETE FROM public.investment_performance
WHERE investor_id IN (SELECT id FROM imp_fixture_investors)
  AND nav = 85000000
  AND twr_pct = 12.4
  AND irr_pct = 14.1
  AND yield_pct = 8.5;

DELETE FROM public.investor_referral_commissions
WHERE investor_id IN (SELECT id FROM imp_fixture_investors)
  AND commission_amount = 250000
  AND status = 'pending'
  AND referral_code LIKE 'HDH-INV-%';

DELETE FROM public.investment_distributions
WHERE investor_id IN (SELECT id FROM imp_fixture_investors)
  AND reference IN ('DIV-DEMO-001', 'DIV-DEMO-002')
  AND amount = 750000;

DELETE FROM public.portfolio_holdings h
USING public.investor_portfolios p
WHERE h.portfolio_id = p.id
  AND p.investor_id IN (SELECT id FROM imp_fixture_investors)
  AND h.opportunity_id IS NULL
  AND h.units = 10
  AND h.cost_basis = 70000000
  AND h.current_value = 85000000
  AND COALESCE(h.metadata, '{}'::jsonb) = '{}'::jsonb;

UPDATE public.investor_wallets
SET available_balance = 0,
    pending_balance = 0,
    reserved_balance = 0,
    updated_at = now()
WHERE investor_id IN (SELECT id FROM imp_fixture_investors)
  AND available_balance = 2500000
  AND pending_balance = 500000;

UPDATE public.investor_portfolios p
SET total_cost = COALESCE((
      SELECT sum(h.cost_basis) FROM public.portfolio_holdings h
      WHERE h.portfolio_id = p.id
    ), 0),
    total_value = COALESCE((
      SELECT sum(h.current_value) FROM public.portfolio_holdings h
      WHERE h.portfolio_id = p.id
    ), 0),
    unrealized_gain = COALESCE((
      SELECT sum(h.current_value - h.cost_basis)
      FROM public.portfolio_holdings h
      WHERE h.portfolio_id = p.id
    ), 0),
    realized_gain = 0,
    updated_at = now()
WHERE p.investor_id IN (SELECT id FROM imp_fixture_investors);

UPDATE public.investors i
SET aum = COALESCE((
      SELECT sum(p.total_value) FROM public.investor_portfolios p
      WHERE p.investor_id = i.id
    ), 0),
    total_committed = COALESCE((
      SELECT sum(c.amount) FROM public.investment_commitments c
      WHERE c.investor_id = i.id
        AND c.status NOT IN ('cancelled', 'refunded')
    ), 0),
    metadata = COALESCE(i.metadata, '{}'::jsonb)
      || jsonb_build_object('source', 'portal_self_provisioned'),
    updated_at = now()
WHERE i.id IN (SELECT id FROM imp_fixture_investors);

-- The old migration created investor records for client/admin/finance roles.
-- Remove only those deterministic records when no real business data remains.
DELETE FROM public.investors i
WHERE i.id IN (SELECT id FROM imp_fixture_investors)
  AND i.investor_code =
    'INV-' || upper(substring(replace(i.user_id::text, '-', ''), 1, 8))
  AND NOT EXISTS (
    SELECT 1
    FROM public.user_roles ur
    JOIN public.roles r ON r.id = ur.role_id
    WHERE ur.user_id = i.user_id
      AND COALESCE(ur.is_deleted, false) = false
      AND r.slug = 'investor'
  )
  AND NOT EXISTS (
    SELECT 1 FROM public.investment_commitments c
    WHERE c.investor_id = i.id
  )
  AND NOT EXISTS (
    SELECT 1 FROM public.portfolio_holdings h
    JOIN public.investor_portfolios p ON p.id = h.portfolio_id
    WHERE p.investor_id = i.id
  )
  AND NOT EXISTS (
    SELECT 1 FROM public.investment_distributions d
    WHERE d.investor_id = i.id
  )
  AND NOT EXISTS (
    SELECT 1 FROM public.payments p
    WHERE p.investor_id = i.id
  )
  AND NOT EXISTS (
    SELECT 1 FROM public.investor_conversations c
    WHERE c.investor_id = i.id
  );

COMMIT;
