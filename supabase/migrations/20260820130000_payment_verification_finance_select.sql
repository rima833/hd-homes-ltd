-- Align client_payment_intents staff SELECT with finance verification permissions.
-- Mirrors _finance_can_verify() so the queue works even before that helper exists.

DROP POLICY IF EXISTS client_payment_intents_select_own ON public.client_payment_intents;

CREATE POLICY client_payment_intents_select_own ON public.client_payment_intents
  FOR SELECT TO authenticated
  USING (
    client_id = public.client_id_for_user(auth.uid())
    OR public.has_permission('manage_payments')
    OR public.has_permission('finance.payments')
    OR public.has_permission('finance.write')
    OR public.has_role('super_admin')
  );
