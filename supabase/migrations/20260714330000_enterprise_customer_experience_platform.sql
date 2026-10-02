-- APPLIED remotely (2026-07-21) via MCP chunks: ecxp_p1a, ecxp_p1b, ecxp_p2, ecxp_p3
-- Volume 4 Part 22 — Enterprise Customer Experience (CX), Omnichannel Engagement,
-- Loyalty & Personalization Platform (ECXP)
-- ENRICHES customer_feedback / personalization_profiles in place. Never recreates them.
-- Does NOT recreate csat_surveys, nps_surveys, crm_referrals, crm_segments,
-- audience_segments, dxp_personalization_rules, or /dashboard/personalization.
-- Permissions use (slug, name, description, module); has_permission slug is FIRST.
-- Seed UUIDs are hex-only e220….

BEGIN;

INSERT INTO public.permissions (slug, name, description, module) VALUES
 ('cx.read','View CX','View Customer Experience Command Center','cx'),
 ('cx.write','Manage CX','Create and update CX records','cx'),
 ('cx.journeys','Journeys','Manage customer journeys','cx'),
 ('cx.omnichannel','Omnichannel','Manage touchpoints and channels','cx'),
 ('cx.personalization','Personalization','Manage personalization rules','cx'),
 ('cx.loyalty','Loyalty','Manage loyalty programs and rewards','cx'),
 ('cx.success','Customer Success','Manage success plans and tasks','cx'),
 ('cx.health','Health Scoring','View and manage customer health','cx'),
 ('cx.feedback','Feedback','Manage surveys, reviews, and feedback','cx'),
 ('cx.segments','Segments','Manage customer segments','cx'),
 ('cx.analytics','CX Analytics','View journey and CX analytics','cx'),
 ('cx.ai','CX AI','View CX AI insights','cx'),
 ('cx.admin','CX Administration','Administer the Customer Experience Platform','cx')
ON CONFLICT (slug) DO UPDATE SET
 name=EXCLUDED.name, description=EXCLUDED.description, module=EXCLUDED.module, updated_at=now();

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM public.roles r CROSS JOIN public.permissions p
WHERE p.slug LIKE 'cx.%' AND (
 r.slug IN ('super_admin','admin')
 OR (r.slug='finance' AND p.slug IN ('cx.read','cx.analytics','cx.health'))
 OR (r.slug='sales_team' AND p.slug IN ('cx.read','cx.journeys','cx.loyalty','cx.success'))
 OR (r.slug='marketing' AND p.slug IN ('cx.read','cx.personalization','cx.segments','cx.loyalty','cx.feedback'))
 OR (r.slug='construction_manager' AND p.slug IN ('cx.read','cx.success'))
) ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS public.customer_profiles_360 (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'customer', status text NOT NULL DEFAULT 'active',
 severity text NOT NULL DEFAULT 'info', display_name text, email text, phone text,
 loyalty_tier text, health_label text, clv_amount numeric, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.customer_touchpoints (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 customer_id uuid REFERENCES public.customer_profiles_360(id) ON DELETE CASCADE,
 title text NOT NULL, category text NOT NULL DEFAULT 'touchpoint',
 channel text NOT NULL DEFAULT 'website', status text NOT NULL DEFAULT 'recorded',
 severity text NOT NULL DEFAULT 'info', summary text,
 occurred_at timestamptz NOT NULL DEFAULT now(),
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.customer_timelines (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 customer_id uuid REFERENCES public.customer_profiles_360(id) ON DELETE CASCADE,
 title text NOT NULL, category text NOT NULL DEFAULT 'timeline',
 status text NOT NULL DEFAULT 'recorded', severity text NOT NULL DEFAULT 'info',
 actor_label text, summary text, occurred_at timestamptz NOT NULL DEFAULT now(),
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.customer_channels (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'channel', channel_type text NOT NULL DEFAULT 'digital',
 status text NOT NULL DEFAULT 'active', summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.customer_journeys (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'journey', journey_type text NOT NULL DEFAULT 'lead_nurture',
 status text NOT NULL DEFAULT 'active', severity text NOT NULL DEFAULT 'info',
 owner_label text, summary text, metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.journey_steps (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 journey_id uuid NOT NULL REFERENCES public.customer_journeys(id) ON DELETE CASCADE,
 title text NOT NULL, step_order int NOT NULL DEFAULT 1,
 status text NOT NULL DEFAULT 'planned', summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.journey_executions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 journey_id uuid NOT NULL REFERENCES public.customer_journeys(id) ON DELETE CASCADE,
 customer_id uuid REFERENCES public.customer_profiles_360(id) ON DELETE SET NULL,
 title text NOT NULL, category text NOT NULL DEFAULT 'execution',
 status text NOT NULL DEFAULT 'in_progress', severity text NOT NULL DEFAULT 'info',
 current_step text, summary text, started_at timestamptz NOT NULL DEFAULT now(),
 completed_at timestamptz, metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

-- Volume 3 personalization_profiles: enrich only — never DROP/recreate.
ALTER TABLE public.personalization_profiles
 ADD COLUMN IF NOT EXISTS cx_surface text,
 ADD COLUMN IF NOT EXISTS engagement_score numeric,
 ADD COLUMN IF NOT EXISTS budget_band text,
 ADD COLUMN IF NOT EXISTS preferred_channel text,
 ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb;

CREATE TABLE IF NOT EXISTS public.personalization_rules (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'personalization', rule_type text NOT NULL DEFAULT 'recommendation',
 status text NOT NULL DEFAULT 'active', severity text NOT NULL DEFAULT 'info',
 summary text, rule_config jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.recommendation_history (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 customer_id uuid REFERENCES public.customer_profiles_360(id) ON DELETE SET NULL,
 title text NOT NULL, category text NOT NULL DEFAULT 'recommendation',
 status text NOT NULL DEFAULT 'served', severity text NOT NULL DEFAULT 'info',
 reason text, summary text, served_at timestamptz NOT NULL DEFAULT now(),
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.loyalty_programs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'loyalty', status text NOT NULL DEFAULT 'active',
 summary text, metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.loyalty_tiers (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 program_id uuid REFERENCES public.loyalty_programs(id) ON DELETE CASCADE,
 code text UNIQUE, title text NOT NULL, tier_rank int NOT NULL DEFAULT 1,
 status text NOT NULL DEFAULT 'active', points_threshold int DEFAULT 0, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.loyalty_points (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 customer_id uuid REFERENCES public.customer_profiles_360(id) ON DELETE CASCADE,
 title text NOT NULL, category text NOT NULL DEFAULT 'points',
 status text NOT NULL DEFAULT 'posted', points int NOT NULL DEFAULT 0,
 summary text, occurred_at timestamptz NOT NULL DEFAULT now(),
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.loyalty_rewards (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'reward', status text NOT NULL DEFAULT 'available',
 points_cost int DEFAULT 0, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.customer_referrals (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'referral', status text NOT NULL DEFAULT 'open',
 severity text NOT NULL DEFAULT 'info', referrer_label text, referee_label text,
 summary text, metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.customer_health_scores (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 customer_id uuid REFERENCES public.customer_profiles_360(id) ON DELETE CASCADE,
 title text NOT NULL, category text NOT NULL DEFAULT 'health',
 status text NOT NULL DEFAULT 'healthy', severity text NOT NULL DEFAULT 'info',
 score numeric, health_label text, summary text, recorded_at timestamptz NOT NULL DEFAULT now(),
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.customer_success_plans (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'success', status text NOT NULL DEFAULT 'active',
 severity text NOT NULL DEFAULT 'info', customer_id uuid REFERENCES public.customer_profiles_360(id) ON DELETE SET NULL,
 csm_label text, summary text, metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.customer_success_tasks (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 plan_id uuid NOT NULL REFERENCES public.customer_success_plans(id) ON DELETE CASCADE,
 title text NOT NULL, category text NOT NULL DEFAULT 'task',
 status text NOT NULL DEFAULT 'open', severity text NOT NULL DEFAULT 'info',
 owner_label text, due_at timestamptz, summary text,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.customer_segments (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'segment', status text NOT NULL DEFAULT 'active',
 segment_type text NOT NULL DEFAULT 'dynamic', member_count int DEFAULT 0, summary text,
 criteria jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

-- CSHOP customer_feedback: enrich only — never DROP/recreate.
ALTER TABLE public.customer_feedback
 ADD COLUMN IF NOT EXISTS title text,
 ADD COLUMN IF NOT EXISTS category text DEFAULT 'feedback',
 ADD COLUMN IF NOT EXISTS status text DEFAULT 'recorded',
 ADD COLUMN IF NOT EXISTS severity text DEFAULT 'info',
 ADD COLUMN IF NOT EXISTS cx_surface text,
 ADD COLUMN IF NOT EXISTS summary text,
 ADD COLUMN IF NOT EXISTS hub_metadata jsonb DEFAULT '{}'::jsonb,
 ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

CREATE TABLE IF NOT EXISTS public.customer_surveys (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'survey', survey_type text NOT NULL DEFAULT 'csat',
 status text NOT NULL DEFAULT 'active', severity text NOT NULL DEFAULT 'info',
 summary text, metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.survey_responses (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 survey_id uuid NOT NULL REFERENCES public.customer_surveys(id) ON DELETE CASCADE,
 title text NOT NULL, category text NOT NULL DEFAULT 'response',
 status text NOT NULL DEFAULT 'submitted', score numeric, respondent_label text, summary text,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.customer_reviews (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'review', status text NOT NULL DEFAULT 'published',
 severity text NOT NULL DEFAULT 'info', rating numeric, author_label text, body text, summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.customer_sentiment (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 customer_id uuid REFERENCES public.customer_profiles_360(id) ON DELETE SET NULL,
 title text NOT NULL, category text NOT NULL DEFAULT 'sentiment',
 status text NOT NULL DEFAULT 'analyzed', severity text NOT NULL DEFAULT 'info',
 sentiment_label text, score numeric, summary text, recorded_at timestamptz NOT NULL DEFAULT now(),
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.journey_analytics (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 metric_key text NOT NULL, category text NOT NULL DEFAULT 'analytics',
 status text NOT NULL DEFAULT 'ok', value numeric, unit text DEFAULT 'pct', summary text,
 series jsonb NOT NULL DEFAULT '[]'::jsonb, recorded_at timestamptz NOT NULL DEFAULT now(),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.cx_reports (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 category text NOT NULL DEFAULT 'report', report_type text NOT NULL DEFAULT 'executive',
 status text NOT NULL DEFAULT 'ready', summary text,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.cx_activity_logs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), action text NOT NULL, title text NOT NULL,
 category text NOT NULL DEFAULT 'cx', actor_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
 actor_label text, entity_type text, entity_id uuid, severity text NOT NULL DEFAULT 'info',
 status text NOT NULL DEFAULT 'recorded', summary text, metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 occurred_at timestamptz NOT NULL DEFAULT now(),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.cx_notifications (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), recipient_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
 title text NOT NULL, category text NOT NULL DEFAULT 'cx', channel text NOT NULL DEFAULT 'in_app',
 severity text NOT NULL DEFAULT 'info', status text NOT NULL DEFAULT 'unread', body text,
 read_at timestamptz, metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.cx_ai_insights (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, title text NOT NULL,
 body text NOT NULL, category text NOT NULL DEFAULT 'cx', insight_type text NOT NULL,
 confidence_pct numeric(5,2), status text NOT NULL DEFAULT 'active', editable boolean NOT NULL DEFAULT true,
 disclaimer text NOT NULL DEFAULT 'AI-generated — editable / advisory',
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_customer_touchpoints_occurred ON public.customer_touchpoints(occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_journey_executions_status ON public.journey_executions(status, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_customer_health_scores_status ON public.customer_health_scores(status, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_loyalty_points_customer ON public.loyalty_points(customer_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_customer_referrals_status ON public.customer_referrals(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_journey_analytics_key ON public.journey_analytics(metric_key, recorded_at DESC);

INSERT INTO storage.buckets (id,name,public) VALUES ('cx-artifacts','cx-artifacts',false)
ON CONFLICT (id) DO NOTHING;

DO $$ BEGIN
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.customer_touchpoints; EXCEPTION WHEN duplicate_object THEN NULL; END;
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.journey_executions; EXCEPTION WHEN duplicate_object THEN NULL; END;
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.loyalty_points; EXCEPTION WHEN duplicate_object THEN NULL; END;
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.customer_health_scores; EXCEPTION WHEN duplicate_object THEN NULL; END;
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.cx_activity_logs; EXCEPTION WHEN duplicate_object THEN NULL; END;
 BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.cx_notifications; EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

DO $$
DECLARE t text;
BEGIN
 FOREACH t IN ARRAY ARRAY[
  'customer_profiles_360','customer_touchpoints','customer_timelines','customer_channels',
  'customer_journeys','journey_steps','journey_executions',
  'personalization_rules','recommendation_history',
  'loyalty_programs','loyalty_tiers','loyalty_points','loyalty_rewards',
  'customer_referrals','customer_health_scores','customer_success_plans','customer_success_tasks',
  'customer_segments','customer_surveys','survey_responses','customer_reviews','customer_sentiment',
  'journey_analytics','cx_reports','cx_activity_logs','cx_notifications','cx_ai_insights'
 ] LOOP
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
  EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_select', t);
  EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_write', t);
  EXECUTE format(
   'CREATE POLICY %I ON public.%I FOR SELECT USING (public.has_permission(''cx.read'', auth.uid()) OR public.has_permission(''cx.admin'', auth.uid()) OR public.has_role(''super_admin'', auth.uid()))',
   t || '_select', t
  );
  EXECUTE format(
   'CREATE POLICY %I ON public.%I FOR ALL USING (public.has_permission(''cx.write'', auth.uid()) OR public.has_permission(''cx.admin'', auth.uid()) OR public.has_role(''super_admin'', auth.uid())) WITH CHECK (public.has_permission(''cx.write'', auth.uid()) OR public.has_permission(''cx.admin'', auth.uid()) OR public.has_role(''super_admin'', auth.uid()))',
   t || '_write', t
  );
 END LOOP;
END $$;

GRANT SELECT, INSERT, UPDATE, DELETE ON
 public.customer_profiles_360, public.customer_touchpoints, public.customer_timelines, public.customer_channels,
 public.customer_journeys, public.journey_steps, public.journey_executions,
 public.personalization_rules, public.recommendation_history,
 public.loyalty_programs, public.loyalty_tiers, public.loyalty_points, public.loyalty_rewards,
 public.customer_referrals, public.customer_health_scores, public.customer_success_plans, public.customer_success_tasks,
 public.customer_segments, public.customer_surveys, public.survey_responses, public.customer_reviews, public.customer_sentiment,
 public.journey_analytics, public.cx_reports, public.cx_activity_logs, public.cx_notifications, public.cx_ai_insights
TO authenticated;

-- Phase 1 demo seeds (hex-only e220…).
INSERT INTO public.customer_profiles_360 (id,code,title,display_name,email,loyalty_tier,health_label,clv_amount,status,summary) VALUES
 ('e2200001-0000-4000-8000-000000000001','CX-360-001','Adaeze Nwosu','Adaeze Nwosu','adaeze@example.com','Gold','healthy',18500000,'active','Buyer + loyalty member'),
 ('e2200001-0000-4000-8000-000000000002','CX-360-002','Tunde Bakare','Tunde Bakare','tunde@example.com','Silver','needs_attention',6200000,'active','At-risk engagement')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.customer_channels (id,code,title,channel_type,status,summary) VALUES
 ('e2200002-0000-4000-8000-000000000001','CH-WEB','Website','digital','active','Public site + property browse'),
 ('e2200002-0000-4000-8000-000000000002','CH-PORTAL','Customer Portal','digital','active','Authenticated owner experience'),
 ('e2200002-0000-4000-8000-000000000003','CH-EMAIL','Email','digital','active','Lifecycle and nurture')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.customer_touchpoints (id,customer_id,title,channel,status,summary) VALUES
 ('e2200003-0000-4000-8000-000000000001','e2200001-0000-4000-8000-000000000001','Viewed Lekki duplex listing','website','recorded','High-intent browse'),
 ('e2200003-0000-4000-8000-000000000002','e2200001-0000-4000-8000-000000000001','Opened reservation confirmation','email','recorded','Payment journey step')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.customer_timelines (id,customer_id,title,category,actor_label,summary) VALUES
 ('e2200003-0000-4000-8000-000000000003','e2200001-0000-4000-8000-000000000001','Lead converted to reservation','sales','Sales Team','Milestone logged')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.customer_journeys (id,code,title,journey_type,status,owner_label,summary) VALUES
 ('e2200004-0000-4000-8000-000000000001','JRN-LEAD','Lead nurturing journey','lead_nurture','active','Marketing','Welcome → consult → reserve'),
 ('e2200004-0000-4000-8000-000000000002','JRN-OWNER','Owner success journey','owner','active','Customer Success','Handover → support → referral')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.journey_steps (id,journey_id,title,step_order,status,summary) VALUES
 ('e2200004-0000-4000-8000-000000000003','e2200004-0000-4000-8000-000000000001','Welcome',1,'planned','Intro email'),
 ('e2200004-0000-4000-8000-000000000004','e2200004-0000-4000-8000-000000000001','Property recommendations',2,'planned','Personalized listings'),
 ('e2200004-0000-4000-8000-000000000005','e2200004-0000-4000-8000-000000000001','Consultation',3,'planned','Sales call')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.journey_executions (id,journey_id,customer_id,title,status,current_step,summary) VALUES
 ('e2200004-0000-4000-8000-000000000006','e2200004-0000-4000-8000-000000000001','e2200001-0000-4000-8000-000000000001','Adaeze lead nurture','in_progress','Property recommendations','Active nurture')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.personalization_rules (id,code,title,rule_type,status,summary,rule_config) VALUES
 ('e2200005-0000-4000-8000-000000000001','PR-BUDGET-LAGOS','Lagos mid-budget listings','recommendation','active','Match budget + location','{"budget":"15-25m","city":"Lagos"}'::jsonb)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.recommendation_history (id,customer_id,title,status,reason,summary) VALUES
 ('e2200005-0000-4000-8000-000000000002','e2200001-0000-4000-8000-000000000001','Recommended Lekki duplex','served','Budget + browse history','Explainable next-best property')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.loyalty_programs (id,code,title,status,summary) VALUES
 ('e2200006-0000-4000-8000-000000000001','LOY-HD','HD Homes Loyalty','active','Points + tier program')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.loyalty_tiers (id,program_id,code,title,tier_rank,points_threshold,status,summary) VALUES
 ('e2200006-0000-4000-8000-000000000002','e2200006-0000-4000-8000-000000000001','TIER-BRONZE','Bronze',1,0,'active','Entry'),
 ('e2200006-0000-4000-8000-000000000003','e2200006-0000-4000-8000-000000000001','TIER-SILVER','Silver',2,1000,'active','Growing'),
 ('e2200006-0000-4000-8000-000000000004','e2200006-0000-4000-8000-000000000001','TIER-GOLD','Gold',3,5000,'active','High value'),
 ('e2200006-0000-4000-8000-000000000005','e2200006-0000-4000-8000-000000000001','TIER-PLATINUM','Platinum',4,15000,'active','VIP'),
 ('e2200006-0000-4000-8000-000000000006','e2200006-0000-4000-8000-000000000001','TIER-DIAMOND','Diamond',5,40000,'active','Advocacy')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.loyalty_points (id,customer_id,title,points,status,summary) VALUES
 ('e2200006-0000-4000-8000-000000000007','e2200001-0000-4000-8000-000000000001','Reservation bonus',2500,'posted','Gold progress')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.loyalty_rewards (id,code,title,points_cost,status,summary) VALUES
 ('e2200006-0000-4000-8000-000000000008','RWD-SITE','Exclusive site tour',800,'available','VIP preview invite')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.customer_referrals (id,code,title,status,referrer_label,referee_label,summary) VALUES
 ('e2200007-0000-4000-8000-000000000001','REF-2026-018','Adaeze referred Chiamaka','open','Adaeze Nwosu','Chiamaka Obi','Referral reward pending conversion')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.customer_health_scores (id,customer_id,title,status,score,health_label,summary) VALUES
 ('e2200008-0000-4000-8000-000000000001','e2200001-0000-4000-8000-000000000001','Adaeze health','healthy',88,'healthy','Strong payments + portal use'),
 ('e2200008-0000-4000-8000-000000000002','e2200001-0000-4000-8000-000000000002','Tunde health','needs_attention',54,'needs_attention','Low engagement · watch churn')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.customer_success_plans (id,code,title,status,customer_id,csm_label,summary) VALUES
 ('e2200009-0000-4000-8000-000000000001','CSP-ADA','Adaeze onboarding plan','active','e2200001-0000-4000-8000-000000000001','Ngozi CSM','Handover + orientation')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.customer_success_tasks (id,plan_id,title,status,owner_label,due_at,summary) VALUES
 ('e2200009-0000-4000-8000-000000000002','e2200009-0000-4000-8000-000000000001','Schedule orientation call','open','Ngozi CSM',now()+interval '2 days','Owner journey')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.customer_segments (id,code,title,segment_type,member_count,status,summary,criteria) VALUES
 ('e220000a-0000-4000-8000-000000000001','SEG-HV','High-value buyers','dynamic',42,'active','CLV and Gold+','{"min_clv":10000000,"tier":["Gold","Platinum","Diamond"]}'::jsonb),
 ('e220000a-0000-4000-8000-000000000002','SEG-RISK','At-risk customers','dynamic',11,'active','Health needs attention','{"health":["needs_attention","at_risk"]}'::jsonb)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.customer_surveys (id,code,title,survey_type,status,summary) VALUES
 ('e220000b-0000-4000-8000-000000000001','SRV-CSAT-Q3','Q3 CSAT pulse','csat','active','Post-handover satisfaction'),
 ('e220000b-0000-4000-8000-000000000002','SRV-NPS-Q3','Q3 NPS','nps','active','Promoter tracking')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.survey_responses (id,survey_id,title,score,respondent_label,status,summary) VALUES
 ('e220000b-0000-4000-8000-000000000003','e220000b-0000-4000-8000-000000000001','Adaeze CSAT',5,'Adaeze Nwosu','submitted','Excellent'),
 ('e220000b-0000-4000-8000-000000000004','e220000b-0000-4000-8000-000000000002','Adaeze NPS',9,'Adaeze Nwosu','submitted','Promoter')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.customer_feedback (id,title,category,status,channel,customer_name,rating,comment,sentiment,cx_surface,summary)
SELECT gen_random_uuid(), 'Portal handover experience','feedback','recorded','portal','Adaeze Nwosu',5,'Smooth documentation support','positive','cx','CX command-center seed'
WHERE NOT EXISTS (
 SELECT 1 FROM public.customer_feedback WHERE cx_surface = 'cx' AND customer_name = 'Adaeze Nwosu'
);

INSERT INTO public.customer_reviews (id,code,title,rating,author_label,body,status,summary) VALUES
 ('e220000c-0000-4000-8000-000000000001','REV-2026-09','Excellent sales consultation',5,'Adaeze Nwosu','Clear guidance from reservation to payment.','published','Public review')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.customer_sentiment (id,customer_id,title,sentiment_label,score,status,summary) VALUES
 ('e220000c-0000-4000-8000-000000000002','e2200001-0000-4000-8000-000000000001','Adaeze sentiment','positive',0.86,'analyzed','Strong promoter signals')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.journey_analytics (id,code,title,metric_key,status,value,unit,summary) VALUES
 ('e220000d-0000-4000-8000-000000000001','JA-CONV','Lead to reservation conversion','lead_to_reservation_pct','ok',24,'pct','Last 30 days'),
 ('e220000d-0000-4000-8000-000000000002','JA-NPS','Net Promoter Score','nps','ok',62,'score','Quarter to date'),
 ('e220000d-0000-4000-8000-000000000003','JA-RET','Customer retention','retention_pct','ok',91,'pct','Trailing 12 months')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.cx_ai_insights (id,code,title,body,insight_type,confidence_pct) VALUES
 ('e220000e-0000-4000-8000-000000000001','AI-CX-01','Prioritize outreach for Tunde Bakare','Health score 54 with low engagement — schedule CSM check-in before churn risk rises.','churn',90),
 ('e220000e-0000-4000-8000-000000000002','AI-CX-02','Promote Gold referral reward to Adaeze','Active Gold member with open referral — nudge exclusive site-tour redemption.','loyalty',87)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.cx_activity_logs (id,action,title,category,actor_label,entity_type,severity,status,summary) VALUES
 ('e220000f-0000-4000-8000-000000000001','journey.progressed','Lead nurture advanced','journey','Marketing','journey_executions','info','recorded','Property recommendations step'),
 ('e220000f-0000-4000-8000-000000000002','loyalty.points_posted','Reservation bonus posted','loyalty','Loyalty Engine','loyalty_points','info','recorded','+2500 points')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.kpi_snapshots (id,metric_key,label,value,previous_value,unit,change_pct,series,period,metadata) VALUES
 ('e220000f-0000-4000-8000-000000000003','cx_nps','NPS',62,58,'score',6.9,'[48,50,52,55,58,60,62]'::jsonb,'daily','{"module":"cx"}'),
 ('e220000f-0000-4000-8000-000000000004','cx_csat','CSAT',4.6,4.4,'score',4.5,'[4.1,4.2,4.3,4.3,4.4,4.5,4.6]'::jsonb,'daily','{"module":"cx"}'),
 ('e220000f-0000-4000-8000-000000000005','cx_retention','Retention',91,89,'pct',2.2,'[84,85,86,87,88,90,91]'::jsonb,'daily','{"module":"cx"}')
ON CONFLICT (id) DO NOTHING;

COMMIT;
