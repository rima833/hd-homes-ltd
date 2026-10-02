-- HD Homes Support Phase 3 — explicit RLS and least-privilege grants.

-- Customer-visible timeline events must be marked separately from internal audit.
ALTER TABLE public.support_ticket_events
  ADD COLUMN IF NOT EXISTS is_internal boolean NOT NULL DEFAULT false;

-- Ticket-number generation must not require sequence privileges for customers.
ALTER FUNCTION public.ensure_support_ticket_number() SECURITY DEFINER;
REVOKE ALL ON FUNCTION public.ensure_support_ticket_number() FROM PUBLIC;
REVOKE ALL ON SEQUENCE public.support_ticket_number_seq FROM anon;
REVOKE ALL ON SEQUENCE public.support_ticket_number_seq FROM authenticated;

-- Remove broad default privileges inherited by new tables.
REVOKE ALL ON TABLE public.support_ticket_links FROM anon, authenticated;
REVOKE ALL ON TABLE public.support_ticket_events FROM anon, authenticated;
REVOKE ALL ON TABLE public.support_settings FROM anon, authenticated;
REVOKE ALL ON TABLE public.support_operating_hours FROM anon, authenticated;
REVOKE ALL ON TABLE public.support_holidays FROM anon, authenticated;
REVOKE ALL ON TABLE public.support_quick_replies FROM anon, authenticated;
REVOKE ALL ON TABLE public.support_assignment_rules FROM anon, authenticated;

-- Safe public availability/configuration reads.
GRANT SELECT ON TABLE public.support_settings TO anon, authenticated;
GRANT SELECT ON TABLE public.support_operating_hours TO anon, authenticated;
GRANT SELECT ON TABLE public.support_holidays TO anon, authenticated;

-- Authenticated access is still restricted by row policies below.
GRANT SELECT, INSERT, UPDATE, DELETE
  ON TABLE public.support_ticket_links TO authenticated;
GRANT SELECT, INSERT
  ON TABLE public.support_ticket_events TO authenticated;
GRANT INSERT, UPDATE, DELETE
  ON TABLE public.support_settings TO authenticated;
GRANT INSERT, UPDATE, DELETE
  ON TABLE public.support_operating_hours TO authenticated;
GRANT INSERT, UPDATE, DELETE
  ON TABLE public.support_holidays TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON TABLE public.support_quick_replies TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON TABLE public.support_assignment_rules TO authenticated;

-- ---------------------------------------------------------------------------
-- Ticket links: internal cross-domain context only.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS support_ticket_links_staff_select
  ON public.support_ticket_links;
DROP POLICY IF EXISTS support_ticket_links_staff_write
  ON public.support_ticket_links;

CREATE POLICY support_ticket_links_staff_select
ON public.support_ticket_links
FOR SELECT TO authenticated
USING (
  public.has_permission('support.read', auth.uid())
  OR public.has_permission('support.tickets', auth.uid())
  OR public.has_role('super_admin', auth.uid())
);

CREATE POLICY support_ticket_links_staff_write
ON public.support_ticket_links
FOR ALL TO authenticated
USING (
  public.has_permission('support.write', auth.uid())
  OR public.has_permission('support.tickets', auth.uid())
  OR public.has_role('super_admin', auth.uid())
)
WITH CHECK (
  public.has_permission('support.write', auth.uid())
  OR public.has_permission('support.tickets', auth.uid())
  OR public.has_role('super_admin', auth.uid())
);

-- ---------------------------------------------------------------------------
-- Ticket events: staff see all; ticket owners see only non-internal events.
-- Events are append-only for application roles.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS support_ticket_events_staff_select
  ON public.support_ticket_events;
DROP POLICY IF EXISTS support_ticket_events_owner_select
  ON public.support_ticket_events;
DROP POLICY IF EXISTS support_ticket_events_staff_insert
  ON public.support_ticket_events;

CREATE POLICY support_ticket_events_staff_select
ON public.support_ticket_events
FOR SELECT TO authenticated
USING (
  public.has_permission('support.read', auth.uid())
  OR public.has_permission('support.tickets', auth.uid())
  OR public.has_role('super_admin', auth.uid())
);

CREATE POLICY support_ticket_events_owner_select
ON public.support_ticket_events
FOR SELECT TO authenticated
USING (
  is_internal = false
  AND EXISTS (
    SELECT 1
    FROM public.tickets t
    WHERE t.id = support_ticket_events.ticket_id
      AND t.user_id = auth.uid()
      AND COALESCE(t.is_deleted, false) = false
  )
);

CREATE POLICY support_ticket_events_staff_insert
ON public.support_ticket_events
FOR INSERT TO authenticated
WITH CHECK (
  public.has_permission('support.write', auth.uid())
  OR public.has_permission('support.tickets', auth.uid())
  OR public.has_role('super_admin', auth.uid())
);

-- ---------------------------------------------------------------------------
-- Public support availability; staff-only mutation.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS support_settings_public_select
  ON public.support_settings;
DROP POLICY IF EXISTS support_settings_staff_write
  ON public.support_settings;
CREATE POLICY support_settings_public_select
ON public.support_settings
FOR SELECT TO anon, authenticated
USING (true);
CREATE POLICY support_settings_staff_write
ON public.support_settings
FOR ALL TO authenticated
USING (
  public.has_permission('support.write', auth.uid())
  OR public.has_permission('support.sla', auth.uid())
  OR public.has_role('super_admin', auth.uid())
)
WITH CHECK (
  public.has_permission('support.write', auth.uid())
  OR public.has_permission('support.sla', auth.uid())
  OR public.has_role('super_admin', auth.uid())
);

DROP POLICY IF EXISTS support_operating_hours_public_select
  ON public.support_operating_hours;
DROP POLICY IF EXISTS support_operating_hours_staff_write
  ON public.support_operating_hours;
CREATE POLICY support_operating_hours_public_select
ON public.support_operating_hours
FOR SELECT TO anon, authenticated
USING (true);
CREATE POLICY support_operating_hours_staff_write
ON public.support_operating_hours
FOR ALL TO authenticated
USING (
  public.has_permission('support.write', auth.uid())
  OR public.has_permission('support.sla', auth.uid())
  OR public.has_role('super_admin', auth.uid())
)
WITH CHECK (
  public.has_permission('support.write', auth.uid())
  OR public.has_permission('support.sla', auth.uid())
  OR public.has_role('super_admin', auth.uid())
);

DROP POLICY IF EXISTS support_holidays_public_select
  ON public.support_holidays;
DROP POLICY IF EXISTS support_holidays_staff_write
  ON public.support_holidays;
CREATE POLICY support_holidays_public_select
ON public.support_holidays
FOR SELECT TO anon, authenticated
USING (true);
CREATE POLICY support_holidays_staff_write
ON public.support_holidays
FOR ALL TO authenticated
USING (
  public.has_permission('support.write', auth.uid())
  OR public.has_permission('support.sla', auth.uid())
  OR public.has_role('super_admin', auth.uid())
)
WITH CHECK (
  public.has_permission('support.write', auth.uid())
  OR public.has_permission('support.sla', auth.uid())
  OR public.has_role('super_admin', auth.uid())
);

-- ---------------------------------------------------------------------------
-- Quick replies and assignment rules are never public.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS support_quick_replies_staff_select
  ON public.support_quick_replies;
DROP POLICY IF EXISTS support_quick_replies_staff_write
  ON public.support_quick_replies;
CREATE POLICY support_quick_replies_staff_select
ON public.support_quick_replies
FOR SELECT TO authenticated
USING (
  public.has_permission('support.read', auth.uid())
  OR public.has_permission('support.chat', auth.uid())
  OR public.has_permission('support.tickets', auth.uid())
  OR public.has_role('super_admin', auth.uid())
);
CREATE POLICY support_quick_replies_staff_write
ON public.support_quick_replies
FOR ALL TO authenticated
USING (
  public.has_permission('support.write', auth.uid())
  OR public.has_permission('support.knowledge', auth.uid())
  OR public.has_role('super_admin', auth.uid())
)
WITH CHECK (
  public.has_permission('support.write', auth.uid())
  OR public.has_permission('support.knowledge', auth.uid())
  OR public.has_role('super_admin', auth.uid())
);

DROP POLICY IF EXISTS support_assignment_rules_staff_select
  ON public.support_assignment_rules;
DROP POLICY IF EXISTS support_assignment_rules_staff_write
  ON public.support_assignment_rules;
CREATE POLICY support_assignment_rules_staff_select
ON public.support_assignment_rules
FOR SELECT TO authenticated
USING (
  public.has_permission('support.read', auth.uid())
  OR public.has_permission('support.tickets', auth.uid())
  OR public.has_permission('support.sla', auth.uid())
  OR public.has_role('super_admin', auth.uid())
);
CREATE POLICY support_assignment_rules_staff_write
ON public.support_assignment_rules
FOR ALL TO authenticated
USING (
  public.has_permission('support.write', auth.uid())
  OR public.has_permission('support.sla', auth.uid())
  OR public.has_role('super_admin', auth.uid())
)
WITH CHECK (
  public.has_permission('support.write', auth.uid())
  OR public.has_permission('support.sla', auth.uid())
  OR public.has_role('super_admin', auth.uid())
);
