-- Phase 9 — Investor messaging & support
-- 1) Harden ticket_messages owner INSERT/SELECT (hide internal notes)
-- 2) Ensure tickets channel metadata for investor portal

-- ---------------------------------------------------------------------------
-- ticket_messages — customer cannot see/write internal notes
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS ticket_messages_insert ON public.ticket_messages;
DROP POLICY IF EXISTS ticket_messages_own ON public.ticket_messages;
DROP POLICY IF EXISTS ticket_messages_owner_insert ON public.ticket_messages;
DROP POLICY IF EXISTS ticket_messages_owner_select ON public.ticket_messages;

CREATE POLICY ticket_messages_owner_insert ON public.ticket_messages
  FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND COALESCE(is_internal, false) = false
    AND EXISTS (
      SELECT 1
      FROM public.tickets t
      WHERE t.id = ticket_id
        AND t.user_id = auth.uid()
        AND COALESCE(t.is_deleted, false) = false
    )
  );

CREATE POLICY ticket_messages_owner_select ON public.ticket_messages
  FOR SELECT TO authenticated
  USING (
    COALESCE(is_internal, false) = false
    AND EXISTS (
      SELECT 1
      FROM public.tickets t
      WHERE t.id = ticket_id
        AND t.user_id = auth.uid()
        AND COALESCE(t.is_deleted, false) = false
    )
  );

-- Staff/support SELECT must not leak internal notes to customers via OR owner path.
DROP POLICY IF EXISTS ticket_messages_support_select ON public.ticket_messages;
CREATE POLICY ticket_messages_support_select ON public.ticket_messages
  FOR SELECT TO authenticated
  USING (
    public.has_permission('support.read', auth.uid())
    OR public.has_permission('support.tickets', auth.uid())
    OR public.has_permission('manage_tickets', auth.uid())
    OR public.has_role('super_admin', auth.uid())
    OR public.is_staff()
  );

-- ---------------------------------------------------------------------------
-- Soft-close: investors may update own open tickets (status/description only via app)
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS tickets_client_update ON public.tickets;
CREATE POLICY tickets_owner_update ON public.tickets
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

COMMENT ON POLICY ticket_messages_owner_select ON public.ticket_messages IS
  'Investor portal: owner reads non-internal ticket messages (Phase 9).';
COMMENT ON POLICY ticket_messages_owner_insert ON public.ticket_messages IS
  'Investor portal: owner replies with non-internal messages (Phase 9).';
