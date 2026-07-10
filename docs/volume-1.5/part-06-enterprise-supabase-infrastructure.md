# Volume 1.5 – Part 6

# Enterprise Supabase Infrastructure

**Status:** Draft — awaiting approval before implementation.

**Depends on:** [Parts 1–5](./README.md)

> This is the final part of Volume 1.5. With Parts 1–6 documented, the enterprise backend blueprint is complete. **No infrastructure changes are applied until the full volume is reviewed and approved.**

---

## Module Overview

Supabase is the backend platform for the entire HD Homes ecosystem.

| Responsibility | Technology |
|----------------|------------|
| Authentication | Supabase Auth |
| Database | PostgreSQL 17 |
| Authorization | Row-Level Security (RLS) |
| File storage | Supabase Storage (20 buckets) |
| Real-time | Supabase Realtime |
| Serverless logic | Edge Functions (Deno) |
| Scheduled tasks | pg_cron + Edge Functions |
| Search | PostgreSQL FTS + PostGIS |
| Monitoring | Supabase Dashboard + custom alerts |

Every backend feature must be designed with **enterprise scalability, security, and observability** from day one.

---

## Current State vs Target

| Area | Current (Volume 1 Part 3) | Target (Volume 1.5) |
|------|---------------------------|---------------------|
| Project | `wbonjdqsifwsawhhxygl` (eu-west-1) | + dev, staging environments |
| Schemas | `public` only | 12 logical schemas |
| Tables | 74 in `public` | 150+ across schemas |
| RLS | Enabled on all 74 tables | Enabled on every table, no exceptions |
| Storage buckets | 18 | 20 |
| Edge Functions | 0 | 30+ planned |
| Views | 0 | 10 dashboard views |
| Materialized views | 0 | 10 report views |
| PostGIS | Not enabled | Enabled |
| pg_cron | Not configured | Daily/weekly/monthly jobs |
| Feature flags | Not implemented | `system.feature_flags` table |
| Event bus | Not implemented | `system.events` table |
| Job queue | Not implemented | `system.job_queue` table |

---

## Environment Strategy

```text
Development  →  Testing  →  Staging  →  Production
```

| Environment | Purpose | Supabase project |
|-------------|---------|----------------|
| Development | Local `supabase start` + remote dev project | Local + optional dev remote |
| Testing | CI automated tests | Ephemeral or dedicated test project |
| Staging | Pre-production validation | `hd-homes-staging` (to create) |
| Production | Live platform | `wbonjdqsifwsawhhxygl` |

**Rules:**
- Never develop directly in production
- Never use `service_role` key in Flutter client
- Secrets via `env.json` (local) and Supabase Dashboard secrets (Edge Functions)
- Migrations tested locally → staging → production

**Flutter config:** `lib/core/config/supabase_config.dart` + `env.example.json`

---

## Database Schema Organization

### Target: Multi-Schema Architecture

Instead of placing everything in `public`, organize into logical PostgreSQL schemas:

```text
auth          → Supabase managed (users, sessions)
public        → API-exposed entry points, views, RPC wrappers
crm           → leads, clients, activities, referrals
properties    → properties, estates, reservations, inspections
finance       → payments, invoices, ledger, commissions
construction  → projects, milestones, contractors, budgets
cms           → pages, sections, hero, navigation, footer
marketing     → campaigns, newsletter, promotions, analytics
analytics     → sessions, page views, events, reports
notifications → notifications, templates, delivery log
reports       → materialized views, report metadata
system        → settings, feature_flags, job_queue, events
audit         → audit_logs, activity_logs (append-only)
```

**Benefits:** better organization, granular grants, easier maintenance, multi-tenant readiness.

**Migration path:** Phase 1 keeps tables in `public` (current). Phase 2 moves tables to domain schemas with `public` views for backward compatibility. Update `config.toml`:

```toml
[api]
schemas = ["public", "crm", "properties", "finance", "construction", "cms", "marketing"]
```

---

## Authentication

### Supported Providers

| Provider | Phase | Status |
|----------|-------|--------|
| Email + password | 1 | ✅ Configured |
| Phone OTP | 2 | Planned |
| Google OAuth | 2 | Planned |
| Apple | 3 | Future |
| Microsoft | 3 | Future |
| Facebook | 3 | Future |

### Features

| Feature | Implementation |
|---------|----------------|
| Email verification | Supabase Auth `email_confirmed_at` |
| Password reset | Supabase Auth flow |
| MFA (TOTP) | Supabase Auth MFA (admin mandatory) |
| Session management | `system.user_sessions` table |
| Device tracking | Session metadata |
| Login history | `audit.activity_logs` |
| Trusted devices | `system.trusted_devices` |

### Auth Trigger (existing)

```sql
-- auth.users AFTER INSERT → public.handle_new_user()
-- Creates: profiles, default client role
```

**Target alignment (Part 1):** Rename `profiles` → `users`, assign `role_id`, create profile extensions.

---

## User Session Management

### `system.user_sessions`

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `user_id` | UUID | FK → users |
| `session_token_hash` | TEXT | Hashed Supabase session ID |
| `device` | TEXT | `mobile`, `tablet`, `desktop` |
| `browser` | TEXT | |
| `operating_system` | TEXT | |
| `country` | TEXT | |
| `ip_address` | INET | |
| `last_activity_at` | TIMESTAMPTZ | |
| `started_at` | TIMESTAMPTZ | |
| `expires_at` | TIMESTAMPTZ | |
| `is_revoked` | BOOLEAN | DEFAULT false |

**RLS:** Users SELECT/UPDATE own sessions; revoke sets `is_revoked = true`.

---

## Row-Level Security (RLS)

### Global Policy

**RLS enabled on every table. No exceptions.**

Never bypass RLS with `service_role` in frontend code. Edge Functions use `service_role` only for:
- Webhook verification
- System cron jobs
- Cross-user notifications

### Role Matrix (summary)

| Role | Access pattern |
|------|----------------|
| Public (anon) | SELECT published content only |
| Client | Own records: payments, documents, tickets, favorites |
| Investor | Own portfolios, returns, construction reports |
| Sales | Assigned leads/clients; no finance write |
| Finance | Payment tables; no CRM notes |
| Marketing | CMS + marketing tables |
| Construction | Project tables; no payroll |
| Admin | Permission-gated via `has_permission()` |

Full per-table policies documented in Parts 1–5. Consolidated RLS reference to be generated as migration `008_rls_consolidated.sql` on approval.

### RLS Performance Guidelines

- Use `(SELECT auth.uid())` wrapper in policies for plan caching
- Index all columns referenced in policy `USING` clauses
- Prefer `has_permission('slug')` over nested subqueries where possible
- Test policies with `SET ROLE authenticated; SET request.jwt.claims = ...`

---

## Storage Buckets

### Target Bucket Map (20 buckets)

| Bucket | Public | Max size | MIME types | Used by |
|--------|--------|----------|------------|---------|
| `avatars` | Yes | 5 MB | image/* | User profiles |
| `company-assets` | Yes | 2 MB | image/*, svg | Logos, branding |
| `property-images` | Yes | 10 MB | image/* | Property gallery |
| `property-videos` | Yes | 50 MB | video/mp4, webm | Property tours |
| `estate-masterplans` | Yes | 20 MB | image/*, pdf | Estate pages |
| `estate-documents` | No | 20 MB | pdf | Estate legal docs |
| `blog-images` | Yes | 10 MB | image/* | Blog posts |
| `gallery` | Yes | 10 MB | image/* | CMS gallery |
| `contracts` | No | 20 MB | pdf | Client contracts |
| `receipts` | No | 10 MB | pdf, image/* | Payment receipts |
| `invoices` | No | 20 MB | pdf | Client invoices |
| `construction-media` | Yes | 100 MB | image/*, video/* | Progress updates |
| `inspection-media` | No | 10 MB | image/* | Inspection photos |
| `client-documents` | No | 20 MB | pdf | KYC, ID |
| `investor-documents` | No | 20 MB | pdf | Investor reports |
| `downloads` | Yes | 20 MB | pdf | Public brochures |
| `marketing-assets` | Yes | 10 MB | image/* | Campaign assets |
| `reports` | No | 50 MB | pdf, xlsx | Generated reports |
| `temporary-uploads` | No | 50 MB | * | Staging before validation |
| `backups` | No | 100 MB | * | System backups |

### Current (18 buckets — live)

`property-images`, `property-videos`, `estate-images`, `estate-masterplans`, `blog-images`, `gallery`, `avatars`, `marketing`, `team`, `logos`, `downloads`, `construction-images`, `construction-videos`, `documents`, `contracts`, `receipts`, `allocation-letters`, `backups`

**Gap:** Rename/consolidate to target names; add `invoices`, `inspection-media`, `investor-documents`, `temporary-uploads`, `company-assets`, `reports`.

### Folder Convention

```text
{bucket}/{user_id}/{filename}     → private buckets
{bucket}/{entity_type}/{entity_id}/{filename}  → public buckets
```

### File Validation (Edge Function: `validate-upload`)

| Check | Action |
|-------|--------|
| MIME type | Whitelist per bucket |
| File size | Enforce bucket limit |
| Filename | Sanitize, strip path traversal |
| Images | Strip EXIF metadata |
| Images | Generate thumbnails + WebP variants |
| Duplicates | Hash check against `media_library` |
| Virus scan | Future ClamAV integration |

---

## Edge Functions Catalog

**Location:** `supabase/functions/` (none deployed yet)

### Authentication

| Function | Trigger | Purpose |
|----------|---------|---------|
| `user-onboarding` | Auth signup | Extended profile setup |
| `send-welcome-email` | Signup | Welcome email via SMTP |
| `assign-role` | Admin action | Role assignment with audit |
| `session-cleanup` | Cron daily | Revoke expired sessions |

### Payments

| Function | Trigger | Purpose |
|----------|---------|---------|
| `paystack-webhook` | HTTP POST | Verify + update payment status |
| `flutterwave-webhook` | HTTP POST | Verify + update payment status |
| `generate-receipt` | Payment success | PDF receipt → storage |
| `generate-invoice` | Invoice issued | PDF invoice → storage |
| `installment-reminder` | Cron daily | Overdue installment emails |

### CRM

| Function | Trigger | Purpose |
|----------|---------|---------|
| `assign-lead` | Lead INSERT | Round-robin or rule-based assignment |
| `schedule-followup` | Lead activity | Create CRM task |
| `process-referral` | Sale completed | Award referral bonus |
| `route-notification` | Event | Multi-channel delivery |

### Construction

| Function | Trigger | Purpose |
|----------|---------|---------|
| `construction-notify` | Update INSERT | Notify investors + clients |
| `milestone-alert` | Milestone delayed | Alert project manager |
| `budget-alert` | Budget threshold | Alert finance + executive |

### CMS

| Function | Trigger | Purpose |
|----------|---------|---------|
| `generate-seo` | Page publish | AI SEO suggestions |
| `regenerate-sitemap` | Content publish | XML sitemap update |
| `send-newsletter` | Campaign schedule | Bulk email send |
| `schedule-campaign` | Cron | Campaign dispatcher |

### AI

| Function | Trigger | Purpose |
|----------|---------|---------|
| `property-recommendations` | Cron nightly | Update recommendation scores |
| `ai-content-generate` | Job queue | Process `ai_content_jobs` |
| `roi-calculator` | RPC | Investment ROI computation |
| `analytics-summary` | Cron weekly | AI executive summary |

### Utilities

| Function | Trigger | Purpose |
|----------|---------|---------|
| `generate-pdf` | Various | Generic PDF renderer |
| `optimize-image` | Storage upload | Resize, WebP, thumbnail |
| `generate-slug` | RPC | Unique slug from title |
| `verify-backup` | Cron daily | Backup integrity check |

### API Versioning

All HTTP Edge Functions exposed at:

```text
/functions/v1/{function-name}
```

Future breaking changes → `/functions/v2/`.

---

## Database Triggers

### Existing (live)

| Trigger | Table | Function |
|---------|-------|----------|
| `on_auth_user_created` | `auth.users` | `handle_new_user()` |
| `trg_*_audit` | RBAC tables | `set_audit_fields()` |

### Target Triggers (on approval)

| Event | Trigger action |
|-------|----------------|
| New user registered | Profile + role + welcome notification + email |
| Property published | Status history + search vector refresh + notify subscribers |
| Payment completed | Receipt + ledger entry + commission + notify teams |
| Invoice created | Generate invoice number + notify client |
| Reservation expired | Revert property status + notify client |
| Inspection booked | Timeline entry + calendar block + notify agent |
| Blog published | Sitemap regen + search vector refresh |
| Construction updated | Notify investors + clients |
| Referral completed | Award bonus + loyalty points |
| Support ticket created | Notify assigned staff |
| Job application submitted | Notify HR |
| Any status change | `audit_logs` INSERT |
| Price change | `property_pricing_history` INSERT |

### Event-Driven Architecture (Enterprise Enhancement)

#### `system.events`

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `event_type` | TEXT | `payment.completed`, `property.published` |
| `entity_type` | TEXT | |
| `entity_id` | UUID | |
| `payload` | JSONB | |
| `processed` | BOOLEAN | DEFAULT false |
| `created_at` | TIMESTAMPTZ | |

Triggers INSERT into `system.events`. Edge Functions or pg listeners process asynchronously. Keeps modules loosely coupled.

---

## Realtime Subscriptions

Enable Realtime on these tables:

| Channel | Table(s) | Audience |
|---------|----------|----------|
| Notifications | `notifications` | `user_id = auth.uid()` |
| Chat | `chat_messages` | Room members |
| Private messages | `messages` | `receiver_id = auth.uid()` |
| Support tickets | `ticket_messages` | Ticket participants |
| Payment status | `payments` | Client (own) + finance |
| Reservations | `property_reservations` | Client + sales |
| Inspections | `inspection_bookings` | Client + agent |
| Construction | `construction_updates` | Investors + clients |
| CRM dashboard | `leads` | Assigned sales agents |
| Admin dashboard | `system.events` | Staff with `reports.view` |
| Property availability | `property_availability_calendar` | Public read (published) |

**Flutter:** Use `supabase.channel()` with RLS-filtered postgres changes. Minimize polling.

---

## Database Views

Standard views with `security_invoker = true`:

| View | Schema | Purpose |
|------|--------|---------|
| `executive_dashboard` | reports | MD/GM KPIs (Part 4) |
| `sales_dashboard` | reports | Pipeline, conversions, top agents |
| `finance_dashboard` | reports | Revenue, outstanding, cash flow |
| `marketing_dashboard` | reports | Campaign ROI, traffic, leads |
| `construction_dashboard` | reports | Project progress, budgets, delays |
| `client_dashboard` | reports | Client portal summary |
| `investor_dashboard` | reports | Portfolio, ROI, construction |
| `property_dashboard` | reports | Listing performance, views |
| `crm_dashboard` | reports | Leads, tasks, follow-ups |
| `customer_360_profile` | crm | Unified customer view (Part 3) |

---

## Materialized Views

Precomputed reports — refresh via pg_cron or on-demand:

| View | Refresh | Purpose |
|------|---------|---------|
| `mv_monthly_sales` | Daily | Sales by month |
| `mv_annual_revenue` | Daily | Year-to-date revenue |
| `mv_property_performance` | Daily | Views, inquiries, conversions per property |
| `mv_estate_performance` | Daily | Estate-level metrics |
| `mv_top_agents` | Weekly | Sales leaderboard |
| `mv_marketing_performance` | Daily | Campaign aggregates |
| `mv_lead_conversion` | Daily | Funnel metrics |
| `mv_investor_roi` | Monthly | Investor returns |
| `mv_construction_progress` | Daily | Project completion snapshot |
| `mv_website_statistics` | Daily | Traffic aggregates |

```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY reports.mv_monthly_sales;
```

---

## Stored Procedures (RPC Functions)

Exposed via Supabase RPC (`/rest/v1/rpc/{name}`):

| Function | Purpose |
|----------|---------|
| `generate_property_code()` | `HD-P-00001` sequence |
| `generate_invoice_number()` | `HD-INV-00001` |
| `generate_receipt_number()` | `HD-RCP-00001` |
| `generate_lead_code()` | `HD-L-00001` |
| `generate_client_number()` | `HD-C-00001` |
| `calculate_roi(portfolio_id)` | Investment ROI |
| `calculate_commission(payment_id)` | Sales commission |
| `validate_installment_schedule(plan_id)` | Schedule integrity check |
| `search_properties(query, filters)` | Full-text + filter search |
| `properties_nearby(lat, lng, radius_km)` | PostGIS radius search |
| `executive_dashboard_metrics(period)` | Executive KPIs JSONB |
| `crm_dashboard_metrics(date_from, date_to)` | CRM KPIs JSONB |
| `marketing_dashboard_metrics(period)` | Marketing KPIs JSONB |
| `archive_old_notifications(days)` | Retention cleanup |
| `get_ab_variant(test_id, session_id)` | A/B test serving |
| `get_personalized_content(context)` | Dynamic personalization |

**Security:** `SECURITY DEFINER` functions in private schema; expose via thin `public` wrappers with permission checks. Revoke direct EXECUTE from `anon` where internal-only (already done for `has_permission`, etc.).

---

## Full-Text Search

### Implementation

```sql
-- Add to searchable tables (Part 2, Part 5)
ALTER TABLE properties ADD COLUMN search_vector tsvector;
CREATE INDEX idx_properties_fts ON properties USING GIN (search_vector);

-- Trigger to maintain vector
CREATE TRIGGER trg_properties_search
  BEFORE INSERT OR UPDATE ON properties
  FOR EACH ROW EXECUTE FUNCTION update_search_vector();
```

### Searchable Entities

| Entity | Table | Weighted fields |
|--------|-------|-----------------|
| Properties | `properties` | title (A), description (B), address (C) |
| Estates | `estates` | name (A), description (B) |
| Blog posts | `blog_posts` | title (A), excerpt (B), content (C) |
| FAQs | `faqs` | question (A), answer (B) |
| Team | `team_members` | name (A), position (B) |
| Services | `services` | title (A), description (B) |
| Careers | `careers` | title (A), description (B) |

**Target:** Property search < 300 ms.

---

## Geospatial Search (PostGIS)

```sql
CREATE EXTENSION IF NOT EXISTS postgis;

ALTER TABLE properties ADD COLUMN geom geography(POINT, 4326);
CREATE INDEX idx_properties_geom ON properties USING GIST (geom);

-- Nearby search RPC
CREATE FUNCTION properties_nearby(lat float, lng float, radius_km float)
RETURNS SETOF properties AS $$
  SELECT * FROM properties
  WHERE ST_DWithin(
    geom,
    ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography,
    radius_km * 1000
  )
  AND status = 'published';
$$ LANGUAGE sql STABLE;
```

**Capabilities:** nearby properties, radius search, map clustering (via geohash), polygon search, administrative boundaries (future).

---

## Scheduled Jobs (pg_cron)

Enable via Supabase Dashboard → Database → Extensions → `pg_cron`.

### Daily

| Job | Time (UTC) | Action |
|-----|------------|--------|
| `backup-verify` | 02:00 | Verify backup integrity |
| `installment-reminders` | 08:00 | Overdue installment emails |
| `reservation-cleanup` | 00:30 | Expire reservations |
| `analytics-refresh` | 03:00 | Refresh materialized views |
| `session-cleanup` | 04:00 | Revoke expired sessions |
| `lead-dormancy` | 05:00 | Mark inactive leads dormant |
| `ai-scores-refresh` | 02:30 | Update recommendation scores |

### Weekly

| Job | Day | Action |
|-----|-----|--------|
| `executive-report` | Monday 07:00 | Generate executive PDF |
| `seo-audit` | Sunday 06:00 | SEO health check |
| `newsletter-dispatch` | Per schedule | Campaign sends |

### Monthly

| Job | Action |
|-----|--------|
| `financial-summary` | Monthly P&L report |
| `investor-reports` | Per-investor construction + ROI reports |
| `construction-summary` | All-project progress report |
| `data-retention` | Archive old notifications, activity logs |

---

## Background Job Queue (Enterprise Enhancement)

### `system.job_queue`

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `job_type` | TEXT | `pdf_generate`, `bulk_email`, `image_optimize` |
| `payload` | JSONB | Job parameters |
| `status` | TEXT | `pending`, `processing`, `completed`, `failed` |
| `priority` | INT | DEFAULT 0 |
| `attempts` | INT | DEFAULT 0 |
| `max_attempts` | INT | DEFAULT 3 |
| `scheduled_at` | TIMESTAMPTZ | |
| `started_at` | TIMESTAMPTZ | |
| `completed_at` | TIMESTAMPTZ | |
| `error` | TEXT | |

Edge Function `process-job-queue` polls and processes. Keeps app responsive under heavy load.

**Use cases:** PDF generation, bulk campaigns, image optimization, report generation, AI processing, data imports.

---

## Feature Flags

### `system.feature_flags`

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `key` | TEXT | UNIQUE |
| `name` | TEXT | Display name |
| `description` | TEXT | |
| `is_enabled` | BOOLEAN | DEFAULT false |
| `enabled_for_roles` | TEXT[] | Role slugs |
| `enabled_for_users` | UUID[] | Specific users (beta) |
| `metadata` | JSONB | Config per feature |
| + audit fields | | |

**Seed flags:**

| key | Default |
|-----|---------|
| `ai_recommendations` | false |
| `virtual_tours` | false |
| `referral_program` | true |
| `mortgage_module` | false |
| `rentals` | false |
| `property_auctions` | false |
| `beta_dashboard` | false |
| `maintenance_mode` | false |

**Flutter:** `featureFlagsProvider` reads from `system.feature_flags` WHERE `is_enabled = true`.

---

## API Design Guidelines

| Guideline | Implementation |
|-----------|----------------|
| REST for CRUD | Supabase client `.from('table')` |
| RPC for complex logic | `.rpc('function_name', params)` |
| Naming | snake_case tables, snake_case RPC |
| Pagination | `.range(from, to)` — max 1000 rows (config.toml) |
| Filtering | `.eq()`, `.in()`, `.gte()` PostgREST operators |
| Sorting | `.order('column', ascending: false)` |
| Cursor pagination | RPC with `last_id` param for large datasets |
| Rate limiting | Supabase platform limits + Edge Function throttling |
| Validation | DB constraints + Edge Function input validation |
| Errors | Structured `{ code, message, details }` from Edge Functions |
| Versioning | `/functions/v1/` prefix |

---

## Performance Targets

| Operation | Target |
|-----------|--------|
| Authentication | < 200 ms |
| Property search | < 300 ms |
| Dashboard load | < 500 ms |
| File upload (10 MB) | < 5 s |
| Webhook processing | < 1 s |

### Optimization Checklist

- [ ] Indexes on all FK columns and RLS policy columns
- [ ] Composite indexes for common filter combinations
- [ ] Materialized views for dashboard KPIs
- [ ] `EXPLAIN ANALYZE` on slow queries (> 100 ms)
- [ ] Connection pooling via Supabase Pooler (production)
- [ ] Efficient RLS — avoid per-row function calls where possible
- [ ] Image CDN via Supabase Storage public URLs
- [ ] Flutter: pagination, lazy loading, cached network images

---

## Security Hardening

| Control | Status | Action |
|---------|--------|--------|
| RLS on every table | ✅ Live (74 tables) | Maintain on all new tables |
| Revoke RPC on internal functions | ✅ Done | Maintain on new functions |
| JWT validation | ✅ Supabase default | Short expiry for sensitive ops |
| MFA for admins | ⏳ | Enable in Supabase Dashboard |
| API rate limiting | ⏳ | Configure Supabase + Edge Functions |
| Brute-force protection | ⏳ | Supabase Auth rate limits |
| Secret rotation | ⏳ | Quarterly rotation schedule |
| Audit logging | ✅ `audit_logs` | Extend to all sensitive ops |
| Least-privilege roles | ✅ RBAC | Align with Part 1 permission keys |
| No service_role in client | ✅ | Enforced in code review |
| `search_path` on functions | ✅ Done | Maintain on all new functions |
| Views with `security_invoker` | ⏳ | Required for all views |

---

## Backup & Disaster Recovery

| Strategy | Configuration |
|----------|---------------|
| Daily automated backups | Supabase Pro plan (enabled) |
| Point-in-Time Recovery (PITR) | Enable on production |
| Weekly full snapshot | Export via `pg_dump` to `backups` bucket |
| Backup verification | Edge Function `verify-backup` (daily cron) |
| Restore testing | Quarterly restore drill to staging |
| RPO | < 24 hours (daily backup) / < 5 min (PITR) |
| RTO | < 4 hours (documented playbook) |

### Disaster Recovery Playbook (summary)

1. Assess scope (full vs partial failure)
2. Notify stakeholders
3. If DB corruption → restore from PITR to staging, validate, promote
4. If Storage loss → restore from `backups` bucket
5. If Edge Function failure → rollback deployment via CI/CD
6. Post-incident review → update playbook

---

## Monitoring & Observability

| Metric | Tool |
|--------|------|
| API latency | Supabase Dashboard → API |
| Database performance | Supabase Dashboard → Database |
| Slow queries | `pg_stat_statements` extension |
| Edge Function failures | Supabase Functions logs |
| Storage usage | Supabase Dashboard → Storage |
| Auth failures | Supabase Auth logs |
| Realtime connections | Supabase Realtime metrics |
| Payment webhook failures | `payment_webhook_events` + alert |
| Error rates | Custom `system.error_log` table |

### Alerts (configure in Supabase or external)

| Alert | Threshold |
|-------|-----------|
| API p95 latency | > 1 s |
| Database CPU | > 80% for 5 min |
| Edge Function error rate | > 5% in 10 min |
| Failed payment webhooks | Any failure |
| Storage > 80% quota | Warning |
| Auth failure spike | > 100/min |

---

## Logging

### `audit.activity_logs` (Part 1) + `system.error_log`

| Log type | Destination |
|----------|-------------|
| Authentication | `activity_logs` + Supabase Auth logs |
| Payments | `audit_logs` + `payment_webhook_events` |
| CRM | `activity_logs` |
| CMS | `activity_logs` |
| Construction | `activity_logs` |
| Security events | `audit_logs` (immutable) |
| Edge Functions | Supabase Functions logs (structured JSON) |

**Format:** `{ timestamp, level, module, action, user_id, entity_id, metadata }`

---

## AI Readiness

### `system.ai_config`

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `service` | TEXT | `openai`, `recommendations`, `lead_scoring` |
| `model` | TEXT | Model identifier |
| `config` | JSONB | API params, thresholds |
| `is_enabled` | BOOLEAN | |
| + audit fields | | |

**AI services (future):**

| Service | Table / Function |
|---------|------------------|
| Property recommendations | `property_recommendation_scores` + Edge Function |
| Lead scoring | `leads.score` + Edge Function |
| Construction forecasting | `ai_construction_analytics` |
| AI chatbot | Edge Function + `chat_rooms` |
| Market trend analysis | Materialized views + AI summary |
| Report generation | `ai_content_jobs` |
| Document summarization | Edge Function |

Store AI config separately from business data. Never store API keys in database — use Supabase secrets.

---

## Multi-Tenant Readiness (Enterprise Enhancement)

Design for future multi-company support without restructuring:

| Pattern | Implementation |
|---------|----------------|
| `company_id` column | Add to all domain tables (nullable, default single company) |
| RLS | `company_id = get_user_company_id()` |
| Settings | Per-company `settings` rows |
| Branding | Per-company theme in `settings` |
| Storage | `{company_id}/{bucket}/...` prefix |

Currently single-tenant (HD Homes Ltd). Column added as nullable with default UUID.

---

## Business Intelligence Layer (Enterprise Enhancement)

Dedicated `reports` schema with:

- Materialized views (pre-aggregated KPIs)
- `executive_dashboard` view
- Export RPCs (PDF, Excel, CSV)
- Future: read replica for BI tools (Power BI, Tableau, Looker)

Data flow:

```text
Domain tables → Triggers/events → Materialized views → Dashboard RPCs → Flutter Admin
                                                      → BI tool (future)
```

---

## Deployment Pipeline

```text
Local Development (supabase start)
        ↓
    Git push → GitHub
        ↓
    Code Review (PR)
        ↓
    CI/CD (GitHub Actions)
        ├── flutter analyze + test
        ├── supabase db lint
        ├── Migration dry-run on test DB
        └── Edge Function deploy to staging
        ↓
    Staging validation
        ↓
    Production deploy (manual approval)
        ├── supabase db push (migrations)
        ├── Edge Functions deploy
        └── Smoke tests
```

### CI/CD Checklist (every deployment)

- [ ] Run all migrations
- [ ] Execute automated tests
- [ ] Verify RLS policies (supabase test or custom script)
- [ ] Validate Edge Functions respond
- [ ] Roll back automatically on failure
- [ ] Notify team on deploy success/failure

---

## Environment Configuration

| Secret | Development | Production |
|--------|-------------|------------|
| `SUPABASE_URL` | `env.json` | Flutter build env |
| `SUPABASE_PUBLISHABLE_KEY` | `env.json` | Flutter build env |
| `SUPABASE_SERVICE_ROLE_KEY` | Edge Functions only | Edge Functions only |
| `PAYSTACK_SECRET_KEY` | Edge Function secret | Edge Function secret |
| `FLUTTERWAVE_SECRET_KEY` | Edge Function secret | Edge Function secret |
| `SMTP_*` | Edge Function secret | Edge Function secret |
| `GOOGLE_MAPS_API_KEY` | `env.json` (client) | `env.json` (client) |
| `OPENAI_API_KEY` | Edge Function secret | Edge Function secret |

**Never commit:** `env.json`, `.env`, service role keys, payment secrets.

**Reference:** `env.example.json` in project root.

---

## Cursor Implementation Checklist

| Step | Action | Status |
|------|--------|--------|
| 1 | Configure Supabase project structure | ⏳ Awaiting approval |
| 2 | Create database schemas | ⏳ Phase 2 migration |
| 3 | Write SQL migrations (Parts 1–5 alignment) | ⏳ Awaiting approval |
| 4 | Enable RLS for every table | ✅ Live; maintain |
| 5 | Configure storage buckets | ✅ 18 live; extend to 20 |
| 6 | Build Edge Functions incrementally | ⏳ Not started |
| 7 | Create triggers and stored procedures | ⏳ Partial (auth trigger live) |
| 8 | Configure Realtime channels | ⏳ Not started |
| 9 | Document API endpoints and RPCs | ✅ This document |
| 10 | Test security before frontend features | ⏳ On approval |

---

## Volume 1.5 Implementation Roadmap

After blueprint approval, implement in this order:

| Phase | Work | Est. migrations |
|-------|------|-----------------|
| **A** | Part 1 alignment — audit fields, users rename, settings | 3–5 |
| **B** | Part 2 — property module expansion | 5–8 |
| **C** | Part 3 — CRM + investor expansion | 5–8 |
| **D** | Part 4 — finance + construction expansion | 5–8 |
| **E** | Part 5 — CMS + marketing expansion | 5–8 |
| **F** | Part 6 — infrastructure (schemas, PostGIS, cron, views) | 3–5 |
| **G** | Edge Functions — auth, payments, CMS (incremental) | 10–15 functions |
| **H** | Seed data + staging validation | 1–2 |

**Total estimated:** 30–45 migrations, 30+ Edge Functions.

---

## Gap Analysis: Infrastructure

| Component | Current | Target |
|-----------|---------|--------|
| Environments | Production only | Dev + staging + production |
| Schemas | `public` | 12 domain schemas |
| Edge Functions | 0 | 30+ |
| pg_cron | Not enabled | 15+ scheduled jobs |
| PostGIS | Not enabled | Enabled |
| Full-text search | Not enabled | 7 entity types |
| Materialized views | 0 | 10 |
| Dashboard views | 0 | 10 |
| Feature flags | 0 | 8+ flags |
| Event bus | 0 | `system.events` |
| Job queue | 0 | `system.job_queue` |
| Session tracking | 0 | `system.user_sessions` |
| AI config | 0 | `system.ai_config` |
| Multi-tenant columns | 0 | `company_id` nullable |
| CI/CD pipeline | Not configured | GitHub Actions |
| Monitoring alerts | Dashboard only | Custom alerts |
| DR playbook | Not documented | Documented above |

---

**End of Volume 1.5 – Part 6**

---

## ✅ Volume 1.5 Complete

| Part | Document | Topic |
|------|----------|-------|
| 1 | [Philosophy & Core Schema](./part-01-philosophy-and-core-schema.md) | Users, RBAC, media, audit |
| 2 | [Property & Estate](./part-02-property-estate-architecture.md) | Listings, estates, search, AI scores |
| 3 | [Client, Investor & CRM](./part-03-client-investor-crm-architecture.md) | Leads, 360° CRM, referrals, chat |
| 4 | [Finance & Construction](./part-04-finance-construction-architecture.md) | Payments, ledger, projects, executive dashboard |
| 5 | [CMS, Marketing & Analytics](./part-05-cms-marketing-analytics.md) | Headless CMS, campaigns, A/B tests, AI content |
| 6 | [Supabase Infrastructure](./part-06-enterprise-supabase-infrastructure.md) | Security, Edge Functions, cron, DR, monitoring |

**Next phase:** Volume 2 – Public Website (premium HD Homes web experience, built on this foundation).

*Awaiting your approval of Volume 1.5 before any migration or Edge Function implementation.*
