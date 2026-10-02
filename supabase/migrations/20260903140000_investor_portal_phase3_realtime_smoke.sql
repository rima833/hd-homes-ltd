-- Phase 3b — Investor portal realtime publication smoke + completeness pass.
-- Idempotent publication ensure + catalog smoke RPC for CI / ops.

DO $$
DECLARE
  tbl text;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'investors',
    'portfolio_holdings',
    'investment_distributions',
    'investor_wallets',
    'investor_payment_intents',
    'investment_receiving_accounts',
    'payments',
    'finance_receipts',
    'investor_documents',
    'investor_reports',
    'investor_statements',
    'investment_performance',
    'investor_notifications',
    'investor_alerts',
    'investor_activity_logs',
    'investor_referral_commissions',
    'investor_preferences',
    'investor_conversations',
    'investor_conversation_messages',
    'construction_progress_updates',
    'construction_update_media',
    'construction_projects',
    'project_milestones',
    'tickets',
    'ticket_messages'
  ]
  LOOP
    IF EXISTS (
      SELECT 1
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public'
        AND c.relname = tbl
        AND c.relkind IN ('r', 'p')
    ) AND NOT EXISTS (
      SELECT 1
      FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = tbl
    ) THEN
      EXECUTE format(
        'ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',
        tbl
      );
    END IF;
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.investor_portal_phase3_realtime_smoke()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_required text[] := ARRAY[
    'investors',
    'portfolio_holdings',
    'investment_distributions',
    'investor_wallets',
    'investor_payment_intents',
    'investment_receiving_accounts',
    'payments',
    'finance_receipts',
    'investor_documents',
    'investor_reports',
    'investor_statements',
    'investment_performance',
    'investor_notifications',
    'investor_alerts',
    'investor_activity_logs',
    'investor_referral_commissions',
    'investor_preferences',
    'investor_conversations',
    'investor_conversation_messages',
    'construction_progress_updates',
    'construction_update_media',
    'construction_projects',
    'project_milestones',
    'tickets',
    'ticket_messages'
  ];
  v_missing text[] := ARRAY[]::text[];
  t text;
BEGIN
  FOREACH t IN ARRAY v_required LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = t
    ) THEN
      -- Only count as missing when the table exists.
      IF EXISTS (
        SELECT 1 FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = t AND c.relkind IN ('r', 'p')
      ) THEN
        v_missing := array_append(v_missing, t);
      END IF;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'ok', array_length(v_missing, 1) IS NULL,
    'missing_publications', to_jsonb(v_missing),
    'required_count', coalesce(array_length(v_required, 1), 0),
    'checked_at', now()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.investor_portal_phase3_realtime_smoke() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.investor_portal_phase3_realtime_smoke() TO authenticated;
