import 'package:hdhomesproject/features/dxp/domain/entities/dxp_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads Marketing Command Center snapshot from Supabase (falls back to demo).
class DxpService {
  DxpService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<DxpCommandCenterSnapshot> loadCommandCenter() async {
    final demo = DxpDemo.snapshot();
    final client = _client;
    if (client == null) return demo;

    try {
      List<DxpLandingPage> landing = demo.landingPages;
      try {
        final rows = await client
            .from('landing_pages')
            .select()
            .order('updated_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          landing = rows
              .map(
                (e) => DxpLandingPage.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<DxpCmsPage> pages = demo.cmsPages;
      try {
        final rows = await client
            .from('pages')
            .select()
            .eq('is_deleted', false)
            .order('updated_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          pages = rows
              .map(
                (e) =>
                    DxpCmsPage.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<DxpBlogPost> blogs = demo.blogPosts;
      try {
        final rows = await client
            .from('blogs')
            .select()
            .eq('is_deleted', false)
            .order('updated_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          blogs = rows
              .map(
                (e) =>
                    DxpBlogPost.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<DxpCampaign> campaigns = demo.campaigns;
      try {
        final rows = await client
            .from('campaigns')
            .select()
            .eq('is_deleted', false)
            .order('updated_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          campaigns = rows
              .map(
                (e) =>
                    DxpCampaign.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<DxpFormSubmission> forms = demo.formSubmissions;
      try {
        final rows = await client
            .from('form_submissions')
            .select()
            .order('submitted_at', ascending: false)
            .limit(80);
        if (rows.isNotEmpty) {
          forms = rows
              .map(
                (e) => DxpFormSubmission.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<DxpSeoHealth> seo = demo.seoHealth;
      try {
        final rows = await client
            .from('seo_metadata')
            .select()
            .order('updated_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          seo = rows
              .map(
                (e) =>
                    DxpSeoHealth.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<DxpCalendarItem> calendar = demo.calendar;
      try {
        final rows = await client
            .from('content_calendar')
            .select()
            .order('scheduled_for', ascending: true)
            .limit(40);
        if (rows.isNotEmpty) {
          calendar = rows
              .map(
                (e) => DxpCalendarItem.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<DxpAbTest> abTests = demo.abTests;
      try {
        final rows = await client.from('ab_tests').select().limit(20);
        if (rows.isNotEmpty) {
          abTests = rows
              .map(
                (e) =>
                    DxpAbTest.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<DxpMediaAsset> media = demo.mediaAssets;
      try {
        final rows = await client.from('media_library').select().limit(40);
        if (rows.isNotEmpty) {
          media = rows
              .map(
                (e) => DxpMediaAsset.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {
        try {
          final rows = await client
              .from('media')
              .select()
              .eq('is_deleted', false)
              .limit(40);
          if (rows.isNotEmpty) {
            media = rows
                .map(
                  (e) => DxpMediaAsset.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ),
                )
                .toList();
          }
        } catch (_) {}
      }

      List<DxpActivity> activities = demo.activities;
      try {
        final rows = await client
            .from('marketing_activity_logs')
            .select()
            .order('occurred_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          activities = rows
              .map(
                (e) =>
                    DxpActivity.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<DxpAlert> alerts = demo.alerts;
      try {
        final rows = await client
            .from('marketing_notifications')
            .select()
            .order('created_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          alerts = rows
              .map(
                (e) => DxpAlert.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<DxpFunnelStage> funnel = demo.funnel;
      try {
        final rows = await client
            .from('marketing_analytics')
            .select()
            .like('metric_key', 'funnel_%')
            .limit(10);
        if (rows.isNotEmpty) {
          funnel = rows.map((raw) {
            final m = Map<String, dynamic>.from(raw as Map);
            final key = (m['metric_key'] as String? ?? '').replaceFirst(
              'funnel_',
              '',
            );
            return DxpFunnelStage(
              label: m['metric_label'] as String? ?? key,
              value: (m['metric_value'] as num?)?.toDouble() ?? 0,
              stageKey: key,
            );
          }).toList();
        }
      } catch (_) {}

      final hasAnyRemote = landing != demo.landingPages ||
          campaigns != demo.campaigns ||
          forms != demo.formSubmissions ||
          blogs != demo.blogPosts;

      if (!hasAnyRemote && landing.isEmpty) return demo;

      return DxpCommandCenterSnapshot(
        kpis: DxpDemo.aggregateKpis(
          campaigns: campaigns,
          landingPages: landing,
          blogPosts: blogs,
          formSubmissions: forms,
          seoHealth: seo,
          funnel: funnel,
        ),
        funnel: funnel,
        campaigns: campaigns,
        landingPages: landing,
        cmsPages: pages,
        blogPosts: blogs,
        mediaAssets: media,
        formSubmissions: forms,
        seoHealth: seo,
        calendar: calendar,
        abTests: abTests,
        activities: activities,
        alerts: alerts,
        aiInsights: demo.aiInsights,
        fromRemote: true,
        loadedAt: DateTime.now(),
      );
    } catch (_) {
      return demo;
    }
  }

  /// Stub AI content studio briefing.
  String generateContentBriefing(DxpCommandCenterSnapshot snap) {
    final drafts =
        snap.blogPosts.where((b) => b.status == BlogPostStatus.draft).length;
    final leads = snap.formSubmissions.length;
    final published =
        snap.landingPages.where((p) => p.isPublished).length;
    return 'AI content briefing: $published published landing page(s) · '
        '$drafts draft post(s) · $leads form lead(s) this window. '
        'Prioritize SEO edits on low-score drafts before next calendar send. '
        '(${snap.aiDisclaimer})';
  }

  /// Stub conversion intelligence — funnel + CTA experiment notes.
  static List<String> detectConversionSignals(DxpCommandCenterSnapshot snap) {
    final out = <String>[];
    if (snap.funnel.length >= 3) {
      final awareness = snap.funnel
          .firstWhere(
            (f) => f.stageKey == 'awareness',
            orElse: () => snap.funnel.first,
          )
          .value;
      final conversion = snap.funnel
          .firstWhere(
            (f) => f.stageKey == 'conversion',
            orElse: () => snap.funnel.last,
          )
          .value;
      if (awareness > 0) {
        final cvr = (conversion / awareness) * 100;
        out.add(
          'Conversion funnel CVR ${cvr.toStringAsFixed(2)}% '
          '(${formatDxpCount(awareness)} → ${formatDxpCount(conversion)})',
        );
      }
    }
    for (final test in snap.abTests) {
      if (test.status == 'running') {
        out.add('A/B running: ${test.name} (${test.primaryMetric})');
      }
    }
    for (final seo in snap.seoHealth) {
      if (seo.healthScore < 70) {
        out.add('SEO watch ${seo.path} score ${seo.healthScore.toStringAsFixed(0)}');
      }
    }
    if (out.isEmpty) {
      out.add('No material conversion signals in current demo snapshot.');
    }
    return out;
  }
}
