-- HD Homes Support Phase 2 — production database foundation.
-- Extends the existing support system; does not create a second ticket/chat stack.

-- ---------------------------------------------------------------------------
-- Ticket lifecycle and customer classification
-- ---------------------------------------------------------------------------
ALTER TABLE public.tickets
  ADD COLUMN IF NOT EXISTS customer_type text,
  ADD COLUMN IF NOT EXISTS last_customer_response_at timestamptz,
  ADD COLUMN IF NOT EXISTS last_agent_response_at timestamptz,
  ADD COLUMN IF NOT EXISTS waiting_since timestamptz,
  ADD COLUMN IF NOT EXISTS reopened_at timestamptz,
  ADD COLUMN IF NOT EXISTS resolution_confirmed_at timestamptz;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'tickets_customer_type_check'
  ) THEN
    ALTER TABLE public.tickets
      ADD CONSTRAINT tickets_customer_type_check
      CHECK (
        customer_type IS NULL
        OR customer_type IN ('website_visitor', 'client', 'investor')
      );
  END IF;
END $$;

-- All ticket creation paths receive a stable public ticket number.
CREATE SEQUENCE IF NOT EXISTS public.support_ticket_number_seq START WITH 1106;

DO $$
DECLARE
  v_max bigint;
BEGIN
  SELECT max((regexp_match(ticket_number, '([0-9]+)$'))[1]::bigint)
  INTO v_max
  FROM public.tickets
  WHERE ticket_number ~ '^HD-T-[0-9]{4}-[0-9]+$';

  IF v_max IS NOT NULL THEN
    PERFORM setval(
      'public.support_ticket_number_seq',
      GREATEST(
        v_max,
        (SELECT last_value FROM public.support_ticket_number_seq)
      ),
      true
    );
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.ensure_support_ticket_number()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.ticket_number IS NULL OR btrim(NEW.ticket_number) = '' THEN
    NEW.ticket_number :=
      'HD-T-' || to_char(COALESCE(NEW.created_at, now()), 'YYYY') || '-' ||
      lpad(nextval('public.support_ticket_number_seq')::text, 4, '0');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_tickets_ensure_number ON public.tickets;
CREATE TRIGGER trg_tickets_ensure_number
BEFORE INSERT ON public.tickets
FOR EACH ROW EXECUTE FUNCTION public.ensure_support_ticket_number();

UPDATE public.tickets
SET ticket_number =
  'HD-T-' || to_char(created_at, 'YYYY') || '-' ||
  lpad(nextval('public.support_ticket_number_seq')::text, 4, '0')
WHERE ticket_number IS NULL OR btrim(ticket_number) = '';

-- ---------------------------------------------------------------------------
-- Cross-domain context without duplicating CRM/property/finance records
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.support_ticket_links (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id uuid NOT NULL REFERENCES public.tickets(id) ON DELETE CASCADE,
  entity_type text NOT NULL CHECK (
    entity_type IN (
      'crm_lead', 'crm_client', 'client', 'investor', 'property', 'estate',
      'application', 'payment', 'inspection', 'construction_project',
      'document', 'investment', 'portfolio'
    )
  ),
  entity_id uuid NOT NULL,
  label text,
  resource_url text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (ticket_id, entity_type, entity_id)
);

CREATE INDEX IF NOT EXISTS idx_support_ticket_links_entity
  ON public.support_ticket_links (entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_support_ticket_links_ticket
  ON public.support_ticket_links (ticket_id, created_at DESC);

-- Immutable lifecycle/audit event stream. UI activity can be derived from this.
CREATE TABLE IF NOT EXISTS public.support_ticket_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id uuid NOT NULL REFERENCES public.tickets(id) ON DELETE CASCADE,
  actor_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  actor_label text,
  action text NOT NULL CHECK (
    action IN (
      'created', 'assigned', 'reassigned', 'unassigned', 'status_changed',
      'priority_changed', 'customer_replied', 'agent_replied',
      'internal_note_created', 'attachment_added', 'escalated',
      'resolved', 'resolution_confirmed', 'closed', 'reopened'
    )
  ),
  from_status text,
  to_status text,
  from_priority text,
  to_priority text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_support_ticket_events_ticket_created
  ON public.support_ticket_events (ticket_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_support_ticket_events_action_created
  ON public.support_ticket_events (action, created_at DESC);

-- ---------------------------------------------------------------------------
-- Configurable operating hours, rules and quick replies
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.support_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  timezone text NOT NULL DEFAULT 'Africa/Lagos',
  welcome_message text NOT NULL DEFAULT
    'Hello 👋 Welcome to HD Homes. How can we help you today?',
  offline_message text NOT NULL DEFAULT
    'Our support team is currently offline. Leave a message and we will get back to you as soon as possible.',
  business_hours_enabled boolean NOT NULL DEFAULT true,
  offline_ticket_enabled boolean NOT NULL DEFAULT true,
  auto_assignment_enabled boolean NOT NULL DEFAULT false,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS support_settings_singleton_idx
  ON public.support_settings ((true));

INSERT INTO public.support_settings (id)
SELECT gen_random_uuid()
WHERE NOT EXISTS (SELECT 1 FROM public.support_settings);

CREATE TABLE IF NOT EXISTS public.support_operating_hours (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  day_of_week smallint NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  is_open boolean NOT NULL DEFAULT false,
  opens_at time,
  closes_at time,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (day_of_week),
  CHECK (
    (is_open = false)
    OR (opens_at IS NOT NULL AND closes_at IS NOT NULL AND opens_at < closes_at)
  )
);

INSERT INTO public.support_operating_hours (
  day_of_week, is_open, opens_at, closes_at
)
SELECT d, false, NULL, NULL
FROM generate_series(0, 6) AS d
ON CONFLICT (day_of_week) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.support_holidays (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  holiday_date date NOT NULL UNIQUE,
  name text NOT NULL,
  is_closed boolean NOT NULL DEFAULT true,
  opens_at time,
  closes_at time,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (
    is_closed
    OR (opens_at IS NOT NULL AND closes_at IS NOT NULL AND opens_at < closes_at)
  )
);

CREATE TABLE IF NOT EXISTS public.support_quick_replies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  shortcut text NOT NULL UNIQUE,
  body text NOT NULL,
  category_id uuid REFERENCES public.support_categories(id) ON DELETE SET NULL,
  team_id uuid REFERENCES public.support_teams(id) ON DELETE SET NULL,
  is_active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 100,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_support_quick_replies_active
  ON public.support_quick_replies (is_active, sort_order, title);

CREATE TABLE IF NOT EXISTS public.support_assignment_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  rank integer NOT NULL DEFAULT 100,
  is_enabled boolean NOT NULL DEFAULT false,
  category_id uuid REFERENCES public.support_categories(id) ON DELETE SET NULL,
  customer_type text CHECK (
    customer_type IS NULL
    OR customer_type IN ('website_visitor', 'client', 'investor')
  ),
  channel text,
  priority text,
  team_id uuid REFERENCES public.support_teams(id) ON DELETE SET NULL,
  queue_id uuid REFERENCES public.support_queues(id) ON DELETE SET NULL,
  conditions jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_support_assignment_rules_enabled_rank
  ON public.support_assignment_rules (is_enabled, rank);

-- ---------------------------------------------------------------------------
-- Delivery/read foundation for all existing real-time message channels
-- ---------------------------------------------------------------------------
ALTER TABLE public.ticket_messages
  ADD COLUMN IF NOT EXISTS client_message_id text,
  ADD COLUMN IF NOT EXISTS delivery_status text NOT NULL DEFAULT 'sent',
  ADD COLUMN IF NOT EXISTS delivered_at timestamptz,
  ADD COLUMN IF NOT EXISTS read_at timestamptz,
  ADD COLUMN IF NOT EXISTS failed_at timestamptz;

ALTER TABLE public.live_chat_messages
  ADD COLUMN IF NOT EXISTS client_message_id text,
  ADD COLUMN IF NOT EXISTS delivery_status text NOT NULL DEFAULT 'sent',
  ADD COLUMN IF NOT EXISTS delivered_at timestamptz,
  ADD COLUMN IF NOT EXISTS read_at timestamptz,
  ADD COLUMN IF NOT EXISTS failed_at timestamptz,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

ALTER TABLE public.client_conversation_messages
  ADD COLUMN IF NOT EXISTS client_message_id text,
  ADD COLUMN IF NOT EXISTS delivery_status text NOT NULL DEFAULT 'sent',
  ADD COLUMN IF NOT EXISTS delivered_at timestamptz,
  ADD COLUMN IF NOT EXISTS failed_at timestamptz;

ALTER TABLE public.investor_conversation_messages
  ADD COLUMN IF NOT EXISTS client_message_id text,
  ADD COLUMN IF NOT EXISTS delivery_status text NOT NULL DEFAULT 'sent',
  ADD COLUMN IF NOT EXISTS delivered_at timestamptz,
  ADD COLUMN IF NOT EXISTS failed_at timestamptz;

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'ticket_messages',
    'live_chat_messages',
    'client_conversation_messages',
    'investor_conversation_messages'
  ]
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_constraint
      WHERE conname = t || '_delivery_status_check'
    ) THEN
      EXECUTE format(
        'ALTER TABLE public.%I ADD CONSTRAINT %I CHECK
         (delivery_status IN (''sending'',''sent'',''delivered'',''read'',''failed''))',
        t,
        t || '_delivery_status_check'
      );
    END IF;
  END LOOP;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS idx_ticket_messages_client_id
  ON public.ticket_messages (client_message_id)
  WHERE client_message_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_live_chat_messages_client_id
  ON public.live_chat_messages (client_message_id)
  WHERE client_message_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_client_messages_client_id
  ON public.client_conversation_messages (client_message_id)
  WHERE client_message_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_investor_messages_client_id
  ON public.investor_conversation_messages (client_message_id)
  WHERE client_message_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- Consistent created_at/updated_at metadata for existing support tables
-- ---------------------------------------------------------------------------
ALTER TABLE public.support_assignments
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
UPDATE public.support_assignments
SET created_at = assigned_at
WHERE created_at IS DISTINCT FROM assigned_at;

ALTER TABLE public.support_activity_logs
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
UPDATE public.support_activity_logs
SET created_at = occurred_at
WHERE created_at IS DISTINCT FROM occurred_at;

ALTER TABLE public.support_categories
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.support_priorities
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.support_statuses
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.support_queues
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.support_slas
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.support_escalations
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.support_ticket_attachments
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.support_ticket_notes
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.support_notifications
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

-- Existing shared trigger helper maintains every mutable support record.
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'tickets', 'ticket_messages', 'live_chat_sessions', 'live_chat_messages',
    'client_conversations', 'client_conversation_messages',
    'investor_conversations', 'investor_conversation_messages',
    'support_agents', 'support_teams', 'support_queues', 'support_categories',
    'support_priorities', 'support_statuses', 'support_slas',
    'support_escalations', 'support_assignments', 'support_ticket_attachments',
    'support_ticket_notes', 'support_activity_logs', 'support_notifications',
    'support_knowledge_articles', 'support_ticket_links',
    'support_ticket_events', 'support_settings', 'support_operating_hours',
    'support_holidays', 'support_quick_replies', 'support_assignment_rules'
  ]
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON public.%I',
      'trg_' || t || '_updated_at', t);
    EXECUTE format(
      'CREATE TRIGGER %I BEFORE UPDATE ON public.%I
       FOR EACH ROW EXECUTE FUNCTION public.set_updated_at()',
      'trg_' || t || '_updated_at', t
    );
  END LOOP;
END $$;

-- New tables are deny-by-default until Phase 3 installs explicit policies.
ALTER TABLE public.support_ticket_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_ticket_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_operating_hours ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_holidays ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_quick_replies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_assignment_rules ENABLE ROW LEVEL SECURITY;

-- Realtime only for state that must update immediately in staff/customer UIs.
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'support_ticket_events',
    'support_settings',
    'support_operating_hours',
    'support_holidays',
    'support_quick_replies',
    'support_assignment_rules'
  ]
  LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = t
    ) THEN
      EXECUTE format(
        'ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',
        t
      );
    END IF;
  END LOOP;
END $$;

COMMENT ON TABLE public.support_ticket_links IS
  'Links existing tickets to CRM, property, finance, inspection, construction, document and portal records without duplicating source data.';
COMMENT ON TABLE public.support_ticket_events IS
  'Append-oriented ticket lifecycle and audit timeline.';
COMMENT ON TABLE public.support_assignment_rules IS
  'Disabled-by-default configurable routing rules; automation is implemented in a later phase.';
