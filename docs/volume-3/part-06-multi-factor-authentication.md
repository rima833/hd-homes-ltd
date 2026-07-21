# Volume 3 — Part 6: Multi-Factor Authentication (MFA)

Enterprise MFA platform for **HD Homes Ltd** — TOTP, backup codes, trusted devices, Adaptive Security Engine™, and Security Center management.

## Status

| Layer | Status |
|-------|--------|
| Domain (policies, Adaptive Security Engine™, models) | Done |
| `MfaService` (Supabase Auth MFA + hashed backup codes) | Done |
| Riverpod providers / controller | Done |
| Setup wizard (`/account/mfa/setup`) | Done |
| Login challenge (`/mfa/challenge`) | Done |
| Security Center MFA management | Done |
| SQL migration | **Applied** as `multi_factor_authentication` (2026-07-13) |

Local file: `supabase/migrations/20260713140000_multi_factor_authentication.sql`.

## Architecture

```text
Password login → Adaptive Security Engine™
  → enrollment required → /account/mfa/setup
  → second factor required → /mfa/challenge
  → trusted device / AAL2 → Smart Login Router™
```

### Primary factor

Supabase GoTrue MFA **TOTP** (`auth.mfa.enroll` / `challengeAndVerify`). Compatible with Google Authenticator, Microsoft Authenticator, Authy, 1Password, Bitwarden.

### Business metadata (PostgreSQL)

| Table | Purpose |
|-------|---------|
| `mfa_settings` | Enabled flag, preferred method |
| `backup_codes` | SHA-256 hashed one-time recovery codes |
| `mfa_events` | MFA audit trail |
| `mfa_policies` | Role requirement / trust duration (Admin editable) |
| `trusted_devices.mfa_trusted_until` | Device trust window |
| `user_sessions` MFA columns | Session MFA metadata (future-ready) |

Secrets never leave Supabase Auth; the app only stores hashed backup codes and policy metadata.

## Policy defaults

| Role | Requirement |
|------|-------------|
| Client | Optional |
| Investor | Recommended |
| Staff roles | Required |
| Super Admin | Mandatory (no email fallback; shorter trust window) |

## Key routes

| Path | Purpose |
|------|---------|
| `/account/mfa/setup` | Guided enrollment wizard |
| `/mfa/challenge` | Post-login second factor |
| `/account/security` | MFA enable/disable, backup codes, trusted devices |

## Enterprise features (Phase 1 foundations)

1. **Adaptive Security Engine™** — login MFA / step-up decisions by role, trust, and AAL.
2. **Enterprise Device Trust Manager** — trust duration, revoke, Security Center list.
3. **Step-up authentication** — `StepUpAction` + engine hooks for sensitive actions.
4. **Security Readiness Score** — Part 5 health + MFA / backup / trust bonuses.
5. **MFA Compliance Dashboard** — admin UI deferred; `mfa_policies` + `mfa_events` ready.

## Enable MFA in Supabase

In the Supabase Dashboard → Authentication → Multi-Factor → enable **TOTP**. Without this, enrollment calls fail.

## Tests

```bash
flutter test test/mfa_platform_test.dart
```

## Next

Part 6 is complete. **Part 7 — User Profiles & Account Management** is in progress / see `part-07-user-profiles-account-management.md`.

Also enable **TOTP** in Supabase Dashboard → Authentication → Multi-Factor if not already on.
