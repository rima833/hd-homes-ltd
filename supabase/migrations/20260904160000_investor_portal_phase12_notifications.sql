-- Phase 12 — Investor notifications
-- 1) Owner mark-read via RPC only (no free-form column updates)
-- 2) Admin publish with deep-link metadata
-- 3) Seed/backfill route + category in metadata for demo rows

-- ---------------------------------------------------------------------------
-- Remove owner UPDATE that allowed rewriting title/body/metadata
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS investor_notifications_portal_update
  ON public.investor_notifications;

-- Staff / permission write remains via investor_notifications_write.
-- Ensure staff path includes is_staff() for desks without investors.write.
DROP POLICY IF EXISTS investor_notifications_write ON public.investor_notifications;
CREATE POLICY investor_notifications_write ON public.investor_notifications
  FOR ALL TO authenticated
  USING (
    public.is_staff()
    OR public.has_permission('investors.write', auth.uid())
    OR public.has_permission('investors.notify', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.is_staff()
    OR public.has_permission('investors.write', auth.uid())
    OR public.has_permission('investors.notify', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

-- Owner SELECT already covered by investor_notifications_portal_owner.

-- ---------------------------------------------------------------------------
-- Mark one/all notifications read (owner or staff)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.investor_mark_notifications_read(
  p_notification_ids uuid[] DEFAULT NULL
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_investor_id uuid := public.investor_id_for_user(auth.uid());
  v_count integer := 0;
BEGIN
  IF v_investor_id IS NULL AND NOT public.is_staff() THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  IF p_notification_ids IS NULL OR cardinality(p_notification_ids) = 0 THEN
    -- Mark all unread for the current investor
    IF v_investor_id IS NULL THEN
      RAISE EXCEPTION 'investor_not_found';
    END IF;
    UPDATE public.investor_notifications n
    SET is_read = true
    WHERE n.investor_id = v_investor_id
      AND n.is_read = false;
    GET DIAGNOSTICS v_count = ROW_COUNT;
  ELSE
    UPDATE public.investor_notifications n
    SET is_read = true
    WHERE n.id = ANY(p_notification_ids)
      AND n.is_read = false
      AND (
        n.investor_id = v_investor_id
        OR public.is_staff()
        OR public.has_permission('investors.write', auth.uid())
        OR public.has_role('super_admin', auth.uid())
      );
    GET DIAGNOSTICS v_count = ROW_COUNT;
  END IF;

  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.investor_mark_notifications_read(uuid[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.investor_mark_notifications_read(uuid[]) TO authenticated;

COMMENT ON FUNCTION public.investor_mark_notifications_read(uuid[]) IS
  'Owner/staff mark investor_notifications read; NULL ids = mark all for current investor (Phase 12).';

-- ---------------------------------------------------------------------------
-- Admin publish — single investor notification with deep-link metadata
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_publish_investor_notification(
  p_investor_id uuid,
  p_title text,
  p_body text DEFAULT NULL,
  p_route text DEFAULT NULL,
  p_category text DEFAULT 'general',
  p_channel text DEFAULT 'in_app',
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_id uuid;
  v_title text := NULLIF(trim(COALESCE(p_title, '')), '');
  v_channel text := lower(trim(COALESCE(p_channel, 'in_app')));
  v_category text := lower(trim(COALESCE(p_category, 'general')));
  v_route text := NULLIF(trim(COALESCE(p_route, '')), '');
  v_meta jsonb;
BEGIN
  IF NOT (
    public.is_staff()
    OR public.has_permission('investors.write', auth.uid())
    OR public.has_permission('investors.notify', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  IF v_title IS NULL THEN
    RAISE EXCEPTION 'title_required';
  END IF;

  IF v_channel NOT IN ('email','sms','whatsapp','in_app','push') THEN
    RAISE EXCEPTION 'invalid_channel';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.investors i
    WHERE i.id = p_investor_id AND COALESCE(i.is_deleted, false) = false
  ) THEN
    RAISE EXCEPTION 'investor_not_found';
  END IF;

  -- Only allow in-app portal deep links under /investor (or absolute https later).
  IF v_route IS NOT NULL
     AND v_route NOT LIKE '/investor%'
     AND v_route NOT LIKE 'https://%' THEN
    RAISE EXCEPTION 'invalid_route';
  END IF;

  v_meta := COALESCE(p_metadata, '{}'::jsonb)
    || jsonb_build_object('category', v_category);
  IF v_route IS NOT NULL THEN
    v_meta := v_meta || jsonb_build_object('route', v_route);
  END IF;

  INSERT INTO public.investor_notifications (
    investor_id, channel, title, body, is_read, sent_at, metadata
  ) VALUES (
    p_investor_id,
    v_channel,
    v_title,
    NULLIF(trim(COALESCE(p_body, '')), ''),
    false,
    now(),
    v_meta
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_publish_investor_notification(
  uuid, text, text, text, text, text, jsonb
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_publish_investor_notification(
  uuid, text, text, text, text, text, jsonb
) TO authenticated;

COMMENT ON FUNCTION public.admin_publish_investor_notification(
  uuid, text, text, text, text, text, jsonb
) IS
  'Staff publish in-app investor notification with optional /investor deep link (Phase 12).';

-- ---------------------------------------------------------------------------
-- Backfill category + route on existing rows missing them (best-effort)
-- ---------------------------------------------------------------------------
UPDATE public.investor_notifications n
SET metadata = COALESCE(n.metadata, '{}'::jsonb) || jsonb_build_object(
  'category',
  CASE
    WHEN lower(n.title) LIKE '%dividend%'
      OR lower(n.title) LIKE '%distribution%'
      OR lower(n.title) LIKE '%payout%'
      OR lower(n.title) LIKE '%pay%'
      THEN 'payments'
    WHEN lower(n.title) LIKE '%construction%'
      OR lower(n.title) LIKE '%site%'
      THEN 'construction'
    WHEN lower(n.title) LIKE '%document%'
      OR lower(n.title) LIKE '%statement%'
      OR lower(n.title) LIKE '%report%'
      THEN 'documents'
    WHEN lower(n.title) LIKE '%kyc%'
      OR lower(n.title) LIKE '%verif%'
      THEN 'kyc'
    WHEN n.metadata ? 'announcement_id' THEN 'announcement'
    WHEN n.metadata ? 'update_id' OR n.metadata ? 'project_id' THEN 'construction'
    ELSE COALESCE(n.metadata ->> 'category', 'general')
  END,
  'route',
  CASE
    WHEN n.metadata ? 'route' AND NULLIF(n.metadata ->> 'route', '') IS NOT NULL
      THEN n.metadata ->> 'route'
    WHEN lower(n.title) LIKE '%dividend%'
      OR lower(n.title) LIKE '%distribution%'
      OR lower(n.title) LIKE '%payout%'
      OR lower(n.title) LIKE '%pay%'
      THEN '/investor/payments'
    WHEN lower(n.title) LIKE '%construction%'
      OR lower(n.title) LIKE '%site%'
      OR n.metadata ? 'update_id'
      OR n.metadata ? 'project_id'
      THEN '/investor/construction'
    WHEN lower(n.title) LIKE '%document%'
      THEN '/investor/documents'
    WHEN lower(n.title) LIKE '%statement%'
      OR lower(n.title) LIKE '%report%'
      THEN '/investor/reports'
    WHEN lower(n.title) LIKE '%kyc%'
      OR lower(n.title) LIKE '%verif%'
      THEN '/investor/settings'
    WHEN n.metadata ? 'announcement_id' THEN '/investor/notifications'
    WHEN lower(n.title) LIKE '%message%'
      OR lower(n.title) LIKE '%ticket%'
      THEN '/investor/messages'
    ELSE '/investor/notifications'
  END
)
WHERE NOT (COALESCE(n.metadata, '{}'::jsonb) ? 'route')
   OR NOT (COALESCE(n.metadata, '{}'::jsonb) ? 'category');
