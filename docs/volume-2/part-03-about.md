# Volume 2 — Part 3: About HD Homes

**Status:** Phase 1 implemented — awaiting approval before CMS binding.

## Page objective

Premium corporate About experience combining company profile, storytelling, leadership credibility, and investor confidence.

## Sections implemented

| # | Section | Widget |
|---|---------|--------|
| 1 | Hero banner | `AboutHeroSection` |
| 2 | Company introduction | `AboutIntroSection` |
| 3 | Our story | `AboutStorySection` |
| 4–5 | Vision, mission, values | `AboutVisionValuesSection` |
| 6 | Company timeline | `AboutTimelineSection` |
| 7 | Leadership team | `AboutLeadershipSection` |
| 8–9 | Why choose + services | `AboutServicesSection` |
| 10–14 | Awards, partners, CSR, sustainability, process | `AboutImpactSection` |
| 15–17 | Statistics, offices, careers | `AboutOperationsSection` |
| 18–19 + enterprise | Executive video, milestone map, profile, trust, testimonials, CTA | `AboutEnterpriseSection` |

## Enterprise enhancements

- Executive video message (CMS video URL ready)
- Interactive milestone map (GIS-ready placeholder)
- Digital company profile (view/download)
- Trust & compliance center

## Code structure

```
lib/features/about/
├── data/models/about_cms_content.dart
├── data/providers/about_content_provider.dart
└── presentation/
    ├── pages/about_page.dart
    ├── sections/
    └── widgets/about_icons.dart
```

## CMS fields

All business content flows from `aboutContentProvider` — hero, intro, story, values, timeline, leadership, awards, partners, CSR, offices, careers, testimonials, trust center, SEO (future).

## Approval checklist

- [ ] Corporate narrative and copy approved
- [ ] Leadership placeholder profiles approved
- [ ] Timeline milestones approved
- [ ] Trust center references approved (replace RC-XXXXXXX with real refs before launch)
- [ ] Ready for CMS wiring

## Next steps

1. Bind `aboutContentProvider` to Supabase CMS
2. Real leadership photos and executive video
3. GIS map integration for milestone map
4. SEO: `SeoMetadata.about` with AboutPage schema (wire to document head in CMS pass)
