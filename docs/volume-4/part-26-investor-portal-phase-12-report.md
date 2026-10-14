# Investor Portal — Phase 12 Report (Notifications)

**Date:** 2026-09-04  
**Status:** Complete — migration applied  
**Migration:** `supabase/migrations/20260904160000_investor_portal_phase12_notifications.sql`

---

## 1. What was already implemented

- Notifications list + search + unread filter + chrome badge
- Realtime invalidation on `investor_notifications` / `investor_alerts`
- Settings preference toggles (email/SMS/push + alert types)
- Construction + announcement fan-out already insert into `investor_notifications`

## 2. What was reused

- `investor_notifications` table + portal SELECT policy
- Existing chrome unread badge + snackbar live events
- Client portal pattern: tap → mark read → deep link

## 3. What was removed / fixed

- Owner UPDATE policy that allowed rewriting title/body/metadata (removed)
- N+1 mark-all loop via per-row table updates
- Missing deep-link / category metadata on rows
- No staff publish RPC for targeted investor alerts

## 4. What was created / changed

| Change | Detail |
|--------|--------|
| RPC | `investor_mark_notifications_read(ids\|null)` — mark one/all; ownership-gated |
| RPC | `admin_publish_investor_notification(...)` — staff publish + `/investor*` route |
| RLS | Staff write policy includes `is_staff()` / `investors.notify` |
| Backfill | Existing rows get `metadata.category` + `metadata.route` |
| Models | Category, actionRoute, portalRoute helpers |
| Service | Mark-read via RPC; `markAllNotificationsRead` |
| UI | Live chip, category filters, deep-link open, prefs shortcut |
| IMP | 360° “Notify investor” form with deep-link picker |

## 5. Database changes

Two SECURITY DEFINER functions + metadata backfill (no new tables).

## 6. RLS changes

- Dropped `investor_notifications_portal_update`
- Hardened `investor_notifications_write` for staff / notify permission

## 7. Realtime changes

None new — existing hub already invalidates notifications + dashboard badge.

## 8. Cloudinary changes

None.

## 9. Admin connections

IMP 360 → `admin_publish_investor_notification` → investor Notifications center + badge refresh live.  
Construction/announcement fan-outs continue to write `investor_notifications` (source migrations updated to stamp `route`/`category` for future publishes).

## 10. Routes created/changed

None (`/investor/notifications`). Deep links navigate to existing `/investor/*` modules.

## 11. Tests performed

| Test | Result |
|------|--------|
| Apply Phase 12 migration | Success |
| RPCs exist; owner UPDATE policy removed | Confirmed |
| Gift sample rows backfilled with route/category | Confirmed |
| Dart analyze Phase 12 touchpoints | No errors |

## 12. Remaining issues

- Push/email delivery still preference metadata only (in-app is live path)
- Broader IMP assign-investment / docs / messaging write paths remain Phase 13

**Ready for Phase 13** (Admin integration).
