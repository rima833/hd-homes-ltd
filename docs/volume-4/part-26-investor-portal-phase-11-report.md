# Investor Portal — Phase 11 Report (Referrals & KYC)

**Date:** 2026-09-04  
**Status:** Complete — migration applied  
**Migration:** `supabase/migrations/20260904150000_investor_portal_phase11_referrals_kyc.sql`

---

## 1. What was already implemented

- Referrals page with code share (clipboard / WhatsApp / email) + commission list from `investor_referral_commissions`
- Settings KYC line + link to `/account/verification`
- Owner SELECT on referral commissions; staff-only SELECT on KYC reviews (gap)

## 2. What was reused

- `investor_referral_commissions`, `investor_kyc_reviews`, `investor_compliance`, `investors.kyc_status`
- Existing verification center route for document submission
- IMP 360° workspace for staff KYC actions

## 3. What was removed / fixed

- Investor could not read own KYC review history (RLS staff-only)
- No admin RPC to sync `investors.kyc_status` + append review row
- Referrals UI lacked program rules / live chip / successful-referral KPI
- Settings KYC was status text only (no review history / compliance meta)

## 4. What was created / changed

| Change | Detail |
|--------|--------|
| RLS | `investor_kyc_reviews_portal_owner` SELECT for owner + staff |
| RLS | `investor_referral_commissions_staff` FOR ALL (staff / investors.write / referrals) |
| RPC | `admin_verify_investor_kyc(investor_id, status, notes)` |
| Models | `InvestorKycBundle`, `InvestorKycReview`, `InvestorReferralProgramRules`; enriched referral summary |
| Service | `loadKycBundle`; richer `loadReferrals`; IMP `verifyInvestorKyc` |
| Providers | `investorKycBundleProvider`; realtime bucket `kyc` |
| Referrals UI | Rules steps, live chip, successful referrals KPI |
| Settings UI | KYC section with status, compliance chips, review history, live chip |
| IMP UI | 360° KYC verify actions (under review / approve / reject / resubmit) |

## 5. Database changes

SECURITY DEFINER function `admin_verify_investor_kyc` only (no new tables).

## 6. RLS changes

- Owner SELECT on `investor_kyc_reviews`
- Staff write policy on `investor_referral_commissions`

## 7. Realtime changes

- `investor_kyc_reviews` added to `supabase_realtime` + `REPLICA IDENTITY FULL`
- Investor hub listens + invalidates KYC bundle / record / dashboard
- IMP realtime invalidates on `investor_kyc_reviews`

## 8. Cloudinary changes

None (KYC document upload remains on verification center).

## 9. Admin connections

IMP Command Center → `admin_verify_investor_kyc` → `investors.kyc_status` + `investor_kyc_reviews` → investor Settings / dashboard refresh live.

Staff award commissions via `investor_referral_commissions` writes → Referrals page live.

## 10. Routes created/changed

None (`/investor/referrals`, `/investor/settings`; verification still `/account/verification`).

## 11. Tests performed

| Test | Result |
|------|--------|
| Apply Phase 11 migration | Success |
| Confirm `admin_verify_investor_kyc` exists (SECURITY DEFINER) | Success |
| Confirm `investor_kyc_reviews` in realtime publication | Success |
| Dart analyze Phase 11 touchpoints | No errors (pre-existing warnings only) |

## 12. Remaining issues

- Program reward rates are copy/rules in UI — not a DB rate table (admin still awards absolute commission amounts)
- Full KYC document capture UX lives on account verification center (not duplicated in portal)

**Ready for Phase 12** (Notifications).
