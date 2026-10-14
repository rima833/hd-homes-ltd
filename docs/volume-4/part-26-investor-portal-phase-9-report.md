# Investor Portal — Phase 9 Report (Messaging & Support)

**Date:** 2026-09-04  
**Status:** Complete — migration applied  
**Migration:** `supabase/migrations/20260904130000_investor_portal_phase9_messaging_support.sql`

---

## 1. What was already implemented

- IR Messages: conversations list + realtime chat + new conversation dialog
- Support: ticket create/list + static FAQs
- Realtime hub listens to `investor_conversations`, `investor_conversation_messages`, `tickets`, `ticket_messages`
- Client portal already had ticket threads (parity target)

## 2. What was reused

- Shared `tickets` / `ticket_messages` tables
- Cloudinary upload via `mediaServiceProvider` (same pattern as bank-transfer proof)
- Existing message/ticket tick providers + realtime buckets

## 3. What was removed / fixed

- Support list-only UX (no thread / reply)
- Loose `ticket_messages` INSERT (`auth.uid() IS NOT NULL`)
- Owner SELECT that could surface staff `is_internal` notes via OR policies

## 4. What was created / changed

| Change | Detail |
|--------|--------|
| RLS | Owner INSERT/SELECT on `ticket_messages` (non-internal only); staff SELECT separated; owner UPDATE on `tickets` |
| Models | `InvestorTicketMessage`, `InvestorMessageAttachment`; message/ticket attachments; richer ticket fields |
| Service | `listTicketMessages`, `sendTicketMessage`, attachment-aware `sendMessage` / `createTicket` |
| Providers | `investorTicketMessagesProvider` |
| Support UI | Live chip, ticket thread, reply composer, Cloudinary attachments |
| Messages UI | Attachment pick/upload + bubble links |

## 5. Database changes

Policy updates only (no new tables).

## 6. RLS changes

- Investors read/write only **non-internal** messages on **their** tickets
- Staff keep full support write + select (including internal notes)
- Investors may UPDATE own tickets (e.g. reopen on reply)

## 7. Realtime changes

Existing tickets/messages listeners refresh threads via `investorTicketsTickProvider` / `investorMessagesTickProvider`.

## 8. Cloudinary changes

Support/chat attachments upload to `hdhomes/investors/{investorId}/support|messages` and store delivery URLs in `attachments` jsonb.

## 9. Admin connections

Support desk replies on `ticket_messages` → investor thread updates live. IR staff can use conversations table for messaging. Internal notes stay staff-only.

## 10. Routes created/changed

None (`/investor/messages`, `/investor/support`).

## 11. Tests performed

| Test | Result |
|------|--------|
| Apply Phase 9 migration | Success |
| Dart analyze messages/support/service/models | No errors |

## 12. Remaining issues

- Dedicated notification deep-links for new ticket replies remain Phase 12
- PDF upload depends on Cloudinary raw/image support in the shared media service
- Reports & analytics Phase 10 next

**Ready for Phase 10** (Reports & Analytics).
