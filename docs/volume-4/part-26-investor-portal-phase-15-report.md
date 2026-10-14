# Investor Portal — Phase 15 Report (E2E Tests)

**Date:** 2026-09-04  
**Status:** Complete  
**Migration:** `supabase/migrations/20260904180000_investor_portal_phase15_e2e_smoke.sql`

---

## 1. What was already implemented

- Unit coverage in `test/investor_portal_test.dart` (routes + core models)
- Phase 2 security smoke RPC
- Full Phases 2–14 feature surface (admin write → investor live)

## 2. What was reused

- `investor_portal_phase2_security_smoke()` nested inside Phase 15 smoke
- NavigationConfig / AppBottomNav / domain models as contract anchors

## 3. What was removed / fixed

- No production bugs found; portfolio notification category label now resolves to **Portfolio**

## 4. What was created / changed

| Artifact | Detail |
|----------|--------|
| `test/investor_portal_e2e_scenario_test.dart` | Admin→investor scenario contract suite |
| `investor_portal_phase15_e2e_smoke()` | Catalog smoke: RPCs + owner policies + realtime tables |
| Docs checklist | Manual sign-off matrix below |

## 5. Database changes

SECURITY DEFINER smoke function only.

## 6–8. RLS / Realtime / Cloudinary

Verified via smoke (no schema changes).

## 9. Admin → investor action matrix (automated + manual)

| Admin action | RPC / desk | Investor surface | Deep link |
|--------------|------------|------------------|-----------|
| Assign holding | `admin_assign_investor_holding` | Portfolio | `/investor/portfolio/:id` |
| Publish document | `admin_publish_document_to_investor` | Documents | `/investor/documents` |
| Message | `admin_message_investor` | Messages | `/investor/messages` |
| KYC verify | `admin_verify_investor_kyc` | Settings | `/investor/settings` |
| Notify | `admin_publish_investor_notification` | Notifications | `/investor/*` route param |
| Confirm payment intent | `admin_confirm_investor_intent` | Payments | `/investor/payments` |
| Construction publish | CPMS fan-out | Construction + Notifications | `/investor/construction` |

## 10. Routes

No new routes (Phase 14 More hub already wired).

## 11. Tests performed

| Test | Result |
|------|--------|
| `flutter test test/investor_portal_test.dart test/investor_portal_e2e_scenario_test.dart` | **All passed** |
| `SELECT public.investor_portal_phase15_e2e_smoke()` | **`ok: true`** (RPCs, policies, realtime, Phase 2 smoke) |

### Automated scenario groups

- Mobile bottom nav destinations + longest-prefix selection
- Assign investment deep link
- Document / message / KYC / notifications contracts
- Referrals earnings math
- Realtime hub table coverage
- Sidebar module route completeness
- IMP write → investor path matrix

## 12. Manual sign-off checklist (production QA)

Use sample investor Gift / `INV-54E44F66` when available.

- [ ] Sign in as investor → `/investor` loads with live chip
- [ ] Mobile: bottom bar Dashboard / Portfolio / Payments / More
- [ ] More hub opens Analytics, Construction, Documents, Messages, Settings
- [ ] IMP 360 → Assign holding → portfolio + notification appear live
- [ ] IMP 360 → Publish document → vault + notification
- [ ] IMP 360 → Message → messages thread + notification
- [ ] IMP 360 → KYC Approve → Settings KYC status updates live
- [ ] Payments: create bank-transfer intent (pending only; staff confirms)
- [ ] Notifications: tap item marks read and navigates deep link
- [ ] Referrals: code share + commission list
- [ ] Construction: project stages / media load for held properties
- [ ] Sign out from More hub

## 13. Production QA pass (2026-09-04)

Automated / data QA against Gift (`INV-54E44F66` / `investor_id` `3e40813d-68ff-4210-bac4-0436faaa7189`):

| Check | Result |
|-------|--------|
| `investor_portal_phase15_e2e_smoke()` | `ok: true` |
| Flutter unit + e2e scenario tests | All passed |
| Portfolio holding | Victoria Crest B12 U4 — cost ₦70M / value ₦85M; `property_id` linked; **1** construction project |
| Documents | 3 vault rows (contract, statement, tax) with `file_url` |
| Notifications | 3 unread with route deep links |
| Referrals | 1 commission + wallet + receiving account |
| Messaging | 1 open conversation (`portfolio`) |
| Payment intents | 0 (bank-transfer path still needs manual create) |
| KYC | Status `pending`; 0 review rows (IMP verify still manual) |

**Data fix applied:** `investors.aum` / `total_committed` were `0` while holdings totaled 85M/70M — updated Gift to `aum=85000000`, `total_committed=70000000` so dashboard AUM matches portfolio.

Section 12 checklist items remain **unchecked** — they require signed-in UI walkthrough (investor + IMP desks).

## 14. Portal status

Phases **1–15** of Part 26 are complete against the master rewrite brief.

**Next:** finish §12 manual sign-off in the running app, then commit/PR if desired.

**Suggested follow-ups (out of scope):** device-lab UI automation (Patrol/integration_test), push/email delivery workers, denser performance seed series.
