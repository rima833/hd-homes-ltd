# Investor Portal — Phase 5 Report (Portfolio & Investment Detail)

**Date:** 2026-09-03  
**Status:** Complete  
**Scope:** Portfolio list + investment detail workspace (`/investor/portfolio`, `/investor/portfolio/:id`)

---

## 1. What was already implemented

- Holdings list with search/sort/grid from `portfolio_holdings`
- Basic detail page (overview + financials only)
- Property image join via `properties` / `property_images`

## 2. What was reused

- `InvestorService.listHoldings` / `getHolding`
- Portal cards, KPI cards, empty/error widgets, realtime holding invalidation
- Existing distributions, documents, intents, activity, construction loaders

## 3. What was removed

- Thin detail page that only showed units/cost/value
- Detail page dependency on a bare `InvestorHolding` (now loads a full bundle)

## 4. What was created / changed

| Change | Detail |
|--------|--------|
| `InvestorHolding` enrich | Development/building/unit parse from label + metadata; ownership/payment/construction fields |
| `InvestorHoldingDetail` | Bundle: holding + distributions + docs + intents + activity + construction |
| `loadHoldingDetail` | Scopes related rows by portfolio/opportunity/property/metadata; single-holding fallback |
| Detail UI | Tabbed workspace: Overview, Financials, Payments, Construction, Documents, Distributions, Activity |
| Portfolio list | Development title, building/unit subtitle, invested amount, skeleton loading |
| Models | `metadata` on distributions/documents/intents; `propertyId` on construction updates |

## 5. Database changes

None.

## 6. RLS changes

None.

## 7. Realtime changes

Existing hub still invalidates `investorHoldingDetailProvider` on portfolio/payment/construction changes.

## 8. Cloudinary changes

None (images via existing property URLs / MediaDeliveryImage).

## 9. Admin connections

Detail data is Admin-assigned holdings + Finance distributions/intents + CPMS construction + DDCMS documents.

## 10. Routes created/changed

None (existing `/investor/portfolio/:holdingId`).

## 11. Tests performed

| Test | Result |
|------|--------|
| Dart analyze detail + portfolio pages | Clean after MediaDeliveryImage / color fixes |
| Label parse for `Victoria Crest — Building 12 Unit 4` | Development / Building / Unit fields populated |
| No invented installment schedule | Payments tab shows real intents only |

## 12. Remaining issues

- Full payment-plan / late-charge ledger still Phase 6
- Construction media depth Phase 7
- Document open-in-place signing still Phase 8
- Message thread pre-filtered by holding still future polish

**Ready for Phase 6** (Payments & Finance) when approved.
