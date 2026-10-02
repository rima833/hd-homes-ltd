-- Client portal: property applications + support realtime hardening
BEGIN;

-- ---------------------------------------------------------------------------
-- Property applications (client purchase workflow)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.client_property_applications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  property_id uuid NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  payment_plan text,
  amount_offered numeric(15,2),
  notes text,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN (
      'draft',
      'submitted',
      'under_review',
      'approved',
      'payment_pending',
      'completed',
      'rejected',
      'cancelled'
    )),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES auth.users(id),
  updated_by uuid REFERENCES auth.users(id),
  is_deleted boolean NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_client_property_applications_client
  ON public.client_property_applications (client_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_client_property_applications_property
  ON public.client_property_applications (property_id, created_at DESC);

ALTER TABLE public.client_property_applications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS client_property_applications_select_own ON public.client_property_applications;
CREATE POLICY client_property_applications_select_own ON public.client_property_applications
  FOR SELECT USING (
    client_id = public.client_id_for_user(auth.uid())
    OR public.is_staff()
  );

DROP POLICY IF EXISTS client_property_applications_insert_own ON public.client_property_applications;
CREATE POLICY client_property_applications_insert_own ON public.client_property_applications
  FOR INSERT WITH CHECK (
    client_id = public.client_id_for_user(auth.uid())
    OR public.is_staff()
  );

DROP POLICY IF EXISTS client_property_applications_update_own_limited ON public.client_property_applications;
CREATE POLICY client_property_applications_update_own_limited ON public.client_property_applications
  FOR UPDATE USING (
    client_id = public.client_id_for_user(auth.uid())
    OR public.is_staff()
  )
  WITH CHECK (
    client_id = public.client_id_for_user(auth.uid())
    OR public.is_staff()
  );

-- ---------------------------------------------------------------------------
-- Support replies: ensure realtime publication for ticket_messages
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.client_property_applications;
  EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.ticket_messages;
  EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

COMMIT;
