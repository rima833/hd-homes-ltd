# Volume 1.5 – Part 2

# Property & Estate Database Architecture

**Status:** Draft — awaiting approval before any migration work.

**Depends on:** [Part 1 – Database Philosophy & Core Schema](./part-01-philosophy-and-core-schema.md)

---

## Module Overview

The Property & Estate Module is the foundation of the HD Homes business.

It powers:

| Consumer | Capability |
|----------|------------|
| Public Website | Property listings, estate pages, search, comparison |
| Client Dashboard | Saved properties, reservations, inspections, payment plans |
| Investor Portal | Portfolio-linked properties, ROI analytics |
| CRM | Inquiries, lead conversion, inspection booking |
| Finance | Installment plans, pricing history |
| Construction | Progress updates tied to estates/phases |
| Reports & AI | Engagement scores, recommendations, search indexes |

The database must support **thousands of estates** and **millions of property records**.

---

## Business Hierarchy

```text
HD Homes
│
├── Estates
│      │
│      ├── Phases
│      │      │
│      │      ├── Blocks
│      │      │      │
│      │      │      └── Plots / Units  (→ properties)
│      │      │
│      │      └── Shared Facilities
│
└── Standalone Properties  (estate_id = NULL)
```

Standalone properties have no `estate_id`. Estate properties inherit location context from the estate but maintain their own geo coordinates.

---

## Lifecycles

### Property Lifecycle

```text
draft → pending_review → published → reserved → under_offer → sold → archived
```

Every status transition is recorded in `property_status_history` and logged to `audit_logs`.

### Estate Lifecycle

```text
planning → infrastructure_development → phase_1_sales → phase_2_sales
         → construction → handover → completed
```

Enum: `estate_status`

---

## Table Catalog

Part 2 defines **28 tables** in this module (including junction and history tables).

| # | Table | Purpose |
|---|-------|---------|
| 1 | `property_categories` | Top-level property groupings |
| 2 | `property_types` | Specific property types per category |
| 3 | `estates` | Estate developments |
| 4 | `estate_phases` | Multi-phase developments |
| 5 | `blocks` | Optional sub-division within phases |
| 6 | `properties` | Central business entity |
| 7 | `property_features` | Feature catalog (global) |
| 8 | `property_feature_assignments` | Property ↔ feature M2M |
| 9 | `property_amenities` | Nearby amenities with distance |
| 10 | `property_images` | Image gallery via media FK |
| 11 | `property_videos` | Videos and virtual tours |
| 12 | `property_documents` | Brochures, plans, contracts |
| 13 | `property_payment_plans` | Installment plan definitions |
| 14 | `payment_plan_installments` | Installment schedule rows |
| 15 | `property_pricing_history` | Immutable price change log |
| 16 | `property_status_history` | Immutable status change log |
| 17 | `property_favorites` | User saved properties |
| 18 | `property_comparisons` | User comparison lists |
| 19 | `property_view_history` | Engagement tracking |
| 20 | `property_inquiries` | Inquiry → CRM lead source |
| 21 | `property_inspections` | Inspection bookings |
| 22 | `property_reservations` | Temporary holds |
| 23 | `property_tags` | Tag catalog |
| 24 | `property_tag_assignments` | Property ↔ tag M2M |
| 25 | `property_recommendation_scores` | AI/recommendation metadata |
| 26 | `estate_amenities` | Estate-level shared facilities |
| 27 | `estate_images` | Estate gallery via media FK |
| 28 | `property_availability_calendar` | Unified availability (enhancement) |

> All tables include Part 1 audit fields unless noted append-only.

---

## 1. `property_categories`

**Purpose:** Groups properties into high-level categories for navigation and filtering.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `name` | TEXT | NOT NULL | e.g. Residential |
| `slug` | TEXT | NOT NULL, UNIQUE | e.g. `residential` |
| `description` | TEXT | | |
| `icon` | TEXT | | Lucide icon name or media_id |
| `display_order` | INT | DEFAULT 0 | |
| + audit fields | | | |

**Seed examples:** Residential, Commercial, Industrial, Mixed Use, Agricultural, Luxury, Affordable Housing

**Indexes:** `idx_property_categories_slug`, `idx_property_categories_display_order`

**RLS:** Public SELECT; staff with `property.edit` for ALL.

---

## 2. `property_types`

**Purpose:** Specific property types linked to a category.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `category_id` | UUID | FK → property_categories | |
| `name` | TEXT | NOT NULL | e.g. Duplex |
| `slug` | TEXT | NOT NULL, UNIQUE | |
| `description` | TEXT | | |
| + audit fields | | | |

**Seed examples:** Land, Apartment, Duplex, Detached House, Semi Detached, Terrace House, Bungalow, Office, Warehouse, Retail Shop, Hotel, Factory, Penthouse, Villa

**Indexes:** `idx_property_types_category_id`, `idx_property_types_slug`

---

## 3. `estates`

**Purpose:** Stores every estate development.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `name` | TEXT | NOT NULL | |
| `slug` | TEXT | NOT NULL, UNIQUE | URL slug |
| `description` | TEXT | | Full HTML/JSONB content |
| `estate_code` | TEXT | UNIQUE | e.g. `HD-E-001` |
| `developer_name` | TEXT | DEFAULT `'HD Homes Limited'` | |
| `location` | TEXT | | Street/area |
| `state` | TEXT | | |
| `city` | TEXT | | |
| `country` | TEXT | DEFAULT `'Nigeria'` | |
| `latitude` | DOUBLE PRECISION | | |
| `longitude` | DOUBLE PRECISION | | |
| `geohash` | TEXT | | For proximity search |
| `masterplan_media_id` | UUID | FK → media | |
| `cover_image_media_id` | UUID | FK → media | |
| `logo_media_id` | UUID | FK → media | |
| `status` | estate_status | DEFAULT `planning` | Enum |
| `launch_date` | DATE | | |
| `completion_date` | DATE | | |
| + audit fields | | | |

**Relationships:**

```text
estates 1──N estate_phases
estates 1──N properties
estates 1──N estate_amenities
estates 1──N estate_images
estates 1──N projects (construction module)
```

**Indexes:** `idx_estates_slug`, `idx_estates_status`, `idx_estates_city_state (city, state)`, `idx_estates_geohash`

**RLS:** Public SELECT where `status` IN (`phase_1_sales`, `phase_2_sales`, `construction`, `handover`, `completed`) AND `is_deleted = false`; staff with `property.edit`.

---

## 4. `estate_phases`

**Purpose:** Multi-phase developments within an estate.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `estate_id` | UUID | FK → estates, NOT NULL | |
| `phase_name` | TEXT | NOT NULL | e.g. Phase 1 |
| `phase_number` | INT | | 1, 2, 3… |
| `launch_date` | DATE | | |
| `expected_completion` | DATE | | |
| `status` | estate_phase_status | DEFAULT `planning` | |
| + audit fields | | | |

**Indexes:** `idx_estate_phases_estate_id`, `idx_estate_phases_status`

---

## 5. `blocks`

**Purpose:** Optional sub-division within a phase for large developments.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `phase_id` | UUID | FK → estate_phases, NOT NULL | |
| `block_name` | TEXT | NOT NULL | e.g. Block A |
| `description` | TEXT | | |
| `status` | TEXT | DEFAULT `active` | |
| + audit fields | | | |

**Indexes:** `idx_blocks_phase_id`

---

## 6. `properties`

**Purpose:** Central business table. Every plot, unit, or standalone listing.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `property_code` | TEXT | UNIQUE, NOT NULL | Auto-generated e.g. `HD-P-00001` |
| `slug` | TEXT | UNIQUE, NOT NULL | URL slug |
| `title` | TEXT | NOT NULL | |
| `short_description` | TEXT | | Card/listing summary |
| `full_description` | TEXT | | Detail page content |
| `estate_id` | UUID | FK → estates | NULL = standalone |
| `phase_id` | UUID | FK → estate_phases | |
| `block_id` | UUID | FK → blocks | |
| `category_id` | UUID | FK → property_categories | |
| `type_id` | UUID | FK → property_types | |
| `price` | NUMERIC(15,2) | NOT NULL | Current price |
| `currency` | TEXT | DEFAULT `'NGN'` | |
| `bedrooms` | INT | | |
| `bathrooms` | INT | | |
| `toilets` | INT | | |
| `parking_spaces` | INT | | |
| `land_size` | NUMERIC(12,2) | | sqm |
| `building_size` | NUMERIC(12,2) | | sqm |
| `floors` | INT | | |
| `year_built` | INT | | |
| `latitude` | DOUBLE PRECISION | | |
| `longitude` | DOUBLE PRECISION | | |
| `geohash` | TEXT | | Proximity/clustering |
| `address` | TEXT | | |
| `status` | property_status | DEFAULT `draft` | Enum |
| `featured` | BOOLEAN | DEFAULT false | |
| `exclusive_listing` | BOOLEAN | DEFAULT false | |
| `available_for_installment` | BOOLEAN | DEFAULT false | |
| `featured_until` | TIMESTAMPTZ | | Auto-expire featured |
| `published_at` | TIMESTAMPTZ | | |
| `search_vector` | TSVECTOR | | Full-text search (generated) |
| + audit fields | | | |

**Relationships:**

```text
properties 1──N property_images
properties 1──N property_videos
properties 1──N property_documents
properties N──M property_features (via assignments)
properties 1──N property_amenities
properties 1──N property_payment_plans
properties 1──N property_pricing_history
properties 1──N property_status_history
properties 1──N property_favorites
properties 1──N property_comparisons
properties 1──N property_view_history
properties 1──N property_inquiries
properties 1──N property_inspections
properties 1──N property_reservations
properties N──M property_tags (via assignments)
properties 1──1 property_recommendation_scores
```

**Indexes:**

```sql
CREATE UNIQUE INDEX idx_properties_slug ON properties (slug);
CREATE UNIQUE INDEX idx_properties_code ON properties (property_code);
CREATE INDEX idx_properties_estate_status ON properties (estate_id, status);
CREATE INDEX idx_properties_city_price ON properties (city, price);  -- via denormalized or join
CREATE INDEX idx_properties_status_featured ON properties (status, featured);
CREATE INDEX idx_properties_type_price ON properties (type_id, price);
CREATE INDEX idx_properties_published ON properties (published_at DESC) WHERE status = 'published';
CREATE INDEX idx_properties_geohash ON properties (geohash);
CREATE INDEX idx_properties_search ON properties USING GIN (search_vector);
```

**RLS:** See [Row-Level Security](#row-level-security-rls) section below.

---

## 7. `property_features` (catalog)

**Purpose:** Global reusable feature catalog. Not per-property inline strings.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `name` | TEXT | NOT NULL, UNIQUE | e.g. Swimming Pool |
| `icon` | TEXT | | |
| `category` | TEXT | | `interior`, `exterior`, `security`, `smart` |
| + audit fields | | | |

**Seed examples:** Swimming Pool, Gym, Elevator, Cinema, Walk-in Closet, Generator, Smart Home, Solar System, CCTV, Fiber Internet, Private Garden, Water Treatment

---

## 8. `property_feature_assignments`

**Purpose:** Many-to-many property ↔ feature.

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | UUID | PK |
| `property_id` | UUID | FK → properties, NOT NULL |
| `feature_id` | UUID | FK → property_features, NOT NULL |
| + audit fields | | |

**Unique:** `(property_id, feature_id)`

---

## 9. `property_amenities`

**Purpose:** Nearby points of interest with distance data.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `property_id` | UUID | FK → properties, NOT NULL | |
| `name` | TEXT | NOT NULL | e.g. School |
| `amenity_type` | TEXT | | `education`, `health`, `retail`, … |
| `distance_km` | NUMERIC(8,2) | | |
| `travel_time_minutes` | INT | | |
| `maps_url` | TEXT | | Google Maps link |
| `latitude` | DOUBLE PRECISION | | |
| `longitude` | DOUBLE PRECISION | | |
| + audit fields | | | |

**Examples:** School, Hospital, Shopping Mall, Police Station, Airport, Church, Mosque, Bank, Fuel Station, Bus Stop, Recreation Park

---

## 10. `property_images`

**Purpose:** Unlimited image gallery. Never store URLs on `properties` directly.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `property_id` | UUID | FK → properties, NOT NULL | |
| `media_id` | UUID | FK → media, NOT NULL | |
| `caption` | TEXT | | |
| `display_order` | INT | DEFAULT 0 | |
| `is_cover` | BOOLEAN | DEFAULT false | One per property |
| + audit fields | | | |

**Constraint:** Partial unique index — one `is_cover = true` per property.

**Storage bucket:** `property-images`

---

## 11. `property_videos`

**Purpose:** YouTube, Vimeo, uploaded, drone, 360° tours.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `property_id` | UUID | FK → properties, NOT NULL | |
| `media_id` | UUID | FK → media | NULL for external embeds |
| `video_url` | TEXT | | YouTube/Vimeo URL |
| `video_type` | video_type | NOT NULL | Enum |
| `title` | TEXT | | |
| `display_order` | INT | DEFAULT 0 | |
| + audit fields | | | |

**Enum `video_type`:** `uploaded`, `youtube`, `vimeo`, `drone`, `tour_360`

---

## 12. `property_documents`

**Purpose:** Brochures, floor plans, survey plans, title docs, contracts.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `property_id` | UUID | FK → properties, NOT NULL | |
| `document_type` | document_type | NOT NULL | Enum |
| `media_id` | UUID | FK → media, NOT NULL | |
| `visibility` | document_visibility | DEFAULT `admin` | Enum |
| `title` | TEXT | | |
| + audit fields | | | |

**Enum `document_type`:** `brochure`, `floor_plan`, `survey_plan`, `allocation_letter`, `title_document`, `price_list`, `contract`

**Enum `document_visibility`:** `public`, `client`, `investor`, `admin`

---

## 13. `property_payment_plans`

**Purpose:** Installment sales configuration per property.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `property_id` | UUID | FK → properties, NOT NULL | |
| `plan_name` | TEXT | NOT NULL | e.g. 12-Month Plan |
| `minimum_deposit` | NUMERIC(15,2) | | Absolute amount |
| `minimum_deposit_percent` | NUMERIC(5,2) | | Alternative to absolute |
| `duration_months` | INT | NOT NULL | |
| `interest_rate` | NUMERIC(5,2) | DEFAULT 0 | Annual % |
| `processing_fee` | NUMERIC(15,2) | DEFAULT 0 | |
| `status` | TEXT | DEFAULT `active` | |
| + audit fields | | | |

**RLS:** Public SELECT; `payment.approve` / finance role for write.

---

## 14. `payment_plan_installments`

**Purpose:** Schedule rows within a payment plan.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `payment_plan_id` | UUID | FK → property_payment_plans, NOT NULL | |
| `installment_number` | INT | NOT NULL | 1, 2, 3… |
| `percentage` | NUMERIC(5,2) | | % of remaining balance |
| `due_days` | INT | NOT NULL | Days from reservation/purchase |
| + audit fields | | | |

**Unique:** `(payment_plan_id, installment_number)`

---

## 15. `property_pricing_history`

**Purpose:** Immutable price change log. Never overwrite.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `property_id` | UUID | FK → properties, NOT NULL | |
| `old_price` | NUMERIC(15,2) | NOT NULL | |
| `new_price` | NUMERIC(15,2) | NOT NULL | |
| `currency` | TEXT | DEFAULT `'NGN'` | |
| `changed_by` | UUID | FK → users | |
| `reason` | TEXT | | |
| `created_at` | TIMESTAMPTZ | DEFAULT now() | Append-only |

**Trigger:** On `properties.price` UPDATE → INSERT row here automatically.

**RLS:** SELECT by finance/admin; no UPDATE/DELETE.

---

## 16. `property_status_history`

**Purpose:** Immutable status transition log.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `property_id` | UUID | FK → properties, NOT NULL | |
| `old_status` | property_status | | NULL on first publish |
| `new_status` | property_status | NOT NULL | |
| `changed_by` | UUID | FK → users | |
| `reason` | TEXT | | |
| `created_at` | TIMESTAMPTZ | DEFAULT now() | Append-only |

**Trigger:** On `properties.status` UPDATE → INSERT row + `audit_logs` entry.

---

## 17. `property_favorites`

**Purpose:** User saved properties (client dashboard).

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | UUID | PK |
| `user_id` | UUID | FK → users, NOT NULL |
| `property_id` | UUID | FK → properties, NOT NULL |
| `created_at` | TIMESTAMPTZ | DEFAULT now() |

**Unique:** `(user_id, property_id)`

**RLS:** Users manage own rows only.

---

## 18. `property_comparisons`

**Purpose:** Side-by-side property comparison (max 4 per session).

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | UUID | PK |
| `user_id` | UUID | FK → users, NOT NULL |
| `property_id` | UUID | FK → properties, NOT NULL |
| `created_at` | TIMESTAMPTZ | DEFAULT now() |

**Unique:** `(user_id, property_id)`

**Business rule:** Max 4 properties per user — enforced via Edge Function or DB constraint.

---

## 19. `property_view_history`

**Purpose:** Engagement tracking for analytics and AI scores.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `property_id` | UUID | FK → properties, NOT NULL | |
| `user_id` | UUID | FK → users | NULL = anonymous |
| `session_id` | TEXT | | Anonymous tracking |
| `device` | TEXT | | `mobile`, `tablet`, `desktop` |
| `browser` | TEXT | | |
| `ip_address` | INET | | |
| `viewed_at` | TIMESTAMPTZ | DEFAULT now() | |

**Indexes:** `idx_view_history_property`, `idx_view_history_user_viewed (user_id, viewed_at DESC)`

**RLS:** INSERT by anyone; SELECT own history or staff with `reports.view`.

---

## 20. `property_inquiries`

**Purpose:** Every inquiry becomes a CRM lead.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `property_id` | UUID | FK → properties, NOT NULL | |
| `user_id` | UUID | FK → users | NULL if guest |
| `full_name` | TEXT | NOT NULL | |
| `phone` | TEXT | | |
| `email` | TEXT | | |
| `message` | TEXT | | |
| `lead_status` | lead_status | DEFAULT `new` | Enum |
| `assigned_to` | UUID | FK → users | Sales agent |
| `lead_id` | UUID | FK → leads | Created on conversion |
| + audit fields | | | |

**Automation:** INSERT trigger → create `leads` row if not exists.

---

## 21. `property_inspections`

**Purpose:** Online inspection booking.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `property_id` | UUID | FK → properties, NOT NULL | |
| `client_id` | UUID | FK → clients | |
| `sales_agent_id` | UUID | FK → users | |
| `inspection_date` | DATE | NOT NULL | |
| `inspection_time` | TIME | NOT NULL | |
| `status` | inspection_status | DEFAULT `pending` | Enum |
| `notes` | TEXT | | |
| + audit fields | | | |

**Enum `inspection_status`:** `pending`, `confirmed`, `completed`, `cancelled`, `no_show`

**RLS:** Client sees own; sales agent sees assigned; staff with `crm.manage`.

---

## 22. `property_reservations`

**Purpose:** Temporary property holds with expiry.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | UUID | PK | |
| `property_id` | UUID | FK → properties, NOT NULL | |
| `client_id` | UUID | FK → clients, NOT NULL | |
| `reservation_amount` | NUMERIC(15,2) | NOT NULL | Deposit paid |
| `expires_at` | TIMESTAMPTZ | NOT NULL | |
| `status` | reservation_status | DEFAULT `active` | Enum |
| + audit fields | | | |

**Enum `reservation_status`:** `active`, `expired`, `converted`, `cancelled`

**Automation:** Cron/Edge Function archives expired reservations → property status reverts from `reserved`.

---

## 23. `property_tags` + 24. `property_tag_assignments`

**Tags catalog:**

| Column | Type |
|--------|------|
| `id` | UUID PK |
| `name` | TEXT UNIQUE |
| `slug` | TEXT UNIQUE |
| `color` | TEXT |
| + audit fields | |

**Seed examples:** Luxury, Waterfront, Investment, Family, Commercial, Affordable, New Listing, Hot Deal

**Assignments:** `(property_id, tag_id)` unique pair.

---

## 25. `property_recommendation_scores`

**Purpose:** AI and analytics metadata per property.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `property_id` | UUID | PK, FK → properties | 1:1 |
| `recommendation_score` | NUMERIC(5,4) | DEFAULT 0 | 0.0000–1.0000 |
| `popularity_score` | NUMERIC(5,4) | DEFAULT 0 | View/favorite weighted |
| `investment_score` | NUMERIC(5,4) | DEFAULT 0 | ROI potential |
| `engagement_score` | NUMERIC(5,4) | DEFAULT 0 | Inquiry/conversion rate |
| `last_calculated_at` | TIMESTAMPTZ | | |
| + audit fields | | | |

**Updated by:** Scheduled Edge Function (nightly) or on significant events.

---

## 26. `estate_amenities`

**Purpose:** Shared facilities at estate level (not per-property).

| Column | Type | Notes |
|--------|------|-------|
| `estate_id` | UUID FK | |
| `name` | TEXT | e.g. Clubhouse, Tennis Court |
| `description` | TEXT | |
| `media_id` | UUID FK | Optional image |

---

## 27. `estate_images`

Same pattern as `property_images` but `estate_id` FK. Storage bucket: `estate-images`.

---

## 28. `property_availability_calendar` (Enterprise Enhancement)

**Purpose:** Single source of truth for availability across website, sales, client, and investor portals.

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `property_id` | UUID | FK → properties |
| `event_type` | availability_event_type | Enum |
| `starts_at` | TIMESTAMPTZ | NOT NULL |
| `ends_at` | TIMESTAMPTZ | NOT NULL |
| `reference_id` | UUID | FK to inspection/reservation/maintenance |
| `reference_type` | TEXT | `inspection`, `reservation`, `maintenance`, `construction` |
| `is_blocking` | BOOLEAN | Blocks new bookings if true |
| `notes` | TEXT | |
| + audit fields | | |

**Enum `availability_event_type`:** `inspection`, `reservation`, `maintenance`, `construction`, `handover`, `blocked`

**Prevents:** Double-booked inspections, overlapping reservations, sales conflicts during construction.

---

## Smart Search Index

### Filterable dimensions

| Dimension | Source |
|-----------|--------|
| Location | `properties.latitude/longitude`, `address`, estate city/state |
| Price | `properties.price` |
| Bedrooms / Bathrooms | `properties.bedrooms`, `bathrooms` |
| Estate | `properties.estate_id` |
| Status | `properties.status` |
| Category / Type | `category_id`, `type_id` |
| Amenities | `property_amenities` |
| Features | `property_feature_assignments` |
| Tags | `property_tag_assignments` |
| Completion | `estates.status`, `projects.completion_percent` |
| Investment ROI | `property_recommendation_scores.investment_score` |
| Keywords | `properties.search_vector` (GIN) |

### Search RPC (planned)

```sql
-- search_properties(query, filters JSONB) → SETOF properties
-- Uses tsvector + PostGIS radius when lat/lng provided
```

---

## Map & Geospatial Data

Every property and estate stores:

| Field | Purpose |
|-------|---------|
| `latitude` | Map pin |
| `longitude` | Map pin |
| `geohash` | Prefix search, clustering |

**Future:** PostGIS extension for `ST_DWithin` radius queries and commute distance.

**Flutter:** Google Maps clustering via geohash buckets.

---

## Row-Level Security (RLS)

### Public (unauthenticated)

| Table | Access |
|-------|--------|
| `properties` | SELECT where `status = 'published'` AND `is_deleted = false` |
| `estates` | SELECT where estate is in active sales/construction phase |
| `property_images`, `property_videos` | SELECT for published properties |
| `property_documents` | SELECT where `visibility = 'public'` |
| `property_categories`, `property_types` | SELECT all active |
| `property_payment_plans` | SELECT where property is published |

### Clients (authenticated, role: client)

| Table | Access |
|-------|--------|
| Published properties | SELECT (same as public) |
| `property_favorites` | ALL own rows |
| `property_comparisons` | ALL own rows |
| `property_reservations` | SELECT/INSERT own |
| `property_inspections` | SELECT/INSERT own |
| `property_view_history` | INSERT; SELECT own |
| `property_documents` | SELECT where `visibility IN ('public', 'client')` |

### Sales Team

| Table | Access |
|-------|--------|
| Properties | ALL where assigned OR `property.create` permission |
| `property_inquiries` | ALL assigned inquiries |
| `property_inspections` | ALL assigned inspections |
| Pricing | SELECT only (no write) |

### Marketing Team

| Table | Access |
|-------|--------|
| Properties | UPDATE description, images, videos, featured fields only |
| Pricing | No access |
| Delete | No access |

### Finance Team

| Table | Access |
|-------|--------|
| `properties.price` | UPDATE |
| `property_payment_plans` | ALL |
| `property_pricing_history` | SELECT |
| Delete properties | No access |

### Construction Managers

| Table | Access |
|-------|--------|
| Estate/project progress | UPDATE |
| Property availability | UPDATE via calendar |
| Financial fields | No access |

### Admins

Full access based on `permissions` table. Super Admin bypasses all checks.

---

## Automation & Business Rules

| Trigger / Job | Action |
|---------------|--------|
| `BEFORE INSERT properties` | Generate `property_code`, `slug` if empty |
| `AFTER UPDATE properties.price` | Insert `property_pricing_history` |
| `AFTER UPDATE properties.status` | Insert `property_status_history` + notify followers |
| `AFTER INSERT property_images` | Queue image resize/optimize (Edge Function) |
| `AFTER INSERT property_reservations` | Set property `status = 'reserved'` |
| Cron: expired reservations | Set `status = 'expired'`, revert property status |
| Cron: nightly | Recalculate `property_recommendation_scores` |
| `AFTER property change` | Refresh `search_vector` |
| Inquiry INSERT | Create CRM `leads` row |

---

## API Contract (Flutter ↔ Supabase)

| Operation | Method | Table/RPC |
|-----------|--------|-----------|
| List published properties | `.from('properties').select('*, property_images(*)')` | Filter `status=eq.published` |
| Property detail | `.select('*, ...')` | By slug |
| Search | `.rpc('search_properties', {query, filters})` | RPC |
| Save favorite | `.from('property_favorites').upsert()` | |
| Book inspection | `.from('property_inspections').insert()` | |
| Reserve property | `.from('property_reservations').insert()` | |
| Price history | `.from('property_pricing_history').select()` | Finance only |
| Nearby properties | `.rpc('properties_nearby', {lat, lng, radius_km})` | PostGIS future |

---

## Cursor Implementation Checklist

| Step | Action | Status |
|------|--------|--------|
| 1 | Explain business purpose | ✅ This document |
| 2 | Define relationships | ✅ ERD below |
| 3 | Create PostgreSQL schema | ⏳ Awaiting approval |
| 4 | Add indexes | ✅ Defined above |
| 5 | Add foreign keys | ✅ Defined above |
| 6 | Enable RLS | ✅ Policy model defined |
| 7 | Create Supabase migration | ⏳ Awaiting approval |
| 8 | Add seed data | ⏳ Part 6 |
| 9 | Document API contract | ✅ Above |
| 10 | Wait for approval | **← Current step** |

---

## Relationship Overview

```text
Estate
│
├── Estate Phases
│       └── Blocks
│               └── Properties
├── Estate Amenities
├── Estate Images
└── Construction Updates (→ projects module)

Property
│
├── Images          (→ media)
├── Videos          (→ media / embed URL)
├── Documents       (→ media)
├── Feature Assignments
├── Amenities
├── Payment Plans
│       └── Installments
├── Pricing History
├── Status History
├── Favorites
├── Comparisons
├── View History
├── Inquiries       (→ leads)
├── Inspections
├── Reservations
├── Tags
├── Recommendation Scores
└── Availability Calendar
```

---

## Gap Analysis: Live Schema vs Part 2 Target

| Part 2 Target | Live (Volume 1 Part 3) | Gap |
|---------------|------------------------|-----|
| `properties` with 30+ columns | `properties` with 12 columns | Add bedrooms, price inline, geohash, property_code, etc. |
| `property_pricing` separate 1:1 | Exists | Merge price onto `properties` OR keep separate — **decision needed** |
| `property_locations` separate 1:1 | Exists | Merge lat/lng onto `properties` |
| `blocks` table | Missing | **New table** |
| `property_features` as catalog + assignments | Inline `feature` TEXT per row | **Restructure** to catalog + M2M |
| `property_amenities` with distance/maps | Inline `amenity` TEXT | **Extend** columns |
| `payment_plan_installments` | Missing | **New table** |
| `property_pricing_history` | Missing | **New table** |
| `property_status_history` | Missing | **New table** |
| `property_favorites` | Missing | **New table** |
| `property_comparisons` | Missing | **New table** |
| `property_view_history` | `property_views` (partial) | **Extend** with device/browser |
| `property_inquiries` | `leads` only (no property inquiry table) | **New table** or extend leads |
| `property_inspections` | `inspections` in CRM module | **Align** naming and columns |
| `property_reservations` | Missing | **New table** |
| `property_tags` + assignments | Missing | **New tables** |
| `property_recommendation_scores` | Missing | **New table** |
| `property_availability_calendar` | Missing | **New table** (enhancement) |
| `media_id` on images/videos/docs | Inline `url` TEXT | **Migrate** to media FK |
| `estates` with geo, media, estate_code | Basic estates | **Extend** columns |
| ENUM lifecycles | TEXT `status` / `is_published` | **Add ENUMs** |
| Full-text `search_vector` | Missing | **Add** GIN index |
| `geohash` | Missing | **Add** column + index |

**Migration approach:** Incremental alignment migrations. No data loss. Existing URLs migrated to `media` records in a dedicated migration.

---

## Seed Data (Part 2 scope)

| Data | Count |
|------|-------|
| Property categories | 7 |
| Property types | 14 |
| Property features (catalog) | 12 |
| Property tags | 8 |
| Sample estate | 1 (HD Homes pilot estate) |
| Sample properties | 3 (draft, for dev only) |

---

## Enterprise Enhancement: Property Availability Calendar

A unified `property_availability_calendar` prevents scheduling conflicts across:

- Public inspection booking widget
- Sales team calendar
- Client portal "my inspections"
- Construction blackout dates
- Maintenance windows

This is included as table #28 above and should be implemented alongside `property_inspections` and `property_reservations`.

---

**End of Volume 1.5 – Part 2**

*Awaiting your approval before migration work or Part 3.*
