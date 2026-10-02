-- Blog hub: staff write alignment, realtime, categories, published posts, pages seed.

DROP POLICY IF EXISTS blogs_staff ON public.blogs;
CREATE POLICY blogs_staff ON public.blogs FOR ALL
  USING (
    public.has_permission('marketing.cms'::text, auth.uid())
    OR public.has_permission('manage_blog'::text, auth.uid())
    OR public.has_role('super_admin'::text, auth.uid())
  )
  WITH CHECK (
    public.has_permission('marketing.cms'::text, auth.uid())
    OR public.has_permission('manage_blog'::text, auth.uid())
    OR public.has_role('super_admin'::text, auth.uid())
  );

DROP POLICY IF EXISTS blog_categories_staff ON public.blog_categories;
CREATE POLICY blog_categories_staff ON public.blog_categories FOR ALL
  USING (
    public.has_permission('marketing.cms'::text, auth.uid())
    OR public.has_permission('manage_blog'::text, auth.uid())
    OR public.has_role('super_admin'::text, auth.uid())
  )
  WITH CHECK (
    public.has_permission('marketing.cms'::text, auth.uid())
    OR public.has_permission('manage_blog'::text, auth.uid())
    OR public.has_role('super_admin'::text, auth.uid())
  );

DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.blog_categories;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.blog_authors;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.blogs;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
END $$;

INSERT INTO public.blog_categories (id, name, slug, status, is_deleted, updated_at)
VALUES
  ('a1000000-0000-4000-8000-000000000001', 'Buying Guides', 'buying-guides', 'active', false, now()),
  ('a1000000-0000-4000-8000-000000000002', 'Investment Strategies', 'investment', 'active', false, now()),
  ('a1000000-0000-4000-8000-000000000003', 'Building Process', 'construction', 'active', false, now()),
  ('a1000000-0000-4000-8000-000000000004', 'Land Documentation', 'legal', 'active', false, now()),
  ('a1000000-0000-4000-8000-000000000005', 'Mortgages & Finance', 'finance', 'active', false, now()),
  ('a1000000-0000-4000-8000-000000000006', 'Smart Homes & Design', 'lifestyle', 'active', false, now()),
  ('a1000000-0000-4000-8000-000000000007', 'Company News', 'company-news', 'active', false, now()),
  ('a1000000-0000-4000-8000-000000000008', 'Estate Launches', 'estate-launches', 'active', false, now())
ON CONFLICT (slug) DO UPDATE
SET name = EXCLUDED.name,
    status = 'active',
    is_deleted = false,
    updated_at = now();

INSERT INTO public.pages (
  title, slug, content, meta_title, meta_description,
  is_published, published_at, status, is_deleted, updated_at
) VALUES (
  'Blog',
  'blog',
  jsonb_build_object(
    'heroHeadline', 'Insights That Build Better Decisions.',
    'heroSubheadline', 'Guides, market notes, and company news from the HD Homes team.',
    'primaryCtaLabel', 'Browse Articles',
    'secondaryCtaLabel', 'Talk to an Advisor',
    'backgroundImageUrl', 'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?auto=format&fit=crop&w=1920&q=80'
  ),
  'Blog | HD Homes',
  'HD Homes knowledge hub — buying guides, investment insights, and company news.',
  true,
  now(),
  'active',
  false,
  now()
)
ON CONFLICT (slug) DO UPDATE
SET title = EXCLUDED.title,
    content = EXCLUDED.content,
    meta_title = EXCLUDED.meta_title,
    meta_description = EXCLUDED.meta_description,
    is_published = true,
    status = 'active',
    is_deleted = false,
    updated_at = now();

-- Publish the existing draft and seed a working catalog.
UPDATE public.blogs
SET is_published = true,
    featured = true,
    status = 'published',
    published_at = COALESCE(published_at, now()),
    category_id = 'a1000000-0000-4000-8000-000000000002',
    blog_author_id = COALESCE(blog_author_id, 'd4800000-0000-4000-8000-000000000020'),
    cover_image_url = COALESCE(
      cover_image_url,
      'https://images.unsplash.com/photo-1560518883-ce09059eeffa?auto=format&fit=crop&w=1600&q=80'
    ),
    updated_at = now()
WHERE slug = 'why-lekki-still-leads-coastal-demand'
  AND COALESCE(is_deleted, false) = false;

INSERT INTO public.blogs (
  id, title, slug, excerpt, content, cover_image_url, category_id, blog_author_id,
  is_published, featured, published_at, reading_time_minutes, status, is_deleted, updated_at
) VALUES
(
  'b1000000-0000-4000-8000-000000000001',
  'The Complete First-Time Buyer''s Guide to Property in Nigeria (2026)',
  'first-time-buyers-guide-nigeria-2026',
  'Everything you need to know before purchasing your first home — from budgeting to handover.',
  jsonb_build_object('body', E'Buying your first home in Nigeria is a major decision. Start with a clear budget, verify title documents, and work with a licensed developer.\n\n## Budget and financing\nMap your deposit, monthly capacity, and extras such as legal fees and service charges before you inspect.\n\n## Due diligence\nAlways confirm survey, C of O or Governor''s Consent, and estate layout before any payment.\n\n## Closing\nHD Homes walks buyers through allocation, documentation, and handover so there are no surprises.'),
  'https://images.unsplash.com/photo-1560518883-ce09059eeffa?auto=format&fit=crop&w=1600&q=80',
  'a1000000-0000-4000-8000-000000000001',
  'd4800000-0000-4000-8000-000000000020',
  true, true, now() - interval '20 days', 12, 'published', false, now()
),
(
  'b1000000-0000-4000-8000-000000000002',
  'Lekki Property Market Report — Q1 2026',
  'lekki-property-market-report-q1-2026',
  'Price trends, demand index, and investment hotspots across the Lekki corridor.',
  jsonb_build_object('body', E'The Lekki corridor continues to attract owner-occupiers and investors. Demand remains strongest around completed estates with infrastructure already in place.\n\n## What moved this quarter\nWaterfront and gated inventory led enquiries. Off-plan interest stayed healthy where delivery timelines are transparent.\n\n## How to use this report\nCompare yield, exit liquidity, and construction progress — not just asking price — before you commit.'),
  'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=1600&q=80',
  'a1000000-0000-4000-8000-000000000002',
  'd4800000-0000-4000-8000-000000000020',
  true, true, now() - interval '12 days', 15, 'published', false, now()
),
(
  'b1000000-0000-4000-8000-000000000003',
  'Understanding Certificate of Occupancy in Lagos',
  'understanding-certificate-of-occupancy',
  'A plain-language guide to C of O, Governor''s Consent, and title verification.',
  jsonb_build_object('body', E'A Certificate of Occupancy confirms statutory rights over land. In Lagos, transfers on land that already has a C of O typically require Governor''s Consent.\n\n## Why it matters\nTitle defects are the most expensive surprises in Nigerian property. Verify documents with professionals before you pay.\n\n## Next steps\nAsk for survey, title chain, and estate allocation papers. HD Homes legal partners can review them with you.'),
  'https://images.unsplash.com/photo-1450101499163-c8848c66ca85?auto=format&fit=crop&w=1600&q=80',
  'a1000000-0000-4000-8000-000000000004',
  'd4800000-0000-4000-8000-000000000020',
  true, true, now() - interval '40 days', 10, 'published', false, now()
),
(
  'b1000000-0000-4000-8000-000000000004',
  'Horizon Gardens Estate Launch — What Buyers Need to Know',
  'horizon-gardens-estate-launch',
  'HD Homes unveils Phase 1 of its flagship Lekki lifestyle estate.',
  jsonb_build_object('body', E'Horizon Gardens Phase 1 opens with a mix of residential typologies, estate infrastructure, and a clear delivery programme.\n\n## Who it is for\nOwner-occupiers who want a managed community, and investors looking for transparent off-plan terms.\n\n## How to inspect\nBook an inspection from the Contact hub. Allocation follows documented payment schedules.'),
  'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?auto=format&fit=crop&w=1600&q=80',
  'a1000000-0000-4000-8000-000000000008',
  'd4800000-0000-4000-8000-000000000020',
  true, false, now() - interval '8 days', 6, 'published', false, now()
),
(
  'b1000000-0000-4000-8000-000000000005',
  'Mortgage vs Installment Plans: Which Is Right for You?',
  'mortgage-vs-installment-plans',
  'Compare bank mortgages with developer installment plans for Nigerian property buyers.',
  jsonb_build_object('body', E'Bank mortgages and developer installment plans solve different cash-flow problems.\n\n## Mortgages\nUseful when you want a longer tenor and already meet bank documentation requirements.\n\n## Developer plans\nOften simpler for off-plan purchases, with milestones tied to construction. Compare total cost, not just monthly figures.'),
  'https://images.unsplash.com/photo-1554224155-6726b3ff858f?auto=format&fit=crop&w=1600&q=80',
  'a1000000-0000-4000-8000-000000000005',
  'd4800000-0000-4000-8000-000000000020',
  true, false, now() - interval '55 days', 8, 'published', false, now()
),
(
  'b1000000-0000-4000-8000-000000000006',
  'Smart Home Features Worth Investing In',
  'smart-home-features-worth-investing',
  'From security to energy savings — the smart features that add real value.',
  jsonb_build_object('body', E'Not every gadget adds resale value. Prioritise security, metering, and energy efficiency.\n\n## High-value upgrades\nReliable CCTV, access control, inverter-ready wiring, and quality fittings outperform novelty gadgets.\n\n## HD Homes approach\nWe specify features that residents actually use and that estate management can maintain.'),
  'https://images.unsplash.com/photo-1558002038-1055907df827?auto=format&fit=crop&w=1600&q=80',
  'a1000000-0000-4000-8000-000000000006',
  'd4800000-0000-4000-8000-000000000020',
  true, false, now() - interval '48 days', 7, 'published', false, now()
),
(
  'b1000000-0000-4000-8000-000000000007',
  'Construction Timeline: What to Expect When Building with HD Homes',
  'construction-timeline-what-to-expect',
  'From foundation to handover — a transparent look at the build process.',
  jsonb_build_object('body', E'A clear construction programme protects both the client and the developer.\n\n## Typical stages\nSite mobilisation, foundation, structure, finishes, and handover inspections.\n\n## How we communicate\nClients receive progress updates and can book site inspections at agreed milestones.'),
  'https://images.unsplash.com/photo-1503387762-592deb58ef4e?auto=format&fit=crop&w=1600&q=80',
  'a1000000-0000-4000-8000-000000000003',
  'd4800000-0000-4000-8000-000000000020',
  true, false, now() - interval '70 days', 11, 'published', false, now()
),
(
  'b1000000-0000-4000-8000-000000000008',
  'HD Homes Wins Real Estate Excellence Award 2025',
  'hd-homes-wins-excellence-award-2025',
  'Recognized for transparency, quality delivery, and customer satisfaction.',
  jsonb_build_object('body', E'HD Homes was recognised for transparent sales, delivery quality, and client care.\n\nThe award reflects the same standards we apply on every estate: documented processes, verified titles, and after-sales support.'),
  'https://images.unsplash.com/photo-1567427017947-136e82cd2790?auto=format&fit=crop&w=1600&q=80',
  'a1000000-0000-4000-8000-000000000007',
  'd4800000-0000-4000-8000-000000000020',
  true, false, now() - interval '90 days', 4, 'published', false, now()
)
ON CONFLICT (slug) DO UPDATE
SET title = EXCLUDED.title,
    excerpt = EXCLUDED.excerpt,
    content = EXCLUDED.content,
    cover_image_url = EXCLUDED.cover_image_url,
    category_id = EXCLUDED.category_id,
    blog_author_id = EXCLUDED.blog_author_id,
    is_published = true,
    featured = EXCLUDED.featured,
    status = 'published',
    is_deleted = false,
    reading_time_minutes = EXCLUDED.reading_time_minutes,
    updated_at = now();
