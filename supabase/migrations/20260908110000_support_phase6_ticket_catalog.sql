-- Phase 6: canonical ticket fields, catalogs and lifecycle timestamps.
ALTER TABLE public.tickets
  ADD COLUMN IF NOT EXISTS estate_id uuid
    REFERENCES public.estates(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS source text NOT NULL DEFAULT 'support';

CREATE INDEX IF NOT EXISTS idx_tickets_estate
  ON public.tickets (estate_id) WHERE estate_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_tickets_customer_type_status
  ON public.tickets (customer_type, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_tickets_assignee_status
  ON public.tickets (assigned_to, status, created_at DESC)
  WHERE assigned_to IS NOT NULL;

UPDATE public.tickets
SET
  status = CASE WHEN status = 'pending_customer'
    THEN 'waiting_for_customer' ELSE status END,
  source = COALESCE(NULLIF(metadata->>'source', ''), channel, 'support'),
  customer_type = COALESCE(customer_type, CASE
    WHEN user_id IS NULL THEN 'website_visitor'
    WHEN EXISTS (
      SELECT 1 FROM public.investors i WHERE i.user_id = tickets.user_id
    ) THEN 'investor'
    ELSE 'client'
  END);

UPDATE public.support_statuses
SET slug = 'waiting_for_customer', name = 'Waiting for Customer'
WHERE slug = 'pending_customer';

INSERT INTO public.support_statuses
  (id, slug, name, category, is_terminal, sort_order, is_active)
SELECT gen_random_uuid(), 'new', 'New', 'open', false, 5, true
WHERE NOT EXISTS (SELECT 1 FROM public.support_statuses WHERE slug = 'new');

INSERT INTO public.support_statuses
  (id, slug, name, category, is_terminal, sort_order, is_active)
SELECT gen_random_uuid(), 'waiting_for_hd_homes', 'Waiting for HD Homes',
  'pending', false, 35, true
WHERE NOT EXISTS (
  SELECT 1 FROM public.support_statuses WHERE slug = 'waiting_for_hd_homes'
);

WITH required(slug, name, description, sort_order) AS (
  VALUES
    ('property', 'Property', 'Property information and availability', 11),
    ('inspection', 'Inspection', 'Inspection booking support', 21),
    ('application', 'Application', 'Application support', 31),
    ('account', 'Account', 'Account access and profile support', 51),
    ('investment', 'Investment', 'Investment and portfolio support', 55),
    ('technical', 'Technical', 'Technical and portal issues', 56),
    ('complaint', 'Complaint', 'Service complaints and recovery', 70),
    ('other', 'Other', 'Requests outside existing categories', 90)
)
INSERT INTO public.support_categories
  (id, slug, name, description, sort_order, is_active)
SELECT gen_random_uuid(), r.slug, r.name, r.description, r.sort_order, true
FROM required r
WHERE NOT EXISTS (
  SELECT 1 FROM public.support_categories c WHERE c.slug = r.slug
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'tickets_status_check'
  ) THEN
    ALTER TABLE public.tickets ADD CONSTRAINT tickets_status_check CHECK (
      status IN (
        'new', 'open', 'in_progress', 'waiting_for_customer',
        'waiting_for_hd_homes', 'escalated', 'resolved', 'closed'
      )
    );
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'tickets_priority_check'
  ) THEN
    ALTER TABLE public.tickets ADD CONSTRAINT tickets_priority_check CHECK (
      priority IN ('low', 'normal', 'high', 'urgent')
    );
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.apply_support_ticket_lifecycle()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status = 'pending_customer' THEN
    NEW.status := 'waiting_for_customer';
  END IF;
  NEW.source := COALESCE(NULLIF(btrim(NEW.source), ''), NEW.channel, 'support');
  SELECT id INTO NEW.status_id FROM public.support_statuses
    WHERE slug = NEW.status AND is_active IS TRUE LIMIT 1;
  SELECT id INTO NEW.priority_id FROM public.support_priorities
    WHERE slug = NEW.priority AND is_active IS TRUE LIMIT 1;
  IF NEW.category_id IS NOT NULL THEN
    SELECT slug INTO NEW.subcategory FROM public.support_categories
      WHERE id = NEW.category_id;
  END IF;
  IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
    NEW.waiting_since := CASE
      WHEN NEW.status IN ('waiting_for_customer', 'waiting_for_hd_homes')
        THEN now() ELSE NULL END;
    IF NEW.status = 'resolved' THEN
      NEW.resolved_at := COALESCE(NEW.resolved_at, now());
    ELSIF NEW.status = 'closed' THEN
      NEW.closed_at := COALESCE(NEW.closed_at, now());
    ELSIF OLD.status IN ('resolved', 'closed') THEN
      NEW.reopened_at := now();
      NEW.resolution_confirmed_at := NULL;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_apply_support_ticket_lifecycle ON public.tickets;
CREATE TRIGGER trg_apply_support_ticket_lifecycle
BEFORE INSERT OR UPDATE OF status, priority, category_id, source, channel
ON public.tickets
FOR EACH ROW EXECUTE FUNCTION public.apply_support_ticket_lifecycle();
