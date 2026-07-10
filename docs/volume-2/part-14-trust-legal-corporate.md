# Volume 2 — Part 14: Trust, Legal & Corporate Information

Phase 1 implementation of the enterprise Trust Center — a transparency hub for buyers, investors, banks, and regulators.

## Route

| Route | Page |
|-------|------|
| `/trust` | `TrustCenterPage` |

## Architecture

```
lib/features/trust/
├── data/
│   ├── models/trust_center_content.dart
│   └── providers/
│       ├── trust_cms_provider.dart
│       └── trust_document_verification_provider.dart
└── presentation/
    ├── pages/trust_center_page.dart
    ├── routes/trust_routes.dart
    ├── sections/
    │   ├── trust_hero_section.dart
    │   ├── trust_hub_sections.dart
    │   └── trust_closing_sections.dart
    └── widgets/
        ├── trust_enterprise_widgets.dart
        ├── trust_info_cards.dart
        └── trust_legal_form.dart
```

## Sections implemented

1. Premium hero — headline, CTAs (profile, certifications, investor info)
2. Why trust HD Homes — pillar cards + animated statistics
3. Company profile — overview, vision, mission, values, downloads
4. Licenses & certifications — certificate cards with verification links
5. Corporate governance — board, policies
6. Investor protection — safeguards overview
7. Legal document center — searchable, versioned documents
8. Compliance center — AML, KYC, NDPR, etc.
9. Banking & strategic partners
10. Awards & recognition
11. Corporate social responsibility
12. ESG metrics
13. Risk management
14. Transparency reports
15. Trust FAQ — searchable
16. Contact legal & compliance team — inquiry form

## Enterprise features (Phase 1)

- **Document Verification Portal** — verify sample certificate references
- **Digital Due Diligence Room** — Investor Portal link placeholder
- **Transparency Dashboard** — live CMS metrics chips
- **Regulatory Compliance Tracker** — renewal deadlines
- **Digital Agreement Center** — future-ready architecture note
- **Corporate Timeline** — milestone history
- **Trust Score™** — proprietary credibility index with breakdown

## CMS

Content via `trustHubCmsProvider` with sample data. Supabase tables (`legal_documents`, `certifications`, etc.) deferred to Volume 1.5.

## SEO

- `SeoMetadata.trustHub` via `SeoResolver`
- Organization structured data

## Tests

- `test/trust_center_page_test.dart` — page load + document verification unit tests

## Next steps (awaiting approval)

- Supabase document storage with RLS
- PDF preview and download tracking
- CRM integration for legal inquiries
- Admin CMS for policies and certificates
- FAQ Schema generation from CMS FAQs
