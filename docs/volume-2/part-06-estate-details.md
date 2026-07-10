# Volume 2 — Part 6: Estate Details Experience

**Status:** Phase 1 implemented — awaiting approval before Investment Hub (Part 7).

## Module objective

Premium estate showcase at `/estates/:slug` — entire developments with master plans, inventory, infrastructure, construction progress, and investment storytelling.

## User journey

```
Marketplace / Estates → Estate Listing → Estate Details → Master Plan →
Available Properties → Construction → Investment → Book Tour → Reserve → Dashboard
```

## Sections

| # | Section | Widget |
|---|---------|--------|
| 1 | Premium estate hero | `EstateDetailHero` |
| 2–4 | Overview, statistics, master plan | `EstateOverviewSections` |
| 5–8 | Properties, types, amenities, infrastructure | `EstatePropertiesSections` |
| 9–13 | Location, construction, time machine, payment, investment, gallery | `EstateExploreSections` |
| 14–19 | Tours, nearby, lifestyle, FAQ, related, CTA | `EstateClosingSections` |

## Enterprise features

| Feature | Implementation |
|---------|----------------|
| Live estate dashboard | `EstateLiveDashboard` + `_LiveDashboard` |
| Construction time machine | `ConstructionTimeMachineFrame` slider in explore |
| Community experience simulator | `EstateCommunitySimulator` panel |
| Estate investment intelligence | `EstateInvestmentIntelligence` AI panel |
| Interactive plot reservation | `InteractiveMasterPlan` + `_PlotDetailPanel` |

## Code structure

```
lib/features/estates/
├── data/
│   ├── models/estate_detail_content.dart
│   └── providers/
│       ├── estate_listings_provider.dart
│       └── estate_detail_provider.dart
└── presentation/
    ├── pages/
    │   ├── estates_listing_page.dart
    │   └── estate_detail_page.dart
    ├── sections/
    │   ├── estate_overview_sections.dart
    │   ├── estate_properties_sections.dart
    │   ├── estate_explore_sections.dart
    │   └── estate_closing_sections.dart
    ├── widgets/
    │   ├── estate_detail_hero.dart
    │   ├── estate_summary_card.dart
    │   └── interactive_master_plan.dart
    └── routes/estate_routes.dart
```

## Routing

- `/estates` — `EstatesListingPage`
- `/estates/:slug` — `EstateDetailPage` (e.g. `/estates/horizon-gardens`)
- Full-bleed layout in `PublicShell`
- SEO: `SeoMetadata.estates`, `SeoMetadata.estateDetail(name, description)`

## Sample estates

| Slug | Name | Status |
|------|------|--------|
| `horizon-gardens` | Horizon Gardens | Selling Fast |
| `emerald-heights` | Emerald Heights | Phase 1 Open |
| `palm-grove-estate` | Palm Grove Estate | Completed |
| `green-valley` | Green Valley | Under Construction |

## CMS / Supabase (future)

Provider-driven content — Volume 1.5 will bind master plans, plot inventory (Realtime), construction updates, and SEO metadata.

## Approval checklist

- [ ] Hero and estate storytelling approved
- [ ] Interactive master plan and plot reservation UX approved
- [ ] Available properties carousel and type categories approved
- [ ] Enterprise panels (dashboard, time machine, AI) approved
- [ ] Related estates and CTA flow approved
- [ ] Ready for Supabase CMS binding

## Next

**Part 7 — Investment Hub** — dedicated public investment experience.
