-- Fix PGRST203: PostgREST cannot choose between two book_public_consultation
-- overloads when p_office_location_id is omitted. Drop the legacy signature
-- that lacks p_office_location_id; keep the office-aware function.

DROP FUNCTION IF EXISTS public.book_public_consultation(
  text,
  text,
  text,
  text,
  text,
  text,
  timestamptz,
  uuid,
  text,
  text,
  text,
  text,
  text,
  boolean,
  text,
  jsonb,
  text
);
