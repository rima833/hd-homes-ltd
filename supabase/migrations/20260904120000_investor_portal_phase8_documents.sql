-- Phase 8 — Investor document vault
-- 1) Harden publish RPC: version upsert + history + prefer current document_versions
-- 2) Explicit owner SELECT — investors never write documents

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

REVOKE ALL ON FUNCTION public.admin_publish_document_to_investor(uuid, uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_publish_document_to_investor(uuid, uuid, text, text) TO authenticated;

DROP POLICY IF EXISTS investor_documents_portal_owner ON public.investor_documents;
CREATE POLICY investor_documents_portal_owner ON public.investor_documents
  FOR SELECT TO authenticated
  USING (
    investor_id = public.investor_id_for_user(auth.uid())
    OR public.is_staff()
  );

COMMENT ON FUNCTION public.admin_publish_document_to_investor(uuid, uuid, text, text) IS
  'DDCMS → investor vault publish with version upsert and history (Phase 8).';
