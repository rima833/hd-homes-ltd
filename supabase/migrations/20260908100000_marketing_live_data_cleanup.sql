-- Marketing Command Center production cleanup.
-- Removes the original d480... fixture graph and installs audit logging for
-- real campaign, landing, calendar, and form-submission operations.

BEGIN;

-- CRM rows created when the fixture form submissions were backfilled.
DELETE FROM public.crm_activity_logs
WHERE (payload->>'crm_lead_id')::uuid IN (
  SELECT crm_lead_id
  FROM public.form_submissions
  WHERE id::text LIKE 'd4800000-%'
    AND crm_lead_id IS NOT NULL
);

DELETE FROM public.crm_leads
WHERE id IN (
  SELECT crm_lead_id
  FROM public.form_submissions
  WHERE id::text LIKE 'd4800000-%'
    AND crm_lead_id IS NOT NULL
);

DELETE FROM public.marketing_notifications
WHERE id::text LIKE 'd4800000-%';
DELETE FROM public.marketing_activity_logs
WHERE id::text LIKE 'd4800000-%';
DELETE FROM public.marketing_analytics
WHERE id::text LIKE 'd4800000-%';

DELETE FROM public.social_posts
WHERE id::text LIKE 'd4800000-%';
DELETE FROM public.social_accounts
WHERE id::text LIKE 'd4800000-%';

DELETE FROM public.content_calendar
WHERE id::text LIKE 'd4800000-%'
   OR notes = 'Created by agent smoke test';
DELETE FROM public.dxp_personalization_rules
WHERE id::text LIKE 'd4800000-%';
DELETE FROM public.ab_tests
WHERE id::text LIKE 'd4800000-%';
DELETE FROM public.redirects
WHERE id::text LIKE 'd4800000-%';
DELETE FROM public.seo_metadata
WHERE id::text LIKE 'd4800000-%';

DELETE FROM public.form_submissions
WHERE id::text LIKE 'd4800000-%';
DELETE FROM public.forms
WHERE id::text LIKE 'd4800000-%';

DELETE FROM public.email_campaigns
WHERE id::text LIKE 'd4800000-%';
DELETE FROM public.sms_campaigns
WHERE id::text LIKE 'd4800000-%';
DELETE FROM public.whatsapp_campaigns
WHERE id::text LIKE 'd4800000-%';
DELETE FROM public.push_campaigns
WHERE id::text LIKE 'd4800000-%';
DELETE FROM public.campaign_audiences
WHERE id::text LIKE 'd4800000-%';
DELETE FROM public.campaigns
WHERE id::text LIKE 'd4800000-%';
DELETE FROM public.audience_segments
WHERE id::text LIKE 'd4800000-%';
DELETE FROM public.email_templates
WHERE id::text LIKE 'd4800000-%';

DELETE FROM public.blog_tag_links
WHERE blog_id::text LIKE 'd4800000-%'
   OR tag_id::text LIKE 'd4800000-%';
DELETE FROM public.blogs
WHERE id::text LIKE 'd4800000-%';
DELETE FROM public.blog_tags t
WHERE t.id::text LIKE 'd4800000-%'
  AND NOT EXISTS (
    SELECT 1 FROM public.blog_tag_links l WHERE l.tag_id = t.id
  );
DELETE FROM public.blog_authors a
WHERE a.id::text LIKE 'd4800000-%'
  AND NOT EXISTS (
    SELECT 1 FROM public.blogs b WHERE b.blog_author_id = a.id
  );

DELETE FROM public.landing_page_versions
WHERE id::text LIKE 'd4800000-%';
DELETE FROM public.cms_sections
WHERE id::text LIKE 'd4800000-%';
DELETE FROM public.landing_pages
WHERE id::text LIKE 'd4800000-%';

CREATE OR REPLACE FUNCTION public.log_marketing_campaign_activity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.campaigns%ROWTYPE;
  v_action text;
BEGIN
  IF TG_OP = 'DELETE' THEN v_row := OLD; ELSE v_row := NEW; END IF;
  v_action := CASE
    WHEN TG_OP = 'INSERT' THEN 'campaign.created'
    WHEN TG_OP = 'DELETE' THEN 'campaign.deleted'
    WHEN OLD.status IS DISTINCT FROM NEW.status THEN 'campaign.status_changed'
    ELSE 'campaign.updated'
  END;

  INSERT INTO public.marketing_activity_logs (
    action, summary, actor_label, entity_type, entity_id, metadata
  ) VALUES (
    v_action,
    CASE
      WHEN TG_OP = 'INSERT' THEN 'Created campaign “' || v_row.name || '”'
      WHEN TG_OP = 'DELETE' THEN 'Deleted campaign “' || v_row.name || '”'
      WHEN OLD.status IS DISTINCT FROM NEW.status
        THEN 'Campaign “' || v_row.name || '” changed to ' || v_row.status
      ELSE 'Updated campaign “' || v_row.name || '”'
    END,
    coalesce(auth.jwt()->>'email', 'System'),
    'campaign',
    v_row.id,
    jsonb_build_object('status', v_row.status, 'channel', v_row.channel)
  );
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_log_marketing_campaign_activity ON public.campaigns;
CREATE TRIGGER trg_log_marketing_campaign_activity
AFTER INSERT OR UPDATE OR DELETE ON public.campaigns
FOR EACH ROW EXECUTE FUNCTION public.log_marketing_campaign_activity();

CREATE OR REPLACE FUNCTION public.log_marketing_landing_activity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.landing_pages%ROWTYPE;
  v_action text;
BEGIN
  IF TG_OP = 'DELETE' THEN v_row := OLD; ELSE v_row := NEW; END IF;
  v_action := CASE
    WHEN TG_OP = 'INSERT' THEN 'landing.created'
    WHEN TG_OP = 'DELETE' THEN 'landing.deleted'
    WHEN OLD.is_published IS DISTINCT FROM NEW.is_published
      THEN CASE WHEN NEW.is_published THEN 'landing.published' ELSE 'landing.unpublished' END
    ELSE 'landing.updated'
  END;

  INSERT INTO public.marketing_activity_logs (
    action, summary, actor_label, entity_type, entity_id, metadata
  ) VALUES (
    v_action,
    CASE
      WHEN TG_OP = 'INSERT' THEN 'Created landing page “' || v_row.title || '”'
      WHEN TG_OP = 'DELETE' THEN 'Deleted landing page “' || v_row.title || '”'
      WHEN OLD.is_published IS DISTINCT FROM NEW.is_published
        THEN CASE
          WHEN NEW.is_published THEN 'Published landing page “' || v_row.title || '”'
          ELSE 'Unpublished landing page “' || v_row.title || '”'
        END
      ELSE 'Updated landing page “' || v_row.title || '”'
    END,
    coalesce(auth.jwt()->>'email', 'System'),
    'landing_page',
    v_row.id,
    jsonb_build_object('status', v_row.status, 'slug', v_row.slug)
  );
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_log_marketing_landing_activity ON public.landing_pages;
CREATE TRIGGER trg_log_marketing_landing_activity
AFTER INSERT OR UPDATE OR DELETE ON public.landing_pages
FOR EACH ROW EXECUTE FUNCTION public.log_marketing_landing_activity();

CREATE OR REPLACE FUNCTION public.log_marketing_calendar_activity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.content_calendar%ROWTYPE;
BEGIN
  IF TG_OP = 'DELETE' THEN v_row := OLD; ELSE v_row := NEW; END IF;
  INSERT INTO public.marketing_activity_logs (
    action, summary, actor_label, entity_type, entity_id, metadata
  ) VALUES (
    'calendar.' || lower(TG_OP),
    initcap(lower(TG_OP)) || ' calendar item “' || v_row.title || '”',
    coalesce(auth.jwt()->>'email', 'System'),
    'content_calendar',
    v_row.id,
    jsonb_build_object(
      'status', v_row.status,
      'channel', v_row.channel,
      'scheduled_for', v_row.scheduled_for
    )
  );
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_log_marketing_calendar_activity ON public.content_calendar;
CREATE TRIGGER trg_log_marketing_calendar_activity
AFTER INSERT OR UPDATE OR DELETE ON public.content_calendar
FOR EACH ROW EXECUTE FUNCTION public.log_marketing_calendar_activity();

CREATE OR REPLACE FUNCTION public.log_marketing_form_submission_activity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.marketing_activity_logs (
    action, summary, actor_label, entity_type, entity_id, metadata
  ) VALUES (
    'form.submitted',
    'Received website form submission',
    'Website',
    'form_submission',
    NEW.id,
    jsonb_build_object(
      'form_id', NEW.form_id,
      'source_path', NEW.source_path,
      'crm_synced', NEW.crm_lead_id IS NOT NULL
    )
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_log_marketing_form_submission_activity
  ON public.form_submissions;
CREATE TRIGGER trg_log_marketing_form_submission_activity
AFTER INSERT ON public.form_submissions
FOR EACH ROW EXECUTE FUNCTION public.log_marketing_form_submission_activity();

COMMIT;
