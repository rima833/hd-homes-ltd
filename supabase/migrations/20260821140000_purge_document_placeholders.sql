-- Purge placeholder client portal docs + archive DDCMS seed records.
-- Applied remotely 2026-08-21 via MCP; kept locally for repo parity.

BEGIN;

UPDATE public.client_documents
SET
  is_deleted = true,
  is_client_visible = false,
  updated_at = now()
WHERE coalesce(is_deleted, false) = false
  AND (
    file_url ILIKE '%hdhomes.ng/docs/%-sample.pdf%'
    OR file_url ILIKE '%allocation-sample.pdf%'
    OR file_url ILIKE '%agreement-sample.pdf%'
    OR (
      title IN ('Allocation Letter', 'Purchase Agreement')
      AND file_url ILIKE 'https://%'
      AND storage_path IS NULL
    )
  );

UPDATE public.documents
SET status = 'archived', updated_at = now()
WHERE id::text LIKE 'd1200004%';

UPDATE public.contract_records
SET status = 'cancelled', updated_at = now()
WHERE id::text LIKE 'd1200005%';

DELETE FROM public.document_activity_logs WHERE id::text LIKE 'd120001a%';
DELETE FROM public.document_notifications WHERE id::text LIKE 'd120001b%';
DELETE FROM public.document_ai_insights WHERE id::text LIKE 'd120001c%';
DELETE FROM public.document_reports WHERE id::text LIKE 'd1200019%';
DELETE FROM public.archival_records WHERE id::text LIKE 'd1200017%';
DELETE FROM public.document_shares WHERE id::text LIKE 'd1200015%';

COMMIT;
