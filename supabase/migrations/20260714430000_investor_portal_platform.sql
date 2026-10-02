-- ============================================================================
-- HD HOMES — INVESTOR PORTAL (Volume 4)
-- Owner-scoped RLS, ensure_investor_record(), messaging, referral commissions,
-- realtime publication, and construction visibility.
-- ============================================================================

-- ── 1. Messaging + referral commissions ─────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.investor_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id UUID NOT NULL REFERENCES public.investors(id) ON DELETE CASCADE,
  subject TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'support',
  assigned_staff_id UUID REFERENCES public.profiles(id),
  last_message_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'open',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE IF NOT EXISTS public.investor_conversation_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES public.investor_conversations(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES auth.users(id),
  body TEXT NOT NULL,
  attachments JSONB NOT NULL DEFAULT '[]'::jsonb,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE IF NOT EXISTS public.investor_referral_commissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id UUID NOT NULL REFERENCES public.investors(id) ON DELETE CASCADE,
  referred_user_id UUID REFERENCES auth.users(id),
  referral_code TEXT,
  commission_amount NUMERIC(15,2) NOT NULL DEFAULT 0,
  currency TEXT NOT NULL DEFAULT 'NGN',
  paid_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'pending',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_investor_conversations_investor
  ON public.investor_conversations(investor_id, last_message_at DESC);
CREATE INDEX IF NOT EXISTS idx_investor_messages_conversation
  ON public.investor_conversation_messages(conversation_id, created_at);
CREATE INDEX IF NOT EXISTS idx_investor_referral_commissions_investor
  ON public.investor_referral_commissions(investor_id);

-- ── 2. Helper + ensure RPC ──────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.investor_id_for_user(uid UUID)
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
  SELECT id FROM public.investors
  WHERE user_id = uid AND COALESCE(is_deleted, false) = false
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.ensure_investor_record()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE
  uid uuid := auth.uid();
  row public.investors;
  code text;
  u_email text;
  u_name text;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  INSERT INTO public.profiles (id, email, account_status, status)
  SELECT
    u.id,
    COALESCE(u.email, u.id::text || '@users.local'),
    CASE
      WHEN u.email_confirmed_at IS NOT NULL THEN 'active'::public.account_status
      ELSE 'pending_verification'::public.account_status
    END,
    'active'
  FROM auth.users u
  WHERE u.id = uid
  ON CONFLICT (id) DO NOTHING;

  SELECT * INTO row
  FROM public.investors
  WHERE user_id = uid AND COALESCE(is_deleted, false) = false
  LIMIT 1;

  IF FOUND THEN
    INSERT INTO public.investor_portfolios (investor_id, name)
    VALUES (row.id, 'Primary Portfolio')
    ON CONFLICT (investor_id) DO NOTHING;

    INSERT INTO public.investor_wallets (investor_id)
    VALUES (row.id)
    ON CONFLICT (investor_id) DO NOTHING;

    RETURN to_jsonb(row);
  END IF;

  SELECT email,
         COALESCE(raw_user_meta_data->>'full_name', split_part(email, '@', 1))
    INTO u_email, u_name
  FROM auth.users WHERE id = uid;

  code := 'INV-' || upper(substring(replace(uid::text, '-', ''), 1, 8));

  INSERT INTO public.investors (
    user_id, investor_code, full_name, email, status, lifecycle_status, kyc_status
  )
  VALUES (
    uid, code, COALESCE(u_name, 'Investor'), u_email, 'active', 'active', 'pending'
  )
  ON CONFLICT (user_id) DO UPDATE
    SET updated_at = now(),
        is_deleted = false,
        status = 'active'
  RETURNING * INTO row;

  INSERT INTO public.investor_portfolios (investor_id, name)
  VALUES (row.id, 'Primary Portfolio')
  ON CONFLICT (investor_id) DO NOTHING;

  INSERT INTO public.investor_wallets (investor_id)
  VALUES (row.id)
  ON CONFLICT (investor_id) DO NOTHING;

  INSERT INTO public.investor_preferences (investor_id)
  VALUES (row.id)
  ON CONFLICT (investor_id) DO NOTHING;

  RETURN to_jsonb(row);
END;
$$;

REVOKE ALL ON FUNCTION public.ensure_investor_record() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ensure_investor_record() TO authenticated;
GRANT EXECUTE ON FUNCTION public.investor_id_for_user(uuid) TO authenticated;

-- ── 3. Owner-scoped RLS ─────────────────────────────────────────────────────

ALTER TABLE public.investor_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_conversation_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_referral_commissions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS investors_self_select ON public.investors;
CREATE POLICY investors_self_select ON public.investors
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.is_staff() OR public.has_permission('investors.read'));

DROP POLICY IF EXISTS investors_self_update ON public.investors;
CREATE POLICY investors_self_update ON public.investors
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid() OR public.is_staff())
  WITH CHECK (user_id = auth.uid() OR public.is_staff());

-- Generic owner policies for IMP child tables
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'investor_portfolios','portfolio_holdings','investment_distributions',
    'investor_wallets','investor_documents','investor_reports','investor_statements',
    'investment_performance','investor_notifications','investor_activity_logs',
    'investor_preferences','investor_profiles','investor_relationships',
    'investment_commitments','investor_alerts'
  ]
  LOOP
    IF EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema='public' AND table_name=t
    ) THEN
      EXECUTE format('DROP POLICY IF EXISTS %I_portal_owner ON public.%I', t, t);
      IF t = 'portfolio_holdings' THEN
        EXECUTE format($p$
          CREATE POLICY %I_portal_owner ON public.%I
          FOR SELECT TO authenticated
          USING (
            public.is_staff()
            OR EXISTS (
              SELECT 1 FROM public.investor_portfolios ip
              WHERE ip.id = portfolio_id
                AND ip.investor_id = public.investor_id_for_user(auth.uid())
            )
          )
        $p$, t, t);
      ELSE
        EXECUTE format($p$
          CREATE POLICY %I_portal_owner ON public.%I
          FOR SELECT TO authenticated
          USING (
            investor_id = public.investor_id_for_user(auth.uid())
            OR public.is_staff()
          )
        $p$, t, t);
      END IF;
    END IF;
  END LOOP;
END $$;

-- Preferences update for owner
DROP POLICY IF EXISTS investor_preferences_portal_write ON public.investor_preferences;
CREATE POLICY investor_preferences_portal_write ON public.investor_preferences
  FOR ALL TO authenticated
  USING (investor_id = public.investor_id_for_user(auth.uid()) OR public.is_staff())
  WITH CHECK (investor_id = public.investor_id_for_user(auth.uid()) OR public.is_staff());

DROP POLICY IF EXISTS investor_notifications_portal_update ON public.investor_notifications;
CREATE POLICY investor_notifications_portal_update ON public.investor_notifications
  FOR UPDATE TO authenticated
  USING (investor_id = public.investor_id_for_user(auth.uid()) OR public.is_staff())
  WITH CHECK (investor_id = public.investor_id_for_user(auth.uid()) OR public.is_staff());

DROP POLICY IF EXISTS investor_conversations_own ON public.investor_conversations;
CREATE POLICY investor_conversations_own ON public.investor_conversations
  FOR ALL TO authenticated
  USING (investor_id = public.investor_id_for_user(auth.uid()) OR public.is_staff())
  WITH CHECK (investor_id = public.investor_id_for_user(auth.uid()) OR public.is_staff());

DROP POLICY IF EXISTS investor_messages_own ON public.investor_conversation_messages;
CREATE POLICY investor_messages_own ON public.investor_conversation_messages
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.investor_conversations c
      WHERE c.id = conversation_id
        AND (c.investor_id = public.investor_id_for_user(auth.uid()) OR public.is_staff())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.investor_conversations c
      WHERE c.id = conversation_id
        AND (c.investor_id = public.investor_id_for_user(auth.uid()) OR public.is_staff())
    )
  );

DROP POLICY IF EXISTS investor_referral_commissions_own ON public.investor_referral_commissions;
CREATE POLICY investor_referral_commissions_own ON public.investor_referral_commissions
  FOR SELECT TO authenticated
  USING (investor_id = public.investor_id_for_user(auth.uid()) OR public.is_staff());

GRANT SELECT, INSERT, UPDATE, DELETE ON public.investor_conversations TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.investor_conversation_messages TO authenticated;
GRANT SELECT ON public.investor_referral_commissions TO authenticated;

ALTER PUBLICATION supabase_realtime ADD TABLE public.investor_conversation_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.investor_notifications;

-- Construction updates readable when linked via holding property
DROP POLICY IF EXISTS construction_updates_investor_read ON public.construction_updates;
CREATE POLICY construction_updates_investor_read ON public.construction_updates
  FOR SELECT TO authenticated
  USING (
    public.is_staff()
    OR EXISTS (
      SELECT 1
      FROM public.projects p
      JOIN public.portfolio_holdings h ON h.property_id = p.property_id
      JOIN public.investor_portfolios ip ON ip.id = h.portfolio_id
      WHERE p.id = construction_updates.project_id
        AND ip.investor_id = public.investor_id_for_user(auth.uid())
    )
  );

-- Production migrations do not create investors or financial activity.
-- Local/test fixtures belong in Supabase seed files and must carry an
-- explicit fixture identifier and environment marker.
