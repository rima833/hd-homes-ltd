-- Master HD Homes transactional email content.
-- The shared shell (black header, logo, gold rule, footer) is applied by the
-- Edge renderer. These rows are the inner content only.

UPDATE public.app_settings
SET value = jsonb_set(
      jsonb_set(value, '{primary_color}', '"#d6a847"'),
      '{sender_email}',
      '"no-reply@hdhomesltd.com"'
    ),
    updated_at = now()
WHERE key = 'email_brand';

UPDATE public.email_templates
SET
  body_html = replace(
    body_html,
    'style="display:inline-block;background:#D4A34E;color:#ffffff;text-decoration:none;padding:14px 22px;border-radius:6px;font-weight:700;font-size:14px;"',
    'class="button" style="display:inline-block;background:#d6a847;color:#111111;text-decoration:none;font-size:16px;font-weight:bold;padding:16px 34px;border-radius:8px;min-width:210px;text-align:center;"'
  ),
  updated_at = now()
WHERE body_html LIKE '%background:#D4A34E%';

UPDATE public.email_templates
SET
  body_html = replace(
    replace(
      body_html,
      '<span style="color:#3F4148;word-break:break-all;">{{cta_url}}</span>',
      ''
    ),
    'If the button does not work, copy and paste this link into your browser:<br>',
    'If the button does not work, open HD Homes or contact support.'
  ),
  updated_at = now()
WHERE body_html LIKE '%copy and paste this link%';

UPDATE public.email_templates
SET
  subject = 'You''re invited to join HD Homes',
  body_html = $staff$
<p style="margin:0 0 12px;font-size:13px;font-weight:bold;letter-spacing:1.5px;text-transform:uppercase;color:#b0842f;">Staff Invitation</p>
<h1 class="heading" style="margin:0 0 22px;font-size:30px;line-height:1.25;font-weight:700;color:#111111;">You're invited to join HD Homes</h1>
<p style="margin:0 0 18px;font-size:16px;line-height:1.7;color:#4b5563;">Hello <strong style="color:#111111;">{{recipient_name}}</strong>,</p>
<p style="margin:0 0 18px;font-size:16px;line-height:1.7;color:#4b5563;">You have been invited to join <strong style="color:#111111;">HD Homes Limited</strong> as a member of our team.</p>
<p style="margin:0 0 30px;font-size:16px;line-height:1.7;color:#4b5563;">Click the button below to securely accept your invitation and complete your staff account setup.</p>
<table width="100%" cellpadding="0" cellspacing="0" border="0"><tr><td align="center">
<a href="{{action_url}}" class="button" style="display:inline-block;background:#d6a847;color:#111111;text-decoration:none;font-size:16px;font-weight:bold;padding:16px 34px;border-radius:8px;min-width:210px;text-align:center;">Accept Invitation</a>
</td></tr></table>
<table width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-top:32px;background:#faf8f2;border:1px solid #eee5d2;border-radius:10px;"><tr><td style="padding:18px 20px;">
<p style="margin:0;font-size:13px;line-height:1.6;color:#6b7280;"><strong style="color:#333333;">Important:</strong> This invitation is intended only for the person who received this email. If you were not expecting this invitation, you can safely ignore this message.</p>
</td></tr></table>
<p style="margin:30px 0 0;font-size:12px;line-height:1.6;color:#9ca3af;text-align:center;">If the button does not work, please open the invitation from your HD Homes account or contact support.</p>
$staff$,
  text_body = 'You have been invited to join HD Homes Limited. Open the message in an HTML email client and use Accept Invitation. If you were not expecting this invitation, you can ignore it.',
  variables = '["recipient_name","first_name","action_url","cta_url","role_name"]'::jsonb,
  updated_at = now()
WHERE slug = 'staff_invite';

UPDATE public.email_templates
SET
  subject = 'You''re invited to HD Homes',
  body_html = $portal$
<p style="margin:0 0 12px;font-size:13px;font-weight:bold;letter-spacing:1.5px;text-transform:uppercase;color:#b0842f;">Portal Invitation</p>
<h1 class="heading" style="margin:0 0 22px;font-size:30px;line-height:1.25;font-weight:700;color:#111111;">You're invited to HD Homes</h1>
<p style="margin:0 0 18px;font-size:16px;line-height:1.7;color:#4b5563;">Hello <strong style="color:#111111;">{{recipient_name}}</strong>,</p>
<p style="margin:0 0 18px;font-size:16px;line-height:1.7;color:#4b5563;">You have been invited to the <strong style="color:#111111;">HD Homes</strong> {{portal_name}} portal.</p>
<p style="margin:0 0 30px;font-size:16px;line-height:1.7;color:#4b5563;">Use the button below to accept your invitation and finish account setup.</p>
<table width="100%" cellpadding="0" cellspacing="0" border="0"><tr><td align="center">
<a href="{{action_url}}" class="button" style="display:inline-block;background:#d6a847;color:#111111;text-decoration:none;font-size:16px;font-weight:bold;padding:16px 34px;border-radius:8px;min-width:210px;text-align:center;">Accept Invitation</a>
</td></tr></table>
<p style="margin:30px 0 0;font-size:12px;line-height:1.6;color:#9ca3af;text-align:center;">If the button does not work, open HD Homes or contact support.</p>
$portal$,
  text_body = 'You have been invited to the HD Homes portal. Use Accept Invitation in the email.',
  updated_at = now()
WHERE slug = 'portal_invite';
