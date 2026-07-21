-- Volume 4 Part 2 — Enterprise Property Management System (PMS)
-- Extends Volume 2 property foundation. DO NOT apply remotely until user says approve.

BEGIN;

INSERT INTO public.permissions (slug, name, description, module) VALUES
  ('properties.read', 'View Properties', 'View PMS inventory and listings', 'properties'),
  ('properties.write', 'Manage Properties', 'Create and edit properties', 'properties'),
  ('properties.approve', 'Approve Properties', 'Approve listing publish workflow', 'properties'),
  ('properties.media', 'Manage Property Media', 'Upload and organize property media', 'properties'),
  ('properties.documents', 'Manage Property Documents', 'Manage legal and property documents', 'properties'),
  ('properties.pricing', 'Manage Property Pricing', 'Update prices and installment plans', 'properties'),
  ('properties.inspections', 'Manage Inspections', 'Schedule and report property inspections', 'properties'),
  ('properties.ownership', 'Manage Ownership', 'Track ownership history and transfers', 'properties'),
  ('properties.analytics', 'View Property Analytics', 'View inventory analytics and scores', 'properties'),
  ('properties.bulk', 'Bulk Property Operations', 'Bulk edit, publish, and export', 'properties'),
  ('properties.ai', 'AI Property Assistant', 'Use AI summaries and recommendations', 'properties')
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  module = EXCLUDED.module,
  updated_at = now();

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE p.slug LIKE 'properties.%'
  AND (
    r.slug IN ('super_admin', 'admin')
    OR (r.slug = 'sales_team' AND p.slug IN (
      'properties.read','properties.write','properties.approve','properties.media',
      'properties.pricing','properties.inspections','properties.analytics','properties.ai','properties.bulk'
    ))
    OR (r.slug = 'finance' AND p.slug IN (
      'properties.read','properties.pricing','properties.analytics','properties.ownership'
    ))
    OR (r.slug = 'construction_manager' AND p.slug IN (
      'properties.read','properties.write','properties.inspections','properties.analytics'
    ))
    OR (r.slug = 'marketing' AND p.slug IN (
      'properties.read','properties.media','properties.analytics','properties.ai'
    ))
    OR (r.slug IN ('client', 'investor') AND p.slug = 'properties.read')
  )
ON CONFLICT DO NOTHING;

-- Align Volume 2 foundation tables with PMS hierarchy columns
ALTER TABLE public.estates
  ADD COLUMN IF NOT EXISTS tagline text,
  ADD COLUMN IF NOT EXISTS city text,
  ADD COLUMN IF NOT EXISTS state text,
  ADD COLUMN IF NOT EXISTS country text DEFAULT 'Nigeria',
  ADD COLUMN IF NOT EXISTS is_featured boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS published_at timestamptz;

ALTER TABLE public.estate_phases
  ADD COLUMN IF NOT EXISTS code text,
  ADD COLUMN IF NOT EXISTS sort_order int NOT NULL DEFAULT 0;

ALTER TABLE public.property_types
  ADD COLUMN IF NOT EXISTS sort_order int NOT NULL DEFAULT 0;

CREATE UNIQUE INDEX IF NOT EXISTS idx_estate_phases_estate_name
  ON public.estate_phases (estate_id, name)
  WHERE COALESCE(is_deleted, false) = false;

CREATE TABLE IF NOT EXISTS public.estate_blocks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  estate_id uuid NOT NULL REFERENCES public.estates(id) ON DELETE CASCADE,
  phase_id uuid REFERENCES public.estate_phases(id) ON DELETE SET NULL,
  name text NOT NULL,
  code text,
  sort_order int NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (estate_id, name)
);

CREATE TABLE IF NOT EXISTS public.estate_buildings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  estate_id uuid NOT NULL REFERENCES public.estates(id) ON DELETE CASCADE,
  block_id uuid REFERENCES public.estate_blocks(id) ON DELETE SET NULL,
  phase_id uuid REFERENCES public.estate_phases(id) ON DELETE SET NULL,
  name text NOT NULL,
  code text,
  floors int,
  sort_order int NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (estate_id, name)
);

CREATE TABLE IF NOT EXISTS public.property_units (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid REFERENCES public.properties(id) ON DELETE CASCADE,
  estate_id uuid REFERENCES public.estates(id) ON DELETE SET NULL,
  phase_id uuid REFERENCES public.estate_phases(id) ON DELETE SET NULL,
  block_id uuid REFERENCES public.estate_blocks(id) ON DELETE SET NULL,
  building_id uuid REFERENCES public.estate_buildings(id) ON DELETE SET NULL,
  unit_code text NOT NULL,
  unit_label text,
  floor_number int,
  bedrooms numeric(4,1),
  bathrooms numeric(4,1),
  toilets numeric(4,1),
  parking_spaces int,
  built_up_area_sqm numeric(14,2),
  inventory_status text NOT NULL DEFAULT 'available'
    CHECK (inventory_status IN (
      'available','reserved','sold','under_contract','rented','leased','archived'
    )),
  development_status text NOT NULL DEFAULT 'planned'
    CHECK (development_status IN ('planned','under_construction','completed','renovating')),
  listing_price numeric(14,2),
  is_active boolean NOT NULL DEFAULT true,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (estate_id, unit_code)
);

ALTER TABLE public.properties
  ADD COLUMN IF NOT EXISTS property_code text,
  ADD COLUMN IF NOT EXISTS summary text,
  ADD COLUMN IF NOT EXISTS inventory_status text DEFAULT 'available',
  ADD COLUMN IF NOT EXISTS development_status text DEFAULT 'planned',
  ADD COLUMN IF NOT EXISTS marketing_status text DEFAULT 'new_listing',
  ADD COLUMN IF NOT EXISTS category_slug text,
  ADD COLUMN IF NOT EXISTS phase_id uuid,
  ADD COLUMN IF NOT EXISTS block_id uuid,
  ADD COLUMN IF NOT EXISTS building_id uuid,
  ADD COLUMN IF NOT EXISTS unit_id uuid,
  ADD COLUMN IF NOT EXISTS city text,
  ADD COLUMN IF NOT EXISTS state text,
  ADD COLUMN IF NOT EXISTS country text DEFAULT 'Nigeria',
  ADD COLUMN IF NOT EXISTS address_line text,
  ADD COLUMN IF NOT EXISTS bedrooms numeric(4,1),
  ADD COLUMN IF NOT EXISTS bathrooms numeric(4,1),
  ADD COLUMN IF NOT EXISTS land_size_sqm numeric(14,2),
  ADD COLUMN IF NOT EXISTS building_size_sqm numeric(14,2),
  ADD COLUMN IF NOT EXISTS listing_price numeric(14,2),
  ADD COLUMN IF NOT EXISTS currency text DEFAULT 'NGN',
  ADD COLUMN IF NOT EXISTS toilets numeric(4,1),
  ADD COLUMN IF NOT EXISTS floors int,
  ADD COLUMN IF NOT EXISTS parking_spaces int,
  ADD COLUMN IF NOT EXISTS investor_price numeric(14,2),
  ADD COLUMN IF NOT EXISTS rental_price numeric(14,2),
  ADD COLUMN IF NOT EXISTS promo_price numeric(14,2),
  ADD COLUMN IF NOT EXISTS performance_score numeric(5,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS ai_summary text,
  ADD COLUMN IF NOT EXISTS tags text[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS publish_workflow_status text DEFAULT 'draft';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'properties_inventory_status_check'
  ) THEN
    ALTER TABLE public.properties
      ADD CONSTRAINT properties_inventory_status_check
      CHECK (inventory_status IS NULL OR inventory_status IN (
        'available','reserved','sold','under_contract','rented','leased','archived'
      ));
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'properties_development_status_check'
  ) THEN
    ALTER TABLE public.properties
      ADD CONSTRAINT properties_development_status_check
      CHECK (development_status IS NULL OR development_status IN (
        'planned','under_construction','completed','renovating'
      ));
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'properties_marketing_status_check'
  ) THEN
    ALTER TABLE public.properties
      ADD CONSTRAINT properties_marketing_status_check
      CHECK (marketing_status IS NULL OR marketing_status IN (
        'featured','premium','new_listing','hot_deal','sold_out'
      ));
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'properties_publish_workflow_status_check'
  ) THEN
    ALTER TABLE public.properties
      ADD CONSTRAINT properties_publish_workflow_status_check
      CHECK (publish_workflow_status IS NULL OR publish_workflow_status IN (
        'draft','pending_review','published','archived'
      ));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'properties_phase_id_fkey'
  ) THEN
    ALTER TABLE public.properties
      ADD CONSTRAINT properties_phase_id_fkey
      FOREIGN KEY (phase_id) REFERENCES public.estate_phases(id) ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'properties_block_id_fkey'
  ) THEN
    ALTER TABLE public.properties
      ADD CONSTRAINT properties_block_id_fkey
      FOREIGN KEY (block_id) REFERENCES public.estate_blocks(id) ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'properties_building_id_fkey'
  ) THEN
    ALTER TABLE public.properties
      ADD CONSTRAINT properties_building_id_fkey
      FOREIGN KEY (building_id) REFERENCES public.estate_buildings(id) ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'properties_unit_id_fkey'
  ) THEN
    ALTER TABLE public.properties
      ADD CONSTRAINT properties_unit_id_fkey
      FOREIGN KEY (unit_id) REFERENCES public.property_units(id) ON DELETE SET NULL;
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS idx_properties_property_code_unique
  ON public.properties (property_code) WHERE property_code IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.property_price_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  price_type text NOT NULL CHECK (price_type IN (
    'listing','promo','investor','rental','installment','bulk','campaign'
  )),
  old_price numeric(14,2),
  new_price numeric(14,2) NOT NULL,
  currency text NOT NULL DEFAULT 'NGN',
  reason text,
  changed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  effective_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.property_installment_schedules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid NOT NULL REFERENCES public.property_payment_plans(id) ON DELETE CASCADE,
  installment_number int NOT NULL,
  due_offset_days int NOT NULL DEFAULT 0,
  amount numeric(14,2) NOT NULL,
  label text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (plan_id, installment_number)
);

CREATE TABLE IF NOT EXISTS public.property_virtual_tours (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  tour_type text NOT NULL CHECK (tour_type IN (
    'matterport','vr','360','interactive_floorplan','other'
  )),
  title text NOT NULL,
  embed_url text,
  provider text,
  sort_order int NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.property_maps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid REFERENCES public.properties(id) ON DELETE CASCADE,
  estate_id uuid REFERENCES public.estates(id) ON DELETE CASCADE,
  map_type text NOT NULL CHECK (map_type IN (
    'google','estate_layout','satellite','heatmap','digital_twin'
  )),
  title text NOT NULL,
  map_url text,
  geojson jsonb NOT NULL DEFAULT '{}'::jsonb,
  nearby_amenities jsonb NOT NULL DEFAULT '[]'::jsonb,
  is_primary boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (property_id IS NOT NULL OR estate_id IS NOT NULL)
);

CREATE TABLE IF NOT EXISTS public.property_owners (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  owner_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  owner_name text NOT NULL,
  owner_type text NOT NULL DEFAULT 'individual'
    CHECK (owner_type IN ('individual','joint','investor','company','hd_homes')),
  ownership_percentage numeric(5,2) NOT NULL DEFAULT 100
    CHECK (ownership_percentage > 0 AND ownership_percentage <= 100),
  is_current boolean NOT NULL DEFAULT true,
  acquired_at date,
  documents jsonb NOT NULL DEFAULT '[]'::jsonb,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.property_ownership_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  from_owner_id uuid REFERENCES public.property_owners(id) ON DELETE SET NULL,
  to_owner_id uuid REFERENCES public.property_owners(id) ON DELETE SET NULL,
  transfer_type text NOT NULL DEFAULT 'sale'
    CHECK (transfer_type IN ('sale','gift','inheritance','investment','internal','other')),
  transfer_date date NOT NULL DEFAULT CURRENT_DATE,
  transfer_price numeric(14,2),
  document_refs jsonb NOT NULL DEFAULT '[]'::jsonb,
  notes text,
  recorded_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.property_inspections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  inspection_type text NOT NULL CHECK (inspection_type IN (
    'site_visit','virtual_tour','open_house','investor_visit','handover'
  )),
  status text NOT NULL DEFAULT 'scheduled'
    CHECK (status IN ('scheduled','confirmed','completed','cancelled','no_show')),
  scheduled_at timestamptz NOT NULL,
  completed_at timestamptz,
  assigned_staff_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  visitor_name text,
  visitor_email text,
  visitor_phone text,
  visitor_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  report_summary text,
  report_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.property_tag_catalog (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  category text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.property_tag_links (
  property_id uuid NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  tag_id uuid NOT NULL REFERENCES public.property_tag_catalog(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (property_id, tag_id)
);

CREATE TABLE IF NOT EXISTS public.property_analytics_daily (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  metric_date date NOT NULL DEFAULT CURRENT_DATE,
  views int NOT NULL DEFAULT 0,
  favorites int NOT NULL DEFAULT 0,
  bookings int NOT NULL DEFAULT 0,
  inspections int NOT NULL DEFAULT 0,
  leads int NOT NULL DEFAULT 0,
  sales int NOT NULL DEFAULT 0,
  revenue numeric(14,2) NOT NULL DEFAULT 0,
  investor_interest int NOT NULL DEFAULT 0,
  conversion_rate numeric(8,4) NOT NULL DEFAULT 0,
  traffic_sources jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (property_id, metric_date)
);

CREATE TABLE IF NOT EXISTS public.property_scores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL UNIQUE REFERENCES public.properties(id) ON DELETE CASCADE,
  performance_score numeric(5,2) NOT NULL DEFAULT 0,
  demand_score numeric(5,2) NOT NULL DEFAULT 0,
  conversion_score numeric(5,2) NOT NULL DEFAULT 0,
  investor_score numeric(5,2) NOT NULL DEFAULT 0,
  media_quality_score numeric(5,2) NOT NULL DEFAULT 0,
  score_breakdown jsonb NOT NULL DEFAULT '{}'::jsonb,
  computed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.property_relationships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  related_entity_type text NOT NULL CHECK (related_entity_type IN (
    'investor','client','owner','lead','booking','contract','document','payment','construction_project'
  )),
  related_entity_id uuid,
  related_label text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.property_approvals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  step_key text NOT NULL CHECK (step_key IN (
    'sales_team','manager_review','legal_review','executive_approval','published'
  )),
  step_order int NOT NULL DEFAULT 1,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','approved','rejected','skipped')),
  reviewer_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  comments text,
  decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (property_id, step_key)
);

CREATE TABLE IF NOT EXISTS public.property_lifecycle_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  event_type text NOT NULL,
  title text NOT NULL,
  description text,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  actor_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_estate_blocks_estate ON public.estate_blocks (estate_id, sort_order);
CREATE INDEX IF NOT EXISTS idx_estate_buildings_estate ON public.estate_buildings (estate_id, sort_order);
CREATE INDEX IF NOT EXISTS idx_property_units_estate_status ON public.property_units (estate_id, inventory_status);
CREATE INDEX IF NOT EXISTS idx_properties_inventory_status ON public.properties (inventory_status);
CREATE INDEX IF NOT EXISTS idx_properties_development_status ON public.properties (development_status);
CREATE INDEX IF NOT EXISTS idx_properties_marketing_status ON public.properties (marketing_status);
CREATE INDEX IF NOT EXISTS idx_properties_block_building ON public.properties (block_id, building_id);
CREATE INDEX IF NOT EXISTS idx_property_price_history_prop ON public.property_price_history (property_id, effective_at DESC);
CREATE INDEX IF NOT EXISTS idx_property_inspections_sched ON public.property_inspections (scheduled_at DESC);
CREATE INDEX IF NOT EXISTS idx_property_inspections_status ON public.property_inspections (status);
CREATE INDEX IF NOT EXISTS idx_property_owners_current ON public.property_owners (property_id, is_current);
CREATE INDEX IF NOT EXISTS idx_property_analytics_daily_date ON public.property_analytics_daily (metric_date DESC);
CREATE INDEX IF NOT EXISTS idx_property_lifecycle_events_prop ON public.property_lifecycle_events (property_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_property_approvals_status ON public.property_approvals (status, step_order);
CREATE INDEX IF NOT EXISTS idx_property_relationships_prop ON public.property_relationships (property_id, related_entity_type);

DROP TRIGGER IF EXISTS trg_estate_blocks_updated_at ON public.estate_blocks;
CREATE TRIGGER trg_estate_blocks_updated_at
  BEFORE UPDATE ON public.estate_blocks
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_estate_buildings_updated_at ON public.estate_buildings;
CREATE TRIGGER trg_estate_buildings_updated_at
  BEFORE UPDATE ON public.estate_buildings
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_property_units_updated_at ON public.property_units;
CREATE TRIGGER trg_property_units_updated_at
  BEFORE UPDATE ON public.property_units
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_property_virtual_tours_updated_at ON public.property_virtual_tours;
CREATE TRIGGER trg_property_virtual_tours_updated_at
  BEFORE UPDATE ON public.property_virtual_tours
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_property_maps_updated_at ON public.property_maps;
CREATE TRIGGER trg_property_maps_updated_at
  BEFORE UPDATE ON public.property_maps
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_property_owners_updated_at ON public.property_owners;
CREATE TRIGGER trg_property_owners_updated_at
  BEFORE UPDATE ON public.property_owners
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_property_inspections_updated_at ON public.property_inspections;
CREATE TRIGGER trg_property_inspections_updated_at
  BEFORE UPDATE ON public.property_inspections
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_property_analytics_daily_updated_at ON public.property_analytics_daily;
CREATE TRIGGER trg_property_analytics_daily_updated_at
  BEFORE UPDATE ON public.property_analytics_daily
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_property_scores_updated_at ON public.property_scores;
CREATE TRIGGER trg_property_scores_updated_at
  BEFORE UPDATE ON public.property_scores
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_property_approvals_updated_at ON public.property_approvals;
CREATE TRIGGER trg_property_approvals_updated_at
  BEFORE UPDATE ON public.property_approvals
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

INSERT INTO public.property_types (slug, name, description, sort_order) VALUES
  ('land', 'Land', 'Undeveloped land parcel', 10),
  ('residential_plot', 'Residential Plot', 'Residential land plot', 20),
  ('commercial_plot', 'Commercial Plot', 'Commercial land plot', 30),
  ('apartment', 'Apartment', 'Apartment unit', 40),
  ('duplex', 'Duplex', 'Duplex home', 50),
  ('terrace_house', 'Terrace House', 'Terrace house', 60),
  ('detached_house', 'Detached House', 'Detached house', 70),
  ('semi_detached_house', 'Semi-Detached House', 'Semi-detached house', 80),
  ('bungalow', 'Bungalow', 'Single-storey bungalow', 90),
  ('penthouse', 'Penthouse', 'Penthouse apartment', 100),
  ('office_space', 'Office Space', 'Commercial office', 110),
  ('warehouse', 'Warehouse', 'Warehouse facility', 120),
  ('retail_space', 'Retail Space', 'Retail commercial unit', 130),
  ('hotel', 'Hotel', 'Hotel property', 140),
  ('mixed_use_development', 'Mixed-Use Development', 'Mixed-use development', 150),
  ('estate_development', 'Estate Development', 'Full estate development', 160),
  ('investment_property', 'Investment Property', 'Investment-focused asset', 170)
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  sort_order = EXCLUDED.sort_order,
  updated_at = now();

INSERT INTO public.property_tag_catalog (slug, name, category) VALUES
  ('luxury', 'Luxury', 'lifestyle'),
  ('family_friendly', 'Family Friendly', 'lifestyle'),
  ('investment_opportunity', 'Investment Opportunity', 'investment'),
  ('waterfront', 'Waterfront', 'location'),
  ('smart_home', 'Smart Home', 'features'),
  ('commercial_hotspot', 'Commercial Hotspot', 'commercial'),
  ('featured', 'Featured', 'marketing')
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  category = EXCLUDED.category;

INSERT INTO public.estates (slug, name, tagline, description, city, state, country, is_featured, is_published, published_at)
VALUES (
  'victoria-crest-estate',
  'Victoria Crest Estate',
  'Flagship lakeside community',
  'Enterprise digital-twin estate used by the HD Homes Property Management System.',
  'Lagos', 'Lagos', 'Nigeria', true, true, now()
)
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  tagline = EXCLUDED.tagline,
  description = EXCLUDED.description,
  city = EXCLUDED.city,
  state = EXCLUDED.state,
  is_featured = true,
  is_published = true,
  published_at = COALESCE(public.estates.published_at, now()),
  updated_at = now();

INSERT INTO public.estate_phases (estate_id, name, code, status, sort_order)
SELECT e.id, 'Phase A', 'A', 'selling', 1
FROM public.estates e
WHERE e.slug = 'victoria-crest-estate'
  AND NOT EXISTS (
    SELECT 1 FROM public.estate_phases ep
    WHERE ep.estate_id = e.id AND ep.name = 'Phase A'
  );

INSERT INTO public.estate_blocks (estate_id, phase_id, name, code, sort_order)
SELECT e.id, p.id, 'Block B', 'B', 1
FROM public.estates e
JOIN public.estate_phases p ON p.estate_id = e.id AND p.code = 'A'
WHERE e.slug = 'victoria-crest-estate'
ON CONFLICT (estate_id, name) DO NOTHING;

INSERT INTO public.estate_buildings (estate_id, block_id, phase_id, name, code, floors, sort_order)
SELECT e.id, b.id, p.id, 'Building 12', '12', 4, 1
FROM public.estates e
JOIN public.estate_phases p ON p.estate_id = e.id AND p.code = 'A'
JOIN public.estate_blocks b ON b.estate_id = e.id AND b.name = 'Block B'
WHERE e.slug = 'victoria-crest-estate'
ON CONFLICT (estate_id, name) DO NOTHING;

INSERT INTO public.property_units (
  estate_id, phase_id, block_id, building_id, unit_code, unit_label,
  floor_number, bedrooms, bathrooms, toilets, parking_spaces, built_up_area_sqm,
  inventory_status, development_status, listing_price
)
SELECT e.id, p.id, b.id, g.id, 'VC-A-B-12-U4', 'Unit 4',
  2, 3, 3, 4, 2, 185, 'available', 'completed', 85000000
FROM public.estates e
JOIN public.estate_phases p ON p.estate_id = e.id AND p.code = 'A'
JOIN public.estate_blocks b ON b.estate_id = e.id AND b.name = 'Block B'
JOIN public.estate_buildings g ON g.estate_id = e.id AND g.name = 'Building 12'
WHERE e.slug = 'victoria-crest-estate'
ON CONFLICT (estate_id, unit_code) DO NOTHING;

INSERT INTO public.properties (
  slug, title, summary, description, property_code, type_id, estate_id, phase_id,
  block_id, building_id, unit_id, city, state, country, address_line, bedrooms, bathrooms,
  toilets, floors, parking_spaces, land_size_sqm, building_size_sqm, listing_price, promo_price,
  investor_price, rental_price, currency, status, inventory_status, development_status,
  marketing_status, publish_workflow_status, category_slug, is_featured, is_published,
  published_at, performance_score, tags, ai_summary
)
SELECT
  'victoria-crest-unit-4',
  'Victoria Crest — Building 12 Unit 4',
  '3-bedroom residence in Phase A, Block B.',
  'Sample enterprise PMS property spanning the full estate hierarchy.',
  'HDH-VC-A-B-12-U4',
  pt.id, e.id, p.id, b.id, g.id, u.id,
  'Lagos', 'Lagos', 'Nigeria',
  'Building 12, Block B, Phase A, Victoria Crest Estate',
  3, 3, 4, 4, 2, 250, 185,
  85000000, 82000000, 80000000, 2500000, 'NGN',
  'available', 'available', 'completed', 'featured', 'published', 'residential',
  true, true, now(), 82.5,
  ARRAY['luxury','family_friendly','investment_opportunity'],
  'Strong family demand asset with investor-friendly installment flexibility.'
FROM public.estates e
JOIN public.estate_phases p ON p.estate_id = e.id AND p.code = 'A'
JOIN public.estate_blocks b ON b.estate_id = e.id AND b.name = 'Block B'
JOIN public.estate_buildings g ON g.estate_id = e.id AND g.name = 'Building 12'
JOIN public.property_units u ON u.estate_id = e.id AND u.unit_code = 'VC-A-B-12-U4'
JOIN public.property_types pt ON pt.slug = 'apartment'
WHERE e.slug = 'victoria-crest-estate'
ON CONFLICT (slug) DO UPDATE SET
  title = EXCLUDED.title,
  property_code = EXCLUDED.property_code,
  inventory_status = EXCLUDED.inventory_status,
  development_status = EXCLUDED.development_status,
  marketing_status = EXCLUDED.marketing_status,
  publish_workflow_status = EXCLUDED.publish_workflow_status,
  performance_score = EXCLUDED.performance_score,
  ai_summary = EXCLUDED.ai_summary,
  updated_at = now();

UPDATE public.property_units u
SET property_id = p.id
FROM public.properties p
WHERE p.slug = 'victoria-crest-unit-4'
  AND u.unit_code = 'VC-A-B-12-U4'
  AND (u.property_id IS DISTINCT FROM p.id);

UPDATE public.properties p
SET unit_id = u.id
FROM public.property_units u
WHERE p.slug = 'victoria-crest-unit-4'
  AND u.unit_code = 'VC-A-B-12-U4'
  AND (p.unit_id IS DISTINCT FROM u.id);

INSERT INTO public.property_scores (property_id, performance_score, demand_score, conversion_score, investor_score, media_quality_score, score_breakdown)
SELECT p.id, 82.5, 78, 71, 85, 74,
  '{"views":24,"leads":6,"inspections":3,"sales":1,"revenue":85000000}'::jsonb
FROM public.properties p
WHERE p.slug = 'victoria-crest-unit-4'
ON CONFLICT (property_id) DO UPDATE SET
  performance_score = EXCLUDED.performance_score,
  demand_score = EXCLUDED.demand_score,
  conversion_score = EXCLUDED.conversion_score,
  investor_score = EXCLUDED.investor_score,
  media_quality_score = EXCLUDED.media_quality_score,
  score_breakdown = EXCLUDED.score_breakdown,
  computed_at = now(),
  updated_at = now();

INSERT INTO public.property_analytics_daily (
  property_id, metric_date, views, favorites, bookings, inspections, leads, sales, revenue, investor_interest, conversion_rate, traffic_sources
)
SELECT p.id, CURRENT_DATE, 24, 8, 2, 3, 6, 0, 0, 5, 0.125,
  '{"organic":10,"referral":6,"paid":5,"direct":3}'::jsonb
FROM public.properties p
WHERE p.slug = 'victoria-crest-unit-4'
ON CONFLICT (property_id, metric_date) DO UPDATE SET
  views = EXCLUDED.views,
  favorites = EXCLUDED.favorites,
  bookings = EXCLUDED.bookings,
  inspections = EXCLUDED.inspections,
  leads = EXCLUDED.leads,
  investor_interest = EXCLUDED.investor_interest,
  conversion_rate = EXCLUDED.conversion_rate,
  traffic_sources = EXCLUDED.traffic_sources,
  updated_at = now();

INSERT INTO public.property_approvals (property_id, step_key, step_order, status)
SELECT p.id, s.step_key, s.step_order,
  CASE WHEN s.step_key = 'published' THEN 'approved' ELSE 'approved' END
FROM public.properties p
CROSS JOIN (VALUES
  ('sales_team', 1),
  ('manager_review', 2),
  ('legal_review', 3),
  ('executive_approval', 4),
  ('published', 5)
) AS s(step_key, step_order)
WHERE p.slug = 'victoria-crest-unit-4'
ON CONFLICT (property_id, step_key) DO NOTHING;

INSERT INTO public.property_lifecycle_events (property_id, event_type, title, description)
SELECT p.id, e.event_type, e.title, e.description
FROM public.properties p
CROSS JOIN (VALUES
  ('created', 'Property created', 'Registered in PMS hierarchy'),
  ('price_changed', 'Listing price set', 'NGN 85,000,000'),
  ('published', 'Published', 'Approved through executive workflow')
) AS e(event_type, title, description)
WHERE p.slug = 'victoria-crest-unit-4'
  AND NOT EXISTS (
    SELECT 1 FROM public.property_lifecycle_events x
    WHERE x.property_id = p.id AND x.event_type = e.event_type
  );

INSERT INTO public.property_owners (
  property_id, owner_name, owner_type, ownership_percentage, is_current, acquired_at, notes
)
SELECT p.id, 'HD Homes Ltd', 'hd_homes', 100, true, CURRENT_DATE, 'Inventory ownership pending sale'
FROM public.properties p
WHERE p.slug = 'victoria-crest-unit-4'
  AND NOT EXISTS (
    SELECT 1 FROM public.property_owners o
    WHERE o.property_id = p.id AND o.is_current = true
  );

INSERT INTO public.property_maps (estate_id, map_type, title, map_url, nearby_amenities, is_primary)
SELECT e.id, 'digital_twin', 'Victoria Crest Digital Twin', null,
  '[{"type":"school","name":"Crest Academy"},{"type":"hospital","name":"Lakeside Medical"},{"type":"bank","name":"GTBank"},{"type":"shopping","name":"Victoria Mall"}]'::jsonb,
  true
FROM public.estates e
WHERE e.slug = 'victoria-crest-estate'
  AND NOT EXISTS (
    SELECT 1 FROM public.property_maps m
    WHERE m.estate_id = e.id AND m.map_type = 'digital_twin'
  );

ALTER TABLE public.estate_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.estate_buildings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_units ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_price_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_installment_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_virtual_tours ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_maps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_owners ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_ownership_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_inspections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_tag_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_tag_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_analytics_daily ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_relationships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_approvals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_lifecycle_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS estate_blocks_select ON public.estate_blocks;
CREATE POLICY estate_blocks_select ON public.estate_blocks FOR SELECT TO authenticated
  USING (public.has_permission('properties.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
DROP POLICY IF EXISTS estate_blocks_write ON public.estate_blocks;
CREATE POLICY estate_blocks_write ON public.estate_blocks FOR ALL TO authenticated
  USING (public.has_permission('properties.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('properties.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS estate_buildings_select ON public.estate_buildings;
CREATE POLICY estate_buildings_select ON public.estate_buildings FOR SELECT TO authenticated
  USING (public.has_permission('properties.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
DROP POLICY IF EXISTS estate_buildings_write ON public.estate_buildings;
CREATE POLICY estate_buildings_write ON public.estate_buildings FOR ALL TO authenticated
  USING (public.has_permission('properties.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('properties.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS property_units_select ON public.property_units;
CREATE POLICY property_units_select ON public.property_units FOR SELECT TO authenticated
  USING (public.has_permission('properties.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
DROP POLICY IF EXISTS property_units_write ON public.property_units;
CREATE POLICY property_units_write ON public.property_units FOR ALL TO authenticated
  USING (public.has_permission('properties.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('properties.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS property_price_history_select ON public.property_price_history;
CREATE POLICY property_price_history_select ON public.property_price_history FOR SELECT TO authenticated
  USING (public.has_permission('properties.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
DROP POLICY IF EXISTS property_price_history_write ON public.property_price_history;
CREATE POLICY property_price_history_write ON public.property_price_history FOR ALL TO authenticated
  USING (public.has_permission('properties.pricing', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('properties.pricing', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS property_installment_schedules_select ON public.property_installment_schedules;
CREATE POLICY property_installment_schedules_select ON public.property_installment_schedules FOR SELECT TO authenticated
  USING (public.has_permission('properties.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
DROP POLICY IF EXISTS property_installment_schedules_write ON public.property_installment_schedules;
CREATE POLICY property_installment_schedules_write ON public.property_installment_schedules FOR ALL TO authenticated
  USING (public.has_permission('properties.pricing', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('properties.pricing', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS property_virtual_tours_select ON public.property_virtual_tours;
CREATE POLICY property_virtual_tours_select ON public.property_virtual_tours FOR SELECT TO authenticated
  USING (public.has_permission('properties.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
DROP POLICY IF EXISTS property_virtual_tours_write ON public.property_virtual_tours;
CREATE POLICY property_virtual_tours_write ON public.property_virtual_tours FOR ALL TO authenticated
  USING (public.has_permission('properties.media', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('properties.media', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS property_maps_select ON public.property_maps;
CREATE POLICY property_maps_select ON public.property_maps FOR SELECT TO authenticated
  USING (public.has_permission('properties.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
DROP POLICY IF EXISTS property_maps_write ON public.property_maps;
CREATE POLICY property_maps_write ON public.property_maps FOR ALL TO authenticated
  USING (public.has_permission('properties.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('properties.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS property_owners_select ON public.property_owners;
CREATE POLICY property_owners_select ON public.property_owners FOR SELECT TO authenticated
  USING (
    public.has_permission('properties.ownership', auth.uid())
    OR public.has_permission('properties.read', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
DROP POLICY IF EXISTS property_owners_write ON public.property_owners;
CREATE POLICY property_owners_write ON public.property_owners FOR ALL TO authenticated
  USING (public.has_permission('properties.ownership', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('properties.ownership', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS property_ownership_history_select ON public.property_ownership_history;
CREATE POLICY property_ownership_history_select ON public.property_ownership_history FOR SELECT TO authenticated
  USING (
    public.has_permission('properties.ownership', auth.uid())
    OR public.has_permission('properties.read', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
DROP POLICY IF EXISTS property_ownership_history_write ON public.property_ownership_history;
CREATE POLICY property_ownership_history_write ON public.property_ownership_history FOR ALL TO authenticated
  USING (public.has_permission('properties.ownership', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('properties.ownership', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS property_inspections_select ON public.property_inspections;
CREATE POLICY property_inspections_select ON public.property_inspections FOR SELECT TO authenticated
  USING (public.has_permission('properties.inspections', auth.uid()) OR public.has_permission('properties.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
DROP POLICY IF EXISTS property_inspections_write ON public.property_inspections;
CREATE POLICY property_inspections_write ON public.property_inspections FOR ALL TO authenticated
  USING (public.has_permission('properties.inspections', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('properties.inspections', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS property_tag_catalog_select ON public.property_tag_catalog;
CREATE POLICY property_tag_catalog_select ON public.property_tag_catalog FOR SELECT TO authenticated
  USING (true);
DROP POLICY IF EXISTS property_tag_catalog_write ON public.property_tag_catalog;
CREATE POLICY property_tag_catalog_write ON public.property_tag_catalog FOR ALL TO authenticated
  USING (public.has_permission('properties.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('properties.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS property_tag_links_select ON public.property_tag_links;
CREATE POLICY property_tag_links_select ON public.property_tag_links FOR SELECT TO authenticated
  USING (public.has_permission('properties.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
DROP POLICY IF EXISTS property_tag_links_write ON public.property_tag_links;
CREATE POLICY property_tag_links_write ON public.property_tag_links FOR ALL TO authenticated
  USING (public.has_permission('properties.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('properties.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS property_analytics_daily_select ON public.property_analytics_daily;
CREATE POLICY property_analytics_daily_select ON public.property_analytics_daily FOR SELECT TO authenticated
  USING (public.has_permission('properties.analytics', auth.uid()) OR public.has_permission('properties.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
DROP POLICY IF EXISTS property_analytics_daily_write ON public.property_analytics_daily;
CREATE POLICY property_analytics_daily_write ON public.property_analytics_daily FOR ALL TO authenticated
  USING (public.has_permission('properties.analytics', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('properties.analytics', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS property_scores_select ON public.property_scores;
CREATE POLICY property_scores_select ON public.property_scores FOR SELECT TO authenticated
  USING (public.has_permission('properties.analytics', auth.uid()) OR public.has_permission('properties.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
DROP POLICY IF EXISTS property_scores_write ON public.property_scores;
CREATE POLICY property_scores_write ON public.property_scores FOR ALL TO authenticated
  USING (public.has_permission('properties.analytics', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('properties.analytics', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS property_relationships_select ON public.property_relationships;
CREATE POLICY property_relationships_select ON public.property_relationships FOR SELECT TO authenticated
  USING (public.has_permission('properties.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
DROP POLICY IF EXISTS property_relationships_write ON public.property_relationships;
CREATE POLICY property_relationships_write ON public.property_relationships FOR ALL TO authenticated
  USING (public.has_permission('properties.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('properties.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS property_approvals_select ON public.property_approvals;
CREATE POLICY property_approvals_select ON public.property_approvals FOR SELECT TO authenticated
  USING (public.has_permission('properties.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
DROP POLICY IF EXISTS property_approvals_write ON public.property_approvals;
CREATE POLICY property_approvals_write ON public.property_approvals FOR ALL TO authenticated
  USING (public.has_permission('properties.approve', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('properties.approve', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS property_lifecycle_events_select ON public.property_lifecycle_events;
CREATE POLICY property_lifecycle_events_select ON public.property_lifecycle_events FOR SELECT TO authenticated
  USING (public.has_permission('properties.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
DROP POLICY IF EXISTS property_lifecycle_events_write ON public.property_lifecycle_events;
CREATE POLICY property_lifecycle_events_write ON public.property_lifecycle_events FOR ALL TO authenticated
  USING (public.has_permission('properties.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('properties.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'estate_blocks','estate_buildings','property_units','property_price_history',
    'property_virtual_tours','property_maps','property_owners','property_ownership_history',
    'property_inspections','property_analytics_daily','property_scores','property_relationships',
    'property_approvals','property_lifecycle_events'
  ]
  LOOP
    BEGIN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    EXCEPTION WHEN duplicate_object THEN
      NULL;
    END;
  END LOOP;
END $$;

COMMIT;

-- Status: APPLIED remotely 2026-07-14 (chunked apply_migration p1–p6).
