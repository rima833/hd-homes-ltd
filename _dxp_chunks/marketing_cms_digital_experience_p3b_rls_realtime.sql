-- Remainder of p3 after truncation (from email_campaigns_select onward)
DROP POLICY IF EXISTS email_campaigns_select ON public.email_campaigns;
DROP POLICY IF EXISTS email_campaigns_write ON public.email_campaigns;
CREATE POLICY email_campaigns_select ON public.email_campaigns FOR SELECT
  USING (public.has_permission('marketing.read', auth.uid()) OR public.has_permission('marketing.campaigns', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY email_campaigns_write ON public.email_campaigns FOR ALL
  USING (public.has_permission('marketing.campaigns', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.campaigns', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS sms_campaigns_select ON public.sms_campaigns;
DROP POLICY IF EXISTS sms_campaigns_write ON public.sms_campaigns;
CREATE POLICY sms_campaigns_select ON public.sms_campaigns FOR SELECT
  USING (public.has_permission('marketing.read', auth.uid()) OR public.has_permission('marketing.campaigns', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY sms_campaigns_write ON public.sms_campaigns FOR ALL
  USING (public.has_permission('marketing.campaigns', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.campaigns', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS whatsapp_campaigns_select ON public.whatsapp_campaigns;
DROP POLICY IF EXISTS whatsapp_campaigns_write ON public.whatsapp_campaigns;
CREATE POLICY whatsapp_campaigns_select ON public.whatsapp_campaigns FOR SELECT
  USING (public.has_permission('marketing.read', auth.uid()) OR public.has_permission('marketing.campaigns', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY whatsapp_campaigns_write ON public.whatsapp_campaigns FOR ALL
  USING (public.has_permission('marketing.campaigns', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.campaigns', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS push_campaigns_select ON public.push_campaigns;
DROP POLICY IF EXISTS push_campaigns_write ON public.push_campaigns;
CREATE POLICY push_campaigns_select ON public.push_campaigns FOR SELECT
  USING (public.has_permission('marketing.read', auth.uid()) OR public.has_permission('marketing.campaigns', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY push_campaigns_write ON public.push_campaigns FOR ALL
  USING (public.has_permission('marketing.campaigns', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.campaigns', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS forms_select ON public.forms;
DROP POLICY IF EXISTS forms_write ON public.forms;
CREATE POLICY forms_select ON public.forms FOR SELECT
  USING (
    is_active = true
    OR public.has_permission('marketing.read', auth.uid())
    OR public.has_permission('marketing.forms', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY forms_write ON public.forms FOR ALL
  USING (public.has_permission('marketing.forms', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.forms', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS form_submissions_select ON public.form_submissions;
DROP POLICY IF EXISTS form_submissions_insert ON public.form_submissions;
DROP POLICY IF EXISTS form_submissions_write ON public.form_submissions;
CREATE POLICY form_submissions_select ON public.form_submissions FOR SELECT
  USING (public.has_permission('marketing.read', auth.uid()) OR public.has_permission('marketing.forms', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY form_submissions_insert ON public.form_submissions FOR INSERT
  WITH CHECK (true);
CREATE POLICY form_submissions_write ON public.form_submissions FOR UPDATE
  USING (public.has_permission('marketing.forms', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.forms', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS dxp_personalization_rules_select ON public.dxp_personalization_rules;
DROP POLICY IF EXISTS dxp_personalization_rules_write ON public.dxp_personalization_rules;
CREATE POLICY dxp_personalization_rules_select ON public.dxp_personalization_rules FOR SELECT
  USING (public.has_permission('marketing.read', auth.uid()) OR public.has_permission('marketing.cms', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY dxp_personalization_rules_write ON public.dxp_personalization_rules FOR ALL
  USING (public.has_permission('marketing.cms', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.cms', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS ab_tests_select ON public.ab_tests;
DROP POLICY IF EXISTS ab_tests_write ON public.ab_tests;
CREATE POLICY ab_tests_select ON public.ab_tests FOR SELECT
  USING (public.has_permission('marketing.read', auth.uid()) OR public.has_permission('marketing.analytics', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY ab_tests_write ON public.ab_tests FOR ALL
  USING (public.has_permission('marketing.analytics', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.analytics', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS content_calendar_select ON public.content_calendar;
DROP POLICY IF EXISTS content_calendar_write ON public.content_calendar;
CREATE POLICY content_calendar_select ON public.content_calendar FOR SELECT
  USING (public.has_permission('marketing.read', auth.uid()) OR public.has_permission('marketing.cms', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY content_calendar_write ON public.content_calendar FOR ALL
  USING (public.has_permission('marketing.cms', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.cms', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS social_accounts_select ON public.social_accounts;
DROP POLICY IF EXISTS social_accounts_write ON public.social_accounts;
CREATE POLICY social_accounts_select ON public.social_accounts FOR SELECT
  USING (public.has_permission('marketing.read', auth.uid()) OR public.has_permission('marketing.social', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY social_accounts_write ON public.social_accounts FOR ALL
  USING (public.has_permission('marketing.social', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.social', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS social_posts_select ON public.social_posts;
DROP POLICY IF EXISTS social_posts_write ON public.social_posts;
CREATE POLICY social_posts_select ON public.social_posts FOR SELECT
  USING (public.has_permission('marketing.read', auth.uid()) OR public.has_permission('marketing.social', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY social_posts_write ON public.social_posts FOR ALL
  USING (public.has_permission('marketing.social', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.social', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS marketing_analytics_select ON public.marketing_analytics;
DROP POLICY IF EXISTS marketing_analytics_write ON public.marketing_analytics;
CREATE POLICY marketing_analytics_select ON public.marketing_analytics FOR SELECT
  USING (public.has_permission('marketing.read', auth.uid()) OR public.has_permission('marketing.analytics', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY marketing_analytics_write ON public.marketing_analytics FOR ALL
  USING (public.has_permission('marketing.analytics', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.analytics', auth.uid()) OR public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS marketing_activity_logs_select ON public.marketing_activity_logs;
DROP POLICY IF EXISTS marketing_activity_logs_write ON public.marketing_activity_logs;
CREATE POLICY marketing_activity_logs_select ON public.marketing_activity_logs FOR SELECT
  USING (public.has_permission('marketing.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY marketing_activity_logs_write ON public.marketing_activity_logs FOR ALL
  USING (public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

DROP POLICY IF EXISTS marketing_notifications_select ON public.marketing_notifications;
DROP POLICY IF EXISTS marketing_notifications_write ON public.marketing_notifications;
CREATE POLICY marketing_notifications_select ON public.marketing_notifications FOR SELECT
  USING (public.has_permission('marketing.read', auth.uid()) OR public.has_role('super_admin', auth.uid()));
CREATE POLICY marketing_notifications_write ON public.marketing_notifications FOR ALL
  USING (public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()))
  WITH CHECK (public.has_permission('marketing.write', auth.uid()) OR public.has_role('super_admin', auth.uid()));

-- Enrichment policies on legacy campaigns / seo / pages for marketing.* staff
DROP POLICY IF EXISTS campaigns_marketing_select ON public.campaigns;
DROP POLICY IF EXISTS campaigns_marketing_write ON public.campaigns;
CREATE POLICY campaigns_marketing_select ON public.campaigns FOR SELECT
  USING (
    public.has_permission('marketing.read', auth.uid())
    OR public.has_permission('marketing.campaigns', auth.uid())
    OR public.has_permission('manage_marketing', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );
CREATE POLICY campaigns_marketing_write ON public.campaigns FOR ALL
  USING (
    public.has_permission('marketing.campaigns', auth.uid())
    OR public.has_permission('marketing.write', auth.uid())
    OR public.has_permission('manage_marketing', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  )
  WITH CHECK (
    public.has_permission('marketing.campaigns', auth.uid())
    OR public.has_permission('marketing.write', auth.uid())
    OR public.has_permission('manage_marketing', auth.uid())
    OR public.has_role('super_admin', auth.uid())
  );

-- Grants
GRANT SELECT, INSERT, UPDATE, DELETE ON public.cms_templates TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.cms_page_versions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.cms_sections TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.landing_pages TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.landing_page_versions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.blog_authors TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.blog_tags TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.blog_tag_links TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.media_folders TO authenticated;
GRANT SELECT ON public.media_library TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.seo_metadata TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.redirects TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.audience_segments TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.campaign_audiences TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.email_templates TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.email_campaigns TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.sms_campaigns TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.whatsapp_campaigns TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.push_campaigns TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.forms TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.form_submissions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.dxp_personalization_rules TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.ab_tests TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.content_calendar TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.social_accounts TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.social_posts TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.marketing_analytics TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.marketing_activity_logs TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.marketing_notifications TO authenticated;

-- Public anon can insert form submissions + read published landing pages (via RLS)
GRANT SELECT ON public.landing_pages TO anon;
GRANT SELECT ON public.forms TO anon;
GRANT INSERT ON public.form_submissions TO anon;
GRANT SELECT ON public.blog_authors TO anon;
GRANT SELECT ON public.blog_tags TO anon;
GRANT SELECT ON public.blog_tag_links TO anon;

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'landing_pages',
    'forms',
    'form_submissions',
    'campaigns',
    'email_campaigns',
    'content_calendar',
    'marketing_activity_logs',
    'blogs'
  ]
  LOOP
    BEGIN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    EXCEPTION WHEN duplicate_object THEN
      NULL;
    END;
  END LOOP;
END $$;

