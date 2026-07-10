-- Migration 004: Clients, Investors, Construction, Finance, CRM, Marketing, Support, Analytics

-- ===========================================================================
-- CLIENTS
-- ===========================================================================

CREATE TABLE public.clients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID UNIQUE REFERENCES public.profiles(id) ON DELETE SET NULL,
  client_code TEXT UNIQUE,
  assigned_sales_id UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.client_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL UNIQUE REFERENCES public.clients(id) ON DELETE CASCADE,
  occupation TEXT,
  employer TEXT,
  date_of_birth DATE,
  id_type TEXT,
  id_number TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.client_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  file_url TEXT NOT NULL,
  document_type TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.client_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL UNIQUE REFERENCES public.clients(id) ON DELETE CASCADE,
  preferences JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.client_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  notification_id UUID REFERENCES public.notifications(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

-- ===========================================================================
-- INVESTORS
-- ===========================================================================

CREATE TABLE public.investors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID UNIQUE REFERENCES public.profiles(id) ON DELETE SET NULL,
  investor_code TEXT UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.investment_portfolios (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id UUID NOT NULL REFERENCES public.investors(id) ON DELETE CASCADE,
  property_id UUID REFERENCES public.properties(id),
  estate_id UUID REFERENCES public.estates(id),
  investment_amount NUMERIC(15,2) NOT NULL DEFAULT 0,
  currency TEXT NOT NULL DEFAULT 'NGN',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.investment_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  portfolio_id UUID NOT NULL REFERENCES public.investment_portfolios(id) ON DELETE CASCADE,
  transaction_type TEXT NOT NULL,
  amount NUMERIC(15,2) NOT NULL,
  currency TEXT NOT NULL DEFAULT 'NGN',
  transaction_date TIMESTAMPTZ NOT NULL DEFAULT now(),
  reference TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.investment_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id UUID NOT NULL REFERENCES public.investors(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  file_url TEXT,
  report_period TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.investment_returns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  portfolio_id UUID NOT NULL REFERENCES public.investment_portfolios(id) ON DELETE CASCADE,
  return_amount NUMERIC(15,2) NOT NULL,
  return_percent NUMERIC(8,4),
  period_start DATE,
  period_end DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

-- ===========================================================================
-- CONSTRUCTION
-- ===========================================================================

CREATE TABLE public.projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  property_id UUID REFERENCES public.properties(id),
  estate_id UUID REFERENCES public.estates(id),
  completion_percent NUMERIC(5,2) NOT NULL DEFAULT 0,
  start_date DATE,
  expected_end_date DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.construction_updates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  completion_percent NUMERIC(5,2),
  update_date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.construction_photos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  update_id UUID NOT NULL REFERENCES public.construction_updates(id) ON DELETE CASCADE,
  url TEXT NOT NULL,
  caption TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.construction_videos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  update_id UUID NOT NULL REFERENCES public.construction_updates(id) ON DELETE CASCADE,
  url TEXT NOT NULL,
  title TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.milestones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  target_date DATE,
  completed_at TIMESTAMPTZ,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

-- ===========================================================================
-- FINANCE
-- ===========================================================================

CREATE TABLE public.payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID REFERENCES public.clients(id),
  investor_id UUID REFERENCES public.investors(id),
  property_id UUID REFERENCES public.properties(id),
  amount NUMERIC(15,2) NOT NULL,
  currency TEXT NOT NULL DEFAULT 'NGN',
  payment_method TEXT,
  payment_provider TEXT,
  provider_reference TEXT,
  paid_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'pending',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.installments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_plan_id UUID REFERENCES public.property_payment_plans(id),
  client_id UUID REFERENCES public.clients(id),
  property_id UUID REFERENCES public.properties(id),
  amount NUMERIC(15,2) NOT NULL,
  due_date DATE NOT NULL,
  paid_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'pending',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.receipts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id UUID NOT NULL REFERENCES public.payments(id) ON DELETE CASCADE,
  receipt_number TEXT UNIQUE,
  file_url TEXT,
  issued_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID REFERENCES public.clients(id),
  invoice_number TEXT UNIQUE,
  amount NUMERIC(15,2) NOT NULL,
  currency TEXT NOT NULL DEFAULT 'NGN',
  due_date DATE,
  file_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'draft',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id UUID REFERENCES public.payments(id),
  transaction_type TEXT NOT NULL,
  amount NUMERIC(15,2) NOT NULL,
  reference TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.commissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sales_user_id UUID REFERENCES public.profiles(id),
  payment_id UUID REFERENCES public.payments(id),
  amount NUMERIC(15,2) NOT NULL,
  commission_percent NUMERIC(5,2),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'pending',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

-- ===========================================================================
-- CRM
-- ===========================================================================

CREATE TABLE public.leads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  first_name TEXT NOT NULL,
  last_name TEXT,
  email TEXT,
  phone TEXT,
  source TEXT,
  assigned_to UUID REFERENCES public.profiles(id),
  property_id UUID REFERENCES public.properties(id),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'new',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.appointments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id UUID REFERENCES public.leads(id),
  client_id UUID REFERENCES public.clients(id),
  assigned_to UUID REFERENCES public.profiles(id),
  scheduled_at TIMESTAMPTZ NOT NULL,
  location TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'scheduled',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.inspections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES public.properties(id),
  client_id UUID REFERENCES public.clients(id),
  lead_id UUID REFERENCES public.leads(id),
  assigned_to UUID REFERENCES public.profiles(id),
  scheduled_at TIMESTAMPTZ NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'scheduled',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.followups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id UUID REFERENCES public.leads(id),
  client_id UUID REFERENCES public.clients(id),
  assigned_to UUID REFERENCES public.profiles(id),
  due_at TIMESTAMPTZ NOT NULL,
  notes TEXT,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'pending',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  assigned_to UUID REFERENCES public.profiles(id),
  due_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'pending',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type TEXT NOT NULL,
  entity_id UUID NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type TEXT NOT NULL,
  entity_id UUID NOT NULL,
  activity_type TEXT NOT NULL,
  description TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

-- ===========================================================================
-- MARKETING
-- ===========================================================================

CREATE TABLE public.blog_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.blogs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  excerpt TEXT,
  content JSONB NOT NULL DEFAULT '{}'::jsonb,
  cover_image_url TEXT,
  category_id UUID REFERENCES public.blog_categories(id),
  author_id UUID REFERENCES public.profiles(id),
  is_published BOOLEAN NOT NULL DEFAULT false,
  published_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'draft',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.newsletter (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL UNIQUE,
  is_subscribed BOOLEAN NOT NULL DEFAULT true,
  subscribed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.campaigns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  channel TEXT,
  content JSONB NOT NULL DEFAULT '{}'::jsonb,
  starts_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'draft',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.seo (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type TEXT NOT NULL,
  entity_id UUID NOT NULL,
  meta_title TEXT,
  meta_description TEXT,
  canonical_url TEXT,
  og_image_url TEXT,
  structured_data JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  UNIQUE (entity_type, entity_id)
);

CREATE TABLE public.social_links (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  platform TEXT NOT NULL,
  url TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

-- ===========================================================================
-- SUPPORT
-- ===========================================================================

CREATE TABLE public.tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.profiles(id),
  subject TEXT NOT NULL,
  priority TEXT NOT NULL DEFAULT 'normal',
  assigned_to UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'open',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.ticket_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id UUID NOT NULL REFERENCES public.tickets(id) ON DELETE CASCADE,
  sender_id UUID REFERENCES public.profiles(id),
  message TEXT NOT NULL,
  is_internal BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID REFERENCES public.profiles(id),
  recipient_id UUID REFERENCES public.profiles(id),
  message TEXT NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

-- ===========================================================================
-- ANALYTICS
-- ===========================================================================

CREATE TABLE public.visitor_statistics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  visit_date DATE NOT NULL DEFAULT CURRENT_DATE,
  page_path TEXT,
  visitor_count INT NOT NULL DEFAULT 0,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.property_views (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.profiles(id),
  session_id TEXT,
  viewed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.popular_searches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  search_term TEXT NOT NULL,
  search_count INT NOT NULL DEFAULT 1,
  last_searched_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE public.user_activity (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.profiles(id),
  activity_type TEXT NOT NULL,
  entity_type TEXT,
  entity_id UUID,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  updated_by UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'active',
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

-- Enable RLS on all tables
DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'clients','client_profiles','client_documents','client_preferences','client_notifications',
    'investors','investment_portfolios','investment_transactions','investment_reports','investment_returns',
    'projects','construction_updates','construction_photos','construction_videos','milestones',
    'payments','installments','receipts','invoices','transactions','commissions',
    'leads','appointments','inspections','followups','tasks','notes','activities',
    'blog_categories','blogs','newsletter','campaigns','seo','social_links',
    'tickets','ticket_messages','chat_messages',
    'visitor_statistics','property_views','popular_searches','user_activity'
  ] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
  END LOOP;
END $$;

-- Client: own data only
CREATE POLICY clients_own ON public.clients FOR SELECT USING (
  user_id = auth.uid() OR public.has_permission('manage_crm') OR public.has_role('admin') OR public.has_role('super_admin')
);
CREATE POLICY clients_staff ON public.clients FOR ALL USING (public.has_permission('manage_crm') OR public.has_role('admin'));

CREATE POLICY client_profiles_own ON public.client_profiles FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.clients c WHERE c.id = client_id AND c.user_id = auth.uid())
  OR public.has_permission('manage_crm')
);
CREATE POLICY client_profiles_staff ON public.client_profiles FOR ALL USING (public.has_permission('manage_crm'));

CREATE POLICY client_documents_own ON public.client_documents FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.clients c WHERE c.id = client_id AND c.user_id = auth.uid())
  OR public.has_permission('manage_crm') OR public.has_permission('manage_payments')
);
CREATE POLICY client_documents_staff ON public.client_documents FOR ALL USING (
  public.has_permission('manage_crm') OR public.has_permission('manage_payments')
);

-- Investors: own data
CREATE POLICY investors_own ON public.investors FOR SELECT USING (
  user_id = auth.uid() OR public.has_role('admin') OR public.has_role('super_admin')
);
CREATE POLICY investors_staff ON public.investors FOR ALL USING (public.has_role('admin') OR public.has_role('super_admin'));

CREATE POLICY portfolios_own ON public.investment_portfolios FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.investors i WHERE i.id = investor_id AND i.user_id = auth.uid())
  OR public.has_role('admin')
);
CREATE POLICY portfolios_staff ON public.investment_portfolios FOR ALL USING (public.has_role('admin'));

-- Construction: construction managers + admins
CREATE POLICY projects_staff ON public.projects FOR ALL USING (
  public.has_permission('manage_construction') OR public.has_role('admin')
);
CREATE POLICY projects_client_read ON public.projects FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.clients c
  JOIN public.properties p ON p.id = projects.property_id
    WHERE c.user_id = auth.uid()
  )
);

CREATE POLICY construction_updates_staff ON public.construction_updates FOR ALL USING (public.has_permission('manage_construction'));
CREATE POLICY construction_updates_read ON public.construction_updates FOR SELECT USING (true);
CREATE POLICY construction_photos_read ON public.construction_photos FOR SELECT USING (true);
CREATE POLICY construction_photos_staff ON public.construction_photos FOR ALL USING (public.has_permission('manage_construction'));
CREATE POLICY construction_videos_read ON public.construction_videos FOR SELECT USING (true);
CREATE POLICY construction_videos_staff ON public.construction_videos FOR ALL USING (public.has_permission('manage_construction'));
CREATE POLICY milestones_staff ON public.milestones FOR ALL USING (public.has_permission('manage_construction'));
CREATE POLICY milestones_read ON public.milestones FOR SELECT USING (true);

-- Finance: finance role + own payments
CREATE POLICY payments_own ON public.payments FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.clients c WHERE c.id = client_id AND c.user_id = auth.uid())
  OR EXISTS (SELECT 1 FROM public.investors i WHERE i.id = investor_id AND i.user_id = auth.uid())
  OR public.has_permission('manage_payments')
);
CREATE POLICY payments_staff ON public.payments FOR ALL USING (public.has_permission('manage_payments'));

CREATE POLICY installments_own ON public.installments FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.clients c WHERE c.id = client_id AND c.user_id = auth.uid())
  OR public.has_permission('manage_payments')
);
CREATE POLICY installments_staff ON public.installments FOR ALL USING (public.has_permission('manage_payments'));

CREATE POLICY receipts_own ON public.receipts FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.payments p
    JOIN public.clients c ON c.id = p.client_id
    WHERE p.id = payment_id AND c.user_id = auth.uid()
  ) OR public.has_permission('manage_payments')
);
CREATE POLICY receipts_staff ON public.receipts FOR ALL USING (public.has_permission('manage_payments'));

CREATE POLICY invoices_staff ON public.invoices FOR ALL USING (public.has_permission('manage_payments'));
CREATE POLICY transactions_staff ON public.transactions FOR ALL USING (public.has_permission('manage_payments'));
CREATE POLICY commissions_staff ON public.commissions FOR ALL USING (public.has_permission('manage_payments'));

-- CRM: sales team sees assigned leads
CREATE POLICY leads_assigned ON public.leads FOR SELECT USING (
  assigned_to = auth.uid() OR public.has_permission('manage_crm')
);
CREATE POLICY leads_staff ON public.leads FOR ALL USING (public.has_permission('manage_crm'));

CREATE POLICY appointments_assigned ON public.appointments FOR ALL USING (
  assigned_to = auth.uid() OR public.has_permission('manage_crm')
);
CREATE POLICY inspections_assigned ON public.inspections FOR ALL USING (
  assigned_to = auth.uid() OR public.has_permission('manage_crm') OR (
    client_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.clients c WHERE c.id = inspections.client_id AND c.user_id = auth.uid()
    )
  )
);
CREATE POLICY followups_assigned ON public.followups FOR ALL USING (
  assigned_to = auth.uid() OR public.has_permission('manage_crm')
);
CREATE POLICY tasks_assigned ON public.tasks FOR ALL USING (
  assigned_to = auth.uid() OR public.is_staff()
);
CREATE POLICY notes_staff ON public.notes FOR ALL USING (public.is_staff());
CREATE POLICY activities_staff ON public.activities FOR ALL USING (public.is_staff());

-- Marketing / Blog
CREATE POLICY blog_categories_public ON public.blog_categories FOR SELECT USING (is_deleted = false);
CREATE POLICY blog_categories_staff ON public.blog_categories FOR ALL USING (public.has_permission('manage_blog'));

CREATE POLICY blogs_public ON public.blogs FOR SELECT USING (is_published = true AND is_deleted = false);
CREATE POLICY blogs_staff ON public.blogs FOR ALL USING (public.has_permission('manage_blog'));

CREATE POLICY newsletter_public_insert ON public.newsletter FOR INSERT WITH CHECK (true);
CREATE POLICY newsletter_staff ON public.newsletter FOR ALL USING (public.has_permission('manage_marketing'));

CREATE POLICY campaigns_staff ON public.campaigns FOR ALL USING (public.has_permission('manage_marketing'));
CREATE POLICY seo_public ON public.seo FOR SELECT USING (is_deleted = false);
CREATE POLICY seo_staff ON public.seo FOR ALL USING (public.has_permission('manage_marketing'));
CREATE POLICY social_public ON public.social_links FOR SELECT USING (is_deleted = false);
CREATE POLICY social_staff ON public.social_links FOR ALL USING (public.has_permission('manage_marketing'));

-- Support
CREATE POLICY tickets_own ON public.tickets FOR SELECT USING (user_id = auth.uid() OR public.is_staff());
CREATE POLICY tickets_create ON public.tickets FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY tickets_staff ON public.tickets FOR ALL USING (public.is_staff());

CREATE POLICY ticket_messages_own ON public.ticket_messages FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.tickets t WHERE t.id = ticket_id AND (t.user_id = auth.uid() OR public.is_staff()))
);
CREATE POLICY ticket_messages_insert ON public.ticket_messages FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY chat_own ON public.chat_messages FOR ALL USING (
  sender_id = auth.uid() OR recipient_id = auth.uid()
);

-- Analytics: staff only
CREATE POLICY analytics_staff ON public.visitor_statistics FOR ALL USING (public.has_permission('manage_reports'));
CREATE POLICY property_views_insert ON public.property_views FOR INSERT WITH CHECK (true);
CREATE POLICY property_views_staff ON public.property_views FOR SELECT USING (public.has_permission('manage_reports'));
CREATE POLICY popular_searches_public ON public.popular_searches FOR SELECT USING (true);
CREATE POLICY popular_searches_insert ON public.popular_searches FOR INSERT WITH CHECK (true);
CREATE POLICY user_activity_own ON public.user_activity FOR SELECT USING (user_id = auth.uid() OR public.has_permission('manage_reports'));
CREATE POLICY user_activity_insert ON public.user_activity FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
