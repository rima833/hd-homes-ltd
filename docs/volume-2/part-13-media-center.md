# Volume 2 — Part 13: Media Center & Virtual Experiences

Phase 1 implementation of the enterprise Media Center — an immersive digital showroom for properties and estates.

## Routes

| Route | Page | Description |
|-------|------|-------------|
| `/gallery` | `MediaCenterHubPage` | Media Center hub with featured showrooms |
| `/gallery/:slug` | `MediaExperiencePage` | Full immersive experience per property/estate |

### Sample slugs

- `horizon-gardens` — Estate digital showroom
- `h001` — Horizon Gardens 3BR Terrace
- `emerald-heights` — Construction-focused showcase

## Architecture

```
lib/features/media/
├── data/
│   ├── models/media_content.dart       # CMS models
│   └── providers/media_cms_provider.dart
└── presentation/
    ├── pages/
    │   ├── media_center_hub_page.dart
    │   └── media_experience_page.dart
    ├── routes/media_routes.dart
    ├── sections/
    │   ├── media_hero_section.dart
    │   ├── media_hub_sections.dart
    │   └── media_experience_sections.dart
    └── widgets/
        ├── media_card.dart
        ├── media_gallery_grid.dart
        └── media_icons.dart
```

## Sections implemented

### Hub (`/gallery`)

1. Media hero — cinematic hero with CTAs
2. Featured media experiences — showroom cards
3. Smart media analytics preview
4. Press & brand kit
5. Book inspection CTA

### Experience detail (`/gallery/:slug`)

1. Media hero — property context, media count, CTAs
2. Featured media cards
3. HD image gallery — categories, lightbox
4. 360° virtual tour viewer — room navigation, hotspots
5. Drone experience — chapters
6. Property video center
7. Floor plan viewer
8. Estate masterplan
9. Construction progress timeline
10. Virtual open house
11. Before & after comparison slider
12. Media download center
13. Smart media timeline
14. Investor construction dashboard preview
15. AI virtual property guide (placeholder copy)
16. Share experience
17. VR & AR future-ready section
18. Related media
19. Book inspection CTA

## CMS

Content is served via Riverpod providers with sample data (`mediaHubCmsProvider`, `mediaExperienceProvider`). Supabase Storage and RLS wiring is deferred to Volume 1.5.

## SEO

- Hub: `SeoMetadata.mediaHub` via `SeoResolver`
- Detail: `SeoMetadata.mediaExperience()` via `SeoBinder`
- Structured data: `CollectionPage` (hub), `MediaObject` (detail)

## Enterprise features (Phase 1 placeholders)

- AI Virtual Property Guide — copy + architecture hook
- Before & After Viewer — drag slider
- Smart Media Timeline — chronological events
- VR & AR — future-ready section
- Investor Dashboard Preview — public completion metrics
- Smart Media Analytics — hub analytics chips

## Tests

`test/media_center_page_test.dart` — hub load, experience sections, not-found state.

## Next steps (awaiting approval)

- Supabase `media_assets` tables and Storage buckets
- Real image/video CDN integration
- Embedded 360° tour provider (e.g. Matterport)
- Live virtual open house streaming
- Admin CMS media management UI
