-- Client portal: application/allocation lifecycle notifications
BEGIN;

CREATE OR REPLACE FUNCTION public.emit_client_application_lifecycle_events()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old_status text := lower(coalesce(OLD.status, ''));
  v_new_status text := lower(coalesce(NEW.status, ''));
  v_client_user_id uuid;
  v_property_title text;
  v_title text;
  v_body text;
  v_priority text := 'normal';
BEGIN
  IF TG_OP = 'UPDATE' AND v_old_status = v_new_status THEN
    RETURN NEW;
  END IF;

  SELECT c.user_id INTO v_client_user_id
  FROM public.clients c
  WHERE c.id = NEW.client_id
    AND c.is_deleted = false
  LIMIT 1;

  IF v_client_user_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT p.title INTO v_property_title
  FROM public.properties p
  WHERE p.id = NEW.property_id
  LIMIT 1;

  v_property_title := coalesce(v_property_title, 'Property');

  CASE v_new_status
    WHEN 'submitted' THEN
      v_title := 'Application submitted';
      v_body := v_property_title || ' application has been submitted.';
    WHEN 'under_review' THEN
      v_title := 'Application under review';
      v_body := 'Your application for ' || v_property_title || ' is now under review.';
    WHEN 'approved' THEN
      v_title := 'Application approved';
      v_body := 'Your application for ' || v_property_title || ' has been approved.';
      v_priority := 'high';
    WHEN 'payment_pending' THEN
      v_title := 'Payment required';
      v_body := 'Your application for ' || v_property_title || ' is awaiting payment.';
      v_priority := 'high';
    WHEN 'completed' THEN
      v_title := 'Application completed';
      v_body := 'Your purchase process for ' || v_property_title || ' is completed.';
    WHEN 'rejected' THEN
      v_title := 'Application update';
      v_body := 'Your application for ' || v_property_title || ' was not approved.';
      v_priority := 'high';
    WHEN 'cancelled' THEN
      v_title := 'Application cancelled';
      v_body := 'Your application for ' || v_property_title || ' has been cancelled.';
    ELSE
      v_title := 'Application updated';
      v_body := 'Your application status changed to ' || v_new_status || '.';
  END CASE;

  INSERT INTO public.client_timeline (
    client_id, event_type, title, body, property_id, metadata, occurred_at
  ) VALUES (
    NEW.client_id,
    'application',
    v_title,
    v_body,
    NEW.property_id,
    jsonb_build_object(
      'application_id', NEW.id,
      'from_status', nullif(v_old_status, ''),
      'to_status', v_new_status
    ),
    now()
  );

  INSERT INTO public.notifications (
    user_id, title, body, channel, category, type, priority, template_slug,
    action_url, metadata, is_read, delivery_status
  ) VALUES (
    v_client_user_id,
    v_title,
    v_body,
    'in_app',
    'properties',
    CASE WHEN v_new_status IN ('rejected') THEN 'warning' ELSE 'information' END,
    v_priority,
    null,
    '/client/applications',
    jsonb_build_object('application_id', NEW.id, 'status', v_new_status),
    false,
    'delivered'
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_emit_client_application_lifecycle_events ON public.client_property_applications;
CREATE TRIGGER trg_emit_client_application_lifecycle_events
  AFTER INSERT OR UPDATE OF status ON public.client_property_applications
  FOR EACH ROW EXECUTE FUNCTION public.emit_client_application_lifecycle_events();

CREATE OR REPLACE FUNCTION public.emit_client_allocation_lifecycle_events()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old_status text := lower(coalesce(OLD.allocation_status, ''));
  v_new_status text := lower(coalesce(NEW.allocation_status, ''));
  v_client_user_id uuid;
  v_property_title text;
  v_title text;
  v_body text;
BEGIN
  IF TG_OP = 'UPDATE' AND v_old_status = v_new_status THEN
    RETURN NEW;
  END IF;

  SELECT c.user_id INTO v_client_user_id
  FROM public.clients c
  WHERE c.id = NEW.client_id
    AND c.is_deleted = false
  LIMIT 1;

  IF v_client_user_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT p.title INTO v_property_title
  FROM public.properties p
  WHERE p.id = NEW.property_id
  LIMIT 1;
  v_property_title := coalesce(v_property_title, 'Property');

  CASE v_new_status
    WHEN 'allocated' THEN
      v_title := 'Property allocated';
      v_body := v_property_title || ' has now been allocated to your account.';
    WHEN 'documentation' THEN
      v_title := 'Documentation in progress';
      v_body := 'Documentation for ' || v_property_title || ' is in progress.';
    WHEN 'handover_pending' THEN
      v_title := 'Handover preparation';
      v_body := v_property_title || ' is being prepared for handover.';
    WHEN 'handed_over' THEN
      v_title := 'Property handed over';
      v_body := 'Handover for ' || v_property_title || ' is complete.';
    ELSE
      v_title := 'Allocation updated';
      v_body := 'Allocation status changed to ' || v_new_status || '.';
  END CASE;

  INSERT INTO public.client_timeline (
    client_id, event_type, title, body, property_id, metadata, occurred_at
  ) VALUES (
    NEW.client_id,
    'allocation',
    v_title,
    v_body,
    NEW.property_id,
    jsonb_build_object(
      'client_property_id', NEW.id,
      'from_status', nullif(v_old_status, ''),
      'to_status', v_new_status
    ),
    now()
  );

  INSERT INTO public.notifications (
    user_id, title, body, channel, category, type, priority, template_slug,
    action_url, metadata, is_read, delivery_status
  ) VALUES (
    v_client_user_id,
    v_title,
    v_body,
    'in_app',
    'properties',
    'information',
    CASE WHEN v_new_status = 'handed_over' THEN 'high' ELSE 'normal' END,
    null,
    '/client/properties',
    jsonb_build_object('client_property_id', NEW.id, 'allocation_status', v_new_status),
    false,
    'delivered'
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_emit_client_allocation_lifecycle_events ON public.client_properties;
CREATE TRIGGER trg_emit_client_allocation_lifecycle_events
  AFTER INSERT OR UPDATE OF allocation_status ON public.client_properties
  FOR EACH ROW EXECUTE FUNCTION public.emit_client_allocation_lifecycle_events();

COMMIT;
