-- Pin search_path on functions the security advisor flagged.
-- pg_net cannot be moved with SET SCHEMA; the drain function calls net.http_post by name.

ALTER FUNCTION public.prevent_audit_mutation() SET search_path = public;
ALTER FUNCTION public.prevent_vault_mutation() SET search_path = public;
ALTER FUNCTION public.generate_client_payment_reference() SET search_path = public;
ALTER FUNCTION public._attendance_haversine_m(double precision, double precision, double precision, double precision) SET search_path = public, extensions;
ALTER FUNCTION public._attendance_employment_ok(text) SET search_path = public;
ALTER FUNCTION public.construction_project_slug(text, text, uuid) SET search_path = public;
ALTER FUNCTION public.media_sync_primary_cover() SET search_path = public;
ALTER FUNCTION public.sync_phone_on_file() SET search_path = public;
ALTER FUNCTION public._website_ref(text) SET search_path = public;
ALTER FUNCTION public._email_seed_body(text, text, text, text) SET search_path = public;
