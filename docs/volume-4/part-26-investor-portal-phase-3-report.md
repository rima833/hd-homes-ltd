# Investor Portal — Phase 3 Report (Realtime Foundation)

**Date:** 2026-09-03  
**Status:** Complete — migration applied to remote Supabase  
**Migration:** `supabase/migrations/20260903130000_investor_portal_phase3_realtime.sql`

---

## 1. What was already implemented

- `investorPortalRealtimeHubProvider` keepAlive in `investorShellRoute`
- Filtered Postgres subscriptions with debounce + bucket invalidation
- Chrome live-dot + snackbar for human-readable events
- Message/ticket tick providers for open threads

## 2. What was reused

- Existing hub architecture and chrome connection UI
- Shell wiring (`ref.watch(investorPortalRealtimeHubProvider)`)
- Canonical CPMS tables (`construction_progress_updates` / media / projects)

## 3. What was removed

- Global `finance_receipts` subscription (noisy; money path covered by `payments` + `investor_payment_intents`)
- Deprecated `InvestorService.listConstructionUpdates` (unused; use `loadConstruction`)
- No legacy `construction_updates` / `construction_photos` listeners (already absent; documented as intentional)

## 4. What was created / changed

| Change | Detail |
|--------|--------|
| Channel stability | Hub watches investor **id** via `select` — KYC/record refetch no longer tears down the channel |
| Scoped table registry | `investorPortalRealtimeInvestorScopedTables` for `investor_id` filters |
| Activity bucket | `investor_activity_logs` → dashboard refresh |
| Publication ensure | Idempotent ADD for all hub tables |
| REPLICA IDENTITY FULL | Filtered UPDATE events include `investor_id` / `user_id` |
| Smoke RPC | `investor_portal_phase3_realtime_smoke()` |
| Chrome import | Explicit `identity_provider` import |

## 5. Database changes

- `ALTER PUBLICATION supabase_realtime ADD TABLE …` (missing only)
- `ALTER TABLE … REPLICA IDENTITY FULL` on hub tables
- Smoke function `investor_portal_phase3_realtime_smoke`

## 6. RLS changes

None (Phase 2).

## 7. Realtime changes

- Filters remain on owner-scoped tables (`investor_id` / `user_id`)
- Unscoped (RLS-on-refetch): `portfolio_holdings`, construction tables, `ticket_messages`, conversation messages, receiving accounts
- Disposal unchanged: debounce + event timers cancelled; `removeChannel` on dispose
- Auth change: userId / investorId `select` rebuilds channel only when identity scope changes

## 8. Cloudinary changes

None.

## 9. Admin connections

Admin mutations on published tables still fan out to the investor hub (payment confirm, construction publish, documents, messages).

## 10. Routes created/changed

None.

## 11. Tests performed

| Test | Result |
|------|--------|
| Apply Phase 3 migration | Success |
| `investor_portal_phase3_realtime_smoke()` | `ok: true` |
| Sample tables `REPLICA IDENTITY` | `full` on intents/notifications/payments/investors |
| Dart analyze on touched files | Clean |

## 12. Remaining issues

- Unscoped construction/message/ticket_message events still wake every connected investor client (debounce + RLS refetch mitigates; deeper per-row filters need conversation/project membership columns)
- No automated browser E2E for live snackbar yet (Phase 15)
- Dashboard/metrics UX polish is Phase 4

**Ready for Phase 4** (Investor Dashboard redesign + live metrics) when approved.
