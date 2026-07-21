-- Volume 3 Part 5 — Password Recovery & Account Security
-- Status: APPLIED remotely as password_recovery_account_security (approved 2026-07-13).

CREATE TABLE IF NOT EXISTS public.password_reset_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  email TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'sent',
  user_agent TEXT,
  ip_address INET,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_password_reset_requests_email
  ON public.password_reset_requests(email);
CREATE INDEX IF NOT EXISTS idx_password_reset_requests_created_at
  ON public.password_reset_requests(created_at DESC);

CREATE TABLE IF NOT EXISTS public.password_change_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reason TEXT NOT NULL DEFAULT 'change',
  user_agent TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb
  -- password hashes intentionally omitted (Supabase Auth owns credentials;
  -- historyLimit is future-ready for Edge Function hashing)
);

CREATE INDEX IF NOT EXISTS idx_password_change_history_user_id
  ON public.password_change_history(user_id);

-- Adaptive password policies by role (Admin Panel editable)
CREATE TABLE IF NOT EXISTS public.password_policies (
  role_slug TEXT PRIMARY KEY,
  min_length INT NOT NULL DEFAULT 8,
  max_length INT NOT NULL DEFAULT 128,
  require_uppercase BOOLEAN NOT NULL DEFAULT true,
  require_lowercase BOOLEAN NOT NULL DEFAULT true,
  require_number BOOLEAN NOT NULL DEFAULT true,
  require_special BOOLEAN NOT NULL DEFAULT true,
  history_limit INT NOT NULL DEFAULT 5,
  prevent_reuse BOOLEAN NOT NULL DEFAULT false,
  expiry_days INT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.password_policies (
  role_slug, min_length, prevent_reuse, history_limit
) VALUES
  ('client', 8, false, 5),
  ('investor', 8, false, 5),
  ('sales_team', 10, true, 5),
  ('finance', 10, true, 5),
  ('marketing', 10, true, 5),
  ('construction_manager', 10, true, 5),
  ('admin', 12, true, 5),
  ('super_admin', 12, true, 5)
ON CONFLICT (role_slug) DO NOTHING;

ALTER TABLE public.password_reset_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.password_change_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.password_policies ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS password_reset_insert ON public.password_reset_requests;
CREATE POLICY password_reset_insert ON public.password_reset_requests
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS password_reset_staff ON public.password_reset_requests;
CREATE POLICY password_reset_staff ON public.password_reset_requests
  FOR SELECT USING (
    public.has_role('admin') OR public.has_role('super_admin')
    OR (user_id IS NOT NULL AND user_id = auth.uid())
  );

DROP POLICY IF EXISTS password_change_own ON public.password_change_history;
CREATE POLICY password_change_own ON public.password_change_history
  FOR SELECT USING (
    user_id = auth.uid()
    OR public.has_role('admin')
    OR public.has_role('super_admin')
  );

DROP POLICY IF EXISTS password_change_insert ON public.password_change_history;
CREATE POLICY password_change_insert ON public.password_change_history
  FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS password_policies_read ON public.password_policies;
CREATE POLICY password_policies_read ON public.password_policies
  FOR SELECT USING (true);

GRANT INSERT ON public.password_reset_requests TO anon, authenticated;
GRANT SELECT ON public.password_reset_requests TO authenticated;
GRANT SELECT, INSERT ON public.password_change_history TO authenticated;
GRANT SELECT ON public.password_policies TO anon, authenticated;
