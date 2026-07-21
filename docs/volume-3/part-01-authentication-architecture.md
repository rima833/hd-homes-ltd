# Volume 3 — Part 1: Authentication Architecture & Identity Management

Phase 1 IAM foundation for HD Homes. Login/register **screens already exist** from Volume 1; this part strengthens the identity platform underneath them. **Part 2** will redesign premium registration / onboarding.

## Status

**Implemented in code.** Migration **applied** to Supabase project `wbonjdqsifwsawhhxygl` (`identity_platform_sessions_devices`).

## Architecture

```
Supabase Auth  →  Session / Token services  →  Profile + RBAC
                         ↓
              AuthSessionSnapshot (Riverpod)
                         ↓
         RouteAuthorization + PermissionEngine
                         ↓
        Client / Investor / Admin shells
```

## Code map

```
lib/core/auth/
├── auth.dart
├── models/          # AuthStatus, AuthSessionSnapshot, SecurityEvent
├── policies/        # AuthSecurityPolicy
├── routing/         # RouteAuthorization
└── services/        # Session, Permission, Security, Token

lib/features/authentication/
├── data/            # Datasource + repository (permissions RPC, friendly errors)
├── domain/          # Entities, repository contract, usecases
└── presentation/
    └── providers/
        ├── identity_provider.dart   # Global IAM session
        └── auth_controller.dart     # Sign-in / out actions

supabase/migrations/
└── 20260713065853_identity_platform_sessions_devices.sql  # DRAFT
```

## Authentication states

`AuthStatus`: unauthenticated → authenticating → authenticated | emailPending | verificationPending | suspended | inactive | deleted

Resolved via `resolveAuthStatus()` from session + `profiles.account_status` + email confirmation.

## Global provider

`identitySessionProvider` is the single source of truth:

- Current `AuthSessionSnapshot`
- Profile, roles, permissions
- Session refresh / inactivity hooks
- Sign-out (local or all devices)

Consumers should prefer this over talking to Supabase Auth directly.

## Route protection

`RouteAuthorization.evaluate()` + GoRouter `refreshListenable` in [`app_router.dart`](../../lib/core/router/app_router.dart):

- Public vs protected prefixes
- Auth-route bounce when already signed in
- Role gates for `/dashboard`, `/client`, `/investor`
- Blocked accounts redirected with safe messages

## Permissions

1. Try RPC `get_user_permission_slugs` (applied on remote)
2. Fallback: `PermissionEngine` role → slug map matching seed data

`hasPermissionProvider(slug)` for UI action gates.

## Session intelligence

`SessionService`:

- Activity tracking
- Inactivity warning (25m) / timeout logout (30m)
- Proactive refresh within 2m of JWT expiry
- `SignOutScope.global` for logout everywhere

## Security monitoring

`SecurityService`:

- Failed login counting + client lockout
- Local event buffer + best-effort `authentication_logs` insert
- Events: login, logout, password reset, suspicious, session revoked

## Database (applied)

New / extended tables on remote:

- `user_sessions`, `trusted_devices`, `login_history`
- `security_events`, `authentication_logs`
- `user_preferences`, `notification_preferences`
- `investor` role + `get_user_permission_slugs()`

Depends on existing Volume 1.5 RBAC (`profiles`, `roles`, `permissions`, RLS helpers).

## Approval gate

1. ~~Applying `20260713065853_identity_platform_sessions_devices.sql`~~ ✅ Applied
2. ~~Starting **Volume 3 Part 2 — Registration & Account Creation**~~ ✅ Complete (app + SQL; see [Part 2](./part-02-registration-account-creation.md))
