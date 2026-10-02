-- Public book-inspection: SECURITY DEFINER RPC for anon/authenticated visitors.

CREATE OR REPLACE FUNCTION public.book_public_inspection(
  p_full_name text,
  p_phone text,
  p_email text,
  p_property_id uuid DEFAULT NULL,
  p_estate_id uuid DEFAULT NULL,
  p_scheduled_at timestamptz DEFAULT NULL,
  p_meeting_type text DEFAULT 'site_visit',
  p_advisor_name text DEFAULT NULL,
  p_notes text DEFAULT NULL,
  p_budget text DEFAULT NULL,
  p_timeline text DEFAULT NULL,
  p_financing text DEFAULT NULL,
  p_location text DEFAULT NULL,
  p_property_type text DEFAULT NULL,
  p_purpose text DEFAULT NULL,
  p_investment_interest boolean DEFAULT false,
  p_document_urls jsonb DEFAULT '[]'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_name text := NULLIF(trim(COALESCE(p_full_name, '')), '');
  v_phone text := NULLIF(trim(COALESCE(p_phone, '')), '');
  v_email text := lower(NULLIF(trim(COALESCE(p_email, '')), ''));
  v_meeting text := CASE
    WHEN lower(COALESCE(p_meeting_type, '')) IN ('virtual', 'virtual_tour') THEN 'virtual_tour'
    ELSE 'site_visit'
  END;
  v_when timestamptz := COALESCE(p_scheduled_at, now() + interval '2 days');
  v_ref text;
  v_inspection_id uuid;
  v_lead_id uuid;
  v_first text;
  v_last text;
  v_space int;
BEGIN
  IF v_name IS NULL OR length(v_name) < 2 THEN
    RAISE EXCEPTION 'full name required';
  END IF;
  IF v_phone IS NULL OR length(v_phone) < 7 THEN
    RAISE EXCEPTION 'phone required';
  END IF;
  IF v_email IS NULL OR position('@' in v_email) = 0 THEN
    RAISE EXCEPTION 'valid email required';
  END IF;

  v_space := position(' ' in v_name);
  IF v_space > 0 THEN
    v_first := left(v_name, v_space - 1);
    v_last := trim(substr(v_name, v_space + 1));
  ELSE
    v_first := v_name;
    v_last := '';
  END IF;

  v_ref := 'INS-' || to_char(now(), 'YYYY') || '-' ||
           lpad((floor(random() * 900000) + 100000)::int::text, 6, '0');

  INSERT INTO public.leads (
    first_name,
    last_name,
    phone,
    email,
    source,
    status,
    property_id,
    notes
  ) VALUES (
    v_first,
    v_last,
    v_phone,
    v_email,
    'book_inspection',
    'new',
    p_property_id,
    trim(both E'\n' from concat_ws(E'\n',
      'Ref: ' || v_ref,
      CASE WHEN p_advisor_name IS NOT NULL THEN 'Advisor: ' || p_advisor_name END,
      CASE WHEN p_notes IS NOT NULL AND length(trim(p_notes)) > 0 THEN 'Notes: ' || trim(p_notes) END,
      CASE WHEN p_budget IS NOT NULL THEN 'Budget: ' || p_budget END,
      CASE WHEN p_timeline IS NOT NULL THEN 'Timeline: ' || p_timeline END,
      CASE WHEN p_financing IS NOT NULL THEN 'Financing: ' || p_financing END,
      CASE WHEN p_location IS NOT NULL THEN 'Location: ' || p_location END,
      CASE WHEN p_property_type IS NOT NULL THEN 'Type: ' || p_property_type END,
      CASE WHEN p_purpose IS NOT NULL THEN 'Purpose: ' || p_purpose END,
      'Investment interest: ' || CASE WHEN p_investment_interest THEN 'yes' ELSE 'no' END,
      'Meeting: ' || v_meeting,
      'Docs: ' || COALESCE(p_document_urls::text, '[]')
    ))
  )
  RETURNING id INTO v_lead_id;

  IF p_property_id IS NOT NULL THEN
    INSERT INTO public.property_inspections (
      property_id,
      inspection_type,
      status,
      scheduled_at,
      visitor_name,
      visitor_email,
      visitor_phone,
      report_payload
    ) VALUES (
      p_property_id,
      v_meeting,
      'scheduled',
      v_when,
      v_name,
      v_email,
      v_phone,
      jsonb_build_object(
        'reference', v_ref,
        'lead_id', v_lead_id,
        'estate_id', p_estate_id,
        'advisor_name', p_advisor_name,
        'notes', p_notes,
        'qualification', jsonb_build_object(
          'budget', p_budget,
          'timeline', p_timeline,
          'financing', p_financing,
          'location', p_location,
          'property_type', p_property_type,
          'purpose', p_purpose,
          'investment_interest', p_investment_interest
        ),
        'document_urls', COALESCE(p_document_urls, '[]'::jsonb),
        'channel', 'public_web'
      )
    )
    RETURNING id INTO v_inspection_id;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'reference', v_ref,
    'inspection_id', v_inspection_id,
    'lead_id', v_lead_id,
    'scheduled_at', v_when,
    'meeting_type', v_meeting
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.book_public_inspection(
  text, text, text, uuid, uuid, timestamptz, text, text, text,
  text, text, text, text, text, text, boolean, jsonb
) TO anon, authenticated;
