-- Clients and investors can download only files that were issued to them.
-- Staff access stays on the existing enterprise-documents policy.

DROP POLICY IF EXISTS storage_issued_client_documents_read ON storage.objects;
CREATE POLICY storage_issued_client_documents_read ON storage.objects
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.client_documents d
      JOIN public.clients c ON c.id = d.client_id
      WHERE c.user_id = auth.uid()
        AND COALESCE(c.is_deleted, false) = false
        AND COALESCE(d.is_deleted, false) = false
        AND COALESCE(d.is_client_visible, true) = true
        AND (
          (d.storage_bucket = bucket_id AND d.storage_path = name)
          OR d.file_url = 'storage://' || bucket_id || '/' || name
          OR d.file_url = bucket_id || '/' || name
        )
    )
  );

DROP POLICY IF EXISTS storage_issued_investor_documents_read ON storage.objects;
CREATE POLICY storage_issued_investor_documents_read ON storage.objects
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.investor_documents d
      JOIN public.investors i ON i.id = d.investor_id
      WHERE i.user_id = auth.uid()
        AND COALESCE(i.is_deleted, false) = false
        AND (
          d.file_url = 'storage://' || bucket_id || '/' || name
          OR d.file_url = bucket_id || '/' || name
          OR (
            d.metadata->>'storage_bucket' = bucket_id
            AND d.metadata->>'storage_path' = name
          )
        )
    )
    OR EXISTS (
      SELECT 1
      FROM public.investor_reports r
      JOIN public.investors i ON i.id = r.investor_id
      WHERE i.user_id = auth.uid()
        AND COALESCE(i.is_deleted, false) = false
        AND (
          r.file_url = 'storage://' || bucket_id || '/' || name
          OR r.file_url = bucket_id || '/' || name
        )
    )
    OR EXISTS (
      SELECT 1
      FROM public.investor_statements s
      JOIN public.investors i ON i.id = s.investor_id
      WHERE i.user_id = auth.uid()
        AND COALESCE(i.is_deleted, false) = false
        AND (
          s.file_url = 'storage://' || bucket_id || '/' || name
          OR s.file_url = bucket_id || '/' || name
        )
    )
  );
