-- ============================================================================
-- HD HOMES — CLIENT PORTAL (Volume 3)
-- Production schema for the complete client portal. Connects owned properties,
-- timeline, messaging, referrals, and payment intents to existing domain tables.
-- STATUS: APPLIED remotely 2026-07-22 (client_portal_p1_schema / p2_rls / p3_seeds)
-- ============================================================================

-- ── 1. Core portal tables ───────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.client_properties (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  purchase_date DATE,
  purchase_price NUMERIC(15,2),
  currency TEXT NOT NULL DEFAULT 'NGN',
  payment_progress_pct NUMERIC(5,2) NOT NULL DEFAULT 0,
  construction_progress_pct NUMERIC(5,2) NOT NULL DEFAULT 0,
  allocation_status TEXT NOT NULL DEFAULT 'pending',
  relationship_manager_id UUID REFERENCES public.profiles(id),
  brochure_url TEXT,
  notes TEXT,
  hub_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  UNIQUE (client_id, property_id)
);

CREATE TABLE IF NOT EXISTS public.client_timeline (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT,
  property_id UUID REFERENCES public.properties(id),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE IF NOT EXISTS public.client_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
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

CREATE TABLE IF NOT EXISTS public.client_conversation_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES public.client_conversations(id) ON DELETE CASCADE,
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

CREATE TABLE IF NOT EXISTS public.client_payment_intents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  property_id UUID REFERENCES public.properties(id),
  installment_id UUID REFERENCES public.installments(id),
  amount NUMERIC(15,2) NOT NULL,
  currency TEXT NOT NULL DEFAULT 'NGN',
  provider TEXT NOT NULL DEFAULT 'paystack',
  provider_reference TEXT,
  bank_reference TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  paid_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'pending',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE IF NOT EXISTS public.client_referral_commissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
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

CREATE INDEX IF NOT EXISTS idx_client_properties_client ON public.client_properties(client_id);
CREATE INDEX IF NOT EXISTS idx_client_timeline_client ON public.client_timeline(client_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_client_conversations_client ON public.client_conversations(client_id, last_message_at DESC);
CREATE INDEX IF NOT EXISTS idx_client_messages_conversation ON public.client_conversation_messages(conversation_id, created_at);
CREATE INDEX IF NOT EXISTS idx_client_payment_intents_client ON public.client_payment_intents(client_id, created_at DESC);

-- ── 2. Client-scoped RLS on existing tables ───────────────────────────────

ALTER TABLE public.client_properties ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.client_timeline ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.client_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.client_conversation_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.client_payment_intents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.client_referral_commissions ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.client_id_for_user(uid UUID)
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id FROM public.clients WHERE user_id = uid AND is_deleted = false LIMIT 1;
$$;

DROP POLICY IF EXISTS clients_self_insert ON public.clients;
CREATE POLICY clients_self_insert ON public.clients
  FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS client_properties_own ON public.client_properties;
CREATE POLICY client_properties_own ON public.client_properties
  FOR ALL USING (
    client_id = public.client_id_for_user(auth.uid())
    OR public.is_staff()
  );

DROP POLICY IF EXISTS client_timeline_own ON public.client_timeline;
CREATE POLICY client_timeline_own ON public.client_timeline
  FOR SELECT USING (
    client_id = public.client_id_for_user(auth.uid())
    OR public.is_staff()
  );

DROP POLICY IF EXISTS client_conversations_own ON public.client_conversations;
CREATE POLICY client_conversations_own ON public.client_conversations
  FOR ALL USING (
    client_id = public.client_id_for_user(auth.uid())
    OR public.is_staff()
  );

DROP POLICY IF EXISTS client_messages_own ON public.client_conversation_messages;
CREATE POLICY client_messages_own ON public.client_conversation_messages
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.client_conversations cc
      WHERE cc.id = conversation_id
        AND (cc.client_id = public.client_id_for_user(auth.uid()) OR public.is_staff())
    )
  );

DROP POLICY IF EXISTS client_payment_intents_own ON public.client_payment_intents;
CREATE POLICY client_payment_intents_own ON public.client_payment_intents
  FOR ALL USING (
    client_id = public.client_id_for_user(auth.uid())
    OR public.has_permission('manage_payments')
  );

DROP POLICY IF EXISTS client_referral_commissions_own ON public.client_referral_commissions;
CREATE POLICY client_referral_commissions_own ON public.client_referral_commissions
  FOR ALL USING (
    client_id = public.client_id_for_user(auth.uid())
    OR public.is_staff()
  );

-- Client INSERT on tickets (support)
DROP POLICY IF EXISTS tickets_client_insert ON public.tickets;
CREATE POLICY tickets_client_insert ON public.tickets
  FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS tickets_client_update ON public.tickets;
CREATE POLICY tickets_client_update ON public.tickets
  FOR UPDATE USING (user_id = auth.uid());

-- Client read projects linked to owned properties
DROP POLICY IF EXISTS projects_client_read ON public.projects;
CREATE POLICY projects_client_read ON public.projects
  FOR SELECT USING (
    public.is_staff()
    OR EXISTS (
      SELECT 1 FROM public.client_properties cp
      JOIN public.clients c ON c.id = cp.client_id
      WHERE cp.property_id = projects.property_id
        AND c.user_id = auth.uid()
        AND cp.is_deleted = false
    )
  );

-- Client write own documents
DROP POLICY IF EXISTS client_documents_client_insert ON public.client_documents;
CREATE POLICY client_documents_client_insert ON public.client_documents
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.clients c
      WHERE c.id = client_id AND c.user_id = auth.uid()
    )
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON public.client_properties TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.client_timeline TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.client_conversations TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.client_conversation_messages TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.client_payment_intents TO authenticated;
GRANT SELECT ON public.client_referral_commissions TO authenticated;
GRANT INSERT ON public.client_referral_commissions TO authenticated;

ALTER PUBLICATION supabase_realtime ADD TABLE public.client_conversation_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.client_timeline;

-- ── 3. Demo seeds (portal demo client — link user_id after registration) ────

INSERT INTO public.clients (id, client_code, status)
VALUES ('f2600001-0000-4000-8000-000000000001', 'CLT-DEMO-001', 'active')
ON CONFLICT (client_code) DO NOTHING;

INSERT INTO public.client_properties (
  id, client_id, property_id, purchase_date, purchase_price,
  payment_progress_pct, construction_progress_pct, allocation_status, status
)
SELECT
  'f2600002-0000-4000-8000-000000000001',
  'f2600001-0000-4000-8000-000000000001',
  p.id,
  CURRENT_DATE - 180,
  45000000,
  65,
  42,
  'allocated',
  'active'
FROM public.properties p
WHERE p.is_deleted = false AND p.is_published = true
ORDER BY p.created_at
LIMIT 1
ON CONFLICT (client_id, property_id) DO NOTHING;

INSERT INTO public.client_timeline (id, client_id, event_type, title, body, occurred_at) VALUES
  ('f2600003-0000-4000-8000-000000000001', 'f2600001-0000-4000-8000-000000000001', 'payment', 'Installment received', '₦2,500,000 payment confirmed.', now() - interval '3 days'),
  ('f2600003-0000-4000-8000-000000000002', 'f2600001-0000-4000-8000-000000000001', 'construction', 'Foundation complete', 'Site engineer signed off foundation works.', now() - interval '7 days'),
  ('f2600003-0000-4000-8000-000000000003', 'f2600001-0000-4000-8000-000000000001', 'document', 'Allocation letter issued', 'Your allocation letter is ready for download.', now() - interval '14 days')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.installments (id, client_id, property_id, amount, due_date, status, paid_at)
SELECT
  'f2600004-0000-4000-8000-000000000001',
  'f2600001-0000-4000-8000-000000000001',
  cp.property_id,
  2500000,
  CURRENT_DATE + 30,
  'pending',
  NULL
FROM public.client_properties cp
WHERE cp.id = 'f2600002-0000-4000-8000-000000000001'
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.payments (id, client_id, property_id, amount, currency, payment_method, payment_provider, paid_at, status)
SELECT
  'f2600005-0000-4000-8000-000000000001',
  'f2600001-0000-4000-8000-000000000001',
  cp.property_id,
  2500000,
  'NGN',
  'bank_transfer',
  'paystack',
  now() - interval '3 days',
  'completed'
FROM public.client_properties cp
WHERE cp.id = 'f2600002-0000-4000-8000-000000000001'
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.client_documents (id, client_id, title, file_url, document_type, status) VALUES
  ('f2600006-0000-4000-8000-000000000001', 'f2600001-0000-4000-8000-000000000001', 'Allocation Letter', 'https://hdhomes.ng/docs/allocation-sample.pdf', 'allocation', 'active'),
  ('f2600006-0000-4000-8000-000000000002', 'f2600001-0000-4000-8000-000000000001', 'Purchase Agreement', 'https://hdhomes.ng/docs/agreement-sample.pdf', 'contract', 'active')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.client_referral_commissions (id, client_id, referral_code, commission_amount, status) VALUES
  ('f2600007-0000-4000-8000-000000000001', 'f2600001-0000-4000-8000-000000000001', 'HDHOMES-CLT-DEMO', 150000, 'pending')
ON CONFLICT (id) DO NOTHING;
