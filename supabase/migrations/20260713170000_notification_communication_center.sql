-- Volume 3 Part 9 — Notification & Communication Center
-- Status: APPLIED remotely as notification_communication_center (approved 2026-07-13).
-- Note: extends existing public.notifications (from domain foundation) rather than recreating it.

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS category TEXT NOT NULL DEFAULT 'system',
  ADD COLUMN IF NOT EXISTS type TEXT NOT NULL DEFAULT 'information',
  ADD COLUMN IF NOT EXISTS priority TEXT NOT NULL DEFAULT 'normal',
  ADD COLUMN IF NOT EXISTS template_slug TEXT,
  ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_archived BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS delivery_status TEXT NOT NULL DEFAULT 'delivered';

CREATE INDEX IF NOT EXISTS idx_notifications_user_created
  ON public.notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON public.notifications(user_id)
  WHERE is_read = false AND is_archived = false;

CREATE TABLE IF NOT EXISTS public.notification_delivery (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  notification_id UUID REFERENCES public.notifications(id) ON DELETE SET NULL,
  channel TEXT NOT NULL,
  title TEXT,
  body TEXT,
  status TEXT NOT NULL DEFAULT 'queued',
  provider TEXT,
  error_message TEXT,
  attempt_count INT NOT NULL DEFAULT 0,
  scheduled_at TIMESTAMPTZ,
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notification_delivery_status
  ON public.notification_delivery(status, created_at);

CREATE TABLE IF NOT EXISTS public.notification_templates (
  slug TEXT PRIMARY KEY,
  title_template TEXT NOT NULL,
  body_template TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'system',
  type TEXT NOT NULL DEFAULT 'information',
  default_channels TEXT[] NOT NULL DEFAULT ARRAY['in_app'],
  is_active BOOLEAN NOT NULL DEFAULT true,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.notification_templates (slug, title_template, body_template, category, type, default_channels)
VALUES
  ('welcome', 'Welcome to HD Homes, {{first_name}}', 'Your account is ready. Complete your profile to unlock personalized property recommendations.', 'account', 'success', ARRAY['in_app','email']),
  ('kyc_approved', 'Identity verified', 'Congratulations {{first_name}} — your KYC is approved. Status: {{verification_status}}.', 'kyc', 'success', ARRAY['in_app','email']),
  ('security_alert', 'Security alert', '{{message}}', 'security', 'critical', ARRAY['in_app','email','sms']),
  ('booking_confirmed', 'Booking confirmed', 'Your booking {{booking_reference}} for {{property_name}} is confirmed.', 'bookings', 'success', ARRAY['in_app','email']),
  ('payment_successful', 'Payment received', 'We received {{payment_amount}} for {{property_name}}.', 'payments', 'success', ARRAY['in_app','email']),
  ('announcement', '{{title}}', '{{body}}', 'announcements', 'announcement', ARRAY['in_app'])
ON CONFLICT (slug) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.announcement_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  target_audience TEXT NOT NULL DEFAULT 'everyone',
  published BOOLEAN NOT NULL DEFAULT false,
  published_at TIMESTAMPTZ,
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.communication_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID REFERENCES auth.users(id),
  event_type TEXT NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.communication_campaigns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  template_slug TEXT,
  audience TEXT NOT NULL DEFAULT 'everyone',
  status TEXT NOT NULL DEFAULT 'draft',
  scheduled_at TIMESTAMPTZ,
  launched_at TIMESTAMPTZ,
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_delivery ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcement_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.communication_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.communication_campaigns ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS notifications_own ON public.notifications;
CREATE POLICY notifications_own ON public.notifications
  FOR ALL USING (
    user_id = auth.uid()
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  )
  WITH CHECK (
    user_id = auth.uid()
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS notification_delivery_own ON public.notification_delivery;
CREATE POLICY notification_delivery_own ON public.notification_delivery
  FOR SELECT USING (
    user_id = auth.uid()
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS notification_delivery_insert ON public.notification_delivery;
CREATE POLICY notification_delivery_insert ON public.notification_delivery
  FOR INSERT WITH CHECK (
    user_id = auth.uid()
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS notification_templates_read ON public.notification_templates;
CREATE POLICY notification_templates_read ON public.notification_templates
  FOR SELECT USING (true);

DROP POLICY IF EXISTS announcement_posts_read ON public.announcement_posts;
CREATE POLICY announcement_posts_read ON public.announcement_posts
  FOR SELECT USING (published = true OR public.has_role('admin') OR public.has_role('super_admin'));

DROP POLICY IF EXISTS announcement_posts_admin ON public.announcement_posts;
CREATE POLICY announcement_posts_admin ON public.announcement_posts
  FOR ALL USING (public.has_role('admin') OR public.has_role('super_admin'))
  WITH CHECK (public.has_role('admin') OR public.has_role('super_admin'));

DROP POLICY IF EXISTS communication_logs_staff ON public.communication_logs;
CREATE POLICY communication_logs_staff ON public.communication_logs
  FOR ALL USING (
    public.has_role('admin') OR public.has_role('super_admin') OR actor_id = auth.uid()
  )
  WITH CHECK (actor_id = auth.uid() OR public.has_role('admin') OR public.has_role('super_admin'));

DROP POLICY IF EXISTS communication_campaigns_admin ON public.communication_campaigns;
CREATE POLICY communication_campaigns_admin ON public.communication_campaigns
  FOR ALL USING (public.has_role('admin') OR public.has_role('super_admin'))
  WITH CHECK (public.has_role('admin') OR public.has_role('super_admin'));

GRANT SELECT, INSERT, UPDATE, DELETE ON public.notifications TO authenticated;
GRANT SELECT, INSERT ON public.notification_delivery TO authenticated;
GRANT SELECT ON public.notification_templates TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.announcement_posts TO authenticated;
GRANT SELECT, INSERT ON public.communication_logs TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.communication_campaigns TO authenticated;
