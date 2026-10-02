-- Client portal security + realtime hardening
-- 1) Tighten construction_updates client visibility
-- 2) Ensure key client tables are included in realtime publication
-- 3) Remove permissive client payment intent update/delete for regular clients

BEGIN;

-- ---------------------------------------------------------------------------
-- 1) Construction updates: replace global read with scoped read
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS construction_updates_read ON public.construction_updates;
CREATE POLICY construction_updates_read ON public.construction_updates
  FOR SELECT USING (
    public.is_staff()
    OR EXISTS (
      SELECT 1
      FROM public.projects p
      JOIN public.client_properties cp ON cp.property_id = p.property_id
      JOIN public.clients c ON c.id = cp.client_id
      WHERE p.id = construction_updates.project_id
        AND c.user_id = auth.uid()
        AND cp.is_deleted = false
    )
  );

-- ---------------------------------------------------------------------------
-- 2) Realtime publication coverage for client portal tables
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'client_properties',
    'client_documents',
    'client_preferences',
    'client_referral_commissions',
    'client_payment_intents',
    'client_conversations',
    'construction_updates',
    'payments',
    'installments',
    'property_inspections',
    'tickets',
    'favorite_items'
  ]
  LOOP
    BEGIN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    EXCEPTION WHEN duplicate_object THEN
      NULL;
    END;
  END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- 3) Payment intents: least-privilege for clients
--    Clients can create and read their own intents, but cannot mutate
--    terminal state directly.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS client_payment_intents_own ON public.client_payment_intents;

CREATE POLICY client_payment_intents_select_own ON public.client_payment_intents
  FOR SELECT USING (
    client_id = public.client_id_for_user(auth.uid())
    OR public.has_permission('manage_payments')
  );

CREATE POLICY client_payment_intents_insert_own ON public.client_payment_intents
  FOR INSERT WITH CHECK (
    client_id = public.client_id_for_user(auth.uid())
    OR public.has_permission('manage_payments')
  );

CREATE POLICY client_payment_intents_update_staff_only ON public.client_payment_intents
  FOR UPDATE USING (
    public.has_permission('manage_payments')
  )
  WITH CHECK (
    public.has_permission('manage_payments')
  );

CREATE POLICY client_payment_intents_delete_staff_only ON public.client_payment_intents
  FOR DELETE USING (
    public.has_permission('manage_payments')
  );

COMMIT;
