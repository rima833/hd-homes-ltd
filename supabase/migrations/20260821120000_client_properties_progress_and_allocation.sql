-- Client My Properties: allocate from applications, live payment/construction progress

BEGIN;

-- ─── Progress sync ───────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.sync_client_property_progress(
  p_client_id uuid,
  p_property_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_price numeric(16,2);
  v_paid numeric(16,2) := 0;
  v_payment_count bigint := 0;
  v_pct numeric(5,2) := 0;
  v_construction numeric(5,2) := 0;
  v_allocation text;
BEGIN
  IF p_client_id IS NULL OR p_property_id IS NULL THEN
    RETURN;
  END IF;

  SELECT COALESCE(cp.purchase_price, pp.price, p.listing_price, 0)
  INTO v_price
  FROM public.client_properties cp
  JOIN public.properties p ON p.id = cp.property_id
  LEFT JOIN LATERAL (
    SELECT price FROM public.property_pricing
    WHERE property_id = p.id
    ORDER BY updated_at DESC NULLS LAST
    LIMIT 1
  ) pp ON true
  WHERE cp.client_id = p_client_id
    AND cp.property_id = p_property_id
    AND COALESCE(cp.is_deleted, false) = false
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  SELECT COALESCE(SUM(pay.amount), 0), COUNT(*)
  INTO v_paid, v_payment_count
  FROM public.payments pay
  WHERE pay.client_id = p_client_id
    AND pay.property_id = p_property_id
    AND COALESCE(pay.is_deleted, false) = false
    AND lower(COALESCE(pay.status, '')) IN ('completed', 'paid', 'success', 'verified');

  -- Only overwrite stored % once real verified payments exist.
  IF v_payment_count > 0 AND v_price > 0 THEN
    v_pct := LEAST(100, ROUND((v_paid / v_price) * 100, 2));
  ELSE
    v_pct := NULL;
  END IF;

  SELECT COALESCE(pr.completion_percent, 0) INTO v_construction
  FROM public.projects pr
  WHERE pr.property_id = p_property_id
    AND COALESCE(pr.is_deleted, false) = false
  ORDER BY pr.updated_at DESC NULLS LAST
  LIMIT 1;

  IF NOT FOUND THEN
    SELECT MAX(cu.completion_percent) INTO v_construction
    FROM public.construction_updates cu
    JOIN public.projects pr ON pr.id = cu.project_id
    WHERE pr.property_id = p_property_id
      AND COALESCE(cu.is_deleted, false) = false
      AND COALESCE(pr.is_deleted, false) = false;
  END IF;

  SELECT allocation_status INTO v_allocation
  FROM public.client_properties
  WHERE client_id = p_client_id
    AND property_id = p_property_id
    AND COALESCE(is_deleted, false) = false
  LIMIT 1;

  IF v_pct IS NOT NULL AND COALESCE(v_pct, 0) >= 100
     AND COALESCE(v_construction, 0) >= 100
     AND v_allocation IS DISTINCT FROM 'handed_over'
     AND v_allocation IS DISTINCT FROM 'handover_pending' THEN
    v_allocation := 'handover_pending';
  ELSIF v_pct IS NOT NULL AND COALESCE(v_pct, 0) >= 100
     AND v_allocation IN ('pending', 'allocated') THEN
    v_allocation := 'documentation';
  END IF;

  UPDATE public.client_properties
  SET
    payment_progress_pct = COALESCE(v_pct, payment_progress_pct),
    construction_progress_pct = COALESCE(v_construction, construction_progress_pct),
    allocation_status = COALESCE(v_allocation, allocation_status),
    updated_at = now()
  WHERE client_id = p_client_id
    AND property_id = p_property_id
    AND COALESCE(is_deleted, false) = false;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_sync_client_property_progress_from_payment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.sync_client_property_progress(
    COALESCE(NEW.client_id, OLD.client_id),
    COALESCE(NEW.property_id, OLD.property_id)
  );
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_payments_sync_client_progress ON public.payments;
CREATE TRIGGER trg_payments_sync_client_progress
  AFTER INSERT OR UPDATE OF amount, status, property_id, client_id, is_deleted
  ON public.payments
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_sync_client_property_progress_from_payment();

CREATE OR REPLACE FUNCTION public.trg_sync_client_property_progress_from_project()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT cp.client_id, cp.property_id
    FROM public.client_properties cp
    WHERE cp.property_id = COALESCE(NEW.property_id, OLD.property_id)
      AND COALESCE(cp.is_deleted, false) = false
  LOOP
    PERFORM public.sync_client_property_progress(r.client_id, r.property_id);
  END LOOP;
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_projects_sync_client_progress ON public.projects;
CREATE TRIGGER trg_projects_sync_client_progress
  AFTER INSERT OR UPDATE OF completion_percent, property_id, is_deleted, status
  ON public.projects
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_sync_client_property_progress_from_project();

-- ─── Allocate property when application advances ─────────────────────────────
CREATE OR REPLACE FUNCTION public.allocate_client_property_from_application()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_price numeric(16,2);
  v_status text := lower(COALESCE(NEW.status, ''));
BEGIN
  IF TG_OP = 'UPDATE' AND lower(COALESCE(OLD.status, '')) = v_status THEN
    RETURN NEW;
  END IF;

  IF v_status NOT IN (
    'approved', 'payment_pending', 'payment_active',
    'contract_pending', 'completed'
  ) THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(NEW.amount_offered, pp.price, p.listing_price)
  INTO v_price
  FROM public.properties p
  LEFT JOIN LATERAL (
    SELECT price FROM public.property_pricing
    WHERE property_id = p.id
    ORDER BY updated_at DESC NULLS LAST
    LIMIT 1
  ) pp ON true
  WHERE p.id = NEW.property_id
  LIMIT 1;

  INSERT INTO public.client_properties (
    client_id,
    property_id,
    purchase_date,
    purchase_price,
    currency,
    payment_progress_pct,
    construction_progress_pct,
    allocation_status,
    status,
    is_deleted
  ) VALUES (
    NEW.client_id,
    NEW.property_id,
    CURRENT_DATE,
    v_price,
    'NGN',
    0,
    0,
    CASE
      WHEN v_status = 'completed' THEN 'documentation'
      ELSE 'allocated'
    END,
    'active',
    false
  )
  ON CONFLICT (client_id, property_id) DO UPDATE
  SET
    purchase_price = COALESCE(EXCLUDED.purchase_price, public.client_properties.purchase_price),
    is_deleted = false,
    status = 'active',
    allocation_status = CASE
      WHEN public.client_properties.allocation_status IN ('handed_over', 'handover_pending', 'documentation')
        THEN public.client_properties.allocation_status
      WHEN v_status = 'completed' THEN 'documentation'
      ELSE COALESCE(public.client_properties.allocation_status, 'allocated')
    END,
    updated_at = now();

  PERFORM public.sync_client_property_progress(NEW.client_id, NEW.property_id);

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_allocate_client_property_from_application
  ON public.client_property_applications;
CREATE TRIGGER trg_allocate_client_property_from_application
  AFTER INSERT OR UPDATE OF status
  ON public.client_property_applications
  FOR EACH ROW
  EXECUTE FUNCTION public.allocate_client_property_from_application();

-- Friendlier handover / completion notification copy
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
  v_property_title := coalesce(v_property_title, 'your property');

  CASE v_new_status
    WHEN 'allocated' THEN
      v_title := 'Your property is ready to track';
      v_body := v_property_title || ' is now on My Properties. Follow payments and construction progress here.';
    WHEN 'documentation' THEN
      v_title := 'Documentation underway';
      v_body := 'Great progress on ' || v_property_title || '! We are preparing your ownership documents.';
    WHEN 'handover_pending' THEN
      v_title := 'Handover is almost here';
      v_body := 'Exciting news — ' || v_property_title || ' is being prepared for handover. You are nearly home!';
    WHEN 'handed_over' THEN
      v_title := 'Congratulations — keys ready!';
      v_body := 'Handover for ' || v_property_title || ' is complete. Welcome home — we are so happy for you!';
    ELSE
      v_title := 'Allocation updated';
      v_body := 'Allocation status for ' || v_property_title || ' is now ' || v_new_status || '.';
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
    CASE WHEN v_new_status IN ('handed_over', 'handover_pending') THEN 'high' ELSE 'normal' END,
    null,
    '/client/properties',
    jsonb_build_object('client_property_id', NEW.id, 'allocation_status', v_new_status),
    false,
    'delivered'
  );

  RETURN NEW;
END;
$$;

-- Backfill progress for existing allocations
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT client_id, property_id
    FROM public.client_properties
    WHERE COALESCE(is_deleted, false) = false
  LOOP
    PERFORM public.sync_client_property_progress(r.client_id, r.property_id);
  END LOOP;
END $$;

GRANT EXECUTE ON FUNCTION public.sync_client_property_progress(uuid, uuid) TO authenticated;

COMMIT;
