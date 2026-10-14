# Investor Command Center — Ops Runbook & Staff Walkthrough

**Surface:** `/dashboard/investors`  
**Audience:** Relationship managers, compliance, finance ops, support  
**Companion:** Investor portal `/investor/*` · [Part 4 IMP](./part-04-investor-management-platform.md) · [Part 26 Portal](./part-26-investor-portal.md)

---

## Principles

1. **Honest data only** — empty queues and ₦0 AUM are valid; never invent metrics.
2. **Permission-gated actions** — if a button is missing, the role lacks the slug (see below).
3. **Portal is the investor source of truth for delivery** — admin writes should appear under `/investor/*` after refresh / Live sync.
4. **Deep-link out when needed** — Support desk and CPMS remain available for full workflows.

---

## Desk map (current tabs)

| Tab | What it is for |
|-----|----------------|
| **Overview** | Queue shortcuts, portfolio mix, alerts/activity snapshot |
| **Investors** | Searchable directory + preview; filters (type, lifecycle, KYC, owner) |
| **Capital** | Segments: Investments · Capital Raise · Portfolio · Distributions (+ website link/publish) |
| **Payments** | Payment intents / confirm & reject |
| **Compliance** | Segments: KYC · Documents |
| **Support** | Portal conversations + tickets with **in-IMP reply** |
| **Insights** | Segments: Reports · Activity · Alerts (+ notification publish) |
| **360° Investor** | Per-investor workspace with section nav (Profile · Compliance · Capital · Engage · Reports · Construction) |

Live pill meanings: **Live sync** = subscribed; **Reconnecting…** = channel down; **Offline** = Supabase not configured.

---

## Permissions (common actions)

| Action | Typical slugs |
|--------|----------------|
| View desk | `investors.read` |
| Create/edit investor, assign owner | `investors.write` |
| Capital raise / website publish | `investors.opportunities` (or write) |
| Fund commitment / holdings | `investors.portfolio` |
| Confirm/reject payment | `investors.payments` |
| KYC verify | `investors.kyc` |
| Publish vault docs | `investors.documents` |
| Message / notify | `investors.communicate` |
| Ticket reply | `support.write` / `support.tickets` / communicate |
| Reports / referrals | `investors.reports` / `investors.referrals` |

---

## Daily ops loop (15 minutes)

1. Open **Overview** → clear **Overdue Actions**, **Pending Payments**, **KYC Pending**.
2. **Payments** → confirm or reject with notes (ledger posts only on confirm/fund paths).
3. **Compliance → KYC** → move pending reviews; check evidence in 360.
4. **Support** → reply to open investor threads / tickets (use internal note when needed).
5. **Insights → Alerts** → acknowledge/resolve; send portal notification if investor should act.
6. Spot-check **Live sync** still green after a write.

---

## Staff walkthrough checklist

Use a **non-production or sandbox investor** when possible. Check each box after the portal side confirms.

### A. Access & chrome

- [ ] Sign in as staff with investor permissions
- [ ] Navigate to `/dashboard/investors`
- [ ] KPI strip shows real numbers (zeros OK); no demo filler
- [ ] Live pill shows **Live sync** (or expected Offline in local-only)

### B. Directory & ownership

- [ ] **Investors** tab: search by name/code/email
- [ ] Filter by type, lifecycle, KYC, and **owner**
- [ ] Preview an investor without leaving the tab
- [ ] Open **360°** from the row
- [ ] Assign / change relationship manager (Profile segment)
- [ ] Create a follow-up task

### C. Capital & website

- [ ] **Capital → Capital Raise**: open opportunity list
- [ ] Link a website investment card to an operational opportunity
- [ ] Publish / unpublish / feature a website card (public site only shows `active`)
- [ ] **Capital → Investments**: add or fund a commitment when allowed
- [ ] Confirm holding appears under portal **Portfolio** for that investor

### D. Payments & compliance

- [ ] **Payments**: confirm one intent (or reject with notes)
- [ ] Portal **Payments** reflects status after sync
- [ ] **Compliance → KYC**: set under review / approve / reject / needs resubmission
- [ ] Portal **Settings / KYC** shows updated status
- [ ] **Compliance → Documents**: publish a DDCMS doc into the vault
- [ ] Portal **Documents** lists the new file

### E. Engage & insights

- [ ] **360 → Engage** or **Insights → Alerts**: send in-app notification with deep link
- [ ] Portal **Notifications** shows it; deep link opens the right module
- [ ] **Support**: select a conversation, read thread, send reply
- [ ] Portal **Messages** shows the reply
- [ ] Reply to a **ticket** (and optionally an internal note — investor must not see the note)
- [ ] **Insights → Reports**: publish a report; portal **Reports** lists it

### F. Construction

- [ ] Open investor with property-linked holdings
- [ ] **360 → Construction**: see progress + cover/update thumbs when media exists
- [ ] Portal **Construction** shows the same investor-visible updates

### G. Smoke (engineering / release)

- [ ] Flutter: `flutter test test/investor_portal_e2e_scenario_test.dart`
- [ ] SQL (authenticated): `select public.investor_portal_imp_ops_e2e_smoke();` → `ok: true`

---

## Troubleshooting

| Symptom | Check |
|---------|--------|
| Empty desk / zeros | Real empty book vs connection; confirm Live / remote labels |
| Action buttons missing | Role permissions (table above) |
| Portal not updating | Live sync; investor `user_id` linked; hard refresh portal |
| Website card invisible publicly | Status must be `active` (not `draft` / `archived`) |
| Ticket reply fails | Needs support write/tickets permission; ticket not closed for customers |
| Construction empty in 360 | Holdings need `property_id` linked to CPMS projects |
| Anon / security smoke fails | Run `investor_portal_imp_ops_e2e_smoke()`; look at `anon_execute_open` (migration `20260916130000` revokes anon EXECUTE on admin_/investor_ DEFINER RPCs) |

---

## Admin → portal write map

| Admin action | Portal surface |
|--------------|----------------|
| Assign holding / fund commitment | `/investor/portfolio` |
| Publish document | `/investor/documents` |
| Message / conversation reply | `/investor/messages` |
| Ticket reply | `/investor/support` |
| KYC verify | `/investor/settings` |
| Notification publish | `/investor/notifications` (+ deep link) |
| Confirm payment intent | `/investor/payments` |
| Publish report | `/investor/reports` |
| Award referral | `/investor/referrals` |
| Construction publish (CPMS) | `/investor/construction` |
| Website card publish | Public `/investment` (not portal) |

---

## Related code & smoke

- UI: `lib/features/imp/presentation/pages/investor_command_center_page.dart`
- Service: `lib/features/imp/domain/services/imp_service.dart`
- Portal realtime tables: `investorPortalRealtimeTables`
- Contract tests: `test/investor_portal_e2e_scenario_test.dart` (Scenario J)
- Catalog smoke: `investor_portal_imp_ops_e2e_smoke()` · migrations `20260915120000_imp_portal_e2e_sync_smoke.sql` + `20260916130000_imp_investor_anon_execute_revoke.sql`
