# Volume 2 — Part 5: Property Details Experience

**Status:** Phase 1 implemented — awaiting approval before Estate Details.

## Module objective

Premium digital property showroom at `/properties/:id` — immersive media, transparent specs, financial tools, and conversion paths for inspections, reservations, and investments.

## User journey

```
Marketplace → Select Property → Property Details → Explore Media →
Review Specs → Calculate Payments → Evaluate Investment →
Book Inspection → Reserve → Login/Register → Purchase
```

## Sections

| # | Section | Widget |
|---|---------|--------|
| 1 | Hero media gallery | `PropertyMediaGallery` |
| 2–3 | Summary + quick actions | `PropertyDetailHeader`, `PropertyStickyActions` |
| 4–8 | Overview, specs, pricing, mortgage, ROI | `PropertyDetailBodySections` |
| 9–16 | Tours, floor plans, map, amenities, construction, docs, nearby | `PropertyDetailExploreSections` |
| 17–20 | Reviews, FAQ, related, CTA | `PropertyDetailClosingSections` |

## Enterprise features

| Feature | Implementation |
|---------|----------------|
| Live availability dashboard | `PropertyAvailabilityDashboard` + `_Availability` |
| Inspection slot booking | `InspectionSlot` chips → `/book-inspection` |
| Neighborhood intelligence | `NeighborhoodIntelligence` panel |
| Smart document vault | `PropertyDocument` list with download UI |
| AI decision assistant | `PropertyAiInsight` panel |

## Code structure

```
lib/features/properties/
├── data/
│   ├── models/property_detail_content.dart
│   └── providers/property_detail_provider.dart
└── presentation/
    ├── pages/property_detail_page.dart
    ├── sections/
    │   ├── property_detail_header.dart
    │   ├── property_detail_body_sections.dart
    │   ├── property_detail_explore_sections.dart
    │   └── property_detail_closing_sections.dart
    └── widgets/property_media_gallery.dart
```

## State providers

- `propertyDetailProvider(id)` — full detail content from marketplace listing + CMS placeholders
- `relatedPropertiesProvider(id)` — similar properties by location/type

## Routing

- Route: `/properties/:id` via `PropertyDetailPage`
- Full-bleed layout in `PublicShell` (no top padding)
- SEO: `SeoMetadata.propertyDetail(title, description)`

## CMS / Supabase (future)

All content is provider-driven — no hardcoded copy in widgets. Volume 1.5 migrations will bind:

- Media, pricing, payment plans, documents
- Construction updates (Realtime)
- Inspection slots
- Reviews, FAQs, neighborhood data

## Approval checklist

- [ ] Gallery and media UX approved
- [ ] Quick actions and sticky panel approved
- [ ] Mortgage calculator and investment section approved
- [ ] Enterprise panels (availability, AI, neighborhood) approved
- [ ] Related properties and CTA flow approved
- [ ] Ready for Supabase CMS binding

## Next

**Estate Details Page** — master plans, estate-wide amenities, plot inventory (after Part 5 approval).
