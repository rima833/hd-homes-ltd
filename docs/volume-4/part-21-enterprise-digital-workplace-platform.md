# Volume 4 — Part 21: Enterprise Communication, Collaboration, Knowledge Management & Digital Workplace Platform (EDWP)

Enterprise messaging, collaboration workspaces, knowledge/wiki, meetings, communities, and AI workplace assistance for HD Homes.

## Status

| Layer | Status |
|---|---|
| Domain models + demo snapshot | Done |
| Supabase service + offline fallback | Done |
| Riverpod controller + Realtime invalidation | Done |
| `/dashboard/workplace` command center | Done |
| SQL, permissions, RLS, storage, seeds | **APPLIED** remotely (2026-07-21) |

Canonical migration: `supabase/migrations/20260714320000_enterprise_digital_workplace_platform.sql`

## Architecture

`DigitalWorkplaceCommandCenterPage` → EDWP Riverpod providers → `EdwpService` → Supabase with per-table demo fallback.

The command center has 12 tabs: Overview, Messages, Announcements, Workspaces, Tasks, Calendar, Meetings, Knowledge, Wiki, Communities, Analytics, and AI.

Phase 1 enterprise surfaces:

1. Enterprise Digital Headquarters™
2. Intelligent Collaboration Engine™
3. Organizational Knowledge Graph™
4. Smart Meeting Intelligence™
5. Executive Collaboration Center™

## Collision-safe schema

Enriched with `ALTER TABLE … ADD COLUMN IF NOT EXISTS` only:

- `knowledge_articles` — `workplace_surface`, `category_id`, `owner_label`, `version_label`, `hub_metadata`

EDWP does **not** recreate:

- Volume 3 `tasks` (uses `collaborative_tasks` + `task_comments` / `task_checklists`)
- `chat_messages` (uses `direct_messages` + `group_conversations`)
- `announcement_posts` / `hr_announcements` (uses `workplace_announcements`)
- `support_knowledge_*` / `meeting_records` / `board_meetings`

New tables include workplace profiles/status, messaging, announcements, collaboration workspaces, collaborative tasks, calendars/events, meeting rooms/meetings/agendas/minutes/actions, knowledge categories/versions, wiki pages/revisions, communities, search history, productivity metrics, activity logs, notifications, and `workplace_ai_insights`.

Private storage bucket: `workplace-artifacts`.

Realtime: `direct_messages`, `workplace_announcements`, `collaborative_tasks`, `meetings`, `workplace_activity_logs`, `workplace_notifications`.

## Permissions

`workplace.read`, `workplace.write`, `workplace.messaging`, `workplace.announcements`, `workplace.workspaces`, `workplace.tasks`, `workplace.calendar`, `workplace.meetings`, `workplace.knowledge`, `workplace.wiki`, `workplace.communities`, `workplace.search`, `workplace.ai`, `workplace.analytics`, `workplace.admin`.

Role grants:

- `super_admin`, `admin`: all
- `finance`: read, analytics, meetings
- `construction_manager`: read, workspaces, tasks
- `sales_team`: read, messaging, tasks
- `marketing`: read, announcements, communities

RLS calls `has_permission('slug', auth.uid())` with the slug first.

## Route note

`/dashboard/workplace` → Digital Workplace Command Center. Do **not** replace `/dashboard/communications` (`AdminCommunicationPage`).

## Verification

`test/edwp_platform_test.dart` covers demo surfaces, KPI strip, advisory AI output, task/meeting register data, offline service fallback, briefing/signals, and the 12-tab controller contract.

## Next

SQL applied and verified. Volume 4 continues through Parts 22–25. Await approval before Part 22.
