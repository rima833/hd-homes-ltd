-- Client applications workflow: statuses, docs link, plans catalog, RLS
-- Applied remotely via Supabase MCP as client_applications_workflow_hardening.
-- This file keeps the repo in sync for local/CLI workflows.

BEGIN;

WITH ranked AS (
  SELECT id,
    row_number() OVER (
      PARTITION BY client_id, property_id
      ORDER BY created_at DESC, id DESC
    ) AS rn
  FROM public.client_property_applications
  WHERE is_deleted = false
    AND status = ANY (ARRAY[
      'draft','submitted','under_review','documents_required',
      'approved','payment_pending','payment_active','contract_pending'
    ])
)
UPDATE public.client_property_applications cpa
SET is_deleted = true, updated_at = now()
FROM ranked r
WHERE cpa.id = r.id AND r.rn > 1;

ALTER TABLE public.client_property_applications
  DROP CONSTRAINT IF EXISTS client_property_applications_status_check;

ALTER TABLE public.client_property_applications
  ADD CONSTRAINT client_property_applications_status_check
  CHECK (status = ANY (ARRAY[
    'draft'::text, 'submitted'::text, 'under_review'::text, 'documents_required'::text,
    'approved'::text, 'payment_pending'::text, 'payment_active'::text, 'contract_pending'::text,
    'completed'::text, 'rejected'::text, 'cancelled'::text
  ]));

ALTER TABLE public.client_documents
  ADD COLUMN IF NOT EXISTS application_id uuid REFERENCES public.client_property_applications(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS property_id uuid REFERENCES public.properties(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS review_status text NOT NULL DEFAULT 'uploaded',
  ADD COLUMN IF NOT EXISTS file_name text,
  ADD COLUMN IF NOT EXISTS is_client_visible boolean NOT NULL DEFAULT true;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'client_documents_review_status_check'
  ) THEN
    ALTER TABLE public.client_documents
      ADD CONSTRAINT client_documents_review_status_check
      CHECK (review_status = ANY (ARRAY[
        'required'::text, 'uploaded'::text, 'under_review'::text,
        'approved'::text, 'rejected'::text, 'expired'::text
      ]));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_client_documents_application_id
  ON public.client_documents(application_id) WHERE is_deleted = false;

CREATE UNIQUE INDEX IF NOT EXISTS uq_client_property_applications_active
  ON public.client_property_applications(client_id, property_id)
  WHERE is_deleted = false
    AND status = ANY (ARRAY[
      'draft','submitted','under_review','documents_required',
      'approved','payment_pending','payment_active','contract_pending'
    ]);

CREATE TABLE IF NOT EXISTS public.application_payment_plan_catalog (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  description text,
  installment_months integer,
  initial_deposit_percent numeric(5,2),
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.application_payment_plan_catalog
  (code, name, description, installment_months, initial_deposit_percent, sort_order)
VALUES
  ('outright', 'Outright purchase', 'Full payment', 0, 100, 1),
  ('3_months', '3 months', 'Pay over 3 months', 3, 30, 2),
  ('6_months', '6 months', 'Pay over 6 months', 6, 20, 3),
  ('12_months', '12 months', 'Pay over 12 months', 12, 15, 4),
  ('18_months', '18 months', 'Pay over 18 months', 18, 10, 5)
ON CONFLICT (code) DO NOTHING;

ALTER TABLE public.application_payment_plan_catalog ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS application_payment_plan_catalog_select ON public.application_payment_plan_catalog;
CREATE POLICY application_payment_plan_catalog_select
  ON public.application_payment_plan_catalog FOR SELECT TO authenticated USING (is_active = true);

DROP POLICY IF EXISTS application_payment_plan_catalog_staff ON public.application_payment_plan_catalog;
CREATE POLICY application_payment_plan_catalog_staff
  ON public.application_payment_plan_catalog FOR ALL TO authenticated
  USING (public.is_staff()) WITH CHECK (public.is_staff());

CREATE TABLE IF NOT EXISTS public.application_required_document_types (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  description text,
  is_required boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.application_required_document_types (code, name, description, is_required, sort_order)
VALUES
  ('valid_id', 'Valid ID', 'Government-issued photo ID', true, 1),
  ('proof_of_address', 'Proof of address', 'Utility bill or bank statement', true, 2),
  ('passport_photo', 'Passport photograph', 'Recent passport-sized photo', true, 3),
  ('supporting', 'Supporting document', 'Optional supporting document', false, 4)
ON CONFLICT (code) DO NOTHING;

ALTER TABLE public.application_required_document_types ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS application_required_document_types_select ON public.application_required_document_types;
CREATE POLICY application_required_document_types_select
  ON public.application_required_document_types FOR SELECT TO authenticated USING (is_active = true);

DROP POLICY IF EXISTS application_required_document_types_staff ON public.application_required_document_types;
CREATE POLICY application_required_document_types_staff
  ON public.application_required_document_types FOR ALL TO authenticated
  USING (public.is_staff()) WITH CHECK (public.is_staff());

DROP POLICY IF EXISTS client_property_applications_update_own_limited ON public.client_property_applications;
DROP POLICY IF EXISTS client_property_applications_client_update ON public.client_property_applications;
DROP POLICY IF EXISTS client_property_applications_staff_update ON public.client_property_applications;

CREATE POLICY client_property_applications_client_update
  ON public.client_property_applications FOR UPDATE TO authenticated
  USING (client_id = public.client_id_for_user(auth.uid()))
  WITH CHECK (
    client_id = public.client_id_for_user(auth.uid())
    AND status = ANY (ARRAY['draft'::text, 'submitted'::text, 'cancelled'::text])
  );

CREATE POLICY client_property_applications_staff_update
  ON public.client_property_applications FOR UPDATE TO authenticated
  USING (public.is_staff()) WITH CHECK (public.is_staff());

CREATE OR REPLACE FUNCTION public.enforce_client_application_status_transition()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF public.is_staff() THEN RETURN NEW; END IF;
  IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
    IF NEW.status = 'cancelled' THEN RETURN NEW; END IF;
    IF OLD.status = 'draft' AND NEW.status IN ('draft', 'submitted') THEN RETURN NEW; END IF;
    IF OLD.status = NEW.status THEN RETURN NEW; END IF;
    RAISE EXCEPTION 'Clients cannot set application status to %', NEW.status USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_client_application_status_transition ON public.client_property_applications;
CREATE TRIGGER trg_enforce_client_application_status_transition
  BEFORE UPDATE ON public.client_property_applications
  FOR EACH ROW EXECUTE FUNCTION public.enforce_client_application_status_transition();

-- Lifecycle emitter updated in remote migration; keep body in sync via remote apply.

COMMIT;
