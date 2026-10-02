-- Client portal finance->client propagation + document metadata guards
BEGIN;

-- ---------------------------------------------------------------------------
-- 1) Auto-populate storage metadata for client documents
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.normalize_client_document_storage_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v text;
  slash_pos int;
BEGIN
  IF NEW.file_url IS NULL OR btrim(NEW.file_url) = '' THEN
    RETURN NEW;
  END IF;

  v := btrim(NEW.file_url);

  IF NEW.storage_bucket IS NOT NULL AND NEW.storage_path IS NOT NULL THEN
    RETURN NEW;
  END IF;

  IF v LIKE 'storage://%/%' THEN
    v := replace(v, 'storage://', '');
    slash_pos := position('/' in v);
    IF slash_pos > 1 THEN
      NEW.storage_bucket := split_part(v, '/', 1);
      NEW.storage_path := substring(v from slash_pos + 1);
    END IF;
    RETURN NEW;
  END IF;

  IF v NOT LIKE 'http://%' AND v NOT LIKE 'https://%' AND v LIKE '%/%' THEN
    slash_pos := position('/' in v);
    IF slash_pos > 1 THEN
      NEW.storage_bucket := split_part(v, '/', 1);
      NEW.storage_path := substring(v from slash_pos + 1);
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_client_documents_normalize_storage ON public.client_documents;
CREATE TRIGGER trg_client_documents_normalize_storage
  BEFORE INSERT OR UPDATE ON public.client_documents
  FOR EACH ROW EXECUTE FUNCTION public.normalize_client_document_storage_fields();

ALTER TABLE public.client_documents
  DROP CONSTRAINT IF EXISTS client_documents_storage_ref_check;

ALTER TABLE public.client_documents
  ADD CONSTRAINT client_documents_storage_ref_check
  CHECK (
    (file_url ~ '^https?://')
    OR (storage_bucket IS NOT NULL AND storage_path IS NOT NULL)
    OR (file_url LIKE 'storage://%/%')
    OR (
      file_url NOT LIKE 'http://%'
      AND file_url NOT LIKE 'https://%'
      AND file_url LIKE '%/%'
    )
  );

-- ---------------------------------------------------------------------------
-- 2) Finance payment updates -> client timeline + in-app notification
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.emit_client_payment_events()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_client_user_id uuid;
  v_property_title text;
  v_amount_text text;
  v_status text;
  v_should_emit boolean := false;
BEGIN
  IF NEW.client_id IS NULL THEN
    RETURN NEW;
  END IF;

  v_status := lower(coalesce(NEW.status, ''));
  IF v_status IN ('completed', 'paid', 'succeeded', 'success') THEN
    IF TG_OP = 'INSERT' THEN
      v_should_emit := true;
    ELSIF TG_OP = 'UPDATE' THEN
      IF lower(coalesce(OLD.status, '')) NOT IN ('completed', 'paid', 'succeeded', 'success') THEN
        v_should_emit := true;
      END IF;
    END IF;
  END IF;

  IF NOT v_should_emit THEN
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

  v_amount_text := '₦' || to_char(coalesce(NEW.amount, 0), 'FM999,999,999,999,990.00');

  INSERT INTO public.client_timeline (
    client_id,
    event_type,
    title,
    body,
    property_id,
    metadata,
    occurred_at
  ) VALUES (
    NEW.client_id,
    'payment',
    'Payment received',
    v_amount_text || ' confirmed' ||
      CASE WHEN v_property_title IS NOT NULL THEN ' for ' || v_property_title ELSE '' END || '.',
    NEW.property_id,
    jsonb_build_object(
      'payment_id', NEW.id,
      'provider', NEW.payment_provider,
      'reference', NEW.provider_reference,
      'status', NEW.status
    ),
    coalesce(NEW.paid_at, now())
  );

  INSERT INTO public.notifications (
    user_id,
    title,
    body,
    channel,
    category,
    type,
    priority,
    template_slug,
    action_url,
    metadata,
    is_read,
    delivery_status
  ) VALUES (
    v_client_user_id,
    'Payment received',
    v_amount_text || ' has been confirmed on your account.',
    'in_app',
    'payments',
    'success',
    'normal',
    'payment_successful',
    '/client/payments',
    jsonb_build_object(
      'payment_id', NEW.id,
      'client_id', NEW.client_id,
      'property_id', NEW.property_id
    ),
    false,
    'delivered'
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_emit_client_payment_events ON public.payments;
CREATE TRIGGER trg_emit_client_payment_events
  AFTER INSERT OR UPDATE OF status, paid_at ON public.payments
  FOR EACH ROW EXECUTE FUNCTION public.emit_client_payment_events();

COMMIT;
