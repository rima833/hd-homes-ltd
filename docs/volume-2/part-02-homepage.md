# Volume 2 — Part 2: Homepage (Digital Flagship)

**Status:** Phase 1 implemented — awaiting approval before CMS binding and polish passes.

## User journey implemented

| # | Section | Widget | CMS |
|---|---------|--------|-----|
| 1 | Cinematic loading | `HomeSplashOverlay` | — |
| 2 | Announcement bar | `GlobalNotificationBar` (shell) | `announcement` |
| 3 | Sticky navigation | `PublicNavBar` (shell) | — |
| 4 | Premium hero | `HomeHeroSection` | `hero` |
| 5 | Smart property search | `HomePropertySearchSection` | future |
| 6 | Quick statistics | `HomeStatsSection` | `stats` |
| 7 | Who we are | `HomeAboutSection` | `about` |
| 8 | Why choose HD Homes | `HomeWhyChooseSection` | `whyChoose` |
| — | Lifestyle explorer | `HomeLifestyleExplorerSection` | `lifestyles` |
| 9 | Featured estates | `HomeFeaturedEstatesSection` | `estates` |
| 10 | Featured properties | `HomeFeaturedPropertiesSection` | `properties` |
| 11 | Nigeria map | `HomeMapSection` | GIS future |
| 12 | Investment | `HomeInvestmentSection` | `investments` |
| 13 | Payment calculator | `HomePaymentCalculatorSection` | — |
| 14 | ROI calculator | `HomeRoiCalculatorSection` | — |
| 15–16 | Construction + timeline | `HomeConstructionSection` | `constructionProjects` |
| 17 | Virtual tours | `HomeVirtualToursSection` | CMS media |
| 18–20 | Testimonials, partners, awards | `home_social_proof_sections.dart` | CMS |
| 21–24 | Blog, insights, events, FAQ | `HomeContentHubSection` | CMS |
| 25–29 | Downloads, newsletter, CTAs, AI teaser | `HomeClosingSections` | CMS |
| 30 | Footer | `PublicFooter` (shell) | — |

## Code structure

```
lib/features/home/
├── data/
│   ├── models/home_cms_content.dart
│   └── providers/home_content_provider.dart
└── presentation/
    ├── pages/home_page.dart
    ├── sections/          # One file per major block
    └── widgets/           # EstateCard, AnimatedStatistic
```

## Next steps (post-approval)

1. Bind `homeContentProvider` to Supabase CMS tables (Volume 1.5 Part 5)
2. Hero video / drone assets from media library
3. Real GIS map integration
4. Mega menus for Properties, Estates, Investment
5. Performance pass (lazy section loading, image CDN)
6. SEO structured data injection via `SeoMetadata.home`

## Approval checklist

- [ ] Homepage narrative flow approved
- [ ] Section order and density approved
- [ ] Placeholder copy and stats approved
- [ ] Calculators and comparison tools approved
- [ ] Ready for CMS wiring
