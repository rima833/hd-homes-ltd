# Volume 1.5 – Part 4

# Finance & Construction Database Architecture

**Status:** Draft — awaiting approval before any migration work.

**Depends on:** [Part 1](./part-01-philosophy-and-core-schema.md) · [Part 2](./part-02-property-estate-architecture.md) · [Part 3](./part-03-client-investor-crm-architecture.md)

> Parts 5 and 6 of Volume 1.5 are still to come. This document is not the final blueprint volume.

---

## Module Overview

This module is the **financial engine** and **construction operations backbone** of HD Homes. Finance and construction are tightly coupled — construction progress directly affects property availability, installment schedules, and investor confidence.

| System | Capability |
|--------|------------|
| Client Dashboard | Payments, receipts, installment schedules, invoices |
| Investor Portal | Construction reports, ROI, project progress |
| Sales CRM | Payment status visibility (read-only) |
| Admin / Finance | Full ledger, commissions, expenses, reports |
| Construction | Projects, milestones, contractors, budgets, defects |
| Public Website | Payment initiation (via gateway webhooks) |
| Future | Mortgages, rentals, multi-company accounting |

---

## Finance Module

### Payment Lifecycle

```text
initiated → pending → processing → successful → receipt_generated → ledger_updated → completed
```

Failed, cancelled, refunded, and chargeback payments remain in history permanently. **Never hard-delete financial records.**

---

## Finance Table Catalog

| # | Table | Purpose |
|---|-------|---------|
| 1 | `payments` | Every payment transaction |
| 2 | `invoices` | Client billing documents |
| 3 | `invoice_line_items` | Invoice line breakdown |
| 4 | `receipts` | Generated on successful payment |
| 5 | `installment_plans` | Property financing plans (extends Part 2) |
| 6 | `installment_schedule` | Per-installment due dates and amounts |
| 7 | `refunds` | Refund requests and processing |
| 8 | `transactions_ledger` | Append-only financial ledger |
| 9 | `commissions` | Sales agent commission tracking |
| 10 | `expenses` | Company expense records |
| 11 | `financial_reports` | Generated report metadata |
| 12 | `payment_webhook_events` | Gateway webhook audit log |

> All tables include Part 1 audit fields unless noted append-only.

---

### 1. `payments`

**Purpose:** Central record for every payment transaction.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `payment_reference` | TEXT | UNIQUE, NOT NULL | Auto: `HD-PAY-00001` |
| `client_id` | UUID | FK → clients | |
| `investor_id` | UUID | FK → investors | Either client or investor |
| `property_id` | UUID | FK → properties | |
| `invoice_id` | UUID | FK → invoices | |
| `payment_plan_id` | UUID | FK → installment_plans | |
| `installment_id` | UUID | FK → installment_schedule | Specific installment |
| `amount` | NUMERIC(15,2) | NOT NULL | |
| `currency` | TEXT | DEFAULT `'NGN'` | |
| `payment_method` | payment_method | NOT NULL | Enum |
| `payment_provider` | TEXT | | `paystack`, `flutterwave`, etc. |
| `transaction_reference` | TEXT | | Gateway reference |
| `payment_status` | payment_status | DEFAULT `pending` | Enum |
| `payment_date` | TIMESTAMPTZ | | Actual payment timestamp |
| `verified_by` | UUID | FK → users | Finance staff |
| `verified_at` | TIMESTAMPTZ | | Manual verification |
| `notes` | TEXT | | |
| + audit fields | | | |

**Enum `payment_method`:** `bank_transfer`, `card`, `paystack`, `flutterwave`, `moniepoint`, `opay`, `ussd`, `pos`, `cash`, `cheque`, `mortgage`, `crypto`

**Enum `payment_status`:** `initiated`, `pending`, `processing`, `successful`, `failed`, `cancelled`, `refunded`, `chargeback`

**Indexes:** `idx_payments_client`, `idx_payments_property`, `idx_payments_status`, `idx_payments_reference`, `idx_payments_date DESC`

**Check:** `client_id IS NOT NULL OR investor_id IS NOT NULL`

---

### 2. `invoices`

**Purpose:** Formal billing documents.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `invoice_number` | TEXT | UNIQUE, NOT NULL | Auto: `HD-INV-00001` |
| `client_id` | UUID | FK → clients, NOT NULL | |
| `property_id` | UUID | FK → properties | |
| `issue_date` | DATE | NOT NULL | |
| `due_date` | DATE | NOT NULL | |
| `subtotal` | NUMERIC(15,2) | NOT NULL | |
| `tax` | NUMERIC(15,2) | DEFAULT 0 | VAT from settings |
| `discount` | NUMERIC(15,2) | DEFAULT 0 | |
| `total` | NUMERIC(15,2) | NOT NULL | |
| `currency` | TEXT | DEFAULT `'NGN'` | |
| `status` | invoice_status | DEFAULT `draft` | Enum |
| `notes` | TEXT | | |
| + audit fields | | | |

**Enum `invoice_status`:** `draft`, `issued`, `paid`, `overdue`, `cancelled`

**Indexes:** `idx_invoices_client`, `idx_invoices_status`, `idx_invoices_due_date`

---

### 3. `invoice_line_items`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | UUID | PK |
| `invoice_id` | UUID | FK → invoices, NOT NULL |
| `description` | TEXT | NOT NULL |
| `quantity` | INT | DEFAULT 1 |
| `unit_price` | NUMERIC(15,2) | NOT NULL |
| `line_total` | NUMERIC(15,2) | NOT NULL |
| + audit fields | | |

---

### 4. `receipts`

**Purpose:** Auto-generated on successful payment. PDF stored via media.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `receipt_number` | TEXT | UNIQUE, NOT NULL | Auto: `HD-RCP-00001` |
| `payment_id` | UUID | FK → payments, UNIQUE, NOT NULL | 1:1 |
| `client_id` | UUID | FK → clients | |
| `receipt_media_id` | UUID | FK → media | PDF in `receipts` bucket |
| `issued_by` | UUID | FK → users | System or finance staff |
| `issued_at` | TIMESTAMPTZ | DEFAULT now() | |
| + audit fields | | | |

**Automation:** On `payments.payment_status = 'successful'` → INSERT receipt + generate PDF (Edge Function).

---

### 5. `installment_plans`

**Purpose:** Financing plan definitions (extends Part 2 `property_payment_plans`).

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `property_id` | UUID | FK → properties, NOT NULL | |
| `client_id` | UUID | FK → clients | Assigned on reservation |
| `plan_name` | TEXT | NOT NULL | |
| `minimum_deposit` | NUMERIC(15,2) | NOT NULL | |
| `interest_rate` | NUMERIC(5,2) | DEFAULT 0 | Annual % |
| `duration_months` | INT | NOT NULL | |
| `grace_period_days` | INT | DEFAULT 0 | |
| `processing_fee` | NUMERIC(15,2) | DEFAULT 0 | |
| `late_fee` | NUMERIC(15,2) | DEFAULT 0 | Per overdue installment |
| `status` | TEXT | DEFAULT `active` | |
| + audit fields | | | |

> **Alignment note:** Part 2 defined `property_payment_plans`. Target schema consolidates to `installment_plans` with client assignment — migration will rename/extend.

---

### 6. `installment_schedule`

**Purpose:** Every installment due date and payment status.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `payment_plan_id` | UUID | FK → installment_plans, NOT NULL | |
| `installment_number` | INT | NOT NULL | 1, 2, 3… |
| `due_date` | DATE | NOT NULL | |
| `amount` | NUMERIC(15,2) | NOT NULL | |
| `status` | installment_status | DEFAULT `pending` | Enum |
| `paid_at` | TIMESTAMPTZ | | |
| `payment_id` | UUID | FK → payments | Link on payment |
| + audit fields | | | |

**Enum `installment_status`:** `pending`, `paid`, `overdue`, `waived`, `cancelled`

**Unique:** `(payment_plan_id, installment_number)`

**Indexes:** `idx_installment_schedule_due (due_date, status)`

**Automation:** Cron job marks `overdue` past `due_date + grace_period`; notifies client.

---

### 7. `refunds`

**Purpose:** Refund request workflow.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `payment_id` | UUID | FK → payments, NOT NULL | |
| `requested_by` | UUID | FK → users | |
| `reason` | TEXT | NOT NULL | |
| `refund_amount` | NUMERIC(15,2) | NOT NULL | |
| `status` | refund_status | DEFAULT `pending` | Enum |
| `approved_by` | UUID | FK → users | |
| `processed_at` | TIMESTAMPTZ | | |
| + audit fields | | | |

**Enum `refund_status`:** `pending`, `approved`, `rejected`, `processed`

---

### 8. `transactions_ledger`

**Purpose:** Append-only double-entry financial ledger. **Never UPDATE or DELETE.**

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `reference` | TEXT | NOT NULL | Links to payment/invoice |
| `transaction_type` | ledger_transaction_type | NOT NULL | Enum |
| `amount` | NUMERIC(15,2) | NOT NULL | |
| `currency` | TEXT | DEFAULT `'NGN'` | |
| `debit_account` | TEXT | NOT NULL | Chart of accounts code |
| `credit_account` | TEXT | NOT NULL | Chart of accounts code |
| `description` | TEXT | | |
| `payment_id` | UUID | FK → payments | |
| `metadata` | JSONB | DEFAULT `{}` | |
| `created_at` | TIMESTAMPTZ | DEFAULT now() | Append-only |

**Enum `ledger_transaction_type`:** `payment`, `refund`, `commission`, `expense`, `adjustment`, `transfer`

**RLS:** INSERT by system/triggers only; SELECT by finance role. No UPDATE/DELETE policies.

**Future:** Multi-company via `company_id` column.

---

### 9. `commissions`

**Purpose:** Sales agent commission on closed sales.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `sales_agent_id` | UUID | FK → users, NOT NULL | |
| `property_id` | UUID | FK → properties | |
| `client_id` | UUID | FK → clients | |
| `payment_id` | UUID | FK → payments | Triggering payment |
| `commission_percentage` | NUMERIC(5,2) | NOT NULL | |
| `commission_amount` | NUMERIC(15,2) | NOT NULL | |
| `status` | commission_status | DEFAULT `pending` | Enum |
| `paid_at` | TIMESTAMPTZ | | |
| + audit fields | | | |

**Enum `commission_status`:** `pending`, `approved`, `paid`, `cancelled`

---

### 10. `expenses`

**Purpose:** Company operational expenses.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `expense_category` | expense_category | NOT NULL | Enum |
| `description` | TEXT | NOT NULL | |
| `amount` | NUMERIC(15,2) | NOT NULL | |
| `currency` | TEXT | DEFAULT `'NGN'` | |
| `vendor` | TEXT | | |
| `supplier_id` | UUID | FK → suppliers | |
| `project_id` | UUID | FK → construction_projects | Construction expenses |
| `invoice_media_id` | UUID | FK → media | |
| `approved_by` | UUID | FK → users | |
| `expense_date` | DATE | NOT NULL | |
| + audit fields | | | |

**Enum `expense_category`:** `construction`, `marketing`, `office`, `utilities`, `payroll`, `legal`, `other`

---

### 11. `financial_reports`

**Purpose:** Metadata for generated financial reports (PDF via media).

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `report_type` | financial_report_type | NOT NULL | Enum |
| `title` | TEXT | NOT NULL | |
| `period_start` | DATE | | |
| `period_end` | DATE | | |
| `media_id` | UUID | FK → media | Generated PDF |
| `generated_by` | UUID | FK → users | System or staff |
| `generated_at` | TIMESTAMPTZ | DEFAULT now() | |
| `metadata` | JSONB | DEFAULT `{}` | Summary figures |
| + audit fields | | | |

**Enum `financial_report_type`:** `revenue`, `expenses`, `profit`, `sales`, `installments`, `outstanding_payments`, `refunds`, `investor_returns`, `monthly_performance`

---

### 12. `payment_webhook_events`

**Purpose:** Immutable log of payment gateway webhooks (Paystack, Flutterwave).

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `provider` | TEXT | `paystack`, `flutterwave` |
| `event_type` | TEXT | |
| `payload` | JSONB | Raw webhook body |
| `payment_id` | UUID | FK → payments |
| `processed` | BOOLEAN | DEFAULT false |
| `created_at` | TIMESTAMPTZ | Append-only |

---

## Construction Module

### Project Lifecycle

```text
planning → approval → foundation → structure → roofing → finishing
         → inspection → completed → handover
```

Enum: `construction_project_status`

Construction progress updates property `availability` and investor reporting.

---

## Construction Table Catalog

| # | Table | Purpose |
|---|-------|---------|
| 13 | `construction_projects` | Estate/phase construction projects |
| 14 | `construction_milestones` | Project milestones |
| 15 | `construction_updates` | Daily/weekly progress posts |
| 16 | `construction_media` | Photos, drone, 360° (via media FK) |
| 17 | `contractors` | Contractor registry |
| 18 | `project_contractors` | Project ↔ contractor M2M |
| 19 | `project_materials` | Material usage tracking |
| 20 | `suppliers` | Supplier registry |
| 21 | `project_budgets` | Budget vs actual tracking |
| 22 | `site_inspections` | Quality inspections |
| 23 | `defect_logs` | Defect tracking and resolution |
| 24 | `handover_records` | Client handover documentation |
| 25 | `investor_construction_reports` | Investor-facing progress reports |
| 26 | `ai_construction_analytics` | AI predictions per project |

---

### 13. `construction_projects`

**Purpose:** Central construction project record.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `project_code` | TEXT | UNIQUE, NOT NULL | Auto: `HD-PRJ-00001` |
| `estate_id` | UUID | FK → estates | |
| `phase_id` | UUID | FK → estate_phases | |
| `property_id` | UUID | FK → properties | Unit-level projects |
| `project_name` | TEXT | NOT NULL | |
| `description` | TEXT | | |
| `budget` | NUMERIC(15,2) | | Total approved budget |
| `start_date` | DATE | | |
| `expected_completion` | DATE | | |
| `actual_completion` | DATE | | |
| `status` | construction_project_status | DEFAULT `planning` | Enum |
| `project_manager_id` | UUID | FK → users | |
| `completion_percent` | NUMERIC(5,2) | DEFAULT 0 | Cached |
| + audit fields | | | |

**Indexes:** `idx_projects_estate`, `idx_projects_status`, `idx_projects_manager`

---

### 14. `construction_milestones`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `project_id` | UUID | FK → construction_projects, NOT NULL | |
| `title` | TEXT | NOT NULL | e.g. Site Clearing |
| `description` | TEXT | | |
| `completion_percentage` | NUMERIC(5,2) | | Weight toward project % |
| `status` | milestone_status | DEFAULT `pending` | Enum |
| `planned_date` | DATE | | |
| `completed_date` | DATE | | |
| `sort_order` | INT | DEFAULT 0 | |
| + audit fields | | | |

**Enum `milestone_status`:** `pending`, `in_progress`, `completed`, `delayed`, `cancelled`

---

### 15. `construction_updates`

**Purpose:** Daily/weekly progress posts (client + investor visible).

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `project_id` | UUID | FK → construction_projects, NOT NULL | |
| `title` | TEXT | NOT NULL | |
| `description` | TEXT | | |
| `progress_percentage` | NUMERIC(5,2) | | Snapshot at update time |
| `weather` | TEXT | | Optional context |
| `updated_by` | UUID | FK → users | |
| `update_date` | DATE | DEFAULT CURRENT_DATE | |
| + audit fields | | | |

**Automation:** Notify investors and clients linked to project properties.

---

### 16. `construction_media`

**Purpose:** Unified media for construction (replaces separate photos/videos tables).

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `project_id` | UUID | FK → construction_projects | |
| `update_id` | UUID | FK → construction_updates | Optional link |
| `media_id` | UUID | FK → media, NOT NULL | |
| `caption` | TEXT | | |
| `media_type` | construction_media_type | NOT NULL | Enum |
| `uploaded_by` | UUID | FK → users | |
| + audit fields | | | |

**Enum `construction_media_type`:** `photo`, `drone_video`, `progress_video`, `tour_360`

**Storage buckets:** `construction-images`, `construction-videos`

---

### 17. `contractors`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | UUID | PK |
| `company_name` | TEXT | NOT NULL |
| `contact_person` | TEXT | |
| `phone` | TEXT | |
| `email` | TEXT | |
| `specialization` | TEXT | `foundation`, `roofing`, `electrical`, etc. |
| `license_number` | TEXT | |
| `status` | TEXT | DEFAULT `active` |
| + audit fields | | |

---

### 18. `project_contractors`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | UUID | PK |
| `project_id` | UUID | FK → construction_projects, NOT NULL |
| `contractor_id` | UUID | FK → contractors, NOT NULL |
| `contract_value` | NUMERIC(15,2) | |
| `start_date` | DATE | |
| `end_date` | DATE | |
| + audit fields | | |

**Unique:** `(project_id, contractor_id)`

---

### 19. `project_materials`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `project_id` | UUID | FK → construction_projects, NOT NULL | |
| `material_name` | TEXT | NOT NULL | Cement, Steel, Tiles… |
| `quantity` | NUMERIC(12,2) | NOT NULL | |
| `unit` | TEXT | NOT NULL | `bags`, `tons`, `sqm` |
| `cost` | NUMERIC(15,2) | | |
| `supplier_id` | UUID | FK → suppliers | |
| + audit fields | | | |

---

### 20. `suppliers`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | UUID | PK |
| `company_name` | TEXT | NOT NULL |
| `contact_person` | TEXT | |
| `phone` | TEXT | |
| `email` | TEXT | |
| `address` | TEXT | |
| `category` | TEXT | `materials`, `equipment`, `services` |
| + audit fields | | |

---

### 21. `project_budgets`

**Purpose:** Budget vs spent tracking per project.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `project_id` | UUID | FK → construction_projects, UNIQUE | 1:1 |
| `budget` | NUMERIC(15,2) | NOT NULL | Approved budget |
| `spent` | NUMERIC(15,2) | DEFAULT 0 | Computed from expenses + materials |
| `remaining` | NUMERIC(15,2) | GENERATED | `budget - spent` |
| `variance` | NUMERIC(15,2) | | `spent - budget` |
| `updated_at` | TIMESTAMPTZ | | |
| + audit fields | | | |

**Automation:** Recalculate `spent` on expense/material INSERT.

---

### 22. `site_inspections`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `project_id` | UUID | FK → construction_projects, NOT NULL | |
| `inspector_id` | UUID | FK → users | |
| `inspection_date` | DATE | NOT NULL | |
| `result` | inspection_result | NOT NULL | Enum |
| `remarks` | TEXT | | |
| + audit fields | | | |

**Enum `inspection_result`:** `passed`, `passed_with_notes`, `failed`, `requires_rework`

---

### 23. `defect_logs`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `project_id` | UUID | FK → construction_projects, NOT NULL | |
| `milestone_id` | UUID | FK → construction_milestones | |
| `description` | TEXT | NOT NULL | |
| `severity` | defect_severity | NOT NULL | Enum |
| `assigned_to` | UUID | FK → users | |
| `resolved_at` | TIMESTAMPTZ | | |
| + audit fields | | | |

**Enum `defect_severity`:** `low`, `medium`, `high`, `critical`

---

### 24. `handover_records`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `project_id` | UUID | FK → construction_projects, NOT NULL | |
| `client_id` | UUID | FK → clients, NOT NULL | |
| `property_id` | UUID | FK → properties | |
| `handover_date` | DATE | NOT NULL | |
| `accepted_by` | UUID | FK → users | Client representative |
| `documents_media_id` | UUID | FK → media | Handover pack PDF |
| + audit fields | | | |

**Automation:** On handover → update `client_properties.ownership_status`, property status → `sold`.

---

### 25. `investor_construction_reports`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `project_id` | UUID | FK → construction_projects, NOT NULL | |
| `investor_id` | UUID | FK → investors, NOT NULL | |
| `report_period` | TEXT | NOT NULL | e.g. `2026-Q1` |
| `progress` | NUMERIC(5,2) | | Completion % |
| `photos` | JSONB | DEFAULT `[]` | Array of media_ids |
| `financial_summary` | JSONB | DEFAULT `{}` | Budget/spend summary |
| `media_id` | UUID | FK → media | Full PDF report |
| `generated_at` | TIMESTAMPTZ | DEFAULT now() | |

---

### 26. `ai_construction_analytics`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `project_id` | UUID | FK → construction_projects, UNIQUE | 1:1 |
| `completion_prediction` | DATE | | AI forecast date |
| `delay_probability` | NUMERIC(5,4) | | 0–1 |
| `budget_risk` | NUMERIC(5,4) | | 0–1 overrun probability |
| `material_forecast` | JSONB | DEFAULT `{}` | Predicted material needs |
| `generated_at` | TIMESTAMPTZ | | |

---

## Enterprise Enhancement: Executive Operations Dashboard

### `executive_dashboard_metrics` (VIEW + RPC)

**Purpose:** Single real-time view for MD, GM, and executives — aggregating finance, construction, CRM, sales, and marketing.

**KPIs displayed:**

| Category | Metrics |
|----------|---------|
| Revenue | Daily / weekly / monthly / yearly revenue |
| Sales | Pipeline value, conversions, top agents |
| Construction | Progress across all estates, delayed projects |
| Finance | Outstanding payments, cash flow trends, refunds |
| Investors | ROI summaries, portfolio performance |
| CRM | Lead conversion rates, active leads |
| Marketing | Campaign performance |
| Alerts | Critical overdue items, AI business insights |

```sql
-- Planned RPC: executive_dashboard_metrics(period TEXT)
-- Returns JSONB with all KPI sections
-- Backed by materialized views refreshed hourly
```

**Data sources:** `payments`, `transactions_ledger`, `construction_projects`, `leads`, `property_reservations`, `investment_returns`, `ai_customer_insights`, `ai_construction_analytics`, `commissions`

**RLS:** `reports.view` permission or `super_admin` / `admin` roles only.

---

## Relationship Overview

```text
Payments
│
├── Receipts (1:1 on success)
├── Invoices
├── Installment Plans → Installment Schedule
├── Refunds
├── Transactions Ledger (append-only)
├── Commissions
├── Payment Webhook Events
└── Financial Reports

Construction Projects
│
├── Milestones
├── Updates → Construction Media
├── Contractors (M2M)
├── Materials → Suppliers
├── Budgets
├── Site Inspections
├── Defect Logs
├── Handover Records
├── Investor Construction Reports
└── AI Construction Analytics

Cross-module links:
  payments.property_id → properties
  payments.client_id → clients (Part 3)
  construction_projects.estate_id → estates (Part 2)
  handover_records → client_properties (Part 3)
  expenses.project_id → construction_projects
```

---

## Row-Level Security (RLS)

### Clients

| Table | Access |
|-------|--------|
| `payments`, `receipts`, `invoices` | SELECT own (`client_id` match) |
| `installment_schedule` | SELECT own via plan |
| Financial documents | SELECT where visibility allows |
| Construction updates | SELECT for owned properties |
| Ledger, expenses, commissions | **No access** |

### Investors

| Table | Access |
|-------|--------|
| `investor_construction_reports` | SELECT own |
| `construction_updates`, `construction_media` | SELECT for invested estates/properties |
| `investment_returns` | SELECT own (Part 3) |
| Payments / ledger | **No access** unless investor payment |

### Finance Team

| Table | Access |
|-------|--------|
| All finance tables | ALL with `payment.approve` / `finance` role |
| `expenses` | ALL |
| `financial_reports` | ALL |
| Construction budgets | SELECT only |
| HR / system settings | **No access** unless permitted |

### Construction Managers

| Table | Access |
|-------|--------|
| All construction tables | ALL with `construction.update` |
| `project_budgets`, `expenses` (project) | ALL |
| `payments`, payroll | **No access** |

### Sales Team

| Table | Access |
|-------|--------|
| `payments` | SELECT for assigned clients only |
| `commissions` | SELECT own |
| Edit financial records | **Denied** |

### Marketing Team

No access to finance or construction tables.

### Admins

Full access based on assigned permissions.

---

## Automation & Business Rules

| Event | Automation |
|-------|-------------|
| Payment initiated | Generate `payment_reference`, INSERT ledger `initiated` |
| Webhook received | Log `payment_webhook_events`, verify signature, update status |
| Payment successful | Generate receipt PDF, INSERT ledger, notify finance + sales |
| Payment failed | Retain record, notify client, no receipt |
| Invoice issued | Generate `invoice_number`, notify client |
| Invoice overdue | Cron: set status `overdue`, send reminder |
| Installment due | Cron: notify client; apply late fee after grace |
| Final payment | Update property status → `sold`, create `client_properties` |
| Commission trigger | On successful payment → INSERT `commissions` |
| Refund approved | INSERT ledger reversal, update payment status |
| Construction update | Notify linked investors + clients |
| Milestone delayed | Alert project manager |
| Budget overrun | Alert finance + executive dashboard |
| Handover complete | Update ownership, generate handover documents |
| Monthly cron | Generate `financial_reports` + `investor_construction_reports` |
| Nightly cron | Refresh `ai_construction_analytics` |

---

## Realtime Subscriptions

| Channel | Table | Audience |
|---------|-------|----------|
| Payment status | `payments` | Client (own), finance (all) |
| Construction updates | `construction_updates` | Investors, clients on project |
| Budget alerts | `project_budgets` | Project managers, executives |
| Defect assigned | `defect_logs` | Assigned contractor/staff |

---

## API Contract (Flutter ↔ Supabase)

| Operation | Table / RPC |
|-----------|-------------|
| Initiate payment | `payments.insert()` + gateway SDK |
| Verify webhook | Edge Function `payment-webhook` |
| Client payment history | `payments.select().eq('client_id', id)` |
| Download receipt | `receipts` → `media` → storage URL |
| View installment schedule | `installment_schedule` via plan |
| Finance dashboard | `rpc('finance_dashboard_metrics')` |
| Construction progress | `construction_updates` + `construction_media` |
| Project budget | `project_budgets.select().eq('project_id', id)` |
| Executive dashboard | `rpc('executive_dashboard_metrics', {period})` |
| Investor report | `investor_construction_reports.select()` |

---

## Cursor Implementation Checklist

| Step | Action | Status |
|------|--------|--------|
| 1 | Explain business purpose | ✅ This document |
| 2 | Define relationships | ✅ ERD above |
| 3 | Create PostgreSQL schema | ⏳ Awaiting approval |
| 4 | Add indexes and constraints | ✅ Defined above |
| 5 | Enable RLS | ✅ Policy model defined |
| 6 | Create Supabase migration | ⏳ Awaiting approval |
| 7 | Add seed data | ⏳ Part 8 |
| 8 | Document API contracts | ✅ Above |
| 9 | Configure realtime | ✅ Defined above |
| 10 | Wait for approval | **← Current step** |

---

## Gap Analysis: Live Schema vs Part 4 Target

### Finance

| Part 4 Target | Live | Gap |
|---------------|------|-----|
| `payments` with full lifecycle | Basic `payments` (12 cols) | **Extend** — add reference, invoice_id, verified_by, full status enum |
| `invoices` with line items | Basic `invoices` (no subtotal/tax) | **Extend** + add `invoice_line_items` |
| `receipts` with media_id | `file_url` inline | **Migrate** to media FK |
| `installment_plans` | `property_payment_plans` (Part 2) | **Rename/extend** + add client_id |
| `installment_schedule` | `installments` (client-linked) | **Restructure** — link to plan schedule |
| `refunds` | Missing | **New table** |
| `transactions_ledger` | `transactions` (basic) | **Replace/extend** — append-only, debit/credit |
| `commissions` | Exists | **Extend** — add property_id, client_id |
| `expenses` | Missing | **New table** |
| `financial_reports` | Missing | **New table** |
| `payment_webhook_events` | Missing | **New table** |

### Construction

| Part 4 Target | Live | Gap |
|---------------|------|-----|
| `construction_projects` | `projects` (basic) | **Rename/extend** — add project_code, budget, manager |
| `construction_milestones` | `milestones` | **Extend** — add completion_percentage, status enum |
| `construction_updates` | Exists | **Extend** — add weather, progress_percentage |
| `construction_media` | `construction_photos` + `construction_videos` | **Consolidate** via media FK |
| `contractors` | Missing | **New table** |
| `project_contractors` | Missing | **New table** |
| `project_materials` | Missing | **New table** |
| `suppliers` | Missing | **New table** |
| `project_budgets` | Missing | **New table** |
| `site_inspections` | Missing | **New table** |
| `defect_logs` | Missing | **New table** |
| `handover_records` | Missing | **New table** |
| `investor_construction_reports` | Missing | **New table** |
| `ai_construction_analytics` | Missing | **New table** |
| `executive_dashboard_metrics` | Missing | **New VIEW/RPC** |

---

## Future Expansion Hooks

| Feature | Schema preparation |
|---------|-------------------|
| Mortgages | `payment_method = 'mortgage'`, `installment_plans` interest fields |
| Rentals | New `rental_agreements` table (Part 5+) |
| Multi-company | `company_id` on ledger, expenses, projects |
| Crypto payments | `payment_method = 'crypto'` enum value ready |

---

**End of Volume 1.5 – Part 4**

*Awaiting Parts 5 and 6, then approval before migration work.*
