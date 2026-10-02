-- Phone is collected at registration / profile edit — no SMS OTP required.
-- Treat a non-empty phone as "on file" (phone_verified = true).

CREATE OR REPLACE FUNCTION public.sync_phone_on_file()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF nullif(btrim(COALESCE(NEW.phone, '')), '') IS NOT NULL THEN
    NEW.phone_verified := true;
  ELSE
    NEW.phone_verified := false;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_phone_on_file ON public.profiles;
CREATE TRIGGER profiles_phone_on_file
  BEFORE INSERT OR UPDATE OF phone ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_phone_on_file();

-- Backfill existing accounts that already provided a phone.
UPDATE public.profiles
SET phone_verified = true,
    updated_at = now()
WHERE nullif(btrim(COALESCE(phone, '')), '') IS NOT NULL
  AND phone_verified IS DISTINCT FROM true;

UPDATE public.profiles
SET phone_verified = false,
    updated_at = now()
WHERE nullif(btrim(COALESCE(phone, '')), '') IS NULL
  AND phone_verified IS DISTINCT FROM false;
