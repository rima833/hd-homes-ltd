# Volume 1.5 – Enterprise Database & Supabase Blueprint

**HD Homes Ltd – Enterprise PropTech Platform**

This volume is the authoritative backend specification. Every Flutter entity, repository, Edge Function, and Supabase migration must align with these documents.

**Status: Blueprint complete (Parts 1–6) — awaiting approval before implementation.**

---

## Parts

| Part | Document | Topic | Status |
|------|----------|-------|--------|
| **1** | [Database Philosophy & Core Schema](./part-01-philosophy-and-core-schema.md) | Users, RBAC, media, audit | Draft |
| **2** | [Property & Estate Architecture](./part-02-property-estate-architecture.md) | Listings, estates, search, AI | Draft |
| **3** | [Client, Investor & CRM](./part-03-client-investor-crm-architecture.md) | Leads, 360° CRM, referrals | Draft |
| **4** | [Finance & Construction](./part-04-finance-construction-architecture.md) | Payments, ledger, projects | Draft |
| **5** | [CMS, Marketing & Analytics](./part-05-cms-marketing-analytics.md) | Headless CMS, campaigns, A/B | Draft |
| **6** | [Enterprise Supabase Infrastructure](./part-06-enterprise-supabase-infrastructure.md) | Security, Edge Functions, DR | Draft |

---

## Implementation Rule

**No schema migrations, Edge Functions, or infrastructure changes are applied until Volume 1.5 is reviewed and approved.**

The live database (74 tables, 18 buckets, 7 migrations) was created during Volume 1 Part 3. Volume 1.5 defines the **target enterprise standard**. Alignment migrations will be planned per the [Part 6 Implementation Roadmap](./part-06-enterprise-supabase-infrastructure.md#volume-15-implementation-roadmap).

---

## Quick Reference

| Item | Value |
|------|-------|
| Production project | `wbonjdqsifwsawhhxygl` (eu-west-1) |
| Live tables | 74 (all RLS enabled) |
| Live storage buckets | 18 |
| Target tables | 150+ across 12 schemas |
| Target Edge Functions | 30+ |
| Local migrations | `supabase/migrations/` |
| Flutter Supabase config | `lib/core/config/supabase_config.dart` |
| Environment template | `env.example.json` |

---

## What's Next

1. **Review & approve** Volume 1.5 (all 6 parts)
2. **Alignment migrations** — Phase A through F per Part 6 roadmap
3. **Volume 2** — Public Website (premium HD Homes web experience)

---

## Document Conventions

- All tables use UUID primary keys (Part 1)
- All tables include audit fields: `created_at`, `updated_at`, `created_by`, `updated_by`, `deleted_at`, `deleted_by`, `status`, `is_active`, `is_deleted`
- Soft delete only — never hard-delete business or financial records
- RLS on every table — no exceptions
- Media via `media_library` FK — never inline URLs in target schema
- Permissions use `module.action` format (e.g. `property.create`)
