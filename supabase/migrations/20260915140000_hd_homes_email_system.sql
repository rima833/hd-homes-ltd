-- HD Homes production email system foundation.
-- Extends existing queues (notification_delivery, website_form_outbox, email_templates).
-- No parallel email_events / email_deliveries tables.

BEGIN;

-- ---------------------------------------------------------------------------
-- email_templates extensions
-- ---------------------------------------------------------------------------
ALTER TABLE public.email_templates
  ADD COLUMN IF NOT EXISTS category text NOT NULL DEFAULT 'system',
  ADD COLUMN IF NOT EXISTS variables jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS is_security boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS text_body text,
  ADD COLUMN IF NOT EXISTS updated_by uuid REFERENCES auth.users(id);

CREATE INDEX IF NOT EXISTS idx_email_templates_category
  ON public.email_templates(category, is_active);

-- ---------------------------------------------------------------------------
-- notification_delivery extensions
-- ---------------------------------------------------------------------------
ALTER TABLE public.notification_delivery
  ADD COLUMN IF NOT EXISTS recipient_email text,
  ADD COLUMN IF NOT EXISTS template_slug text,
  ADD COLUMN IF NOT EXISTS provider_message_id text,
  ADD COLUMN IF NOT EXISTS payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS html_body text,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

ALTER TABLE public.notification_delivery
  ALTER COLUMN user_id DROP NOT NULL;

CREATE INDEX IF NOT EXISTS idx_notification_delivery_email_queue
  ON public.notification_delivery(status, created_at)
  WHERE channel = 'email';

CREATE INDEX IF NOT EXISTS idx_notification_delivery_template
  ON public.notification_delivery(template_slug, created_at DESC);

-- ---------------------------------------------------------------------------
-- website_form_outbox delivery fields
-- ---------------------------------------------------------------------------
ALTER TABLE public.website_form_outbox
  ADD COLUMN IF NOT EXISTS provider text,
  ADD COLUMN IF NOT EXISTS provider_message_id text,
  ADD COLUMN IF NOT EXISTS error_message text,
  ADD COLUMN IF NOT EXISTS attempt_count int NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS sent_at timestamptz,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

-- ---------------------------------------------------------------------------
-- Brand + integration settings (public-safe only; no secrets)
-- ---------------------------------------------------------------------------
INSERT INTO public.app_settings (key, value, category, is_public, description)
VALUES (
  'email_brand',
  jsonb_build_object(
    'logo_url', '',
    'sender_name', 'HD Homes Limited',
    'sender_email', 'no-reply@hdhomes.ng',
    'reply_to', 'support@hdhomes.ng',
    'support_email', 'support@hdhomes.ng',
    'website_url', 'https://hdhomes.ng',
    'privacy_url', 'https://hdhomes.ng/#/trust',
    'terms_url', 'https://hdhomes.ng/#/trust',
    'primary_color', '#D4A34E',
    'company_name', 'HD Homes Limited',
    'tagline', 'Making Quality Housing Accessible'
  ),
  'email',
  true,
  'HD Homes transactional email branding (no secrets)'
)
ON CONFLICT (key) DO UPDATE
SET
  value = public.app_settings.value || EXCLUDED.value,
  category = 'email',
  is_public = true,
  description = COALESCE(public.app_settings.description, EXCLUDED.description),
  updated_at = now(),
  is_deleted = false,
  status = 'active';

UPDATE public.app_settings
SET
  value = jsonb_set(
    jsonb_set(
      COALESCE(value, '{}'::jsonb),
      '{email}',
      jsonb_build_object(
        'configured', false,
        'provider', 'resend',
        'notes', 'Resend Edge worker - set RESEND_API_KEY secret and verify domain'
      ),
      true
    ),
    '{email,provider}',
    '"resend"'::jsonb,
    true
  ),
  updated_at = now()
WHERE key = 'integrations';

-- ---------------------------------------------------------------------------
-- HTML body helper (content fragment only; shell applied in Edge)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._email_seed_body(
  p_heading text,
  p_intro text,
  p_cta_label text DEFAULT NULL,
  p_extra_html text DEFAULT ''
)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT
    '<h1 style="margin:0 0 16px;font-size:22px;line-height:1.3;color:#0F1115;font-weight:700;">'
    || p_heading || '</h1>'
    || '<p style="margin:0 0 16px;font-size:15px;line-height:1.6;color:#3F4148;">'
    || 'Hello {{first_name}},</p>'
    || '<p style="margin:0 0 20px;font-size:15px;line-height:1.6;color:#3F4148;">'
    || p_intro || '</p>'
    || COALESCE(p_extra_html, '')
    || CASE
         WHEN p_cta_label IS NULL OR length(trim(p_cta_label)) = 0 THEN ''
         ELSE
           '<p style="margin:28px 0 8px;">'
           || '<a href="{{cta_url}}" style="display:inline-block;background:#D4A34E;color:#ffffff;'
           || 'text-decoration:none;padding:14px 22px;border-radius:6px;font-weight:700;font-size:14px;">'
           || p_cta_label || '</a></p>'
           || '<p style="margin:12px 0 0;font-size:12px;line-height:1.5;color:#6B7280;">'
           || 'If the button does not work, copy and paste this link into your browser:<br>'
           || '<span style="color:#3F4148;word-break:break-all;">{{cta_url}}</span></p>'
       END;
$$;

-- ---------------------------------------------------------------------------
-- Seed transactional templates
-- ---------------------------------------------------------------------------
INSERT INTO public.email_templates (
  name, slug, subject, body_html, text_body, category, variables, is_security, is_active, metadata
)
VALUES
  (
    'Welcome',
    'welcome',
    'Welcome to HD Homes',
    public._email_seed_body(
      'Welcome to HD Homes',
      'Thank you for creating your HD Homes account. Your portal is ready - confirm your email if prompted, then explore properties, payments, and support in one place.',
      'Open HD Homes'
    ),
    'Welcome to HD Homes. Your account is ready.',
    'authentication',
    '["first_name","cta_url"]'::jsonb,
    false,
    true,
    '{"channel":"transactional"}'::jsonb
  ),
  (
    'Security alert',
    'security_alert',
    'HD Homes security alert',
    public._email_seed_body(
      'Security alert',
      '{{message}}',
      'Review account security',
      '<p style="margin:0 0 16px;font-size:13px;line-height:1.5;color:#6B7280;">If you did not perform this action, contact support immediately.</p>'
    ),
    'Security alert: {{message}}',
    'security',
    '["first_name","message","cta_url"]'::jsonb,
    true,
    true,
    '{"channel":"security"}'::jsonb
  ),
  (
    'Payment received',
    'payment_successful',
    'Payment received - HD Homes',
    public._email_seed_body(
      'Payment received',
      'We received {{payment_amount}} for {{property_name}}. You can review the receipt and payment history in your client portal.',
      'View payments'
    ),
    'We received {{payment_amount}} for {{property_name}}.',
    'finance',
    '["first_name","payment_amount","property_name","cta_url"]'::jsonb,
    false,
    true,
    '{}'::jsonb
  ),
  (
    'Payment submitted',
    'payment_submitted',
    'Payment submitted - HD Homes',
    public._email_seed_body(
      'Payment submitted',
      'We received your payment submission of {{payment_amount}} for {{property_name}}. Our finance team will verify it shortly.',
      'Track payment'
    ),
    'Payment submitted: {{payment_amount}} for {{property_name}}.',
    'finance',
    '["first_name","payment_amount","property_name","cta_url"]'::jsonb,
    false,
    true,
    '{}'::jsonb
  ),
  (
    'Payment verified',
    'payment_verified',
    'Payment verified - HD Homes',
    public._email_seed_body(
      'Payment verified',
      'Good news - your payment of {{payment_amount}} for {{property_name}} has been verified.',
      'View receipt'
    ),
    'Payment verified: {{payment_amount}} for {{property_name}}.',
    'finance',
    '["first_name","payment_amount","property_name","cta_url"]'::jsonb,
    false,
    true,
    '{}'::jsonb
  ),
  (
    'Payment rejected',
    'payment_rejected',
    'Payment update - HD Homes',
    public._email_seed_body(
      'Payment needs attention',
      'We could not verify your payment of {{payment_amount}} for {{property_name}}. {{message}}',
      'Update payment'
    ),
    'Payment rejected for {{property_name}}: {{message}}',
    'finance',
    '["first_name","payment_amount","property_name","message","cta_url"]'::jsonb,
    false,
    true,
    '{}'::jsonb
  ),
  (
    'Booking confirmed',
    'booking_confirmed',
    'Inspection booking confirmed - HD Homes',
    public._email_seed_body(
      'Booking confirmed',
      'Your booking {{booking_reference}} for {{property_name}} is confirmed.',
      'View booking'
    ),
    'Booking {{booking_reference}} for {{property_name}} is confirmed.',
    'inspections',
    '["first_name","booking_reference","property_name","cta_url"]'::jsonb,
    false,
    true,
    '{}'::jsonb
  ),
  (
    'Inspection confirmed',
    'inspection_confirmed',
    'Inspection confirmed - HD Homes',
    public._email_seed_body(
      'Inspection confirmed',
      'Your inspection for {{property_name}} is confirmed for {{scheduled_at}}.',
      'View details'
    ),
    'Inspection for {{property_name}} confirmed at {{scheduled_at}}.',
    'inspections',
    '["first_name","property_name","scheduled_at","cta_url","meeting_url"]'::jsonb,
    false,
    true,
    '{}'::jsonb
  ),
  (
    'Inspection reminder',
    'inspection_reminder',
    'Inspection reminder - HD Homes',
    public._email_seed_body(
      'Inspection reminder',
      'This is a reminder that your inspection for {{property_name}} is scheduled for {{scheduled_at}}.',
      'View inspection'
    ),
    'Reminder: inspection for {{property_name}} at {{scheduled_at}}.',
    'inspections',
    '["first_name","property_name","scheduled_at","cta_url"]'::jsonb,
    false,
    true,
    '{}'::jsonb
  ),
  (
    'Support ticket created',
    'support_ticket_created',
    'Support request received - HD Homes',
    public._email_seed_body(
      'We received your request',
      'Your support ticket {{ticket_reference}} has been created. Our team will respond as soon as possible.',
      'Open ticket'
    ),
    'Support ticket {{ticket_reference}} created.',
    'support',
    '["first_name","ticket_reference","cta_url"]'::jsonb,
    false,
    true,
    '{}'::jsonb
  ),
  (
    'Support ticket updated',
    'support_ticket_updated',
    'Support update - HD Homes',
    public._email_seed_body(
      'Support ticket update',
      'There is a new update on ticket {{ticket_reference}}: {{message}}',
      'View conversation'
    ),
    'Ticket {{ticket_reference}} updated: {{message}}',
    'support',
    '["first_name","ticket_reference","message","cta_url"]'::jsonb,
    false,
    true,
    '{}'::jsonb
  ),
  (
    'Support ticket resolved',
    'support_ticket_resolved',
    'Support ticket resolved - HD Homes',
    public._email_seed_body(
      'Ticket resolved',
      'Your support ticket {{ticket_reference}} has been marked as resolved. If you still need help, reply from your portal.',
      'Open portal'
    ),
    'Ticket {{ticket_reference}} resolved.',
    'support',
    '["first_name","ticket_reference","cta_url"]'::jsonb,
    false,
    true,
    '{}'::jsonb
  ),
  (
    'Construction update',
    'construction_update',
    'Construction update - HD Homes',
    public._email_seed_body(
      'Construction update',
      'A new construction update is available for {{property_name}}: {{message}}',
      'View update'
    ),
    'Construction update for {{property_name}}: {{message}}',
    'construction',
    '["first_name","property_name","message","cta_url"]'::jsonb,
    false,
    true,
    '{}'::jsonb
  ),
  (
    'Document available',
    'document_published',
    'New document available - HD Homes',
    public._email_seed_body(
      'New document available',
      'A new document ({{document_title}}) is available in your portal.',
      'Open documents'
    ),
    'New document: {{document_title}}',
    'documents',
    '["first_name","document_title","cta_url"]'::jsonb,
    false,
    true,
    '{}'::jsonb
  ),
  (
    'Investor KYC update',
    'investor_kyc_update',
    'Investor verification update - HD Homes',
    public._email_seed_body(
      'Verification update',
      'Your investor verification status is now {{verification_status}}. {{message}}',
      'Open investor portal'
    ),
    'KYC status: {{verification_status}}',
    'investors',
    '["first_name","verification_status","message","cta_url"]'::jsonb,
    false,
    true,
    '{}'::jsonb
  ),
  (
    'Investor payment update',
    'investor_payment_update',
    'Investment payment update - HD Homes',
    public._email_seed_body(
      'Investment payment update',
      'Your investment payment of {{payment_amount}} is now {{status}}.',
      'View portfolio'
    ),
    'Investment payment {{payment_amount}} is {{status}}.',
    'investors',
    '["first_name","payment_amount","status","cta_url"]'::jsonb,
    false,
    true,
    '{}'::jsonb
  ),
  (
    'Staff invitation',
    'staff_invite',
    'You are invited to HD Homes Admin',
    public._email_seed_body(
      'You have been invited',
      'You have been invited to join HD Homes as staff. Use the secure link below to accept your invitation.',
      'Accept invitation'
    ),
    'You are invited to HD Homes Admin.',
    'staff',
    '["first_name","cta_url","role_name"]'::jsonb,
    false,
    true,
    '{}'::jsonb
  ),
  (
    'Portal invitation',
    'portal_invite',
    'You are invited to HD Homes',
    public._email_seed_body(
      'You have been invited',
      'You have been invited to the HD Homes {{portal_name}} portal. Accept the invitation to get started.',
      'Accept invitation'
    ),
    'You are invited to the HD Homes {{portal_name}} portal.',
    'staff',
    '["first_name","cta_url","portal_name"]'::jsonb,
    false,
    true,
    '{}'::jsonb
  ),
  (
    'Announcement',
    'announcement',
    '{{title}}',
    public._email_seed_body(
      '{{title}}',
      '{{body}}',
      'Learn more'
    ),
    '{{title}} - {{body}}',
    'system',
    '["first_name","title","body","cta_url"]'::jsonb,
    false,
    true,
    '{}'::jsonb
  ),
  (
    'KYC approved',
    'kyc_approved',
    'Identity verified - HD Homes',
    public._email_seed_body(
      'Identity verified',
      'Congratulations - your identity verification is approved. Status: {{verification_status}}.',
      'Continue'
    ),
    'KYC approved. Status: {{verification_status}}.',
    'authentication',
    '["first_name","verification_status","cta_url"]'::jsonb,
    false,
    true,
    '{}'::jsonb
  ),
  (
    'Website support ticket received',
    'support_ticket_received',
    'We received your message - HD Homes',
    public._email_seed_body(
      'Message received',
      'Thank you for contacting HD Homes. We received your support request and will follow up shortly.',
      'Visit HD Homes'
    ),
    'We received your support request.',
    'support',
    '["first_name","cta_url"]'::jsonb,
    false,
    true,
    '{}'::jsonb
  ),
  (
    'Career application received',
    'career_application_received',
    'Application received - HD Homes',
    public._email_seed_body(
      'Application received',
      'Thank you for applying to HD Homes. We have received your application and will review it carefully.',
      'Visit careers'
    ),
    'We received your career application.',
    'system',
    '["first_name","cta_url"]'::jsonb,
    false,
    true,
    '{}'::jsonb
  ),
  (
    'Partnership request received',
    'partnership_request_received',
    'Partnership request received - HD Homes',
    public._email_seed_body(
      'Partnership request received',
      'Thank you for your interest in partnering with HD Homes. Our team will review your request.',
      'Visit HD Homes'
    ),
    'We received your partnership request.',
    'system',
    '["first_name","cta_url"]'::jsonb,
    false,
    true,
    '{}'::jsonb
  ),
  (
    'Password changed',
    'password_changed',
    'Your HD Homes password was changed',
    public._email_seed_body(
      'Password changed',
      'Your HD Homes account password was changed successfully. If you did not make this change, contact support immediately.',
      'Secure my account'
    ),
    'Your HD Homes password was changed.',
    'security',
    '["first_name","cta_url"]'::jsonb,
    true,
    true,
    '{}'::jsonb
  ),
  (
    'Email address changed',
    'email_changed',
    'Your HD Homes email address was changed',
    public._email_seed_body(
      'Email address changed',
      'The email address on your HD Homes account was changed. If you did not request this, contact support immediately.',
      'Contact support'
    ),
    'Your HD Homes email address was changed.',
    'security',
    '["first_name","cta_url"]'::jsonb,
    true,
    true,
    '{}'::jsonb
  )
ON CONFLICT (slug) DO UPDATE
SET
  name = EXCLUDED.name,
  subject = EXCLUDED.subject,
  body_html = EXCLUDED.body_html,
  text_body = EXCLUDED.text_body,
  category = EXCLUDED.category,
  variables = EXCLUDED.variables,
  is_security = EXCLUDED.is_security,
  is_active = EXCLUDED.is_active,
  metadata = COALESCE(public.email_templates.metadata, '{}'::jsonb) || EXCLUDED.metadata,
  updated_at = now();

-- Keep notification_templates catalog aligned for in-app + email defaults
INSERT INTO public.notification_templates (
  slug, title_template, body_template, category, type, default_channels
)
VALUES
  ('payment_submitted', 'Payment submitted', 'We received your payment of {{payment_amount}} for {{property_name}}.', 'payments', 'information', ARRAY['in_app','email']),
  ('payment_verified', 'Payment verified', 'Your payment of {{payment_amount}} for {{property_name}} is verified.', 'payments', 'success', ARRAY['in_app','email']),
  ('payment_rejected', 'Payment update', 'Your payment for {{property_name}} needs attention: {{message}}', 'payments', 'warning', ARRAY['in_app','email']),
  ('inspection_confirmed', 'Inspection confirmed', 'Inspection for {{property_name}} is confirmed for {{scheduled_at}}.', 'bookings', 'success', ARRAY['in_app','email']),
  ('inspection_reminder', 'Inspection reminder', 'Reminder: inspection for {{property_name}} on {{scheduled_at}}.', 'bookings', 'information', ARRAY['in_app','email']),
  ('support_ticket_created', 'Support request received', 'Ticket {{ticket_reference}} was created.', 'support', 'information', ARRAY['in_app','email']),
  ('support_ticket_updated', 'Support update', 'Ticket {{ticket_reference}}: {{message}}', 'support', 'information', ARRAY['in_app','email']),
  ('support_ticket_resolved', 'Support ticket resolved', 'Ticket {{ticket_reference}} was resolved.', 'support', 'success', ARRAY['in_app','email']),
  ('construction_update', 'Construction update', '{{message}}', 'construction', 'information', ARRAY['in_app','email']),
  ('document_published', 'New document', '{{document_title}} is available in your portal.', 'documents', 'information', ARRAY['in_app','email']),
  ('investor_kyc_update', 'Verification update', 'Status: {{verification_status}}. {{message}}', 'kyc', 'information', ARRAY['in_app','email']),
  ('investor_payment_update', 'Investment payment', 'Payment {{payment_amount}} is {{status}}.', 'payments', 'information', ARRAY['in_app','email']),
  ('staff_invite', 'Staff invitation', 'You have been invited to HD Homes Admin.', 'account', 'information', ARRAY['email']),
  ('portal_invite', 'Portal invitation', 'You have been invited to the HD Homes portal.', 'account', 'information', ARRAY['email']),
  ('password_changed', 'Password changed', 'Your HD Homes password was changed.', 'security', 'critical', ARRAY['in_app','email']),
  ('email_changed', 'Email changed', 'Your HD Homes email address was changed.', 'security', 'critical', ARRAY['in_app','email'])
ON CONFLICT (slug) DO UPDATE
SET
  title_template = EXCLUDED.title_template,
  body_template = EXCLUDED.body_template,
  category = EXCLUDED.category,
  type = EXCLUDED.type,
  default_channels = EXCLUDED.default_channels,
  updated_at = now();

-- ---------------------------------------------------------------------------
-- RPCs
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.queue_transactional_email(
  p_template_slug text,
  p_recipient_email text,
  p_user_id uuid DEFAULT NULL,
  p_variables jsonb DEFAULT '{}'::jsonb,
  p_notification_id uuid DEFAULT NULL,
  p_payload jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_template public.email_templates%ROWTYPE;
  v_title text;
  v_body text;
  v_key text;
  v_val text;
BEGIN
  IF NULLIF(trim(COALESCE(p_template_slug, '')), '') IS NULL THEN
    RAISE EXCEPTION 'template_slug_required';
  END IF;
  IF NULLIF(trim(COALESCE(p_recipient_email, '')), '') IS NULL THEN
    RAISE EXCEPTION 'recipient_email_required';
  END IF;

  SELECT * INTO v_template
  FROM public.email_templates
  WHERE slug = trim(p_template_slug)
    AND is_active = true
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'template_not_found';
  END IF;

  v_title := v_template.subject;
  v_body := COALESCE(v_template.text_body, v_template.subject);

  FOR v_key, v_val IN
    SELECT key, value #>> '{}'
    FROM jsonb_each(COALESCE(p_variables, '{}'::jsonb))
  LOOP
    v_title := replace(v_title, '{{' || v_key || '}}', COALESCE(v_val, ''));
    v_body := replace(v_body, '{{' || v_key || '}}', COALESCE(v_val, ''));
  END LOOP;

  INSERT INTO public.notification_delivery (
    user_id,
    notification_id,
    channel,
    title,
    body,
    status,
    recipient_email,
    template_slug,
    payload
  ) VALUES (
    p_user_id,
    p_notification_id,
    'email',
    v_title,
    v_body,
    'queued',
    lower(trim(p_recipient_email)),
    v_template.slug,
    COALESCE(p_payload, '{}'::jsonb) || jsonb_build_object('variables', COALESCE(p_variables, '{}'::jsonb))
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.queue_transactional_email(text, text, uuid, jsonb, uuid, jsonb)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.queue_transactional_email(text, text, uuid, jsonb, uuid, jsonb)
  TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_list_email_deliveries(
  p_limit int DEFAULT 50,
  p_status text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_limit int := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 200);
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication_required';
  END IF;
  IF NOT (
    public.has_permission('manage_settings', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN
    RAISE EXCEPTION 'permission_denied';
  END IF;

  RETURN COALESCE(
    (
      SELECT jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC)
      FROM (
        SELECT
          d.id,
          d.user_id,
          d.recipient_email,
          d.template_slug,
          d.title,
          d.status,
          d.provider,
          d.provider_message_id,
          d.error_message,
          d.attempt_count,
          d.sent_at,
          d.created_at,
          d.payload
        FROM public.notification_delivery d
        WHERE d.channel = 'email'
          AND (
            p_status IS NULL
            OR NULLIF(trim(p_status), '') IS NULL
            OR d.status = trim(p_status)
          )
        ORDER BY d.created_at DESC
        LIMIT v_limit
      ) x
    ),
    '[]'::jsonb
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_email_deliveries(int, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_list_email_deliveries(int, text)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_email_system_status()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_brand jsonb;
  v_integrations jsonb;
  v_queued int;
  v_sent int;
  v_failed int;
  v_last_sent timestamptz;
  v_last_failed timestamptz;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication_required';
  END IF;
  IF NOT (
    public.has_permission('manage_settings', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN
    RAISE EXCEPTION 'permission_denied';
  END IF;

  SELECT value INTO v_brand
  FROM public.app_settings
  WHERE key = 'email_brand' AND COALESCE(is_deleted, false) = false
  LIMIT 1;

  SELECT value INTO v_integrations
  FROM public.app_settings
  WHERE key = 'integrations' AND COALESCE(is_deleted, false) = false
  LIMIT 1;

  SELECT COUNT(*) INTO v_queued
  FROM public.notification_delivery
  WHERE channel = 'email' AND status = 'queued';

  SELECT COUNT(*) INTO v_sent
  FROM public.notification_delivery
  WHERE channel = 'email' AND status IN ('sent', 'delivered');

  SELECT COUNT(*) INTO v_failed
  FROM public.notification_delivery
  WHERE channel = 'email' AND status = 'failed';

  SELECT MAX(sent_at) INTO v_last_sent
  FROM public.notification_delivery
  WHERE channel = 'email' AND status IN ('sent', 'delivered');

  SELECT MAX(created_at) INTO v_last_failed
  FROM public.notification_delivery
  WHERE channel = 'email' AND status = 'failed';

  RETURN jsonb_build_object(
    'brand', COALESCE(v_brand, '{}'::jsonb),
    'provider', COALESCE(v_integrations -> 'email', '{}'::jsonb),
    'queued', v_queued,
    'sent', v_sent,
    'failed', v_failed,
    'outbox_queued', (
      SELECT COUNT(*) FROM public.website_form_outbox WHERE status = 'queued'
    ),
    'template_count', (
      SELECT COUNT(*) FROM public.email_templates WHERE is_active = true
    ),
    'last_sent_at', v_last_sent,
    'last_failed_at', v_last_failed,
    'checked_at', now()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_email_system_status() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_email_system_status() TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_upsert_email_template(
  p_slug text,
  p_name text,
  p_subject text,
  p_body_html text,
  p_text_body text DEFAULT NULL,
  p_category text DEFAULT 'system',
  p_variables jsonb DEFAULT '[]'::jsonb,
  p_is_active boolean DEFAULT true
)
RETURNS public.email_templates
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.email_templates;
  v_existing public.email_templates;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication_required';
  END IF;
  IF NOT (
    public.has_permission('manage_settings', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  ) THEN
    RAISE EXCEPTION 'permission_denied';
  END IF;

  SELECT * INTO v_existing
  FROM public.email_templates
  WHERE slug = trim(p_slug)
  LIMIT 1;

  IF FOUND AND v_existing.is_security AND COALESCE(p_is_active, true) = false THEN
    RAISE EXCEPTION 'security_template_cannot_be_disabled';
  END IF;

  INSERT INTO public.email_templates AS t (
    name, slug, subject, body_html, text_body, category, variables, is_active, updated_by, updated_at
  )
  VALUES (
    trim(p_name),
    trim(p_slug),
    trim(p_subject),
    p_body_html,
    p_text_body,
    COALESCE(NULLIF(trim(p_category), ''), 'system'),
    COALESCE(p_variables, '[]'::jsonb),
    COALESCE(p_is_active, true),
    auth.uid(),
    now()
  )
  ON CONFLICT (slug) DO UPDATE
  SET
    name = EXCLUDED.name,
    subject = EXCLUDED.subject,
    body_html = EXCLUDED.body_html,
    text_body = EXCLUDED.text_body,
    category = EXCLUDED.category,
    variables = EXCLUDED.variables,
    is_active = CASE
      WHEN t.is_security THEN true
      ELSE EXCLUDED.is_active
    END,
    updated_by = auth.uid(),
    updated_at = now()
  RETURNING * INTO v_row;

  INSERT INTO public.communication_logs (actor_id, event_type, metadata)
  VALUES (
    auth.uid(),
    'email_template_upserted',
    jsonb_build_object('slug', v_row.slug, 'is_active', v_row.is_active)
  );

  RETURN v_row;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_upsert_email_template(
  text, text, text, text, text, text, jsonb, boolean
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_upsert_email_template(
  text, text, text, text, text, text, jsonb, boolean
) TO authenticated;

-- ---------------------------------------------------------------------------
-- RLS hardening for email admin surfaces
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS email_templates_select ON public.email_templates;
DROP POLICY IF EXISTS email_templates_write ON public.email_templates;
CREATE POLICY email_templates_select ON public.email_templates
  FOR SELECT TO authenticated
  USING (
    public.has_permission('manage_settings', auth.uid())
    OR public.has_permission('manage_marketing', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR public.is_staff(auth.uid())
  );
CREATE POLICY email_templates_write ON public.email_templates
  FOR ALL TO authenticated
  USING (
    public.has_permission('manage_settings', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('manage_settings', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

DROP POLICY IF EXISTS notification_delivery_select_own ON public.notification_delivery;
DROP POLICY IF EXISTS notification_delivery_insert_own ON public.notification_delivery;
DROP POLICY IF EXISTS notification_delivery_admin ON public.notification_delivery;

CREATE POLICY notification_delivery_select_own ON public.notification_delivery
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR public.has_permission('manage_settings', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

CREATE POLICY notification_delivery_insert_own ON public.notification_delivery
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    OR public.has_permission('manage_settings', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

CREATE POLICY notification_delivery_admin_update ON public.notification_delivery
  FOR UPDATE TO authenticated
  USING (
    public.has_permission('manage_settings', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('manage_settings', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'notification_delivery'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notification_delivery;
  END IF;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

COMMIT;
