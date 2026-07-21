# Volume 3 — Part 9: Notification & Communication Center

Centralized Enterprise Communication Platform — Smart Communication Orchestrator™, multi-channel delivery queue, Notification Center, and Admin Communication Center.

## Status

| Layer | Status |
|-------|--------|
| Domain (channels, templates, orchestrator, quiet hours) | Done |
| `CommunicationService` (dispatch, inbox, realtime, announcements) | Done |
| Notification Center UI | Done |
| Admin Communication Center | Done |
| Portal notifications routes wired | Done |
| SQL + realtime publication | **Applied** as `notification_communication_center` (2026-07-13) |

Local file: `supabase/migrations/20260713170000_notification_communication_center.sql`  
(extends the existing foundation `notifications` table).

## Architecture

```text
Business event → CommunicationService.dispatch()
  → Template Engine ({{variables}})
  → Smart Communication Orchestrator™ (prefs, priority, quiet hours)
  → In-app notification (+ delivery queue for email/SMS/push)
  → Supabase Realtime → Notification Center
```

Feature modules must not send messages directly — call `CommunicationController.notify` / `CommunicationService.dispatch`.

## Routes

| Path | Purpose |
|------|---------|
| `/account/notifications` | Notification Center |
| `/client/notifications` | Same inbox |
| `/investor/notifications` | Same inbox |
| `/dashboard/notifications` | Same inbox |
| `/dashboard/communications` | Admin publish + templates |

## Phase 1 channels

| Channel | Status |
|---------|--------|
| In-app | Live (Postgres + Realtime) |
| Email | Queued in `notification_delivery` (provider adapter next) |
| SMS | Queued (Termii/Twilio ready) |
| WhatsApp / Push | Architecture ready |

## Enterprise features

1. **Smart Communication Orchestrator™**  
2. **AI Notification Assistant** — future interface  
3. **Unified Communication Timeline** — inbox + delivery rows  
4. **Workflow Automation Engine** — template-driven triggers (extendable)  
5. **Executive Communication Intelligence** — schema ready for analytics  

## Tests

```bash
flutter test test/communication_platform_test.dart
```

## Approval gate

Part 9 SQL is applied. **Part 10 — Activity Logs, Audit Trails & System Monitoring** is implemented in-app; apply its SQL only after approval.
