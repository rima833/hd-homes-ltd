-- Client/investor portal integrity hardening.
-- Restricts owner writes to intended operations and aligns portal smoke checks.

BEGIN;

-- Allocations and progress are staff/system managed. Clients can only read.
DROP POLICY IF EXISTS client_properties_own ON public.client_properties;
DROP POLICY IF EXISTS client_properties_owner_select ON public.client_properties;
DROP POLICY IF EXISTS client_properties_staff_all ON public.client_properties;

CREATE POLICY client_properties_owner_select
  ON public.client_properties
  FOR SELECT TO authenticated
  USING (client_id = public.client_id_for_user(auth.uid()));

CREATE POLICY client_properties_staff_all
  ON public.client_properties
  FOR ALL TO authenticated
  USING (public.is_staff())
  WITH CHECK (public.is_staff());

-- Clients may open and read conversations, but cannot change assignment,
-- lifecycle status, soft-delete state, or other staff-managed metadata.
DROP POLICY IF EXISTS client_conversations_own ON public.client_conversations;
DROP POLICY IF EXISTS client_conversations_owner_select
  ON public.client_conversations;
DROP POLICY IF EXISTS client_conversations_owner_insert
  ON public.client_conversations;
DROP POLICY IF EXISTS client_conversations_staff_all
  ON public.client_conversations;

CREATE POLICY client_conversations_owner_select
  ON public.client_conversations
  FOR SELECT TO authenticated
  USING (client_id = public.client_id_for_user(auth.uid()));

CREATE POLICY client_conversations_owner_insert
  ON public.client_conversations
  FOR INSERT TO authenticated
  WITH CHECK (
    client_id = public.client_id_for_user(auth.uid())
    AND assigned_staff_id IS NULL
    AND status = 'open'
    AND is_deleted = false
  );

CREATE POLICY client_conversations_staff_all
  ON public.client_conversations
  FOR ALL TO authenticated
  USING (public.is_staff())
  WITH CHECK (public.is_staff());

-- Client message writes are append-only and must identify the signed-in sender.
DROP POLICY IF EXISTS client_messages_own
  ON public.client_conversation_messages;
DROP POLICY IF EXISTS client_messages_owner_select
  ON public.client_conversation_messages;
DROP POLICY IF EXISTS client_messages_owner_insert
  ON public.client_conversation_messages;
DROP POLICY IF EXISTS client_messages_staff_all
  ON public.client_conversation_messages;

CREATE POLICY client_messages_owner_select
  ON public.client_conversation_messages
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.client_conversations conversation
      WHERE conversation.id = conversation_id
        AND conversation.client_id = public.client_id_for_user(auth.uid())
    )
  );

CREATE POLICY client_messages_owner_insert
  ON public.client_conversation_messages
  FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND is_deleted = false
    AND EXISTS (
      SELECT 1
      FROM public.client_conversations conversation
      WHERE conversation.id = conversation_id
        AND conversation.client_id = public.client_id_for_user(auth.uid())
    )
  );

CREATE POLICY client_messages_staff_all
  ON public.client_conversation_messages
  FOR ALL TO authenticated
  USING (public.is_staff())
  WITH CHECK (public.is_staff());

-- Cancellation is an explicit operation; owners no longer have arbitrary
-- UPDATE access to inspection records.
DROP POLICY IF EXISTS property_inspections_client_update
  ON public.property_inspections;

CREATE OR REPLACE FUNCTION public.cancel_client_property_inspection(
  p_inspection_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_updated_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication_required';
  END IF;

  UPDATE public.property_inspections inspection
  SET
    status = 'cancelled',
    updated_at = now()
  WHERE inspection.id = p_inspection_id
    AND lower(COALESCE(inspection.status, '')) IN (
      'pending', 'requested', 'scheduled', 'confirmed', 'rescheduled'
    )
    AND (
      inspection.visitor_profile_id = auth.uid()
      OR EXISTS (
        SELECT 1
        FROM public.client_properties client_property
        JOIN public.clients client
          ON client.id = client_property.client_id
        WHERE client_property.property_id = inspection.property_id
          AND client.user_id = auth.uid()
          AND client_property.is_deleted = false
      )
    )
  RETURNING inspection.id INTO v_updated_id;

  IF v_updated_id IS NULL THEN
    RAISE EXCEPTION 'inspection_not_cancellable';
  END IF;

  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.cancel_client_property_inspection(uuid)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.cancel_client_property_inspection(uuid)
  FROM anon;
GRANT EXECUTE ON FUNCTION public.cancel_client_property_inspection(uuid)
  TO authenticated;

-- Keep the catalog smoke aligned with the latest owner policy name.
CREATE OR REPLACE FUNCTION public.investor_portal_phase2_security_smoke()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_policies text[];
  v_missing text[] := ARRAY[]::text[];
  v_required text[] := ARRAY[
    'investor_payment_intents_select',
    'investor_payment_intents_insert',
    'investor_payment_intents_update_owner',
    'investor_payment_intents_finance_write',
    'construction_update_media_investor_read',
    'construction_update_media_client_read'
  ];
  p text;
  v_legacy_all boolean;
  v_fn_exists boolean;
  v_trigger_exists boolean;
BEGIN
  SELECT COALESCE(
    array_agg(policyname ORDER BY policyname),
    ARRAY[]::text[]
  )
  INTO v_policies
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename IN (
      'investor_payment_intents',
      'construction_update_media'
    );

  FOREACH p IN ARRAY v_required LOOP
    IF NOT (p = ANY (v_policies)) THEN
      v_missing := array_append(v_missing, p);
    END IF;
  END LOOP;

  SELECT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'investor_payment_intents'
      AND policyname = 'investor_payment_intents_own'
      AND cmd = 'ALL'
  ) INTO v_legacy_all;

  SELECT EXISTS (
    SELECT 1
    FROM pg_proc procedure
    JOIN pg_namespace namespace ON namespace.oid = procedure.pronamespace
    WHERE namespace.nspname = 'public'
      AND procedure.proname = 'admin_publish_document_to_investor'
  ) INTO v_fn_exists;

  SELECT EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgname = 'trg_investor_payment_intents_owner_guard'
      AND NOT tgisinternal
  ) INTO v_trigger_exists;

  RETURN jsonb_build_object(
    'ok',
      array_length(v_missing, 1) IS NULL
      AND NOT v_legacy_all
      AND v_fn_exists
      AND v_trigger_exists,
    'missing_policies', to_jsonb(v_missing),
    'legacy_for_all_policy_present', v_legacy_all,
    'admin_publish_document_to_investor', v_fn_exists,
    'owner_guard_trigger', v_trigger_exists,
    'checked_at', now()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.investor_portal_phase2_security_smoke()
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.investor_portal_phase2_security_smoke()
  TO authenticated;

CREATE OR REPLACE FUNCTION public.investor_portal_phase15_e2e_smoke()
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
    'admin_verify_investor_kyc',
    'admin_confirm_investor_intent',
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
    'investor_conversations'
  ];
  v_missing_rt text[] := ARRAY[]::text[];
  f text;
  p text;
  t text;
  v_phase2 jsonb;
BEGIN
  FOREACH f IN ARRAY v_required_fns LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM pg_proc procedure
      JOIN pg_namespace namespace ON namespace.oid = procedure.pronamespace
      WHERE namespace.nspname = 'public'
        AND procedure.proname = f
    ) THEN
      v_missing_fns := array_append(v_missing_fns, f);
    END IF;
  END LOOP;

  FOREACH p IN ARRAY v_required_policies LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM pg_policies
      WHERE schemaname = 'public'
        AND policyname = p
    ) THEN
      v_missing_policies := array_append(v_missing_policies, p);
    END IF;
  END LOOP;

  FOREACH t IN ARRAY v_rt_tables LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = t
    ) THEN
      v_missing_rt := array_append(v_missing_rt, t);
    END IF;
  END LOOP;

  BEGIN
    v_phase2 := public.investor_portal_phase2_security_smoke();
  EXCEPTION WHEN undefined_function THEN
    v_phase2 := jsonb_build_object(
      'ok', false,
      'error', 'phase2_smoke_missing'
    );
  END;

  RETURN jsonb_build_object(
    'ok',
      array_length(v_missing_fns, 1) IS NULL
      AND array_length(v_missing_policies, 1) IS NULL
      AND array_length(v_missing_rt, 1) IS NULL
      AND COALESCE((v_phase2 ->> 'ok')::boolean, false),
    'missing_functions', to_jsonb(v_missing_fns),
    'missing_policies', to_jsonb(v_missing_policies),
    'missing_realtime_tables', to_jsonb(v_missing_rt),
    'phase2_smoke', v_phase2,
    'checked_at', now()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.investor_portal_phase15_e2e_smoke()
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.investor_portal_phase15_e2e_smoke()
  TO authenticated;

COMMIT;
