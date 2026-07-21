# Volume 4 — Admin Dashboard & Business Management

Enterprise operational core for **HD Homes Ltd**. Builds on Volume 2 public site and Volume 3 identity/RBAC.

Volume 4 continues through **Parts 1–25**. Part 10 (EOC) is a midpoint, not the end of the volume.

## Parts

| Part | Document | Status |
|------|----------|--------|
| 1 | [Executive Dashboard & Business Intelligence](./part-01-executive-dashboard-business-intelligence.md) | Phase 1 complete · SQL applied |
| 2 | [Property Management System (PMS)](./part-02-property-management-system.md) | Phase 1 complete · SQL applied |
| 3 | [Client Relationship Management (CRM)](./part-03-client-relationship-management.md) | Phase 1 complete · SQL applied |
| 4 | [Investor Management Platform (IMP)](./part-04-investor-management-platform.md) | Phase 1 complete · SQL applied |
| 5 | [Sales & Booking Management System (SBMS)](./part-05-sales-booking-management-system.md) | Phase 1 complete · SQL applied |
| 6 | [Construction & Project Management System (CPMS)](./part-06-construction-project-management-system.md) | Phase 1 complete · SQL applied |
| 7 | [Finance, Accounting & Payment Management (FAPMS)](./part-07-finance-accounting-payment-management.md) | Phase 1 complete · SQL applied |
| 8 | [Marketing, CMS & Digital Experience (DXP)](./part-08-marketing-cms-digital-experience.md) | Phase 1 complete · SQL **APPLIED** (verified 2026-07-15) |
| 9 | [Enterprise Human Capital Management (HCM)](./part-09-enterprise-human-capital-management.md) | Phase 1 complete · SQL **APPLIED** |
| 10 | [Executive Intelligence & Enterprise Operations Center (EOC)](./part-10-executive-intelligence-enterprise-operations-center.md) | Phase 1 complete · SQL **APPLIED** |
| 11 | [Customer Support, Help Desk & Omnichannel Communication Platform (CSHOP)](./part-11-customer-support-omnichannel-platform.md) | Phase 1 complete · SQL **APPLIED** |
| 12 | [Document, Digital Asset & Contract Management System (DDCMS)](./part-12-document-digital-asset-contract-management.md) | Phase 1 complete · SQL **APPLIED** |
| 13 | [Procurement, Vendor, Inventory & Supply Chain Management (PVISCM)](./part-13-procurement-vendor-inventory-supply-chain.md) | Phase 1 complete · SQL **APPLIED** |
| 14 | [Enterprise Asset, Facilities & Maintenance Management (EAFMS)](./part-14-enterprise-asset-facilities-maintenance.md) | Phase 1 complete · SQL **APPLIED** |
| 15 | [Enterprise GRC, Internal Audit & Legal (GRCA)](./part-15-enterprise-grc-audit-legal-management.md) | Phase 1 complete · SQL **APPLIED** |
| 16 | [Enterprise BI, Advanced Analytics & Data Warehouse (BIADW)](./part-16-enterprise-bi-analytics-data-warehouse.md) | Phase 1 complete · SQL **APPLIED** |
| 17 | [Enterprise AI Intelligence Hub, ML & Decision Support (EAIH)](./part-17-enterprise-ai-intelligence-hub.md) | Phase 1 complete · SQL **APPLIED** (2026-07-21) |
| 18 | [Enterprise Integration Platform, API Gateway, Workflow Orchestration & Event-Driven Architecture (EIP)](./part-18-enterprise-integration-platform.md) | Phase 1 complete · SQL **LOCAL ONLY** — await approve |
| 19–25 | *(planned)* | Wait for approve before Part 19 |

## Implementation rules

- Do **not** apply new migrations until approved.
- Protect executive metrics with RBAC (`view_executive_dashboard`, `manage_reports`, module permissions).
- Prefer KPI snapshots + Realtime over ad-hoc heavy joins from Flutter.
- AI insights must be labelled as AI-generated vs factual metrics.
- Dashboard customization should integrate Personalization Engine (Volume 3 Part 13).
- Never bypass RLS from Flutter.
