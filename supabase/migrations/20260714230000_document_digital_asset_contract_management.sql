-- APPLIED remotely 2026-07-15 (chunked document_digital_asset_contract_p1–p3)
-- Volume 4 Part 12 — Document, Digital Asset & Contract Management System (DDCMS)
-- Status: APPLIED remotely 2026-07-15.
--
-- Approach:
--   • NEVER recreate/drop module docs:
--     property_documents, client_documents, crm_documents, investor_documents,
--     employee_documents, applicant_documents, project_documents, kyc_documents,
--     document_reviews (KYC), sales_documents.
--   • NEW enterprise tables under DDCMS.
--   • EOC already has workflow_steps — use document_workflow_steps /
--     document_workflows (NOT workflow_steps).
--   • Prefer public.documents (does not exist yet). Seed UUIDs hex-only (d120…).
--   • Permissions: slug, name, description, module ONLY.
--   • RLS: has_permission('slug', auth.uid()) — slug FIRST.
--
-- Volume 4 continues Parts 13–25. Wait for approve before Part 13.

BEGIN;

-- ---------------------------------------------------------------------------
-- Permissions
-- ---------------------------------------------------------------------------
INSERT INTO public.permissions (slug, name, description, module) VALUES
  ('documents.read', 'View Documents', 'View Document Command Center and repository', 'documents'),
  ('documents.write', 'Manage Documents', 'Create and edit enterprise documents', 'documents'),
  ('documents.upload', 'Upload Documents', 'Upload files to enterprise document storage', 'documents'),
  ('documents.approve', 'Approve Documents', 'Approve document workflows and contracts', 'documents'),
  ('documents.contracts', 'Manage Contracts', 'Manage contract records and amendments', 'documents'),
  ('documents.signatures', 'Manage Signatures', 'Manage digital signature requests', 'documents'),
  ('documents.dam', 'Digital Asset Management', 'Manage digital assets and collections', 'documents'),
  ('documents.share', 'Share Documents', 'Create and manage document shares', 'documents'),
  ('documents.archive', 'Archive Documents', 'Archive and restore documents', 'documents'),
  ('documents.retention', 'Retention Policies', 'Manage retention and archival policies', 'documents'),
  ('documents.ai', 'Document AI', 'Use document AI intelligence tools', 'documents'),
  ('documents.analytics', 'Document Analytics', 'View document KPIs and analytics', 'documents'),
  ('documents.reports', 'Document Reports', 'Generate and view document reports', 'documents'),
  ('documents.admin', 'Documents Admin', 'Administer DDCMS settings and policies', 'documents')
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  module = EXCLUDED.module,
  updated_at = now();

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE p.slug LIKE 'documents.%'
  AND (
    r.slug IN ('super_admin', 'admin')
    OR (r.slug = 'finance' AND p.slug IN (
      'documents.read', 'documents.contracts', 'documents.approve',
      'documents.analytics', 'documents.reports', 'documents.archive'
    ))
    OR (r.slug = 'sales_team' AND p.slug IN (
      'documents.read', 'documents.upload', 'documents.share'
    ))
    OR (r.slug = 'construction_manager' AND p.slug IN (
      'documents.read', 'documents.upload', 'documents.approve', 'documents.contracts'
    ))
    OR (r.slug = 'marketing' AND p.slug IN (
      'documents.read', 'documents.upload', 'documents.dam', 'documents.share'
    ))
  )
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Core taxonomy
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.document_folders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id uuid REFERENCES public.document_folders(id) ON DELETE SET NULL,
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  description text,
  path text,
  sort_order int NOT NULL DEFAULT 100,
  is_active boolean NOT NULL DEFAULT true,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.document_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  description text,
  module_scope text DEFAULT 'enterprise',
  sort_order int NOT NULL DEFAULT 100,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.document_tags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  color text DEFAULT '#6B7280',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  folder_id uuid REFERENCES public.document_folders(id) ON DELETE SET NULL,
  category_id uuid REFERENCES public.document_categories(id) ON DELETE SET NULL,
  title text NOT NULL,
  code text UNIQUE,
  description text,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','in_review','approved','published','archived','expired')),
  mime_type text,
  file_name text,
  storage_bucket text DEFAULT 'enterprise-documents',
  storage_path text,
  current_version int NOT NULL DEFAULT 1,
  owner_label text,
  sensitivity text NOT NULL DEFAULT 'internal'
    CHECK (sensitivity IN ('public','internal','confidential','restricted')),
  tags text[] NOT NULL DEFAULT '{}',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_documents_folder ON public.documents(folder_id);
CREATE INDEX IF NOT EXISTS idx_documents_category ON public.documents(category_id);
CREATE INDEX IF NOT EXISTS idx_documents_status ON public.documents(status);
CREATE INDEX IF NOT EXISTS idx_documents_created ON public.documents(created_at DESC);

CREATE TABLE IF NOT EXISTS public.document_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id uuid NOT NULL REFERENCES public.documents(id) ON DELETE CASCADE,
  version_number int NOT NULL,
  change_summary text,
  file_name text,
  storage_path text,
  uploaded_by text,
  is_current boolean NOT NULL DEFAULT false,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (document_id, version_number)
);

CREATE TABLE IF NOT EXISTS public.document_metadata (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id uuid NOT NULL REFERENCES public.documents(id) ON DELETE CASCADE,
  key text NOT NULL,
  value text,
  value_json jsonb,
  UNIQUE (document_id, key)
);

CREATE TABLE IF NOT EXISTS public.document_tag_links (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id uuid NOT NULL REFERENCES public.documents(id) ON DELETE CASCADE,
  tag_id uuid NOT NULL REFERENCES public.document_tags(id) ON DELETE CASCADE,
  UNIQUE (document_id, tag_id)
);

CREATE TABLE IF NOT EXISTS public.document_permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id uuid NOT NULL REFERENCES public.documents(id) ON DELETE CASCADE,
  principal_type text NOT NULL DEFAULT 'role'
    CHECK (principal_type IN ('role','user','team')),
  principal_label text NOT NULL,
  can_read boolean NOT NULL DEFAULT true,
  can_write boolean NOT NULL DEFAULT false,
  can_share boolean NOT NULL DEFAULT false,
  can_approve boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Workflows (document-specific — NOT EOC workflow_steps)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.document_workflows (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id uuid REFERENCES public.documents(id) ON DELETE CASCADE,
  name text NOT NULL,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','completed','cancelled','paused')),
  current_step int NOT NULL DEFAULT 1,
  started_at timestamptz DEFAULT now(),
  completed_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.document_workflow_steps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workflow_id uuid NOT NULL REFERENCES public.document_workflows(id) ON DELETE CASCADE,
  step_order int NOT NULL,
  name text NOT NULL,
  assignee_role text,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','in_progress','completed','skipped','rejected')),
  due_at timestamptz,
  completed_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (workflow_id, step_order)
);

CREATE TABLE IF NOT EXISTS public.document_approvals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id uuid REFERENCES public.documents(id) ON DELETE CASCADE,
  workflow_id uuid REFERENCES public.document_workflows(id) ON DELETE SET NULL,
  title text NOT NULL,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','approved','rejected','cancelled')),
  requester_label text,
  approver_label text,
  decision_note text,
  decided_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.document_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id uuid NOT NULL REFERENCES public.documents(id) ON DELETE CASCADE,
  author_label text,
  body text NOT NULL,
  is_internal boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Contracts & signatures
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.contract_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id uuid REFERENCES public.documents(id) ON DELETE SET NULL,
  contract_number text NOT NULL UNIQUE,
  title text NOT NULL,
  contract_type text NOT NULL DEFAULT 'sale'
    CHECK (contract_type IN ('sale','lease','service','construction','employment','nda','other')),
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','negotiation','pending_signature','active','amended','expired','terminated')),
  counterparty_name text,
  value_amount numeric,
  currency text DEFAULT 'NGN',
  effective_date date,
  expiry_date date,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.contract_parties (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contract_id uuid NOT NULL REFERENCES public.contract_records(id) ON DELETE CASCADE,
  party_name text NOT NULL,
  party_role text NOT NULL DEFAULT 'counterparty',
  email text,
  signed boolean NOT NULL DEFAULT false,
  signed_at timestamptz
);

CREATE TABLE IF NOT EXISTS public.contract_milestones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contract_id uuid NOT NULL REFERENCES public.contract_records(id) ON DELETE CASCADE,
  title text NOT NULL,
  due_date date,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','completed','overdue','waived')),
  amount numeric,
  sort_order int NOT NULL DEFAULT 100
);

CREATE TABLE IF NOT EXISTS public.contract_amendments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contract_id uuid NOT NULL REFERENCES public.contract_records(id) ON DELETE CASCADE,
  amendment_number int NOT NULL,
  summary text NOT NULL,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','pending','approved','rejected')),
  effective_date date,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (contract_id, amendment_number)
);

CREATE TABLE IF NOT EXISTS public.signature_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id uuid REFERENCES public.documents(id) ON DELETE SET NULL,
  contract_id uuid REFERENCES public.contract_records(id) ON DELETE SET NULL,
  title text NOT NULL,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','sent','partially_signed','completed','declined','expired','cancelled')),
  requester_label text,
  due_at timestamptz,
  completed_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.digital_signatures (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES public.signature_requests(id) ON DELETE CASCADE,
  signer_name text NOT NULL,
  signer_email text,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','signed','declined')),
  signed_at timestamptz,
  signature_method text DEFAULT 'drawn',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

-- ---------------------------------------------------------------------------
-- OCR & extraction
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ocr_processing_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id uuid REFERENCES public.documents(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'queued'
    CHECK (status IN ('queued','processing','completed','failed','cancelled')),
  engine text DEFAULT 'tesseract',
  pages int DEFAULT 1,
  progress_pct int DEFAULT 0,
  error_message text,
  started_at timestamptz,
  completed_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.extracted_document_data (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id uuid REFERENCES public.documents(id) ON DELETE CASCADE,
  job_id uuid REFERENCES public.ocr_processing_jobs(id) ON DELETE SET NULL,
  field_key text NOT NULL,
  field_value text,
  confidence numeric,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Digital Asset Management (DAM)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.digital_assets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  asset_type text NOT NULL DEFAULT 'image'
    CHECK (asset_type IN ('image','video','audio','design','brochure','other')),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft','active','archived')),
  mime_type text,
  storage_bucket text DEFAULT 'digital-assets',
  storage_path text,
  width_px int,
  height_px int,
  usage_rights text,
  tags text[] NOT NULL DEFAULT '{}',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.asset_collections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.asset_collection_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  collection_id uuid NOT NULL REFERENCES public.asset_collections(id) ON DELETE CASCADE,
  asset_id uuid NOT NULL REFERENCES public.digital_assets(id) ON DELETE CASCADE,
  sort_order int NOT NULL DEFAULT 100,
  UNIQUE (collection_id, asset_id)
);

CREATE TABLE IF NOT EXISTS public.asset_usage_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_id uuid NOT NULL REFERENCES public.digital_assets(id) ON DELETE CASCADE,
  channel text,
  context_label text,
  used_by text,
  used_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Sharing, retention, search, reports, activity, AI
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.document_shares (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id uuid NOT NULL REFERENCES public.documents(id) ON DELETE CASCADE,
  share_token text,
  recipient_label text,
  recipient_email text,
  access_level text NOT NULL DEFAULT 'view'
    CHECK (access_level IN ('view','comment','download')),
  expires_at timestamptz,
  is_revoked boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.retention_policies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  category_slug text,
  retain_months int NOT NULL DEFAULT 84,
  action_on_expiry text NOT NULL DEFAULT 'review'
    CHECK (action_on_expiry IN ('review','archive','delete')),
  is_active boolean NOT NULL DEFAULT true,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.archival_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id uuid REFERENCES public.documents(id) ON DELETE SET NULL,
  policy_id uuid REFERENCES public.retention_policies(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'scheduled'
    CHECK (status IN ('scheduled','archived','restored','purged')),
  scheduled_at timestamptz,
  archived_at timestamptz,
  note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.document_search_index (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id uuid NOT NULL REFERENCES public.documents(id) ON DELETE CASCADE,
  search_text text NOT NULL,
  keywords text[] NOT NULL DEFAULT '{}',
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (document_id)
);

CREATE TABLE IF NOT EXISTS public.document_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  report_type text NOT NULL DEFAULT 'usage',
  period_label text,
  summary text,
  metrics jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.document_activity_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id uuid REFERENCES public.documents(id) ON DELETE SET NULL,
  action text NOT NULL,
  summary text NOT NULL,
  actor_label text,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS public.document_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  body text,
  severity text NOT NULL DEFAULT 'info'
    CHECK (severity IN ('info','warning','critical')),
  is_read boolean NOT NULL DEFAULT false,
  related_document_id uuid REFERENCES public.documents(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.document_ai_insights (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  body text NOT NULL,
  insight_type text NOT NULL DEFAULT 'advisory',
  confidence_pct numeric,
  editable boolean NOT NULL DEFAULT true,
  disclaimer text NOT NULL DEFAULT 'AI-generated — editable / advisory',
  related_document_id uuid REFERENCES public.documents(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Storage buckets (enterprise-documents, digital-assets)
-- ---------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  (
    'enterprise-documents',
    'enterprise-documents',
    false,
    52428800,
    ARRAY[
      'application/pdf',
      'image/jpeg',
      'image/png',
      'image/webp',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    ]
  ),
  (
    'digital-assets',
    'digital-assets',
    false,
    104857600,
    ARRAY[
      'image/jpeg',
      'image/png',
      'image/webp',
      'image/svg+xml',
      'video/mp4',
      'application/pdf'
    ]
  )
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS storage_enterprise_documents_staff ON storage.objects;
CREATE POLICY storage_enterprise_documents_staff ON storage.objects
  FOR ALL TO authenticated
  USING (
    bucket_id = 'enterprise-documents'
    AND (
      public.has_permission('documents.read', auth.uid())
      OR public.has_permission('documents.upload', auth.uid())
      OR public.has_permission('documents.admin', auth.uid())
      OR public.has_role('super_admin', auth.uid())
    )
  )
  WITH CHECK (
    bucket_id = 'enterprise-documents'
    AND (
      public.has_permission('documents.upload', auth.uid())
      OR public.has_permission('documents.write', auth.uid())
      OR public.has_permission('documents.admin', auth.uid())
      OR public.has_role('super_admin', auth.uid())
    )
  );

DROP POLICY IF EXISTS storage_digital_assets_staff ON storage.objects;
CREATE POLICY storage_digital_assets_staff ON storage.objects
  FOR ALL TO authenticated
  USING (
    bucket_id = 'digital-assets'
    AND (
      public.has_permission('documents.dam', auth.uid())
      OR public.has_permission('documents.read', auth.uid())
      OR public.has_role('super_admin', auth.uid())
    )
  )
  WITH CHECK (
    bucket_id = 'digital-assets'
    AND (
      public.has_permission('documents.dam', auth.uid())
      OR public.has_permission('documents.upload', auth.uid())
      OR public.has_role('super_admin', auth.uid())
    )
  );

-- ---------------------------------------------------------------------------
-- Seeds (hex-only UUIDs d120…)
-- ---------------------------------------------------------------------------
INSERT INTO public.document_folders (id, parent_id, name, slug, description, path, sort_order) VALUES
  ('d1200001-0000-4000-8000-000000000001', NULL, 'Legal & Title', 'legal-title', 'Deeds, titles, and legal packs', '/legal-title', 10),
  ('d1200001-0000-4000-8000-000000000002', NULL, 'Construction', 'construction', 'Drawings and site packs', '/construction', 20),
  ('d1200001-0000-4000-8000-000000000003', NULL, 'Marketing', 'marketing', 'Brochures and campaign assets', '/marketing', 30),
  ('d1200001-0000-4000-8000-000000000004', NULL, 'HR & Policies', 'hr-policies', 'Employee policies and handbooks', '/hr-policies', 40),
  ('d1200001-0000-4000-8000-000000000005', NULL, 'Finance', 'finance', 'Invoices and financial docs', '/finance', 50)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.document_categories (id, slug, name, description, module_scope, sort_order) VALUES
  ('d1200002-0000-4000-8000-000000000001', 'property-deed', 'Property Deed', 'Title and deed documents', 'property', 10),
  ('d1200002-0000-4000-8000-000000000002', 'construction-drawing', 'Construction Drawing', 'Plans and drawings', 'construction', 20),
  ('d1200002-0000-4000-8000-000000000003', 'marketing-brochure', 'Marketing Brochure', 'Sales and marketing collateral', 'marketing', 30),
  ('d1200002-0000-4000-8000-000000000004', 'hr-policy', 'HR Policy', 'People policies', 'hr', 40),
  ('d1200002-0000-4000-8000-000000000005', 'finance-invoice', 'Finance Invoice', 'Invoices and receipts', 'finance', 50),
  ('d1200002-0000-4000-8000-000000000006', 'contract', 'Contract', 'Commercial agreements', 'legal', 60)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.document_tags (id, slug, name, color) VALUES
  ('d1200003-0000-4000-8000-000000000001', 'confidential', 'Confidential', '#DC2626'),
  ('d1200003-0000-4000-8000-000000000002', 'client-facing', 'Client Facing', '#2563EB'),
  ('d1200003-0000-4000-8000-000000000003', 'requires-signature', 'Requires Signature', '#D97706'),
  ('d1200003-0000-4000-8000-000000000004', 'retention-alert', 'Retention Alert', '#7C3AED')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.documents (
  id, folder_id, category_id, title, code, description, status, mime_type, file_name,
  storage_path, current_version, owner_label, sensitivity, tags, metadata
) VALUES
  ('d1200004-0000-4000-8000-000000000001',
   'd1200001-0000-4000-8000-000000000001', 'd1200002-0000-4000-8000-000000000001',
   'Lekki Phase 2 — Block B Title Deed', 'DOC-2026-1201',
   'Certified soft-copy title deed for Block B allocation pack.',
   'approved', 'application/pdf', 'lekki-b-title-deed.pdf',
   'legal/lekki-b-title-deed.pdf', 2, 'Legal Desk', 'confidential',
   ARRAY['confidential','legal'], '{"demo":true,"category":"property-deed"}'::jsonb),
  ('d1200004-0000-4000-8000-000000000002',
   'd1200001-0000-4000-8000-000000000002', 'd1200002-0000-4000-8000-000000000002',
   'Unit C-12 Architectural Drawing (Stub)', 'DOC-2026-1202',
   'Construction drawing metadata stub — file upload pending DAM sync.',
   'in_review', 'application/pdf', 'unit-c12-drawing.pdf',
   'construction/unit-c12-drawing.pdf', 1, 'Site Office', 'internal',
   ARRAY['construction'], '{"demo":true,"category":"construction-drawing","stub":true}'::jsonb),
  ('d1200004-0000-4000-8000-000000000003',
   'd1200001-0000-4000-8000-000000000003', 'd1200002-0000-4000-8000-000000000003',
   'Oceanview Estates Marketing Brochure Q3', 'DOC-2026-1203',
   'Q3 sales brochure for open-house weekends.',
   'published', 'application/pdf', 'oceanview-brochure-q3.pdf',
   'marketing/oceanview-brochure-q3.pdf', 3, 'Marketing', 'public',
   ARRAY['client-facing','marketing'], '{"demo":true,"category":"marketing-brochure"}'::jsonb),
  ('d1200004-0000-4000-8000-000000000004',
   'd1200001-0000-4000-8000-000000000004', 'd1200002-0000-4000-8000-000000000004',
   'Employee Code of Conduct 2026', 'DOC-2026-1204',
   'Updated HR policy handbook for all staff.',
   'approved', 'application/pdf', 'code-of-conduct-2026.pdf',
   'hr/code-of-conduct-2026.pdf', 1, 'HR Ops', 'internal',
   ARRAY['hr'], '{"demo":true,"category":"hr-policy"}'::jsonb),
  ('d1200004-0000-4000-8000-000000000005',
   'd1200001-0000-4000-8000-000000000005', 'd1200002-0000-4000-8000-000000000005',
   'June Installment Invoice — Adeyemi', 'DOC-2026-1205',
   'Client installment invoice for June payment cycle.',
   'approved', 'application/pdf', 'invoice-adeyemi-jun.pdf',
   'finance/invoice-adeyemi-jun.pdf', 1, 'Finance', 'confidential',
   ARRAY['finance','confidential'], '{"demo":true,"category":"finance-invoice"}'::jsonb),
  ('d1200004-0000-4000-8000-000000000006',
   'd1200001-0000-4000-8000-000000000001', 'd1200002-0000-4000-8000-000000000006',
   'Sale Agreement — Plot B-14 Oceanview', 'DOC-2026-1206',
   'Primary sale agreement awaiting digital signature.',
   'in_review', 'application/pdf', 'sale-agreement-b14.pdf',
   'legal/sale-agreement-b14.pdf', 1, 'Sales Legal', 'confidential',
   ARRAY['requires-signature','contract'], '{"demo":true,"category":"contract"}'::jsonb)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.document_versions (id, document_id, version_number, change_summary, file_name, storage_path, uploaded_by, is_current) VALUES
  ('d1200005-0000-4000-8000-000000000001', 'd1200004-0000-4000-8000-000000000001', 1, 'Initial scan upload', 'lekki-b-title-deed-v1.pdf', 'legal/lekki-b-title-deed-v1.pdf', 'Legal Desk', false),
  ('d1200005-0000-4000-8000-000000000002', 'd1200004-0000-4000-8000-000000000001', 2, 'Certified copy with registry stamp', 'lekki-b-title-deed.pdf', 'legal/lekki-b-title-deed.pdf', 'Legal Desk', true),
  ('d1200005-0000-4000-8000-000000000003', 'd1200004-0000-4000-8000-000000000003', 3, 'Q3 pricing refresh', 'oceanview-brochure-q3.pdf', 'marketing/oceanview-brochure-q3.pdf', 'Marketing', true)
ON CONFLICT DO NOTHING;

INSERT INTO public.document_metadata (id, document_id, key, value, value_json) VALUES
  ('d1200006-0000-4000-8000-000000000001', 'd1200004-0000-4000-8000-000000000001', 'registry_number', 'LG/REG/2024/88421', NULL),
  ('d1200006-0000-4000-8000-000000000002', 'd1200004-0000-4000-8000-000000000002', 'drawing_revision', 'R0-stub', '{"stub":true}'::jsonb),
  ('d1200006-0000-4000-8000-000000000003', 'd1200004-0000-4000-8000-000000000005', 'invoice_amount', '2500000', '{"currency":"NGN"}'::jsonb)
ON CONFLICT DO NOTHING;

INSERT INTO public.document_tag_links (id, document_id, tag_id) VALUES
  ('d1200007-0000-4000-8000-000000000001', 'd1200004-0000-4000-8000-000000000001', 'd1200003-0000-4000-8000-000000000001'),
  ('d1200007-0000-4000-8000-000000000002', 'd1200004-0000-4000-8000-000000000003', 'd1200003-0000-4000-8000-000000000002'),
  ('d1200007-0000-4000-8000-000000000003', 'd1200004-0000-4000-8000-000000000006', 'd1200003-0000-4000-8000-000000000003')
ON CONFLICT DO NOTHING;

INSERT INTO public.document_workflows (id, document_id, name, status, current_step) VALUES
  ('d1200008-0000-4000-8000-000000000001', 'd1200004-0000-4000-8000-000000000006', 'Sale Agreement Approval', 'active', 2),
  ('d1200008-0000-4000-8000-000000000002', 'd1200004-0000-4000-8000-000000000002', 'Drawing Review', 'active', 1)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.document_workflow_steps (id, workflow_id, step_order, name, assignee_role, status) VALUES
  ('d1200009-0000-4000-8000-000000000001', 'd1200008-0000-4000-8000-000000000001', 1, 'Legal draft check', 'admin', 'completed'),
  ('d1200009-0000-4000-8000-000000000002', 'd1200008-0000-4000-8000-000000000001', 2, 'Finance value check', 'finance', 'in_progress'),
  ('d1200009-0000-4000-8000-000000000003', 'd1200008-0000-4000-8000-000000000001', 3, 'Director approve', 'super_admin', 'pending'),
  ('d1200009-0000-4000-8000-000000000004', 'd1200008-0000-4000-8000-000000000002', 1, 'CM review drawing', 'construction_manager', 'in_progress')
ON CONFLICT DO NOTHING;

INSERT INTO public.document_approvals (
  id, document_id, workflow_id, title, status, requester_label, approver_label, decided_at
) VALUES
  ('d120000a-0000-4000-8000-000000000001', 'd1200004-0000-4000-8000-000000000006',
   'd1200008-0000-4000-8000-000000000001', 'Approve Sale Agreement B-14', 'pending', 'Sales Legal', NULL, NULL),
  ('d120000a-0000-4000-8000-000000000002', 'd1200004-0000-4000-8000-000000000002',
   'd1200008-0000-4000-8000-000000000002', 'Approve Unit C-12 Drawing Stub', 'pending', 'Site Office', NULL, NULL),
  ('d120000a-0000-4000-8000-000000000003', 'd1200004-0000-4000-8000-000000000004',
   NULL, 'Approve Code of Conduct 2026', 'approved', 'HR Ops', 'Admin', now() - interval '2 days')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.contract_records (
  id, document_id, contract_number, title, contract_type, status,
  counterparty_name, value_amount, currency, effective_date, expiry_date, metadata
) VALUES
  ('d120000b-0000-4000-8000-000000000001', 'd1200004-0000-4000-8000-000000000006',
   'CTR-2026-1401', 'Sale Agreement — Plot B-14 Oceanview', 'sale', 'pending_signature',
   'Tunde Bakare', 45000000, 'NGN', CURRENT_DATE, CURRENT_DATE + interval '18 months',
   '{"demo":true}'::jsonb),
  ('d120000b-0000-4000-8000-000000000002', NULL,
   'CTR-2026-1402', 'Construction Phase 2 Subcontract', 'construction', 'active',
   'Apex Build Co.', 120000000, 'NGN', CURRENT_DATE - interval '30 days', CURRENT_DATE + interval '12 months',
   '{"demo":true}'::jsonb),
  ('d120000b-0000-4000-8000-000000000003', NULL,
   'CTR-2026-1403', 'Marketing Agency Retainer Q3', 'service', 'negotiation',
   'Nova Creative', 8500000, 'NGN', NULL, NULL, '{"demo":true}'::jsonb)
ON CONFLICT (contract_number) DO NOTHING;

INSERT INTO public.contract_parties (id, contract_id, party_name, party_role, email, signed) VALUES
  ('d120000c-0000-4000-8000-000000000001', 'd120000b-0000-4000-8000-000000000001', 'HD Homes Ltd', 'vendor', 'legal@hdhomes.ng', true),
  ('d120000c-0000-4000-8000-000000000002', 'd120000b-0000-4000-8000-000000000001', 'Tunde Bakare', 'buyer', 'tunde.bakare@example.com', false),
  ('d120000c-0000-4000-8000-000000000003', 'd120000b-0000-4000-8000-000000000002', 'Apex Build Co.', 'contractor', 'ops@apexbuild.ng', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.contract_milestones (id, contract_id, title, due_date, status, amount, sort_order) VALUES
  ('d120000d-0000-4000-8000-000000000001', 'd120000b-0000-4000-8000-000000000001', 'Initial deposit', CURRENT_DATE + 7, 'pending', 9000000, 10),
  ('d120000d-0000-4000-8000-000000000002', 'd120000b-0000-4000-8000-000000000001', 'Allocation letter', CURRENT_DATE + 30, 'pending', NULL, 20),
  ('d120000d-0000-4000-8000-000000000003', 'd120000b-0000-4000-8000-000000000002', 'Foundation complete', CURRENT_DATE + 60, 'pending', 25000000, 10)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.signature_requests (id, document_id, contract_id, title, status, requester_label, due_at) VALUES
  ('d120000e-0000-4000-8000-000000000001', 'd1200004-0000-4000-8000-000000000006',
   'd120000b-0000-4000-8000-000000000001', 'Sign Sale Agreement B-14', 'sent', 'Sales Legal', now() + interval '5 days'),
  ('d120000e-0000-4000-8000-000000000002', NULL,
   'd120000b-0000-4000-8000-000000000003', 'Sign Marketing Retainer Q3', 'pending', 'Marketing', now() + interval '10 days')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.digital_signatures (id, request_id, signer_name, signer_email, status, signed_at) VALUES
  ('d120000f-0000-4000-8000-000000000001', 'd120000e-0000-4000-8000-000000000001', 'HD Homes Authorized Signatory', 'legal@hdhomes.ng', 'signed', now() - interval '1 day'),
  ('d120000f-0000-4000-8000-000000000002', 'd120000e-0000-4000-8000-000000000001', 'Tunde Bakare', 'tunde.bakare@example.com', 'pending', NULL),
  ('d120000f-0000-4000-8000-000000000003', 'd120000e-0000-4000-8000-000000000002', 'Nova Creative Director', 'director@novacreative.ng', 'pending', NULL)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ocr_processing_jobs (id, document_id, status, engine, pages, progress_pct, started_at) VALUES
  ('d1200010-0000-4000-8000-000000000001', 'd1200004-0000-4000-8000-000000000001', 'completed', 'tesseract', 4, 100, now() - interval '2 hours'),
  ('d1200010-0000-4000-8000-000000000002', 'd1200004-0000-4000-8000-000000000005', 'processing', 'tesseract', 2, 55, now() - interval '10 minutes'),
  ('d1200010-0000-4000-8000-000000000003', 'd1200004-0000-4000-8000-000000000002', 'queued', 'tesseract', 1, 0, NULL)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.extracted_document_data (id, document_id, job_id, field_key, field_value, confidence) VALUES
  ('d1200011-0000-4000-8000-000000000001', 'd1200004-0000-4000-8000-000000000001',
   'd1200010-0000-4000-8000-000000000001', 'registry_number', 'LG/REG/2024/88421', 0.94),
  ('d1200011-0000-4000-8000-000000000002', 'd1200004-0000-4000-8000-000000000001',
   'd1200010-0000-4000-8000-000000000001', 'plot_label', 'Block B', 0.88)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.digital_assets (id, title, asset_type, status, mime_type, storage_path, width_px, height_px, usage_rights, tags) VALUES
  ('d1200012-0000-4000-8000-000000000001', 'Oceanview Hero Aerial', 'image', 'active', 'image/jpeg',
   'assets/oceanview-hero.jpg', 2400, 1350, 'HD Homes internal + ads', ARRAY['brochure','hero']),
  ('d1200012-0000-4000-8000-000000000002', 'Site Progress Reel June', 'video', 'active', 'video/mp4',
   'assets/site-progress-june.mp4', 1920, 1080, 'Client portal only', ARRAY['construction']),
  ('d1200012-0000-4000-8000-000000000003', 'Brand Logo Pack 2026', 'design', 'active', 'image/svg+xml',
   'assets/logo-pack-2026.svg', NULL, NULL, 'Brand guidelines', ARRAY['brand'])
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.asset_collections (id, name, slug, description) VALUES
  ('d1200013-0000-4000-8000-000000000001', 'Q3 Campaign Kit', 'q3-campaign-kit', 'Marketing assets for Q3 launch'),
  ('d1200013-0000-4000-8000-000000000002', 'Site Media Library', 'site-media', 'Construction progress media')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.asset_collection_items (id, collection_id, asset_id, sort_order) VALUES
  ('d1200014-0000-4000-8000-000000000001', 'd1200013-0000-4000-8000-000000000001', 'd1200012-0000-4000-8000-000000000001', 10),
  ('d1200014-0000-4000-8000-000000000002', 'd1200013-0000-4000-8000-000000000001', 'd1200012-0000-4000-8000-000000000003', 20),
  ('d1200014-0000-4000-8000-000000000003', 'd1200013-0000-4000-8000-000000000002', 'd1200012-0000-4000-8000-000000000002', 10)
ON CONFLICT DO NOTHING;

INSERT INTO public.document_shares (id, document_id, share_token, recipient_label, recipient_email, access_level, expires_at) VALUES
  ('d1200015-0000-4000-8000-000000000001', 'd1200004-0000-4000-8000-000000000003',
   'shr_d120a1', 'Open House Guests', NULL, 'view', now() + interval '14 days'),
  ('d1200015-0000-4000-8000-000000000002', 'd1200004-0000-4000-8000-000000000005',
   'shr_d120a2', 'Ngozi Adeyemi', 'ngozi.adeyemi@example.com', 'download', now() + interval '7 days')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.retention_policies (id, name, slug, category_slug, retain_months, action_on_expiry) VALUES
  ('d1200016-0000-4000-8000-000000000001', 'Financial Records 7y', 'finance-7y', 'finance-invoice', 84, 'archive'),
  ('d1200016-0000-4000-8000-000000000002', 'HR Policies Active', 'hr-active', 'hr-policy', 36, 'review'),
  ('d1200016-0000-4000-8000-000000000003', 'Marketing Collateral 2y', 'marketing-2y', 'marketing-brochure', 24, 'archive')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.archival_records (id, document_id, policy_id, status, scheduled_at, note) VALUES
  ('d1200017-0000-4000-8000-000000000001', 'd1200004-0000-4000-8000-000000000005',
   'd1200016-0000-4000-8000-000000000001', 'scheduled', now() + interval '90 days', 'Retention alert seeded for finance invoice'),
  ('d1200017-0000-4000-8000-000000000002', 'd1200004-0000-4000-8000-000000000003',
   'd1200016-0000-4000-8000-000000000003', 'scheduled', now() + interval '180 days', 'Marketing brochure retention window')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.document_search_index (id, document_id, search_text, keywords) VALUES
  ('d1200018-0000-4000-8000-000000000001', 'd1200004-0000-4000-8000-000000000001',
   'lekki phase 2 block b title deed registry', ARRAY['title','deed','lekki']),
  ('d1200018-0000-4000-8000-000000000002', 'd1200004-0000-4000-8000-000000000006',
   'sale agreement plot b14 oceanview signature', ARRAY['contract','sale','signature'])
ON CONFLICT DO NOTHING;

INSERT INTO public.document_reports (id, title, report_type, period_label, summary, metrics) VALUES
  ('d1200019-0000-4000-8000-000000000001', 'Document Usage Weekly', 'usage', 'W28 2026',
   'Most viewed: marketing brochure; highest sensitivity downloads: title deed.',
   '{"views":128,"downloads":34,"shares":9}'::jsonb),
  ('d1200019-0000-4000-8000-000000000002', 'Contract Pipeline', 'contracts', 'Jul 2026',
   '1 pending signature, 1 active construction, 1 negotiation.',
   '{"pending_signature":1,"active":1,"negotiation":1}'::jsonb)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.document_activity_logs (id, document_id, action, summary, actor_label, occurred_at) VALUES
  ('d120001a-0000-4000-8000-000000000001', 'd1200004-0000-4000-8000-000000000006',
   'workflow_started', 'Sale Agreement B-14 entered approval workflow', 'Sales Legal', now() - interval '3 hours'),
  ('d120001a-0000-4000-8000-000000000002', 'd1200004-0000-4000-8000-000000000001',
   'ocr_completed', 'OCR completed for title deed (4 pages)', 'System', now() - interval '2 hours'),
  ('d120001a-0000-4000-8000-000000000003', 'd1200004-0000-4000-8000-000000000003',
   'shared', 'Brochure shared for open-house guests', 'Marketing', now() - interval '1 hour'),
  ('d120001a-0000-4000-8000-000000000004', NULL,
   'retention_alert', 'Finance invoice retention window scheduled', 'Compliance', now() - interval '30 minutes')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.document_notifications (id, title, body, severity, related_document_id) VALUES
  ('d120001b-0000-4000-8000-000000000001', 'Signature pending', 'Buyer signature still pending on Sale Agreement B-14', 'warning',
   'd1200004-0000-4000-8000-000000000006'),
  ('d120001b-0000-4000-8000-000000000002', 'OCR queue', 'Construction drawing stub queued for OCR', 'info',
   'd1200004-0000-4000-8000-000000000002'),
  ('d120001b-0000-4000-8000-000000000003', 'Retention alert', 'Finance invoice archival scheduled in 90 days', 'critical',
   'd1200004-0000-4000-8000-000000000005')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.document_ai_insights (id, title, body, insight_type, confidence_pct, editable, disclaimer, related_document_id) VALUES
  ('d120001c-0000-4000-8000-000000000001',
   'Contract risk — pending buyer signature',
   'Sale Agreement B-14 has vendor signed but buyer pending. Recommend gentle reminder within 48 hours to avoid allocation delay.',
   'contract_risk', 82, true, 'AI-generated — editable / advisory',
   'd1200004-0000-4000-8000-000000000006'),
  ('d120001c-0000-4000-8000-000000000002',
   'OCR backlog advisory',
   'Two jobs are active/queued. Prioritize invoice OCR before month-end finance close.',
   'ops', 74, true, 'AI-generated — editable / advisory', NULL),
  ('d120001c-0000-4000-8000-000000000003',
   'Retention compliance watch',
   'One finance archival is scheduled. Confirm no active disputes before auto-archive.',
   'compliance', 79, true, 'AI-generated — editable / advisory',
   'd1200004-0000-4000-8000-000000000005')
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.document_folders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_metadata ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_tag_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_workflows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_workflow_steps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_approvals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contract_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contract_parties ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contract_milestones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contract_amendments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.signature_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.digital_signatures ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ocr_processing_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.extracted_document_data ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.digital_assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.asset_collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.asset_collection_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.asset_usage_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_shares ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.retention_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.archival_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_search_index ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_ai_insights ENABLE ROW LEVEL SECURITY;

-- Helper macro pattern: select with documents.read; write with module permission
DROP POLICY IF EXISTS document_folders_select ON public.document_folders;
DROP POLICY IF EXISTS document_folders_write ON public.document_folders;
CREATE POLICY document_folders_select ON public.document_folders FOR SELECT
  USING (public.has_permission('documents.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY document_folders_write ON public.document_folders FOR ALL
  USING (public.has_permission('documents.write', auth.uid()) OR public.has_permission('documents.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('documents.write', auth.uid()) OR public.has_permission('documents.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS document_categories_select ON public.document_categories;
DROP POLICY IF EXISTS document_categories_write ON public.document_categories;
CREATE POLICY document_categories_select ON public.document_categories FOR SELECT
  USING (public.has_permission('documents.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY document_categories_write ON public.document_categories FOR ALL
  USING (public.has_permission('documents.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('documents.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS document_tags_select ON public.document_tags;
DROP POLICY IF EXISTS document_tags_write ON public.document_tags;
CREATE POLICY document_tags_select ON public.document_tags FOR SELECT
  USING (public.has_permission('documents.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY document_tags_write ON public.document_tags FOR ALL
  USING (public.has_permission('documents.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('documents.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS documents_select ON public.documents;
DROP POLICY IF EXISTS documents_write ON public.documents;
CREATE POLICY documents_select ON public.documents FOR SELECT
  USING (public.has_permission('documents.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY documents_write ON public.documents FOR ALL
  USING (public.has_permission('documents.write', auth.uid()) OR public.has_permission('documents.upload', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('documents.write', auth.uid()) OR public.has_permission('documents.upload', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS document_versions_select ON public.document_versions;
DROP POLICY IF EXISTS document_versions_write ON public.document_versions;
CREATE POLICY document_versions_select ON public.document_versions FOR SELECT
  USING (public.has_permission('documents.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY document_versions_write ON public.document_versions FOR ALL
  USING (public.has_permission('documents.write', auth.uid()) OR public.has_permission('documents.upload', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('documents.write', auth.uid()) OR public.has_permission('documents.upload', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS document_metadata_select ON public.document_metadata;
DROP POLICY IF EXISTS document_metadata_write ON public.document_metadata;
CREATE POLICY document_metadata_select ON public.document_metadata FOR SELECT
  USING (public.has_permission('documents.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY document_metadata_write ON public.document_metadata FOR ALL
  USING (public.has_permission('documents.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('documents.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS document_tag_links_select ON public.document_tag_links;
DROP POLICY IF EXISTS document_tag_links_write ON public.document_tag_links;
CREATE POLICY document_tag_links_select ON public.document_tag_links FOR SELECT
  USING (public.has_permission('documents.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY document_tag_links_write ON public.document_tag_links FOR ALL
  USING (public.has_permission('documents.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('documents.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS document_permissions_select ON public.document_permissions;
DROP POLICY IF EXISTS document_permissions_write ON public.document_permissions;
CREATE POLICY document_permissions_select ON public.document_permissions FOR SELECT
  USING (public.has_permission('documents.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY document_permissions_write ON public.document_permissions FOR ALL
  USING (public.has_permission('documents.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('documents.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS document_workflows_select ON public.document_workflows;
DROP POLICY IF EXISTS document_workflows_write ON public.document_workflows;
CREATE POLICY document_workflows_select ON public.document_workflows FOR SELECT
  USING (public.has_permission('documents.read', auth.uid()) OR public.has_permission('documents.approve', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY document_workflows_write ON public.document_workflows FOR ALL
  USING (public.has_permission('documents.approve', auth.uid()) OR public.has_permission('documents.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('documents.approve', auth.uid()) OR public.has_permission('documents.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS document_workflow_steps_select ON public.document_workflow_steps;
DROP POLICY IF EXISTS document_workflow_steps_write ON public.document_workflow_steps;
CREATE POLICY document_workflow_steps_select ON public.document_workflow_steps FOR SELECT
  USING (public.has_permission('documents.read', auth.uid()) OR public.has_permission('documents.approve', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY document_workflow_steps_write ON public.document_workflow_steps FOR ALL
  USING (public.has_permission('documents.approve', auth.uid()) OR public.has_permission('documents.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('documents.approve', auth.uid()) OR public.has_permission('documents.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS document_approvals_select ON public.document_approvals;
DROP POLICY IF EXISTS document_approvals_write ON public.document_approvals;
CREATE POLICY document_approvals_select ON public.document_approvals FOR SELECT
  USING (public.has_permission('documents.approve', auth.uid()) OR public.has_permission('documents.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY document_approvals_write ON public.document_approvals FOR ALL
  USING (public.has_permission('documents.approve', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('documents.approve', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS document_comments_select ON public.document_comments;
DROP POLICY IF EXISTS document_comments_write ON public.document_comments;
CREATE POLICY document_comments_select ON public.document_comments FOR SELECT
  USING (public.has_permission('documents.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY document_comments_write ON public.document_comments FOR ALL
  USING (public.has_permission('documents.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('documents.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS contract_records_select ON public.contract_records;
DROP POLICY IF EXISTS contract_records_write ON public.contract_records;
CREATE POLICY contract_records_select ON public.contract_records FOR SELECT
  USING (public.has_permission('documents.contracts', auth.uid()) OR public.has_permission('documents.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY contract_records_write ON public.contract_records FOR ALL
  USING (public.has_permission('documents.contracts', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('documents.contracts', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS contract_parties_select ON public.contract_parties;
DROP POLICY IF EXISTS contract_parties_write ON public.contract_parties;
CREATE POLICY contract_parties_select ON public.contract_parties FOR SELECT
  USING (public.has_permission('documents.contracts', auth.uid()) OR public.has_permission('documents.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY contract_parties_write ON public.contract_parties FOR ALL
  USING (public.has_permission('documents.contracts', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('documents.contracts', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS contract_milestones_select ON public.contract_milestones;
DROP POLICY IF EXISTS contract_milestones_write ON public.contract_milestones;
CREATE POLICY contract_milestones_select ON public.contract_milestones FOR SELECT
  USING (public.has_permission('documents.contracts', auth.uid()) OR public.has_permission('documents.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY contract_milestones_write ON public.contract_milestones FOR ALL
  USING (public.has_permission('documents.contracts', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('documents.contracts', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS contract_amendments_select ON public.contract_amendments;
DROP POLICY IF EXISTS contract_amendments_write ON public.contract_amendments;
CREATE POLICY contract_amendments_select ON public.contract_amendments FOR SELECT
  USING (public.has_permission('documents.contracts', auth.uid()) OR public.has_permission('documents.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY contract_amendments_write ON public.contract_amendments FOR ALL
  USING (public.has_permission('documents.contracts', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('documents.contracts', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS signature_requests_select ON public.signature_requests;
DROP POLICY IF EXISTS signature_requests_write ON public.signature_requests;
CREATE POLICY signature_requests_select ON public.signature_requests FOR SELECT
  USING (public.has_permission('documents.signatures', auth.uid()) OR public.has_permission('documents.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY signature_requests_write ON public.signature_requests FOR ALL
  USING (public.has_permission('documents.signatures', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('documents.signatures', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS digital_signatures_select ON public.digital_signatures;
DROP POLICY IF EXISTS digital_signatures_write ON public.digital_signatures;
CREATE POLICY digital_signatures_select ON public.digital_signatures FOR SELECT
  USING (public.has_permission('documents.signatures', auth.uid()) OR public.has_permission('documents.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY digital_signatures_write ON public.digital_signatures FOR ALL
  USING (public.has_permission('documents.signatures', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('documents.signatures', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ocr_processing_jobs_select ON public.ocr_processing_jobs;
DROP POLICY IF EXISTS ocr_processing_jobs_write ON public.ocr_processing_jobs;
CREATE POLICY ocr_processing_jobs_select ON public.ocr_processing_jobs FOR SELECT
  USING (public.has_permission('documents.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ocr_processing_jobs_write ON public.ocr_processing_jobs FOR ALL
  USING (public.has_permission('documents.write', auth.uid()) OR public.has_permission('documents.ai', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('documents.write', auth.uid()) OR public.has_permission('documents.ai', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS extracted_document_data_select ON public.extracted_document_data;
DROP POLICY IF EXISTS extracted_document_data_write ON public.extracted_document_data;
CREATE POLICY extracted_document_data_select ON public.extracted_document_data FOR SELECT
  USING (public.has_permission('documents.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY extracted_document_data_write ON public.extracted_document_data FOR ALL
  USING (public.has_permission('documents.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('documents.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS digital_assets_select ON public.digital_assets;
DROP POLICY IF EXISTS digital_assets_write ON public.digital_assets;
CREATE POLICY digital_assets_select ON public.digital_assets FOR SELECT
  USING (public.has_permission('documents.dam', auth.uid()) OR public.has_permission('documents.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY digital_assets_write ON public.digital_assets FOR ALL
  USING (public.has_permission('documents.dam', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('documents.dam', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS asset_collections_select ON public.asset_collections;
DROP POLICY IF EXISTS asset_collections_write ON public.asset_collections;
CREATE POLICY asset_collections_select ON public.asset_collections FOR SELECT
  USING (public.has_permission('documents.dam', auth.uid()) OR public.has_permission('documents.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY asset_collections_write ON public.asset_collections FOR ALL
  USING (public.has_permission('documents.dam', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('documents.dam', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS asset_collection_items_select ON public.asset_collection_items;
DROP POLICY IF EXISTS asset_collection_items_write ON public.asset_collection_items;
CREATE POLICY asset_collection_items_select ON public.asset_collection_items FOR SELECT
  USING (public.has_permission('documents.dam', auth.uid()) OR public.has_permission('documents.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY asset_collection_items_write ON public.asset_collection_items FOR ALL
  USING (public.has_permission('documents.dam', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('documents.dam', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS asset_usage_logs_select ON public.asset_usage_logs;
DROP POLICY IF EXISTS asset_usage_logs_write ON public.asset_usage_logs;
CREATE POLICY asset_usage_logs_select ON public.asset_usage_logs FOR SELECT
  USING (public.has_permission('documents.dam', auth.uid()) OR public.has_permission('documents.analytics', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY asset_usage_logs_write ON public.asset_usage_logs FOR ALL
  USING (public.has_permission('documents.dam', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('documents.dam', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS document_shares_select ON public.document_shares;
DROP POLICY IF EXISTS document_shares_write ON public.document_shares;
CREATE POLICY document_shares_select ON public.document_shares FOR SELECT
  USING (public.has_permission('documents.share', auth.uid()) OR public.has_permission('documents.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY document_shares_write ON public.document_shares FOR ALL
  USING (public.has_permission('documents.share', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('documents.share', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS retention_policies_select ON public.retention_policies;
DROP POLICY IF EXISTS retention_policies_write ON public.retention_policies;
CREATE POLICY retention_policies_select ON public.retention_policies FOR SELECT
  USING (public.has_permission('documents.retention', auth.uid()) OR public.has_permission('documents.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY retention_policies_write ON public.retention_policies FOR ALL
  USING (public.has_permission('documents.retention', auth.uid()) OR public.has_permission('documents.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('documents.retention', auth.uid()) OR public.has_permission('documents.admin', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS archival_records_select ON public.archival_records;
DROP POLICY IF EXISTS archival_records_write ON public.archival_records;
CREATE POLICY archival_records_select ON public.archival_records FOR SELECT
  USING (public.has_permission('documents.archive', auth.uid()) OR public.has_permission('documents.retention', auth.uid()) OR public.has_permission('documents.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY archival_records_write ON public.archival_records FOR ALL
  USING (public.has_permission('documents.archive', auth.uid()) OR public.has_permission('documents.retention', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('documents.archive', auth.uid()) OR public.has_permission('documents.retention', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS document_search_index_select ON public.document_search_index;
DROP POLICY IF EXISTS document_search_index_write ON public.document_search_index;
CREATE POLICY document_search_index_select ON public.document_search_index FOR SELECT
  USING (public.has_permission('documents.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY document_search_index_write ON public.document_search_index FOR ALL
  USING (public.has_permission('documents.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('documents.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS document_reports_select ON public.document_reports;
DROP POLICY IF EXISTS document_reports_write ON public.document_reports;
CREATE POLICY document_reports_select ON public.document_reports FOR SELECT
  USING (public.has_permission('documents.reports', auth.uid()) OR public.has_permission('documents.analytics', auth.uid()) OR public.has_permission('documents.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY document_reports_write ON public.document_reports FOR ALL
  USING (public.has_permission('documents.reports', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('documents.reports', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS document_activity_logs_select ON public.document_activity_logs;
DROP POLICY IF EXISTS document_activity_logs_write ON public.document_activity_logs;
CREATE POLICY document_activity_logs_select ON public.document_activity_logs FOR SELECT
  USING (public.has_permission('documents.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY document_activity_logs_write ON public.document_activity_logs FOR ALL
  USING (public.has_permission('documents.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('documents.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS document_notifications_select ON public.document_notifications;
DROP POLICY IF EXISTS document_notifications_write ON public.document_notifications;
CREATE POLICY document_notifications_select ON public.document_notifications FOR SELECT
  USING (public.has_permission('documents.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY document_notifications_write ON public.document_notifications FOR ALL
  USING (public.has_permission('documents.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('documents.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS document_ai_insights_select ON public.document_ai_insights;
DROP POLICY IF EXISTS document_ai_insights_write ON public.document_ai_insights;
CREATE POLICY document_ai_insights_select ON public.document_ai_insights FOR SELECT
  USING (public.has_permission('documents.ai', auth.uid()) OR public.has_permission('documents.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY document_ai_insights_write ON public.document_ai_insights FOR ALL
  USING (public.has_permission('documents.ai', auth.uid()) OR public.has_permission('documents.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('documents.ai', auth.uid()) OR public.has_permission('documents.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE ON
  public.document_folders,
  public.document_categories,
  public.document_tags,
  public.documents,
  public.document_versions,
  public.document_metadata,
  public.document_tag_links,
  public.document_permissions,
  public.document_workflows,
  public.document_workflow_steps,
  public.document_approvals,
  public.document_comments,
  public.contract_records,
  public.contract_parties,
  public.contract_milestones,
  public.contract_amendments,
  public.signature_requests,
  public.digital_signatures,
  public.ocr_processing_jobs,
  public.extracted_document_data,
  public.digital_assets,
  public.asset_collections,
  public.asset_collection_items,
  public.asset_usage_logs,
  public.document_shares,
  public.retention_policies,
  public.archival_records,
  public.document_search_index,
  public.document_reports,
  public.document_activity_logs,
  public.document_notifications,
  public.document_ai_insights
TO authenticated;

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'documents',
    'document_approvals',
    'signature_requests',
    'ocr_processing_jobs',
    'document_activity_logs',
    'document_notifications'
  ]
  LOOP
    BEGIN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    EXCEPTION
      WHEN duplicate_object THEN NULL;
      WHEN undefined_object THEN NULL;
    END;
  END LOOP;
END $$;

COMMIT;
