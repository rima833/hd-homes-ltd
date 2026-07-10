# Volume 2 — Part 10: Contact, Bookings & Lead Generation Hub

Enterprise customer engagement platform for **HD Homes Ltd** — multi-channel contact, bookings, smart lead routing, and CRM placeholders.

## Status

**Phase 1 implemented** — CMS placeholder providers with sample content. Supabase CRM binding awaits Volume 1.5 schema approval.

## Routes

| Route | Page |
|-------|------|
| `/contact` | Contact & Lead Generation Hub |
| `/book-inspection` | Same hub, scrolled to inspection booking |

## Sections

1. Premium hero with CTAs
2. Contact option cards (phone, WhatsApp, email, offices, appointments, inspection, IR, partnerships, live chat, virtual meeting)
3. Office directory (head, regional, sales, construction)
4. Interactive map placeholder (Google Maps in production)
5. Book property inspection (physical/virtual, qualification, visitor pass QR)
6. Book consultation (live calendar slots)
7. Request callback
8. Live chat placeholder
9. WhatsApp department routing
10. Department directory with SLA
11. Support center (complaints, feedback)
12. Careers contact form
13. Partnership requests
14. Emergency contacts
15. AI assistant placeholder
16. Enterprise CRM pipeline visualization
17. FAQ with search
18. Newsletter signup

## Lead routing engine

`routeLead()` in `lead_routing_provider.dart` scores leads 0–100 based on budget, investment interest, timeline, and location. Assigns department, staff tier, and priority. All form submissions create `SubmittedLead` records in memory (CRM placeholder).

## Enterprise features (Phase 1 placeholders)

- Smart lead qualification fields on inspection form
- AI conversation assistant section
- Digital visitor pass code on inspection/consultation confirmation
- CRM pipeline stage chips
- Real-time calendar slots from CMS

## SEO

- `SeoMetadata.contactHub` on `/contact` and `/book-inspection`
- ContactPage + LocalBusiness structured data

## Code map

```
lib/features/contact/
├── data/
│   ├── models/contact_content.dart
│   └── providers/
│       ├── contact_cms_provider.dart
│       └── lead_routing_provider.dart
└── presentation/
    ├── pages/contact_page.dart
    ├── routes/contact_routes.dart
    ├── sections/
    │   ├── contact_hero_section.dart
    │   ├── contact_hub_sections.dart
    │   └── contact_closing_sections.dart
    └── widgets/
        ├── contact_widgets.dart
        └── contact_forms.dart
```

## Tests

- `test/contact_page_test.dart` — hub sections, inspection deep-link, form submission + CRM routing

## Future (Volume 1.5+)

- Supabase leads table, timeline, assignments
- Google Maps embed
- Live chat + WhatsApp CRM logging
- Email/SMS notifications
- File uploads to Supabase Storage
- Real-time calendar with Realtime sync

## Test locally

```bash
flutter run -d chrome
# /contact and /book-inspection
flutter test test/contact_page_test.dart
```

## Volume 2 progress

Parts **1–10** implemented (Phase 1). Parts **11–15** remain.
