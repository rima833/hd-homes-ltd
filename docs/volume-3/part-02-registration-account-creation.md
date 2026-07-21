# Volume 3 — Part 2: Registration & Account Creation

Progressive Registration™ for HD Homes — multi-step onboarding for clients and investors.

## Status

**Phase 1 complete** — app code + remote SQL applied.  
Registration SQL (`20260713081000_registration_onboarding.sql`) applied as `registration_onboarding` (remote version `20260713094558`) on project `wbonjdqsifwsawhhxygl` (2026-07-13).

## Routes

| Route | Page | SEO |
|-------|------|-----|
| `/register` | Multi-step `RegisterPage` | index |
| `/register?type=investor&ref=CODE&email=…&invite=…` | Prefills account type, referral, email, invite token | index |
| `/verify-email?email=…&type=…` | Email verification handoff + resend | noindex |
| `/welcome?type=…` | Welcome / next-steps experience | noindex |

## Architecture

```
lib/features/authentication/
├── domain/
│   ├── entities/registration_models.dart
│   ├── services/
│   │   ├── registration_validator.dart
│   │   ├── registration_assistant.dart
│   │   ├── captcha_service.dart
│   │   └── phone_otp_service.dart
│   └── repositories/registration_repository.dart
├── data/
│   └── repositories/registration_repository_impl.dart
└── presentation/
    ├── providers/registration_controller.dart
    ├── pages/
    │   ├── register_page.dart
    │   ├── verify_email_page.dart
    │   └── welcome_page.dart
    └── widgets/
        ├── account_type_cards.dart
        ├── password_strength_meter.dart
        └── registration_stepper_header.dart
```

## Steps

1. **Account type** — Client / Investor (future types shown disabled)
2. **Personal info** — name, email, phone, location, optional referral
3. **Credentials** — password + confirm + strength meter / checklist
4. **Legal** — Terms, Privacy, Cookies + optional marketing opts
5. **Review** — summary → Create Account

## Post-create flow

- Supabase Auth `signUp` with rich `user_metadata` (`account_type`, legal versions, prefs, referral)
- On email confirmation required → `/verify-email`
- If already confirmed → `/welcome` with role-specific next steps

## Role assignment

Handled by DB trigger once registration migration is applied:

- `account_type=investor` → `investor` role
- otherwise → `client` role

Plus preferences, security settings, legal acceptances, referral rows.

## Tests

- `test/registration_flow_test.dart` — validator, password strength, account types, assistant tips

## Approval gate

Awaiting approval before:

1. Starting **Volume 3 Part 4 — Email & Phone Verification**

~~Previously pending: applying `20260713081000_registration_onboarding.sql`~~ ✅ Applied (`registration_onboarding`)  
~~Part 3 Login~~ ✅ App Phase 1 (see [Part 3](./part-03-login-secure-authentication.md); login SQL pending)
