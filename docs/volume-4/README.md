# Volume 4 — Admin Dashboard & Business Management

Enterprise operational core for **HD Homes Ltd**. Builds on Volume 2 public site and Volume 3 identity/RBAC.

Volume 4 continues through **Parts 1–26**. Part 10 (EOC) is a midpoint, not the end of the volume.

## Parts

| Part | Document | Status |
|------|----------|--------|
| 1 | [Executive Dashboard & Business Intelligence](./part-01-executive-dashboard-business-intelligence.md) | Phase 1 complete · SQL applied |
| 2 | [Property Management System (PMS)](./part-02-property-management-system.md) | Phase 1 complete · SQL applied |
| 3 | [Client Relationship Management (CRM)](./part-03-client-relationship-management.md) | Phase 1 complete · SQL applied |
| 4 | [Investor Management Platform (IMP)](./part-04-investor-management-platform.md) · [Ops runbook](./part-04-investor-ops-runbook.md) | Phase 1 complete · SQL applied · ops desk rebuild |
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
| 17 | [Enterprise AI Intelligence Hub, ML & Decision Support (EAIH)](./part-17-enterprise-ai-intelligence-hub.md) | Built · **AI deferred to Phase 2** (see [`docs/ai-deferment.md`](../ai-deferment.md)) |
| 18 | [Enterprise Integration Platform, API Gateway, Workflow Orchestration & Event-Driven Architecture (EIP)](./part-18-enterprise-integration-platform.md) | Phase 1 complete · SQL **APPLIED** |
| 19 | [Enterprise Security Operations Platform (ESP)](./part-19-enterprise-security-operations-platform.md) | Phase 1 complete · SQL **APPLIED** |
| 20 | [Enterprise DevOps, Platform Engineering, Infrastructure, Observability & Release Management (EDP)](./part-20-enterprise-devops-platform-engineering.md) | Phase 1 complete · SQL **APPLIED** |
| 21 | [Enterprise Communication, Collaboration, Knowledge Management & Digital Workplace (EDWP)](./part-21-enterprise-digital-workplace-platform.md) | Phase 1 complete · SQL **APPLIED** |
| 22 | [Enterprise Customer Experience, Omnichannel Engagement, Loyalty & Personalization (ECXP)](./part-22-enterprise-customer-experience-platform.md) | Phase 1 complete · SQL **APPLIED** |
| 23 | [Enterprise Performance Management, Financial Planning, Budgeting, Forecasting & Executive Reporting (EPM)](./part-23-enterprise-performance-management.md) | Phase 1 complete · SQL **APPLIED** (2026-07-21) |
| 24 | [Enterprise Governance, Risk, Compliance, Internal Audit & Business Continuity (EGRC)](./part-24-enterprise-grc-platform.md) | Phase 1 complete · SQL **APPLIED** (2026-07-21) |
| 25 | [Enterprise Executive Command Center, AI BI, Strategic Decision Support & Digital Twin (ECC)](./part-25-enterprise-executive-command-center.md) | Phase 1 complete · SQL **APPLIED** (2026-07-21) · **Volume 4 finale** |
| 26 | [Investor Portal (Production)](./part-26-investor-portal.md) | Flutter complete · SQL **APPLIED** · portal companion to IMP |

## Volume 4 status

**Volume 4 is complete** (Parts 1–25 Flutter + SQL).

**AI Deferment (Pre-Launch):** every AI surface across Volumes 2–4 is gated by
`kAiFeaturesEnabled = false`. See [`docs/ai-deferment.md`](../ai-deferment.md).
The platform launches as a rock-solid enterprise PropTech system; AI returns as
Phase 2 (Post-Launch AI Upgrade) without a redesign.

## Implementation rules

- Do **not** apply new migrations until approved.
- Protect executive metrics with RBAC (`view_executive_dashboard`, `manage_reports`, module permissions).
- Prefer KPI snapshots + Realtime over ad-hoc heavy joins from Flutter.
- AI is deferred — do not reintroduce AI UI, routes, or dependencies while
  `kAiFeaturesEnabled` is `false`. Keep extension points in
  `lib/core/engines/engines.dart` for Phase 2.
- Dashboard customization should integrate Personalization Engine (Volume 3 Part 13).
- Never bypass RLS from Flutter.
