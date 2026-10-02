-- Phase 7: desk engagement — reports, referrals, 360 enrichment, document auth.

BEGIN;

-- Align report/statement write policies with investors.reports.
DROP POLICY IF EXISTS investor_reports_write ON public.investor_reports;
CREATE POLICY investor_reports_write ON public.investor_reports
  FOR ALL TO authenticated
  USING (
    public.has_permission('investors.reports', auth.uid())
    OR public.has_permission('investors.analytics', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('investors.reports', auth.uid())
    OR public.has_permission('investors.analytics', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

DROP POLICY IF EXISTS investor_statements_write ON public.investor_statements;
CREATE POLICY investor_statements_write ON public.investor_statements
  FOR ALL TO authenticated
  USING (
    public.has_permission('investors.reports', auth.uid())
    OR public.has_permission('investors.documents', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('investors.reports', auth.uid())
    OR public.has_permission('investors.documents', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

-- Allow IMP desk document permission on vault publish.
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
  v_version int := 1;
  v_existing_id uuid;
  v_existing_url text;
  v_existing_version int;
  v_existing_meta jsonb;
  v_history jsonb;
  v_ver_path text;
  v_mime text;
BEGIN
  IF NOT (
    public.has_permission('investors.documents', auth.uid())
    OR public.has_permission('documents.share', auth.uid())
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

  BEGIN
    SELECT dv.storage_path INTO v_ver_path
    FROM public.document_versions dv
    WHERE dv.document_id = p_document_id
      AND COALESCE(dv.is_current, false) = true
    ORDER BY dv.version_number DESC
    LIMIT 1;
  EXCEPTION
    WHEN undefined_table THEN
      v_ver_path := NULL;
  END;

  IF NULLIF(trim(COALESCE(v_ver_path, '')), '') IS NOT NULL THEN
    v_file_url := 'storage://' || COALESCE(NULLIF(v_doc.storage_bucket, ''), 'documents')
      || '/' || trim(v_ver_path);
    v_version := COALESCE(v_doc.current_version, 1);
  ELSIF v_doc.storage_bucket IS NOT NULL AND NULLIF(v_doc.storage_path, '') IS NOT NULL THEN
    v_file_url := 'storage://' || v_doc.storage_bucket || '/' || v_doc.storage_path;
    v_version := COALESCE(v_doc.current_version, 1);
  ELSIF NULLIF(v_doc.storage_path, '') IS NOT NULL
        AND (v_doc.storage_path LIKE 'http://%' OR v_doc.storage_path LIKE 'https://%') THEN
    v_file_url := v_doc.storage_path;
    v_version := COALESCE(v_doc.current_version, 1);
  ELSIF NULLIF(v_doc.storage_path, '') IS NOT NULL THEN
    v_file_url := v_doc.storage_path;
    v_version := COALESCE(v_doc.current_version, 1);
  ELSIF COALESCE(v_doc.metadata->>'file_url', '') <> '' THEN
    v_file_url := v_doc.metadata->>'file_url';
    v_version := COALESCE(v_doc.current_version, 1);
  ELSIF COALESCE(v_doc.metadata->>'secure_url', '') <> '' THEN
    v_file_url := v_doc.metadata->>'secure_url';
    v_version := COALESCE(v_doc.current_version, 1);
  ELSE
    RAISE EXCEPTION 'document_has_no_file';
  END IF;

  v_mime := NULLIF(v_doc.mime_type, '');

  SELECT id, file_url, version, metadata
    INTO v_existing_id, v_existing_url, v_existing_version, v_existing_meta
  FROM public.investor_documents
  WHERE investor_id = p_investor_id
    AND metadata->>'source_document_id' = p_document_id::text
  ORDER BY version DESC, updated_at DESC NULLS LAST
  LIMIT 1;

  IF v_existing_id IS NOT NULL THEN
    v_history := COALESCE(v_existing_meta->'version_history', '[]'::jsonb);
    IF NULLIF(trim(COALESCE(v_existing_url, '')), '') IS NOT NULL
       AND v_existing_url IS DISTINCT FROM v_file_url THEN
      v_history := v_history || jsonb_build_array(
        jsonb_build_object(
          'version', COALESCE(v_existing_version, 1),
          'file_url', v_existing_url,
          'replaced_at', now()
        )
      );
    END IF;

    UPDATE public.investor_documents SET
      title = COALESCE(NULLIF(trim(p_title), ''), v_doc.title, title),
      document_type = COALESCE(NULLIF(trim(p_document_type), ''), document_type, 'shared'),
      file_url = v_file_url,
      version = GREATEST(COALESCE(v_version, 1), COALESCE(v_existing_version, 1) + 1),
      is_sensitive = COALESCE(v_doc.sensitivity, 'internal')
        IN ('confidential', 'restricted', 'secret'),
      metadata = COALESCE(v_existing_meta, '{}'::jsonb) || jsonb_build_object(
        'source_document_id', p_document_id,
        'mime_type', v_mime,
        'file_name', v_doc.file_name,
        'delivery', CASE
          WHEN v_file_url LIKE 'https://res.cloudinary.com/%' THEN 'cloudinary'
          WHEN v_file_url LIKE 'http%' THEN 'https'
          WHEN v_file_url LIKE 'storage://%' THEN 'storage'
          ELSE 'path'
        END,
        'version_history', v_history,
        'published_at', now()
      ),
      updated_at = now()
    WHERE id = v_existing_id
    RETURNING id INTO v_id;
  ELSE
    INSERT INTO public.investor_documents (
      investor_id, title, document_type, file_url, version, is_sensitive, metadata
    ) VALUES (
      p_investor_id,
      COALESCE(NULLIF(trim(p_title), ''), v_doc.title),
      COALESCE(NULLIF(trim(p_document_type), ''), 'shared'),
      v_file_url,
      COALESCE(v_version, 1),
      COALESCE(v_doc.sensitivity, 'internal') IN ('confidential', 'restricted', 'secret'),
      jsonb_build_object(
        'source_document_id', p_document_id,
        'mime_type', v_mime,
        'file_name', v_doc.file_name,
        'delivery', CASE
          WHEN v_file_url LIKE 'https://res.cloudinary.com/%' THEN 'cloudinary'
          WHEN v_file_url LIKE 'http%' THEN 'https'
          WHEN v_file_url LIKE 'storage://%' THEN 'storage'
          ELSE 'path'
        END,
        'version_history', '[]'::jsonb,
        'published_at', now()
      )
    )
    RETURNING id INTO v_id;
  END IF;

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

CREATE OR REPLACE FUNCTION public.admin_publish_investor_report(
  p_investor_id uuid,
  p_title text,
  p_report_type text DEFAULT 'portfolio',
  p_file_url text DEFAULT NULL,
  p_period_label text DEFAULT NULL,
  p_notify boolean DEFAULT true
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_title text := NULLIF(trim(COALESCE(p_title, '')), '');
  v_type text := lower(trim(COALESCE(p_report_type, 'portfolio')));
  v_url text := NULLIF(trim(COALESCE(p_file_url, '')), '');
  v_period text := NULLIF(trim(COALESCE(p_period_label, '')), '');
BEGIN
  IF NOT (
    public.has_permission('investors.reports', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;
  IF v_title IS NULL THEN RAISE EXCEPTION 'title_required'; END IF;
  IF v_type NOT IN (
    'portfolio', 'performance', 'tax', 'compliance', 'market', 'custom'
  ) THEN
    RAISE EXCEPTION 'invalid_report_type';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.investors
    WHERE id = p_investor_id AND COALESCE(is_deleted, false) = false
  ) THEN
    RAISE EXCEPTION 'investor_not_found';
  END IF;

  INSERT INTO public.investor_reports (
    investor_id, title, report_type, file_url, period_label, generated_at, metadata
  ) VALUES (
    p_investor_id, v_title, v_type, v_url, v_period, now(),
    jsonb_build_object('published_by', auth.uid(), 'source', 'admin_command_center')
  )
  RETURNING id INTO v_id;

  INSERT INTO public.investor_activity_logs (
    investor_id, event_type, title, description, payload, actor_id, occurred_at
  ) VALUES (
    p_investor_id, 'report_published', 'Investor report published', v_title,
    jsonb_build_object(
      'report_id', v_id, 'report_type', v_type, 'period_label', v_period
    ),
    auth.uid(), now()
  );

  INSERT INTO public.investor_command_events (
    investor_id, aggregate_type, aggregate_id, event_type, payload, actor_id
  ) VALUES (
    p_investor_id, 'investor_reports', v_id, 'published',
    jsonb_build_object('title', v_title, 'report_type', v_type),
    auth.uid()
  );

  IF COALESCE(p_notify, true) THEN
    PERFORM public.admin_publish_investor_notification(
      p_investor_id,
      'New report available',
      v_title || CASE WHEN v_period IS NULL THEN '' ELSE ' · ' || v_period END,
      '/investor/reports',
      'reports',
      'in_app',
      jsonb_build_object('report_id', v_id)
    );
  END IF;

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_award_investor_referral(
  p_investor_id uuid,
  p_commission_amount numeric,
  p_currency text DEFAULT 'NGN',
  p_referral_code text DEFAULT NULL,
  p_referred_user_id uuid DEFAULT NULL,
  p_status text DEFAULT 'pending',
  p_notify boolean DEFAULT true
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_amount numeric := COALESCE(p_commission_amount, 0);
  v_currency text := upper(trim(COALESCE(p_currency, 'NGN')));
  v_status text := lower(trim(COALESCE(p_status, 'pending')));
  v_code text := NULLIF(trim(COALESCE(p_referral_code, '')), '');
BEGIN
  IF NOT (
    public.has_permission('investors.referrals', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;
  IF v_amount <= 0 THEN RAISE EXCEPTION 'invalid_amount'; END IF;
  IF v_currency !~ '^[A-Z]{3}$' THEN RAISE EXCEPTION 'invalid_currency'; END IF;
  IF v_status NOT IN ('pending', 'approved', 'paid', 'rejected', 'cancelled') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.investors
    WHERE id = p_investor_id AND COALESCE(is_deleted, false) = false
  ) THEN
    RAISE EXCEPTION 'investor_not_found';
  END IF;

  INSERT INTO public.investor_referral_commissions (
    investor_id, referred_user_id, referral_code, commission_amount,
    currency, status, paid_at, created_by, updated_by
  ) VALUES (
    p_investor_id, p_referred_user_id, v_code, round(v_amount, 2),
    v_currency, v_status,
    CASE WHEN v_status = 'paid' THEN now() ELSE NULL END,
    auth.uid(), auth.uid()
  )
  RETURNING id INTO v_id;

  INSERT INTO public.investor_activity_logs (
    investor_id, event_type, title, description, payload, actor_id, occurred_at
  ) VALUES (
    p_investor_id, 'referral_awarded', 'Referral commission recorded',
    COALESCE(v_code, 'Referral award'),
    jsonb_build_object(
      'commission_id', v_id, 'amount', v_amount,
      'currency', v_currency, 'status', v_status
    ),
    auth.uid(), now()
  );

  INSERT INTO public.investor_command_events (
    investor_id, aggregate_type, aggregate_id, event_type, payload, actor_id
  ) VALUES (
    p_investor_id, 'investor_referral_commissions', v_id, 'awarded',
    jsonb_build_object('amount', v_amount, 'status', v_status),
    auth.uid()
  );

  IF COALESCE(p_notify, true) THEN
    PERFORM public.admin_publish_investor_notification(
      p_investor_id,
      'Referral update',
      'A referral commission of ' || v_currency || ' ' || v_amount::text
        || ' was recorded.',
      '/investor/referrals',
      'referrals',
      'in_app',
      jsonb_build_object('commission_id', v_id)
    );
  END IF;

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_get_investor_360(p_investor_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_investor jsonb;
BEGIN
  IF NOT (
    public.has_permission('investors.read', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN RAISE EXCEPTION 'not authorized'; END IF;
  SELECT to_jsonb(i) || jsonb_build_object(
    'assigned_staff_name', (
      SELECT COALESCE(
        NULLIF(trim(concat_ws(' ', p.first_name, p.last_name)), ''),
        p.email
      )
      FROM public.profiles p
      WHERE p.id = i.assigned_staff_id
    )
  )
  INTO v_investor
  FROM public.investors i
  WHERE i.id = p_investor_id AND COALESCE(i.is_deleted, false) = false;
  IF v_investor IS NULL THEN RAISE EXCEPTION 'investor_not_found'; END IF;

  RETURN v_investor || jsonb_build_object(
    'portfolios', COALESCE((
      SELECT jsonb_agg(to_jsonb(p) ORDER BY p.created_at)
      FROM public.investor_portfolios p
      WHERE p.investor_id = p_investor_id
    ), '[]'::jsonb),
    'holdings', COALESCE((
      SELECT jsonb_agg(to_jsonb(h) ORDER BY h.created_at DESC)
      FROM public.portfolio_holdings h
      JOIN public.investor_portfolios p ON p.id = h.portfolio_id
      WHERE p.investor_id = p_investor_id
    ), '[]'::jsonb),
    'commitments', COALESCE((
      SELECT jsonb_agg(to_jsonb(c) ORDER BY c.committed_at DESC)
      FROM public.investment_commitments c
      WHERE c.investor_id = p_investor_id
    ), '[]'::jsonb),
    'distributions', COALESCE((
      SELECT jsonb_agg(to_jsonb(d) ORDER BY d.created_at DESC)
      FROM public.investment_distributions d
      WHERE d.investor_id = p_investor_id
    ), '[]'::jsonb),
    'wallets', COALESCE((
      SELECT jsonb_agg(to_jsonb(w) ORDER BY w.created_at)
      FROM public.investor_wallets w
      WHERE w.investor_id = p_investor_id
    ), '[]'::jsonb),
    'ledger', COALESCE((
      SELECT jsonb_agg(to_jsonb(t) ORDER BY t.posted_at DESC)
      FROM (
        SELECT * FROM public.investment_transactions
        WHERE investor_id = p_investor_id
        ORDER BY posted_at DESC LIMIT 200
      ) t
    ), '[]'::jsonb),
    'kyc_documents', COALESCE((
      SELECT jsonb_agg(to_jsonb(k) ORDER BY k.created_at DESC)
      FROM public.investor_kyc_documents k
      WHERE k.investor_id = p_investor_id
    ), '[]'::jsonb),
    'documents', COALESCE((
      SELECT jsonb_agg(to_jsonb(d) ORDER BY d.created_at DESC)
      FROM (
        SELECT * FROM public.investor_documents
        WHERE investor_id = p_investor_id
        ORDER BY created_at DESC LIMIT 50
      ) d
    ), '[]'::jsonb),
    'conversations', COALESCE((
      SELECT jsonb_agg(to_jsonb(c) ORDER BY c.last_message_at DESC NULLS LAST)
      FROM (
        SELECT * FROM public.investor_conversations
        WHERE investor_id = p_investor_id
          AND COALESCE(is_deleted, false) = false
        ORDER BY last_message_at DESC NULLS LAST, created_at DESC
        LIMIT 25
      ) c
    ), '[]'::jsonb),
    'reports', COALESCE((
      SELECT jsonb_agg(to_jsonb(r) ORDER BY r.generated_at DESC NULLS LAST)
      FROM (
        SELECT * FROM public.investor_reports
        WHERE investor_id = p_investor_id
        ORDER BY generated_at DESC NULLS LAST, created_at DESC
        LIMIT 50
      ) r
    ), '[]'::jsonb),
    'statements', COALESCE((
      SELECT jsonb_agg(to_jsonb(s) ORDER BY s.created_at DESC)
      FROM (
        SELECT * FROM public.investor_statements
        WHERE investor_id = p_investor_id
        ORDER BY created_at DESC LIMIT 50
      ) s
    ), '[]'::jsonb),
    'referrals', COALESCE((
      SELECT jsonb_agg(to_jsonb(rc) ORDER BY rc.created_at DESC)
      FROM (
        SELECT * FROM public.investor_referral_commissions
        WHERE investor_id = p_investor_id
          AND COALESCE(is_deleted, false) = false
        ORDER BY created_at DESC LIMIT 50
      ) rc
    ), '[]'::jsonb),
    'payment_intents', COALESCE((
      SELECT jsonb_agg(to_jsonb(pi) ORDER BY pi.created_at DESC)
      FROM (
        SELECT * FROM public.investor_payment_intents
        WHERE investor_id = p_investor_id
          AND COALESCE(is_deleted, false) = false
        ORDER BY created_at DESC LIMIT 50
      ) pi
    ), '[]'::jsonb),
    'tasks', COALESCE((
      SELECT jsonb_agg(to_jsonb(t) ORDER BY t.created_at DESC)
      FROM (
        SELECT * FROM public.investor_tasks
        WHERE investor_id = p_investor_id
          AND status IN ('open', 'in_progress')
        ORDER BY created_at DESC LIMIT 50
      ) t
    ), '[]'::jsonb),
    'activities', COALESCE((
      SELECT jsonb_agg(to_jsonb(a) ORDER BY a.occurred_at DESC)
      FROM (
        SELECT * FROM public.investor_activity_logs
        WHERE investor_id = p_investor_id
        ORDER BY occurred_at DESC LIMIT 200
      ) a
    ), '[]'::jsonb)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_publish_investor_report(
  uuid, text, text, text, text, boolean
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_award_investor_referral(
  uuid, numeric, text, text, uuid, text, boolean
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_publish_investor_report(
  uuid, text, text, text, text, boolean
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_award_investor_referral(
  uuid, numeric, text, text, uuid, text, boolean
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_publish_document_to_investor(
  uuid, uuid, text, text
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_investor_360(uuid) TO authenticated;

COMMIT;
