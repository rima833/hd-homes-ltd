// Volume 4 Part 8 — Enterprise Marketing, CMS & Digital Experience (DXP) models.

const String kAiContentDisclaimer =
    'AI-generated — editable. Suggestions are drafts for human review, not '
    'published content guarantees or performance promises.';

String formatDxpCount(double? value) {
  if (value == null) return '—';
  final n = value;
  if (n.abs() >= 1e6) return '${(n / 1e6).toStringAsFixed(1)}M';
  if (n.abs() >= 1e3) return '${(n / 1e3).toStringAsFixed(1)}K';
  return n == n.roundToDouble()
      ? n.toStringAsFixed(0)
      : n.toStringAsFixed(1);
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
  const DxpKpi({
    required this.label,
    required this.value,
    this.unit = 'count',
  });

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

  double get clickRate =>
      impressions <= 0 ? 0 : (clicks / impressions) * 100;

  factory DxpCampaign.fromJson(Map<String, dynamic> json) {
    final metrics = json['metrics'];
    Map<String, dynamic> m = {};
    if (metrics is Map) {
      m = Map<String, dynamic>.from(metrics);
    }
    return DxpCampaign(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      channel: json['primary_channel'] as String? ??
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
    this.status = LandingPageStatus.draft,
    this.isPublished = false,
    this.seoScore,
    this.conversionGoal,
    this.ctaLabel,
    this.publishedAt,
  });

  final String id;
  final String title;
  final String slug;
  final String? headline;
  final LandingPageStatus status;
  final bool isPublished;
  final double? seoScore;
  final String? conversionGoal;
  final String? ctaLabel;
  final DateTime? publishedAt;

  factory DxpLandingPage.fromJson(Map<String, dynamic> json) {
    return DxpLandingPage(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      headline: json['headline'] as String?,
      status: LandingPageStatus.fromSlug(json['status'] as String?),
      isPublished: json['is_published'] as bool? ?? false,
      seoScore: (json['seo_score'] as num?)?.toDouble(),
      conversionGoal: json['conversion_goal'] as String?,
      ctaLabel: json['cta_label'] as String?,
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
  });

  final String id;
  final String title;
  final String slug;
  final bool isPublished;
  final String status;
  final double? seoScore;
  final String locale;

  factory DxpCmsPage.fromJson(Map<String, dynamic> json) {
    return DxpCmsPage(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      isPublished: json['is_published'] as bool? ?? false,
      status: json['status'] as String? ?? 'active',
      seoScore: (json['seo_score'] as num?)?.toDouble(),
      locale: json['locale'] as String? ?? 'en',
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

  String? get aiDisclaimer =>
      aiGenerated ? kAiContentDisclaimer : null;

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
  });

  final String id;
  final String fileUrl;
  final String? title;
  final String fileType;
  final String? folderName;
  final String? altText;

  factory DxpMediaAsset.fromJson(Map<String, dynamic> json) {
    return DxpMediaAsset(
      id: json['id'] as String,
      fileUrl: json['file_url'] as String? ?? '',
      title: json['title'] as String?,
      fileType: json['file_type'] as String? ?? 'image',
      folderName: json['folder_name'] as String?,
      altText: json['alt_text'] as String?,
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
  });

  final String id;
  final String formId;
  final String? email;
  final String? phone;
  final String? sourcePath;
  final String status;
  final DateTime? submittedAt;
  final String? displayName;

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
      displayName: p['full_name'] as String?,
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
  });

  final String id;
  final String path;
  final String? metaTitle;
  final double healthScore;
  final int issueCount;
  final String? entityType;

  factory DxpSeoHealth.fromJson(Map<String, dynamic> json) {
    return DxpSeoHealth(
      id: json['id'] as String,
      path: json['path'] as String? ?? '',
      metaTitle: json['meta_title'] as String?,
      healthScore: (json['health_score'] as num?)?.toDouble() ?? 0,
      issueCount: json['issue_count'] as int? ?? 0,
      entityType: json['entity_type'] as String?,
    );
  }
}

class DxpCalendarItem {
  const DxpCalendarItem({
    required this.id,
    required this.title,
    required this.scheduledFor,
    this.channel = 'blog',
    this.status = 'planned',
    this.ownerLabel,
    this.notes,
  });

  final String id;
  final String title;
  final DateTime scheduledFor;
  final String channel;
  final String status;
  final String? ownerLabel;
  final String? notes;

  factory DxpCalendarItem.fromJson(Map<String, dynamic> json) {
    return DxpCalendarItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      scheduledFor: DateTime.tryParse(json['scheduled_for'] as String? ?? '') ??
          DateTime.now(),
      channel: json['channel'] as String? ?? 'blog',
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
  });

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
}

abstract final class DxpDemo {
  static DxpCommandCenterSnapshot snapshot() {
    final now = DateTime.now();
    final landing = _landing();
    final blogs = _blogs();
    final campaigns = _campaigns(now);
    final forms = _forms(now);
    final seo = _seo();
    final funnel = _funnel();
    return DxpCommandCenterSnapshot(
      kpis: aggregateKpis(
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
      cmsPages: _cmsPages(),
      blogPosts: blogs,
      mediaAssets: _media(),
      formSubmissions: forms,
      seoHealth: seo,
      calendar: _calendar(now),
      abTests: _abTests(),
      activities: _activities(now),
      alerts: _alerts(),
      aiInsights: _aiInsights(),
      fromRemote: false,
      loadedAt: now,
    );
  }

  static List<DxpKpi> aggregateKpis({
    required List<DxpCampaign> campaigns,
    required List<DxpLandingPage> landingPages,
    required List<DxpBlogPost> blogPosts,
    required List<DxpFormSubmission> formSubmissions,
    required List<DxpSeoHealth> seoHealth,
    required List<DxpFunnelStage> funnel,
  }) {
    final publishedLp =
        landingPages.where((p) => p.isPublished).length.toDouble();
    final draftBlogs =
        blogPosts.where((b) => b.status == BlogPostStatus.draft).length.toDouble();
    final activeCampaigns = campaigns
        .where((c) => c.status == CampaignStatus.active)
        .length
        .toDouble();
    final leads = formSubmissions.length.toDouble();
    final avgSeo = seoHealth.isEmpty
        ? 0.0
        : seoHealth.fold<double>(0, (s, e) => s + e.healthScore) /
            seoHealth.length;
    final conversions = funnel
        .where((f) => f.stageKey == 'conversion')
        .fold<double>(0, (s, f) => s + f.value);
    final awareness = funnel
        .where((f) => f.stageKey == 'awareness')
        .fold<double>(0, (s, f) => s + f.value);
    final convRate = awareness <= 0 ? 0.0 : (conversions / awareness) * 100;

    return [
      DxpKpi(label: 'Published LPs', value: publishedLp),
      DxpKpi(label: 'Active Campaigns', value: activeCampaigns),
      DxpKpi(label: 'Form Leads', value: leads),
      DxpKpi(label: 'Draft Posts', value: draftBlogs),
      DxpKpi(label: 'Avg SEO Score', value: avgSeo, unit: 'score'),
      DxpKpi(label: 'Funnel CVR', value: convRate, unit: 'percent'),
      DxpKpi(label: 'Conversions', value: conversions),
      DxpKpi(
        label: 'Sessions (30d)',
        value: awareness > 0 ? awareness : 28420,
      ),
    ];
  }

  static List<DxpFunnelStage> _funnel() => const [
        DxpFunnelStage(
          label: 'Awareness',
          value: 128400,
          stageKey: 'awareness',
        ),
        DxpFunnelStage(
          label: 'Consideration',
          value: 4120,
          stageKey: 'consideration',
        ),
        DxpFunnelStage(
          label: 'Conversion',
          value: 186,
          stageKey: 'conversion',
        ),
      ];

  static List<DxpLandingPage> _landing() => const [
        DxpLandingPage(
          id: 'd4800000-0000-4000-8000-000000000030',
          title: 'Lekki Waterfront Launch',
          slug: 'lekki-waterfront-launch',
          headline: 'Own waterfront living in Lekki',
          status: LandingPageStatus.published,
          isPublished: true,
          seoScore: 86,
          conversionGoal: 'inspection_booking',
          ctaLabel: 'Book inspection',
        ),
        DxpLandingPage(
          id: 'd4800000-0000-4000-8000-000000000031',
          title: 'Investor Open Day',
          slug: 'investor-open-day',
          headline: 'Investor Open Day — Ajah corridor',
          status: LandingPageStatus.draft,
          seoScore: 62,
          conversionGoal: 'rsvp',
          ctaLabel: 'Reserve seat',
        ),
      ];

  static List<DxpCmsPage> _cmsPages() => const [
        DxpCmsPage(
          id: 'd4800000-0000-4000-8000-000000000210',
          title: 'Home',
          slug: 'home',
          isPublished: true,
          seoScore: 78,
        ),
        DxpCmsPage(
          id: 'd4800000-0000-4000-8000-000000000211',
          title: 'About HD Homes',
          slug: 'about',
          isPublished: true,
          seoScore: 71,
        ),
      ];

  static List<DxpBlogPost> _blogs() => const [
        DxpBlogPost(
          id: 'd4800000-0000-4000-8000-000000000040',
          title: 'Why Lekki still leads coastal demand',
          slug: 'why-lekki-still-leads-coastal-demand',
          excerpt:
              'A market note for buyers evaluating waterfront inventory.',
          status: BlogPostStatus.draft,
          seoScore: 58,
          readingTimeMinutes: 6,
          aiGenerated: true,
          aiEditable: true,
        ),
      ];

  static List<DxpMediaAsset> _media() => const [
        DxpMediaAsset(
          id: 'd4800000-0000-4000-8000-000000000220',
          title: 'Waterfront hero dusk',
          fileUrl: 'https://cdn.example.com/lekki-hero.jpg',
          fileType: 'image',
          folderName: 'Campaign Assets',
          altText: 'Lekki waterfront villa at dusk',
        ),
        DxpMediaAsset(
          id: 'd4800000-0000-4000-8000-000000000221',
          title: 'Brochure PDF',
          fileUrl: 'https://cdn.example.com/lekki-brochure.pdf',
          fileType: 'document',
          folderName: 'Campaign Assets',
        ),
      ];

  static List<DxpCampaign> _campaigns(DateTime now) => [
        DxpCampaign(
          id: 'd4800000-0000-4000-8000-000000000060',
          name: 'Q3 Waterfront Awareness',
          channel: 'email',
          status: CampaignStatus.active,
          campaignCode: 'CAMP-Q3-WF',
          objective: 'awareness',
          budgetAmount: 8500000,
          impressions: 128400,
          clicks: 4120,
          conversions: 186,
          startsAt: now.subtract(const Duration(days: 7)),
          endsAt: now.add(const Duration(days: 45)),
        ),
        DxpCampaign(
          id: 'd4800000-0000-4000-8000-000000000072',
          name: 'SMS reminder — weekend tour',
          channel: 'sms',
          status: CampaignStatus.active,
          campaignCode: 'CAMP-SMS-01',
          impressions: 980,
          clicks: 420,
          conversions: 64,
        ),
        DxpCampaign(
          id: 'd4800000-0000-4000-8000-000000000073',
          name: 'WhatsApp nurture — brochure',
          channel: 'whatsapp',
          status: CampaignStatus.draft,
          campaignCode: 'CAMP-WA-01',
        ),
      ];

  static List<DxpFormSubmission> _forms(DateTime now) => [
        DxpFormSubmission(
          id: 'd4800000-0000-4000-8000-000000000081',
          formId: 'd4800000-0000-4000-8000-000000000080',
          email: 'tunde@example.com',
          phone: '+2348011110001',
          sourcePath: '/landing/lekki-waterfront-launch',
          status: 'new',
          submittedAt: now.subtract(const Duration(hours: 6)),
          displayName: 'Tunde Adebayo',
        ),
        DxpFormSubmission(
          id: 'd4800000-0000-4000-8000-000000000082',
          formId: 'd4800000-0000-4000-8000-000000000080',
          email: 'ngozi@example.com',
          phone: '+2348022220002',
          sourcePath: '/landing/lekki-waterfront-launch',
          status: 'contacted',
          submittedAt: now.subtract(const Duration(days: 1)),
          displayName: 'Ngozi Ike',
        ),
      ];

  static List<DxpSeoHealth> _seo() => const [
        DxpSeoHealth(
          id: 'd4800000-0000-4000-8000-000000000090',
          path: '/landing/lekki-waterfront-launch',
          metaTitle: 'Lekki Waterfront Homes | HD Homes',
          healthScore: 86,
          issueCount: 1,
          entityType: 'landing_page',
        ),
        DxpSeoHealth(
          id: 'd4800000-0000-4000-8000-000000000091',
          path: '/blog/why-lekki-still-leads-coastal-demand',
          metaTitle: 'Why Lekki still leads coastal demand',
          healthScore: 58,
          issueCount: 2,
          entityType: 'blog',
        ),
      ];

  static List<DxpCalendarItem> _calendar(DateTime now) => [
        DxpCalendarItem(
          id: 'd4800000-0000-4000-8000-0000000000c0',
          title: 'Publish Lekki coastal demand draft',
          scheduledFor: now.add(const Duration(days: 3)),
          channel: 'blog',
          status: 'planned',
          ownerLabel: 'Editorial',
          notes: 'Human edit required — AI outline present',
        ),
        DxpCalendarItem(
          id: 'd4800000-0000-4000-8000-0000000000c1',
          title: 'WhatsApp brochure nurture send',
          scheduledFor: now.add(const Duration(days: 1)),
          channel: 'whatsapp',
          status: 'scheduled',
          ownerLabel: 'Marketing Ops',
        ),
      ];

  static List<DxpAbTest> _abTests() => const [
        DxpAbTest(
          id: 'd4800000-0000-4000-8000-0000000000b0',
          name: 'CTA copy — Book vs Reserve',
          hypothesis:
              '“Book inspection” will convert higher than “Reserve a tour”.',
          status: 'running',
          primaryMetric: 'conversion_rate',
          trafficSplit: 50,
        ),
      ];

  static List<DxpActivity> _activities(DateTime now) => [
        DxpActivity(
          id: 'd4800000-0000-4000-8000-0000000000f0',
          summary: 'Published Lekki Waterfront Launch landing page',
          action: 'landing.published',
          actorLabel: 'Marketing Ops',
          occurredAt: now.subtract(const Duration(days: 3)),
        ),
        DxpActivity(
          id: 'd4800000-0000-4000-8000-0000000000f1',
          summary: 'Sent Waterfront email wave 1',
          action: 'campaign.email.sent',
          actorLabel: 'System',
          occurredAt: now.subtract(const Duration(days: 2)),
        ),
        DxpActivity(
          id: 'd4800000-0000-4000-8000-0000000000f2',
          summary: 'New inspection request from Tunde Adebayo',
          action: 'form.submission',
          actorLabel: 'Public web',
          occurredAt: now.subtract(const Duration(hours: 6)),
        ),
      ];

  static List<DxpAlert> _alerts() => const [
        DxpAlert(
          id: 'd4800000-0000-4000-8000-0000000000f8',
          title: 'SEO watch — draft blog',
          body: 'Draft blog meta score is 58 — expand description before publish.',
          severity: 'warning',
          category: 'seo',
        ),
        DxpAlert(
          id: 'd4800000-0000-4000-8000-0000000000f9',
          title: 'Form spike',
          body: 'Two inspection submissions in the last day on waterfront LP.',
          severity: 'info',
          category: 'forms',
        ),
      ];

  static List<DxpAiInsight> _aiInsights() => const [
        DxpAiInsight(
          id: 'ai-1',
          title: 'Strengthen draft blog SEO',
          body:
              'Expand the meta description and add an OG image before publishing '
              '“Why Lekki still leads coastal demand”.',
          category: 'seo',
          confidencePct: 82,
          editable: true,
        ),
        DxpAiInsight(
          id: 'ai-2',
          title: 'CTA A/B still early',
          body:
              'Book vs Reserve test needs more samples — avoid declaring a winner '
              'until consideration volume rises.',
          category: 'experiments',
          confidencePct: 64,
          editable: true,
        ),
        DxpAiInsight(
          id: 'ai-3',
          title: 'WhatsApp nurture ready',
          body:
              'Schedule WhatsApp brochure send after SMS reminder wave to keep '
              'inspection pipeline warm.',
          category: 'campaigns',
          confidencePct: 74,
          editable: true,
        ),
      ];
}
