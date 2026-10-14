# Investor Portal — Phase 7 Report (Construction)

**Date:** 2026-09-04  
**Status:** Complete — migration applied  
**Migration:** `supabase/migrations/20260903150000_investor_portal_phase7_construction.sql`

---

## 1. What was already implemented

- Construction page with hero, Gantt, updates, photo preview, video open-via-browser
- `InvestorService.loadConstruction` on unified CPMS tables (`construction_progress_updates` + media)
- Realtime hub listens to construction updates / media / projects / milestones
- Phase 2 investor media SELECT policies

## 2. What was reused

- CPMS publish path (`admin` Construction → `construction_progress_updates`)
- `InvestorGanttChart`, portal cards, `MediaDeliveryImage`, existing realtime buckets
- Holding detail Construction tab (enriched, not replaced)

## 3. What was removed / fixed

- Treating all media as photos (ignored `media_type`)
- Loading milestones/projects without investor RLS (always empty for pure investors)
- Holding detail construction scope that only filtered updates, not phases/projects

## 4. What was created / changed

| Change | Detail |
|--------|--------|
| RLS helper | `investor_owns_construction_project(uuid)` — holding ↔ `property_id` |
| Policies | Investor SELECT on `construction_projects`, `project_phases`, `project_milestones` |
| Realtime | `project_phases` publication ensure + REPLICA IDENTITY FULL; Flutter hub listen |
| Models | `InvestorConstructionPhase`, `InvestorConstructionProject`, enriched update/video/bundle |
| Service | Project-first load: projects → phases → milestones → updates; split image/video; Cloudinary `media` join |
| UI | Project chips, stage pipeline, live chip, ETA/schedule, video thumbnails, phase/milestone tags |
| Detail tab | Stages + photos/videos + link to construction hub |

## 5. Database changes

- Function + 3 SELECT policies
- `project_phases` realtime publication / replica identity (idempotent)

## 6. RLS changes

Investors can read CPMS project/phase/milestone rows only when they hold a portfolio unit on that project’s `property_id`. Updates/media remain gated by existing investor visibility policies.

## 7. Realtime changes

`project_phases` added to hub table list + listener (`Construction phase update` snackbar).

## 8. Cloudinary changes

Update media select joins `media:media_id(secure_url, thumbnail_url)` so delivery prefers Cloudinary secure URLs when present.

## 9. Admin connections

Admin Construction Desk publish → investor-visible updates → portal invalidates via realtime. No investor write path.

## 10. Routes created/changed

None (`/investor/construction`).

## 11. Tests performed

| Test | Result |
|------|--------|
| Apply Phase 7 migration | Success |
| Dart analyze construction/service/models/realtime | No errors (warnings only) |
| Policies present for projects/phases/milestones | Confirmed |

## 12. Remaining issues

- Seed media currently image-only (video UI ready when Admin uploads `media_type=video`)
- Projects without `property_id` remain invisible to investors by design
- Documents Phase 8 next

**Ready for Phase 8** (Documents vault).
