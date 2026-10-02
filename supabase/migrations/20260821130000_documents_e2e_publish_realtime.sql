-- Document E2E: portal publish bridge + realtime (local mirror of remote apply)

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'investor_documents',
    'contract_records',
    'digital_assets',
    'document_shares',
    'signature_requests',
    'ocr_processing_jobs',
    'property_documents'
  ]
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    END IF;
  END LOOP;
END $$;
