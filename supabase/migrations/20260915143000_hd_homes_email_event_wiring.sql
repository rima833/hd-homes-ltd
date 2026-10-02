-- Wire business events to transactional email queue (extends HD Homes email system).

BEGIN;

-- ---------------------------------------------------------------------------
-- Enrich _notify_user: keep in-app + queue email when recipient known
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._notify_user(
  p_user_id uuid,
  p_title text,
  p_body text,
  p_type text DEFAULT 'payment',
  p_data jsonb DEFAULT '{}'::jsonb
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email text;
  v_first text;
  v_slug text;
  v_vars jsonb;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN;
  END IF;

  BEGIN
    INSERT INTO public.notifications (
      user_id, title, body, type, category, metadata, is_read, channel, status
    ) VALUES (
      p_user_id, p_title, p_body, p_type, 'payment', p_data, false, 'in_app', 'active'
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  BEGIN
    SELECT lower(email), nullif(trim(first_name), '')
    INTO v_email, v_first
    FROM public.profiles
    WHERE id = p_user_id
    LIMIT 1;

    IF v_email IS NULL OR position('@' in v_email) = 0 THEN
      RETURN;
    END IF;

    v_slug := COALESCE(
      nullif(trim(p_data ->> 'template_slug'), ''),
      CASE
        WHEN p_type ILIKE '%reject%' OR p_title ILIKE '%reject%' OR p_title ILIKE '%attention%'
          THEN 'payment_rejected'
        WHEN p_type ILIKE '%verif%' OR p_title ILIKE '%verif%' OR p_title ILIKE '%approved%'
          THEN 'payment_verified'
        WHEN p_title ILIKE '%submitted%' OR p_type ILIKE '%submitted%'
          THEN 'payment_submitted'
        WHEN p_title ILIKE '%received%' OR p_title ILIKE '%payment%'
          THEN 'payment_successful'
        ELSE 'payment_successful'
      END
    );

    v_vars := jsonb_build_object(
      'first_name', COALESCE(v_first, 'there'),
      'message', COALESCE(p_body, ''),
      'payment_amount', COALESCE(p_data ->> 'amount', p_data ->> 'payment_amount', ''),
      'property_name', COALESCE(p_data ->> 'property_name', 'your property'),
      'cta_url', COALESCE(
        nullif(trim(p_data ->> 'cta_url'), ''),
        nullif(trim(p_data ->> 'action_url'), ''),
        (SELECT value ->> 'website_url' FROM public.app_settings WHERE key = 'email_brand' LIMIT 1),
        'https://hdhomes.ng'
      )
    ) || COALESCE(p_data, '{}'::jsonb);

    PERFORM public.queue_transactional_email(
      v_slug,
      v_email,
      p_user_id,
      v_vars,
      NULL,
      jsonb_build_object('source', '_notify_user', 'type', p_type, 'title', p_title)
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;
END;
$$;

-- ---------------------------------------------------------------------------
-- Construction publish emails
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.construction_queue_emails_for_update(
  p_update_id uuid,
  p_project_id uuid,
  p_property_id uuid,
  p_project_name text,
  p_message text,
  p_visibility text[]
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r record;
  v_site text;
BEGIN
  SELECT COALESCE(
    (SELECT value ->> 'website_url' FROM public.app_settings WHERE key = 'email_brand' LIMIT 1),
    (SELECT value ->> 'site_url' FROM public.app_settings WHERE key = 'seo' LIMIT 1),
    'https://hdhomes.ng'
  ) INTO v_site;

  IF 'clients' = ANY(p_visibility) AND p_property_id IS NOT NULL THEN
    FOR r IN
      SELECT DISTINCT c.user_id, lower(p.email) AS email, nullif(trim(p.first_name), '') AS first_name
      FROM public.clients c
      JOIN public.client_properties cprop ON cprop.client_id = c.id
      JOIN public.profiles p ON p.id = c.user_id
      WHERE cprop.property_id = p_property_id
        AND COALESCE(cprop.is_deleted, false) = false
        AND c.user_id IS NOT NULL
        AND COALESCE(c.is_deleted, false) = false
        AND p.email IS NOT NULL
    LOOP
      BEGIN
        PERFORM public.queue_transactional_email(
          'construction_update',
          r.email,
          r.user_id,
          jsonb_build_object(
            'first_name', COALESCE(r.first_name, 'there'),
            'property_name', COALESCE(p_project_name, 'your project'),
            'message', COALESCE(p_message, 'A new construction update is available.'),
            'cta_url', v_site || '/#/client/construction'
          ),
          NULL,
          jsonb_build_object('update_id', p_update_id, 'project_id', p_project_id)
        );
      EXCEPTION WHEN OTHERS THEN
        NULL;
      END;
    END LOOP;
  END IF;

  IF 'investors' = ANY(p_visibility) AND p_property_id IS NOT NULL THEN
    FOR r IN
      SELECT DISTINCT inv.user_id, lower(p.email) AS email, nullif(trim(p.first_name), '') AS first_name
      FROM public.investors inv
      JOIN public.investor_portfolios ip ON ip.investor_id = inv.id
      JOIN public.portfolio_holdings h ON h.portfolio_id = ip.id
      JOIN public.profiles p ON p.id = inv.user_id
      WHERE h.property_id = p_property_id
        AND COALESCE(inv.is_deleted, false) = false
        AND inv.user_id IS NOT NULL
        AND p.email IS NOT NULL
    LOOP
      BEGIN
        PERFORM public.queue_transactional_email(
          'construction_update',
          r.email,
          r.user_id,
          jsonb_build_object(
            'first_name', COALESCE(r.first_name, 'there'),
            'property_name', COALESCE(p_project_name, 'your project'),
            'message', COALESCE(p_message, 'A new construction update is available.'),
            'cta_url', v_site || '/#/investor/construction'
          ),
          NULL,
          jsonb_build_object('update_id', p_update_id, 'project_id', p_project_id, 'audience', 'investor')
        );
      EXCEPTION WHEN OTHERS THEN
        NULL;
      END;
    END LOOP;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.construction_queue_emails_for_update(uuid, uuid, uuid, text, text, text[])
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.construction_queue_emails_for_update(uuid, uuid, uuid, text, text, text[])
  TO service_role;

CREATE OR REPLACE FUNCTION public.trg_construction_published_email()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cp public.construction_projects%ROWTYPE;
  v_msg text;
BEGIN
  IF NEW.is_published IS TRUE
     AND (OLD.is_published IS DISTINCT FROM TRUE)
  THEN
    SELECT * INTO v_cp FROM public.construction_projects WHERE id = NEW.project_id;
    IF FOUND THEN
      v_msg := COALESCE(NEW.short_description, NEW.title, 'Construction update published');
      PERFORM public.construction_queue_emails_for_update(
        NEW.id,
        NEW.project_id,
        v_cp.property_id,
        v_cp.name,
        v_msg,
        COALESCE(NEW.visibility, ARRAY[]::text[])
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_construction_published_email ON public.construction_progress_updates;
CREATE TRIGGER trg_construction_published_email
  AFTER UPDATE OF is_published, status ON public.construction_progress_updates
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_construction_published_email();

-- ---------------------------------------------------------------------------
-- Support ticket emails
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_support_ticket_email()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email text;
  v_first text;
  v_user uuid;
  v_ref text;
  v_site text;
  v_slug text;
BEGIN
  SELECT COALESCE(
    (SELECT value ->> 'website_url' FROM public.app_settings WHERE key = 'email_brand' LIMIT 1),
    'https://hdhomes.ng'
  ) INTO v_site;

  -- support_tickets is a view over tickets; trigger must live on tickets.
  v_user := COALESCE(NEW.user_id, NEW.created_by);
  v_ref := COALESCE(NEW.ticket_number, NEW.id::text);

  IF TG_OP = 'INSERT' THEN
    v_slug := 'support_ticket_created';
  ELSIF TG_OP = 'UPDATE'
        AND NEW.status IS DISTINCT FROM OLD.status
        AND lower(COALESCE(NEW.status::text, '')) IN ('resolved', 'closed') THEN
    v_slug := 'support_ticket_resolved';
  ELSIF TG_OP = 'UPDATE' THEN
    v_slug := 'support_ticket_updated';
  ELSE
    RETURN NEW;
  END IF;

  v_email := nullif(lower(trim(COALESCE(NEW.customer_email, ''))), '');
  IF v_email IS NULL AND v_user IS NOT NULL THEN
    SELECT lower(email), nullif(trim(first_name), '')
    INTO v_email, v_first
    FROM public.profiles WHERE id = v_user LIMIT 1;
  ELSIF v_user IS NOT NULL THEN
    SELECT nullif(trim(first_name), '') INTO v_first
    FROM public.profiles WHERE id = v_user LIMIT 1;
  END IF;

  IF v_email IS NULL THEN
    RETURN NEW;
  END IF;

  BEGIN
    PERFORM public.queue_transactional_email(
      v_slug,
      v_email,
      v_user,
      jsonb_build_object(
        'first_name', COALESCE(v_first, 'there'),
        'ticket_reference', v_ref,
        'message', COALESCE(NEW.subject, 'Support update'),
        'cta_url', v_site || '/#/client/support'
      ),
      NULL,
      jsonb_build_object('ticket_id', NEW.id, 'source', 'support_trigger')
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_support_ticket_email ON public.tickets;
CREATE TRIGGER trg_support_ticket_email
  AFTER INSERT OR UPDATE ON public.tickets
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_support_ticket_email();

-- ---------------------------------------------------------------------------
-- Property inspection emails
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_property_inspection_email()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email text;
  v_first text;
  v_user uuid;
  v_site text;
  v_prop text;
  v_when text;
BEGIN
  IF TG_OP = 'UPDATE'
     AND NEW.status IS NOT DISTINCT FROM OLD.status
     AND COALESCE(NEW.meeting_url, '') IS NOT DISTINCT FROM COALESCE(OLD.meeting_url, '') THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(
    (SELECT value ->> 'website_url' FROM public.app_settings WHERE key = 'email_brand' LIMIT 1),
    'https://hdhomes.ng'
  ) INTO v_site;

  -- property_inspections uses visitor_* fields (not user_id/customer_email)
  v_user := COALESCE(NEW.visitor_profile_id, NEW.created_by);
  v_email := nullif(lower(trim(COALESCE(NEW.visitor_email, ''))), '');
  IF v_email IS NULL AND v_user IS NOT NULL THEN
    SELECT lower(email), nullif(trim(first_name), '')
    INTO v_email, v_first
    FROM public.profiles WHERE id = v_user LIMIT 1;
  ELSIF v_user IS NOT NULL THEN
    SELECT nullif(trim(first_name), '') INTO v_first
    FROM public.profiles WHERE id = v_user LIMIT 1;
  END IF;

  IF v_email IS NULL THEN
    RETURN NEW;
  END IF;

  BEGIN
    SELECT name INTO v_prop
    FROM public.properties
    WHERE id = NEW.property_id
    LIMIT 1;
  EXCEPTION WHEN OTHERS THEN
    v_prop := 'your property';
  END;

  v_when := COALESCE(NEW.scheduled_at::text, '');

  BEGIN
    PERFORM public.queue_transactional_email(
      CASE
        WHEN lower(COALESCE(NEW.status::text, '')) IN ('confirmed', 'scheduled', 'approved')
          THEN 'inspection_confirmed'
        ELSE 'booking_confirmed'
      END,
      v_email,
      v_user,
      jsonb_build_object(
        'first_name', COALESCE(v_first, 'there'),
        'property_name', COALESCE(v_prop, 'your property'),
        'scheduled_at', v_when,
        'booking_reference', COALESCE(NEW.reference, NEW.id::text),
        'meeting_url', COALESCE(NEW.meeting_url, ''),
        'cta_url', v_site || '/#/client/inspections'
      ),
      NULL,
      jsonb_build_object('inspection_id', NEW.id, 'source', 'inspection_trigger')
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_property_inspection_email ON public.property_inspections;
CREATE TRIGGER trg_property_inspection_email
  AFTER INSERT OR UPDATE ON public.property_inspections
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_property_inspection_email();

COMMIT;
