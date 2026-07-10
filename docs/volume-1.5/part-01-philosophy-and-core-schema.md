# Volume 1.5 – Part 1

# Database Philosophy & Core Schema

**Status:** Draft — awaiting approval before any migration work.

---

## Database Philosophy

The HD Homes database is the **single source of truth** for the entire platform.

Every website page, dashboard, report, notification, document, property listing, payment, and user action must originate from the database.

The database must be:

| Requirement | Meaning |
|-------------|---------|
| Highly normalized | 3NF or higher where practical |
| Secure | RLS on every exposed table; least-privilege policies |
| Scalable | UUID-first; indexes for search and reporting |
| Auditable | Immutable audit logs; soft deletes only |
| Extensible | Module-based design; polymorphic where needed |
| Performant | Composite indexes; full-text search ready |
| Cloud-native | Supabase Postgres + Storage + Auth |
| API-first | All access via Supabase client or Edge Functions |

The schema must support **millions of records** without structural redesign.

---

## Database Design Principles

### 1. UUID Primary Keys

Every table uses UUIDs — never serial integers.

```sql
id UUID PRIMARY KEY DEFAULT gen_random_uuid()
```

**Benefits:** globally unique IDs, better security, easier sync, distributed-system ready.

---

### 2. Audit Fields

Every table **must** include these fields. No exceptions.

| Column | Type | Purpose |
|--------|------|---------|
| `id` | UUID | Primary key |
| `created_at` | TIMESTAMPTZ | Record creation (UTC) |
| `updated_at` | TIMESTAMPTZ | Last modification (UTC) |
| `created_by` | UUID | FK → users.id |
| `updated_by` | UUID | FK → users.id |
| `deleted_at` | TIMESTAMPTZ | Soft-delete timestamp (nullable) |
| `deleted_by` | UUID | Who soft-deleted (nullable) |
| `status` | TEXT or ENUM | Business status |
| `is_active` | BOOLEAN | Active flag (default true) |
| `is_deleted` | BOOLEAN | Soft-delete flag (default false) |

**Trigger:** `set_audit_fields()` auto-populates `created_by`, `updated_by`, `created_at`, `updated_at` on INSERT/UPDATE.

---

### 3. Soft Delete

Never permanently delete business data.

```text
is_deleted = true
deleted_at = now()
deleted_by = auth.uid()
```

**Benefits:** recovery, compliance, audit trail, historical reporting.

All SELECT policies must filter `is_deleted = false` unless staff explicitly queries archived records.

---

### 4. Timestamp Standards

Always UTC. Always `TIMESTAMPTZ`.

```sql
created_at TIMESTAMPTZ NOT NULL DEFAULT now()
updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
```

Never use `TIMESTAMP WITHOUT TIME ZONE` or local server time.

---

### 5. Naming Conventions

| Element | Convention | Examples |
|---------|------------|----------|
| Tables | plural, snake_case | `users`, `properties`, `payments` |
| Columns | snake_case | `first_name`, `phone_number`, `property_price` |
| Foreign keys | `{entity}_id` | `user_id`, `property_id`, `client_id` |
| Indexes | `idx_{table}_{columns}` | `idx_properties_slug` |
| Policies | `{table}_{action}_{scope}` | `properties_public_read` |
| Enums | snake_case type name | `property_status`, `payment_status` |

---

## Database Modules

Every table belongs to exactly one module.

```text
Authentication        → users, roles, permissions, role_permissions, user_permissions
Users                 → admin_profiles, client_profiles, investor_profiles, staff_profiles
Website CMS           → pages, menus, navigation, banners, hero_sections, …
Properties            → properties, property_images, property_videos, …
Estates               → estates, estate_phases, estate_images, …
Clients               → client reservations, documents, preferences
Investors             → portfolios, transactions, reports
CRM                   → leads, appointments, inspections, followups
Finance               → payments, installments, receipts, invoices
Construction          → projects, construction_updates, milestones
Marketing             → blogs, campaigns, newsletter, seo
Support               → tickets, ticket_messages, chat_messages
Notifications         → notifications, notification_templates
Reports               → (views — Part 5)
Analytics             → visitor_statistics, property_views, activity_logs
System Settings       → settings
Audit Logs            → audit_logs (immutable)
```

---

## Core User Model

All authenticated users share **one central `users` table**. Module-specific data lives in profile extension tables.

```text
users
│
├── admin_profiles      (Super Admin, Admin)
├── client_profiles     (Client / buyer)
├── investor_profiles   (Investor)
└── staff_profiles      (Sales, Finance, Marketing, Construction)
```

**Rule:** Never duplicate user records across modules. A user may have zero or one profile per type.

```text
users 1──0..1 admin_profiles
users 1──0..1 client_profiles
users 1──0..1 investor_profiles
users 1──0..1 staff_profiles
```

---

## Core Authentication Tables

### `users`

**Purpose:** Central identity table. Extends Supabase `auth.users`.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK, FK → auth.users(id) | Same as Supabase Auth UID |
| `email` | TEXT | NOT NULL, UNIQUE | Synced from auth |
| `phone` | TEXT | | E.164 format |
| `first_name` | TEXT | | |
| `last_name` | TEXT | | |
| `avatar_media_id` | UUID | FK → media(id) | Never store URL directly |
| `role_id` | UUID | FK → roles(id) | Primary role (denormalized for fast checks) |
| `status` | account_status | DEFAULT `pending_verification` | Enum |
| `email_verified` | BOOLEAN | DEFAULT false | |
| `phone_verified` | BOOLEAN | DEFAULT false | |
| `last_login_at` | TIMESTAMPTZ | | |
| `preferred_language` | TEXT | DEFAULT `'en'` | |
| `timezone` | TEXT | DEFAULT `'Africa/Lagos'` | |
| `notification_preferences` | JSONB | DEFAULT `{}` | |
| + audit fields | | | See §2 |

**Indexes:** `idx_users_email`, `idx_users_phone`, `idx_users_status`, `idx_users_role_id`

**RLS:** Users read/update own row; `user.read` permission for staff.

> **Note:** `password_hash` is managed exclusively by Supabase Auth — never stored in `public.users`.

---

### `roles`

**Purpose:** System and custom roles.

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | UUID | PK |
| `name` | TEXT | NOT NULL, UNIQUE (slug) |
| `display_name` | TEXT | NOT NULL |
| `description` | TEXT | |
| `is_system_role` | BOOLEAN | DEFAULT false |
| + audit fields | | |

**Default system roles:**

| name (slug) | display_name | is_system_role |
|-------------|--------------|----------------|
| `super_admin` | Super Admin | true |
| `admin` | Admin | true |
| `sales` | Sales | true |
| `finance` | Finance | true |
| `marketing` | Marketing | true |
| `construction_manager` | Construction Manager | true |
| `client` | Client | true |
| `guest` | Guest | true (unauthenticated — no DB row) |

> Guest is not stored in `user_roles`. Public RLS policies grant anonymous SELECT where appropriate.

---

### `permissions`

**Purpose:** Granular, module-scoped permissions.

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | UUID | PK |
| `module` | TEXT | NOT NULL |
| `permission_key` | TEXT | NOT NULL, UNIQUE |
| `display_name` | TEXT | NOT NULL |
| `description` | TEXT | |
| + audit fields | | |

**Permission key format:** `{module}.{action}`

| permission_key | module | display_name |
|----------------|--------|--------------|
| `property.create` | properties | Create Property |
| `property.edit` | properties | Edit Property |
| `property.delete` | properties | Delete Property |
| `property.publish` | properties | Publish Property |
| `property.view` | properties | View Properties |
| `user.create` | users | Create User |
| `user.update` | users | Update User |
| `user.delete` | users | Delete User |
| `user.manage_roles` | users | Manage Roles |
| `blog.publish` | marketing | Publish Blog |
| `blog.edit` | marketing | Edit Blog |
| `payment.approve` | finance | Approve Payment |
| `payment.view` | finance | View Payments |
| `crm.view` | crm | View CRM |
| `crm.manage` | crm | Manage CRM |
| `construction.update` | construction | Update Construction |
| `construction.view` | construction | View Construction |
| `settings.manage` | settings | Manage Settings |
| `reports.view` | reports | View Reports |
| `marketing.manage` | marketing | Manage Marketing |

---

### `role_permissions`

**Purpose:** Many-to-many role → permission mapping.

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | UUID | PK |
| `role_id` | UUID | FK → roles, NOT NULL |
| `permission_id` | UUID | FK → permissions, NOT NULL |
| + audit fields | | |

**Unique:** `(role_id, permission_id)`

---

### `user_permissions`

**Purpose:** Per-user permission overrides without changing role.

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | UUID | PK |
| `user_id` | UUID | FK → users, NOT NULL |
| `permission_id` | UUID | FK → permissions, NOT NULL |
| `granted` | BOOLEAN | DEFAULT true |
| + audit fields | | |

**Unique:** `(user_id, permission_id)`

**Logic:** `granted = false` explicitly denies even if role grants it. Evaluated before role permissions.

**Example:** Sales Manager normally cannot `payment.approve`. Grant `user_permissions(granted=true)` for one user — no code change.

---

## Profile Tables

### `admin_profiles`

| Column | Type | Notes |
|--------|------|-------|
| `user_id` | UUID | PK, FK → users |
| `employee_id` | TEXT | UNIQUE |
| `department` | TEXT | |
| `position` | TEXT | |
| `office_location` | TEXT | |
| `hire_date` | DATE | |
| + audit fields | | |

---

### `client_profiles`

| Column | Type | Notes |
|--------|------|-------|
| `user_id` | UUID | PK, FK → users |
| `occupation` | TEXT | |
| `date_of_birth` | DATE | |
| `marital_status` | TEXT | |
| `nationality` | TEXT | DEFAULT `'Nigerian'` |
| `government_id` | TEXT | Encrypted at app layer |
| `kyc_status` | kyc_status | Enum: `pending`, `verified`, `rejected` |
| `preferred_contact_method` | TEXT | `email`, `phone`, `whatsapp` |
| `investment_interest` | BOOLEAN | DEFAULT false |
| + audit fields | | |

---

### `investor_profiles`

| Column | Type | Notes |
|--------|------|-------|
| `user_id` | UUID | PK, FK → users |
| `company_name` | TEXT | |
| `investment_type` | TEXT | `individual`, `corporate` |
| `investment_budget` | NUMERIC(15,2) | |
| `preferred_locations` | TEXT[] | |
| `portfolio_value` | NUMERIC(15,2) | Computed/cached |
| `risk_level` | TEXT | `low`, `medium`, `high` |
| + audit fields | | |

---

### `staff_profiles`

| Column | Type | Notes |
|--------|------|-------|
| `user_id` | UUID | PK, FK → users |
| `department` | TEXT | `sales`, `finance`, `marketing`, `construction` |
| `manager_id` | UUID | FK → users |
| `employment_status` | TEXT | `active`, `on_leave`, `terminated` |
| `office_branch` | TEXT | |
| + audit fields | | |

---

## System Settings Table

### `settings`

**Purpose:** Replace all hardcoded platform values. Everything editable from Admin Dashboard.

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `key` | TEXT | NOT NULL, UNIQUE |
| `value` | JSONB | NOT NULL |
| `category` | TEXT | `general`, `branding`, `seo`, `smtp`, `payments`, … |
| `is_public` | BOOLEAN | Readable without auth if true |
| `description` | TEXT | Admin UI helper |
| + audit fields | | |

**Seed keys:**

| key | category | is_public | Example value |
|-----|----------|-----------|---------------|
| `company` | general | true | `{name, tagline, country}` |
| `theme` | branding | true | `{primary, secondary, background}` |
| `contact` | general | true | `{email, phone, address}` |
| `office_locations` | general | true | `[{name, address, lat, lng}]` |
| `social_links` | general | true | `[{platform, url}]` |
| `seo` | seo | true | `{default_title, default_description}` |
| `smtp` | smtp | false | `{host, port, user}` |
| `payment_keys` | payments | false | `{paystack_public, …}` |
| `google_maps` | integrations | false | `{api_key}` |
| `business_hours` | general | true | `{mon: "9-17", …}` |
| `currency` | finance | true | `{code: "NGN", symbol: "₦"}` |
| `tax` | finance | false | `{vat_rate: 7.5}` |
| `maintenance_mode` | system | false | `{enabled: false, message: ""}` |

---

## Media Table

### `media`

**Purpose:** Central file metadata registry. Never store file bytes in Postgres.

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `file_name` | TEXT | NOT NULL |
| `file_type` | TEXT | `image`, `video`, `document`, `archive` |
| `bucket` | TEXT | NOT NULL — Supabase Storage bucket |
| `path` | TEXT | NOT NULL — object path in bucket |
| `mime_type` | TEXT | |
| `size` | BIGINT | Bytes |
| `uploaded_by` | UUID | FK → users |
| `alt_text` | TEXT | Accessibility |
| `metadata` | JSONB | `{width, height, duration, …}` |
| + audit fields | | |

**Reference pattern:**

```text
users.avatar_media_id  →  media.id  →  storage.objects
properties (via property_images.media_id)  →  media  →  storage
```

**Supported file types:** Images (JPEG, PNG, WebP, SVG), Videos (MP4, WebM), PDF, Word, Excel, ZIP.

---

## Activity Logs

### `activity_logs`

**Purpose:** User-facing activity feed and analytics. Mutable retention policy.

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `user_id` | UUID | FK → users (nullable for anonymous) |
| `module` | TEXT | NOT NULL |
| `action` | TEXT | NOT NULL |
| `entity_type` | TEXT | |
| `entity_id` | UUID | |
| `ip_address` | INET | |
| `device` | TEXT | |
| `browser` | TEXT | |
| `operating_system` | TEXT | |
| `location` | TEXT | City/country from IP |
| `metadata` | JSONB | DEFAULT `{}` |
| `created_at` | TIMESTAMPTZ | No `updated_at` — append-only |

**Examples:** User Login, Property Created, Payment Confirmed, Blog Published, Role Updated, Settings Changed.

**Retention:** Minimum 5 years. Configurable via `settings.data_retention`.

---

## Audit Logs

### `audit_logs`

**Purpose:** Immutable security and compliance trail. **Never updated or soft-deleted.**

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `user_id` | UUID | FK → users |
| `action` | TEXT | NOT NULL |
| `module` | TEXT | NOT NULL |
| `entity_type` | TEXT | |
| `entity_id` | UUID | |
| `old_values` | JSONB | Before state |
| `new_values` | JSONB | After state |
| `ip_address` | INET | |
| `user_agent` | TEXT | |
| `created_at` | TIMESTAMPTZ | Append-only |

**Examples:** Permission Changed, User Deleted, Role Assigned, Payment Modified, Invoice Deleted, Contract Uploaded.

**RLS:** INSERT by authenticated users; SELECT by `reports.view` or `super_admin` only. No UPDATE or DELETE policies.

---

## Notifications Table

### `notifications`

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `user_id` | UUID | FK → users, NOT NULL |
| `title` | TEXT | NOT NULL |
| `message` | TEXT | |
| `type` | notification_type | Enum — see below |
| `channel` | notification_channel | Enum — see below |
| `priority` | notification_priority | `low`, `normal`, `high`, `urgent` |
| `read_at` | TIMESTAMPTZ | |
| `sent_at` | TIMESTAMPTZ | |
| `expires_at` | TIMESTAMPTZ | |
| `action_url` | TEXT | Deep link |
| `metadata` | JSONB | DEFAULT `{}` |
| + audit fields | | |

**Types (`notification_type`):** `success`, `information`, `warning`, `error`, `marketing`

**Channels (`notification_channel`):** `email`, `sms`, `push`, `whatsapp`, `in_app`

---

## File Management Strategy

```text
Entity Table
    ↓  (FK)
media table (metadata only)
    ↓  (bucket + path)
Supabase Storage (binary files)
```

**Private buckets:** `{user_id}/{filename}` — RLS checks folder name matches `auth.uid()`.

**Public buckets:** Staff upload; anonymous read.

Never store `file_url` strings directly on entity tables in the target schema. Use `media_id` references.

---

## Enum Standardization

PostgreSQL ENUMs for all status fields.

### `account_status`
`pending_verification`, `active`, `inactive`, `suspended`

### `property_status`
`draft`, `published`, `reserved`, `sold`, `archived`

### `payment_status`
`pending`, `paid`, `failed`, `refunded`, `cancelled`

### `lead_status`
`new`, `contacted`, `qualified`, `inspection_booked`, `negotiation`, `closed_won`, `closed_lost`

### `construction_status`
`planning`, `foundation`, `structure`, `roofing`, `finishing`, `inspection`, `completed`

### `kyc_status`
`pending`, `verified`, `rejected`

### `notification_type`
`success`, `information`, `warning`, `error`, `marketing`

### `notification_channel`
`email`, `sms`, `push`, `whatsapp`, `in_app`

---

## Relationship Strategy

### Client journey

```text
User → client_profiles → Reservations → Payments → Documents → Properties
```

### Property structure

```text
Property → Images → Videos → Amenities → Features → Documents → Payment Plans → Inspections
```

**Rule:** Always enforce foreign keys with explicit `ON DELETE` behavior (CASCADE for children, SET NULL for optional refs).

---

## Indexing Strategy

Create indexes on:

| Column pattern | Reason |
|----------------|--------|
| `email`, `phone` | Login and lookup |
| `slug` (properties, estates, blogs, pages) | URL routing |
| `status` | Filtering |
| `created_at`, `updated_at` | Sorting and reporting |
| `role_id`, `client_id`, `investor_id`, `property_id` | Joins |
| `payment_status` | Finance dashboards |

**Composite indexes:**

```sql
CREATE INDEX idx_properties_status_created ON properties (status, created_at DESC);
CREATE INDEX idx_payments_client_created ON payments (client_id, created_at DESC);
CREATE INDEX idx_activity_logs_user_created ON activity_logs (user_id, created_at DESC);
```

---

## Slug Strategy

Public URLs use human-readable slugs.

```text
/estate/royal-garden-estate
/property/4-bedroom-duplex-lekki
/blog/making-quality-housing-accessible
```

| Table | Column | Constraint |
|-------|--------|------------|
| `properties` | `slug` | UNIQUE, NOT NULL |
| `estates` | `slug` | UNIQUE, NOT NULL |
| `blogs` | `slug` | UNIQUE, NOT NULL |
| `pages` | `slug` | UNIQUE, NOT NULL |

Slug generation: lowercase, hyphenated, derived from title. Collision suffix: `-2`, `-3`, etc.

---

## Search Optimization

Full-text search via PostgreSQL `tsvector` + GIN indexes.

**Searchable entities:** Properties, Estates, Blog posts, FAQs, Team members, Services.

```sql
-- Example (to be added in Part 2 migration)
ALTER TABLE properties ADD COLUMN search_vector tsvector;
CREATE INDEX idx_properties_search ON properties USING GIN (search_vector);
```

Flutter queries use `textSearch` or RPC `search_properties(query)`.

---

## Data Retention Policy

| Record type | Retention |
|-------------|-----------|
| Payments | Permanent |
| Contracts | Permanent |
| Audit logs | Permanent (immutable) |
| Activity logs | Minimum 5 years |
| Notifications | Configurable (default 1 year) |
| Sessions | Expire automatically (Supabase Auth) |

Soft-deleted records: retained indefinitely unless compliance requires purge (super_admin only).

---

## Migration Strategy

| Rule | Detail |
|------|--------|
| Version control | Every change = new file in `supabase/migrations/` |
| Naming | `YYYYMMDDHHMMSS_descriptive_name.sql` |
| Never manual prod edits | Use CLI or MCP `apply_migration` |
| Test first | Local `supabase db reset` then staging |
| Reversible | Include DOWN comments where practical |
| One concern per migration | Foundation → RBAC → Domain → RLS → Seed |

**Workflow:**

```text
Design (this doc) → Approval → Migration SQL → Local test → Staging → Production
```

---

## Seed Data (Part 1 scope)

Initial seed for new environments:

| Data | Table(s) |
|------|----------|
| Roles (8) | `roles` |
| Permissions (~20) | `permissions` |
| Role-permission mappings | `role_permissions` |
| Company settings | `settings` |
| Homepage hero | `hero_sections` |
| Default navigation | `menus`, `navigation` |
| FAQ categories | `faqs` (category column) |
| Property categories | `property_categories` |
| Property types | `property_types` |
| Notification templates | `notification_templates` (Part 2) |

---

## Core Relationship Overview

```text
Users
│
├── Roles
├── Permissions
├── Profiles (admin / client / investor / staff)
├── Notifications
├── Activity Logs
└── Audit Logs

Properties
│
├── Images (→ media)
├── Videos (→ media)
├── Documents (→ media)
├── Amenities
├── Features
├── Payment Plans
└── Inspections

Clients (client_profiles)
│
├── Reservations
├── Payments
├── Documents
├── Support Tickets
└── Notifications

Investors (investor_profiles)
│
├── Portfolios
├── Transactions
├── Reports
└── Documents
```

---

## Cursor Implementation Checklist

Before creating or altering any table:

| Step | Action | Status |
|------|--------|--------|
| 1 | Explain business purpose | ✅ This document |
| 2 | Define relationships | ✅ ERD above |
| 3 | Define indexes | ✅ Indexing strategy |
| 4 | Define constraints | ✅ Per-table specs |
| 5 | Add audit fields | ✅ Standard defined |
| 6 | Enable RLS | ⏳ Part 3 |
| 7 | Create migration files | ⏳ Awaiting approval |
| 8 | Add seed data | ⏳ Part 6 |
| 9 | Document the table | ✅ This document |
| 10 | Wait for approval | **← Current step** |

---

## Current Schema Alignment (Gap Analysis)

The live database (Volume 1 Part 3) partially implements this spec. Key gaps to resolve in a future alignment migration:

| Target (Part 1) | Current (Live) | Action needed |
|-----------------|----------------|---------------|
| `users` table | `profiles` (extends auth.users) | Rename/refactor or alias view |
| `settings` | `app_settings` | Rename + expand keys |
| `permission_key` format `module.action` | `slug` format `create_property` | Migrate slugs + update RLS functions |
| `display_name` on roles | `name` only | Add column |
| `role_id` on users | via `user_roles` junction only | Add denormalized `role_id` or keep junction |
| `deleted_at`, `deleted_by`, `is_active` | Missing on all tables | Add via migration |
| `admin_profiles`, `staff_profiles` | Missing | Create new tables |
| `client_profiles` (on users) | `clients` + `client_profiles` (on clients) | Restructure FK to users |
| `investor_profiles` (on users) | `investors` table | Restructure FK to users |
| `activity_logs` | `user_activity` + `activities` | Consolidate |
| `media` as central registry | `media` exists but URLs stored inline on many tables | Add `media_id` FKs |
| `avatar_media_id` | `avatar_url` TEXT on profiles | Migrate to media FK |
| PostgreSQL ENUMs for statuses | TEXT `status` columns | Add ENUMs incrementally |
| `notification_type`, `priority` | Partial (channel only) | Extend notifications table |
| Full-text search vectors | Not yet | Part 2 |

**Recommendation:** Do not drop live tables. Apply alignment migrations incrementally after Part 1 approval.

---

## Enterprise Enhancement

**UUID-first architecture with strict migration discipline from day one.**

Combined with:

- Centralized `media` management (no inline URLs)
- Separate `activity_logs` (mutable) vs `audit_logs` (immutable)
- Configurable `settings` (no hardcoded values)
- `user_permissions` overrides (no code changes for exceptions)

This positions HD Homes to add rentals, facility management, or partner portals without structural redesign.

---

**End of Volume 1.5 – Part 1**

*Awaiting your approval before migration work or Part 2.*
