-- Investor Portal Phase 2 — RLS isolation smoke checks
-- Run in SQL editor as a privileged role (service_role / postgres).
-- Validates ownership helpers and that Investor A predicates never match Investor B rows.

DO $$
DECLARE
  a_uid uuid;
  b_uid uuid;
  a_inv uuid;
  b_inv uuid;
  seen int;
BEGIN
  SELECT i.user_id, i.id
    INTO a_uid, a_inv
  FROM public.investors i
  WHERE coalesce(i.is_deleted, false) = false
    AND i.user_id IS NOT NULL
  ORDER BY i.created_at
  LIMIT 1;

  SELECT i.user_id, i.id
    INTO b_uid, b_inv
  FROM public.investors i
  WHERE coalesce(i.is_deleted, false) = false
    AND i.user_id IS NOT NULL
    AND i.id <> a_inv
  ORDER BY i.created_at
  LIMIT 1;

  IF a_uid IS NULL OR b_uid IS NULL THEN
    RAISE EXCEPTION 'need_two_investors_with_user_ids';
  END IF;

  IF public.investor_id_for_user(a_uid) IS DISTINCT FROM a_inv THEN
    RAISE EXCEPTION 'helper_mismatch_a';
  END IF;
  IF public.investor_id_for_user(b_uid) IS DISTINCT FROM b_inv THEN
    RAISE EXCEPTION 'helper_mismatch_b';
  END IF;

  SELECT count(*) INTO seen
  FROM public.investor_documents d
  WHERE d.investor_id = b_inv
    AND d.investor_id = public.investor_id_for_user(a_uid);
  IF seen <> 0 THEN
    RAISE EXCEPTION 'docs_cross_visible';
  END IF;

  SELECT count(*) INTO seen
  FROM public.portfolio_holdings ph
  JOIN public.investor_portfolios ip ON ip.id = ph.portfolio_id
  WHERE ip.investor_id = b_inv
    AND ip.investor_id = public.investor_id_for_user(a_uid);
  IF seen <> 0 THEN
    RAISE EXCEPTION 'holdings_cross_visible';
  END IF;

  SELECT count(*) INTO seen
  FROM public.investor_payment_intents p
  WHERE p.investor_id = b_inv
    AND p.investor_id = public.investor_id_for_user(a_uid);
  IF seen <> 0 THEN
    RAISE EXCEPTION 'intents_cross_visible';
  END IF;

  SELECT count(*) INTO seen
  FROM public.investor_conversations c
  WHERE c.investor_id = b_inv
    AND c.investor_id = public.investor_id_for_user(a_uid);
  IF seen <> 0 THEN
    RAISE EXCEPTION 'conversations_cross_visible';
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'investor_payment_intents'
      AND policyname = 'investor_payment_intents_own'
  ) THEN
    RAISE EXCEPTION 'legacy_for_all_policy_still_present';
  END IF;

  IF NOT (public.investor_portal_phase2_security_smoke() ->> 'ok')::boolean THEN
    RAISE EXCEPTION 'phase2_catalog_smoke_failed: %',
      public.investor_portal_phase2_security_smoke();
  END IF;

  RAISE NOTICE 'investor_portal_phase2_isolation_ok a=% b=%', a_inv, b_inv;
END $$;

SELECT public.investor_portal_phase2_security_smoke();
