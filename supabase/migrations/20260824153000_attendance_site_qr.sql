-- Seed a site QR (opaque token) and ensure replica identity for live updates.
-- Does not duplicate Head Office QR.

INSERT INTO public.attendance_qr_codes (location_id, token, label, status)
SELECT
  loc.id,
  'HDH-ATT-' || encode(gen_random_bytes(24), 'hex'),
  loc.name,
  'active'
FROM public.attendance_locations loc
WHERE loc.slug = 'victoria-crest-site'
  AND loc.qr_enabled = true
  AND loc.status = 'active'
  AND NOT EXISTS (
    SELECT 1
    FROM public.attendance_qr_codes q
    WHERE q.location_id = loc.id
      AND q.status = 'active'
  );

ALTER TABLE public.attendance_breaks REPLICA IDENTITY FULL;
ALTER TABLE public.attendance_events REPLICA IDENTITY FULL;
ALTER TABLE public.attendance_records REPLICA IDENTITY FULL;
