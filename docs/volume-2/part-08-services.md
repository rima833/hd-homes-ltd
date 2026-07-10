# Volume 2 — Part 8: Services Experience

**Status:** Phase 1 implemented — awaiting approval before Blog & Knowledge Center (Part 9).

## Module objective

Premium, scalable Services platform positioning HD Homes as a full-service real estate, construction, and property solutions company — with dedicated landing pages per service and CMS-driven content.

## Primary goals

- Explain every HD Homes service clearly
- Build trust through transparency
- Generate qualified leads via smart consultation form
- Support SEO through dedicated service pages
- Enable future expansion without code changes (CMS providers)

## Supported services (29 initial)

| Category | Count | Examples |
|----------|-------|----------|
| Real Estate | 6 | Property Sales, Estate Development, Investment |
| Construction | 6 | Residential, Turnkey, Infrastructure |
| Design & Planning | 5 | Architectural Design, Urban Planning |
| Property Management | 5 | Estate Management, Rental Management |
| Professional Services | 7 | Valuation, Surveying, Legal Advisory |

## Page structure

### Services hub (`/services`)

| # | Section | Widget |
|---|---------|--------|
| 1 | Premium hero | `ServicesHeroSection` |
| 2–4 | Categories, featured, catalog | `ServicesCatalogSections` |
| 5–12 | Why choose, process, case studies, tech, industries, testimonials, FAQ, consultation | `ServicesClosingSections` |

### Service detail (`/services/:slug`)

| Section | Widget |
|---------|--------|
| Hero + overview + benefits | `ServiceDetailSections` |
| Process, deliverables, pricing, gallery | `ServiceDetailSections` |
| AI recommendations, eligibility checker, FAQ, related | `ServiceDetailSections` |
| Consultation form + CTA | `ServiceDetailSections` |

## Enterprise features

| Feature | Implementation |
|---------|----------------|
| AI service recommendations | `aiServiceRecommendationsProvider` |
| Smart project estimator | `estimateProject()` in closing sections |
| Consultant booking | Live expert availability panel |
| Service knowledge center | `knowledgeArticles` in CMS |
| Digital proposal generator | Post-submit message in `ConsultationForm` |
| Project eligibility checker | `ServiceEligibilityQuestion` on detail pages |

## Code structure

```
lib/features/services/
├── data/
│   ├── models/service_models.dart
│   └── providers/
│       ├── services_catalog_provider.dart
│       └── service_detail_provider.dart
└── presentation/
    ├── pages/
    │   ├── services_page.dart
    │   └── service_detail_page.dart
    ├── sections/
    │   ├── services_hero_section.dart
    │   ├── services_catalog_sections.dart
    │   ├── services_closing_sections.dart
    │   └── service_detail_sections.dart
    ├── widgets/
    │   ├── service_card.dart
    │   ├── service_icons.dart
    │   └── consultation_form.dart
    └── routes/service_routes.dart
```

## Routing

- `/services` — `ServicesPage`
- `/services/:slug` — `ServiceDetailPage` (e.g. `/services/property-sales`)
- Full-bleed layout in `PublicShell`
- SEO: `SeoMetadata.servicesHub`, `SeoMetadata.serviceDetail()` — **wired to `<head>` via `SeoBinder` + `SeoHead` (web)**

## CMS management (future)

Admin will manage categories, services, pricing, galleries, FAQs, case studies, experts, and SEO — all via Volume 1.5 Supabase bindings.

## Approval checklist

- [ ] Service catalog and category filtering approved
- [ ] Service detail template and process timeline approved
- [ ] Consultation form fields approved
- [ ] Enterprise panels (estimator, AI, eligibility) approved
- [ ] Ready for Supabase CMS + CRM lead integration

## Next

**Part 9 — Blog, News & Knowledge Center**
