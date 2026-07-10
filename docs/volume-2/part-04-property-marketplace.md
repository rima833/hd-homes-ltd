# Volume 2 — Part 4: Property Marketplace

**Status:** Phase 1 implemented — awaiting approval before Property Details (Part 5).

## Module objective

Enterprise AI-powered property marketplace with search, filters, comparison, favorites, map view, and investment scoring.

## Sections

| # | Section | Widget |
|---|---------|--------|
| 1 | Hero | `MarketplaceHeroSection` |
| 2–3 | AI search + filters | `MarketplaceSearchSection` |
| 4 | Categories + lifestyle | `MarketplaceCategoriesSection` |
| 5–6, 10, 13 | Featured, grid, recommended, recent | `MarketplaceGridSection` |
| 7 | Map view | `MarketplaceMapPreview` (in grid) |
| 8 | Comparison | `MarketplaceComparisonSection` |
| 9 | Favorites | `marketplaceFavoritesProvider` |
| 11 | Investment ranking | `MarketplaceInvestmentSection` |
| 12, 14–16 | Insights, alerts, FAQ, CTA | `MarketplaceClosingSection` |

## Enterprise features

- **Lifestyle discovery** — filter chips in advanced panel
- **Smart Match Score** — per-property badge (0–100%)
- **Availability meter** — live unit availability
- **Investment Score** — 0–100 ranking for invest properties
- **Side-by-side comparison** — up to 4 properties

## Code structure

```
lib/features/properties/
├── data/
│   ├── models/marketplace_property.dart
│   ├── models/marketplace_filters.dart
│   └── providers/
│       ├── marketplace_listings_provider.dart
│       └── marketplace_controller.dart
└── presentation/
    ├── pages/marketplace_page.dart
    ├── sections/
    └── widgets/marketplace_property_card.dart
```

## State providers

- `marketplaceFiltersProvider` — search + filters (instant, no reload)
- `marketplaceFavoritesProvider` — wishlist (session; sync on login later)
- `marketplaceCompareProvider` — up to 4 IDs
- `marketplaceRecentProvider` — recently viewed
- `filteredPropertiesProvider` — computed results

## Approval checklist

- [ ] Sample listings and pricing approved
- [ ] Filter set and sort options approved
- [ ] Card design and badges approved
- [ ] Investment scoring display approved
- [ ] Ready for Supabase CMS binding

## Next: Part 5

**Property Details Page** — galleries, virtual tours, calculators, inspections, AI insights.
