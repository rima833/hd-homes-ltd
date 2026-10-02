-- Phase 2 — Investor Portal database & security hardening
-- 1) Lock investor_payment_intents (no self-confirm)
-- 2) Construction update media investor/client read parity
-- 3) ensure_investor_record requires investor role (or existing row)
-- 4) Local mirror of admin_publish_document_to_investor
-- 5) Freeze trigger for intent money/status fields

-- ---------------------------------------------------------------------------
-- A. Payment intents — replace FOR ALL owner policy
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS investor_payment_intents_own ON public.investor_payment_intents;
DROP POLICY IF EXISTS investor_payment_intents_select ON public.investor_payment_intents;
DROP POLICY IF EXISTS investor_payment_intents_insert ON public.investor_payment_intents;
DROP POLICY IF EXISTS investor_payment_intents_update_owner ON public.investor_payment_intents;
DROP POLICY IF EXISTS investor_payment_intents_staff ON public.investor_payment_intents;

CREATE POLICY investor_payment_intents_select
  ON public.investor_payment_intents
  FOR SELECT
  TO authenticated
  USING (
    investor_id = public.investor_id_for_user(auth.uid())
    OR public.is_staff()
  );

-- Investors may create intents only as pending / awaiting confirmation.
CREATE POLICY investor_payment_intents_insert
  ON public.investor_payment_intents
  FOR INSERT
  TO authenticated
  WITH CHECK (
    investor_id = public.investor_id_for_user(auth.uid())
    AND status = ANY (ARRAY['pending'::text, 'awaiting_confirmation'::text])
    AND COALESCE(is_deleted, false) = false
  );

-- Investors may cancel or attach bank notes only while still open.
-- They cannot move status to confirmed / failed (finance RPC only).
CREATE POLICY investor_payment_intents_update_owner
  ON public.investor_payment_intents
  FOR UPDATE
  TO authenticated
  USING (
    investor_id = public.investor_id_for_user(auth.uid())
    AND status = ANY (ARRAY['pending'::text, 'awaiting_confirmation'::text])
    AND COALESCE(is_deleted, false) = false
  )
  WITH CHECK (
    investor_id = public.investor_id_for_user(auth.uid())
    AND status = ANY (ARRAY['pending'::text, 'awaiting_confirmation'::text, 'cancelled'::text])
    AND COALESCE(is_deleted, false) = false
  );

-- Staff retain full row access for Finance desk reads; confirmation still
-- goes through admin_confirm_investor_intent (SECURITY DEFINER + audit).
CREATE POLICY investor_payment_intents_staff
  ON public.investor_payment_intents
  FOR ALL
  TO authenticated
  USING (public.is_staff())
  WITH CHECK (public.is_staff());

GRANT SELECT, INSERT, UPDATE ON public.investor_payment_intents TO authenticated;

-- Freeze money / settlement fields for non-staff clients (defense in depth).
CREATE OR REPLACE FUNCTION public.investor_payment_intents_owner_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF public.is_staff() THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF NEW.investor_id IS DISTINCT FROM OLD.investor_id
       OR NEW.amount IS DISTINCT FROM OLD.amount
       OR NEW.currency IS DISTINCT FROM OLD.currency
       OR NEW.provider IS DISTINCT FROM OLD.provider
       OR NEW.provider_reference IS DISTINCT FROM OLD.provider_reference
       OR NEW.receiving_account_id IS DISTINCT FROM OLD.receiving_account_id
       OR NEW.paid_at IS DISTINCT FROM OLD.paid_at
       OR COALESCE(NEW.is_deleted, false) IS DISTINCT FROM COALESCE(OLD.is_deleted, false)
    THEN
      RAISE EXCEPTION 'investor_payment_intent_immutable_fields';
    END IF;

    IF NEW.status IS DISTINCT FROM OLD.status
       AND NEW.status NOT IN ('pending', 'awaiting_confirmation', 'cancelled')
    THEN
      RAISE EXCEPTION 'investor_cannot_settle_payment_intent';
    END IF;

    IF NEW.status = 'confirmed' OR NEW.status = 'failed' THEN
      RAISE EXCEPTION 'investor_cannot_settle_payment_intent';
    END IF;
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF NEW.status NOT IN ('pending', 'awaiting_confirmation') THEN
      RAISE EXCEPTION 'investor_invalid_intent_status';
    END IF;
    IF NEW.paid_at IS NOT NULL THEN
      RAISE EXCEPTION 'investor_cannot_set_paid_at';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_investor_payment_intents_owner_guard
  ON public.investor_payment_intents;
CREATE TRIGGER trg_investor_payment_intents_owner_guard
  BEFORE INSERT OR UPDATE ON public.investor_payment_intents
  FOR EACH ROW
  EXECUTE FUNCTION public.investor_payment_intents_owner_guard();

-- ---------------------------------------------------------------------------
-- B. Construction update media — investor + client read (parity with updates)
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS construction_update_media_investor_read
  ON public.construction_update_media;
CREATE POLICY construction_update_media_investor_read
  ON public.construction_update_media
  FOR SELECT
  USING (
    COALESCE(is_deleted, false) = false
    AND EXISTS (
      SELECT 1
      FROM public.construction_progress_updates u
      JOIN public.construction_projects cp ON cp.id = u.project_id
      JOIN public.portfolio_holdings h ON h.property_id = cp.property_id
      JOIN public.investor_portfolios ip ON ip.id = h.portfolio_id
      JOIN public.investors inv ON inv.id = ip.investor_id
      WHERE u.id = construction_update_media.update_id
        AND u.is_published = true
        AND COALESCE(u.is_deleted, false) = false
        AND 'investors' = ANY (u.visibility)
        AND inv.user_id = auth.uid()
        AND COALESCE(inv.is_deleted, false) = false
    )
  );

DROP POLICY IF EXISTS construction_update_media_client_read
  ON public.construction_update_media;
CREATE POLICY construction_update_media_client_read
  ON public.construction_update_media
  FOR SELECT
  USING (
    COALESCE(is_deleted, false) = false
    AND EXISTS (
      SELECT 1
      FROM public.construction_progress_updates u
      JOIN public.construction_projects cp ON cp.id = u.project_id
      JOIN public.client_properties cprop ON cprop.property_id = cp.property_id
      JOIN public.clients c ON c.id = cprop.client_id
      WHERE u.id = construction_update_media.update_id
        AND u.is_published = true
        AND COALESCE(u.is_deleted, false) = false
        AND 'clients' = ANY (u.visibility)
        AND c.user_id = auth.uid()
        AND COALESCE(cprop.is_deleted, false) = false
    )
  );

-- ---------------------------------------------------------------------------
-- C. ensure_investor_record — no silent auto-provision for non-investors
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.ensure_investor_record()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
SET row_security TO off
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

    INSERT INTO public.investor_preferences (investor_id)
    VALUES (row.id)
    ON CONFLICT (investor_id) DO NOTHING;

    RETURN to_jsonb(row);
  END IF;

  -- Admin / Finance / Client must not auto-create investor domain rows.
  IF NOT public.has_role('investor', uid) THEN
    RAISE EXCEPTION 'investor_not_provisioned'
      USING HINT = 'Ask HD Homes admin to create and link an investor profile.';
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

-- ---------------------------------------------------------------------------
-- D. admin_publish_document_to_investor — local migration mirror
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_publish_document_to_investor(
  p_document_id uuid,
  p_investor_id uuid,
  p_document_type text DEFAULT 'shared'::text,
  p_title text DEFAULT NULL::text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_doc public.documents%ROWTYPE;
  v_id uuid;
  v_file_url text;
BEGIN
  IF NOT (
    public.has_permission('documents.share', auth.uid())
    OR public.has_permission('documents.write', auth.uid())
    OR public.has_permission('documents.admin', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.investors i
    WHERE i.id = p_investor_id AND COALESCE(i.is_deleted, false) = false
  ) THEN
    RAISE EXCEPTION 'investor_not_found';
  END IF;

  SELECT * INTO v_doc FROM public.documents WHERE id = p_document_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'document_not_found';
  END IF;

  IF v_doc.storage_bucket IS NOT NULL AND NULLIF(v_doc.storage_path, '') IS NOT NULL THEN
    v_file_url := 'storage://' || v_doc.storage_bucket || '/' || v_doc.storage_path;
  ELSIF NULLIF(v_doc.storage_path, '') IS NOT NULL THEN
    v_file_url := v_doc.storage_path;
  ELSE
    RAISE EXCEPTION 'document_has_no_file';
  END IF;

  INSERT INTO public.investor_documents (
    investor_id, title, document_type, file_url, version, is_sensitive, metadata
  ) VALUES (
    p_investor_id,
    COALESCE(NULLIF(trim(p_title), ''), v_doc.title),
    COALESCE(NULLIF(trim(p_document_type), ''), 'shared'),
    v_file_url,
    COALESCE(v_doc.current_version, 1),
    COALESCE(v_doc.sensitivity, 'internal') IN ('confidential', 'restricted', 'secret'),
    jsonb_build_object('source_document_id', p_document_id)
  )
  RETURNING id INTO v_id;

  BEGIN
    INSERT INTO public.document_activity_logs (
      document_id, action, summary, actor_label, occurred_at
    ) VALUES (
      p_document_id,
      'published_to_investor',
      'Published to investor portal',
      'Admin',
      now()
    );
  EXCEPTION
    WHEN undefined_table THEN NULL;
    WHEN others THEN NULL;
  END;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_publish_document_to_investor(uuid, uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_publish_document_to_investor(uuid, uuid, text, text) TO authenticated;

-- ---------------------------------------------------------------------------
-- E. RLS smoke helper (catalog + structural checks)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.investor_portal_phase2_security_smoke()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_policies text[];
  v_missing text[] := ARRAY[]::text[];
  v_required text[] := ARRAY[
    'investor_payment_intents_select',
    'investor_payment_intents_insert',
    'investor_payment_intents_update_owner',
    'investor_payment_intents_finance_write',
    'construction_update_media_investor_read',
    'construction_update_media_client_read'
  ];
  p text;
  v_legacy_all boolean;
  v_fn_exists boolean;
  v_trigger_exists boolean;
BEGIN
  SELECT coalesce(array_agg(policyname ORDER BY policyname), ARRAY[]::text[])
    INTO v_policies
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename IN ('investor_payment_intents', 'construction_update_media');

  FOREACH p IN ARRAY v_required LOOP
    IF NOT (p = ANY (v_policies)) THEN
      v_missing := array_append(v_missing, p);
    END IF;
  END LOOP;

  SELECT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'investor_payment_intents'
      AND policyname = 'investor_payment_intents_own'
      AND cmd = 'ALL'
  ) INTO v_legacy_all;

  SELECT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'admin_publish_document_to_investor'
  ) INTO v_fn_exists;

  SELECT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'trg_investor_payment_intents_owner_guard'
      AND NOT tgisinternal
  ) INTO v_trigger_exists;

  RETURN jsonb_build_object(
    'ok', (array_length(v_missing, 1) IS NULL)
          AND NOT v_legacy_all
          AND v_fn_exists
          AND v_trigger_exists,
    'missing_policies', to_jsonb(v_missing),
    'legacy_for_all_policy_present', v_legacy_all,
    'admin_publish_document_to_investor', v_fn_exists,
    'owner_guard_trigger', v_trigger_exists,
    'checked_at', now()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.investor_portal_phase2_security_smoke() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.investor_portal_phase2_security_smoke() TO authenticated;
