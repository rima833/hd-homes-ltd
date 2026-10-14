# Investor Portal — Phase 6 Report (Payments & Finance)

**Date:** 2026-09-03  
**Status:** Complete — migration applied  
**Migration:** `supabase/migrations/20260903140000_investor_portal_phase6_payments.sql`

---

## 1. What was already implemented

- Bank-transfer intents table + owner/staff RLS (hardened in Phase 2)
- Finance Admin `admin_confirm_investor_intent` (receipt + wallet credit)
- Basic payments page with simple intent dialog

## 2. What was reused

- `investment_receiving_accounts`, `investor_payment_intents`, `payments`, `finance_receipts`
- Cloudinary signed upload via `mediaServiceProvider`
- FAPMS confirm path unchanged

## 3. What was removed

- One-shot “confirm transfer intent” dialog that skipped confirmation fields
- Direct client INSERT for new payment path (deprecated `createBankTransferIntent`)

## 4. What was created / changed

| Change | Detail |
|--------|--------|
| RLS | `finance_receipts_investor_read` — investors see receipts for their payments |
| RPC | `investor_submit_bank_transfer` — always `awaiting_confirmation`; never settled by investor |
| Service | `submitBankTransfer`, `listSettledPayments`, `listPaymentReceipts` |
| Models | Intent display helpers + `InvestorSettledPayment` / `InvestorPaymentReceipt` |
| UI | Multi-step bank transfer sheet (investment → amount → company account → confirmation + optional proof) |
| Payments page | Outstanding KPI; tabs Pending / History / Distributions / Receipts |

## 5. Database changes

- New policy on `finance_receipts`
- New function `investor_submit_bank_transfer(...)`
- No new installment/late-charge tables (still deferred — use intents + Admin Finance; client installment engine remains separate)

## 6. RLS changes

Investor receipt SELECT via payment ownership join.

## 7. Realtime changes

Existing intents/payments subscriptions continue to refresh the payments provider.

## 8. Cloudinary changes

Optional proof upload to `hdhomes/investors/{investorId}/evidence` (metadata stored on intent; no API secret on client).

## 9. Admin connections

Finance Command Center still verifies via `admin_confirm_investor_intent` → investor sees History + Receipts live.

## 10. Routes created/changed

None (`/investor/payments`).

## 11. Tests performed

| Test | Result |
|------|--------|
| Apply Phase 6 migration | Success |
| Dart analyze payments/sheet/service | No errors |
| Investor cannot settle via RPC | Status forced to `awaiting_confirmation` |

## 12. Remaining issues

- Dedicated investor installment / late-fee ledger still not in schema (product may continue with capital intents)
- PDF receipt download UX still Phase 8/10
- Construction Phase 7 next

**Ready for Phase 7** (Construction) when approved.
