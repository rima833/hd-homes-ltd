# Volume 3 — Part 5: Password Recovery & Account Security

Secure password recovery, Adaptive Password Policies, Security Health Dashboard™, and Account Security Center.

## Status

**Phase 1 complete.**  
SQL applied remotely as `password_recovery_account_security` (2026-07-13).

Part 4 verification SQL applied as `email_phone_verification` (2026-07-13).

## Routes

| Route | Access | Notes |
|-------|--------|-------|
| `/forgot-password` | Public | Premium recovery request (anti-enumeration copy) |
| `/reset-password` | Recovery session | New password + strength meter; allowed while recovery session active |
| `/account/security` | Authenticated | Security Center |

Configure Supabase Auth redirect URL to `/reset-password` for recovery emails.

## Architecture

```
domain/
  entities/account_security_models.dart   # policies, health score, risk signals
  services/account_security_service.dart  # reset / change / revoke / audit
presentation/
  providers/account_security_controller.dart
  pages/
    forgot_password_page.dart
    reset_password_page.dart
    security_center_page.dart
```

## Flows

1. **Forgot password** → cooldown + daily limits → Supabase `resetPasswordForEmail` → audit  
2. **Reset link** → recovery session → validate policy → `updateUser(password)` → revoke sessions → sign out → login  
3. **Change password** (Security Center) → re-auth → update → optional revoke others  

## Security Health Dashboard™

Score from password strength, email/phone verification, MFA (Part 6), session hygiene + recommendations.

## Draft SQL

`supabase/migrations/20260713130000_password_recovery_account_security.sql`

- `password_reset_requests`
- `password_change_history` (reuse prevention future-ready; no plaintext hashes)
- `password_policies` (role-based, admin editable)

## Tests

- `test/account_security_test.dart`

## Approval gate

Awaiting approval before:

1. Applying `20260713130000_password_recovery_account_security.sql`
2. Starting **Volume 3 Part 6 — Multi-Factor Authentication (MFA)**
