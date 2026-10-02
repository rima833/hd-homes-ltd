// Volume 4 Part 8 — Enterprise Marketing, CMS & Digital Experience (DXP) models.

const String kAiContentDisclaimer =
    'AI-generated — editable. Suggestions are drafts for human review, not '
    'published content guarantees or performance promises.';

String formatDxpCount(double? value) {
  if (value == null) return '—';
  final n = value;
  if (n.abs() >= 1e6) return '${(n / 1e6).toStringAsFixed(1)}M';
  if (n.abs() >= 1e3) return '${(n / 1e3).toStringAsFixed(1)}K';
  return n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(1);
}

enum CampaignStatus {
  draft,
  active,
  paused,
  completed,
  cancelled;

  String get label => switch (this) {
    CampaignStatus.draft => 'Draft',
    CampaignStatus.active => 'Active',
    CampaignStatus.paused => 'Paused',
    CampaignStatus.completed => 'Completed',
    CampaignStatus.cancelled => 'Cancelled',
  };

  String get slug => name;

  static CampaignStatus fromSlug(String? raw) {
    return switch ((raw ?? 'draft').toLowerCase()) {
      'active' || 'running' || 'sent' || 'sending' => CampaignStatus.active,
      'paused' => CampaignStatus.paused,
      'completed' || 'done' => CampaignStatus.completed,
      'cancelled' || 'canceled' => CampaignStatus.cancelled,
      _ => CampaignStatus.draft,
    };
  }
}

enum LandingPageStatus {
  draft,
  published,
  archived,
  scheduled;

  String get label => switch (this) {
    LandingPageStatus.draft => 'Draft',
    LandingPageStatus.published => 'Published',
    LandingPageStatus.archived => 'Archived',
    LandingPageStatus.scheduled => 'Scheduled',
  };

  String get slug => name;

  static LandingPageStatus fromSlug(String? raw) {
    return switch ((raw ?? 'draft').toLowerCase()) {
      'published' => LandingPageStatus.published,
      'archived' => LandingPageStatus.archived,
      'scheduled' => LandingPageStatus.scheduled,
      _ => LandingPageStatus.draft,
    };
  }
}

enum BlogPostStatus {
  draft,
  published,
  archived;

  String get label => switch (this) {
    BlogPostStatus.draft => 'Draft',
    BlogPostStatus.published => 'Published',
    BlogPostStatus.archived => 'Archived',
  };

  String get slug => name;

  static BlogPostStatus fromSlug(String? raw, {bool? isPublished}) {
    if (isPublished == true) return BlogPostStatus.published;
    return switch ((raw ?? 'draft').toLowerCase()) {
      'published' => BlogPostStatus.published,
      'archived' => BlogPostStatus.archived,
      _ => BlogPostStatus.draft,
    };
  }
}

class DxpKpi {
  const DxpKpi({required this.label, required this.value, this.unit = 'count'});

  final String label;
  final double value;
  final String unit;

  String get displayValue {
    if (unit == 'percent') {
      return value == value.roundToDouble()
          ? '${value.toStringAsFixed(0)}%'
          : '${value.toStringAsFixed(1)}%';
    }
    if (unit == 'score') {
      return value.toStringAsFixed(0);
    }
    if (unit == 'currency') {
      if (value <= 0) return '₦0';
      if (value.abs() >= 1e6) {
        return '₦${(value / 1e6).toStringAsFixed(1)}M';
      }
      if (value.abs() >= 1e3) {
        return '₦${(value / 1e3).toStringAsFixed(1)}K';
      }
      return '₦${value.toStringAsFixed(0)}';
    }
    return formatDxpCount(value);
  }
}

class DxpFunnelStage {
  const DxpFunnelStage({
    required this.label,
    required this.value,
    this.stageKey = '',
  });

  final String label;
  final double value;
  final String stageKey;

  String get displayValue => formatDxpCount(value);
}

class DxpCampaign {
  const DxpCampaign({
    required this.id,
    required this.name,
    this.channel = 'omni',
    this.status = CampaignStatus.draft,
    this.campaignCode,
    this.objective,
    this.budgetAmount = 0,
    this.impressions = 0,
    this.clicks = 0,
    this.conversions = 0,
    this.startsAt,
    this.endsAt,
  });

  final String id;
  final String name;
  final String channel;
  final CampaignStatus status;
  final String? campaignCode;
  final String? objective;
  final double budgetAmount;
  final double impressions;
  final double clicks;
  final double conversions;
  final DateTime? startsAt;
  final DateTime? endsAt;

  double get clickRate => impressions <= 0 ? 0 : (clicks / impressions) * 100;

  factory DxpCampaign.fromJson(Map<String, dynamic> json) {
    final metrics = json['metrics'];
    Map<String, dynamic> m = {};
    if (metrics is Map) {
      m = Map<String, dynamic>.from(metrics);
    }
    return DxpCampaign(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      channel:
          json['primary_channel'] as String? ??
          json['channel'] as String? ??
          'omni',
      status: CampaignStatus.fromSlug(json['status'] as String?),
      campaignCode: json['campaign_code'] as String?,
      objective: json['objective'] as String?,
      budgetAmount: (json['budget_amount'] as num?)?.toDouble() ?? 0,
      impressions: (m['impressions'] as num?)?.toDouble() ?? 0,
      clicks: (m['clicks'] as num?)?.toDouble() ?? 0,
      conversions: (m['conversions'] as num?)?.toDouble() ?? 0,
      startsAt: DateTime.tryParse(json['starts_at'] as String? ?? ''),
      endsAt: DateTime.tryParse(json['ends_at'] as String? ?? ''),
    );
  }
}

class DxpLandingPage {
  const DxpLandingPage({
    required this.id,
    required this.title,
    required this.slug,
    this.headline,
    this.subheadline,
    this.heroImageUrl,
    this.status = LandingPageStatus.draft,
    this.isPublished = false,
    this.seoScore,
    this.conversionGoal,
    this.ctaLabel,
    this.ctaUrl,
    this.publishedAt,
  });

  final String id;
  final String title;
  final String slug;
  final String? headline;
  final String? subheadline;
  final String? heroImageUrl;
  final LandingPageStatus status;
  final bool isPublished;
  final double? seoScore;
  final String? conversionGoal;
  final String? ctaLabel;
  final String? ctaUrl;
  final DateTime? publishedAt;

  factory DxpLandingPage.fromJson(Map<String, dynamic> json) {
    return DxpLandingPage(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      headline: json['headline'] as String?,
      subheadline: json['subheadline'] as String?,
      heroImageUrl: json['hero_image_url'] as String?,
      status: LandingPageStatus.fromSlug(json['status'] as String?),
      isPublished: json['is_published'] as bool? ?? false,
      seoScore: (json['seo_score'] as num?)?.toDouble(),
      conversionGoal: json['conversion_goal'] as String?,
      ctaLabel: json['cta_label'] as String?,
      ctaUrl: json['cta_url'] as String?,
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
    );
  }
}

class DxpCmsPage {
  const DxpCmsPage({
    required this.id,
    required this.title,
    required this.slug,
    this.isPublished = false,
    this.status = 'active',
    this.seoScore,
    this.locale = 'en',
    this.publishedAt,
  });

  final String id;
  final String title;
  final String slug;
  final bool isPublished;
  final String status;
  final double? seoScore;
  final String locale;
  final DateTime? publishedAt;

  factory DxpCmsPage.fromJson(Map<String, dynamic> json) {
    return DxpCmsPage(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      isPublished: json['is_published'] as bool? ?? false,
      status: json['status'] as String? ?? 'active',
      seoScore: (json['seo_score'] as num?)?.toDouble(),
      locale: json['locale'] as String? ?? 'en',
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
    );
  }
}

class DxpBlogPost {
  const DxpBlogPost({
    required this.id,
    required this.title,
    required this.slug,
    this.excerpt,
    this.status = BlogPostStatus.draft,
    this.isPublished = false,
    this.featured = false,
    this.seoScore,
    this.readingTimeMinutes,
    this.aiGenerated = false,
    this.aiEditable = true,
    this.publishedAt,
  });

  final String id;
  final String title;
  final String slug;
  final String? excerpt;
  final BlogPostStatus status;
  final bool isPublished;
  final bool featured;
  final double? seoScore;
  final int? readingTimeMinutes;
  final bool aiGenerated;
  final bool aiEditable;
  final DateTime? publishedAt;

  String? get aiDisclaimer => aiGenerated ? kAiContentDisclaimer : null;

  factory DxpBlogPost.fromJson(Map<String, dynamic> json) {
    final meta = json['metadata'];
    Map<String, dynamic> m = {};
    if (meta is Map) m = Map<String, dynamic>.from(meta);
    final published = json['is_published'] as bool? ?? false;
    return DxpBlogPost(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      excerpt: json['excerpt'] as String?,
      status: BlogPostStatus.fromSlug(
        json['status'] as String?,
        isPublished: published,
      ),
      isPublished: published,
      featured: json['featured'] as bool? ?? false,
      seoScore: (json['seo_score'] as num?)?.toDouble(),
      readingTimeMinutes: json['reading_time_minutes'] as int?,
      aiGenerated: m['ai_generated'] as bool? ?? false,
      aiEditable: m['editable'] as bool? ?? true,
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
    );
  }
}

class DxpMediaAsset {
  const DxpMediaAsset({
    required this.id,
    required this.fileUrl,
    this.title,
    this.fileType = 'image',
    this.folderName,
    this.altText,
    this.isPublished = false,
  });

  final String id;
  final String fileUrl;
  final String? title;
  final String fileType;
  final String? folderName;
  final String? altText;
  final bool isPublished;

  factory DxpMediaAsset.fromJson(Map<String, dynamic> json) {
    return DxpMediaAsset(
      id: json['id'] as String,
      fileUrl: json['file_url'] as String? ?? '',
      title: json['title'] as String?,
      fileType: json['file_type'] as String? ?? 'image',
      folderName: json['folder_name'] as String?,
      altText: json['alt_text'] as String?,
      isPublished: json['is_published'] as bool? ?? false,
    );
  }
}

class DxpFormSubmission {
  const DxpFormSubmission({
    required this.id,
    required this.formId,
    this.email,
    this.phone,
    this.sourcePath,
    this.status = 'new',
    this.submittedAt,
    this.displayName,
    this.crmLeadId,
    this.crmSyncedAt,
  });

  final String id;
  final String formId;
  final String? email;
  final String? phone;
  final String? sourcePath;
  final String status;
  final DateTime? submittedAt;
  final String? displayName;
  final String? crmLeadId;
  final DateTime? crmSyncedAt;

  bool get isSyncedToCrm =>
      crmLeadId != null && (crmLeadId?.isNotEmpty ?? false);

  factory DxpFormSubmission.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'];
    Map<String, dynamic> p = {};
    if (payload is Map) p = Map<String, dynamic>.from(payload);
    return DxpFormSubmission(
      id: json['id'] as String,
      formId: json['form_id'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      sourcePath: json['source_path'] as String?,
      status: json['status'] as String? ?? 'new',
      submittedAt: DateTime.tryParse(json['submitted_at'] as String? ?? ''),
      displayName:
          p['full_name'] as String? ??
          p['name'] as String? ??
          p['fullName'] as String?,
      crmLeadId: json['crm_lead_id'] as String?,
      crmSyncedAt: DateTime.tryParse(json['crm_synced_at'] as String? ?? ''),
    );
  }
}

class DxpSeoHealth {
  const DxpSeoHealth({
    required this.id,
    required this.path,
    this.metaTitle,
    this.healthScore = 0,
    this.issueCount = 0,
    this.entityType,
    this.metaDescription,
    this.lastAuditAt,
  });

  final String id;
  final String path;
  final String? metaTitle;
  final double healthScore;
  final int issueCount;
  final String? entityType;
  final String? metaDescription;
  final DateTime? lastAuditAt;

  bool get hasCoverage {
    final title = metaTitle?.trim() ?? '';
    final description = metaDescription?.trim() ?? '';
    return title.isNotEmpty && description.isNotEmpty;
  }

  /// A stored score counts only after an audit, or when the score itself is set.
  bool get hasRecordedScore => lastAuditAt != null || healthScore > 0;

  factory DxpSeoHealth.fromJson(Map<String, dynamic> json) {
    return DxpSeoHealth(
      id: json['id'] as String,
      path: json['path'] as String? ?? '',
      metaTitle: json['meta_title'] as String?,
      healthScore: (json['health_score'] as num?)?.toDouble() ?? 0,
      issueCount: json['issue_count'] as int? ?? 0,
      entityType: json['entity_type'] as String?,
      metaDescription: json['meta_description'] as String?,
      lastAuditAt: DateTime.tryParse(json['last_audit_at'] as String? ?? ''),
    );
  }
}

class DxpCalendarItem {
  const DxpCalendarItem({
    required this.id,
    required this.title,
    required this.scheduledFor,
    this.channel = 'blog',
    this.contentType,
    this.status = 'planned',
    this.ownerLabel,
    this.notes,
  });

  final String id;
  final String title;
  final DateTime scheduledFor;
  final String channel;
  final String? contentType;
  final String status;
  final String? ownerLabel;
  final String? notes;

  factory DxpCalendarItem.fromJson(Map<String, dynamic> json) {
    return DxpCalendarItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      scheduledFor:
          DateTime.tryParse(json['scheduled_for'] as String? ?? '') ??
          DateTime.now(),
      channel: json['channel'] as String? ?? 'blog',
      contentType: json['content_type'] as String?,
      status: json['status'] as String? ?? 'planned',
      ownerLabel: json['owner_label'] as String?,
      notes: json['notes'] as String?,
    );
  }
}

class DxpAbTest {
  const DxpAbTest({
    required this.id,
    required this.name,
    this.hypothesis,
    this.status = 'draft',
    this.primaryMetric = 'conversion_rate',
    this.trafficSplit = 50,
    this.winner,
  });

  final String id;
  final String name;
  final String? hypothesis;
  final String status;
  final String primaryMetric;
  final double trafficSplit;
  final String? winner;

  factory DxpAbTest.fromJson(Map<String, dynamic> json) {
    return DxpAbTest(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      hypothesis: json['hypothesis'] as String?,
      status: json['status'] as String? ?? 'draft',
      primaryMetric: json['primary_metric'] as String? ?? 'conversion_rate',
      trafficSplit: (json['traffic_split'] as num?)?.toDouble() ?? 50,
      winner: json['winner'] as String?,
    );
  }
}

class DxpAiInsight {
  const DxpAiInsight({
    required this.id,
    required this.title,
    required this.body,
    this.category = 'content',
    this.confidencePct,
    this.disclaimer = kAiContentDisclaimer,
    this.editable = true,
  });

  final String id;
  final String title;
  final String body;
  final String category;
  final double? confidencePct;
  final String disclaimer;
  final bool editable;
}

class DxpActivity {
  const DxpActivity({
    required this.id,
    required this.summary,
    this.action = '',
    this.actorLabel,
    this.occurredAt,
  });

  final String id;
  final String summary;
  final String action;
  final String? actorLabel;
  final DateTime? occurredAt;

  factory DxpActivity.fromJson(Map<String, dynamic> json) {
    return DxpActivity(
      id: json['id'] as String,
      summary: json['summary'] as String? ?? '',
      action: json['action'] as String? ?? '',
      actorLabel: json['actor_label'] as String?,
      occurredAt: DateTime.tryParse(json['occurred_at'] as String? ?? ''),
    );
  }
}

class DxpAlert {
  const DxpAlert({
    required this.id,
    required this.title,
    this.body,
    this.severity = 'info',
    this.category,
  });

  final String id;
  final String title;
  final String? body;
  final String severity;
  final String? category;

  factory DxpAlert.fromJson(Map<String, dynamic> json) {
    return DxpAlert(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      body: json['body'] as String?,
      severity: json['severity'] as String? ?? 'info',
      category: json['category'] as String?,
    );
  }
}

class DxpCommandCenterSnapshot {
  const DxpCommandCenterSnapshot({
    required this.kpis,
    required this.funnel,
    required this.campaigns,
    required this.landingPages,
    required this.cmsPages,
    required this.blogPosts,
    required this.mediaAssets,
    required this.formSubmissions,
    required this.seoHealth,
    required this.calendar,
    required this.abTests,
    required this.activities,
    required this.alerts,
    required this.aiInsights,
    this.fromRemote = false,
    this.loadedAt,
    this.aiDisclaimer = kAiContentDisclaimer,
    this.loadWarnings = const [],
    this.crmLeadCount = 0,
    this.crmQualifiedCount = 0,
    this.crmLeadCapturedAt = const [],
  });

  factory DxpCommandCenterSnapshot.empty({bool fromRemote = false}) {
    return DxpCommandCenterSnapshot(
      kpis: const [
        DxpKpi(label: 'CRM Leads', value: 0),
        DxpKpi(label: 'Qualified Leads', value: 0),
        DxpKpi(label: 'Won / Clients', value: 0),
        DxpKpi(label: 'Active Campaigns', value: 0),
        DxpKpi(label: 'Published Content', value: 0),
        DxpKpi(label: 'Scheduled Content', value: 0),
        DxpKpi(label: 'Planned Budget', value: 0, unit: 'currency'),
        DxpKpi(label: 'Awaiting CRM Sync', value: 0),
        DxpKpi(label: 'SEO Coverage', value: 0, unit: 'percent'),
        DxpKpi(label: 'SEO Issues', value: 0),
        DxpKpi(label: 'Media Assets', value: 0),
      ],
      funnel: const [],
      campaigns: const [],
      landingPages: const [],
      cmsPages: const [],
      blogPosts: const [],
      mediaAssets: const [],
      formSubmissions: const [],
      seoHealth: const [],
      calendar: const [],
      abTests: const [],
      activities: const [],
      alerts: const [],
      aiInsights: const [],
      fromRemote: fromRemote,
      loadedAt: null,
    );
  }

  final List<DxpKpi> kpis;
  final List<DxpFunnelStage> funnel;
  final List<DxpCampaign> campaigns;
  final List<DxpLandingPage> landingPages;
  final List<DxpCmsPage> cmsPages;
  final List<DxpBlogPost> blogPosts;
  final List<DxpMediaAsset> mediaAssets;
  final List<DxpFormSubmission> formSubmissions;
  final List<DxpSeoHealth> seoHealth;
  final List<DxpCalendarItem> calendar;
  final List<DxpAbTest> abTests;
  final List<DxpActivity> activities;
  final List<DxpAlert> alerts;
  final List<DxpAiInsight> aiInsights;
  final bool fromRemote;
  final DateTime? loadedAt;
  final String aiDisclaimer;
  final List<String> loadWarnings;
  final int crmLeadCount;
  final int crmQualifiedCount;

  /// Real CRM capture timestamps. Empty when a lead has no captured date.
  final List<DateTime> crmLeadCapturedAt;
}
