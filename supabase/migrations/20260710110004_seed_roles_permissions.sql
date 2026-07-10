-- Migration 005: Seed roles, permissions, and default app settings

-- ---------------------------------------------------------------------------
-- Roles (7 authenticated roles; Guest = unauthenticated, no DB role)
-- ---------------------------------------------------------------------------

INSERT INTO public.roles (name, slug, description, is_system) VALUES
  ('Super Admin', 'super_admin', 'Full platform control', true),
  ('Admin', 'admin', 'Daily operations management', true),
  ('Sales Team', 'sales_team', 'Leads, inspections, reservations', true),
  ('Finance', 'finance', 'Payments, receipts, invoices', true),
  ('Marketing', 'marketing', 'Website, blog, campaigns, SEO', true),
  ('Construction Manager', 'construction_manager', 'Projects and progress updates', true),
  ('Client / Investor', 'client', 'Default role for buyers and investors', true);

-- ---------------------------------------------------------------------------
-- Permissions
-- ---------------------------------------------------------------------------

INSERT INTO public.permissions (name, slug, module, description) VALUES
  ('View Properties', 'view_properties', 'properties', 'Browse property listings'),
  ('Create Property', 'create_property', 'properties', 'Create new properties'),
  ('Edit Property', 'edit_property', 'properties', 'Edit property details'),
  ('Delete Property', 'delete_property', 'properties', 'Soft-delete properties'),
  ('Publish Property', 'publish_property', 'properties', 'Publish properties to website'),
  ('Manage Users', 'manage_users', 'auth', 'Create and manage user accounts'),
  ('Manage Roles', 'manage_roles', 'auth', 'Assign roles and permissions'),
  ('Manage Payments', 'manage_payments', 'finance', 'Confirm and manage payments'),
  ('Manage Blog', 'manage_blog', 'marketing', 'Create and publish blog posts'),
  ('Manage Marketing', 'manage_marketing', 'marketing', 'Homepage, banners, campaigns'),
  ('Manage Construction', 'manage_construction', 'construction', 'Construction projects and updates'),
  ('Manage CRM', 'manage_crm', 'crm', 'Leads, inspections, follow-ups'),
  ('Manage Reports', 'manage_reports', 'analytics', 'Business intelligence and reports'),
  ('Manage Settings', 'manage_settings', 'settings', 'Platform and company settings');

-- ---------------------------------------------------------------------------
-- Role → Permission mappings
-- ---------------------------------------------------------------------------

-- Super Admin: all permissions
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE r.slug = 'super_admin';

-- Admin: all except manage_roles
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
JOIN public.permissions p ON p.slug != 'manage_roles'
WHERE r.slug = 'admin';

-- Sales Team
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
JOIN public.permissions p ON p.slug IN (
  'view_properties', 'manage_crm'
)
WHERE r.slug = 'sales_team';

-- Finance
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
JOIN public.permissions p ON p.slug IN (
  'view_properties', 'manage_payments', 'manage_reports'
)
WHERE r.slug = 'finance';

-- Marketing
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
JOIN public.permissions p ON p.slug IN (
  'view_properties', 'manage_blog', 'manage_marketing'
)
WHERE r.slug = 'marketing';

-- Construction Manager
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
JOIN public.permissions p ON p.slug IN (
  'view_properties', 'manage_construction'
)
WHERE r.slug = 'construction_manager';

-- Client: view properties only
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
JOIN public.permissions p ON p.slug = 'view_properties'
WHERE r.slug = 'client';

-- ---------------------------------------------------------------------------
-- Default public app settings
-- ---------------------------------------------------------------------------

INSERT INTO public.app_settings (key, value, category, is_public, description) VALUES
  ('company', '{"name":"HD Homes Limited","tagline":"Making Quality Housing Accessible","country":"Nigeria"}'::jsonb, 'general', true, 'Company information'),
  ('theme', '{"primary":"#B48743","secondary":"#5A5A5C","background":"#000000","text":"#FFFFFF"}'::jsonb, 'branding', true, 'Brand colors from logo'),
  ('contact', '{"email":"","phone":"","address":""}'::jsonb, 'general', true, 'Contact details'),
  ('seo', '{"default_title":"HD Homes Limited","default_description":"Making Quality Housing Accessible"}'::jsonb, 'seo', true, 'Default SEO settings');
