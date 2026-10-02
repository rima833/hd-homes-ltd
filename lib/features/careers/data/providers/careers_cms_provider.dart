import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/careers/data/models/careers_hub_content.dart';
import 'package:hdhomesproject/features/cms/domain/data/hub_page_cms.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final careersRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = Supabase.instance.client;
  final channel = client.channel('public:careers-cms')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'careers_settings',
      callback: (_) => _invalidateCareers(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'career_jobs',
      callback: (_) => _invalidateCareers(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'career_benefits',
      callback: (_) => _invalidateCareers(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'career_stats',
      callback: (_) => _invalidateCareers(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'career_tags',
      callback: (_) => _invalidateCareers(ref),
    )
    ..subscribe();
  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

void _invalidateCareers(Ref ref) {
  ref.invalidate(cmsCareersSettingsProvider);
  ref.invalidate(cmsCareerJobsProvider);
  ref.invalidate(cmsCareerBenefitsProvider);
  ref.invalidate(cmsCareerStatsProvider);
  ref.invalidate(cmsCareerTagsProvider);
  ref.invalidate(publishedCareersSettingsProvider);
  ref.invalidate(publishedCareerJobsProvider);
  ref.invalidate(publishedCareerBenefitsProvider);
  ref.invalidate(publishedCareerStatsProvider);
  ref.invalidate(publishedCareerTagsProvider);
}

final cmsCareersSettingsProvider = FutureProvider<CmsCareersSettings?>((
  ref,
) async {
  if (!ref.watch(supabaseConfiguredProvider)) return null;
  return ref.watch(cmsServiceProvider).getCareersSettings();
});

final cmsCareerJobsProvider = FutureProvider<List<CmsCareerJob>>((ref) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listCareerJobs();
});

final cmsCareerBenefitsProvider = FutureProvider<List<CmsCareerBenefit>>((
  ref,
) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listCareerBenefits();
});

final cmsCareerStatsProvider = FutureProvider<List<CmsCareerStat>>((ref) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listCareerStats();
});

final cmsCareerTagsProvider = FutureProvider<List<CmsCareerTag>>((ref) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listCareerTags();
});

final publishedCareersSettingsProvider = FutureProvider<CmsCareersSettings?>((
  ref,
) async {
  if (!ref.watch(supabaseConfiguredProvider)) return null;
  return ref.watch(cmsServiceProvider).getCareersSettings();
});

final publishedCareerJobsProvider = FutureProvider<List<CmsCareerJob>>((
  ref,
) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listPublishedCareerJobs();
});

final publishedCareerBenefitsProvider = FutureProvider<List<CmsCareerBenefit>>((
  ref,
) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listPublishedCareerBenefits();
});

final publishedCareerStatsProvider = FutureProvider<List<CmsCareerStat>>((
  ref,
) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listPublishedCareerStats();
});

final publishedCareerTagsProvider = FutureProvider<List<CmsCareerTag>>((
  ref,
) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listPublishedCareerTags();
});

final careersHubCmsProvider = Provider<CareersHubCms>((ref) {
  ref.watch(careersRealtimeProvider);
  final base = _fallback;

  if (!ref.watch(supabaseConfiguredProvider)) return base;

  final settings = ref.watch(publishedCareersSettingsProvider).valueOrNull;
  final jobs = ref.watch(publishedCareerJobsProvider).valueOrNull;
  final benefits = ref.watch(publishedCareerBenefitsProvider).valueOrNull;
  final stats = ref.watch(publishedCareerStatsProvider).valueOrNull;
  final tags = ref.watch(publishedCareerTagsProvider).valueOrNull;

  final whyWork =
      tags?.where((t) => t.kind == 'why_work').map((t) => t.label).toList() ??
      base.whyWorkWithUs;
  final pills =
      tags
          ?.where((t) => t.kind == 'benefit_pill')
          .map((t) => t.label)
          .toList() ??
      base.benefitPills;

  final mappedJobs = (jobs == null || jobs.isEmpty)
      ? const <CareerJob>[]
      : [
          for (final j in jobs)
            CareerJob(
              id: j.id,
              title: j.title,
              department: j.department,
              location: j.location,
              employmentType: j.employmentType,
              summary: j.summary,
              description: j.description,
              iconName: j.iconName,
              applyUrl: j.applyUrl,
              featured: j.isFeatured,
            ),
        ];

  final openCount = settings?.openPositionsOverride ?? mappedJobs.length;

  final pageOverlay = hubHeroFromPage(
    ref.watch(publishedPageBySlugProvider('careers')).valueOrNull,
  );

  return CareersHubCms(
    heroOverline: settings?.heroOverline ?? base.heroOverline,
    heroTitleLine1:
        settings?.heroTitleLine1 ?? pageOverlay.headline ?? base.heroTitleLine1,
    heroTitleLine2: settings?.heroTitleLine2 ?? base.heroTitleLine2,
    heroBody: (settings?.heroBody.trim().isNotEmpty ?? false)
        ? settings!.heroBody
        : (pageOverlay.subheadline ?? base.heroBody),
    heroImageUrl: () {
      final fromSettings = settings?.heroImageUrl?.trim();
      if (fromSettings != null && fromSettings.isNotEmpty) return fromSettings;
      final fromPage = pageOverlay.backgroundImageUrl?.trim();
      if (fromPage != null && fromPage.isNotEmpty) return fromPage;
      return base.heroImageUrl;
    }(),
    cultureSummary: (settings?.cultureSummary.trim().isNotEmpty ?? false)
        ? settings!.cultureSummary
        : base.cultureSummary,
    aboutSubtitle: settings?.aboutSubtitle ?? base.aboutSubtitle,
    stats: (stats == null || stats.isEmpty)
        ? const <CareerStatItem>[]
        : [
            for (final s in stats)
              CareerStatItem(
                value: s.value,
                label: s.label,
                iconName: s.iconName,
              ),
          ],
    benefits: (benefits == null || benefits.isEmpty)
        ? const <CareerBenefitCard>[]
        : [
            for (final b in benefits)
              CareerBenefitCard(
                title: b.title,
                description: b.description,
                iconName: b.iconName,
              ),
          ],
    jobs: mappedJobs,
    whyWorkWithUs: whyWork.isEmpty ? base.whyWorkWithUs : whyWork,
    benefitPills: pills.isEmpty ? base.benefitPills : pills,
    openPositionsCount: openCount,
    ctaPrimaryLabel: settings?.ctaPrimaryLabel ?? base.ctaPrimaryLabel,
    ctaSecondaryLabel: settings?.ctaSecondaryLabel ?? base.ctaSecondaryLabel,
    cvBannerText: settings?.cvBannerText ?? base.cvBannerText,
    cvBannerCtaLabel: settings?.cvBannerCtaLabel ?? base.cvBannerCtaLabel,
    cvEmail: settings?.cvEmail ?? base.cvEmail,
    seoTitle: settings?.seoTitle ?? base.seoTitle,
    seoDescription: settings?.seoDescription ?? base.seoDescription,
  );
});

const _fallback = CareersHubCms(
  heroOverline: 'CAREERS',
  heroTitleLine1: 'Build the Future',
  heroTitleLine2: 'With Us',
  heroImageUrl: '',
  heroBody:
      "Join the team shaping Nigeria's next generation of premium communities. We foster innovation, collaboration, and excellence — building careers alongside communities.",
  cultureSummary:
      'We foster innovation, collaboration, and excellence — building careers alongside communities.',
  aboutSubtitle: 'Build your career while building communities.',
  openPositionsCount: 8,
  ctaPrimaryLabel: 'View All Careers',
  ctaSecondaryLabel: 'Submit Your CV',
  cvBannerText:
      "Don't see the right role? Send us your CV and we'll keep you in mind for future opportunities.",
  cvBannerCtaLabel: 'Send Your CV',
  cvEmail: 'careers@hdhomes.ng',
  stats: [
    CareerStatItem(value: '8', label: 'Open Positions', iconName: 'briefcase'),
    CareerStatItem(value: '120+', label: 'Employees', iconName: 'users'),
    CareerStatItem(value: '15+', label: 'Benefits', iconName: 'award'),
    CareerStatItem(value: '4', label: 'Locations', iconName: 'mapPin'),
  ],
  benefits: [
    CareerBenefitCard(
      title: 'Growth & Learning',
      description:
          'Clear career pathways with continuous skill development across every team.',
      iconName: 'trendingUp',
    ),
    CareerBenefitCard(
      title: 'Training & Mentorship',
      description:
          'Structured mentorship and certifications that accelerate professional growth.',
      iconName: 'graduationCap',
    ),
    CareerBenefitCard(
      title: 'Health & Wellness',
      description:
          'Comprehensive medical cover and wellbeing support for you and your family.',
      iconName: 'heart',
    ),
    CareerBenefitCard(
      title: 'Flexible Work',
      description:
          'Hybrid options for eligible roles with trust-based delivery culture.',
      iconName: 'home',
    ),
    CareerBenefitCard(
      title: 'Competitive Rewards',
      description:
          'Market-aligned compensation, bonuses, and preferential housing access.',
      iconName: 'wallet',
    ),
    CareerBenefitCard(
      title: 'Recognition & Impact',
      description:
          'Celebrate excellence while shaping communities across Nigeria.',
      iconName: 'award',
    ),
  ],
  jobs: [
    CareerJob(
      id: 'job-civil',
      title: 'Civil Engineer',
      department: 'Construction',
      location: 'Abuja, Nigeria',
      employmentType: 'Full Time',
      summary:
          'Lead structural and site engineering excellence across flagship residential estates.',
      iconName: 'hardHat',
      featured: true,
    ),
    CareerJob(
      id: 'job-sales',
      title: 'Sales Executive',
      department: 'Sales',
      location: 'Lagos, Nigeria',
      employmentType: 'Full Time',
      summary:
          'Drive property sales across premium corridors with CRM-backed lead pipelines.',
      iconName: 'briefcase',
      featured: true,
    ),
    CareerJob(
      id: 'job-arch',
      title: 'Architect',
      department: 'Design',
      location: 'Lagos, Nigeria',
      employmentType: 'Full Time',
      summary:
          'Design distinctive residential and mixed-use concepts for HD Homes communities.',
      iconName: 'penTool',
      featured: true,
    ),
  ],
  whyWorkWithUs: [
    'Growth-oriented culture',
    'Competitive compensation',
    'Professional development',
    'Impact-driven work',
  ],
  benefitPills: [
    'Health Insurance',
    'Performance bonuses',
    'Training programs',
    'Flexible arrangements',
  ],
);
