# Volume 2 — Part 7: Investment Hub

Phase 1 implementation of the Investment Hub — structured products, ROI tools, and investor resources for local and diaspora buyers.

## Route

| Route | Page |
|-------|------|
| `/investment` | `InvestmentHubPage` |

## Architecture

```
lib/features/investment/
├── data/
│   ├── models/investment_hub_content.dart
│   └── providers/investment_cms_provider.dart
└── presentation/
    ├── pages/investment_hub_page.dart
    ├── routes/investment_routes.dart
    ├── sections/
    │   ├── investment_hero_section.dart
    │   ├── investment_hub_sections.dart
    │   └── investment_closing_sections.dart
    └── widgets/
        ├── investment_icons.dart
        ├── investment_opportunity_card.dart
        ├── investment_roi_calculator.dart
        └── investor_portal_cta.dart
```

## Sections implemented

1. Premium hero — opportunities, ROI calculator, consultation, Investor Portal
2. Why invest — pillar cards + animated statistics
3. Investment opportunities — filterable product grid with estate deep-links
4. Investment process — 6-step journey
5. Market insights — corridor data cards
6. ROI calculator — interactive sliders with projected returns
7. AI investment insights — Growth Engine `investmentInsightsProvider`
8. Investor protection — summary with Trust Center link
9. Investor testimonials
10. Downloads — investment packs and disclosures
11. Investor FAQ — searchable
12. Investor Portal bridge — Access / Sign in / Trust Center
13. Closing CTA — consultation and estates

## Enterprise features (Phase 1)

- **ROI calculator** — interactive projected returns
- **AI investment insights** — Growth Engine `investmentInsightsProvider`
- **Investor Portal hooks** — public CTAs to `/investor` (auth redirect) and login with return URL
- Filterable opportunity cards with estate deep-links

## CMS

Content via `investmentHubCmsProvider` with sample opportunities, process steps, and FAQs. Supabase investor tables deferred to Volume 1.5.

## SEO

- `SeoMetadata.investmentHub` via `SeoResolver`
- WebPage structured data

## Tests

- `test/investment_hub_page_test.dart` — page load and key sections

## Investor Portal bridge

See also [investor-portal-hooks.md](./investor-portal-hooks.md).

| Entry point | Behavior |
|-------------|----------|
| Investment Hub hero / portal CTA | `context.go(RoutePaths.investor)` → auth redirect if logged out |
| Trust Center due diligence | Same portal entry + explicit Sign in link |
| Portal shell stubs | `InvestorPortalStubPage` for all `/investor/*` routes until Volume 3 |

## Next steps (awaiting approval)

- Investor Portal modules (Volume 3)
- Live portfolio tracking and escrow status
- CRM routing for investor consultations
- Supabase CMS for opportunities and disclosures
