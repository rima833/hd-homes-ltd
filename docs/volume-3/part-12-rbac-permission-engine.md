# Volume 3 — Part 12: RBAC & Permission Engine

Enterprise Authorization Engine — dynamic roles, permission matrix, policy evaluation, approval workflows, and UI/route guards.

## Status

| Layer | Status |
|-------|--------|
| Domain (catalog, PolicyEngine, matrix, groups, approvals) | Done |
| `RbacService` (matrix edits, clone role, audit) | Done |
| RBAC Console UI | Done |
| `PermissionGate` widget | Done |
| SQL + realtime | **Applied** as `rbac_permission_engine` (2026-07-13) |

Local file: `supabase/migrations/20260713200000_rbac_permission_engine.sql`

## Architecture

```text
Login → Auth → Role assignment → Permission Engine / PolicyEngine
  → Allow | Deny | Conditional (approval / ownership / branch)
  → Feature module
  → AuditService
```

No feature should hardcode authorization — call `RbacService.authorize` or wrap UI in `PermissionGate`.

## Routes

| Path | Purpose |
|------|---------|
| `/dashboard/roles` | RBAC Console (matrix, roles, groups, approvals) |

## Console tabs

1. **Matrix** — edit role × permission cells (Super Admin locked full)
2. **Roles** — Smart Permission Builder™ (create / clone / archive)
3. **Groups** — Sales / Finance / Support bundles
4. **Approvals** — delete property, large refund, role change + break-glass / access review stubs

## Permission naming

Canonical: `module.action` (e.g. `properties.view`)  
Database (Phase 1): legacy snake_case (`view_properties`) with catalog alias mapping.

## Enterprise features

1. Smart Permission Builder™  
2. Context-Aware Authorization (ownership / branch / amount)  
3. Break-Glass Mode (schema + UI stub)  
4. Access Review & Certification (schema ready)  
5. Executive Authorization Analytics (dashboard metrics)

## Tests

```bash
flutter test test/rbac_platform_test.dart
```

## Approval gate

Part 12 SQL is applied. Part 13 Personalization is implemented in-app; apply its SQL only after approval.
