# Volume 3 — Part 3: Login & Secure Authentication

Unified Authentication Gateway for HD Homes — premium login, Smart Login Router™, session security, and future-ready auth methods.

## Status

**Phase 1 complete** — app code + remote SQL applied.  
Login SQL (`20260713110000_login_secure_authentication.sql`) applied as `login_secure_authentication` (2026-07-13).

## Routes

| Route | Access | Notes |
|-------|--------|-------|
| `/login` | Public | Split brand panel + form; honors `?redirect=` |
| `/forgot-password` | Public | Password reset request |
| `/account/sessions` | Authenticated | Active session list / revoke / sign out everywhere |

## Architecture

```
lib/features/authentication/
├── domain/
│   ├── entities/login_models.dart
│   ├── services/
│   │   ├── smart_login_router.dart      # Smart Login Router™
│   │   ├── login_validator.dart
│   │   ├── auth_method_gateway.dart     # Future methods matrix
│   │   └── device_fingerprint_service.dart
│   └── repositories/session_repository.dart
├── data/repositories/session_repository_impl.dart
└── presentation/
    ├── pages/login_page.dart            # Premium split UI
    ├── pages/active_sessions_page.dart
    └── widgets/
        ├── auth_password_field.dart     # Show/hide + Caps Lock
        ├── login_brand_panel.dart
        └── social_login_buttons.dart    # Disabled (coming soon)
```

Core IAM reused from Part 1:

- `SecurityService` — progressive delay, lockout, audit persist via `record_auth_event` RPC (when applied)
- `SessionService` / `TokenService` — inactivity + JWT refresh
- `RouteAuthorization` — guards + email-pending → `/verify-email`

## Login journey

1. Credentials validated (non-revealing errors)
2. Progressive delay / lockout when abuse detected
3. Supabase Auth `signInWithPassword`
4. Account status checks (suspended / inactive / deleted)
5. Remember-me preference stored (no plaintext credentials)
6. Profile + permissions refresh
7. Device/session registration (`register_login_session` when SQL applied)
8. **Smart Login Router™** destination
9. Realtime auth listeners already owned by `identitySessionProvider`

## Smart Login Router™ priority

1. Email / account verification flows  
2. Safe same-app `redirect` path  
3. Incomplete profile → settings  
4. Role default (`/client`, `/investor`, `/dashboard`)

## Future-ready methods (disabled UI)

- Phone + password  
- Magic link  
- Google / Apple / Microsoft OAuth  

## Draft SQL (awaiting approval)

`supabase/migrations/20260713110000_login_secure_authentication.sql`

- `record_auth_event(...)` — authentication_logs + login_history + security_events  
- `register_login_session(...)` — trusted_devices + user_sessions  
- `revoke_user_session(...)`  
- INSERT policies for durable client/RPC audit writes  

## Tests

- `test/login_secure_auth_test.dart` — validator, Smart Login Router, method flags  

## Approval gate

Awaiting approval before:

1. Starting **Volume 3 Part 4 — Email & Phone Verification** — ✅ App Phase 1 (see [Part 4](./part-04-email-phone-verification.md))

~~Previously pending: applying `20260713110000_login_secure_authentication.sql`~~ ✅ Applied (`login_secure_authentication`)
