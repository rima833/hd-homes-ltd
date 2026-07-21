-- ---------------------------------------------------------------------------
-- Seeds (hex UUIDs only)
-- ---------------------------------------------------------------------------
INSERT INTO public.cms_templates (id, name, slug, description, layout_json) VALUES
  ('d4800000-0000-4000-8000-000000000001', 'Hero + CTA', 'hero-cta', 'Full-bleed hero with primary CTA',
   '{"regions":["hero","cta","footer"]}'::jsonb),
  ('d4800000-0000-4000-8000-000000000002', 'Property Showcase', 'property-showcase', 'Grid of featured units',
   '{"regions":["hero","gallery","specs","cta"]}'::jsonb)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.media_folders (id, name, slug, description) VALUES
  ('d4800000-0000-4000-8000-000000000010', 'Campaign Assets', 'campaign-assets', 'Shared creative for omnichannel campaigns')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.blog_authors (id, display_name, slug, bio) VALUES
  ('d4800000-0000-4000-8000-000000000020', 'HD Homes Editorial', 'hd-homes-editorial',
   'Official editorial voice for HD Homes Ltd.')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.blog_tags (id, name, slug) VALUES
  ('d4800000-0000-4000-8000-000000000021', 'Lekki Living', 'lekki-living'),
  ('d4800000-0000-4000-8000-000000000022', 'Investment Tips', 'investment-tips')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.landing_pages (
  id, title, slug, headline, subheadline, cta_label, cta_url, template_id,
  status, is_published, published_at, conversion_goal, seo_score, content
) VALUES
  (
    'd4800000-0000-4000-8000-000000000030',
    'Lekki Waterfront Launch',
    'lekki-waterfront-launch',
    'Own waterfront living in Lekki',
    'Limited villa allotments with smart financing.',
    'Book inspection',
    '/contact',
    'd4800000-0000-4000-8000-000000000001',
    'published',
    true,
    now() - interval '3 days',
    'inspection_booking',
    86.0,
    '{"sections":["hero","amenities","cta"]}'::jsonb
  ),
  (
    'd4800000-0000-4000-8000-000000000031',
    'Investor Open Day',
    'investor-open-day',
    'Investor Open Day — Ajah corridor',
    'Private briefing for qualified partners.',
    'Reserve seat',
    '/investment',
    'd4800000-0000-4000-8000-000000000001',
    'draft',
    false,
    NULL,
    'rsvp',
    62.0,
    '{"sections":["hero","agenda","form"]}'::jsonb
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.landing_page_versions (
  id, landing_page_id, version_number, title, content, change_summary
) VALUES
  (
    'd4800000-0000-4000-8000-000000000032',
    'd4800000-0000-4000-8000-000000000030',
    1,
    'Lekki Waterfront Launch',
    '{"headline":"Own waterfront living in Lekki"}'::jsonb,
    'Initial published cut'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.cms_sections (
  id, landing_page_id, section_key, section_type, title, content, sort_order
) VALUES
  (
    'd4800000-0000-4000-8000-000000000033',
    'd4800000-0000-4000-8000-000000000030',
    'hero',
    'hero',
    'Hero',
    '{"eyebrow":"New release","body":"Waterfront villas"}'::jsonb,
    0
  )
ON CONFLICT (id) DO NOTHING;

-- Draft blog seed (insert if slug free)
INSERT INTO public.blogs (
  id, title, slug, excerpt, content, is_published, status, featured,
  reading_time_minutes, seo_score, blog_author_id, metadata
) VALUES
  (
    'd4800000-0000-4000-8000-000000000040',
    'Why Lekki still leads coastal demand',
    'why-lekki-still-leads-coastal-demand',
    'A market note for buyers evaluating waterfront inventory.',
    '{"blocks":[{"type":"paragraph","text":"Draft — AI-assisted outline for editorial review."}]}'::jsonb,
    false,
    'draft',
    false,
    6,
    58.0,
    'd4800000-0000-4000-8000-000000000020',
    '{"ai_generated":true,"editable":true,"label":"AI-generated — editable"}'::jsonb
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.blog_tag_links (blog_id, tag_id) VALUES
  ('d4800000-0000-4000-8000-000000000040', 'd4800000-0000-4000-8000-000000000021')
ON CONFLICT DO NOTHING;

INSERT INTO public.audience_segments (id, name, slug, description, estimated_size, rules) VALUES
  (
    'd4800000-0000-4000-8000-000000000050',
    'Warm inspection leads',
    'warm-inspection-leads',
    'Leads who requested property inspection in last 30 days',
    420,
    '{"source":"forms","window_days":30}'::jsonb
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.campaigns (
  id, name, channel, content, starts_at, ends_at, status,
  campaign_code, objective, budget_amount, primary_channel, conversion_goal,
  audience_segment_id, metrics, metadata
) VALUES
  (
    'd4800000-0000-4000-8000-000000000060',
    'Q3 Waterfront Awareness',
    'omni',
    '{"theme":"lekki-waterfront"}'::jsonb,
    now() - interval '7 days',
    now() + interval '45 days',
    'active',
    'CAMP-Q3-WF',
    'awareness',
    8500000,
    'email',
    'inspection_booking',
    'd4800000-0000-4000-8000-000000000050',
    '{"impressions":128400,"clicks":4120,"conversions":186}'::jsonb,
    '{}'::jsonb
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.campaign_audiences (id, campaign_id, segment_id, channel, member_count) VALUES
  (
    'd4800000-0000-4000-8000-000000000061',
    'd4800000-0000-4000-8000-000000000060',
    'd4800000-0000-4000-8000-000000000050',
    'email',
    420
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.email_templates (id, name, slug, subject, body_html) VALUES
  (
    'd4800000-0000-4000-8000-000000000070',
    'Inspection invite',
    'inspection-invite',
    'Your private Lekki waterfront tour',
    '<p>Join us for a guided inspection this weekend.</p>'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.email_campaigns (
  id, campaign_id, template_id, name, subject, status, open_rate, click_rate, sent_at
) VALUES
  (
    'd4800000-0000-4000-8000-000000000071',
    'd4800000-0000-4000-8000-000000000060',
    'd4800000-0000-4000-8000-000000000070',
    'Waterfront email wave 1',
    'Your private Lekki waterfront tour',
    'sent',
    38.5,
    6.2,
    now() - interval '2 days'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.sms_campaigns (
  id, campaign_id, name, message_body, status, delivery_rate, sent_at
) VALUES
  (
    'd4800000-0000-4000-8000-000000000072',
    'd4800000-0000-4000-8000-000000000060',
    'SMS reminder — weekend tour',
    'HD Homes: Reminder — Lekki waterfront inspection this Saturday 11am. Reply YES to confirm.',
    'sent',
    94.0,
    now() - interval '1 day'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.whatsapp_campaigns (
  id, campaign_id, name, template_name, message_body, status, read_rate, sent_at
) VALUES
  (
    'd4800000-0000-4000-8000-000000000073',
    'd4800000-0000-4000-8000-000000000060',
    'WhatsApp nurture — brochure',
    'brochure_share_v1',
    'Here is the Lekki waterfront brochure and financing flyer.',
    'scheduled',
    0,
    NULL
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.forms (id, name, slug, description, fields, success_message, submission_count) VALUES
  (
    'd4800000-0000-4000-8000-000000000080',
    'Inspection request',
    'inspection-request',
    'Capture name, phone, preferred unit type',
    '[{"name":"full_name","type":"text","required":true},{"name":"phone","type":"tel","required":true},{"name":"unit_interest","type":"select"}]'::jsonb,
    'Thanks — our sales team will confirm your slot.',
    2
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.form_submissions (id, form_id, payload, email, phone, source_path, status, submitted_at) VALUES
  (
    'd4800000-0000-4000-8000-000000000081',
    'd4800000-0000-4000-8000-000000000080',
    '{"full_name":"Tunde Adebayo","unit_interest":"3-bed"}'::jsonb,
    'tunde@example.com',
    '+2348011110001',
    '/landing/lekki-waterfront-launch',
    'new',
    now() - interval '6 hours'
  ),
  (
    'd4800000-0000-4000-8000-000000000082',
    'd4800000-0000-4000-8000-000000000080',
    '{"full_name":"Ngozi Ike","unit_interest":"penthouse"}'::jsonb,
    'ngozi@example.com',
    '+2348022220002',
    '/landing/lekki-waterfront-launch',
    'contacted',
    now() - interval '1 day'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.seo_metadata (
  id, entity_type, entity_id, path, meta_title, meta_description, health_score, issue_count, issues, last_audit_at
) VALUES
  (
    'd4800000-0000-4000-8000-000000000090',
    'landing_page',
    'd4800000-0000-4000-8000-000000000030',
    '/landing/lekki-waterfront-launch',
    'Lekki Waterfront Homes | HD Homes',
    'Explore limited waterfront villas with smart financing from HD Homes.',
    86.0,
    1,
    '[{"code":"og_image_missing","severity":"info"}]'::jsonb,
    now() - interval '12 hours'
  ),
  (
    'd4800000-0000-4000-8000-000000000091',
    'blog',
    'd4800000-0000-4000-8000-000000000040',
    '/blog/why-lekki-still-leads-coastal-demand',
    'Why Lekki still leads coastal demand',
    'Draft SEO stub — expand meta description before publish.',
    58.0,
    2,
    '[{"code":"meta_short","severity":"warning"},{"code":"draft_noindex","severity":"info"}]'::jsonb,
    now() - interval '2 hours'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.redirects (id, from_path, to_path, status_code, notes) VALUES
  (
    'd4800000-0000-4000-8000-0000000000a0',
    '/old-lekki-launch',
    '/landing/lekki-waterfront-launch',
    301,
    'Legacy campaign URL'
  ),
  (
    'd4800000-0000-4000-8000-0000000000a1',
    '/promo/q2',
    '/landing/investor-open-day',
    302,
    'Temporary Q2 promo hop'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ab_tests (
  id, name, slug, hypothesis, entity_type, entity_id,
  variant_a, variant_b, status, traffic_split, primary_metric, metadata
) VALUES
  (
    'd4800000-0000-4000-8000-0000000000b0',
    'CTA copy — Book vs Reserve',
    'cta-book-vs-reserve',
    '“Book inspection” will convert higher than “Reserve a tour” on waterfront LP.',
    'landing_page',
    'd4800000-0000-4000-8000-000000000030',
    '{"cta":"Book inspection"}'::jsonb,
    '{"cta":"Reserve a tour"}'::jsonb,
    'running',
    50,
    'conversion_rate',
    '{"ai_generated":false}'::jsonb
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.content_calendar (
  id, title, channel, content_type, scheduled_for, status, owner_label, related_entity_type, related_entity_id, notes
) VALUES
  (
    'd4800000-0000-4000-8000-0000000000c0',
    'Publish Lekki coastal demand draft',
    'blog',
    'post',
    now() + interval '3 days',
    'planned',
    'Editorial',
    'blog',
    'd4800000-0000-4000-8000-000000000040',
    'Human edit required — AI outline present'
  ),
  (
    'd4800000-0000-4000-8000-0000000000c1',
    'WhatsApp brochure nurture send',
    'whatsapp',
    'campaign',
    now() + interval '1 day',
    'scheduled',
    'Marketing Ops',
    'whatsapp_campaign',
    'd4800000-0000-4000-8000-000000000073',
    NULL
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.dxp_personalization_rules (
  id, name, slug, target_entity_type, target_entity_id, conditions, actions, priority
) VALUES
  (
    'd4800000-0000-4000-8000-0000000000d0',
    'Investor-intent hero swap',
    'investor-intent-hero',
    'landing_page',
    'd4800000-0000-4000-8000-000000000031',
    '{"utm_campaign":"investor"}'::jsonb,
    '{"hero_variant":"investor_open_day"}'::jsonb,
    10
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.marketing_analytics (
  id, metric_key, metric_label, metric_value, unit, period_start, period_end, dimensions
) VALUES
  ('d4800000-0000-4000-8000-0000000000e0', 'sessions', 'Sessions', 28420, 'count', CURRENT_DATE - 30, CURRENT_DATE, '{"channel":"organic"}'::jsonb),
  ('d4800000-0000-4000-8000-0000000000e1', 'leads', 'Form leads', 186, 'count', CURRENT_DATE - 30, CURRENT_DATE, '{"source":"landing"}'::jsonb),
  ('d4800000-0000-4000-8000-0000000000e2', 'conversion_rate', 'Conversion rate', 3.4, 'percent', CURRENT_DATE - 30, CURRENT_DATE, '{}'::jsonb),
  ('d4800000-0000-4000-8000-0000000000e3', 'funnel_awareness', 'Funnel — Awareness', 128400, 'count', CURRENT_DATE - 30, CURRENT_DATE, '{"stage":"awareness"}'::jsonb),
  ('d4800000-0000-4000-8000-0000000000e4', 'funnel_consideration', 'Funnel — Consideration', 4120, 'count', CURRENT_DATE - 30, CURRENT_DATE, '{"stage":"consideration"}'::jsonb),
  ('d4800000-0000-4000-8000-0000000000e5', 'funnel_conversion', 'Funnel — Conversion', 186, 'count', CURRENT_DATE - 30, CURRENT_DATE, '{"stage":"conversion"}'::jsonb)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.marketing_activity_logs (id, action, summary, actor_label, entity_type, entity_id, occurred_at) VALUES
  (
    'd4800000-0000-4000-8000-0000000000f0',
    'landing.published',
    'Published Lekki Waterfront Launch landing page',
    'Marketing Ops',
    'landing_page',
    'd4800000-0000-4000-8000-000000000030',
    now() - interval '3 days'
  ),
  (
    'd4800000-0000-4000-8000-0000000000f1',
    'campaign.email.sent',
    'Sent Waterfront email wave 1',
    'System',
    'email_campaign',
    'd4800000-0000-4000-8000-000000000071',
    now() - interval '2 days'
  ),
  (
    'd4800000-0000-4000-8000-0000000000f2',
    'form.submission',
    'New inspection request from Tunde Adebayo',
    'Public web',
    'form_submission',
    'd4800000-0000-4000-8000-000000000081',
    now() - interval '6 hours'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.marketing_notifications (id, title, body, severity, category) VALUES
  (
    'd4800000-0000-4000-8000-0000000000f8',
    'SEO watch — draft blog',
    'Draft blog meta score is 58 — expand description before publish.',
    'warning',
    'seo'
  ),
  (
    'd4800000-0000-4000-8000-0000000000f9',
    'Form spike',
    'Two inspection submissions in the last day on waterfront LP.',
    'info',
    'forms'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.social_accounts (id, platform, handle, display_name, is_connected) VALUES
  ('d4800000-0000-4000-8000-000000000100', 'instagram', '@hdhomesng', 'HD Homes Nigeria', true)
ON CONFLICT (id) DO NOTHING;

