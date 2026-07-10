-- Migration 007: Security hardening (advisor fixes)

-- Fix search_path on utility functions
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_audit_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
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

-- Revoke public RPC access to internal SECURITY DEFINER helpers
REVOKE ALL ON FUNCTION public.get_user_role_slugs(UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.has_role(TEXT, UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.has_permission(TEXT, UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.is_staff(UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;

-- Missing RLS policies
CREATE POLICY client_preferences_own ON public.client_preferences
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.clients c WHERE c.id = client_id AND c.user_id = auth.uid())
    OR public.has_permission('manage_crm')
  );

CREATE POLICY client_notifications_own ON public.client_notifications
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.clients c WHERE c.id = client_id AND c.user_id = auth.uid())
    OR public.is_staff()
  );

CREATE POLICY investment_transactions_own ON public.investment_transactions
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.investment_portfolios p
      JOIN public.investors i ON i.id = p.investor_id
      WHERE p.id = portfolio_id AND i.user_id = auth.uid()
    ) OR public.has_role('admin')
  );

CREATE POLICY investment_reports_own ON public.investment_reports
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.investors i WHERE i.id = investor_id AND i.user_id = auth.uid())
    OR public.has_role('admin')
  );

CREATE POLICY investment_returns_own ON public.investment_returns
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.investment_portfolios p
      JOIN public.investors i ON i.id = p.investor_id
      WHERE p.id = portfolio_id AND i.user_id = auth.uid()
    ) OR public.has_role('admin')
  );

-- Tighten analytics inserts (authenticated only)
DROP POLICY IF EXISTS property_views_insert ON public.property_views;
CREATE POLICY property_views_insert ON public.property_views
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL OR session_id IS NOT NULL);

DROP POLICY IF EXISTS popular_searches_insert ON public.popular_searches;
CREATE POLICY popular_searches_insert ON public.popular_searches
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS newsletter_public_insert ON public.newsletter;
CREATE POLICY newsletter_public_insert ON public.newsletter
  FOR INSERT WITH CHECK (email IS NOT NULL AND length(email) > 3);
