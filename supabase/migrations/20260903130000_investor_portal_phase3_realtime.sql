-- Phase 3 — Investor Portal realtime foundation
-- 1) Ensure all hub tables are in supabase_realtime publication
-- 2) REPLICA IDENTITY FULL so investor_id / user_id filters receive UPDATEs

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
    'payments',
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
    'tickets',
    'ticket_messages',
    'construction_progress_updates',
    'construction_update_media',
    'construction_projects',
    'project_milestones',
    'investment_receiving_accounts'
  ]
  LOOP
    IF EXISTS (
      SELECT 1
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public'
        AND c.relname = tbl
        AND c.relkind IN ('r', 'p')
    ) THEN
      EXECUTE format(
        'ALTER TABLE public.%I REPLICA IDENTITY FULL',
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
    'payments',
    'investor_documents',
    'investor_notifications',
    'investor_conversations',
    'investor_conversation_messages',
    'construction_progress_updates',
    'construction_update_media',
    'tickets',
    'ticket_messages'
  ];
  t text;
  v_missing text[] := ARRAY[]::text[];
  v_not_full text[] := ARRAY[]::text[];
  v_ident text;
BEGIN
  FOREACH t IN ARRAY v_required LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = t
    ) THEN
      v_missing := array_append(v_missing, t);
    END IF;

    SELECT CASE c.relreplident
             WHEN 'd' THEN 'default'
             WHEN 'f' THEN 'full'
             WHEN 'i' THEN 'index'
             WHEN 'n' THEN 'nothing'
           END
      INTO v_ident
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = t;

    IF v_ident IS DISTINCT FROM 'full' THEN
      v_not_full := array_append(v_not_full, t || ':' || coalesce(v_ident, 'missing'));
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'ok', array_length(v_missing, 1) IS NULL AND array_length(v_not_full, 1) IS NULL,
    'missing_publication', to_jsonb(v_missing),
    'not_replica_full', to_jsonb(v_not_full),
    'checked_at', now()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.investor_portal_phase3_realtime_smoke() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.investor_portal_phase3_realtime_smoke() TO authenticated;
