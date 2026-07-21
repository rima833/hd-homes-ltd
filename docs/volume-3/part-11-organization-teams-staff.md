# Volume 3 — Part 11: Organization, Teams & Staff Management

Enterprise Organization & Staff Management — departments, teams, employee directory, reporting hierarchy, onboarding, and branch offices.

## Status

| Layer | Status |
|-------|--------|
| Domain (statuses, departments catalog, hierarchy, onboarding) | Done |
| `OrganizationService` (directory, analytics, onboarding, audit) | Done |
| Organization Hub UI | Done |
| Routes (`/dashboard/organization`, `/dashboard/users`) | Done |
| SQL + realtime publication | **Applied** as `organization_teams_staff` (2026-07-13) |

Local file: `supabase/migrations/20260713190000_organization_teams_staff.sql`

## Architecture

```text
Admin Hub
  → OrganizationService
      → departments / teams / employees / branches
      → reporting hierarchy (manager_id)
      → onboarding checklist
      → AuditService.publish (organization events)
  → Supabase Realtime → Hub refresh
```

## Routes

| Path | Purpose |
|------|---------|
| `/dashboard/organization` | Organization Hub |
| `/dashboard/users` | Same hub (staff directory entry) |

## Hub tabs

1. **Directory** — searchable staff cards + detail (Godwin-style profile layout)
2. **Departments** — 11 seeded departments + branches
3. **Teams** — Sales & Marketing example teams
4. **Org Chart** — Managing Director → GM → managers → officers
5. **Onboarding** — guided 7-step staff activation

## Default departments

Executive Management · Sales & Marketing · Finance & Accounts · Construction & Operations · Architecture & Design · Survey & Land Services · Customer Support · Human Resources · Legal & Compliance · Technology & Systems · Investor Relations

## Employee codes

Format: `HDH-EMP-####` (e.g. `HDH-EMP-0012`)

## Tests

```bash
flutter test test/organization_platform_test.dart
```

## Approval gate

Part 11 SQL is applied. **Part 12 — RBAC & Permission Engine** is implemented in-app; apply its SQL only after approval.
