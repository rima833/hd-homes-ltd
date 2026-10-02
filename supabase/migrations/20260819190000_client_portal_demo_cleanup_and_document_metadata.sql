-- Client portal production hardening:
-- 1) remove demo seed records
-- 2) normalize client document storage metadata
BEGIN;

-- ---------------------------------------------------------------------------
-- 1) Remove legacy demo client seed data
-- ---------------------------------------------------------------------------
DELETE FROM public.client_referral_commissions
WHERE client_id IN (
  SELECT id FROM public.clients WHERE client_code = 'CLT-DEMO-001'
);

DELETE FROM public.client_documents
WHERE client_id IN (
  SELECT id FROM public.clients WHERE client_code = 'CLT-DEMO-001'
);

DELETE FROM public.client_timeline
WHERE client_id IN (
  SELECT id FROM public.clients WHERE client_code = 'CLT-DEMO-001'
);

DELETE FROM public.installments
WHERE client_id IN (
  SELECT id FROM public.clients WHERE client_code = 'CLT-DEMO-001'
);

DELETE FROM public.payments
WHERE client_id IN (
  SELECT id FROM public.clients WHERE client_code = 'CLT-DEMO-001'
);

DELETE FROM public.client_properties
WHERE client_id IN (
  SELECT id FROM public.clients WHERE client_code = 'CLT-DEMO-001'
);

DELETE FROM public.clients
WHERE client_code = 'CLT-DEMO-001';

-- ---------------------------------------------------------------------------
-- 2) Document metadata fields for signed-url flow
-- ---------------------------------------------------------------------------
ALTER TABLE public.client_documents
  ADD COLUMN IF NOT EXISTS storage_bucket text,
  ADD COLUMN IF NOT EXISTS storage_path text;

-- Backfill metadata when file_url uses `storage://bucket/path`.
UPDATE public.client_documents
SET
  storage_bucket = split_part(replace(file_url, 'storage://', ''), '/', 1),
  storage_path = substring(replace(file_url, 'storage://', '') from position('/' in replace(file_url, 'storage://', '')) + 1)
WHERE file_url LIKE 'storage://%/%'
  AND (storage_bucket IS NULL OR storage_path IS NULL);

-- Backfill metadata when file_url looks like `bucket/path` (no URL scheme).
UPDATE public.client_documents
SET
  storage_bucket = split_part(file_url, '/', 1),
  storage_path = substring(file_url from position('/' in file_url) + 1)
WHERE file_url NOT LIKE 'http://%'
  AND file_url NOT LIKE 'https://%'
  AND file_url NOT LIKE 'storage://%'
  AND file_url LIKE '%/%'
  AND (storage_bucket IS NULL OR storage_path IS NULL);

CREATE INDEX IF NOT EXISTS idx_client_documents_storage
  ON public.client_documents (storage_bucket, storage_path);

COMMIT;
