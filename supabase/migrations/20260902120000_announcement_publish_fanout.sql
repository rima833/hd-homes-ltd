-- Admin Communication Center — production fan-out, public surfacing, realtime.

ALTER TABLE public.announcement_posts
  ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS recipient_count INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS surfaces_public_site BOOLEAN NOT NULL DEFAULT false;

DROP POLICY IF EXISTS announcement_posts_anon_public ON public.announcement_posts;
CREATE POLICY announcement_posts_anon_public ON public.announcement_posts
  FOR SELECT TO anon
  USING (published = true AND surfaces_public_site = true);

DROP POLICY IF EXISTS announcement_posts_admin ON public.announcement_posts;
CREATE POLICY announcement_posts_admin ON public.announcement_posts
  FOR ALL TO authenticated
  USING (
    public.has_role('admin', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR public.has_permission('support.write', auth.uid())
    OR public.has_permission('manage_settings', auth.uid())
  )
  WITH CHECK (
    public.has_role('admin', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR public.has_permission('support.write', auth.uid())
    OR public.has_permission('manage_settings', auth.uid())
  );

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.announcement_posts;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE OR REPLACE FUNCTION public.publish_announcement_post(
  p_title TEXT,
  p_body TEXT,
  p_target_audience TEXT DEFAULT 'everyone',
  p_surface_public_site BOOLEAN DEFAULT true,
  p_queue_email BOOLEAN DEFAULT false
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_post public.announcement_posts%ROWTYPE;
  v_in_app INT := 0;
  v_investor INT := 0;
  v_email INT := 0;
  v_action_url TEXT;
  v_audience TEXT := lower(trim(coalesce(p_target_audience, 'everyone')));
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;

  IF NOT (
    public.has_role('admin', v_uid)
    OR public.has_role('super_admin', v_uid)
    OR public.has_permission('support.write', v_uid)
    OR public.has_permission('manage_settings', v_uid)
  ) THEN
    RAISE EXCEPTION 'insufficient permissions';
  END IF;

  IF trim(coalesce(p_title, '')) = '' OR trim(coalesce(p_body, '')) = '' THEN
    RAISE EXCEPTION 'title and body are required';
  END IF;

  IF v_audience NOT IN ('everyone', 'clients', 'investors', 'staff') THEN
    RAISE EXCEPTION 'invalid audience';
  END IF;

  v_action_url := CASE v_audience
    WHEN 'clients' THEN '/client/notifications'
    WHEN 'investors' THEN '/investor/notifications'
    ELSE '/account/notifications'
  END;

  INSERT INTO public.announcement_posts (
    title, body, target_audience, published, published_at, created_by,
    surfaces_public_site, metadata
  ) VALUES (
    trim(p_title),
    trim(p_body),
    v_audience,
    true,
    now(),
    v_uid,
    v_audience = 'everyone' AND coalesce(p_surface_public_site, true),
    jsonb_build_object(
      'queue_email', coalesce(p_queue_email, false),
      'surfaces', CASE v_audience
        WHEN 'everyone' THEN jsonb_build_array('public_site', 'staff', 'clients', 'investors')
        WHEN 'clients' THEN jsonb_build_array('client_portal')
        WHEN 'investors' THEN jsonb_build_array('investor_portal')
        ELSE jsonb_build_array('staff_workspace')
      END
    )
  )
  RETURNING * INTO v_post;

  -- In-app: clients
  IF v_audience IN ('everyone', 'clients') THEN
    INSERT INTO public.notifications (
      user_id, title, body, channel, category, type, priority,
      template_slug, action_url, metadata, is_read, delivery_status
    )
    SELECT DISTINCT
      c.user_id,
      v_post.title,
      v_post.body,
      'in_app',
      'announcements',
      'announcement',
      'high',
      'announcement',
      '/client/notifications',
      jsonb_build_object('announcement_id', v_post.id, 'audience', v_audience),
      false,
      'delivered'
    FROM public.clients c
    WHERE c.user_id IS NOT NULL
      AND COALESCE(c.is_deleted, false) = false
      AND COALESCE(c.status, 'active') = 'active';
  END IF;

  -- In-app: staff workspace
  IF v_audience IN ('everyone', 'staff') THEN
    INSERT INTO public.notifications (
      user_id, title, body, channel, category, type, priority,
      template_slug, action_url, metadata, is_read, delivery_status
    )
    SELECT DISTINCT
      p.id,
      v_post.title,
      v_post.body,
      'in_app',
      'announcements',
      'announcement',
      'high',
      'announcement',
      '/account/notifications',
      jsonb_build_object('announcement_id', v_post.id, 'audience', v_audience),
      false,
      'delivered'
    FROM public.profiles p
    WHERE public.is_staff(p.id)
      AND COALESCE(p.is_deleted, false) = false
      AND COALESCE(p.status, 'active') = 'active'
      AND NOT EXISTS (
        SELECT 1 FROM public.notifications n
        WHERE n.user_id = p.id
          AND n.metadata ->> 'announcement_id' = v_post.id::text
      );
  END IF;

  -- In-app + investor portal inbox
  IF v_audience IN ('everyone', 'investors') THEN
    INSERT INTO public.notifications (
      user_id, title, body, channel, category, type, priority,
      template_slug, action_url, metadata, is_read, delivery_status
    )
    SELECT DISTINCT
      i.user_id,
      v_post.title,
      v_post.body,
      'in_app',
      'announcements',
      'announcement',
      'high',
      'announcement',
      '/investor/notifications',
      jsonb_build_object(
        'announcement_id', v_post.id,
        'audience', v_audience,
        'category', 'announcement',
        'route', '/investor/notifications'
      ),
      false,
      'delivered'
    FROM public.investors i
    WHERE i.user_id IS NOT NULL
      AND COALESCE(i.is_deleted, false) = false
      AND COALESCE(i.status, 'active') = 'active'
      AND NOT EXISTS (
        SELECT 1 FROM public.notifications n
        WHERE n.user_id = i.user_id
          AND n.metadata ->> 'announcement_id' = v_post.id::text
      );

    INSERT INTO public.investor_notifications (
      investor_id, channel, title, body, is_read, sent_at, metadata
    )
    SELECT DISTINCT
      i.id,
      'in_app',
      v_post.title,
      v_post.body,
      false,
      now(),
      jsonb_build_object(
        'announcement_id', v_post.id,
        'audience', v_audience,
        'category', 'announcement',
        'route', '/investor/notifications'
      )
    FROM public.investors i
    WHERE COALESCE(i.is_deleted, false) = false
      AND COALESCE(i.status, 'active') = 'active';
    GET DIAGNOSTICS v_investor = ROW_COUNT;
  END IF;

  SELECT count(DISTINCT user_id)::int INTO v_in_app
  FROM public.notifications
  WHERE metadata ->> 'announcement_id' = v_post.id::text;

  IF coalesce(p_queue_email, false) THEN
    INSERT INTO public.notification_delivery (
      user_id, channel, title, body, status
    )
    SELECT DISTINCT
      n.user_id,
      'email',
      v_post.title,
      v_post.body,
      'queued'
    FROM public.notifications n
    WHERE n.metadata ->> 'announcement_id' = v_post.id::text;
    GET DIAGNOSTICS v_email = ROW_COUNT;
  END IF;

  IF v_audience = 'everyone' AND coalesce(p_surface_public_site, true) THEN
    UPDATE public.banners
    SET status = 'inactive', updated_at = now()
    WHERE status = 'active'
      AND COALESCE(is_deleted, false) = false
      AND link_url = '/contact';

    INSERT INTO public.banners (
      title, subtitle, link_url, sort_order, status, created_by, updated_by
    ) VALUES (
      v_post.title,
      left(v_post.body, 180),
      '/contact',
      0,
      'active',
      v_uid,
      v_uid
    );
  END IF;

  UPDATE public.announcement_posts
  SET
    recipient_count = v_in_app + v_investor,
    metadata = metadata || jsonb_build_object(
      'in_app_count', v_in_app,
      'investor_inbox_count', v_investor,
      'email_queued_count', v_email,
      'published_via', 'admin_communication_center'
    )
  WHERE id = v_post.id
  RETURNING * INTO v_post;

  INSERT INTO public.communication_logs (actor_id, event_type, metadata)
  VALUES (
    v_uid,
    'announcement_published',
    jsonb_build_object(
      'announcement_id', v_post.id,
      'audience', v_audience,
      'in_app_count', v_in_app,
      'investor_inbox_count', v_investor,
      'email_queued_count', v_email,
      'surfaces_public_site', v_post.surfaces_public_site
    )
  );

  RETURN jsonb_build_object(
    'announcement_id', v_post.id,
    'target_audience', v_audience,
    'recipient_count', v_post.recipient_count,
    'in_app_count', v_in_app,
    'investor_inbox_count', v_investor,
    'email_queued_count', v_email,
    'surfaces_public_site', v_post.surfaces_public_site
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.publish_announcement_post(TEXT, TEXT, TEXT, BOOLEAN, BOOLEAN)
  TO authenticated;
