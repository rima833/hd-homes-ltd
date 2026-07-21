# Volume 3 — Part 7: User Profiles & Account Management

Enterprise User Profile Platform — single identity hub for clients, investors, staff, and administrators.

## Status

| Layer | Status |
|-------|--------|
| Domain (`profile_models.dart`, completion & health engines) | Done |
| `ProfileService` (CRUD, prefs, avatars, activity) | Done |
| Riverpod providers / controller | Done |
| Profile Center UI (`/account/profile`) | Done |
| Portal settings/profile routes wired | Done |
| SQL migration | **Applied** as `user_profiles_account_management` (2026-07-13) |

Local file: `supabase/migrations/20260713150000_user_profiles_account_management.sql`.

## Architecture

```text
Supabase Auth (credentials)
        │
PostgreSQL profiles + company_profiles + preferences
        │
ProfileService → ProfileHubSnapshot
        │
Profile Center (Dynamic User Identity™ tabs)
```

## Routes

| Path | Purpose |
|------|---------|
| `/account/profile` | Profile Center (all roles) |
| `/client/settings` | Same Profile Center |
| `/investor/settings` | Same Profile Center |
| `/dashboard/profile` | Same Profile Center |
| `/dashboard/settings` | Same Profile Center (admin account prefs) |

Quick links to Security Center and Verification remain available.

## Sections (Dynamic User Identity™)

Shared tabs with role-aware company visibility:

Overview · Personal · Contact · Company (investors/staff) · Notifications · Regional · Appearance · Privacy · Connected (soon) · Account

## Enterprise features

1. **Intelligent Profile Completion Engine™** — weighted checklist + recommendations  
2. **Dynamic User Identity™** — one architecture, role-specific surfaces  
3. **Smart Preference Engine** — `user_preferences` + extras (theme, locale, privacy)  
4. **Account Health Score** — completion + verification + MFA + security readiness  
5. **Digital Identity Timeline** — `profile_activity` events  

## Storage

Avatars use the existing public `avatars` bucket (`{user_id}/avatar.*`).

## SQL (pending)

Extends `profiles` with personal/contact fields; adds `company_profiles`, `profile_activity`, `profile_completion`.

## Tests

```bash
flutter test test/profile_platform_test.dart
```

## Approval gate

Part 7 SQL is applied. See Part 8 for KYC.
