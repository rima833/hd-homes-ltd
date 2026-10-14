# Investor Portal — Phase 2 Report (Database & Security)

**Date:** 2026-09-03  
**Status:** Complete — migration applied to remote Supabase  
**Migration:** `supabase/migrations/20260903120000_investor_portal_phase2_security.sql`

---

## 1. What was already implemented

- Investor portal tables, owner-scoped RLS helpers (`investor_id_for_user`)
- Finance RPC `admin_confirm_investor_intent` (settlement + receipt + wallet)
- Live `admin_publish_document_to_investor` (was remote-only; now in local migrations)
- Construction progress investor SELECT policies (updates table only)

## 2. What was reused

- Existing `investor_payment_intents` table & status check constraint
- Existing `is_staff()` / `has_role()` / `has_permission()` helpers
- Existing DDCMS publish signature and Finance confirm RPC (unchanged callers)
- Construction ownership joins via `portfolio_holdings` / `client_properties`

## 3. What was removed

- Legacy RLS policy `investor_payment_intents_own` (**FOR ALL** — allowed self-confirm)
- Dead Flutter route duplicate `lib/features/investor/presentation/routes/investor_routes.dart`  
  (canonical routes remain in `shell_routes.dart`)

## 4. What was created

| Change | Detail |
|--------|--------|
| Split payment-intent RLS | SELECT / INSERT / limited UPDATE (owner) + staff ALL |
| Owner guard trigger | Blocks amount/currency/provider/paid_at mutation and settlement statuses for non-staff |
| Construction media RLS | `construction_update_media_investor_read` + `_client_read` |
| `ensure_investor_record` | Requires existing investor row **or** `investor` role — no auto-provision for clients/staff |
| `admin_publish_document_to_investor` | Local migration mirror + investor existence check + activity log best-effort |
| Smoke RPC | `investor_portal_phase2_security_smoke()` |
| Isolation SQL | `supabase/tests/investor_portal_phase2_rls_isolation.sql` |
| Flutter UX | Friendlier error when RPC returns `investor_not_provisioned` |

## 5. Database changes

- Policies + trigger on `investor_payment_intents`
- Policies on `construction_update_media`
- Function replacements: `ensure_investor_record`, `admin_publish_document_to_investor`
- New functions: `investor_payment_intents_owner_guard`, `investor_portal_phase2_security_smoke`

No new business tables.

## 6. RLS changes

**Before:** owner `FOR ALL` on payment intents → investor could UPDATE `status` to `confirmed`.  
**After:** investors may INSERT (`pending`/`awaiting_confirmation`) and UPDATE only to cancel / attach notes while open; settlement via Finance RPC only.

Media: investors/clients can SELECT media for published updates with matching visibility + ownership (parity with progress updates).

## 7. Realtime changes

None in Phase 2 (deferred to Phase 3).

## 8. Cloudinary changes

None.

## 9. Admin connections

- Finance confirm path unchanged (`admin_confirm_investor_intent`)
- DDCMS `publishToInvestor` now backed by migration-tracked RPC

## 10. Routes created/changed

- Removed unused duplicate `investor_routes.dart` only
- Live `/investor/*` shell routes unchanged

## 11. Tests performed

| Test | Result |
|------|--------|
| `select investor_portal_phase2_security_smoke()` | `ok: true` |
| Isolation DO block (A≠B docs/holdings/intents/conversations predicates) | Passed |
| Confirmed-status insert blocked (trigger/RLS) | Blocked as expected |
| Policy catalog: legacy `*_own` FOR ALL gone | Confirmed |

## 12. Remaining issues (next phases)

- Investor installment / late-charge ledger still absent (Phase 6)
- Docs still primarily Supabase Storage (Cloudinary vault later)
- Realtime hub cleanup of stale construction table names (Phase 3)
- Holding detail depth, support threads, mobile More nav (Phases 4+)
- End-to-end JWT-impersonated PostgREST tests still recommended in CI

**Do not claim payments/construction UX complete** — only security foundations for Phase 2.

---

## Exit criteria

- [x] Payment intent self-settlement closed  
- [x] Construction media investor/client read policies  
- [x] Document publish RPC in local migrations  
- [x] Isolation smoke script + catalog smoke RPC  
- [x] Dead routes removed  
- [x] Remote migration applied  

**Ready for Phase 3** (realtime foundation cleanup) when approved.
