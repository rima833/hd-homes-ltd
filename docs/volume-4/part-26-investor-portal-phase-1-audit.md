# Investor Portal — Phase 1 Audit & Implementation Map

**Date:** 2026-09-03  
**Scope:** HD Homes Investor Portal end-to-end readiness  
**Status:** Phase 1 complete (audit + architecture map). No wholesale rewrite.

---

## Executive verdict

The Investor Portal is **not a stub**. It is a live Supabase-backed workspace with PortalShell, 13 routes, Riverpod providers, `InvestorService`, and a realtime hub.

Dashboard values such as **₦85,000,000 / ₦750,000 / ₦2,500,000** for `INV-54E44F66` are **database holdings / distributions / wallet rows** (portal demo seeds), **not Flutter hardcoded constants**.

The portal is production-shaped but **not yet master-spec complete**. Highest risks are security (payment intents RLS), schema gaps (no investor installment/charge engine), construction media RLS, and incomplete modules (holding depth, support threads, mobile nav).

---

## 1. What already works

| Area | Evidence |
|------|----------|
| Auth + portal gate | `/investor/*` protected; role/`canAccessInvestorPortal` redirect |
| Shell + chrome | Sidebar brand, help card, collapse, header search/bell/account |
| Realtime hub | `investorPortalRealtimeHubProvider` keepAlive in `investorShellRoute` |
| Dashboard | Live KPIs from holdings, distributions, wallet, unread |
| Portfolio list | Live holdings + search/sort/grid |
| Analytics | NAV/TWR/IRR/yield + allocation from `investment_performance` |
| Payments (bank transfer) | Receiving accounts + create `investor_payment_intents` |
| Documents | `investor_documents` + signed Storage URL resolve |
| Messages | Conversations/messages + unread badge + mark-read + ticks |
| Notifications | List + mark read/all + chrome badge |
| Referrals | Code + commissions from DB |
| Bootstrap | `ensure_investor_record()` RPC (no client INSERT) |

---

## 2. What partially works

| Module | Gap |
|--------|-----|
| Holding detail | Overview only — missing payment plan, distributions, docs, construction, activity tabs |
| Construction | Progress/milestones/photos work; videos empty; some media RLS blocks investor-only assets |
| Reports | List + client-side PDF/Excel/CSV export; filed report open may skip signed URL helper |
| Support | Ticket create + list; **no ticket message thread/reply UI** |
| Settings | Prefs persist to `investor_preferences`; theme/language not applied app-wide |
| Mobile nav | Bottom nav = Dashboard / Portfolio / Payments / Settings only (8 modules drawer-only) |
| IMP admin | Strong read/command center; many writes go through Finance/CPMS/DDCMS RPCs instead |

---

## 3. What is mock / demo / hardcoded (UI)

| Finding | Location | Action |
|---------|----------|--------|
| Portal demo seed balances | SQL seeds in `20260714430000_investor_portal_platform.sql` | Keep for staging; isolate from production |
| Static FAQ copy | `investor_support_page.dart` | Later: CMS FAQs or remove |
| Share URL `https://hdhomes.ng/investment` | referrals page | Config/env |
| Image missing placeholder widget | portfolio cards | Keep (UI empty state) |
| Investor code fallback `INV-{id}` | chrome/dashboard | OK fallback |
| Dead route duplicate | `investor_routes.dart` unused | Remove in Phase 2 cleanup |

**Not found:** Flutter `mock`/`dummy`/`fake` providers inventing portfolio money.

---

## 4. Database map (reuse — do not recreate)

### Core investor domain (EXISTS)

`investors`, `investor_profiles`, `investor_preferences`, `investor_portfolios`, `portfolio_holdings`, `investment_commitments`, `investment_opportunities`, `investment_distributions`, `investor_wallets`, `investor_bank_accounts`, `investor_documents`, `investor_statements`, `investor_reports`, `investment_performance`, `investor_notifications`, `investor_alerts`, `investor_activity_logs`, `investor_conversations`, `investor_conversation_messages`, `investor_referral_commissions`, `investment_receiving_accounts`, `investor_payment_intents`, `investor_kyc_reviews` / `investor_compliance`

### Adjacent (EXISTS)

`tickets`, `ticket_messages`, `payments`, `construction_projects`, `construction_progress_updates`, `construction_update_media`, `project_milestones`

### Client-only (DO NOT confuse with investor capital)

`installments`, `payment_charges` — property **purchase** engine for clients, not investor capital calls.

### Ideal master-spec gaps (Phase 2+)

| Ideal | Reality / plan |
|-------|----------------|
| Investor installment schedule | Missing — design capital-call / contribution schedule or map commitments |
| Late charges on investor invoices | Missing investor charge ledger (client has `payment_charges`) |
| Proof-of-transfer on intents | Harden + Cloudinary proof + status RPC |
| Single `investments` table | Use `portfolio_holdings` + `investment_commitments` (do not duplicate) |
| Cloudinary document vault | Docs today = Supabase Storage; Cloudinary used for construction/CMS |

---

## 5. RLS & security findings (critical)

| Issue | Risk | Phase |
|-------|------|-------|
| `investor_payment_intents` owner **FOR ALL** | Investor can self-update status to confirmed | **Phase 2 P0** |
| `ensure_investor_record` open to any authenticated user | Auto-provisions investor domain | Phase 2 |
| `construction_update_media` staff/public only | Investor-only updates may hide media | Phase 2/7 |
| `admin_publish_document_to_investor` live RPC missing from local migrations | Env drift | Phase 2 |
| Demo seed ON CONFLICT updates wallet/portfolio | Dangerous if reapplied on prod | Phase 2 |
| `is_staff()` broad OR on some portal policies | Over-wide staff read | Phase 2 review |

---

## 6. Realtime coverage

**Working:** hub keepAlive, message/ticket ticks, invalidations for holdings/payments/docs/notifications/conversations/construction progress tables.

**Applied publication:** `20260902180000_investor_portal_realtime_publication.sql`  
(`portfolio_holdings`, `investor_conversations`, reports/statements/performance/preferences)

**Residual:** Flutter still listens to some stale construction tables; `projects` not published; no subscription filter by investor (relies on RLS + refetch — acceptable for now).

---

## 7. Admin → Supabase → Investor flow (current)

```text
IMP (read/ops) ──┐
FAPMS Finance ───┼─► distributions / intents / receiving accounts ─► Investor Payments
CPMS ────────────┼─► construction_progress_updates + notifications ─► Construction
DDCMS ───────────┼─► investor_documents (RPC) ─────────────────────► Documents
Portal self ─────┴─► intents / messages / tickets / prefs ─────────► Admin sees via desks
```

**Rule confirmed:** Investor UI must not invent business data. Seed data is DB-side.

---

## 8. Media

| Surface | Storage |
|---------|---------|
| Investor documents/statements | Supabase Storage (`storage://` + signed URL) |
| Construction progress media | Often Cloudinary URLs in metadata |
| Avatars / CMS | Cloudinary |

Master-spec Cloudinary-for-all-docs is a **later phase** (do not rip Storage without migration plan).

---

## 9. Navigation IA (retain)

Keep MAIN + ACCOUNT structure. Improve later:

- Mobile: add **More** hub (like client) for Analytics/Construction/Reports/Documents/Referrals/Messages/Support/Notifications
- Optional: rename “Investment Analytics” → “Analytics”

---

## 10. REUSE / REBUILD / REMOVE

### REUSE
`InvestorService`, models, providers, chrome, PortalShell, ExportEngine, auth centers, Finance/CPMS/DDCMS RPCs, existing tables.

### REBUILD (extend)
Holding detail depth, payment confirmation + admin verify lock, construction videos/media RLS, support threads, mobile More nav, investor charge/schedule if product requires.

### REMOVE
Unused `investor_routes.dart`, obsolete realtime table listeners, deprecated `listConstructionUpdates`, stale “portal stubs” comments.

---

## 11. Phased implementation map (sequential)

| Phase | Focus | Exit criteria |
|-------|--------|---------------|
| **1** | Audit & architecture | This document; no blind rewrite |
| **2** | Database & security | Payment intent RLS locked; media/doc RPC in migrations; RLS tests for investor isolation | **DONE 2026-09-03** |
| **3** | Realtime foundation | Hub cleanup; remove stale listeners; verify live updates per entity | **DONE 2026-09-03** |
| **4** | Dashboard | Metrics correctness; empty states; optional live indicator; remove seed confusion in prod | **DONE 2026-09-03** |
| **5** | Portfolio + detail | Full investment detail sections wired to real rows | **DONE 2026-09-03** |
| **6** | Payments & finance | Proof upload, pending verification only, admin verify, overdue/charges if schema added | **DONE 2026-09-03** |
| **7** | Construction | Media RLS, videos, publish → investor live |
| **8** | Documents | Vault UX, signed access, versions, DDCMS parity |
| **9** | Messaging & support | Ticket threads + attachments parity with client |
| **10** | Reports & analytics | Date filters, trusted backend aggregates where needed |
| **11** | Referrals & KYC | Rules/approval; KYC status from existing compliance tables |
| **12** | Notifications | Deep links + consistent center |
| **13** | Admin integration | IMP write paths for assign investment / docs / messages |
| **14** | Polish | Mobile More, a11y, skeletons, performance |
| **15** | E2E tests | Full admin→investor scenario checklist |

---

## 12. Phase 1 deliverables checklist

- [x] Frontend module audit (WORKING / PARTIAL)
- [x] Database / RLS / realtime / media / admin audit
- [x] Clarified “₦85M” = live DB seed, not UI mock
- [x] Implementation map Phases 2–15
- [x] Explicit REUSE / REBUILD / REMOVE
- [ ] Phase 2 starts only after this map is accepted

---

## 13. Immediate next step (Phase 2 — when approved)

1. Harden `investor_payment_intents` RLS (investor INSERT/SELECT + limited UPDATE; status changes via finance RPC only).  
2. Add local migration for `admin_publish_document_to_investor` if missing.  
3. Fix `construction_update_media` investor-read policy.  
4. Delete unused `investor_routes.dart`.  
5. Add automated RLS isolation smoke SQL for Investor A ≠ Investor B.

**Do not proceed to Phase 2 rewrite of dashboard/portfolio UI until Phase 2 security migrations are applied.**
