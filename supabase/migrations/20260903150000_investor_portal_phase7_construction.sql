-- Phase 7 — Investor Portal construction (CPMS) visibility
-- Investors may SELECT projects / phases / milestones for holdings they own.
-- Updates + media investor read already exist (Phases 1–2).

CREATE OR REPLACE FUNCTION public.investor_owns_construction_project(p_project_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.construction_projects cp
    JOIN public.portfolio_holdings h ON h.property_id = cp.property_id
    JOIN public.investor_portfolios ip ON ip.id = h.portfolio_id
    JOIN public.investors inv ON inv.id = ip.investor_id
    WHERE cp.id = p_project_id
      AND inv.user_id = auth.uid()
      AND COALESCE(inv.is_deleted, false) = false
  );
$$;

REVOKE ALL ON FUNCTION public.investor_owns_construction_project(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.investor_owns_construction_project(uuid) TO authenticated;

COMMENT ON FUNCTION public.investor_owns_construction_project(uuid) IS
  'True when the signed-in investor holds a portfolio unit on the project property.';

-- ---------------------------------------------------------------------------
-- construction_projects — investor SELECT for linked holdings
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS construction_projects_investor_read
  ON public.construction_projects;
CREATE POLICY construction_projects_investor_read
  ON public.construction_projects
  FOR SELECT
  USING (public.investor_owns_construction_project(id));

-- ---------------------------------------------------------------------------
-- project_phases — investor SELECT
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS project_phases_investor_read ON public.project_phases;
CREATE POLICY project_phases_investor_read
  ON public.project_phases
  FOR SELECT
  USING (public.investor_owns_construction_project(project_id));

-- ---------------------------------------------------------------------------
-- project_milestones — investor SELECT
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS project_milestones_investor_read
  ON public.project_milestones;
CREATE POLICY project_milestones_investor_read
  ON public.project_milestones
  FOR SELECT
  USING (public.investor_owns_construction_project(project_id));

-- ---------------------------------------------------------------------------
-- Realtime: ensure project_phases published (milestones already in Phase 3)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = 'project_phases'
      AND c.relkind IN ('r', 'p')
  ) AND NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'project_phases'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.project_phases;
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = 'project_phases'
  ) THEN
    EXECUTE 'ALTER TABLE public.project_phases REPLICA IDENTITY FULL';
  END IF;
END $$;
