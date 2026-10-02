-- Investor platform production security and integrity foundation.
-- This migration is intentionally non-destructive to existing business rows.

BEGIN;

-- ---------------------------------------------------------------------------
-- Granular investor-desk capabilities
-- ---------------------------------------------------------------------------
INSERT INTO public.permissions (slug, name, description, module) VALUES
  ('investors.communicate', 'Communicate With Investors', 'Manage investor conversations and targeted notifications', 'investors'),
  ('investors.payments', 'Manage Investor Payments', 'Review investor payment evidence and payment state', 'investors'),
  ('investors.tasks', 'Manage Investor Tasks', 'Assign and complete investor relationship tasks', 'investors'),
  ('investors.reports', 'Manage Investor Reports', 'Create and publish investor reports and statements', 'investors'),
  ('investors.referrals', 'Manage Investor Referrals', 'Review investor referral attribution and rewards', 'investors'),
  ('investors.audit', 'View Investor Audit', 'View immutable investor operations history', 'investors')
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  module = EXCLUDED.module,
  updated_at = now();

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
JOIN public.permissions p ON (
  r.slug IN ('super_admin', 'admin')
  OR (r.slug = 'sales_team' AND p.slug IN (
    'investors.communicate', 'investors.tasks'
  ))
  OR (r.slug = 'finance' AND p.slug IN (
    'investors.payments', 'investors.reports', 'investors.referrals',
    'investors.audit'
  ))
)
WHERE p.slug IN (
  'investors.communicate', 'investors.payments', 'investors.tasks',
  'investors.reports', 'investors.referrals', 'investors.audit'
)
ON CONFLICT DO NOTHING;

-- Portal ownership comes from investors.user_id, never from desk permission.
DELETE FROM public.role_permissions rp
USING public.roles r, public.permissions p
WHERE rp.role_id = r.id
  AND rp.permission_id = p.id
  AND r.slug = 'investor'
  AND p.slug LIKE 'investors.%';

-- ---------------------------------------------------------------------------
-- Ownership helper: callers may resolve themselves; desk users need read.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.investor_id_for_user(uid uuid)
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF uid IS NULL OR auth.uid() IS NULL THEN
    RETURN NULL;
  END IF;
  IF uid <> auth.uid()
     AND NOT public.has_permission('investors.read', auth.uid())
     AND NOT public.has_role('super_admin', auth.uid()) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;
  SELECT i.id INTO v_id
  FROM public.investors i
  WHERE i.user_id = uid
    AND COALESCE(i.is_deleted, false) = false
  ORDER BY i.created_at
  LIMIT 1;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.investor_id_for_user(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.investor_id_for_user(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- Investors: own row is read-only; staff access is capability based.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS investors_select ON public.investors;
DROP POLICY IF EXISTS investors_self_select ON public.investors;
DROP POLICY IF EXISTS investors_self_update ON public.investors;
DROP POLICY IF EXISTS investors_write ON public.investors;

CREATE POLICY investors_owner_select ON public.investors
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() AND COALESCE(is_deleted, false) = false);

CREATE POLICY investors_staff_select ON public.investors
  FOR SELECT TO authenticated
  USING (
    public.has_permission('investors.read', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

CREATE POLICY investors_staff_write ON public.investors
  FOR ALL TO authenticated
  USING (
    public.has_permission('investors.write', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('investors.write', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

-- ---------------------------------------------------------------------------
-- Child-table reads: owner policies never include generic staff access.
-- Existing broad select policies are replaced with explicit desk reads.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'investor_profiles', 'investor_preferences', 'investment_commitments',
    'investor_portfolios', 'investment_distributions', 'investor_wallets',
    'investor_bank_accounts', 'investor_documents', 'investor_statements',
    'investor_reports', 'investor_activity_logs', 'investor_notifications',
    'investor_kyc_reviews', 'investment_performance', 'investor_alerts',
    'investor_relationships', 'investor_referral_commissions', 'investor_tasks'
  ]
  LOOP
    IF to_regclass('public.' || t) IS NULL THEN CONTINUE; END IF;
    EXECUTE format('DROP POLICY IF EXISTS %I_select ON public.%I', t, t);
    EXECUTE format('DROP POLICY IF EXISTS %I_portal_owner ON public.%I', t, t);
    EXECUTE format('DROP POLICY IF EXISTS %I_own ON public.%I', t, t);
    EXECUTE format(
      'CREATE POLICY %I_owner_select ON public.%I FOR SELECT TO authenticated
       USING (investor_id = public.investor_id_for_user(auth.uid()))',
      t, t
    );
    EXECUTE format(
      'CREATE POLICY %I_staff_select ON public.%I FOR SELECT TO authenticated
       USING (
         public.has_permission(''investors.read'', auth.uid())
         OR public.has_role(''super_admin'', auth.uid())
       )',
      t, t
    );
  END LOOP;
END $$;

DROP POLICY IF EXISTS portfolio_holdings_select ON public.portfolio_holdings;
DROP POLICY IF EXISTS portfolio_holdings_portal_owner ON public.portfolio_holdings;
CREATE POLICY portfolio_holdings_owner_select ON public.portfolio_holdings
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.investor_portfolios ip
      WHERE ip.id = portfolio_id
        AND ip.investor_id = public.investor_id_for_user(auth.uid())
    )
  );
CREATE POLICY portfolio_holdings_staff_select ON public.portfolio_holdings
  FOR SELECT TO authenticated
  USING (
    public.has_permission('investors.read', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

-- ---------------------------------------------------------------------------
-- Direct writes: explicit capabilities only.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS investment_commitments_write ON public.investment_commitments;
CREATE POLICY investment_commitments_staff_write ON public.investment_commitments
  FOR ALL TO authenticated
  USING (
    public.has_permission('investors.opportunities', auth.uid())
    OR public.has_permission('investors.portfolio', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('investors.opportunities', auth.uid())
    OR public.has_permission('investors.portfolio', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

DROP POLICY IF EXISTS investor_portfolios_write ON public.investor_portfolios;
CREATE POLICY investor_portfolios_staff_write ON public.investor_portfolios
  FOR ALL TO authenticated
  USING (
    public.has_permission('investors.portfolio', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('investors.portfolio', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

DROP POLICY IF EXISTS portfolio_holdings_write ON public.portfolio_holdings;
CREATE POLICY portfolio_holdings_staff_write ON public.portfolio_holdings
  FOR ALL TO authenticated
  USING (
    public.has_permission('investors.portfolio', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('investors.portfolio', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

DROP POLICY IF EXISTS investor_preferences_write ON public.investor_preferences;
DROP POLICY IF EXISTS investor_preferences_portal_write ON public.investor_preferences;
CREATE POLICY investor_preferences_owner_insert ON public.investor_preferences
  FOR INSERT TO authenticated
  WITH CHECK (investor_id = public.investor_id_for_user(auth.uid()));
CREATE POLICY investor_preferences_owner_update ON public.investor_preferences
  FOR UPDATE TO authenticated
  USING (investor_id = public.investor_id_for_user(auth.uid()))
  WITH CHECK (investor_id = public.investor_id_for_user(auth.uid()));
CREATE POLICY investor_preferences_staff_write ON public.investor_preferences
  FOR ALL TO authenticated
  USING (
    public.has_permission('investors.write', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('investors.write', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

DROP POLICY IF EXISTS investor_notifications_write ON public.investor_notifications;
DROP POLICY IF EXISTS investor_notifications_portal_update ON public.investor_notifications;
CREATE POLICY investor_notifications_staff_write ON public.investor_notifications
  FOR ALL TO authenticated
  USING (
    public.has_permission('investors.communicate', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('investors.communicate', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

DROP POLICY IF EXISTS investor_referral_commissions_staff
  ON public.investor_referral_commissions;
CREATE POLICY investor_referral_commissions_staff_write
  ON public.investor_referral_commissions
  FOR ALL TO authenticated
  USING (
    public.has_permission('investors.referrals', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('investors.referrals', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

DROP POLICY IF EXISTS investor_payment_intents_staff
  ON public.investor_payment_intents;
CREATE POLICY investor_payment_intents_finance_write
  ON public.investor_payment_intents
  FOR ALL TO authenticated
  USING (
    public.has_permission('investors.payments', auth.uid())
    OR public.has_permission('finance.payments', auth.uid())
    OR public.has_permission('finance.approvals', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('investors.payments', auth.uid())
    OR public.has_permission('finance.payments', auth.uid())
    OR public.has_permission('finance.approvals', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

-- Audit history is append-only through SECURITY DEFINER command functions.
DROP POLICY IF EXISTS investor_activity_logs_write ON public.investor_activity_logs;
REVOKE INSERT, UPDATE, DELETE ON public.investor_activity_logs FROM authenticated;

CREATE OR REPLACE FUNCTION public.guard_investor_activity_immutable()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RAISE EXCEPTION 'investor_activity_is_immutable';
END;
$$;
DROP TRIGGER IF EXISTS trg_investor_activity_immutable
  ON public.investor_activity_logs;
CREATE TRIGGER trg_investor_activity_immutable
  BEFORE UPDATE OR DELETE ON public.investor_activity_logs
  FOR EACH ROW EXECUTE FUNCTION public.guard_investor_activity_immutable();

-- ---------------------------------------------------------------------------
-- Investor-relations conversations: owner insert/read, no forgery/deletion.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS investor_conversations_own
  ON public.investor_conversations;
CREATE POLICY investor_conversations_owner_select
  ON public.investor_conversations FOR SELECT TO authenticated
  USING (investor_id = public.investor_id_for_user(auth.uid()));
CREATE POLICY investor_conversations_owner_insert
  ON public.investor_conversations FOR INSERT TO authenticated
  WITH CHECK (
    investor_id = public.investor_id_for_user(auth.uid())
    AND assigned_staff_id IS NULL
    AND status = 'open'
    AND COALESCE(is_deleted, false) = false
  );
CREATE POLICY investor_conversations_owner_update
  ON public.investor_conversations FOR UPDATE TO authenticated
  USING (investor_id = public.investor_id_for_user(auth.uid()))
  WITH CHECK (investor_id = public.investor_id_for_user(auth.uid()));
CREATE POLICY investor_conversations_staff_all
  ON public.investor_conversations FOR ALL TO authenticated
  USING (
    public.has_permission('investors.communicate', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('investors.communicate', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

DROP POLICY IF EXISTS investor_messages_own
  ON public.investor_conversation_messages;
CREATE POLICY investor_messages_owner_select
  ON public.investor_conversation_messages FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.investor_conversations c
      WHERE c.id = conversation_id
        AND c.investor_id = public.investor_id_for_user(auth.uid())
    )
  );
CREATE POLICY investor_messages_owner_insert
  ON public.investor_conversation_messages FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND COALESCE(is_deleted, false) = false
    AND EXISTS (
      SELECT 1 FROM public.investor_conversations c
      WHERE c.id = conversation_id
        AND c.investor_id = public.investor_id_for_user(auth.uid())
        AND c.status = 'open'
        AND COALESCE(c.is_deleted, false) = false
    )
  );
CREATE POLICY investor_messages_owner_update
  ON public.investor_conversation_messages FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.investor_conversations c
      WHERE c.id = conversation_id
        AND c.investor_id = public.investor_id_for_user(auth.uid())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.investor_conversations c
      WHERE c.id = conversation_id
        AND c.investor_id = public.investor_id_for_user(auth.uid())
    )
  );
CREATE POLICY investor_messages_staff_all
  ON public.investor_conversation_messages FOR ALL TO authenticated
  USING (
    public.has_permission('investors.communicate', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('investors.communicate', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

CREATE OR REPLACE FUNCTION public.guard_investor_conversation_owner_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF public.has_permission('investors.communicate', auth.uid())
     OR public.has_role('super_admin', auth.uid()) THEN
    RETURN NEW;
  END IF;
  IF OLD.investor_id <> public.investor_id_for_user(auth.uid())
     OR NEW.investor_id IS DISTINCT FROM OLD.investor_id
     OR NEW.subject IS DISTINCT FROM OLD.subject
     OR NEW.category IS DISTINCT FROM OLD.category
     OR NEW.assigned_staff_id IS DISTINCT FROM OLD.assigned_staff_id
     OR NEW.status IS DISTINCT FROM OLD.status
     OR NEW.is_deleted IS DISTINCT FROM OLD.is_deleted
     OR NEW.created_at IS DISTINCT FROM OLD.created_at
     OR NEW.created_by IS DISTINCT FROM OLD.created_by THEN
    RAISE EXCEPTION 'investor_conversation_fields_are_immutable';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_investor_conversation_owner_update
  ON public.investor_conversations;
CREATE TRIGGER trg_investor_conversation_owner_update
  BEFORE UPDATE ON public.investor_conversations
  FOR EACH ROW EXECUTE FUNCTION public.guard_investor_conversation_owner_update();

CREATE OR REPLACE FUNCTION public.guard_investor_message_owner_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF public.has_permission('investors.communicate', auth.uid())
     OR public.has_role('super_admin', auth.uid()) THEN
    RETURN NEW;
  END IF;
  IF NEW.conversation_id IS DISTINCT FROM OLD.conversation_id
     OR NEW.sender_id IS DISTINCT FROM OLD.sender_id
     OR NEW.body IS DISTINCT FROM OLD.body
     OR NEW.attachments IS DISTINCT FROM OLD.attachments
     OR NEW.created_at IS DISTINCT FROM OLD.created_at
     OR NEW.created_by IS DISTINCT FROM OLD.created_by
     OR NEW.status IS DISTINCT FROM OLD.status
     OR NEW.is_deleted IS DISTINCT FROM OLD.is_deleted
     OR NEW.client_message_id IS DISTINCT FROM OLD.client_message_id
     OR NEW.investor_id IS DISTINCT FROM OLD.investor_id THEN
    RAISE EXCEPTION 'investor_message_fields_are_immutable';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_investor_message_owner_update
  ON public.investor_conversation_messages;
CREATE TRIGGER trg_investor_message_owner_update
  BEFORE UPDATE ON public.investor_conversation_messages
  FOR EACH ROW EXECUTE FUNCTION public.guard_investor_message_owner_update();

REVOKE DELETE ON public.investor_conversations FROM authenticated;
REVOKE DELETE ON public.investor_conversation_messages FROM authenticated;

-- ---------------------------------------------------------------------------
-- Financial and identity constraints. NOT VALID protects legacy rows while
-- enforcing every new write; reconciliation validates them in a later phase.
-- ---------------------------------------------------------------------------
ALTER TABLE public.investor_payment_intents
  DROP CONSTRAINT IF EXISTS investor_payment_intents_status_check;
ALTER TABLE public.investor_payment_intents
  ADD CONSTRAINT investor_payment_intents_status_check CHECK (
    status IN (
      'pending', 'submitted', 'awaiting_confirmation',
      'pending_verification', 'info_requested', 'confirmed',
      'rejected', 'failed', 'cancelled'
    )
  ) NOT VALID;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'investors_nonnegative_financials_check'
  ) THEN
    ALTER TABLE public.investors
      ADD CONSTRAINT investors_nonnegative_financials_check
      CHECK (COALESCE(aum, 0) >= 0 AND COALESCE(total_committed, 0) >= 0)
      NOT VALID;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'investment_commitments_integrity_check'
  ) THEN
    ALTER TABLE public.investment_commitments
      ADD CONSTRAINT investment_commitments_integrity_check
      CHECK (
        amount > 0
        AND currency ~ '^[A-Z]{3}$'
        AND (status = 'funded' OR funded_at IS NULL)
      ) NOT VALID;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'investment_distributions_integrity_check'
  ) THEN
    ALTER TABLE public.investment_distributions
      ADD CONSTRAINT investment_distributions_integrity_check
      CHECK (
        amount > 0
        AND currency ~ '^[A-Z]{3}$'
        AND (status = 'paid' OR paid_at IS NULL)
      ) NOT VALID;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'investor_payment_intents_amount_currency_check'
  ) THEN
    ALTER TABLE public.investor_payment_intents
      ADD CONSTRAINT investor_payment_intents_amount_currency_check
      CHECK (amount > 0 AND currency ~ '^[A-Z]{3}$') NOT VALID;
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_investor_payment_for_intent
  ON public.payments ((metadata->>'intent_id'))
  WHERE metadata ? 'intent_id' AND COALESCE(is_deleted, false) = false;

COMMIT;
