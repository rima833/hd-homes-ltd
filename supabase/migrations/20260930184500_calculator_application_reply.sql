-- Staff reply on a calculator application. Visible to the client who submitted it.
-- Marketing CMS and Finance can both reply.

CREATE OR REPLACE FUNCTION public.reply_calculator_application(
  p_application_id uuid,
  p_status text DEFAULT NULL,
  p_reply text DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.calculator_applications;
BEGIN
  IF NOT (
    public.has_permission('manage_marketing')
    OR public._finance_can_manage()
  ) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF p_status IS NOT NULL AND p_status NOT IN (
    'new', 'reviewed', 'contacted', 'qualified', 'converted', 'closed', 'spam'
  ) THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;

  IF p_reply IS NOT NULL AND char_length(btrim(p_reply)) > 4000 THEN
    RAISE EXCEPTION 'invalid_reply';
  END IF;

  UPDATE public.calculator_applications
  SET
    status = COALESCE(p_status, status),
    notes = CASE WHEN p_notes IS NULL THEN notes ELSE btrim(p_notes) END,
    admin_reply = CASE
      WHEN p_reply IS NULL THEN admin_reply
      ELSE btrim(p_reply)
    END,
    replied_at = CASE
      WHEN p_reply IS NULL OR btrim(p_reply) = '' THEN replied_at
      ELSE now()
    END,
    replied_by = CASE
      WHEN p_reply IS NULL OR btrim(p_reply) = '' THEN replied_by
      ELSE auth.uid()
    END,
    updated_at = now()
  WHERE id = p_application_id
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'lead_not_found';
  END IF;

  RETURN to_jsonb(v_row);
END;
$$;

REVOKE ALL ON FUNCTION public.reply_calculator_application(uuid, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.reply_calculator_application(uuid, text, text, text) TO authenticated;
