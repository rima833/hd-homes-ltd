# Investor Portal — Phase 13 Report (Admin Integration)

**Date:** 2026-09-04  
**Status:** Complete — migration applied  
**Migration:** `supabase/migrations/20260904170000_investor_portal_phase13_admin_integration.sql`

---

## 1. What was already implemented

- IMP Command Center read snapshot (investors, opportunities, holdings, etc.)
- Phase 11–12 write paths: KYC verify + targeted notifications
- `admin_publish_document_to_investor` (Phase 8) — RPC only, not wired in IMP UI
- Investor portal realtime for holdings / documents / messages / notifications

## 2. What was reused

- Existing `admin_publish_document_to_investor`
- `admin_publish_investor_notification` for post-publish vault alerts
- IMP 360° workspace as the staff action surface
- Existing portfolio / conversation / document tables (no parallel schema)

## 3. What was removed / fixed

- Staff portfolio writes previously required `investors.portfolio` only — now include `is_staff()` / `investors.write`
- No staff RPC to assign holdings or message investors from IMP
- Document publish existed in SQL but had no IMP action UI

## 4. What was created / changed

| Change | Detail |
|--------|--------|
| RPC | `admin_assign_investor_holding` — portfolio ensure, holding insert, optional funded commitment, activity, notify |
| RPC | `admin_message_investor` — open/continue conversation, staff reply, notify |
| RLS | Portfolio / holdings / commitments write policies include `is_staff()` |
| ImpService | `assignInvestorHolding`, `publishDocumentToInvestor`, `messageInvestor`, `listPublishableDocuments` |
| IMP 360 UI | Assign investment · Publish document · Message investor (plus existing KYC/Notify) |
| Realtime | IMP hub listens to holdings / documents / conversations |

## 5. Database changes

Two SECURITY DEFINER functions + policy updates (no new tables).

## 6. RLS changes

`investor_portfolios_write`, `portfolio_holdings_write`, `investment_commitments_write` expanded for staff desks.

## 7. Realtime changes

IMP invalidates on `portfolio_holdings`, `investor_documents`, `investor_conversations`. Investor portal already covered.

## 8. Cloudinary changes

None (document publish continues to use Storage / HTTPS / Cloudinary URLs from DDCMS).

## 9. Admin connections

```text
IMP 360
  ├─ Assign holding     → portfolio + commitment + notification → /investor/portfolio/:id
  ├─ Publish document   → investor_documents + notification → /investor/documents
  ├─ Message investor   → conversations + notification → /investor/messages
  ├─ KYC verify         → investors + kyc_reviews (Phase 11)
  └─ Notify             → investor_notifications (Phase 12)
```

## 10. Routes created/changed

None. Deep links use existing `/investor/*` routes.

## 11. Tests performed

| Test | Result |
|------|--------|
| Apply Phase 13 migration | Success |
| RPCs `admin_assign_investor_holding` / `admin_message_investor` exist | Confirmed |
| Dart analyze IMP service + 360 page | No errors |

## 12. Remaining issues

- Document picker lists recent DDCMS rows (including archived seeds) — ops should prefer live vault docs
- Full desk polish (skeletons, mobile More hub, a11y) remains Phase 14

**Ready for Phase 14** (Polish).
