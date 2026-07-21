# Volume 3 — Part 8: KYC & Identity Verification

Enterprise Digital Identity Verification Platform — configurable levels, private document storage, compliance review workspace, and Digital Verification Passport.

## Status

| Layer | Status |
|-------|--------|
| Domain (levels, status, Intelligent Verification Engine™, passport) | Done |
| `KycService` (upload, submit, review, signed URLs) | Done |
| User Identity Verification UI (`/account/kyc`) | Done |
| Compliance Workspace (`/dashboard/compliance`) | Done |
| SQL + private `kyc-documents` bucket | **Applied** as `kyc_identity_verification` (2026-07-13) |

Local file: `supabase/migrations/20260713160000_kyc_identity_verification.sql`.

## Levels

| Level | Name | Typical audience |
|------:|------|------------------|
| 0 | Guest | Public site |
| 1 | Basic | Email + phone |
| 2 | Identity | ID + selfie + address |
| 3 | Investor | Level 2 + compliance declarations |
| 4 | Enterprise | Corporate documents |

## Routes

| Path | Access |
|------|--------|
| `/account/kyc` | Authenticated users |
| `/dashboard/compliance` | Staff (admin shell) |

## Security

- Documents stored in **private** Supabase Storage bucket `kyc-documents`
- Paths: `{user_id}/{type}_{timestamp}.{ext}`
- Previews via **signed URLs** (1 hour), never public object URLs
- RLS: own rows + admin/finance review access

## Enterprise features (Phase 1)

1. **Intelligent Verification Engine™** — progress + trust score  
2. **Smart Compliance Workspace** — review queue + decisions + notes  
3. **AI-assisted review** — interfaces reserved (manual decisions today)  
4. **Digital Verification Passport** — reusable summary for other modules  
5. **Executive analytics** — schema events ready for Part 9+ dashboards  

## Tests

```bash
flutter test test/kyc_platform_test.dart
```

## Approval gate

Part 8 SQL is applied. See Part 9 for the Notification & Communication Center.
