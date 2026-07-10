-- Migration 006: Storage buckets and access policies

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('property-images', 'property-images', true, 10485760, ARRAY['image/jpeg','image/png','image/webp']),
  ('property-videos', 'property-videos', true, 52428800, ARRAY['video/mp4','video/webm']),
  ('estate-images', 'estate-images', true, 10485760, ARRAY['image/jpeg','image/png','image/webp']),
  ('estate-masterplans', 'estate-masterplans', true, 20971520, ARRAY['image/jpeg','image/png','application/pdf']),
  ('blog-images', 'blog-images', true, 10485760, ARRAY['image/jpeg','image/png','image/webp']),
  ('gallery', 'gallery', true, 10485760, ARRAY['image/jpeg','image/png','image/webp']),
  ('avatars', 'avatars', true, 5242880, ARRAY['image/jpeg','image/png','image/webp']),
  ('marketing', 'marketing', true, 10485760, ARRAY['image/jpeg','image/png','image/webp']),
  ('team', 'team', true, 5242880, ARRAY['image/jpeg','image/png','image/webp']),
  ('logos', 'logos', true, 2097152, ARRAY['image/jpeg','image/png','image/svg+xml','image/webp']),
  ('downloads', 'downloads', true, 20971520, ARRAY['application/pdf']),
  ('construction-images', 'construction-images', true, 10485760, ARRAY['image/jpeg','image/png','image/webp']),
  ('construction-videos', 'construction-videos', true, 104857600, ARRAY['video/mp4','video/webm']),
  ('documents', 'documents', false, 20971520, ARRAY['application/pdf']),
  ('contracts', 'contracts', false, 20971520, ARRAY['application/pdf']),
  ('receipts', 'receipts', false, 10485760, ARRAY['application/pdf','image/jpeg','image/png']),
  ('allocation-letters', 'allocation-letters', false, 20971520, ARRAY['application/pdf']),
  ('backups', 'backups', false, 104857600, NULL)
ON CONFLICT (id) DO NOTHING;

-- Public buckets: anyone can read; staff can upload
CREATE POLICY storage_public_read ON storage.objects
  FOR SELECT USING (bucket_id IN (
    'property-images','property-videos','estate-images','estate-masterplans',
    'blog-images','gallery','avatars','marketing','team','logos','downloads',
    'construction-images','construction-videos'
  ));

CREATE POLICY storage_public_upload_staff ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id IN (
      'property-images','property-videos','estate-images','estate-masterplans',
      'blog-images','gallery','avatars','marketing','team','logos','downloads',
      'construction-images','construction-videos'
    )
    AND public.is_staff()
  );

CREATE POLICY storage_public_update_staff ON storage.objects
  FOR UPDATE USING (public.is_staff());

CREATE POLICY storage_public_delete_staff ON storage.objects
  FOR DELETE USING (
    public.has_role('super_admin') OR public.has_role('admin')
  );

-- Private buckets: owner folder or authorized staff
CREATE POLICY storage_private_read ON storage.objects
  FOR SELECT USING (
    bucket_id IN ('documents','contracts','receipts','allocation-letters','backups')
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR public.has_permission('manage_payments')
      OR public.has_role('super_admin')
    )
  );

CREATE POLICY storage_private_upload ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id IN ('documents','contracts','receipts','allocation-letters')
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR public.has_permission('manage_payments')
      OR public.is_staff()
    )
  );

CREATE POLICY storage_private_update ON storage.objects
  FOR UPDATE USING (
    bucket_id IN ('documents','contracts','receipts','allocation-letters')
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR public.has_permission('manage_payments')
    )
  );

CREATE POLICY storage_private_delete ON storage.objects
  FOR DELETE USING (
    public.has_role('super_admin') OR public.has_permission('manage_payments')
  );

-- Avatars: users manage own folder
CREATE POLICY storage_avatars_own ON storage.objects
  FOR ALL USING (
    bucket_id = 'avatars'
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR public.is_staff()
    )
  );
