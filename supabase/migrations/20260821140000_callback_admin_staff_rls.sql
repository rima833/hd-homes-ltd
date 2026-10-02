-- Callback admin: allow is_staff to manage requests/settings/catalog.
-- Applied remotely as callback_admin_rls_and_staff_rpc.

DROP POLICY IF EXISTS callback_requests_admin ON public.callback_requests;
CREATE POLICY callback_requests_admin ON public.callback_requests
  FOR ALL TO authenticated
  USING (
    public.has_permission('callbacks.view', auth.uid())
    OR public.has_permission('callbacks.manage', auth.uid())
    OR public.has_permission('crm.leads', auth.uid())
    OR public.is_staff(auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('callbacks.manage', auth.uid())
    OR public.has_permission('crm.leads', auth.uid())
    OR public.is_staff(auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

DROP POLICY IF EXISTS callback_settings_admin ON public.callback_settings;
CREATE POLICY callback_settings_admin ON public.callback_settings
  FOR ALL TO authenticated
  USING (public.has_permission('callbacks.settings', auth.uid()) OR public.is_staff(auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('callbacks.settings', auth.uid()) OR public.is_staff(auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS callback_departments_admin ON public.callback_departments;
CREATE POLICY callback_departments_admin ON public.callback_departments
  FOR ALL TO authenticated
  USING (public.has_permission('callbacks.settings', auth.uid()) OR public.is_staff(auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('callbacks.settings', auth.uid()) OR public.is_staff(auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS callback_priorities_admin ON public.callback_priorities;
CREATE POLICY callback_priorities_admin ON public.callback_priorities
  FOR ALL TO authenticated
  USING (public.has_permission('callbacks.settings', auth.uid()) OR public.is_staff(auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('callbacks.settings', auth.uid()) OR public.is_staff(auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS callback_working_hours_admin ON public.callback_working_hours;
CREATE POLICY callback_working_hours_admin ON public.callback_working_hours
  FOR ALL TO authenticated
  USING (public.has_permission('callbacks.settings', auth.uid()) OR public.is_staff(auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('callbacks.settings', auth.uid()) OR public.is_staff(auth.uid()) OR public.has_role('super_admin', auth.uid()));
