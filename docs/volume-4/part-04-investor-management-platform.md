# Volume 4 — Part 4: Investor Management Platform (IMP)



Investor Command Center™ for HD Homes admins — capital raise, portfolios,

distributions, KYC reviews, and the 360° investor workspace.



Admin feature lives under `lib/features/imp/`; the production investor portal

lives under `lib/features/investor/`.



## Status



| Layer | Status |

|-------|--------|

| Domain models (live records only) | Done |

| ImpService (Supabase reads and audited RPC writes) | Done |

| Riverpod snapshot / Realtime / UI controller | Done |

| `/dashboard/investors` Investor Command Center™ | **Done** (ops desk rebuild: consolidated tabs, desk KPIs, support reply, construction thumbs) |

| SQL + RLS + IMP tables | **APPLIED** remotely |

| Public `/investor` portal self-service | Live |

| Ops runbook + staff walkthrough | [part-04-investor-ops-runbook.md](./part-04-investor-ops-runbook.md) |

| Security / accounting / ledger hardening | Applied remotely |

| Paginated directory + Investor 360 API | Applied remotely |

| Work queues / ownership / tasks | Applied remotely |

| Governed payment confirm + commitment funding | Applied remotely |

| Reports / referrals / vault / conversations desk | Applied remotely |



Local migrations (canonical; applied remotely in phased chunks):



- `supabase/migrations/20260714150000_investor_management_platform.sql`

- `supabase/migrations/20260909110000_imp_security_integrity_foundation.sql`

- `supabase/migrations/20260909120000_imp_canonical_models.sql`

- `supabase/migrations/20260909123000_imp_command_api_realtime.sql`

- `supabase/migrations/20260909160000_imp_work_queues_relationships.sql`

- `supabase/migrations/20260910120000_imp_finance_lifecycle_governance.sql`

- `supabase/migrations/20260910140000_imp_engagement_desk.sql`



## Architecture



```text

InvestorCommandCenterPage

        ↓

impSnapshotProvider + directory/detail/queues providers + realtime

        ↓

ImpService ──► Supabase RPCs + live tables

        ↓

AdminDeskPage (Overview · Investors · Capital · Payments · Compliance ·

               Support · Insights · server-backed 360°)

```



Production behavior never invents investor records, balances, holdings,

opportunities, alerts, or AI summaries. An unavailable backend is an explicit

error; an empty backend is an honest empty state.



## Routes



| Path | Surface |

|------|---------|

| `/dashboard/investors` | Investor Command Center™ (admin / staff) |

| `/investor/*` | Live investor self-service portal |



## Enterprise features (Phase 1)



1. **Investor Command Center™** — AUM ticker, connection status, 360° Investor CTA

2. **KPI strip** — AUM, Active Investors, Capital Raised, Upcoming Payouts, Avg Investment, Open Opportunities  

3. **Capital Raise Manager™** — opportunity cards with **projected return estimates** + disclaimer  

4. **Portfolio Intelligence** — live holdings + wallets

5. **Distributions queue** — scheduled / paid  

6. **Alerts + activity timeline**  

7. **360° Investor Workspace** — profile, tags, KYC, holdings, payouts, documents, and communication



## Code map



```text

lib/features/imp/

  domain/entities/imp_models.dart

  domain/services/imp_service.dart

  presentation/providers/imp_controller.dart

  presentation/pages/investor_command_center_page.dart



lib/core/router/shell_routes.dart          # wires admin investors → Investor Command Center

lib/core/constants/permissions.dart        # investors.* slugs

supabase/migrations/20260714150000_investor_management_platform.sql

```



## Permissions (after SQL apply)



- `investors.read`

- `investors.write`

- `investors.opportunities`

- `investors.portfolio`

- `investors.distributions`

- `investors.documents`

- `investors.analytics`

- `investors.assign`

- `investors.kyc`

- `investors.communicate`

- `investors.payments`

- `investors.tasks`

- `investors.reports`

- `investors.referrals`

- `investors.audit`



Investor self-service access is enforced by ownership policies and must never

depend on a broad `investors.read` permission. Staff mutations require their

specific investor or finance capability.



## Schema notes



- Extends foundational `investors` / `investment_transactions` tables; adds IMP enrichment tables (`investor_profiles`, `investor_portfolios`, `investment_opportunities`, …).

- Opportunity status: `open|closed|fully_funded|suspended|completed`.

- `return_disclaimer` defaults to estimate language (projected returns are not guarantees).

- KYC statuses align with Volume 3 identity enums.

- RLS separates owner access from explicit staff capabilities.

- Realtime on: investors, opportunities, commitments, distributions, wallets, activity_logs, alerts.

- `investment_transactions` is the append-only canonical investor ledger.

- `investor_command_events` provides an investor-scoped realtime event stream.

- `website_investment_opportunities.operational_opportunity_id` links public

  presentation records to canonical operational opportunities.



## Tests



```bash

flutter test test/imp_platform_test.dart

dart analyze lib/features/imp

```



## Approval gate



Part 4 IMP SQL has been **applied remotely**. Open `/dashboard/investors` signed in as admin/finance/sales to load live data.



## Next



**Volume 4 — Part 5: [Sales & Booking Management System](./part-05-sales-booking-management-system.md)** — reservations, quotations, contracts, commissions, and deal execution (**SQL LOCAL ONLY — await approve**).

