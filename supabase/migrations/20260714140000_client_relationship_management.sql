-- Volume 4 Part 3 — Enterprise Client Relationship Management (CRM)
-- Status: APPLIED remotely 2026-07-14 (chunked p1–p4).

BEGIN;

-- ---------------------------------------------------------------------------
-- Permissions (NO action column — slug, name, description, module only)
-- ---------------------------------------------------------------------------
INSERT INTO public.permissions (slug, name, description, module) VALUES
  ('crm.read', 'View CRM', 'View clients, leads, and CRM command center', 'crm'),
  ('crm.write', 'Manage CRM', 'Create and edit clients and CRM records', 'crm'),
  ('crm.leads', 'Manage Leads', 'Capture and qualify leads', 'crm'),
  ('crm.pipeline', 'Manage Pipeline', 'Move leads across pipeline stages', 'crm'),
  ('crm.tasks', 'Manage CRM Tasks', 'Create and complete CRM tasks and follow-ups', 'crm'),
  ('crm.communications', 'CRM Communications', 'Log and send client communications', 'crm'),
  ('crm.documents', 'CRM Documents', 'Manage client documents', 'crm'),
  ('crm.analytics', 'CRM Analytics', 'View CRM KPIs and health scores', 'crm'),
  ('crm.ai', 'AI CRM Assistant', 'Use AI summaries and lead intelligence', 'crm'),
  ('crm.assign', 'Assign CRM Owners', 'Assign staff to clients and leads', 'crm')
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  module = EXCLUDED.module,
  updated_at = now();

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE p.slug LIKE 'crm.%'
  AND (
    r.slug IN ('super_admin', 'admin')
    OR (r.slug = 'sales_team' AND p.slug IN (
      'crm.read','crm.write','crm.leads','crm.pipeline','crm.tasks',
      'crm.communications','crm.documents','crm.analytics','crm.ai','crm.assign'
    ))
    OR (r.slug = 'marketing' AND p.slug IN (
      'crm.read','crm.leads','crm.communications','crm.ai'
    ))
    OR (r.slug = 'finance' AND p.slug IN (
      'crm.read','crm.analytics'
    ))
  )
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Catalog / pipeline
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.crm_lead_sources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.crm_pipeline_stages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  sort_order int NOT NULL DEFAULT 0,
  probability_pct numeric(5,2) NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Clients
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.crm_clients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_code text NOT NULL UNIQUE,
  full_name text NOT NULL,
  email text,
  phone text,
  whatsapp text,
  customer_type text NOT NULL DEFAULT 'guest'
    CHECK (customer_type IN (
      'guest','registered_client','buyer','investor','property_owner',
      'tenant','corporate','agent_partner','vendor','former_client'
    )),
  relationship_status text NOT NULL DEFAULT 'lead'
    CHECK (relationship_status IN (
      'lead','prospect','active_buyer','investor','owner','dormant','vip'
    )),
  assigned_staff_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  nationality text,
  preferred_language text DEFAULT 'en',
  occupation text,
  company text,
  industry text,
  budget_min numeric(14,2),
  budget_max numeric(14,2),
  preferred_locations text[] NOT NULL DEFAULT '{}',
  health_score numeric(5,2) DEFAULT 0,
  health_label text,
  lead_score numeric(5,2) DEFAULT 0,
  ai_summary text,
  marketing_consent boolean NOT NULL DEFAULT false,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_crm_clients_assigned ON public.crm_clients (assigned_staff_id);
CREATE INDEX IF NOT EXISTS idx_crm_clients_status ON public.crm_clients (relationship_status);
CREATE INDEX IF NOT EXISTS idx_crm_clients_email ON public.crm_clients (email);

-- ---------------------------------------------------------------------------
-- Leads + pipeline history
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.crm_leads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL REFERENCES public.crm_clients(id) ON DELETE CASCADE,
  source_id uuid REFERENCES public.crm_lead_sources(id) ON DELETE SET NULL,
  stage_id uuid REFERENCES public.crm_pipeline_stages(id) ON DELETE SET NULL,
  title text NOT NULL,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','qualified','nurture','won','lost')),
  assigned_to uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  priority text NOT NULL DEFAULT 'medium'
    CHECK (priority IN ('low','medium','high','urgent')),
  conversion_probability numeric(5,2) DEFAULT 0,
  estimated_value numeric(14,2),
  notes text,
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_crm_leads_client ON public.crm_leads (client_id);
CREATE INDEX IF NOT EXISTS idx_crm_leads_stage ON public.crm_leads (stage_id);
CREATE INDEX IF NOT EXISTS idx_crm_leads_status ON public.crm_leads (status);

CREATE TABLE IF NOT EXISTS public.crm_pipeline_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id uuid NOT NULL REFERENCES public.crm_leads(id) ON DELETE CASCADE,
  from_stage_id uuid REFERENCES public.crm_pipeline_stages(id) ON DELETE SET NULL,
  to_stage_id uuid REFERENCES public.crm_pipeline_stages(id) ON DELETE SET NULL,
  changed_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  notes text,
  changed_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Tasks, appointments, notes
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.crm_tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL REFERENCES public.crm_clients(id) ON DELETE CASCADE,
  lead_id uuid REFERENCES public.crm_leads(id) ON DELETE SET NULL,
  title text NOT NULL,
  task_type text NOT NULL DEFAULT 'follow_up'
    CHECK (task_type IN (
      'call','meeting','site_visit','email','follow_up','reminder','internal_note'
    )),
  priority text NOT NULL DEFAULT 'medium'
    CHECK (priority IN ('low','medium','high','urgent')),
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','in_progress','done','cancelled')),
  due_at timestamptz,
  assigned_to uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_crm_tasks_due ON public.crm_tasks (due_at);
CREATE INDEX IF NOT EXISTS idx_crm_tasks_client ON public.crm_tasks (client_id);

CREATE TABLE IF NOT EXISTS public.crm_appointments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL REFERENCES public.crm_clients(id) ON DELETE CASCADE,
  appointment_type text NOT NULL DEFAULT 'meeting',
  title text NOT NULL,
  scheduled_at timestamptz NOT NULL,
  location text,
  meeting_url text,
  assigned_staff_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'scheduled'
    CHECK (status IN ('scheduled','confirmed','completed','cancelled','no_show')),
  property_id uuid REFERENCES public.properties(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_crm_appointments_scheduled ON public.crm_appointments (scheduled_at);

CREATE TABLE IF NOT EXISTS public.crm_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL REFERENCES public.crm_clients(id) ON DELETE CASCADE,
  note_type text NOT NULL DEFAULT 'team'
    CHECK (note_type IN ('private','team','meeting','call','ai')),
  body text NOT NULL,
  is_private boolean NOT NULL DEFAULT false,
  author_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  mentions text[] NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Tags
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.crm_tags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  color text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.crm_client_tags (
  client_id uuid NOT NULL REFERENCES public.crm_clients(id) ON DELETE CASCADE,
  tag_id uuid NOT NULL REFERENCES public.crm_tags(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (client_id, tag_id)
);

-- ---------------------------------------------------------------------------
-- Referrals
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.crm_referrals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_client_id uuid NOT NULL REFERENCES public.crm_clients(id) ON DELETE CASCADE,
  referred_client_id uuid REFERENCES public.crm_clients(id) ON DELETE SET NULL,
  code text NOT NULL UNIQUE,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','qualified','rewarded','expired')),
  reward_amount numeric(14,2),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.crm_referral_rewards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referral_id uuid NOT NULL REFERENCES public.crm_referrals(id) ON DELETE CASCADE,
  amount numeric(14,2) NOT NULL,
  currency text NOT NULL DEFAULT 'NGN',
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','approved','paid','cancelled')),
  paid_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Communications & documents
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.crm_communications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL REFERENCES public.crm_clients(id) ON DELETE CASCADE,
  channel text NOT NULL
    CHECK (channel IN ('email','sms','whatsapp','phone','in_app','live_chat')),
  direction text NOT NULL
    CHECK (direction IN ('inbound','outbound')),
  subject text,
  body text,
  staff_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_crm_communications_client ON public.crm_communications (client_id);

CREATE TABLE IF NOT EXISTS public.crm_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL REFERENCES public.crm_clients(id) ON DELETE CASCADE,
  title text NOT NULL,
  document_type text NOT NULL DEFAULT 'other',
  file_url text,
  version int NOT NULL DEFAULT 1,
  expires_at timestamptz,
  is_sensitive boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Preferences, health, followups, timeline
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.crm_preferences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL UNIQUE REFERENCES public.crm_clients(id) ON DELETE CASCADE,
  preferred_property_types text[] NOT NULL DEFAULT '{}',
  bedrooms numeric(4,1),
  amenities text[] NOT NULL DEFAULT '{}',
  payment_plan_pref text,
  investment_goals text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.crm_health_scores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL UNIQUE REFERENCES public.crm_clients(id) ON DELETE CASCADE,
  score numeric(5,2) NOT NULL DEFAULT 0,
  label text NOT NULL DEFAULT 'healthy',
  breakdown jsonb NOT NULL DEFAULT '{}'::jsonb,
  computed_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.crm_followups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL REFERENCES public.crm_clients(id) ON DELETE CASCADE,
  reason text NOT NULL,
  due_at timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','done','cancelled')),
  assigned_to uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.crm_activity_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL REFERENCES public.crm_clients(id) ON DELETE CASCADE,
  event_type text NOT NULL,
  title text NOT NULL,
  description text,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  actor_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_crm_activity_logs_client ON public.crm_activity_logs (client_id);
CREATE INDEX IF NOT EXISTS idx_crm_activity_logs_occurred ON public.crm_activity_logs (occurred_at DESC);

CREATE TABLE IF NOT EXISTS public.crm_property_matches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL REFERENCES public.crm_clients(id) ON DELETE CASCADE,
  property_id uuid NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  match_score numeric(5,2) NOT NULL DEFAULT 0,
  reason text,
  status text NOT NULL DEFAULT 'suggested'
    CHECK (status IN ('suggested','viewed','interested','dismissed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (client_id, property_id)
);

CREATE TABLE IF NOT EXISTS public.crm_customer_success (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL UNIQUE REFERENCES public.crm_clients(id) ON DELETE CASCADE,
  satisfaction_score numeric(5,2),
  referral_count int NOT NULL DEFAULT 0,
  repeat_purchases int NOT NULL DEFAULT 0,
  loyalty_status text NOT NULL DEFAULT 'bronze'
    CHECK (loyalty_status IN ('bronze','silver','gold','platinum')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.crm_segments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  description text,
  rules jsonb NOT NULL DEFAULT '{}'::jsonb,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.crm_campaign_memberships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  segment_id uuid NOT NULL REFERENCES public.crm_segments(id) ON DELETE CASCADE,
  client_id uuid NOT NULL REFERENCES public.crm_clients(id) ON DELETE CASCADE,
  campaign_key text NOT NULL,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','paused','completed','unsubscribed')),
  joined_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (segment_id, client_id, campaign_key)
);

-- ---------------------------------------------------------------------------
-- Seed: lead sources + pipeline stages
-- ---------------------------------------------------------------------------
INSERT INTO public.crm_lead_sources (slug, name, description) VALUES
  ('website', 'Website', 'Organic / paid web inquiries'),
  ('referral', 'Referral', 'Client or partner referral'),
  ('whatsapp', 'WhatsApp', 'WhatsApp inbound'),
  ('walk_in', 'Walk-in', 'Office or site walk-in'),
  ('social', 'Social Media', 'Instagram / Facebook / LinkedIn'),
  ('event', 'Event', 'Showroom / expo / open house'),
  ('agent', 'Agent Partner', 'Broker or agent partner')
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  is_active = true,
  updated_at = now();

INSERT INTO public.crm_pipeline_stages (slug, name, sort_order, probability_pct) VALUES
  ('new', 'New Lead', 10, 10),
  ('contacted', 'Contacted', 20, 25),
  ('qualified', 'Qualified', 30, 40),
  ('site_visit', 'Site Visit', 40, 55),
  ('negotiation', 'Negotiation', 50, 70),
  ('won', 'Won', 60, 100),
  ('lost', 'Lost', 70, 0)
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  sort_order = EXCLUDED.sort_order,
  probability_pct = EXCLUDED.probability_pct,
  is_active = true,
  updated_at = now();

INSERT INTO public.crm_tags (slug, name, color) VALUES
  ('hot', 'Hot', '#E11D48'),
  ('vip', 'VIP', '#D4AF37'),
  ('investor', 'Investor', '#2563EB'),
  ('lekki', 'Lekki Focus', '#059669')
ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name, color = EXCLUDED.color;

INSERT INTO public.crm_segments (slug, name, description, rules) VALUES
  ('hot-pipeline', 'Hot Pipeline', 'High-probability open leads', '{"min_probability":60}'::jsonb),
  ('vip-buyers', 'VIP Buyers', 'VIP relationship clients', '{"relationship_status":"vip"}'::jsonb)
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  rules = EXCLUDED.rules,
  updated_at = now();

-- ---------------------------------------------------------------------------
-- Seed: 3 sample clients + related CRM rows (fixed UUIDs)
-- ---------------------------------------------------------------------------
INSERT INTO public.crm_clients (
  id, client_code, full_name, email, phone, whatsapp, customer_type, relationship_status,
  nationality, preferred_language, occupation, company, industry,
  budget_min, budget_max, preferred_locations, health_score, health_label, lead_score,
  ai_summary, marketing_consent, metadata
) VALUES
  (
    'a1000000-0000-4000-8000-000000000001',
    'CRM-VIP-001',
    'Adaeze Nwosu',
    'adaeze.nwosu@example.com',
    '+2348010000001',
    '+2348010000001',
    'buyer',
    'vip',
    'Nigerian',
    'en',
    'Entrepreneur',
    'Nwosu Holdings',
    'Real Estate',
    80000000,
    150000000,
    ARRAY['Lekki','Victoria Island'],
    92,
    'vip',
    88,
    'VIP hot lead with strong Lekki duplex preference. High engagement and referral potential — prioritize site visit this week.',
    true,
    '{"demo":true,"persona":"vip_hot_lead"}'::jsonb
  ),
  (
    'a1000000-0000-4000-8000-000000000002',
    'CRM-BUY-002',
    'Chuka Okonkwo',
    'chuka.okonkwo@example.com',
    '+2348010000002',
    '+2348010000002',
    'buyer',
    'active_buyer',
    'Nigerian',
    'en',
    'Banker',
    'First Atlantic Bank',
    'Finance',
    60000000,
    95000000,
    ARRAY['Lekki','Ajah'],
    78,
    'healthy',
    71,
    'Active buyer mid-pipeline. Prefers 3-bed apartments with payment plan flexibility. Next: send installment schedule.',
    true,
    '{"demo":true,"persona":"active_buyer"}'::jsonb
  ),
  (
    'a1000000-0000-4000-8000-000000000003',
    'CRM-INV-003',
    'Horizon Capital Partners',
    'deals@horizoncapital.example',
    '+2348010000003',
    '+2348010000003',
    'investor',
    'investor',
    'Nigerian',
    'en',
    'Investment Director',
    'Horizon Capital',
    'Private Equity',
    150000000,
    500000000,
    ARRAY['Port Harcourt','Lekki','Abuja'],
    85,
    'excellent',
    82,
    'Institutional investor evaluating penthouse and multi-unit tranches. Focus on ROI, yield, and title clarity.',
    false,
    '{"demo":true,"persona":"investor"}'::jsonb
  )
ON CONFLICT (client_code) DO UPDATE SET
  full_name = EXCLUDED.full_name,
  email = EXCLUDED.email,
  relationship_status = EXCLUDED.relationship_status,
  health_score = EXCLUDED.health_score,
  health_label = EXCLUDED.health_label,
  lead_score = EXCLUDED.lead_score,
  ai_summary = EXCLUDED.ai_summary,
  updated_at = now();

INSERT INTO public.crm_preferences (
  client_id, preferred_property_types, bedrooms, amenities, payment_plan_pref, investment_goals
) VALUES
  ('a1000000-0000-4000-8000-000000000001', ARRAY['duplex','maisonette'], 4, ARRAY['Pool','Security','Backup Power'], 'outright', 'Primary residence + prestige'),
  ('a1000000-0000-4000-8000-000000000002', ARRAY['apartment'], 3, ARRAY['Gym','Parking','CCTV'], '12_month', 'Family home close to work'),
  ('a1000000-0000-4000-8000-000000000003', ARRAY['penthouse','apartment'], 5, ARRAY['Concierge','Waterfront','Smart Home'], 'tranche', 'Portfolio yield 12%+ IRR')
ON CONFLICT (client_id) DO UPDATE SET
  preferred_property_types = EXCLUDED.preferred_property_types,
  bedrooms = EXCLUDED.bedrooms,
  amenities = EXCLUDED.amenities,
  payment_plan_pref = EXCLUDED.payment_plan_pref,
  investment_goals = EXCLUDED.investment_goals,
  updated_at = now();

INSERT INTO public.crm_health_scores (client_id, score, label, breakdown, computed_at) VALUES
  ('a1000000-0000-4000-8000-000000000001', 92, 'vip', '{"engagement":95,"recency":90,"pipeline":92,"referrals":88}'::jsonb, now()),
  ('a1000000-0000-4000-8000-000000000002', 78, 'healthy', '{"engagement":80,"recency":75,"pipeline":78,"referrals":60}'::jsonb, now()),
  ('a1000000-0000-4000-8000-000000000003', 85, 'excellent', '{"engagement":82,"recency":88,"pipeline":85,"referrals":70}'::jsonb, now())
ON CONFLICT (client_id) DO UPDATE SET
  score = EXCLUDED.score,
  label = EXCLUDED.label,
  breakdown = EXCLUDED.breakdown,
  computed_at = now();

INSERT INTO public.crm_customer_success (
  client_id, satisfaction_score, referral_count, repeat_purchases, loyalty_status, notes
) VALUES
  ('a1000000-0000-4000-8000-000000000001', 9.2, 2, 0, 'gold', 'VIP nurturing track'),
  ('a1000000-0000-4000-8000-000000000002', 8.1, 0, 0, 'silver', 'Active buyer path'),
  ('a1000000-0000-4000-8000-000000000003', 8.8, 1, 1, 'platinum', 'Repeat investor interest')
ON CONFLICT (client_id) DO UPDATE SET
  satisfaction_score = EXCLUDED.satisfaction_score,
  referral_count = EXCLUDED.referral_count,
  repeat_purchases = EXCLUDED.repeat_purchases,
  loyalty_status = EXCLUDED.loyalty_status,
  notes = EXCLUDED.notes,
  updated_at = now();

-- Leads (idempotent by title+client)
INSERT INTO public.crm_leads (
  id, client_id, source_id, stage_id, title, status, priority,
  conversion_probability, estimated_value, notes, captured_at
)
SELECT
  'b1000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  s.id,
  st.id,
  'Victoria Crest Duplex — VIP inquiry',
  'qualified',
  'urgent',
  82,
  145000000,
  'Hot VIP lead from WhatsApp after open house.',
  now() - interval '2 days'
FROM public.crm_lead_sources s, public.crm_pipeline_stages st
WHERE s.slug = 'whatsapp' AND st.slug = 'negotiation'
  AND NOT EXISTS (
    SELECT 1 FROM public.crm_leads l
    WHERE l.id = 'b1000000-0000-4000-8000-000000000001'
  );

INSERT INTO public.crm_leads (
  id, client_id, source_id, stage_id, title, status, priority,
  conversion_probability, estimated_value, notes, captured_at
)
SELECT
  'b1000000-0000-4000-8000-000000000002',
  'a1000000-0000-4000-8000-000000000002',
  s.id,
  st.id,
  'Azure Court 3-Bed payment plan',
  'open',
  'high',
  58,
  68000000,
  'Requested 12-month installment schedule.',
  now() - interval '5 days'
FROM public.crm_lead_sources s, public.crm_pipeline_stages st
WHERE s.slug = 'website' AND st.slug = 'site_visit'
  AND NOT EXISTS (
    SELECT 1 FROM public.crm_leads l
    WHERE l.id = 'b1000000-0000-4000-8000-000000000002'
  );

INSERT INTO public.crm_leads (
  id, client_id, source_id, stage_id, title, status, priority,
  conversion_probability, estimated_value, notes, captured_at
)
SELECT
  'b1000000-0000-4000-8000-000000000003',
  'a1000000-0000-4000-8000-000000000003',
  s.id,
  st.id,
  'Harbour View investor tranche',
  'qualified',
  'high',
  65,
  220000000,
  'Evaluating PH penthouse for fund allocation.',
  now() - interval '8 days'
FROM public.crm_lead_sources s, public.crm_pipeline_stages st
WHERE s.slug = 'referral' AND st.slug = 'qualified'
  AND NOT EXISTS (
    SELECT 1 FROM public.crm_leads l
    WHERE l.id = 'b1000000-0000-4000-8000-000000000003'
  );

INSERT INTO public.crm_pipeline_history (lead_id, from_stage_id, to_stage_id, notes, changed_at)
SELECT l.id, f.id, t.id, 'Moved to negotiation after site tour', now() - interval '1 day'
FROM public.crm_leads l
JOIN public.crm_pipeline_stages f ON f.slug = 'site_visit'
JOIN public.crm_pipeline_stages t ON t.slug = 'negotiation'
WHERE l.id = 'b1000000-0000-4000-8000-000000000001'
  AND NOT EXISTS (
    SELECT 1 FROM public.crm_pipeline_history h WHERE h.lead_id = l.id
  );

INSERT INTO public.crm_tasks (
  id, client_id, lead_id, title, task_type, priority, status, due_at
)
SELECT * FROM (VALUES
  (
    'c1000000-0000-4000-8000-000000000001'::uuid,
    'a1000000-0000-4000-8000-000000000001'::uuid,
    'b1000000-0000-4000-8000-000000000001'::uuid,
    'Call Adaeze — confirm duplex offer letter',
    'call',
    'urgent',
    'open',
    now() + interval '4 hours'
  ),
  (
    'c1000000-0000-4000-8000-000000000002'::uuid,
    'a1000000-0000-4000-8000-000000000002'::uuid,
    'b1000000-0000-4000-8000-000000000002'::uuid,
    'Send installment schedule PDF',
    'email',
    'high',
    'open',
    now() + interval '1 day'
  ),
  (
    'c1000000-0000-4000-8000-000000000003'::uuid,
    'a1000000-0000-4000-8000-000000000003'::uuid,
    'b1000000-0000-4000-8000-000000000003'::uuid,
    'Prepare investor ROI pack — Harbour View',
    'follow_up',
    'medium',
    'in_progress',
    now() + interval '2 days'
  )
) AS v(id, client_id, lead_id, title, task_type, priority, status, due_at)
WHERE NOT EXISTS (SELECT 1 FROM public.crm_tasks t WHERE t.id = v.id);

INSERT INTO public.crm_appointments (
  id, client_id, appointment_type, title, scheduled_at, location, status
)
SELECT * FROM (VALUES
  (
    'd1000000-0000-4000-8000-000000000001'::uuid,
    'a1000000-0000-4000-8000-000000000001'::uuid,
    'site_visit',
    'VIP site visit — Victoria Crest',
    now() + interval '1 day',
    'Victoria Crest Sales Gallery, Lekki',
    'confirmed'
  ),
  (
    'd1000000-0000-4000-8000-000000000002'::uuid,
    'a1000000-0000-4000-8000-000000000002'::uuid,
    'meeting',
    'Payment plan review — Chuka',
    now() + interval '2 days',
    'HD Homes HQ',
    'scheduled'
  ),
  (
    'd1000000-0000-4000-8000-000000000003'::uuid,
    'a1000000-0000-4000-8000-000000000003'::uuid,
    'investor_briefing',
    'Horizon Capital investor briefing',
    now() + interval '3 days',
    'Virtual',
    'scheduled'
  )
) AS v(id, client_id, appointment_type, title, scheduled_at, location, status)
WHERE NOT EXISTS (SELECT 1 FROM public.crm_appointments a WHERE a.id = v.id);

-- Link appointments to a property when any exists
UPDATE public.crm_appointments a
SET property_id = p.id
FROM (
  SELECT id FROM public.properties ORDER BY created_at NULLS LAST LIMIT 1
) p
WHERE a.id = 'd1000000-0000-4000-8000-000000000001'
  AND a.property_id IS NULL;

INSERT INTO public.crm_activity_logs (client_id, event_type, title, description, payload, occurred_at)
SELECT v.client_id, v.event_type, v.title, v.description, v.payload, v.occurred_at
FROM (VALUES
  (
    'a1000000-0000-4000-8000-000000000001'::uuid,
    'lead_created',
    'VIP lead captured',
    'WhatsApp inbound after open house.',
    '{"channel":"whatsapp"}'::jsonb,
    now() - interval '2 days'
  ),
  (
    'a1000000-0000-4000-8000-000000000001'::uuid,
    'stage_change',
    'Moved to Negotiation',
    'Post site-tour conversion boost.',
    '{"to":"negotiation"}'::jsonb,
    now() - interval '1 day'
  ),
  (
    'a1000000-0000-4000-8000-000000000002'::uuid,
    'task_created',
    'Installment schedule requested',
    'Client asked for 12-month plan.',
    '{}'::jsonb,
    now() - interval '5 days'
  ),
  (
    'a1000000-0000-4000-8000-000000000002'::uuid,
    'appointment_set',
    'Payment plan meeting booked',
    'HQ meeting in 2 days.',
    '{}'::jsonb,
    now() - interval '6 hours'
  ),
  (
    'a1000000-0000-4000-8000-000000000003'::uuid,
    'note',
    'Investor diligence started',
    'Title pack + yield model requested.',
    '{"persona":"investor"}'::jsonb,
    now() - interval '8 days'
  )
) AS v(client_id, event_type, title, description, payload, occurred_at)
WHERE NOT EXISTS (
  SELECT 1 FROM public.crm_activity_logs a
  WHERE a.client_id = v.client_id AND a.event_type = v.event_type AND a.title = v.title
);

INSERT INTO public.crm_followups (client_id, reason, due_at, status)
SELECT v.client_id, v.reason, v.due_at, v.status
FROM (VALUES
  ('a1000000-0000-4000-8000-000000000001'::uuid, 'Send offer letter draft', now() + interval '6 hours', 'pending'),
  ('a1000000-0000-4000-8000-000000000002'::uuid, 'Confirm site visit attendance', now() + interval '30 hours', 'pending')
) AS v(client_id, reason, due_at, status)
WHERE NOT EXISTS (
  SELECT 1 FROM public.crm_followups f
  WHERE f.client_id = v.client_id AND f.reason = v.reason
);

INSERT INTO public.crm_client_tags (client_id, tag_id)
SELECT 'a1000000-0000-4000-8000-000000000001', t.id
FROM public.crm_tags t WHERE t.slug IN ('hot','vip','lekki')
ON CONFLICT DO NOTHING;

INSERT INTO public.crm_client_tags (client_id, tag_id)
SELECT 'a1000000-0000-4000-8000-000000000003', t.id
FROM public.crm_tags t WHERE t.slug = 'investor'
ON CONFLICT DO NOTHING;

INSERT INTO public.crm_referrals (referrer_client_id, referred_client_id, code, status, reward_amount)
SELECT
  'a1000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000002',
  'REF-ADA-CHU-01',
  'qualified',
  250000
WHERE NOT EXISTS (
  SELECT 1 FROM public.crm_referrals r WHERE r.code = 'REF-ADA-CHU-01'
);

INSERT INTO public.crm_communications (
  client_id, channel, direction, subject, body, occurred_at
)
SELECT v.client_id, v.channel, v.direction, v.subject, v.body, v.occurred_at
FROM (VALUES
  (
    'a1000000-0000-4000-8000-000000000001'::uuid,
    'whatsapp',
    'inbound',
    NULL::text,
    'Interested in the Victoria Crest duplex viewed on Saturday.',
    now() - interval '2 days'
  ),
  (
    'a1000000-0000-4000-8000-000000000002'::uuid,
    'email',
    'outbound',
    'Your Azure Court payment plan options',
    'Sharing three installment schedules for review.',
    now() - interval '1 day'
  )
) AS v(client_id, channel, direction, subject, body, occurred_at)
WHERE NOT EXISTS (
  SELECT 1 FROM public.crm_communications c
  WHERE c.client_id = v.client_id AND c.channel = v.channel AND c.body = v.body
);

-- Property matches only when properties exist
INSERT INTO public.crm_property_matches (client_id, property_id, match_score, reason, status)
SELECT
  'a1000000-0000-4000-8000-000000000001',
  p.id,
  91,
  'Budget + location + bed count alignment',
  'interested'
FROM public.properties p
ORDER BY p.created_at NULLS LAST
LIMIT 1
ON CONFLICT (client_id, property_id) DO NOTHING;

INSERT INTO public.crm_property_matches (client_id, property_id, match_score, reason, status)
SELECT
  'a1000000-0000-4000-8000-000000000002',
  p.id,
  84,
  '3-bed preference + payment plan fit',
  'suggested'
FROM public.properties p
ORDER BY p.created_at NULLS LAST
OFFSET 1 LIMIT 1
ON CONFLICT (client_id, property_id) DO NOTHING;

INSERT INTO public.crm_campaign_memberships (segment_id, client_id, campaign_key, status)
SELECT s.id, 'a1000000-0000-4000-8000-000000000001', 'vip-spring-push', 'active'
FROM public.crm_segments s
WHERE s.slug = 'vip-buyers'
  AND NOT EXISTS (
    SELECT 1 FROM public.crm_campaign_memberships m
    WHERE m.client_id = 'a1000000-0000-4000-8000-000000000001'
      AND m.campaign_key = 'vip-spring-push'
  );

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.crm_lead_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_pipeline_stages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_pipeline_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_client_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_referral_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_communications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_health_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_followups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_property_matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_customer_success ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_segments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_campaign_memberships ENABLE ROW LEVEL SECURITY;

-- Catalogs: read for crm.read, write for crm.write
DROP POLICY IF EXISTS crm_lead_sources_select ON public.crm_lead_sources;
CREATE POLICY crm_lead_sources_select ON public.crm_lead_sources FOR SELECT TO authenticated
  USING (public.has_permission('crm.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
DROP POLICY IF EXISTS crm_lead_sources_write ON public.crm_lead_sources;
CREATE POLICY crm_lead_sources_write ON public.crm_lead_sources FOR ALL TO authenticated
  USING (public.has_permission('crm.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('crm.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS crm_pipeline_stages_select ON public.crm_pipeline_stages;
CREATE POLICY crm_pipeline_stages_select ON public.crm_pipeline_stages FOR SELECT TO authenticated
  USING (public.has_permission('crm.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
DROP POLICY IF EXISTS crm_pipeline_stages_write ON public.crm_pipeline_stages;
CREATE POLICY crm_pipeline_stages_write ON public.crm_pipeline_stages FOR ALL TO authenticated
  USING (public.has_permission('crm.pipeline', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('crm.pipeline', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS crm_clients_select ON public.crm_clients;
CREATE POLICY crm_clients_select ON public.crm_clients FOR SELECT TO authenticated
  USING (public.has_permission('crm.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
DROP POLICY IF EXISTS crm_clients_write ON public.crm_clients;
CREATE POLICY crm_clients_write ON public.crm_clients FOR ALL TO authenticated
  USING (public.has_permission('crm.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('crm.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS crm_leads_select ON public.crm_leads;
CREATE POLICY crm_leads_select ON public.crm_leads FOR SELECT TO authenticated
  USING (
    public.has_permission('crm.read', auth.uid())
    OR public.has_permission('crm.leads', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
DROP POLICY IF EXISTS crm_leads_write ON public.crm_leads;
CREATE POLICY crm_leads_write ON public.crm_leads FOR ALL TO authenticated
  USING (public.has_permission('crm.leads', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('crm.leads', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS crm_pipeline_history_select ON public.crm_pipeline_history;
CREATE POLICY crm_pipeline_history_select ON public.crm_pipeline_history FOR SELECT TO authenticated
  USING (
    public.has_permission('crm.read', auth.uid())
    OR public.has_permission('crm.pipeline', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
DROP POLICY IF EXISTS crm_pipeline_history_write ON public.crm_pipeline_history;
CREATE POLICY crm_pipeline_history_write ON public.crm_pipeline_history FOR ALL TO authenticated
  USING (public.has_permission('crm.pipeline', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('crm.pipeline', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS crm_tasks_select ON public.crm_tasks;
CREATE POLICY crm_tasks_select ON public.crm_tasks FOR SELECT TO authenticated
  USING (
    public.has_permission('crm.read', auth.uid())
    OR public.has_permission('crm.tasks', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
DROP POLICY IF EXISTS crm_tasks_write ON public.crm_tasks;
CREATE POLICY crm_tasks_write ON public.crm_tasks FOR ALL TO authenticated
  USING (public.has_permission('crm.tasks', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('crm.tasks', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS crm_appointments_select ON public.crm_appointments;
CREATE POLICY crm_appointments_select ON public.crm_appointments FOR SELECT TO authenticated
  USING (public.has_permission('crm.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
DROP POLICY IF EXISTS crm_appointments_write ON public.crm_appointments;
CREATE POLICY crm_appointments_write ON public.crm_appointments FOR ALL TO authenticated
  USING (public.has_permission('crm.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('crm.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS crm_notes_select ON public.crm_notes;
CREATE POLICY crm_notes_select ON public.crm_notes FOR SELECT TO authenticated
  USING (public.has_permission('crm.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
DROP POLICY IF EXISTS crm_notes_write ON public.crm_notes;
CREATE POLICY crm_notes_write ON public.crm_notes FOR ALL TO authenticated
  USING (public.has_permission('crm.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('crm.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS crm_tags_select ON public.crm_tags;
CREATE POLICY crm_tags_select ON public.crm_tags FOR SELECT TO authenticated
  USING (public.has_permission('crm.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
DROP POLICY IF EXISTS crm_tags_write ON public.crm_tags;
CREATE POLICY crm_tags_write ON public.crm_tags FOR ALL TO authenticated
  USING (public.has_permission('crm.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('crm.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS crm_client_tags_select ON public.crm_client_tags;
CREATE POLICY crm_client_tags_select ON public.crm_client_tags FOR SELECT TO authenticated
  USING (public.has_permission('crm.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
DROP POLICY IF EXISTS crm_client_tags_write ON public.crm_client_tags;
CREATE POLICY crm_client_tags_write ON public.crm_client_tags FOR ALL TO authenticated
  USING (public.has_permission('crm.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('crm.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS crm_referrals_select ON public.crm_referrals;
CREATE POLICY crm_referrals_select ON public.crm_referrals FOR SELECT TO authenticated
  USING (public.has_permission('crm.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
DROP POLICY IF EXISTS crm_referrals_write ON public.crm_referrals;
CREATE POLICY crm_referrals_write ON public.crm_referrals FOR ALL TO authenticated
  USING (public.has_permission('crm.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('crm.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS crm_referral_rewards_select ON public.crm_referral_rewards;
CREATE POLICY crm_referral_rewards_select ON public.crm_referral_rewards FOR SELECT TO authenticated
  USING (public.has_permission('crm.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
DROP POLICY IF EXISTS crm_referral_rewards_write ON public.crm_referral_rewards;
CREATE POLICY crm_referral_rewards_write ON public.crm_referral_rewards FOR ALL TO authenticated
  USING (public.has_permission('crm.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('crm.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS crm_communications_select ON public.crm_communications;
CREATE POLICY crm_communications_select ON public.crm_communications FOR SELECT TO authenticated
  USING (
    public.has_permission('crm.read', auth.uid())
    OR public.has_permission('crm.communications', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
DROP POLICY IF EXISTS crm_communications_write ON public.crm_communications;
CREATE POLICY crm_communications_write ON public.crm_communications FOR ALL TO authenticated
  USING (public.has_permission('crm.communications', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('crm.communications', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS crm_documents_select ON public.crm_documents;
CREATE POLICY crm_documents_select ON public.crm_documents FOR SELECT TO authenticated
  USING (
    public.has_permission('crm.read', auth.uid())
    OR public.has_permission('crm.documents', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
DROP POLICY IF EXISTS crm_documents_write ON public.crm_documents;
CREATE POLICY crm_documents_write ON public.crm_documents FOR ALL TO authenticated
  USING (public.has_permission('crm.documents', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('crm.documents', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS crm_preferences_select ON public.crm_preferences;
CREATE POLICY crm_preferences_select ON public.crm_preferences FOR SELECT TO authenticated
  USING (public.has_permission('crm.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
DROP POLICY IF EXISTS crm_preferences_write ON public.crm_preferences;
CREATE POLICY crm_preferences_write ON public.crm_preferences FOR ALL TO authenticated
  USING (public.has_permission('crm.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('crm.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS crm_health_scores_select ON public.crm_health_scores;
CREATE POLICY crm_health_scores_select ON public.crm_health_scores FOR SELECT TO authenticated
  USING (
    public.has_permission('crm.read', auth.uid())
    OR public.has_permission('crm.analytics', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
DROP POLICY IF EXISTS crm_health_scores_write ON public.crm_health_scores;
CREATE POLICY crm_health_scores_write ON public.crm_health_scores FOR ALL TO authenticated
  USING (public.has_permission('crm.analytics', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('crm.analytics', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS crm_followups_select ON public.crm_followups;
CREATE POLICY crm_followups_select ON public.crm_followups FOR SELECT TO authenticated
  USING (
    public.has_permission('crm.read', auth.uid())
    OR public.has_permission('crm.tasks', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
DROP POLICY IF EXISTS crm_followups_write ON public.crm_followups;
CREATE POLICY crm_followups_write ON public.crm_followups FOR ALL TO authenticated
  USING (public.has_permission('crm.tasks', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('crm.tasks', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS crm_activity_logs_select ON public.crm_activity_logs;
CREATE POLICY crm_activity_logs_select ON public.crm_activity_logs FOR SELECT TO authenticated
  USING (public.has_permission('crm.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
DROP POLICY IF EXISTS crm_activity_logs_write ON public.crm_activity_logs;
CREATE POLICY crm_activity_logs_write ON public.crm_activity_logs FOR ALL TO authenticated
  USING (public.has_permission('crm.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('crm.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS crm_property_matches_select ON public.crm_property_matches;
CREATE POLICY crm_property_matches_select ON public.crm_property_matches FOR SELECT TO authenticated
  USING (public.has_permission('crm.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
DROP POLICY IF EXISTS crm_property_matches_write ON public.crm_property_matches;
CREATE POLICY crm_property_matches_write ON public.crm_property_matches FOR ALL TO authenticated
  USING (public.has_permission('crm.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('crm.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS crm_customer_success_select ON public.crm_customer_success;
CREATE POLICY crm_customer_success_select ON public.crm_customer_success FOR SELECT TO authenticated
  USING (
    public.has_permission('crm.read', auth.uid())
    OR public.has_permission('crm.analytics', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
DROP POLICY IF EXISTS crm_customer_success_write ON public.crm_customer_success;
CREATE POLICY crm_customer_success_write ON public.crm_customer_success FOR ALL TO authenticated
  USING (public.has_permission('crm.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('crm.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS crm_segments_select ON public.crm_segments;
CREATE POLICY crm_segments_select ON public.crm_segments FOR SELECT TO authenticated
  USING (public.has_permission('crm.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
DROP POLICY IF EXISTS crm_segments_write ON public.crm_segments;
CREATE POLICY crm_segments_write ON public.crm_segments FOR ALL TO authenticated
  USING (public.has_permission('crm.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('crm.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS crm_campaign_memberships_select ON public.crm_campaign_memberships;
CREATE POLICY crm_campaign_memberships_select ON public.crm_campaign_memberships FOR SELECT TO authenticated
  USING (public.has_permission('crm.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
DROP POLICY IF EXISTS crm_campaign_memberships_write ON public.crm_campaign_memberships;
CREATE POLICY crm_campaign_memberships_write ON public.crm_campaign_memberships FOR ALL TO authenticated
  USING (public.has_permission('crm.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('crm.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

-- Realtime publication
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'crm_clients','crm_leads','crm_tasks','crm_appointments','crm_activity_logs',
    'crm_pipeline_history','crm_communications','crm_health_scores','crm_followups',
    'crm_property_matches','crm_notes'
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

-- Status: APPLIED remotely 2026-07-14 (chunked apply_migration p1–p4).
