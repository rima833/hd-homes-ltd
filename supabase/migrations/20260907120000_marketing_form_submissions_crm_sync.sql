-- Bridge marketing form_submissions → CRM (reuse upsert_crm_public_lead).
-- Applied remotely via MCP; kept in repo for environments.

ALTER TABLE public.form_submissions
  ADD COLUMN IF NOT EXISTS crm_lead_id uuid REFERENCES public.crm_leads(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS crm_synced_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_form_submissions_crm_lead
  ON public.form_submissions (crm_lead_id)
  WHERE crm_lead_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.sync_marketing_form_submission_to_crm()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_name text;
  v_phone text;
  v_email text;
  v_interest text;
  v_result jsonb;
BEGIN
  IF NEW.crm_lead_id IS NOT NULL THEN
    RETURN NEW;
  END IF;

  v_email := lower(nullif(trim(coalesce(NEW.email, NEW.payload->>'email', '')), ''));
  v_phone := nullif(trim(coalesce(NEW.phone, NEW.payload->>'phone', '')), '');
  v_name := nullif(trim(coalesce(
    NEW.payload->>'full_name',
    NEW.payload->>'name',
    NEW.payload->>'fullName',
    ''
  )), '');
  v_interest := nullif(trim(coalesce(
    NEW.payload->>'unit_interest',
    NEW.payload->>'interest',
    NEW.payload->>'message',
    ''
  )), '');

  IF v_name IS NULL AND v_email IS NOT NULL THEN
    v_name := initcap(replace(split_part(v_email, '@', 1), '.', ' '));
  END IF;

  IF v_name IS NULL OR length(v_name) < 2 OR v_phone IS NULL OR length(v_phone) < 7 THEN
    NEW.metadata := coalesce(NEW.metadata, '{}'::jsonb)
      || jsonb_build_object('crm_sync', 'skipped_missing_fields');
    RETURN NEW;
  END IF;

  BEGIN
    v_result := public.upsert_crm_public_lead(
      v_name,
      v_phone,
      v_email,
      'Marketing form — ' || v_name,
      'Submitted via ' || coalesce(NEW.source_path, 'marketing form'),
      'website',
      NULL,
      NULL,
      v_interest,
      'medium',
      NULL,
      NULL
    );
    NEW.crm_lead_id := nullif(v_result->>'crm_lead_id', '')::uuid;
    NEW.crm_synced_at := now();
    IF NEW.status IS NULL OR NEW.status = 'new' THEN
      NEW.status := 'contacted';
    END IF;
    NEW.metadata := coalesce(NEW.metadata, '{}'::jsonb)
      || jsonb_build_object(
        'crm_sync', 'ok',
        'crm_client_id', v_result->>'crm_client_id'
      );
  EXCEPTION WHEN OTHERS THEN
    NEW.metadata := coalesce(NEW.metadata, '{}'::jsonb)
      || jsonb_build_object('crm_sync', 'error', 'crm_sync_error', SQLERRM);
  END;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_form_submissions_sync_crm ON public.form_submissions;
CREATE TRIGGER trg_form_submissions_sync_crm
  BEFORE INSERT ON public.form_submissions
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_marketing_form_submission_to_crm();

CREATE OR REPLACE FUNCTION public.resync_form_submission_to_crm(p_submission_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r public.form_submissions%ROWTYPE;
  v_name text;
  v_phone text;
  v_email text;
  v_interest text;
  v_result jsonb;
BEGIN
  IF NOT (
    public.has_permission('marketing.forms', auth.uid())
    OR public.has_permission('marketing.write', auth.uid())
    OR public.has_permission('manage_marketing', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  SELECT * INTO r FROM public.form_submissions WHERE id = p_submission_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'submission not found';
  END IF;
  IF r.crm_lead_id IS NOT NULL THEN
    RETURN jsonb_build_object('ok', true, 'crm_lead_id', r.crm_lead_id, 'already_synced', true);
  END IF;

  v_email := lower(nullif(trim(coalesce(r.email, r.payload->>'email', '')), ''));
  v_phone := nullif(trim(coalesce(r.phone, r.payload->>'phone', '')), '');
  v_name := nullif(trim(coalesce(
    r.payload->>'full_name', r.payload->>'name', r.payload->>'fullName', ''
  )), '');
  v_interest := nullif(trim(coalesce(
    r.payload->>'unit_interest', r.payload->>'interest', r.payload->>'message', ''
  )), '');
  IF v_name IS NULL AND v_email IS NOT NULL THEN
    v_name := initcap(replace(split_part(v_email, '@', 1), '.', ' '));
  END IF;
  IF v_name IS NULL OR length(v_name) < 2 OR v_phone IS NULL OR length(v_phone) < 7 THEN
    RAISE EXCEPTION 'submission missing name or phone';
  END IF;

  v_result := public.upsert_crm_public_lead(
    v_name, v_phone, v_email,
    'Marketing form — ' || v_name,
    'Manual sync from ' || coalesce(r.source_path, 'marketing form'),
    'website', NULL, NULL, v_interest, 'medium', NULL, NULL
  );

  UPDATE public.form_submissions SET
    crm_lead_id = nullif(v_result->>'crm_lead_id', '')::uuid,
    crm_synced_at = now(),
    status = CASE WHEN status = 'new' THEN 'contacted' ELSE status END,
    metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object('crm_sync', 'manual_ok')
  WHERE id = p_submission_id;

  RETURN v_result || jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.resync_form_submission_to_crm(uuid) TO authenticated;
