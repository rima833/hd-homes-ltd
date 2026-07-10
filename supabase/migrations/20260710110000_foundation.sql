-- HD Homes Ltd – Enterprise Supabase Ecosystem
-- Migration 001: Foundation utilities, enums, and shared functions

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------

CREATE TYPE public.record_status AS ENUM ('active', 'inactive', 'archived', 'draft');
CREATE TYPE public.account_status AS ENUM (
  'pending_verification',
  'active',
  'inactive',
  'suspended'
);

-- ---------------------------------------------------------------------------
-- Shared trigger: auto-update updated_at
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------------
-- Audit context helper (used by triggers and application code)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.set_audit_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    NEW.created_at = COALESCE(NEW.created_at, now());
    NEW.updated_at = COALESCE(NEW.updated_at, now());
    NEW.created_by = COALESCE(NEW.created_by, auth.uid());
    NEW.updated_by = COALESCE(NEW.updated_by, auth.uid());
    NEW.status = COALESCE(NEW.status, 'active');
    NEW.is_deleted = COALESCE(NEW.is_deleted, false);
  ELSIF TG_OP = 'UPDATE' THEN
    NEW.updated_at = now();
    NEW.updated_by = COALESCE(auth.uid(), NEW.updated_by);
    NEW.created_at = OLD.created_at;
    NEW.created_by = OLD.created_by;
  END IF;
  RETURN NEW;
END;
$$;
