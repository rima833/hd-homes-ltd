-- Phase 2 verification follow-up: covering indexes for every new foreign key.
CREATE INDEX IF NOT EXISTS idx_support_ticket_events_actor
  ON public.support_ticket_events (actor_id)
  WHERE actor_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_support_quick_replies_category
  ON public.support_quick_replies (category_id)
  WHERE category_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_support_quick_replies_team
  ON public.support_quick_replies (team_id)
  WHERE team_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_support_quick_replies_created_by
  ON public.support_quick_replies (created_by)
  WHERE created_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_support_assignment_rules_category
  ON public.support_assignment_rules (category_id)
  WHERE category_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_support_assignment_rules_team
  ON public.support_assignment_rules (team_id)
  WHERE team_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_support_assignment_rules_queue
  ON public.support_assignment_rules (queue_id)
  WHERE queue_id IS NOT NULL;
