-- IMP ops rebuild → investor portal E2E sync smoke (extends phase 15 catalog checks).

CREATE OR REPLACE FUNCTION public.investor_portal_imp_ops_e2e_smoke()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_required_fns text[] := ARRAY[
    'admin_assign_investor_holding',
    'admin_message_investor',
    'admin_publish_document_to_investor',
    'admin_publish_investor_notification',
    'admin_publish_investor_report',
    'admin_verify_investor_kyc',
    'admin_confirm_investor_intent',
    'admin_fund_investment_commitment',
    'admin_get_investor_desk_kpis',
    'admin_get_investor_construction',
    'admin_get_investor_360',
    'admin_list_investors',
    'admin_set_website_investment_opportunity_status',
    'support_ticket_send_message',
    'investor_mark_notifications_read',
    'investor_analytics_snapshot'
  ];
  v_missing_fns text[] := ARRAY[]::text[];
  v_required_policies text[] := ARRAY[
    'investor_notifications_owner_select',
    'investor_kyc_reviews_owner_select',
    'investor_payment_intents_select',
    'investor_payment_intents_insert',
    'investor_documents_owner_select',
    'portfolio_holdings_owner_select'
  ];
  v_missing_policies text[] := ARRAY[]::text[];
  v_rt_tables text[] := ARRAY[
    'investor_notifications',
    'investor_kyc_reviews',
    'portfolio_holdings',
    'investor_documents',
    'investor_conversations',
    'investor_conversation_messages',
    'investor_reports',
    'tickets',
    'ticket_messages',
    'construction_projects',
    'construction_progress_updates',
    'construction_update_media',
    'website_investment_opportunities'
  ];
  v_missing_rt text[] := ARRAY[]::text[];
  v_anon_open text[] := ARRAY[]::text[];
  f text;
  p text;
  t text;
  v_phase15 jsonb;
  r record;
BEGIN
  FOREACH f IN ARRAY v_required_fns LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_proc pr
      JOIN pg_namespace n ON n.oid = pr.pronamespace
      WHERE n.nspname = 'public' AND pr.proname = f
    ) THEN
      v_missing_fns := array_append(v_missing_fns, f);
    END IF;
  END LOOP;

  FOREACH p IN ARRAY v_required_policies LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname = 'public' AND policyname = p
    ) THEN
      v_missing_policies := array_append(v_missing_policies, p);
    END IF;
  END LOOP;

  FOREACH t IN ARRAY v_rt_tables LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = t
    ) THEN
      v_missing_rt := array_append(v_missing_rt, t);
    END IF;
  END LOOP;

  -- Staff DEFINER RPCs used by IMP must not be executable by anon.
  FOR r IN
    SELECT pr.proname
    FROM pg_proc pr
    JOIN pg_namespace n ON n.oid = pr.pronamespace
    WHERE n.nspname = 'public'
      AND pr.proname = ANY (ARRAY[
        'admin_get_investor_desk_kpis',
        'admin_get_investor_construction',
        'admin_set_website_investment_opportunity_status',
        'admin_publish_investor_notification',
        'admin_message_investor',
        'admin_list_investors'
      ])
      AND has_function_privilege('anon', pr.oid, 'EXECUTE')
  LOOP
    v_anon_open := array_append(v_anon_open, r.proname);
  END LOOP;

  BEGIN
    v_phase15 := public.investor_portal_phase15_e2e_smoke();
  EXCEPTION WHEN undefined_function THEN
    v_phase15 := jsonb_build_object('ok', false, 'error', 'phase15_smoke_missing');
  END;

  RETURN jsonb_build_object(
    'ok',
      (array_length(v_missing_fns, 1) IS NULL)
      AND (array_length(v_missing_policies, 1) IS NULL)
      AND (array_length(v_missing_rt, 1) IS NULL)
      AND (array_length(v_anon_open, 1) IS NULL)
      AND COALESCE((v_phase15 ->> 'ok')::boolean, false),
    'missing_functions', to_jsonb(v_missing_fns),
    'missing_policies', to_jsonb(v_missing_policies),
    'missing_realtime_tables', to_jsonb(v_missing_rt),
    'anon_execute_open', to_jsonb(v_anon_open),
    'phase15_smoke', v_phase15,
    'checked_at', now()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.investor_portal_imp_ops_e2e_smoke() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.investor_portal_imp_ops_e2e_smoke() FROM anon;
GRANT EXECUTE ON FUNCTION public.investor_portal_imp_ops_e2e_smoke() TO authenticated;

COMMENT ON FUNCTION public.investor_portal_imp_ops_e2e_smoke() IS
  'IMP ops→portal sync smoke: RPCs, owner RLS, realtime pubs, anon EXECUTE hygiene.';
