-- IMP Phase 8 smoke: engagement RPCs + command APIs (run under authenticated admin).
-- Expectation: functions exist; 360 returns engagement keys; queues/directory callable.

SELECT jsonb_build_object(
  'has_report_rpc', EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'admin_publish_investor_report'
  ),
  'has_referral_rpc', EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'admin_award_investor_referral'
  ),
  'has_fund_rpc', EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'admin_fund_investment_commitment'
  ),
  'has_confirm_rpc', EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'admin_confirm_investor_intent'
  ),
  'command_events_realtime', EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'investor_command_events'
  )
) AS imp_phase8_catalog;
