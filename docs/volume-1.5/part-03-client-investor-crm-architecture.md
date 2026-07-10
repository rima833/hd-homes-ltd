# Volume 1.5 – Part 3

# Client, Investor & CRM Database Architecture

**Status:** Draft — awaiting approval before any migration work.

**Depends on:** [Part 1](./part-01-philosophy-and-core-schema.md) · [Part 2](./part-02-property-estate-architecture.md)

---

## Module Overview

The Client, Investor & CRM module manages every interaction from first website visit through long-term ownership, investment, and referral.

It powers:

| System | Capability |
|--------|------------|
| CRM | Lead pipeline, activities, tasks, 360° customer view |
| Client Dashboard | Properties, documents, reservations, inspections |
| Investor Portal | Portfolios, assets, returns, reports |
| Sales | Lead scoring, assignments, follow-ups |
| Support | Tickets, live chat, private messages |
| Marketing | Referrals, loyalty, saved searches, feedback |
| AI | Purchase probability, churn risk, recommendations |
| Notifications | Cross-channel reminders and alerts |

The database must support **millions of users** with complete, immutable customer history.

---

## Customer Journey

```text
Visitor
  ↓
Lead
  ↓
Registered User
  ↓
Qualified Lead
  ↓
Inspection Booked
  ↓
Reservation Made
  ↓
Payment Started
  ↓
Verified Client
  ↓
Property Owner
  ↓
Investor
  ↓
Referral Partner
  ↓
VIP Client
```

Every transition is logged in `lead_status_history`, `client_timeline`, or `activity_logs`. Journey stage is derivable from related records — not stored as a single mutable field.

---

## Table Catalog

Part 3 defines **35 tables** (including junction, history, and chat sub-tables).

| # | Table | Module |
|---|-------|--------|
| **Lead Management** | | |
| 1 | `leads` | CRM |
| 2 | `lead_status_history` | CRM |
| 3 | `lead_activities` | CRM |
| **Clients** | | |
| 4 | `clients` | Client |
| 5 | `client_properties` | Client |
| 6 | `client_documents` | Client |
| 7 | `client_notes` | CRM |
| 8 | `client_timeline` | Client |
| 9 | `client_loyalty` | Client |
| **Investors** | | |
| 10 | `investors` | Investor |
| 11 | `investment_portfolios` | Investor |
| 12 | `investment_assets` | Investor |
| 13 | `investment_returns` | Investor |
| 14 | `investment_reports` | Investor |
| **Referrals & Loyalty** | | |
| 15 | `referrals` | Marketing |
| **Support & Communication** | | |
| 16 | `support_tickets` | Support |
| 17 | `ticket_messages` | Support |
| 18 | `chat_rooms` | Support |
| 19 | `chat_members` | Support |
| 20 | `chat_messages` | Support |
| 21 | `chat_attachments` | Support |
| 22 | `messages` | Communication |
| **Engagement** | | |
| 23 | `inspection_bookings` | CRM / Property |
| 24 | `property_reservations` | CRM / Property |
| 25 | `wishlists` | Client |
| 26 | `saved_searches` | Client |
| 27 | `appointments` | CRM |
| 28 | `customer_feedback` | Client |
| **CRM Operations** | | |
| 29 | `crm_tasks` | CRM |
| 30 | `ai_customer_insights` | Analytics / AI |
| **Views (read-only)** | | |
| 31 | `customer_360_profile` | VIEW — enterprise enhancement |

> Cross-module tables from Part 2 referenced here: `property_inquiries`, `property_favorites` (may alias `wishlists`).

> All tables include Part 1 audit fields unless noted append-only.

---

## Lead Management

### 1. `leads`

**Purpose:** Every potential customer from any source.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `lead_code` | TEXT | UNIQUE, NOT NULL | Auto: `HD-L-00001` |
| `first_name` | TEXT | NOT NULL | |
| `last_name` | TEXT | | |
| `email` | TEXT | | |
| `phone` | TEXT | | |
| `preferred_contact_method` | TEXT | | `email`, `phone`, `whatsapp` |
| `lead_source` | lead_source | NOT NULL | Enum |
| `interest_type` | TEXT | | `buy`, `invest`, `rent` |
| `budget_min` | NUMERIC(15,2) | | |
| `budget_max` | NUMERIC(15,2) | | |
| `preferred_location` | TEXT | | City/area |
| `preferred_property_type` | UUID | FK → property_types | |
| `property_id` | UUID | FK → properties | Property of interest |
| `status` | lead_status | DEFAULT `new` | Enum |
| `score` | INT | DEFAULT 0 | AI/rule-based 0–100 |
| `assigned_sales_agent` | UUID | FK → users | |
| `next_followup_date` | TIMESTAMPTZ | | |
| `notes` | TEXT | | Summary only — detail in activities |
| `user_id` | UUID | FK → users | Set on registration |
| `converted_client_id` | UUID | FK → clients | Set on win |
| + audit fields | | | |

**Enum `lead_source`:** `website`, `facebook`, `instagram`, `google_ads`, `referral`, `walk_in`, `whatsapp`, `phone_call`, `email_campaign`, `partner`

**Indexes:** `idx_leads_status`, `idx_leads_assigned_agent`, `idx_leads_next_followup`, `idx_leads_email`, `idx_leads_phone`, `idx_leads_score DESC`

---

### 2. `lead_status_history`

**Purpose:** Immutable lead status transitions. Never overwrite.

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | UUID | PK |
| `lead_id` | UUID | FK → leads, NOT NULL |
| `old_status` | lead_status | |
| `new_status` | lead_status | NOT NULL |
| `changed_by` | UUID | FK → users |
| `reason` | TEXT | |
| `created_at` | TIMESTAMPTZ | DEFAULT now() |

**Enum `lead_status`:** `new`, `contacted`, `qualified`, `inspection_scheduled`, `negotiation`, `reservation`, `won`, `lost`, `dormant`

---

### 3. `lead_activities`

**Purpose:** Every sales interaction on a lead.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `lead_id` | UUID | FK → leads, NOT NULL | |
| `activity_type` | lead_activity_type | NOT NULL | Enum |
| `description` | TEXT | | |
| `performed_by` | UUID | FK → users | |
| `scheduled_at` | TIMESTAMPTZ | | |
| `completed_at` | TIMESTAMPTZ | | |
| `metadata` | JSONB | DEFAULT `{}` | Call duration, email ID, etc. |
| + audit fields | | | |

**Enum `lead_activity_type`:** `phone_call`, `email`, `whatsapp`, `meeting`, `inspection`, `reminder`, `proposal_sent`, `follow_up`

**Indexes:** `idx_lead_activities_lead_id`, `idx_lead_activities_scheduled`

---

## Clients

### 4. `clients`

**Purpose:** Verified buyers and property owners.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `user_id` | UUID | FK → users, UNIQUE | |
| `client_number` | TEXT | UNIQUE, NOT NULL | Auto: `HD-C-00001` |
| `verification_status` | kyc_status | DEFAULT `pending` | From Part 1 |
| `assigned_sales_agent` | UUID | FK → users | |
| `lifetime_value` | NUMERIC(15,2) | DEFAULT 0 | Computed/cached |
| `referral_code` | TEXT | UNIQUE | Auto-generated |
| `loyalty_level` | loyalty_level | DEFAULT `bronze` | Enum |
| `journey_stage` | customer_journey_stage | | Derived/cached |
| + audit fields | | | |

**Enum `loyalty_level`:** `bronze`, `silver`, `gold`, `platinum`, `diamond`

**Enum `customer_journey_stage`:** `visitor`, `lead`, `registered`, `qualified`, `inspection_booked`, `reservation`, `payment_started`, `verified`, `owner`, `investor`, `referral_partner`, `vip`

---

### 5. `client_properties`

**Purpose:** Property ownership records.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `client_id` | UUID | FK → clients, NOT NULL | |
| `property_id` | UUID | FK → properties, NOT NULL | |
| `ownership_type` | ownership_type | NOT NULL | Enum |
| `purchase_date` | DATE | | |
| `allocation_date` | DATE | | |
| `ownership_status` | ownership_status | DEFAULT `pending` | Enum |
| + audit fields | | | |

**Enum `ownership_type`:** `full`, `fractional`, `installment`, `lease`

**Enum `ownership_status`:** `pending`, `allocated`, `active`, `transferred`, `sold`

**Unique:** `(client_id, property_id)` where `ownership_status != 'transferred'`

---

### 6. `client_documents`

**Purpose:** KYC and transaction documents.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `client_id` | UUID | FK → clients, NOT NULL | |
| `media_id` | UUID | FK → media, NOT NULL | |
| `document_type` | client_document_type | NOT NULL | Enum |
| `verification_status` | document_verification_status | DEFAULT `pending` | |
| `visibility` | document_visibility | DEFAULT `client` | Enum |
| `title` | TEXT | | |
| + audit fields | | | |

**Enum `client_document_type`:** `kyc`, `passport`, `national_id`, `allocation_letter`, `contract`, `receipt`, `title_document`

**Enum `document_visibility`:** `client`, `admin`, `finance`, `legal`

**Storage bucket:** `documents` (private, `{user_id}/`)

---

### 7. `client_notes`

**Purpose:** Private internal staff notes. Never visible to client.

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | UUID | PK |
| `client_id` | UUID | FK → clients, NOT NULL |
| `staff_id` | UUID | FK → users, NOT NULL |
| `note` | TEXT | NOT NULL |
| `created_at` | TIMESTAMPTZ | DEFAULT now() |

**RLS:** Staff with `crm.manage` only. Clients have zero access.

---

### 8. `client_timeline`

**Purpose:** Complete client event history for dashboard and Customer 360.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `client_id` | UUID | FK → clients, NOT NULL | |
| `event` | TEXT | NOT NULL | Machine key |
| `description` | TEXT | | Human-readable |
| `entity_type` | TEXT | | `property`, `payment`, `inspection` |
| `entity_id` | UUID | | |
| `metadata` | JSONB | DEFAULT `{}` | |
| `created_at` | TIMESTAMPTZ | DEFAULT now() | Append-only |

**Examples:** Registered, Booked Inspection, Reserved Property, Made Payment, Uploaded Documents, Signed Contract, Completed Purchase

**Automation:** Triggers on reservations, payments, document uploads append timeline rows.

---

### 9. `client_loyalty`

**Purpose:** Loyalty program tracking and configurable benefits.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `client_id` | UUID | FK → clients, UNIQUE | |
| `level` | loyalty_level | DEFAULT `bronze` | |
| `points` | INT | DEFAULT 0 | |
| `benefits` | JSONB | DEFAULT `{}` | Configurable per level |
| `level_achieved_at` | TIMESTAMPTZ | | |
| `next_review_at` | TIMESTAMPTZ | | |
| + audit fields | | | |

---

## Investors

### 10. `investors`

**Purpose:** Investor-specific account data.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `user_id` | UUID | FK → users, UNIQUE | |
| `investor_code` | TEXT | UNIQUE, NOT NULL | Auto: `HD-I-00001` |
| `company_name` | TEXT | | Corporate investors |
| `investment_type` | TEXT | | `individual`, `corporate` |
| `investment_budget` | NUMERIC(15,2) | | |
| `investment_goal` | TEXT | | `income`, `growth`, `diversification` |
| `risk_profile` | risk_profile | DEFAULT `medium` | Enum |
| `portfolio_value` | NUMERIC(15,2) | DEFAULT 0 | Cached |
| `preferred_locations` | TEXT[] | | |
| `preferred_property_types` | UUID[] | | FK array to property_types |
| `investment_status` | investment_status | DEFAULT `active` | Enum |
| + audit fields | | | |

**Enum `risk_profile`:** `low`, `medium`, `high`

**Enum `investment_status`:** `prospect`, `active`, `inactive`, `closed`

---

### 11. `investment_portfolios`

**Purpose:** Grouped investments per investor.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `investor_id` | UUID | FK → investors, NOT NULL | |
| `portfolio_name` | TEXT | NOT NULL | |
| `description` | TEXT | | |
| `total_value` | NUMERIC(15,2) | DEFAULT 0 | Computed |
| `roi` | NUMERIC(8,4) | | Cached % |
| `status` | TEXT | DEFAULT `active` | |
| + audit fields | | | |

---

### 12. `investment_assets`

**Purpose:** Individual property/estate holdings within a portfolio.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `portfolio_id` | UUID | FK → investment_portfolios, NOT NULL | |
| `property_id` | UUID | FK → properties | |
| `estate_id` | UUID | FK → estates | |
| `purchase_price` | NUMERIC(15,2) | NOT NULL | |
| `current_market_value` | NUMERIC(15,2) | | Updated periodically |
| `ownership_percentage` | NUMERIC(5,2) | DEFAULT 100 | Fractional support |
| `purchase_date` | DATE | | |
| + audit fields | | | |

**Check:** `property_id IS NOT NULL OR estate_id IS NOT NULL`

---

### 13. `investment_returns`

**Purpose:** Periodic earnings per portfolio.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `portfolio_id` | UUID | FK → investment_portfolios, NOT NULL | |
| `period` | TEXT | NOT NULL | e.g. `2026-Q1` |
| `gross_return` | NUMERIC(15,2) | NOT NULL | |
| `net_return` | NUMERIC(15,2) | NOT NULL | |
| `expenses` | NUMERIC(15,2) | DEFAULT 0 | |
| `roi_percentage` | NUMERIC(8,4) | | |
| `generated_at` | TIMESTAMPTZ | DEFAULT now() | |

---

### 14. `investment_reports`

**Purpose:** Generated investor reports (PDF via media).

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | UUID | PK |
| `investor_id` | UUID | FK → investors, NOT NULL |
| `title` | TEXT | NOT NULL |
| `media_id` | UUID | FK → media |
| `report_period` | TEXT | |
| + audit fields | | |

---

## Referrals

### 15. `referrals`

**Purpose:** Client and investor referral program.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `referrer_id` | UUID | FK → users, NOT NULL | |
| `referred_user_id` | UUID | FK → users | Set on signup |
| `referred_lead_id` | UUID | FK → leads | Set before signup |
| `referral_code` | TEXT | NOT NULL | |
| `reward_amount` | NUMERIC(15,2) | DEFAULT 0 | |
| `status` | referral_status | DEFAULT `pending` | Enum |
| + audit fields | | | |

**Enum `referral_status`:** `pending`, `qualified`, `rewarded`, `rejected`

**Automation:** On referred user completes purchase → `status = rewarded`, credit referrer loyalty points.

---

## Support & Communication

### 16. `support_tickets`

**Purpose:** Unified helpdesk.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `ticket_number` | TEXT | UNIQUE, NOT NULL | Auto: `HD-T-00001` |
| `user_id` | UUID | FK → users, NOT NULL | |
| `category` | ticket_category | NOT NULL | Enum |
| `priority` | ticket_priority | DEFAULT `medium` | Enum |
| `subject` | TEXT | NOT NULL | |
| `status` | ticket_status | DEFAULT `open` | Enum |
| `assigned_to` | UUID | FK → users | |
| + audit fields | | | |

**Enum `ticket_category`:** `general`, `payment`, `property`, `technical`, `investment`, `complaint`

**Enum `ticket_priority`:** `low`, `medium`, `high`, `critical`

**Enum `ticket_status`:** `open`, `in_progress`, `waiting_customer`, `resolved`, `closed`

---

### 17. `ticket_messages`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | UUID | PK |
| `ticket_id` | UUID | FK → support_tickets, NOT NULL |
| `sender_id` | UUID | FK → users |
| `message` | TEXT | NOT NULL |
| `media_id` | UUID | FK → media |
| `is_internal` | BOOLEAN | DEFAULT false |
| `created_at` | TIMESTAMPTZ | DEFAULT now() |

**Realtime:** Subscribe to `ticket_messages` filtered by `ticket_id`.

---

### 18–21. Live Chat

#### `chat_rooms`

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `room_type` | TEXT | `support`, `sales`, `direct` |
| `subject` | TEXT | |
| `status` | TEXT | `active`, `closed` |
| + audit fields | | |

#### `chat_members`

| Column | Type | Notes |
|--------|------|-------|
| `room_id` | UUID | FK → chat_rooms |
| `user_id` | UUID | FK → users |
| `joined_at` | TIMESTAMPTZ | |
| `last_read_at` | TIMESTAMPTZ | |

**Unique:** `(room_id, user_id)`

#### `chat_messages`

| Column | Type | Notes |
|--------|------|-------|
| `room_id` | UUID | FK → chat_rooms |
| `sender_id` | UUID | FK → users |
| `message` | TEXT | |
| `created_at` | TIMESTAMPTZ | |

#### `chat_attachments`

| Column | Type | Notes |
|--------|------|-------|
| `message_id` | UUID | FK → chat_messages |
| `media_id` | UUID | FK → media |

**Realtime:** `chat_messages` channel per `room_id`. Supabase Realtime enabled.

---

### 22. `messages`

**Purpose:** Private 1:1 messaging (not room-based).

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `sender_id` | UUID | FK → users, NOT NULL | |
| `receiver_id` | UUID | FK → users, NOT NULL | |
| `message` | TEXT | NOT NULL | |
| `media_id` | UUID | FK → media | |
| `status` | message_status | DEFAULT `sent` | Enum |
| `sent_at` | TIMESTAMPTZ | DEFAULT now() | |
| `read_at` | TIMESTAMPTZ | | |

**Enum `message_status`:** `sent`, `delivered`, `read`

**Supports:** Client ↔ Sales, Investor ↔ Finance, Client ↔ Support, Admin ↔ Staff

**Indexes:** `idx_messages_sender`, `idx_messages_receiver_read (receiver_id, read_at)`

**Realtime:** Subscribe on `receiver_id = auth.uid()`.

---

## Engagement Tables

### 23. `inspection_bookings`

**Purpose:** Expanded inspection system (replaces basic `inspections`).

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `property_id` | UUID | FK → properties, NOT NULL | |
| `client_id` | UUID | FK → clients | |
| `lead_id` | UUID | FK → leads | Pre-client bookings |
| `sales_agent_id` | UUID | FK → users | |
| `inspection_type` | inspection_type | NOT NULL | Enum |
| `inspection_date` | DATE | NOT NULL | |
| `inspection_time` | TIME | NOT NULL | |
| `meeting_point` | TEXT | | |
| `status` | inspection_status | DEFAULT `pending` | From Part 2 |
| `feedback` | TEXT | | Post-inspection |
| + audit fields | | | |

**Enum `inspection_type`:** `physical`, `virtual`, `video_call`, `drone_tour`

**Links to:** `property_availability_calendar` (Part 2)

---

### 24. `property_reservations`

(Specified in Part 2 — referenced here for CRM journey.)

Enhanced columns per Part 3:

| Column | Type | Notes |
|--------|------|-------|
| `reservation_fee` | NUMERIC(15,2) | Renamed from reservation_amount |
| `expiration_date` | TIMESTAMPTZ | |
| `payment_status` | payment_status | Enum from Part 1 |
| `status` | reservation_status | Enum from Part 2 |

---

### 25. `wishlists`

**Purpose:** Saved properties (alias for `property_favorites` in Part 2).

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | UUID | PK |
| `user_id` | UUID | FK → users, NOT NULL |
| `property_id` | UUID | FK → properties, NOT NULL |
| `created_at` | TIMESTAMPTZ | DEFAULT now() |

**Unique:** `(user_id, property_id)`

---

### 26. `saved_searches`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `user_id` | UUID | FK → users, NOT NULL | |
| `search_name` | TEXT | NOT NULL | e.g. "3-bed Lekki" |
| `filters_json` | JSONB | NOT NULL | Full filter state |
| `notify_new_matches` | BOOLEAN | DEFAULT false | Email/push on match |
| + audit fields | | | |

---

### 27. `appointments`

**Purpose:** General staff meetings (broader than inspections).

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `user_id` | UUID | FK → users, NOT NULL | Client/investor |
| `staff_id` | UUID | FK → users, NOT NULL | |
| `lead_id` | UUID | FK → leads | |
| `appointment_type` | TEXT | | `consultation`, `signing`, `payment` |
| `location` | TEXT | | Physical address |
| `meeting_link` | TEXT | | Video call URL |
| `scheduled_at` | TIMESTAMPTZ | NOT NULL | |
| `status` | TEXT | DEFAULT `scheduled` | |
| + audit fields | | | |

---

### 28. `customer_feedback`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `user_id` | UUID | FK → users, NOT NULL | |
| `property_id` | UUID | FK → properties | |
| `rating` | INT | CHECK 1–5 | |
| `review` | TEXT | | |
| `visibility` | feedback_visibility | DEFAULT `private` | Enum |
| + audit fields | | | |

**Enum `feedback_visibility`:** `private`, `public`, `admin_only`

---

## CRM Operations

### 29. `crm_tasks`

**Purpose:** Sales team task queue.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `assigned_to` | UUID | FK → users, NOT NULL | |
| `lead_id` | UUID | FK → leads | |
| `client_id` | UUID | FK → clients | |
| `title` | TEXT | NOT NULL | |
| `task_type` | crm_task_type | | Enum |
| `priority` | task_priority | DEFAULT `normal` | Enum |
| `status` | task_status | DEFAULT `pending` | Enum |
| `due_date` | TIMESTAMPTZ | | |
| `completed_at` | TIMESTAMPTZ | | |
| + audit fields | | | |

**Enum `crm_task_type`:** `call_client`, `send_brochure`, `inspection`, `prepare_contract`, `follow_up`

**Enum `task_priority`:** `low`, `normal`, `high`, `urgent`

**Enum `task_status`:** `pending`, `in_progress`, `completed`, `cancelled`

---

### 30. `ai_customer_insights`

**Purpose:** AI-generated analytics per user.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `user_id` | UUID | FK → users, UNIQUE | |
| `purchase_probability` | NUMERIC(5,4) | | 0–1 |
| `investment_score` | NUMERIC(5,4) | | 0–1 |
| `engagement_score` | NUMERIC(5,4) | | 0–1 |
| `churn_risk` | NUMERIC(5,4) | | 0–1 |
| `lifetime_value_prediction` | NUMERIC(15,2) | | |
| `recommended_properties_json` | JSONB | DEFAULT `[]` | Array of property UUIDs |
| `generated_at` | TIMESTAMPTZ | | |
| + audit fields | | | |

**Updated by:** Nightly Edge Function or on significant CRM events.

---

## Enterprise Enhancement: Customer 360 Profile

### 31. `customer_360_profile` (VIEW)

**Purpose:** Single unified workspace for sales, finance, support, and management.

Instead of querying 15 tables, staff open one view:

```sql
CREATE VIEW customer_360_profile
WITH (security_invoker = true) AS
SELECT
  u.id AS user_id,
  u.email,
  u.first_name,
  u.last_name,
  c.id AS client_id,
  c.client_number,
  c.verification_status,
  c.loyalty_level,
  c.lifetime_value,
  i.id AS investor_id,
  i.investor_code,
  i.portfolio_value,
  ai.purchase_probability,
  ai.churn_risk,
  ai.recommended_properties_json
FROM users u
LEFT JOIN clients c ON c.user_id = u.id
LEFT JOIN investors i ON i.user_id = u.id
LEFT JOIN ai_customer_insights ai ON ai.user_id = u.id
WHERE u.is_deleted = false;
```

**Child data loaded on demand** (not in view — separate queries):

| Section | Source tables |
|---------|---------------|
| Personal details | `users`, `client_profiles` (Part 1) |
| KYC status | `clients.verification_status`, `client_documents` |
| Property ownership | `client_properties` |
| Payment history | `payments` (Finance module) |
| Investment portfolio | `investment_portfolios`, `investment_assets` |
| Reservations | `property_reservations` |
| Inspection history | `inspection_bookings` |
| Support tickets | `support_tickets` |
| Messages | `messages`, `chat_messages` |
| Documents | `client_documents` |
| Referral performance | `referrals` |
| AI insights | `ai_customer_insights` |
| Activity timeline | `client_timeline`, `lead_activities` |

**Flutter:** Admin CRM screen calls `customer_360_profile` + parallel fetches per section tab.

---

## CRM Dashboard Metrics

Computed via SQL views or Edge Functions (Part 6):

| Metric | Source |
|--------|--------|
| New Leads | `leads` WHERE `status = 'new'` AND date range |
| Active Leads | `leads` WHERE status NOT IN (`won`, `lost`, `dormant`) |
| Conversion Rate | `won` / total leads |
| Reservations | `property_reservations` count |
| Sales | `client_properties` WHERE `ownership_status = 'active'` |
| Revenue | `payments` SUM |
| ROI | `investment_returns` aggregate |
| Top Agents | `leads` GROUP BY `assigned_sales_agent` |
| Customer Satisfaction | `customer_feedback` AVG rating |
| Referral Growth | `referrals` COUNT by month |

---

## Relationship Overview

```text
Users
│
├── Leads → Lead Activities, Lead Status History
├── Clients → Properties, Documents, Timeline, Loyalty, Notes
├── Investors → Portfolios → Assets, Returns, Reports
├── Referrals (as referrer or referred)
├── Support Tickets → Ticket Messages
├── Chat Rooms → Chat Messages
├── Messages (1:1)
├── Notifications
├── Appointments
├── Wishlists
├── Saved Searches
└── AI Customer Insights

Clients
│
├── client_properties (ownership)
├── client_documents
├── client_timeline
├── inspection_bookings
├── property_reservations
├── customer_feedback
└── Payments (Finance module)

Investors
│
├── investment_portfolios
│       └── investment_assets
├── investment_returns
└── investment_reports
```

---

## Row-Level Security (RLS)

### Guest (unauthenticated)

No access to any private CRM table. Public website forms INSERT into `leads` and `property_inquiries` only.

### Clients

| Table | Access |
|-------|--------|
| Own profile | SELECT `clients` WHERE `user_id = auth.uid()` |
| Documents | SELECT own where `visibility IN ('client')` |
| Tickets | ALL own `support_tickets` |
| Messages | SELECT/INSERT where sender or receiver |
| Reservations, inspections | SELECT/INSERT own |
| Wishlists, saved searches | ALL own |
| Timeline | SELECT own |
| Notes | **No access** |
| AI insights | SELECT own (limited fields) |

### Investors

| Table | Access |
|-------|--------|
| Own investor record | SELECT |
| Portfolios, assets, returns, reports | SELECT own |
| Finance records | SELECT own payments only |

### Sales Team

| Table | Access |
|-------|--------|
| Leads | ALL where `assigned_sales_agent = auth.uid()` OR `crm.manage` |
| Clients | SELECT assigned; UPDATE limited fields |
| Lead activities, CRM tasks | ALL assigned |
| Finance records | **No access** |
| Client notes | SELECT/INSERT assigned clients |

### Finance Team

| Table | Access |
|-------|--------|
| Client payment records | SELECT |
| Client documents | SELECT where `visibility IN ('finance', 'admin')` |
| CRM notes | **No access** |
| Lead pipeline | **No access** |

### Support Team

| Table | Access |
|-------|--------|
| Tickets | ALL assigned or `status = 'open'` |
| Chat rooms | Members only |
| Client profile | SELECT basic (name, email) for assigned tickets |

### Marketing Team

| Table | Access |
|-------|--------|
| Referrals | SELECT aggregate |
| Feedback (public) | SELECT |
| Analytics views | SELECT |
| Individual CRM notes | **No access** |

### Admins

Full access via `permissions` table. Customer 360 view unrestricted for `crm.manage` + `user.read`.

---

## Automation & Business Rules

| Event | Automation |
|-------|-------------|
| Lead INSERT | Generate `lead_code`, score via rules, notify assigned agent |
| Lead status change | INSERT `lead_status_history` |
| User registration from lead | Link `leads.user_id`, update status |
| Lead won | Create `clients` row, set `converted_client_id` |
| Client created | Generate `client_number`, `referral_code`, welcome notification |
| Investor created | Generate `investor_code` |
| Inspection booked | Append `client_timeline`, block availability calendar |
| Reservation created | Set property status, append timeline |
| Reservation expired | Cron reverts property, notify client |
| Ticket overdue | Escalate priority, reassign |
| Lead inactive 90 days | Set `status = dormant` (configurable) |
| Referral purchase complete | Award `referral.reward_amount` |
| Document uploaded | Notify finance if KYC type |
| Nightly job | Refresh `ai_customer_insights` |

---

## Realtime Subscriptions

| Channel | Table | Filter |
|---------|-------|--------|
| Ticket updates | `ticket_messages` | `ticket_id = eq.{id}` |
| Live chat | `chat_messages` | `room_id = eq.{id}` |
| Private messages | `messages` | `receiver_id = eq.{uid}` |
| Notifications | `notifications` | `user_id = eq.{uid}` |
| Lead assignment | `leads` | `assigned_sales_agent = eq.{uid}` |

Enable Realtime on these tables in Supabase Dashboard or migration.

---

## API Contract (Flutter ↔ Supabase)

| Operation | Table / RPC |
|-----------|-------------|
| Submit website lead | `leads.insert()` |
| Get my client profile | `clients.select().eq('user_id', uid)` |
| Customer 360 (staff) | `customer_360_profile.select().eq('user_id', id)` |
| Book inspection | `inspection_bookings.insert()` |
| Reserve property | `property_reservations.insert()` |
| Save wishlist | `wishlists.upsert()` |
| Open support ticket | `support_tickets.insert()` + first `ticket_message` |
| Send private message | `messages.insert()` |
| Get AI insights | `ai_customer_insights.select().eq('user_id', uid)` |
| CRM dashboard | `rpc('crm_dashboard_metrics', {date_from, date_to})` |

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
| 7 | Add seed data | ⏳ Part 7 |
| 8 | Document API contracts | ✅ Above |
| 9 | Connect realtime subscriptions | ✅ Defined above |
| 10 | Wait for approval | **← Current step** |

---

## Gap Analysis: Live Schema vs Part 3 Target

| Part 3 Target | Live (Volume 1 Part 3) | Gap |
|---------------|------------------------|-----|
| `leads` with 20+ columns | `leads` with 10 columns | **Extend** — add lead_code, score, budget, etc. |
| `lead_status_history` | Missing | **New table** |
| `lead_activities` | `activities` (polymorphic) | **New dedicated table** or migrate |
| `clients` with loyalty, LTV | Basic `clients` | **Extend** columns |
| `client_properties` | Missing | **New table** |
| `client_documents` with media_id | `file_url` inline | **Migrate** to media FK |
| `client_notes` | `notes` (polymorphic) | **New dedicated table** |
| `client_timeline` | Missing | **New table** |
| `client_loyalty` | Missing | **New table** |
| `investors` extended | Basic `investors` | **Extend** columns |
| `investment_portfolios` as container | Direct property/estate FK | **Restructure** — add portfolio layer |
| `investment_assets` | Merged into portfolios | **New table** |
| `investment_returns` extended | Basic returns | **Extend** columns |
| `referrals` | Missing | **New table** |
| `support_tickets` | `tickets` | **Rename/extend** — add ticket_number, category |
| `ticket_messages` | Exists | **Extend** — add media_id |
| Live chat (rooms/members) | `chat_messages` only (1:1) | **New tables** |
| `messages` (1:1 private) | Partial via `chat_messages` | **New or consolidate** |
| `inspection_bookings` | `inspections` | **Extend/rename** |
| `property_reservations` | Missing | **New** (Part 2) |
| `wishlists` | Missing | **New** |
| `saved_searches` | Missing | **New table** |
| `appointments` | Exists | **Extend** — add meeting_link, types |
| `customer_feedback` | Missing | **New table** |
| `crm_tasks` | `tasks` (generic) | **Extend/rename** |
| `ai_customer_insights` | Missing | **New table** |
| `customer_360_profile` VIEW | Missing | **New view** |
| `client_profiles` on users (Part 1) | `client_profiles` on clients | **Align** FK to users |

---

## Seed Data (Part 3 scope)

| Data | Notes |
|------|-------|
| Sample lead sources | Enum values only |
| Loyalty level benefits | JSON in `settings.loyalty_config` |
| Ticket categories | Enum values |
| CRM task types | Enum values |
| Notification templates | Part 7 |

---

**End of Volume 1.5 – Part 3**

*Awaiting your approval before migration work or Part 4.*
