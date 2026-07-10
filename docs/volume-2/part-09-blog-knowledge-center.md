# Volume 2 — Part 9: Blog, News & Knowledge Center

Enterprise content platform for **HD Homes Ltd** — blog, newsroom, academy, market intelligence, research, video, downloads, and SEO.

## Status

**Phase 1 implemented** — CMS placeholder providers with sample content. Supabase binding awaits Volume 1.5 schema approval.

## Routes

| Route | Page |
|-------|------|
| `/blog` | Knowledge Center hub |
| `/blog/:slug` | Article detail |

Example: `/blog/first-time-buyers-guide-nigeria-2026`

## Sections (Hub)

1. Premium hero with search
2. Featured stories carousel
3. Latest articles grid
4. Category filters
5. Trending tabs (Most Read, Editor's Picks, Popular This Week)
6. Market intelligence dashboard
7. Learning Academy tracks
8. Research library
9. Video center
10. Download center
11. Authors
12. Press & media center
13. Events with registration CTA
14. Real estate glossary (A–Z)
15. Podcasts (future-ready placeholder)
16. Newsletter subscription
17. FAQs

## Article Detail

- Hero, breadcrumbs, TOC, body blocks (paragraph, callout, quote)
- AI summary tabs (30 sec / 2 min / full)
- Social actions (like, share, bookmark, print, copy link)
- Downloads, FAQs, related articles
- Author bio, prev/next navigation
- Comments placeholder (Volume 1.5)

## SEO

- Static: `SeoMetadata.blogHub` via `SeoResolver` on `/blog`
- Dynamic: `SeoMetadata.articleDetail()` via `SeoBinder` on article pages
- NewsArticle JSON-LD with author and publish date

## Code map

```
lib/features/blog/
├── data/
│   ├── models/blog_content.dart
│   └── providers/
│       ├── blog_catalog_provider.dart
│       └── blog_article_provider.dart
└── presentation/
    ├── pages/
    │   ├── blog_hub_page.dart
    │   └── blog_article_page.dart
    ├── routes/blog_routes.dart
    ├── sections/
    │   ├── blog_hub_sections.dart
    │   ├── blog_closing_sections.dart
    │   └── blog_article_sections.dart
    └── widgets/
        ├── article_card.dart
        └── blog_search_bar.dart
```

## Tests

- `test/blog_hub_page_test.dart` — hub sections, article detail, not-found
- `test/seo_resolver_test.dart` — blog hub SEO + dynamic article route

## Future (Volume 1.5+)

- Supabase CMS tables for articles, categories, authors, comments
- Download analytics tracking
- Newsletter double opt-in
- Personalized reading (saved articles, history)
- Live market dashboard from Supabase
- Comment moderation and AI assistant backend

## Test locally

```bash
flutter run -d chrome
# Navigate to /blog and /blog/first-time-buyers-guide-nigeria-2026
flutter test test/blog_hub_page_test.dart
```
