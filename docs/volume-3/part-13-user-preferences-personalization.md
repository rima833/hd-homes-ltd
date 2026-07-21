# Volume 3 — Part 13: User Preferences & Personalization Engine

Enterprise Preference Engine — appearance, dashboards/workspaces, favorites, saved searches, accessibility, localization, behavior/recommendation foundations, and cross-device sync.

## Status

| Layer | Status |
|-------|--------|
| Domain (`PreferenceEngine`, models, command palette catalog) | Done |
| `PersonalizationService` (load/save, realtime, audit) | Done |
| Preference Center + Accessibility UI | Done |
| Executive Personalization Analytics | Done (demo metrics) |
| SQL + realtime | **Applied** as `user_preferences_personalization` (2026-07-13) |

Local file: `supabase/migrations/20260713300000_user_preferences_personalization.sql`

## Architecture

```text
User → Auth → Profile → Preference Engine → Behavior Engine
  → Personalization Service → Dashboard / Widgets / Recommendations
```

Extends existing `user_preferences` (theme, locale, timezone, extras) rather than recreating it. Notification channel prefs remain in Part 9 `notification_preferences`.

## Routes

| Path | Purpose |
|------|---------|
| `/account/preferences` | Preference Center |
| `/account/accessibility` | Accessibility Center (same hub, accessibility tab) |
| `/dashboard/personalization` | Executive anonymized analytics |

## Preference Center tabs

1. **Overview** — welcome greeting, quick actions, recommendations, Adaptive Intelligence suggestions, Smart Workspaces™, recent activity  
2. **Appearance** — theme, density, animation + language/region  
3. **Dashboard** — widget visibility / reset to role default  
4. **Accessibility** — contrast, motion, fonts, keyboard, screen reader, focus, scale  
5. **Favorites** — cross-device bookmarks  
6. **Searches** — saved searches + property interests  

## Enterprise features

1. **Smart Workspace Builder™** — named layouts (`dashboard_layouts`)  
2. **Adaptive Dashboard Intelligence** — confirmation-required suggestions  
3. **Unified Command Palette** — foundation catalog (`CommandPaletteCatalog`; full UX in Part 14)  
4. **Enterprise Preference Profiles** — role templates seeded in SQL  
5. **Executive Personalization Analytics** — aggregated metrics surface  

## Tests

```bash
flutter test test/personalization_platform_test.dart
```

## Approval gate

Part 13 SQL is applied. **Part 14 — Enterprise Search & Global Command Center** can continue; apply its SQL only after approval.
