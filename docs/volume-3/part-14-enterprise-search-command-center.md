# Volume 3 — Part 14: Enterprise Search & Global Command Center

Platform-wide, permission-aware search with Ctrl/Cmd+K command palette, ranking, semantic foundation, and search insights.

## Status

| Layer | Status |
|-------|--------|
| Domain (modes, ranking, semantic foundation, catalog) | Done |
| `EnterpriseSearchService` | Done |
| Global Command Center UI (Ctrl/Cmd+K) | Done |
| Search Insights Dashboard | Done |
| SQL + realtime | **Applied** as `enterprise_search_command_center` (2026-07-13) |

Local file: `supabase/migrations/20260713400000_enterprise_search_command_center.sql`

## Architecture

```text
User → Global Search Bar / Ctrl+K
  → Search Service → Permission filter → Search Index
  → Ranking Engine → Grouped results + Quick Actions
```

## Routes & entry points

| Path / shortcut | Purpose |
|-----------------|--------|
| `Ctrl+K` / `⌘+K` | Global Command Center overlay (all authenticated surfaces) |
| Portal AppBar search icon | Opens the same Command Center |
| `/dashboard/search` | Search Insights (analytics) |
| `/search` | Public marketing search hub (Volume 2; separate) |

## Search modes

Universal · Properties · People · Documents · Reports · Settings · Commands

## Enterprise features

1. **Semantic Search Foundation** — synonyms + NL intent parsing (`SemanticSearchFoundation`)  
2. **Executive Command Center™** — role-gated executive actions in the palette  
3. **Cross-Module Smart Links** — `relatedIds` / `relatedFor` graph edges  
4. **Search Insights Dashboard** — anonymized terms, zero-results, latency, adoption  
5. **Intelligent Workspace Launcher** — pinned workspaces + favorite commands  

## Tests

```bash
flutter test test/enterprise_search_platform_test.dart
```

## Approval gate

Part 14 SQL is applied. **Part 15 — AI Workspace & Digital Assistant Foundation** can continue; apply its SQL only after approval.
