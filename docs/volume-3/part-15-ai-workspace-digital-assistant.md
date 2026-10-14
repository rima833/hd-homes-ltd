# Volume 3 — Part 15: AI Workspace & Digital Assistant Foundation

> **AI capabilities have been intentionally deferred until Phase 2 (Post-Launch
> AI Upgrade).** See [`docs/ai-deferment.md`](../ai-deferment.md). The
> `/account/ai` workspace route, AI Gateway, and related UI are gated by
> `kAiFeaturesEnabled = false`. Workspace infrastructure tables were removed by
> `ai_deferment_phase2` (**APPLIED** 2026-07-21). Code remains in-tree so Phase 2
> can re-enable without a redesign.

Centralized, permission-aware AI layer: AI Gateway, Digital Assistant, copilots, Knowledge Hub, prompt library, and governance — provider-independent.

## Status

| Layer | Status |
|-------|--------|
| Domain (safety, knowledge, prompts, response foundation) | Done (dormant — Phase 2) |
| `AiGateway` + `LocalFoundationProvider` | Done (dormant — Phase 2) |
| AI Workspace UI | **Deferred** — route/nav hidden via `kAiFeaturesEnabled` |
| AI Governance Dashboard | **Deferred** (superseded by Part 17; both gated) |
| SQL + realtime | Applied 2026-07-13 · **dropped** by `ai_deferment_phase2` (2026-07-21) |

Local file: `supabase/migrations/20260713500000_ai_workspace_digital_assistant.sql`

## Architecture

```text
User → AI Gateway → Context Engine → Permission / Safety
  → Knowledge Layer → AI Services / Provider → Response → Audit
```

Feature modules must never call model providers directly — only through `AiGateway`.

## Routes

| Path | Purpose |
|------|---------|
| `/account/ai` | AI Workspace (chat) |
| `/dashboard/ai` | AI Governance & Insights |

## Assistants

General · Property · Investment · CRM · Content · Report · **AI Executive Copilot™** · **AI Sales Copilot™** · **AI Knowledge Hub™** · Workflow

High-impact drafts (CRM / content / sales) set `requiresApproval = true`.

## Enterprise features

1. AI Executive Copilot™  
2. AI Sales Copilot™  
3. AI Knowledge Hub™  
4. AI Automation Studio (future-ready suggestions)  
5. AI Governance & Insights Dashboard  

## Tests

```bash
flutter test test/ai_workspace_platform_test.dart
```

## Approval gate

Part 15 SQL is applied. **Volume 3 is complete.**  
**Volume 4 — Admin Dashboard & Business Management** can begin when you are ready.
