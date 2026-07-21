# Volume 3 — Part 4: Email & Phone Verification

Unified Verification Service™ for HD Homes — reusable email/phone verification, Smart Verification Policies, OTP UI, Verification Center, and Trust Score foundation.

## Status

**Phase 1 complete** — app code + remote SQL applied.  
Verification SQL (`20260713120000_email_phone_verification.sql`) applied as `email_phone_verification` (2026-07-13).

Part 3 login SQL applied as `login_secure_authentication` (2026-07-13).

## Routes

| Route | Access | Notes |
|-------|--------|-------|
| `/verify-email` | Public | Premium email verification handoff + resend + status |
| `/account/verification` | Authenticated | Verification Center |
| `/account/verify-phone` | Authenticated | OTP phone verification |

## Architecture

```
lib/features/authentication/
├── domain/
│   ├── entities/verification_models.dart   # statuses, policies, trust score
│   └── services/
│       ├── verification_service.dart       # Unified Verification Service™
│       ├── phone_otp_service.dart
│       └── sms_provider_adapters.dart      # Termii/Twilio/AT + failover
├── data/services/verification_service_impl.dart
└── presentation/
    ├── providers/verification_controller.dart
    ├── pages/
    │   ├── verify_email_page.dart
    │   ├── phone_verify_page.dart
    │   └── verification_center_page.dart
    └── widgets/otp_code_input.dart
```

## Policies (defaults)

| Role | Email | Phone | MFA |
|------|-------|-------|-----|
| Client | Required | Optional | — |
| Investor | Required | Required | — |
| Staff | Required | Required | — |
| Super Admin | Required | Required | Recommended |

Stored in app catalog; DB table `verification_policies` (when SQL applied) for admin edits.

## SMS providers

- Primary: `MockPhoneOtpService` (dev code `123456`)
- Failover stubs: Termii, Twilio, Africa's Talking
- UI never depends on provider specifics

## Draft SQL

`supabase/migrations/20260713120000_email_phone_verification.sql`

- `verification_events`, `email_change_requests`, `phone_change_requests`, `otp_requests`
- `profiles.phone_verified`, `profiles.trust_score`
- `verification_policies` seed
- `record_verification_event(...)` RPC

## Tests

- `test/verification_service_test.dart`

## Approval gate

Awaiting approval before:

1. Starting **Volume 3 Part 5 — Password Recovery & Account Security** — ✅ App Phase 1 (see [Part 5](./part-05-password-recovery-account-security.md))

~~Previously pending: applying `20260713120000_email_phone_verification.sql`~~ ✅ Applied (`email_phone_verification`)
