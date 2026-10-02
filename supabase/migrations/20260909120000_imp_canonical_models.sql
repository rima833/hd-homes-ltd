-- Canonical operational opportunity, KYC evidence, and append-only ledger.

BEGIN;

DELETE FROM public.investment_transactions
WHERE COALESCE(metadata->>'demo', 'false') = 'true';

-- Website opportunities are presentations of one operational opportunity.
ALTER TABLE public.website_investment_opportunities
  ADD COLUMN IF NOT EXISTS operational_opportunity_id uuid
    REFERENCES public.investment_opportunities(id) ON DELETE SET NULL;

CREATE UNIQUE INDEX IF NOT EXISTS
  uq_website_investment_operational_opportunity
  ON public.website_investment_opportunities(operational_opportunity_id)
  WHERE operational_opportunity_id IS NOT NULL
    AND COALESCE(is_deleted, false) = false;

CREATE OR REPLACE FUNCTION public.sync_operational_opportunity_to_website()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.website_investment_opportunities w
  SET target_amount = NEW.currency || ' '
        || trim(to_char(NEW.target_raise, 'FM999G999G999G999G990D00')),
      amount_raised = NEW.currency || ' '
        || trim(to_char(NEW.amount_raised, 'FM999G999G999G999G990D00')),
      progress_pct = CASE
        WHEN NEW.target_raise <= 0 THEN 0
        ELSE least(100, round(NEW.amount_raised / NEW.target_raise * 100, 2))
      END,
      opportunity_status = NEW.status,
      roi_min = COALESCE(NEW.projected_return_pct, w.roi_min),
      roi_max = COALESCE(NEW.projected_return_pct, w.roi_max),
      risk_level = initcap(NEW.risk_level),
      opening_date = NEW.open_at::date,
      closing_date = NEW.close_at::date,
      updated_at = now(),
      updated_by = auth.uid()
  WHERE w.operational_opportunity_id = NEW.id
    AND COALESCE(w.is_deleted, false) = false;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_operational_opportunity_to_website
  ON public.investment_opportunities;
CREATE TRIGGER trg_sync_operational_opportunity_to_website
  AFTER INSERT OR UPDATE OF
    target_raise, amount_raised, status, projected_return_pct,
    risk_level, open_at, close_at
  ON public.investment_opportunities
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_operational_opportunity_to_website();

CREATE OR REPLACE FUNCTION public.admin_link_website_investment_opportunity(
  p_operational_opportunity_id uuid,
  p_website_opportunity_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT (
    public.has_permission('investors.opportunities', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.investment_opportunities
    WHERE id = p_operational_opportunity_id
  ) THEN
    RAISE EXCEPTION 'opportunity_not_found';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.website_investment_opportunities
    WHERE id = p_website_opportunity_id
      AND COALESCE(is_deleted, false) = false
  ) THEN
    RAISE EXCEPTION 'website_opportunity_not_found';
  END IF;

  UPDATE public.website_investment_opportunities
  SET operational_opportunity_id = NULL, updated_at = now()
  WHERE operational_opportunity_id = p_operational_opportunity_id
    AND id <> p_website_opportunity_id;

  UPDATE public.website_investment_opportunities
  SET operational_opportunity_id = p_operational_opportunity_id,
      updated_at = now(),
      updated_by = auth.uid()
  WHERE id = p_website_opportunity_id;

  UPDATE public.investment_opportunities
  SET amount_raised = amount_raised
  WHERE id = p_operational_opportunity_id;

  RETURN jsonb_build_object(
    'operational_opportunity_id', p_operational_opportunity_id,
    'website_opportunity_id', p_website_opportunity_id
  );
END;
$$;

-- KYC evidence links immutable documents to review decisions.
CREATE TABLE IF NOT EXISTS public.investor_kyc_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL
    REFERENCES public.investors(id) ON DELETE CASCADE,
  document_id uuid NOT NULL
    REFERENCES public.investor_documents(id) ON DELETE RESTRICT,
  review_id uuid
    REFERENCES public.investor_kyc_reviews(id) ON DELETE SET NULL,
  document_type text NOT NULL,
  verification_status text NOT NULL DEFAULT 'pending'
    CHECK (verification_status IN (
      'pending', 'accepted', 'rejected', 'expired', 'superseded'
    )),
  rejection_reason text,
  expires_at timestamptz,
  verified_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  verified_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(investor_id, document_id)
);

CREATE INDEX IF NOT EXISTS idx_investor_kyc_documents_queue
  ON public.investor_kyc_documents(
    verification_status, created_at, investor_id
  );
ALTER TABLE public.investor_kyc_documents ENABLE ROW LEVEL SECURITY;
CREATE POLICY investor_kyc_documents_owner_select
  ON public.investor_kyc_documents FOR SELECT TO authenticated
  USING (investor_id = public.investor_id_for_user(auth.uid()));
CREATE POLICY investor_kyc_documents_staff_select
  ON public.investor_kyc_documents FOR SELECT TO authenticated
  USING (
    public.has_permission('investors.kyc', auth.uid())
    OR public.has_permission('investors.documents', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY investor_kyc_documents_staff_write
  ON public.investor_kyc_documents FOR ALL TO authenticated
  USING (
    public.has_permission('investors.kyc', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('investors.kyc', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
GRANT SELECT, INSERT, UPDATE ON public.investor_kyc_documents
  TO authenticated;

-- Canonical append-only investor ledger.
ALTER TABLE public.investment_transactions
  ADD COLUMN IF NOT EXISTS source_type text,
  ADD COLUMN IF NOT EXISTS source_id uuid,
  ADD COLUMN IF NOT EXISTS idempotency_key text,
  ADD COLUMN IF NOT EXISTS posted_at timestamptz,
  ADD COLUMN IF NOT EXISTS reverses_entry_id uuid
    REFERENCES public.investment_transactions(id) ON DELETE RESTRICT;

UPDATE public.investment_transactions
SET posted_at = COALESCE(posted_at, transaction_date),
    direction = CASE
      WHEN direction IN ('in', 'out') THEN direction
      WHEN amount < 0 THEN 'out'
      ELSE 'in'
    END,
    amount = abs(amount)
WHERE posted_at IS NULL OR direction NOT IN ('in', 'out') OR amount < 0;

ALTER TABLE public.investment_transactions
  ALTER COLUMN investor_id SET NOT NULL,
  ALTER COLUMN direction SET NOT NULL,
  ALTER COLUMN posted_at SET DEFAULT now(),
  ALTER COLUMN posted_at SET NOT NULL;

ALTER TABLE public.investment_transactions
  DROP CONSTRAINT IF EXISTS investment_transactions_canonical_check;
ALTER TABLE public.investment_transactions
  ADD CONSTRAINT investment_transactions_canonical_check CHECK (
    amount > 0
    AND currency ~ '^[A-Z]{3}$'
    AND direction IN ('in', 'out')
    AND status IN ('pending', 'posted', 'active', 'reversed', 'void')
    AND (
      (status = 'reversed' AND reverses_entry_id IS NOT NULL)
      OR status <> 'reversed'
    )
  ) NOT VALID;

CREATE UNIQUE INDEX IF NOT EXISTS uq_investment_transactions_idempotency
  ON public.investment_transactions(idempotency_key)
  WHERE idempotency_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_investment_transactions_investor_posted
  ON public.investment_transactions(investor_id, posted_at DESC);
CREATE INDEX IF NOT EXISTS idx_investment_transactions_source
  ON public.investment_transactions(source_type, source_id)
  WHERE source_type IS NOT NULL AND source_id IS NOT NULL;

ALTER TABLE public.investment_transactions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS investment_transactions_select
  ON public.investment_transactions;
DROP POLICY IF EXISTS investment_transactions_write
  ON public.investment_transactions;
CREATE POLICY investment_transactions_owner_select
  ON public.investment_transactions FOR SELECT TO authenticated
  USING (investor_id = public.investor_id_for_user(auth.uid()));
CREATE POLICY investment_transactions_staff_select
  ON public.investment_transactions FOR SELECT TO authenticated
  USING (
    public.has_permission('investors.payments', auth.uid())
    OR public.has_permission('investors.portfolio', auth.uid())
    OR public.has_permission('investors.distributions', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
REVOKE INSERT, UPDATE, DELETE ON public.investment_transactions
  FROM authenticated;

CREATE OR REPLACE FUNCTION public.guard_investment_transaction_immutable()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RAISE EXCEPTION 'investment_ledger_is_append_only';
END;
$$;
DROP TRIGGER IF EXISTS trg_investment_transaction_immutable
  ON public.investment_transactions;
CREATE TRIGGER trg_investment_transaction_immutable
  BEFORE UPDATE OR DELETE ON public.investment_transactions
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_investment_transaction_immutable();

CREATE OR REPLACE FUNCTION public.admin_post_investor_ledger_entry(
  p_investor_id uuid,
  p_transaction_type text,
  p_amount numeric,
  p_currency text,
  p_direction text,
  p_idempotency_key text,
  p_source_type text DEFAULT NULL,
  p_source_id uuid DEFAULT NULL,
  p_portfolio_id uuid DEFAULT NULL,
  p_opportunity_id uuid DEFAULT NULL,
  p_description text DEFAULT NULL,
  p_reference text DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.investment_transactions%ROWTYPE;
  v_key text := NULLIF(trim(COALESCE(p_idempotency_key, '')), '');
  v_currency text := upper(trim(COALESCE(p_currency, '')));
  v_direction text := lower(trim(COALESCE(p_direction, '')));
  v_type text := lower(trim(COALESCE(p_transaction_type, '')));
BEGIN
  IF NOT (
    public.has_permission('investors.payments', auth.uid())
    OR public.has_permission('investors.portfolio', auth.uid())
    OR public.has_permission('investors.distributions', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;
  IF v_key IS NULL THEN RAISE EXCEPTION 'idempotency_key_required'; END IF;

  SELECT * INTO v_row
  FROM public.investment_transactions
  WHERE idempotency_key = v_key;
  IF FOUND THEN
    RETURN jsonb_build_object(
      'id', v_row.id, 'status', v_row.status, 'idempotent', true
    );
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'invalid_amount';
  END IF;
  IF v_currency !~ '^[A-Z]{3}$' THEN RAISE EXCEPTION 'invalid_currency'; END IF;
  IF v_direction NOT IN ('in', 'out') THEN
    RAISE EXCEPTION 'invalid_direction';
  END IF;
  IF v_type NOT IN (
    'deposit', 'commitment_funding', 'distribution', 'fee',
    'refund', 'adjustment', 'withdrawal'
  ) THEN
    RAISE EXCEPTION 'invalid_transaction_type';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.investors
    WHERE id = p_investor_id AND COALESCE(is_deleted, false) = false
  ) THEN
    RAISE EXCEPTION 'investor_not_found';
  END IF;

  INSERT INTO public.investment_transactions (
    investor_id, portfolio_id, opportunity_id, transaction_type,
    amount, investment_amount, currency, direction, status,
    transaction_date, posted_at, reference, description, source_type,
    source_id, idempotency_key, metadata, created_by, updated_by
  ) VALUES (
    p_investor_id, p_portfolio_id, p_opportunity_id, v_type,
    round(p_amount, 2), round(p_amount, 2), v_currency, v_direction,
    'posted', now(), now(), NULLIF(trim(COALESCE(p_reference, '')), ''),
    NULLIF(trim(COALESCE(p_description, '')), ''),
    NULLIF(trim(COALESCE(p_source_type, '')), ''), p_source_id, v_key,
    COALESCE(p_metadata, '{}'::jsonb), auth.uid(), auth.uid()
  )
  RETURNING * INTO v_row;

  INSERT INTO public.investor_activity_logs (
    investor_id, event_type, title, description, payload, actor_id, occurred_at
  ) VALUES (
    p_investor_id, 'ledger_entry_posted',
    'Investor ledger entry posted', v_type,
    jsonb_build_object(
      'ledger_entry_id', v_row.id, 'amount', v_row.amount,
      'currency', v_row.currency, 'direction', v_row.direction,
      'source_type', v_row.source_type, 'source_id', v_row.source_id
    ),
    auth.uid(), now()
  );

  RETURN jsonb_build_object(
    'id', v_row.id, 'status', v_row.status, 'idempotent', false
  );
END;
$$;

CREATE OR REPLACE VIEW public.investor_account_balances
WITH (security_invoker = true)
AS
SELECT investor_id, currency,
  COALESCE(sum(
    CASE
      WHEN status IN ('posted', 'active') AND direction = 'in' THEN amount
      WHEN status IN ('posted', 'active') AND direction = 'out' THEN -amount
      ELSE 0
    END
  ), 0) AS balance,
  max(posted_at) AS last_posted_at
FROM public.investment_transactions
GROUP BY investor_id, currency;

GRANT SELECT ON public.investor_account_balances TO authenticated;
REVOKE ALL ON FUNCTION public.admin_link_website_investment_opportunity(
  uuid, uuid
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_post_investor_ledger_entry(
  uuid, text, numeric, text, text, text, text, uuid, uuid, uuid,
  text, text, jsonb
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_link_website_investment_opportunity(
  uuid, uuid
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_post_investor_ledger_entry(
  uuid, text, numeric, text, text, text, text, uuid, uuid, uuid,
  text, text, jsonb
) TO authenticated;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public'
      AND tablename = 'investor_kyc_documents'
  ) THEN
    ALTER PUBLICATION supabase_realtime
      ADD TABLE public.investor_kyc_documents;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public'
      AND tablename = 'investment_transactions'
  ) THEN
    ALTER PUBLICATION supabase_realtime
      ADD TABLE public.investment_transactions;
  END IF;
END $$;

COMMIT;
