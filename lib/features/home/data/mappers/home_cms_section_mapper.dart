import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/home/data/models/home_cms_content.dart';

/// Default homepage render order — every key is CMS-controllable.
const kDefaultHomeSectionOrder = <String>[
  'homepage_hero',
  'homepage_search',
  'homepage_about',
  'homepage_why_choose',
  'homepage_featured_estates',
  'homepage_featured_properties',
  'homepage_testimonials',
  'homepage_partners',
  'homepage_trust',
  'homepage_awards',
  'homepage_content_hub',
  'homepage_cta',
  // Trust KPIs sit just above the closing band / public footer.
  'homepage_stats',
  'homepage_closing',
];

/// Public homepage always follows [kDefaultHomeSectionOrder].
/// Scrambled CMS sort values must never rearrange the page.
List<String> reconcileHomeSectionOrder(List<String> cmsOrder) {
  return List<String>.from(kDefaultHomeSectionOrder);
}

/// Overlays non-empty JSON from `cms_sections.content` onto fallback content.
HomeCmsContent mergeHomepageSectionContent({
  required HomeCmsContent base,
  required List<CmsSectionRecord> sections,
}) {
  if (sections.isEmpty) return base;

  final byKey = {for (final s in sections) s.sectionKey: s.content};
  var next = base;

  // Stats / partners / awards are managed via dedicated tables.
  final about = _parseAbout(byKey['homepage_about'], base.about);
  if (about != null) next = _copy(next, about: about);

  final why = _parseWhy(byKey['homepage_why_choose']);
  if (why != null) next = _copy(next, whyChoose: why);

  final lifestyles = _parseLifestyles(byKey['homepage_lifestyle'] ??
      byKey['homepage_lifestyles']);
  if (lifestyles != null) next = _copy(next, lifestyles: lifestyles);

  final investments = _parseInvestments(byKey['homepage_investments']);
  if (investments != null) next = _copy(next, investments: investments);

  // Partners & awards are managed via dedicated tables — never overwrite
  // from cms_sections JSON placeholders.
  final insights = _parseInsights(byKey['homepage_market_insights']);
  if (insights != null) next = _copy(next, marketInsights: insights);

  final events = _parseEvents(byKey['homepage_events']);
  if (events != null) next = _copy(next, events: events);

  final downloads = _parseDownloads(byKey['homepage_downloads']);
  if (downloads != null) next = _copy(next, downloads: downloads);

  final live = _parseLive(byKey['homepage_live_activity']);
  if (live != null) next = _copy(next, liveActivities: live);

  final exec = _parseExecutive(byKey['homepage_executive_welcome'], base.executiveWelcome);
  if (exec != null) next = _copy(next, executiveWelcome: exec);

  final cta = _parseCta(byKey['homepage_cta'] ?? byKey['homepage_closing']);
  if (cta != null) next = _copy(next, cta: cta);

  return next;
}

HomeCmsContent _copy(
  HomeCmsContent b, {
  List<HomeStatItem>? stats,
  HomeAboutContent? about,
  List<HomeWhyChooseItem>? whyChoose,
  List<HomeLifestyleItem>? lifestyles,
  List<HomeInvestmentItem>? investments,
  List<HomePartnerItem>? partners,
  List<HomeAwardItem>? awards,
  List<HomeMarketInsightItem>? marketInsights,
  List<HomeEventItem>? events,
  List<HomeDownloadItem>? downloads,
  List<HomeLiveActivityItem>? liveActivities,
  HomeExecutiveWelcome? executiveWelcome,
  HomeCtaContent? cta,
}) {
  return HomeCmsContent(
    announcement: b.announcement,
    hero: b.hero,
    stats: stats ?? b.stats,
    about: about ?? b.about,
    whyChoose: whyChoose ?? b.whyChoose,
    lifestyles: lifestyles ?? b.lifestyles,
    estates: b.estates,
    properties: b.properties,
    investments: investments ?? b.investments,
    testimonials: b.testimonials,
    partners: partners ?? b.partners,
    awards: awards ?? b.awards,
    blogPosts: b.blogPosts,
    marketInsights: marketInsights ?? b.marketInsights,
    events: events ?? b.events,
    faqs: b.faqs,
    downloads: downloads ?? b.downloads,
    liveActivities: liveActivities ?? b.liveActivities,
    executiveWelcome: executiveWelcome ?? b.executiveWelcome,
    cta: cta ?? b.cta,
    sectionVisibility: b.sectionVisibility,
    sectionOrder: b.sectionOrder,
  );
}

List<dynamic>? _items(Map<String, dynamic>? content) {
  if (content == null || content.isEmpty) return null;
  final raw = content['items'] ?? content['stats'] ?? content['list'];
  if (raw is! List || raw.isEmpty) return null;
  return raw;
}

List<HomeStatItem>? _parseStats(Map<String, dynamic>? content) {
  final items = _items(content);
  if (items == null) return null;
  return [
    for (final raw in items)
      if (raw is Map)
        HomeStatItem(
          value: _parseStatValue(raw['value']),
          label: '${raw['label'] ?? ''}',
          suffix: raw['suffix']?.toString(),
          caption: raw['caption']?.toString(),
          iconName: raw['iconName']?.toString() ?? raw['icon']?.toString(),
        ),
  ];
}

int _parseStatValue(Object? raw) {
  if (raw is num) return raw.toInt();
  if (raw is String) {
    final cleaned = raw.replaceAll(',', '').trim();
    return int.tryParse(cleaned) ?? double.tryParse(cleaned)?.round() ?? 0;
  }
  return 0;
}

HomeAboutContent? _parseAbout(
  Map<String, dynamic>? content,
  HomeAboutContent fallback,
) {
  if (content == null || content.isEmpty) return null;
  if (!_hasUsefulKeys(content, const [
    'title',
    'story',
    'mission',
    'vision',
    'values',
    'highlights',
    'titleAccent',
  ])) {
    return null;
  }

  final highlightsRaw = content['highlights'];
  final highlights = highlightsRaw is List && highlightsRaw.isNotEmpty
      ? [
          for (final raw in highlightsRaw)
            if (raw is Map)
              HomeAboutHighlight(
                title: '${raw['title'] ?? ''}',
                description: '${raw['description'] ?? ''}',
                iconName: '${raw['iconName'] ?? raw['icon'] ?? 'badge'}',
              ),
        ]
      : fallback.highlights;

  final valuesRaw = content['values'];
  final values = valuesRaw is List && valuesRaw.isNotEmpty
      ? valuesRaw.map((e) => '$e').toList()
      : fallback.values;

  return HomeAboutContent(
    title: (content['title'] as String?)?.trim().isNotEmpty == true
        ? content['title'] as String
        : fallback.title,
    titleAccent: content['titleAccent'] as String? ?? fallback.titleAccent,
    story: (content['story'] as String?)?.trim().isNotEmpty == true
        ? content['story'] as String
        : fallback.story,
    mission: (content['mission'] as String?)?.trim().isNotEmpty == true
        ? content['mission'] as String
        : fallback.mission,
    vision: (content['vision'] as String?)?.trim().isNotEmpty == true
        ? content['vision'] as String
        : fallback.vision,
    values: values,
    highlights: highlights,
    ctaLabel: content['ctaLabel'] as String? ??
        content['cta_label'] as String? ??
        fallback.ctaLabel,
    ctaPath: content['ctaPath'] as String? ??
        content['cta_path'] as String? ??
        fallback.ctaPath,
    backgroundImageUrl: content['backgroundImageUrl'] as String? ??
        content['background_image_url'] as String? ??
        fallback.backgroundImageUrl,
  );
}

List<HomeWhyChooseItem>? _parseWhy(Map<String, dynamic>? content) {
  final items = _items(content);
  if (items == null) return null;
  return [
    for (final raw in items)
      if (raw is Map)
        HomeWhyChooseItem(
          title: '${raw['title'] ?? ''}',
          description: '${raw['description'] ?? ''}',
          iconName: '${raw['iconName'] ?? raw['icon'] ?? 'shield'}',
        ),
  ];
}

List<HomeLifestyleItem>? _parseLifestyles(Map<String, dynamic>? content) {
  final items = _items(content);
  if (items == null) return null;
  return [
    for (final raw in items)
      if (raw is Map)
        HomeLifestyleItem(
          label: '${raw['label'] ?? raw['title'] ?? ''}',
          description: '${raw['description'] ?? ''}',
          route: '${raw['route'] ?? raw['path'] ?? RoutePaths.properties}',
        ),
  ];
}

List<HomeInvestmentItem>? _parseInvestments(Map<String, dynamic>? content) {
  final items = _items(content);
  if (items == null) return null;
  return [
    for (final raw in items)
      if (raw is Map)
        HomeInvestmentItem(
          title: '${raw['title'] ?? ''}',
          roi: '${raw['roi'] ?? ''}',
          type: '${raw['type'] ?? ''}',
          duration: '${raw['duration'] ?? ''}',
          risk: '${raw['risk'] ?? ''}',
          growth: '${raw['growth'] ?? ''}',
          route: '${raw['route'] ?? RoutePaths.investment}',
        ),
  ];
}

List<HomePartnerItem>? _parsePartners(Map<String, dynamic>? content) {
  final items = _items(content);
  if (items == null) return null;
  return [
    for (final raw in items)
      if (raw is Map)
        HomePartnerItem(
          name: '${raw['name'] ?? ''}',
          category: '${raw['category'] ?? 'Partner'}',
          tagline: '${raw['tagline'] ?? ''}',
          logoUrl: raw['logoUrl'] as String? ?? raw['logo_url'] as String?,
          iconName: '${raw['iconName'] ?? raw['icon_name'] ?? 'building'}',
        ),
  ];
}

List<HomeAwardItem>? _parseAwards(Map<String, dynamic>? content) {
  final items = _items(content);
  if (items == null) return null;
  return [
    for (final raw in items)
      if (raw is Map)
        HomeAwardItem(
          title: '${raw['title'] ?? ''}',
          year: '${raw['year'] ?? ''}',
          issuer: '${raw['issuer'] ?? ''}',
        ),
  ];
}

List<HomeMarketInsightItem>? _parseInsights(Map<String, dynamic>? content) {
  final items = _items(content);
  if (items == null) return null;
  return [
    for (final raw in items)
      if (raw is Map)
        HomeMarketInsightItem(
          title: '${raw['title'] ?? ''}',
          trend: '${raw['trend'] ?? ''}',
          change: '${raw['change'] ?? ''}',
          summary: '${raw['summary'] ?? raw['description'] ?? ''}',
        ),
  ];
}

List<HomeEventItem>? _parseEvents(Map<String, dynamic>? content) {
  final items = _items(content);
  if (items == null) return null;
  return [
    for (final raw in items)
      if (raw is Map)
        HomeEventItem(
          title: '${raw['title'] ?? ''}',
          date: '${raw['date'] ?? ''}',
          location: '${raw['location'] ?? ''}',
          type: '${raw['type'] ?? 'Event'}',
        ),
  ];
}

List<HomeDownloadItem>? _parseDownloads(Map<String, dynamic>? content) {
  final items = _items(content);
  if (items == null) return null;
  return [
    for (final raw in items)
      if (raw is Map)
        HomeDownloadItem(
          title: '${raw['title'] ?? ''}',
          fileType: '${raw['fileType'] ?? raw['file_type'] ?? 'PDF'}',
          url: '${raw['url'] ?? ''}',
        ),
  ];
}

List<HomeLiveActivityItem>? _parseLive(Map<String, dynamic>? content) {
  final items = _items(content);
  if (items == null) return null;
  return [
    for (final raw in items)
      if (raw is Map)
        HomeLiveActivityItem(
          message: '${raw['message'] ?? ''}',
          timeAgo: '${raw['timeAgo'] ?? raw['time_ago'] ?? ''}',
          type: '${raw['type'] ?? 'update'}',
        ),
  ];
}

HomeExecutiveWelcome? _parseExecutive(
  Map<String, dynamic>? content,
  HomeExecutiveWelcome fallback,
) {
  if (content == null || content.isEmpty) return null;
  if (!_hasUsefulKeys(content, const [
    'name',
    'message',
    'title',
    'videoUrl',
    'video_url',
  ])) {
    return null;
  }

  final rawVideo = content['videoUrl'] ?? content['video_url'];
  final video = rawVideo?.toString().trim();

  return HomeExecutiveWelcome(
    name: (content['name'] as String?)?.trim().isNotEmpty == true
        ? content['name'] as String
        : fallback.name,
    title: (content['title'] as String?)?.trim().isNotEmpty == true
        ? content['title'] as String
        : fallback.title,
    message: (content['message'] as String?)?.trim().isNotEmpty == true
        ? content['message'] as String
        : fallback.message,
    videoUrl: video == null || video.isEmpty ? null : video,
  );
}

HomeCtaContent? _parseCta(Map<String, dynamic>? content) {
  if (content == null || content.isEmpty) return null;
  final headline = content['headline'] as String? ?? content['title'] as String?;
  if (headline == null || headline.trim().isEmpty) return null;
  return HomeCtaContent(
    headline: headline.trim(),
    subheadline: content['subheadline'] as String? ??
        content['subtitle'] as String? ??
        'Book an inspection, request a callback, or speak with our team today.',
    primaryLabel: content['primaryCtaLabel'] as String? ??
        content['cta_label'] as String? ??
        content['primary_label'] as String? ??
        'Book Inspection',
    primaryPath: content['primaryCtaPath'] as String? ??
        content['cta_url'] as String? ??
        content['primary_path'] as String? ??
        RoutePaths.bookInspection,
    secondaryLabel: content['secondaryCtaLabel'] as String? ??
        content['secondary_label'] as String? ??
        'Contact Sales',
    secondaryPath: content['secondaryCtaPath'] as String? ??
        content['secondary_path'] as String? ??
        RoutePaths.contact,
  );
}

bool _hasUsefulKeys(Map<String, dynamic> content, List<String> keys) {
  for (final key in keys) {
    final v = content[key];
    if (v == null) continue;
    if (v is String && v.trim().isEmpty) continue;
    if (v is List && v.isEmpty) continue;
    return true;
  }
  return false;
}
