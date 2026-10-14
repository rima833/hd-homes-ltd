# HD Homes Email System

Production transactional + Auth email for HD Homes. Queues are drained by Edge workers calling Resend. Clients never hold SMTP/API secrets.

## Architecture

Business events / CommunicationService enqueue to `notification_delivery` (email) and website forms use `website_form_outbox`. Edge `process-email-queue` renders `email_templates` with `email_brand` shell and sends via Resend (`RESEND_API_KEY`). Supabase Auth uses Dashboard HTML templates + optional Custom SMTP.

Do not create parallel email_events / email_deliveries tables.

## Secrets (Edge only)

- `RESEND_API_KEY` — Supabase Edge Function secret only (never in Flutter client env).
- Set: `supabase secrets set RESEND_API_KEY=re_xxx`
- Deploy: `process-email-queue` (cron; JWT verify optional), `send-test-email`, `email-provider-health`

## Brand + Auth

- Brand: `app_settings.email_brand` via Admin → Settings → Email → Branding (logo Cloudinary URL, sender, reply-to, footer links).
- Site URL: `app_settings.seo.site_url` for Auth `emailRedirectTo` / `redirectTo` (`/#/verify-email`, `/#/reset-password`). Add production URL to Auth redirect allow-list.
- Paste repo templates from `supabase/templates/*.html` into Dashboard Auth Email Templates (preserve `{{ .ConfirmationURL }}`; no Supabase branding).
- Enable Custom SMTP for Auth (can be Resend SMTP). App mail stays Edge + Resend API.

## DNS

Use Resend-issued SPF, DKIM, DMARC values only. Then Admin → Email → Run health check.

## RPCs

- `queue_transactional_email`
- `admin_list_email_deliveries`
- `admin_email_system_status`
- `admin_upsert_email_template` (security templates cannot be disabled)

## Event wiring

| Area | Hook |
|------|------|
| Payments | `_notify_user` queues email |
| Construction | publish trigger → `construction_update` |
| Support | trigger on `tickets` |
| Inspections | trigger on `property_inspections` |
| Staff/portal invites | OrganizationService enqueue |
| Website forms | outbox drained by worker |

## Admin

Admin → Settings → Email: Overview, Branding, Templates, Logs (Realtime), Test send (real Edge call; no fake success).

## Troubleshooting

- Queued forever: missing `RESEND_API_KEY`, undeployed function, or no cron.
- Health not configured: key/domain check failed.
- Auth unbranded: paste Dashboard templates.
- Wrong redirect host: fix `seo.site_url` + Auth Site URL allow-list.
