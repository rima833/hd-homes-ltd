# Volume 2 — Public Website

Enterprise public website for **HD Homes Ltd**. Volume 2 defines the visitor experience; Volume 1 provides shared architecture, tokens, and shells.

## Parts

| Part | Document | Status |
|------|----------|--------|
| 1 | [Global Website Foundation](./part-01-global-website-foundation.md) | Implemented |
| 2 | [Homepage — Digital Flagship](./part-02-homepage.md) | Phase 1 implemented |
| 3 | [About HD Homes](./part-03-about.md) | Phase 1 implemented |
| 4 | [Property Marketplace](./part-04-property-marketplace.md) | Phase 1 implemented |
| 5 | [Property Details Experience](./part-05-property-details.md) | Phase 1 implemented |
| 6 | [Estate Details Experience](./part-06-estate-details.md) | Phase 1 implemented |
| 7 | [Investment Hub](./part-07-investment-hub.md) | Phase 1 implemented |
| 8 | [Services Experience](./part-08-services.md) | Phase 1 implemented |
| 9 | [Blog, News & Knowledge Center](./part-09-blog-knowledge-center.md) | Phase 1 implemented |
| 10 | [Contact, Bookings & Lead Generation](./part-10-contact-lead-generation.md) | Phase 1 implemented |
| 11 | [Property Search Intelligence](./part-11-property-search-intelligence.md) | Phase 1 implemented |
| 12 | [Careers Hub](./part-12-careers.md) | Phase 1 implemented |
| 13 | [Media Center & Virtual Experiences](./part-13-media-center.md) | Phase 1 implemented |
| 14 | [Trust, Legal & Corporate Information](./part-14-trust-legal-corporate.md) | Phase 1 implemented |
| 15 | [AI, SEO & Growth Engine](./part-15-ai-seo-growth-engine.md) | Phase 1 implemented |

> **Volume 2 is complete** (Parts 1–15). Next: Volume 3 — Authentication & User Ecosystem.
>
> Bridge notes: [Investor Portal hooks](./investor-portal-hooks.md)

## Implementation rule

**Part 1 must be approved before any page work begins.** Every public page inherits:

- Design tokens (`lib/core/theme/tokens/`)
- Global widgets (`lib/core/widgets/`)
- Website foundation (`lib/core/website/`)
- `PublicShell` / `WebsiteAppShell` (`lib/core/layout/public/`)

## Code map

```
lib/core/website/
├── components/     # Reusable public-site widgets
├── l10n/           # AppStrings (i18n-ready)
├── seo/            # SeoMetadata model
└── templates/      # PageTemplate enum
```

## Related

- Volume 1 — App architecture, auth, navigation
- Volume 1.5 — Database blueprint (awaiting approval)
