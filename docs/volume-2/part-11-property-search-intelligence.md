# Volume 2 — Part 11: Property Search Intelligence

Enterprise property discovery for **HD Homes Ltd** — AI search, advanced filters, map exploration, saved searches, alerts, and personalized recommendations.

## Status

**Phase 1 implemented** — extends marketplace listings with Search Intelligence UI and in-memory providers. Supabase tables (saved_searches, alerts, etc.) await Volume 1.5 approval.

## Route

| Route | Page |
|-------|------|
| `/search` | Property Search Intelligence hub |

## Sections

1. Global search bar (autocomplete suggestions, popular/recent)
2. Quick one-click filters (12 types)
3. Advanced search (bedrooms, sort, amenities, investment)
4. Map search (grid/map toggle, Google Maps placeholder)
5. Lifestyle search (8 lifestyle presets)
6. Commute search presets
7. AI Smart Search (natural language → structured filters)
8. AI property matching / recommendations
9. Recently viewed
10. Comparison shortlist (reuses marketplace compare, max 6)
11. Saved searches
12. Property alerts
13. Search analytics
14. Search history
15. Smart empty state with alternatives
16. AI Dream Home Finder questionnaire
17. Smart affordability analyzer
18. AI Neighborhood Matcher
19. Personalized discovery feed
20. Voice & image search placeholders

## Integration

Reuses from Part 4 marketplace:

- `marketplaceListingsProvider` / `filteredPropertiesProvider`
- `marketplaceFiltersProvider`
- `marketplaceFavoritesProvider` / `marketplaceCompareProvider`
- `MarketplacePropertyCard` / `MarketplaceComparisonSection`

## AI search parser

`parseAiSearchQuery()` in `search_intelligence_provider.dart` extracts location, type, bedrooms, budget, amenities, and investment intent from plain-language queries.

## Code map

```
lib/features/search/
├── data/
│   ├── models/search_intelligence.dart
│   └── providers/
│       ├── search_cms_provider.dart
│       └── search_intelligence_provider.dart
└── presentation/
    ├── pages/search_intelligence_page.dart
    ├── routes/search_routes.dart
    ├── sections/
    │   ├── search_hero_section.dart
    │   ├── search_hub_sections.dart
    │   └── search_closing_sections.dart
    └── widgets/
        ├── global_search_bar.dart
        ├── search_results_panel.dart
        └── search_icons.dart
```

## Tests

- `test/search_intelligence_page_test.dart`

## Future (Volume 1.5+)

- Supabase: searches, saved_searches, property_alerts, search_history, shortlists
- Google Maps clusters, heatmaps, draw area
- Voice search, image search
- ML recommendation engine
- Push/WhatsApp alert delivery

## Test locally

```bash
flutter run -d chrome
# /search
flutter test test/search_intelligence_page_test.dart
```

## Volume 2 progress

Parts **1–11** implemented (Phase 1). Parts **12–15** remain. Part **7 (Investment Hub)** still placeholder.
