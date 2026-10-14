# Investor Portal — Phase 8 Report (Documents Vault)

**Date:** 2026-09-04  
**Status:** Complete — migration applied  
**Migration:** `supabase/migrations/20260904120000_investor_portal_phase8_documents.sql`

---

## 1. What was already implemented

- `/investor/documents` list with search / type filters
- `InvestorService.listDocuments` + `resolveDocumentUrl` (https + Supabase Storage signed URLs)
- Realtime hub invalidates documents on `investor_documents` changes
- DDCMS `admin_publish_document_to_investor` (basic insert)
- Owner SELECT via `investor_documents_portal_owner`

## 2. What was reused

- `investor_documents` table (`version`, `is_sensitive`, `expires_at`, `metadata`)
- DDCMS publish entry point (`DdcmsService.publishToInvestor`)
- Portal chrome / KPI / empty / error widgets
- Existing realtime documents bucket

## 3. What was removed

- Thin “open only” card UX without version / sensitivity / expiry context

## 4. What was created / changed

| Change | Detail |
|--------|--------|
| RPC | `admin_publish_document_to_investor` — upsert by `source_document_id`, bump version, archive prior `file_url` into `metadata.version_history`, prefer current `document_versions` path, accept Cloudinary/HTTPS via `storage_path` or metadata |
| RLS | Reaffirm owner SELECT; no investor write policy |
| Models | `InvestorDocument` enriched (sensitive, expiry, delivery kind, version history); `InvestorDocumentVersion` |
| Service | `resolveInvestorDocumentUrl` (expiry guard + Cloudinary/https/storage) |
| UI | Vault redesign: live chip, KPIs, download/open, versions sheet, sensitive/expired chips, skeleton |

## 5. Database changes

- Replaced publish function body (idempotent `CREATE OR REPLACE`)
- Recreated `investor_documents_portal_owner` SELECT policy

## 6. RLS changes

Investors: SELECT own rows only. Staff: existing `investors.documents` write. Investors cannot INSERT/UPDATE/DELETE vault rows.

## 7. Realtime changes

None required — Phase 3 already publishes `investor_documents` and invalidates the provider.

## 8. Cloudinary changes

Publish tags `delivery: cloudinary` when URL is `res.cloudinary.com`. Client opens HTTPS Cloudinary URLs directly (no Storage sign). Construction-style signed upload of investor docs remains Admin/DDCMS-owned.

## 9. Admin connections

Admin DDCMS → `admin_publish_document_to_investor` → vault row upsert → investor sees live update. Re-publish updates the same vault item and keeps prior file URLs in history.

## 10. Routes created/changed

None (`/investor/documents`).

## 11. Tests performed

| Test | Result |
|------|--------|
| Apply Phase 8 migration | Success |
| Dart analyze documents/models/service | No errors |
| Owner SELECT policy present | Confirmed |

## 12. Remaining issues

- Seed docs use public `hdhomes.ng` HTTPS placeholders (fine for open; Storage/Cloudinary used for real packs)
- Dedicated download audit log not added (open is client-side launch)
- Messaging/support Phase 9 next

**Ready for Phase 9** (Messaging & Support).
