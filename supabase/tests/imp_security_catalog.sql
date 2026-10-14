-- Catalog-level guardrails complement role-executed RLS integration tests.

DO $$
DECLARE
  v_definition text;
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.roles r
    JOIN public.role_permissions rp ON rp.role_id = r.id
    JOIN public.permissions p ON p.id = rp.permission_id
    WHERE r.slug = 'investor' AND p.slug LIKE 'investors.%'
  ) THEN
    RAISE EXCEPTION 'investor_role_has_staff_permission';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'investors'
      AND policyname = 'investors_self_update'
  ) THEN
    RAISE EXCEPTION 'unsafe_investor_self_update_policy_present';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN (
        'investor_conversations', 'investor_conversation_messages'
      )
      AND cmd = 'ALL'
      AND COALESCE(qual, '') LIKE '%investor_id_for_user%'
  ) THEN
    RAISE EXCEPTION 'owner_conversation_for_all_policy_present';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'trg_investor_activity_immutable' AND NOT tgisinternal
  ) THEN
    RAISE EXCEPTION 'immutable_investor_activity_trigger_missing';
  END IF;

  SELECT pg_get_functiondef(p.oid) INTO v_definition
  FROM pg_proc p
  WHERE p.pronamespace = 'public'::regnamespace
    AND p.proname = 'admin_message_investor';
  IF v_definition IS NULL
     OR v_definition NOT LIKE '%investors.communicate%'
     OR v_definition LIKE '%public.is_staff()%' THEN
    RAISE EXCEPTION 'admin_message_investor_not_hardened';
  END IF;
END $$;
