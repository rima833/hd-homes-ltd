-- Allow is_staff to operate CRM write paths (sales desk).
-- Applied remotely as crm_staff_write_access.

DROP POLICY IF EXISTS crm_clients_write ON public.crm_clients;
CREATE POLICY crm_clients_write ON public.crm_clients FOR ALL TO authenticated
  USING (public.has_permission('crm.write', auth.uid()) OR public.is_staff(auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('crm.write', auth.uid()) OR public.is_staff(auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS crm_leads_write ON public.crm_leads;
CREATE POLICY crm_leads_write ON public.crm_leads FOR ALL TO authenticated
  USING (public.has_permission('crm.write', auth.uid()) OR public.has_permission('crm.leads', auth.uid()) OR public.is_staff(auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('crm.write', auth.uid()) OR public.has_permission('crm.leads', auth.uid()) OR public.is_staff(auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS crm_pipeline_history_write ON public.crm_pipeline_history;
CREATE POLICY crm_pipeline_history_write ON public.crm_pipeline_history FOR ALL TO authenticated
  USING (public.has_permission('crm.write', auth.uid()) OR public.has_permission('crm.pipeline', auth.uid()) OR public.is_staff(auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('crm.write', auth.uid()) OR public.has_permission('crm.pipeline', auth.uid()) OR public.is_staff(auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS crm_tasks_write ON public.crm_tasks;
CREATE POLICY crm_tasks_write ON public.crm_tasks FOR ALL TO authenticated
  USING (public.has_permission('crm.write', auth.uid()) OR public.has_permission('crm.tasks', auth.uid()) OR public.is_staff(auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('crm.write', auth.uid()) OR public.has_permission('crm.tasks', auth.uid()) OR public.is_staff(auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS crm_appointments_write ON public.crm_appointments;
CREATE POLICY crm_appointments_write ON public.crm_appointments FOR ALL TO authenticated
  USING (public.has_permission('crm.write', auth.uid()) OR public.is_staff(auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('crm.write', auth.uid()) OR public.is_staff(auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS crm_notes_write ON public.crm_notes;
CREATE POLICY crm_notes_write ON public.crm_notes FOR ALL TO authenticated
  USING (public.has_permission('crm.write', auth.uid()) OR public.is_staff(auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('crm.write', auth.uid()) OR public.is_staff(auth.uid()) OR public.has_role('super_admin', auth.uid()));
