import 'package:hdhomesproject/core/media/media_delivery.dart';
import 'package:hdhomesproject/features/dxp/domain/entities/dxp_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads Marketing Command Center from Supabase.
/// When Supabase is configured: never inject demo/fake metrics — empty → 0.
class DxpService {
  DxpService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<DxpCommandCenterSnapshot> loadCommandCenter() async {
    final client = _client;
    if (client == null) {
      return DxpCommandCenterSnapshot.empty(fromRemote: false);
    }

    final warnings = <String>[];

    Future<T> guard<T>(
      String slice,
      Future<T> Function() load,
      T fallback,
    ) async {
      try {
        return await load();
      } catch (e) {
        warnings.add('$slice: $e');
        return fallback;
      }
    }

    final landing = await guard('landing_pages', () async {
      final rows = await client
          .from('landing_pages')
          .select()
          .order('updated_at', ascending: false)
          .limit(80);
      return rows
          .map(
            (e) => DxpLandingPage.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    }, const <DxpLandingPage>[]);

    final pages = await guard('pages', () async {
      final rows = await client
          .from('pages')
          .select()
          .eq('is_deleted', false)
          .order('updated_at', ascending: false)
          .limit(80);
      return rows
          .map((e) => DxpCmsPage.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }, const <DxpCmsPage>[]);

    final blogs = await guard('blogs', () async {
      final rows = await client
          .from('blogs')
          .select()
          .eq('is_deleted', false)
          .order('updated_at', ascending: false)
          .limit(80);
      return rows
          .map((e) => DxpBlogPost.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }, const <DxpBlogPost>[]);

    final campaigns = await guard('campaigns', () async {
      final rows = await client
          .from('campaigns')
          .select()
          .eq('is_deleted', false)
          .order('updated_at', ascending: false)
          .limit(80);
      return rows
          .map((e) => DxpCampaign.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }, const <DxpCampaign>[]);

    final forms = await guard('form_submissions', () async {
      final rows = await client
          .from('form_submissions')
          .select()
          .order('submitted_at', ascending: false)
          .limit(120);
      return rows
          .map(
            (e) =>
                DxpFormSubmission.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    }, const <DxpFormSubmission>[]);

    final seo = await guard('seo_metadata', () async {
      final rows = await client
          .from('seo_metadata')
          .select()
          .order('updated_at', ascending: false)
          .limit(80);
      return rows
          .map(
            (e) => DxpSeoHealth.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    }, const <DxpSeoHealth>[]);

    final calendar = await guard('content_calendar', () async {
      final rows = await client
          .from('content_calendar')
          .select()
          .order('scheduled_for', ascending: true)
          .limit(80);
      return rows
          .map(
            (e) =>
                DxpCalendarItem.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    }, const <DxpCalendarItem>[]);

    final media = await guard('media', () async {
      try {
        final rows = await client.from('media_library').select().limit(80);
        if (rows.isNotEmpty) {
          return rows
              .map(
                (e) =>
                    DxpMediaAsset.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}
      final rows = await client
          .from('media')
          .select()
          .eq('is_deleted', false)
          .limit(80);
      return rows
          .map(
            (e) => DxpMediaAsset.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    }, const <DxpMediaAsset>[]);

    final activities = await guard('marketing_activity_logs', () async {
      final rows = await client
          .from('marketing_activity_logs')
          .select()
          .order('occurred_at', ascending: false)
          .limit(60);
      return rows
          .map((e) => DxpActivity.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }, const <DxpActivity>[]);

    final crmStats = await guard(
      'crm_leads',
      () => _loadCrmLeadStats(client),
      const _CrmLeadStats(),
    );

    // Exclusive CRM stages. Each lead is counted once so the mix sums to the total.
    final funnel = [
      DxpFunnelStage(
        label: 'Open',
        value: crmStats.open.toDouble(),
        stageKey: 'open',
      ),
      DxpFunnelStage(
        label: 'Qualified',
        value: crmStats.qualified.toDouble(),
        stageKey: 'qualified',
      ),
      DxpFunnelStage(
        label: 'Won / clients',
        value: crmStats.won.toDouble(),
        stageKey: 'won',
      ),
      DxpFunnelStage(
        label: 'Lost',
        value: crmStats.lost.toDouble(),
        stageKey: 'lost',
      ),
    ];

    final now = DateTime.now();
    return DxpCommandCenterSnapshot(
      kpis: DxpKpiBuilder.build(
        campaigns: campaigns,
        formSubmissions: forms,
        seoHealth: seo,
        crmLeadCount: crmStats.total,
        crmQualifiedCount: crmStats.qualified,
        crmWonCount: crmStats.won,
        publishedContentCount:
            blogs.where((b) => b.isPublished).length +
            landing.where((p) => p.isPublished).length +
            pages.where((p) => p.isPublished).length,
        mediaCount: media.length,
        scheduledContentCount: calendar
            .where((item) => item.status == 'scheduled')
            .length,
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
      abTests: const [],
      activities: activities,
      alerts: const [],
      aiInsights: const [],
      fromRemote: true,
      loadedAt: now,
      loadWarnings: warnings,
      crmLeadCount: crmStats.total,
      crmQualifiedCount: crmStats.qualified,
      crmLeadCapturedAt: crmStats.capturedAt,
    );
  }

  /// Public published landing by slug (`/lp/:slug`). Returns null if missing.
  Future<DxpLandingPage?> getPublishedLandingBySlug(String slug) async {
    final client = _client;
    if (client == null) return null;
    final clean = slug.trim().toLowerCase();
    if (clean.isEmpty) return null;
    final row = await client
        .from('landing_pages')
        .select()
        .eq('slug', clean)
        .eq('is_published', true)
        .maybeSingle();
    if (row == null) return null;
    return DxpLandingPage.fromJson(Map<String, dynamic>.from(row));
  }

  Future<DxpLandingPage> upsertLandingPage({
    String? id,
    required String title,
    required String slug,
    String? headline,
    String? subheadline,
    String? heroImageUrl,
    String? ctaLabel,
    String? ctaUrl,
    String? conversionGoal,
    LandingPageStatus status = LandingPageStatus.draft,
    bool publish = false,
  }) async {
    final client = _requireClient();
    MediaDelivery.assertCloudinaryMediaUrl(
      heroImageUrl,
      field: 'Landing hero image',
    );
    final cleanSlug = _slugify(slug.isEmpty ? title : slug);
    final payload = <String, dynamic>{
      if (id != null) 'id': id,
      'title': title.trim(),
      'slug': cleanSlug,
      'headline': headline?.trim(),
      'subheadline': subheadline?.trim(),
      'hero_image_url': heroImageUrl?.trim(),
      'cta_label': ctaLabel?.trim(),
      'cta_url': ctaUrl?.trim(),
      'conversion_goal': conversionGoal?.trim(),
      'status': publish ? LandingPageStatus.published.slug : status.slug,
      'is_published': publish || status == LandingPageStatus.published,
      if (publish || status == LandingPageStatus.published)
        'published_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final row = await client
        .from('landing_pages')
        .upsert(payload)
        .select()
        .single();
    return DxpLandingPage.fromJson(Map<String, dynamic>.from(row));
  }

  Future<DxpLandingPage> setLandingPublished({
    required String id,
    required bool published,
  }) async {
    final client = _requireClient();
    final row = await client
        .from('landing_pages')
        .update({
          'is_published': published,
          'status': published
              ? LandingPageStatus.published.slug
              : LandingPageStatus.draft.slug,
          if (published)
            'published_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();
    final page = DxpLandingPage.fromJson(Map<String, dynamic>.from(row));
    await _logActivity(
      action: published ? 'publish' : 'unpublish',
      summary: published
          ? 'Published landing page ${page.title}'
          : 'Unpublished landing page ${page.title}',
      entityType: 'landing_page',
      entityId: id,
    );
    return page;
  }

  Future<DxpCmsPage> setPagePublished({
    required String id,
    required bool published,
  }) async {
    final client = _requireClient();
    final now = DateTime.now().toUtc().toIso8601String();
    final row = await client
        .from('pages')
        .update({
          'is_published': published,
          'published_at': published ? now : null,
          'updated_at': now,
        })
        .eq('id', id)
        .select()
        .single();
    final page = DxpCmsPage.fromJson(Map<String, dynamic>.from(row));
    await _logActivity(
      action: published ? 'publish' : 'unpublish',
      summary: published
          ? 'Published page ${page.title}'
          : 'Unpublished page ${page.title}',
      entityType: 'page',
      entityId: id,
    );
    return page;
  }

  Future<DxpBlogPost> setBlogPublished({
    required String id,
    required bool published,
  }) async {
    final client = _requireClient();
    final now = DateTime.now().toUtc().toIso8601String();
    final row = await client
        .from('blogs')
        .update({
          'is_published': published,
          'status': published ? 'published' : 'draft',
          'published_at': published ? now : null,
          'updated_at': now,
        })
        .eq('id', id)
        .select()
        .single();
    final post = DxpBlogPost.fromJson(Map<String, dynamic>.from(row));
    await _logActivity(
      action: published ? 'publish' : 'unpublish',
      summary: published
          ? 'Published blog ${post.title}'
          : 'Unpublished blog ${post.title}',
      entityType: 'blog',
      entityId: id,
    );
    return post;
  }

  Future<void> setMediaPublished({
    required String id,
    required bool published,
    String? title,
  }) async {
    final client = _requireClient();
    await client
        .from('media')
        .update({
          'is_published': published,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);
    final label = (title ?? '').trim().isEmpty ? 'media asset' : title!.trim();
    await _logActivity(
      action: published ? 'publish' : 'unpublish',
      summary: published ? 'Published $label' : 'Unpublished $label',
      entityType: 'media',
      entityId: id,
    );
  }

  Future<DxpLandingPage> archiveLandingPage(String id) async {
    final client = _requireClient();
    final row = await client
        .from('landing_pages')
        .update({
          'status': LandingPageStatus.archived.slug,
          'is_published': false,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();
    return DxpLandingPage.fromJson(Map<String, dynamic>.from(row));
  }

  Future<DxpCampaign> upsertCampaign({
    String? id,
    required String name,
    String channel = 'omni',
    String? campaignCode,
    String? objective,
    double budgetAmount = 0,
    CampaignStatus status = CampaignStatus.draft,
  }) async {
    final client = _requireClient();
    final payload = <String, dynamic>{
      if (id != null) 'id': id,
      'name': name.trim(),
      'channel': channel.trim().isEmpty ? 'omni' : channel.trim(),
      'primary_channel': channel.trim().isEmpty ? 'omni' : channel.trim(),
      'campaign_code': campaignCode?.trim(),
      'objective': objective?.trim(),
      'budget_amount': budgetAmount,
      'status': status.slug,
      'is_deleted': false,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final row = await client
        .from('campaigns')
        .upsert(payload)
        .select()
        .single();
    return DxpCampaign.fromJson(Map<String, dynamic>.from(row));
  }

  Future<DxpCampaign> setCampaignStatus({
    required String id,
    required CampaignStatus status,
  }) async {
    final client = _requireClient();
    final row = await client
        .from('campaigns')
        .update({
          'status': status.slug,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();
    return DxpCampaign.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> softDeleteCampaign(String id) async {
    final client = _requireClient();
    await client
        .from('campaigns')
        .update({
          'is_deleted': true,
          'status': CampaignStatus.cancelled.slug,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<DxpCalendarItem> upsertCalendarItem({
    String? id,
    required String title,
    required DateTime scheduledFor,
    String channel = 'blog',
    String? contentType,
    String status = 'planned',
    String? ownerLabel,
    String? notes,
  }) async {
    final client = _requireClient();
    final payload = <String, dynamic>{
      if (id != null) 'id': id,
      'title': title.trim(),
      'channel': channel.trim().isEmpty ? 'blog' : channel.trim(),
      'content_type': contentType?.trim(),
      'scheduled_for': scheduledFor.toUtc().toIso8601String(),
      'status': status.trim().isEmpty ? 'planned' : status.trim(),
      'owner_label': ownerLabel?.trim(),
      'notes': notes?.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final row = await client
        .from('content_calendar')
        .upsert(payload)
        .select()
        .single();
    return DxpCalendarItem.fromJson(Map<String, dynamic>.from(row));
  }

  Future<DxpCalendarItem> setCalendarStatus({
    required String id,
    required String status,
  }) async {
    final client = _requireClient();
    final row = await client
        .from('content_calendar')
        .update({
          'status': status.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();
    return DxpCalendarItem.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deleteCalendarItem(String id) async {
    final client = _requireClient();
    await client.from('content_calendar').delete().eq('id', id);
  }

  /// Manual bridge when auto-sync skipped (missing phone/name).
  Future<Map<String, dynamic>> resyncFormSubmissionToCrm(
    String submissionId,
  ) async {
    final client = _requireClient();
    final raw = await client.rpc(
      'resync_form_submission_to_crm',
      params: {'p_submission_id': submissionId},
    );
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {'ok': true, 'raw': raw};
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured');
    }
    return client;
  }

  static String _slugify(String input) {
    final s = input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return s.isEmpty ? 'landing-${DateTime.now().millisecondsSinceEpoch}' : s;
  }

  Future<void> _logActivity({
    required String action,
    required String summary,
    String? entityType,
    String? entityId,
  }) async {
    try {
      final client = _requireClient();
      final user = client.auth.currentUser;
      final meta = user?.userMetadata;
      final named = meta?['full_name'] ?? meta?['name'];
      final actor = named is String && named.trim().isNotEmpty
          ? named.trim()
          : (user?.email?.trim().isNotEmpty ?? false)
          ? user!.email!.trim()
          : 'Marketing desk';
      await client.from('marketing_activity_logs').insert({
        'action': action,
        'summary': summary,
        'actor_label': actor,
        'entity_type': entityType,
        'entity_id': entityId,
        'occurred_at': DateTime.now().toUtc().toIso8601String(),
        'metadata': <String, dynamic>{},
      });
    } catch (_) {
      // Publication already succeeded. A missing activity row must not roll it back.
    }
  }

  Future<_CrmLeadStats> _loadCrmLeadStats(SupabaseClient client) async {
    final rows = await client
        .from('crm_leads')
        .select('id, status, captured_at, created_at')
        .limit(2000);
    var open = 0;
    var qualified = 0;
    var won = 0;
    var lost = 0;
    final capturedAt = <DateTime>[];
    for (final raw in rows) {
      final m = Map<String, dynamic>.from(raw as Map);
      final status = ('${m['status'] ?? ''}').toLowerCase();
      if (status.contains('lost')) {
        lost++;
      } else if (status.contains('won') ||
          status.contains('client') ||
          status.contains('closed')) {
        won++;
      } else if (status.contains('qualif')) {
        qualified++;
      } else {
        open++;
      }
      final at = DateTime.tryParse(
        '${m['captured_at'] ?? m['created_at'] ?? ''}',
      );
      if (at != null) capturedAt.add(at.toLocal());
    }
    return _CrmLeadStats(
      open: open,
      qualified: qualified,
      won: won,
      lost: lost,
      capturedAt: capturedAt,
    );
  }
}

class _CrmLeadStats {
  const _CrmLeadStats({
    this.open = 0,
    this.qualified = 0,
    this.won = 0,
    this.lost = 0,
    this.capturedAt = const [],
  });

  final int open;
  final int qualified;
  final int won;
  final int lost;
  final List<DateTime> capturedAt;

  int get total => open + qualified + won + lost;
}

/// Live KPI builder — never invents sessions/revenue.
abstract final class DxpKpiBuilder {
  static List<DxpKpi> build({
    required List<DxpCampaign> campaigns,
    required List<DxpFormSubmission> formSubmissions,
    required List<DxpSeoHealth> seoHealth,
    required int crmLeadCount,
    required int crmQualifiedCount,
    required int crmWonCount,
    required int publishedContentCount,
    required int mediaCount,
    required int scheduledContentCount,
  }) {
    final activeCampaigns = campaigns
        .where((c) => c.status == CampaignStatus.active)
        .length
        .toDouble();
    final unsyncedForms = formSubmissions
        .where((submission) => !submission.isSyncedToCrm)
        .length;
    final leads = (crmLeadCount + unsyncedForms).toDouble();
    final qualified = crmQualifiedCount.toDouble();
    final won = crmWonCount.toDouble();
    final scored = seoHealth.where((record) => record.hasRecordedScore).toList();
    final seoIsCoverage = scored.isEmpty;
    final seoValue = seoIsCoverage
        ? (seoHealth.isEmpty
              ? 0.0
              : seoHealth.where((record) => record.hasCoverage).length /
                    seoHealth.length *
                    100)
        : scored.fold<double>(0, (sum, record) => sum + record.healthScore) /
              scored.length;

    final plannedBudget = campaigns.fold<double>(
      0,
      (sum, campaign) => sum + campaign.budgetAmount,
    );
    final seoIssues = seoHealth.fold<int>(
      0,
      (sum, record) => sum + record.issueCount,
    );

    return [
      DxpKpi(label: 'CRM Leads', value: leads),
      DxpKpi(label: 'Qualified Leads', value: qualified),
      DxpKpi(label: 'Won / Clients', value: won),
      DxpKpi(label: 'Active Campaigns', value: activeCampaigns),
      DxpKpi(
        label: 'Published Content',
        value: publishedContentCount.toDouble(),
      ),
      DxpKpi(
        label: 'Scheduled Content',
        value: scheduledContentCount.toDouble(),
      ),
      DxpKpi(label: 'Planned Budget', value: plannedBudget, unit: 'currency'),
      DxpKpi(label: 'Awaiting CRM Sync', value: unsyncedForms.toDouble()),
      DxpKpi(
        label: seoIsCoverage ? 'SEO Coverage' : 'Avg SEO Score',
        value: seoValue,
        unit: seoIsCoverage ? 'percent' : 'score',
      ),
      DxpKpi(label: 'SEO Issues', value: seoIssues.toDouble()),
      DxpKpi(label: 'Media Assets', value: mediaCount.toDouble()),
    ];
  }
}
