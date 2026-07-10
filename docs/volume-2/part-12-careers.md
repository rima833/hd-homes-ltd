# Volume 2 — Part 12: Careers Hub

Phase 1 implementation of the Careers Hub — culture, open roles, applications routed to Careers & HR via CRM.

## Route

| Route | Page |
|-------|------|
| `/careers` | `CareersPage` |

## Architecture

```
lib/features/careers/
├── data/
│   ├── models/careers_hub_content.dart
│   └── providers/careers_cms_provider.dart
└── presentation/
    ├── pages/careers_page.dart
    ├── routes/careers_routes.dart
    ├── sections/
    │   ├── careers_hero_section.dart
    │   ├── careers_hub_sections.dart
    │   └── careers_closing_sections.dart
    └── widgets/
        ├── career_icons.dart
        └── career_job_card.dart
```

## Sections implemented

1. Premium hero — open position count, CTAs (roles, general apply, contact HR)
2. Culture & values — company culture summary + value cards
3. Benefits — why work with HD Homes
4. Open roles — filterable job grid (department + employment type)
5. Application form — CRM-routed careers lead with optional preselected role
6. Team testimonials
7. Careers FAQ — searchable
8. Closing CTA — contact careers / about

## CMS

Content via `careersHubCmsProvider` with sample jobs and FAQs. Supabase careers tables deferred to Volume 1.5.

## SEO

- `SeoMetadata.careersHub` via `SeoResolver`
- CollectionPage structured data

## Tests

- `test/careers_page_test.dart` — page load and key sections

## Next steps (awaiting approval)

- CV upload to storage
- ATS / HR admin workflow
- Role detail pages with shareable URLs
- Email notifications to Careers & HR
