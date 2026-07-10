# Volume 2 — Part 1: Global Website Foundation

**Status:** Implemented in codebase — awaiting product approval before Part 2 (pages).

---

## Design intent

Establish a premium, reusable public website layer that every HD Homes marketing page inherits. The foundation prioritizes:

- Brand consistency (gold `#D4A34E`, charcoal, deep black from logo)
- Enterprise motion (subtle fade/slide reveals, scroll progress)
- Conversion paths (search, book inspection, invest, contact)
- Trust signals (Digital Trust Center scaffold)
- CMS-ready placeholders (announcement bar, newsletter, personalization)

Inspired by luxury PropTech leaders (Emaar, DAMAC, Ellington, etc.) without copying layouts.

---

## Design token system

Extended in `lib/core/theme/tokens/`:

| System | File | Notes |
|--------|------|-------|
| Colors | `app_colors.dart` | Brand, status, neutral 50–950, glass, overlays |
| Typography | `app_typography.dart` | Display → caption scale (Manrope) |
| Spacing | `app_spacing.dart` | 8pt grid incl. 56, 72, 120, 160 |
| Radius | `app_radius.dart` | xs → circle, pill aliases |
| Shadows | `app_shadows.dart` | sm/md/lg + gold glow |
| Breakpoints | `app_breakpoints.dart` | Mobile → ultra-wide |

---

## Website module (`lib/core/website/`)

### Layout & structure

| Component | Purpose |
|-----------|---------|
| `PageContainer` | Max-width content with responsive padding |
| `SectionWrapper` | Vertical section + scroll-reveal |
| `AnimatedSectionTitle` | Overline + title + subtitle |
| `WebsiteBreadcrumbs` | Accessible breadcrumb trail |

### Shell integration (`PublicShell`)

| Feature | Component |
|---------|-----------|
| App shell | `PublicShell` / `WebsiteAppShell` |
| Sticky header | `PublicNavBar` (glass on scroll) |
| Announcement | `GlobalNotificationBar` |
| Search | `WebsiteSearchOverlay` |
| Scroll progress | `ScrollProgressBar` |
| Back to top | `ScrollToTopButton` |
| Cookie consent | `CookieConsentBanner` (persisted) |
| Floating actions | `PublicFloatingActions` (WhatsApp, chat, book) |
| Footer | `PublicFooter` |

### Marketing blocks

| Component | Purpose |
|-----------|---------|
| `WebsiteHeroSection` | Reusable hero with CTAs |
| `CtaBanner` | Full-width conversion band |
| `NewsletterBanner` | Email capture (API placeholder) |
| `StatisticCounter` | Animated metrics |
| `DigitalTrustCenter` | Registrations, awards, milestones |
| `ExperienceModesBar` | Lifestyle / budget / investment / map |

### SEO & templates

| File | Purpose |
|------|---------|
| `seo/seo_metadata.dart` | Title, description, OG, schema hooks |
| `seo/seo_head.dart` | Applies metadata to document `<head>` on web |
| `seo/seo_resolver.dart` | Maps routes → static `SeoMetadata` |
| `seo/seo_binder.dart` | Widget that updates head on mount (dynamic pages) |
| `seo/seo_config.dart` | Canonical base URL (`SITE_URL` env) |
| `templates/page_template.dart` | Landing, listing, detail, blog, etc. |
| `l10n/app_strings.dart` | Centralized copy (EN first; FR/AR ready) |

---

## Enterprise enhancements (scaffold)

1. **Experience modes** — `ExperienceModesBar` routes visitors by intent.
2. **Smart personalization** — Storage hooks + mode chips; CMS wiring in Part 5.
3. **Digital Trust Center** — `DigitalTrustCenter` with default trust items.
4. **Global notification bar** — `GlobalNotificationBar` with CMS placeholder message.

---

## Inherited from Volume 1

Already available for all pages:

- Button, form, card, modal, skeleton systems (`lib/core/widgets/`)
- `GoRouter` public shell routes
- Responsive extensions (`context.isMobile`, `pagePadding`, etc.)
- Lucide icons, shimmer, flutter_animate

---

## Accessibility & performance

- Semantic breadcrumbs, focusable nav, cookie banner actions
- Scroll controller avoids nested scroll conflicts
- Lazy section animation via `SectionWrapper`
- Target: sub-2s initial load (optimize assets per page in Part 2+)

---

## What is NOT in Part 1

Per workflow, **no individual page content** was built:

- Homepage sections
- Property/estate listing pages
- Blog, careers, contact forms (beyond placeholders)
- CMS / Supabase content binding

---

## Approval checklist

Before Part 2, confirm:

- [ ] Visual identity (colors, type, spacing) approved
- [ ] Header/footer/navigation structure approved
- [ ] Global components list complete
- [ ] Enterprise scaffolds (trust, modes, announcement) approved
- [ ] i18n approach (`AppStrings` → ARB) accepted

---

## Next: Part 2

Recommended first page: **Homepage** — hero, featured properties, estates, trust, newsletter, CTAs — composed entirely from this foundation.
