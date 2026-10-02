-- Portal Messages: staff can always read/reply (parity with client is_staff()),
-- and ensure conversation touch fires reliably for realtime subscribers.

CREATE OR REPLACE FUNCTION public.can_staff_portal_message_investors(
  p_uid uuid DEFAULT auth.uid()
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT
    p_uid IS NOT NULL
    AND (
      public.is_staff(p_uid)
      OR public.has_role('super_admin', p_uid)
      OR public.has_role('admin', p_uid)
      OR public.has_permission('investors.communicate', p_uid)
      OR public.has_permission('support.write', p_uid)
      OR public.has_permission('support.inbox', p_uid)
    );
$$;

-- Keep REPLICA IDENTITY FULL for filtered realtime UPDATE delivery.
ALTER TABLE public.investor_conversations REPLICA IDENTITY FULL;
ALTER TABLE public.investor_conversation_messages REPLICA IDENTITY FULL;
ALTER TABLE public.client_conversations REPLICA IDENTITY FULL;
ALTER TABLE public.client_conversation_messages REPLICA IDENTITY FULL;

-- Ensure tables stay in the realtime publication.
DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.investor_conversations;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.investor_conversation_messages;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.client_conversations;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.client_conversation_messages;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
END $$;
