import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/command_palette_catalog.dart';

/// Search modes for the Global Command Center.
enum SearchMode {
  universal,
  properties,
  people,
  documents,
  reports,
  settings,
  commands;

  String get label => switch (this) {
        SearchMode.universal => 'Universal',
        SearchMode.properties => 'Properties',
        SearchMode.people => 'People',
        SearchMode.documents => 'Documents',
        SearchMode.reports => 'Reports',
        SearchMode.settings => 'Settings',
        SearchMode.commands => 'Commands',
      };

  String get slug => name;
}

enum SearchResultModule {
  property,
  estate,
  blog,
  service,
  user,
  staff,
  client,
  investor,
  lead,
  booking,
  document,
  investment,
  report,
  ticket,
  notification,
  audit,
  role,
  setting,
  command,
  workspace,
  faq,
  location;

  String get label => switch (this) {
        SearchResultModule.property => 'Properties',
        SearchResultModule.estate => 'Estates',
        SearchResultModule.blog => 'Blog',
        SearchResultModule.service => 'Services',
        SearchResultModule.user => 'Users',
        SearchResultModule.staff => 'Staff',
        SearchResultModule.client => 'Clients',
        SearchResultModule.investor => 'Investors',
        SearchResultModule.lead => 'Leads',
        SearchResultModule.booking => 'Bookings',
        SearchResultModule.document => 'Documents',
        SearchResultModule.investment => 'Investments',
        SearchResultModule.report => 'Reports',
        SearchResultModule.ticket => 'Support Tickets',
        SearchResultModule.notification => 'Notifications',
        SearchResultModule.audit => 'Audit Logs',
        SearchResultModule.role => 'Roles',
        SearchResultModule.setting => 'Settings',
        SearchResultModule.command => 'Commands',
        SearchResultModule.workspace => 'Workspaces',
        SearchResultModule.faq => 'FAQ',
        SearchResultModule.location => 'Locations',
      };

  String get slug => name;

  /// Permission slug required to see this module (null = public / any auth).
  String? get requiredPermission => switch (this) {
        SearchResultModule.property => null,
        SearchResultModule.estate => null,
        SearchResultModule.blog => null,
        SearchResultModule.service => null,
        SearchResultModule.faq => null,
        SearchResultModule.location => null,
        SearchResultModule.user => 'view_users',
        SearchResultModule.staff => 'view_users',
        SearchResultModule.client => 'manage_crm',
        SearchResultModule.investor => 'view_investments',
        SearchResultModule.lead => 'manage_crm',
        SearchResultModule.booking => 'manage_crm',
        SearchResultModule.document => 'view_properties',
        SearchResultModule.investment => 'view_investments',
        SearchResultModule.report => 'manage_reports',
        SearchResultModule.ticket => 'manage_tickets',
        SearchResultModule.notification => null,
        SearchResultModule.audit => 'view_audit_logs',
        SearchResultModule.role => 'manage_roles',
        SearchResultModule.setting => 'manage_roles',
        SearchResultModule.command => null,
        SearchResultModule.workspace => null,
      };

  static SearchResultModule fromSlug(String? raw) {
    return SearchResultModule.values.firstWhere(
      (e) => e.slug == (raw ?? ''),
      orElse: () => SearchResultModule.property,
    );
  }
}

class SearchIndexEntry {
  const SearchIndexEntry({
    required this.id,
    required this.module,
    required this.title,
    required this.path,
    this.subtitle,
    this.keywords = const [],
    this.permissionSlug,
    this.popularity = 0,
    this.preview = const {},
    this.relatedIds = const [],
  });

  final String id;
  final SearchResultModule module;
  final String title;
  final String path;
  final String? subtitle;
  final List<String> keywords;
  final String? permissionSlug;
  final int popularity;
  final Map<String, String> preview;
  final List<String> relatedIds;

  String get haystack =>
      [title, subtitle ?? '', ...keywords, module.label].join(' ').toLowerCase();
}

class SearchResultItem {
  const SearchResultItem({
    required this.entry,
    required this.score,
    this.matchedOn = 'title',
  });

  final SearchIndexEntry entry;
  final double score;
  final String matchedOn;

  String get title => entry.title;
  String get path => entry.path;
  SearchResultModule get module => entry.module;
}

class SearchResultGroup {
  const SearchResultGroup({
    required this.module,
    required this.items,
  });

  final SearchResultModule module;
  final List<SearchResultItem> items;

  String get label => '${module.label} (${items.length})';
}

class SearchSuggestion {
  const SearchSuggestion({
    required this.label,
    required this.query,
    this.kind = 'term',
  });

  final String label;
  final String query;
  final String kind;
}

class SearchHistoryItem {
  const SearchHistoryItem({
    required this.id,
    required this.query,
    this.mode = SearchMode.universal,
    this.createdAt,
  });

  final String id;
  final String query;
  final SearchMode mode;
  final DateTime? createdAt;
}

class FavoriteCommand {
  const FavoriteCommand({
    required this.id,
    required this.actionKey,
    required this.label,
    required this.path,
  });

  final String id;
  final String actionKey;
  final String label;
  final String path;
}

class SearchFilterState {
  const SearchFilterState({
    this.module,
    this.location,
    this.status,
    this.department,
    this.tags = const [],
  });

  final SearchResultModule? module;
  final String? location;
  final String? status;
  final String? department;
  final List<String> tags;

  SearchFilterState copyWith({
    SearchResultModule? module,
    String? location,
    String? status,
    String? department,
    List<String>? tags,
    bool clearModule = false,
  }) {
    return SearchFilterState(
      module: clearModule ? null : (module ?? this.module),
      location: location ?? this.location,
      status: status ?? this.status,
      department: department ?? this.department,
      tags: tags ?? this.tags,
    );
  }
}

class SearchQueryResult {
  const SearchQueryResult({
    required this.query,
    required this.mode,
    required this.groups,
    required this.suggestions,
    required this.commands,
    required this.related,
    required this.latencyMs,
    this.zeroResults = false,
    this.intent,
  });

  final String query;
  final SearchMode mode;
  final List<SearchResultGroup> groups;
  final List<SearchSuggestion> suggestions;
  final List<CommandPaletteAction> commands;
  final List<SearchResultItem> related;
  final int latencyMs;
  final bool zeroResults;
  final SemanticIntent? intent;

  int get totalCount =>
      groups.fold(0, (sum, g) => sum + g.items.length);
}

class SemanticIntent {
  const SemanticIntent({
    required this.raw,
    this.location,
    this.minBedrooms,
    this.maxPrice,
    this.status,
    this.entityHint,
  });

  final String raw;
  final String? location;
  final int? minBedrooms;
  final double? maxPrice;
  final String? status;
  final String? entityHint;
}

class SearchAnalyticsSnapshot {
  const SearchAnalyticsSnapshot({
    required this.topTerms,
    required this.zeroResultTerms,
    required this.popularCommands,
    required this.avgLatencyMs,
    required this.adoptionByDepartment,
  });

  final List<({String label, int count})> topTerms;
  final List<String> zeroResultTerms;
  final List<({String label, int count})> popularCommands;
  final double avgLatencyMs;
  final List<({String department, int searches})> adoptionByDepartment;
}

class EnterpriseSearchSnapshot {
  const EnterpriseSearchSnapshot({
    required this.history,
    required this.favoriteCommands,
    required this.analytics,
    required this.pinnedWorkspaces,
  });

  final List<SearchHistoryItem> history;
  final List<FavoriteCommand> favoriteCommands;
  final SearchAnalyticsSnapshot analytics;
  final List<SearchIndexEntry> pinnedWorkspaces;
}

/// Ranking + permission filtering + semantic foundation.
abstract final class SearchRankingEngine {
  static bool canView(
    SearchIndexEntry entry, {
    required Set<String> permissions,
    required bool isStaff,
    AppRole? role,
  }) {
    if (role == AppRole.superAdmin || role == AppRole.admin) return true;
    final required = entry.permissionSlug ?? entry.module.requiredPermission;
    if (required == null) return true;
    if (permissions.contains(required)) return true;
    // Soft staff allow for CRM-adjacent modules when manage_crm present.
    if (isStaff &&
        (required == 'manage_crm' || required == 'view_properties') &&
        permissions.contains('manage_crm')) {
      return true;
    }
    return false;
  }

  static double score(SearchIndexEntry entry, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return entry.popularity / 1000.0;
    final title = entry.title.toLowerCase();
    var s = 0.0;
    if (title == q) {
      s += 100;
    } else if (title.startsWith(q)) {
      s += 70;
    } else if (title.contains(q)) {
      s += 40;
    }
    for (final k in entry.keywords) {
      final kk = k.toLowerCase();
      if (kk == q) {
        s += 30;
      } else if (kk.contains(q) || q.contains(kk)) {
        s += 15;
      }
    }
    if (entry.subtitle?.toLowerCase().contains(q) == true) s += 10;
    s += entry.popularity * 0.05;
    // Synonym boost via SemanticSearchFoundation
    for (final syn in SemanticSearchFoundation.expand(q)) {
      if (syn == q) continue;
      if (title.contains(syn) || entry.haystack.contains(syn)) s += 8;
    }
    return s;
  }

  static List<SearchResultItem> rank(
    Iterable<SearchIndexEntry> entries,
    String query, {
    required Set<String> permissions,
    required bool isStaff,
    AppRole? role,
    SearchMode mode = SearchMode.universal,
    SearchFilterState filters = const SearchFilterState(),
  }) {
    final filtered = entries.where((e) {
      if (!canView(e, permissions: permissions, isStaff: isStaff, role: role)) {
        return false;
      }
      if (mode == SearchMode.commands) {
        return e.module == SearchResultModule.command;
      }
      if (mode == SearchMode.properties) {
        return e.module == SearchResultModule.property ||
            e.module == SearchResultModule.estate;
      }
      if (mode == SearchMode.people) {
        return {
          SearchResultModule.user,
          SearchResultModule.staff,
          SearchResultModule.client,
          SearchResultModule.investor,
          SearchResultModule.lead,
        }.contains(e.module);
      }
      if (mode == SearchMode.documents) {
        return e.module == SearchResultModule.document;
      }
      if (mode == SearchMode.reports) {
        return e.module == SearchResultModule.report;
      }
      if (mode == SearchMode.settings) {
        return e.module == SearchResultModule.setting ||
            e.module == SearchResultModule.role;
      }
      if (filters.module != null && e.module != filters.module) return false;
      if (filters.location != null &&
          filters.location!.isNotEmpty &&
          !e.haystack.contains(filters.location!.toLowerCase())) {
        return false;
      }
      if (filters.status != null &&
          filters.status!.isNotEmpty &&
          e.preview['status']?.toLowerCase() !=
              filters.status!.toLowerCase()) {
        return false;
      }
      return true;
    });

    final scored = <SearchResultItem>[
      for (final e in filtered)
        SearchResultItem(
          entry: e,
          score: score(e, query),
          matchedOn: e.title.toLowerCase().contains(query.toLowerCase())
              ? 'title'
              : 'keyword',
        ),
    ]..sort((a, b) => b.score.compareTo(a.score));

    if (query.trim().isEmpty) {
      return scored.take(40).toList();
    }
    return scored.where((r) => r.score > 0).take(50).toList();
  }

  static List<SearchResultGroup> group(List<SearchResultItem> items) {
    final map = <SearchResultModule, List<SearchResultItem>>{};
    for (final item in items) {
      map.putIfAbsent(item.module, () => []).add(item);
    }
    final order = SearchResultModule.values;
    return [
      for (final m in order)
        if (map[m]?.isNotEmpty == true)
          SearchResultGroup(module: m, items: map[m]!),
    ];
  }

  /// Cross-Module Smart Links — related records for a hit (permission-filtered).
  static List<SearchResultItem> relatedFor(
    SearchIndexEntry entry,
    Iterable<SearchIndexEntry> index, {
    required Set<String> permissions,
    required bool isStaff,
    AppRole? role,
  }) {
    if (entry.relatedIds.isEmpty) return const [];
    final byId = {for (final e in index) e.id: e};
    final out = <SearchResultItem>[];
    for (final rid in entry.relatedIds) {
      final related = byId[rid];
      if (related == null) continue;
      if (!canView(
        related,
        permissions: permissions,
        isStaff: isStaff,
        role: role,
      )) {
        continue;
      }
      out.add(
        SearchResultItem(entry: related, score: 1, matchedOn: 'related'),
      );
    }
    return out;
  }
}

/// Semantic Search Foundation — synonyms + lightweight NL intent parsing.
abstract final class SemanticSearchFoundation {
  static const synonyms = <String, List<String>>{
    'house': ['property', 'home', 'residence'],
    'property': ['house', 'home', 'listing'],
    'apartment': ['flat', 'unit'],
    'lekki': ['lekki phase 1', 'lekki gardens'],
    'investor': ['investment', 'portfolio'],
    'kyc': ['identity', 'verification', 'compliance'],
  };

  static Set<String> expand(String term) {
    final t = term.toLowerCase().trim();
    final out = <String>{t};
    for (final entry in synonyms.entries) {
      if (entry.key == t || entry.value.contains(t)) {
        out.add(entry.key);
        out.addAll(entry.value);
      }
    }
    return out;
  }

  /// Parses natural-language style queries for future AI wiring.
  static SemanticIntent parseIntent(String raw) {
    final q = raw.trim();
    final lower = q.toLowerCase();
    String? location;
    for (final loc in ['lekki', 'vi', 'victoria island', 'abuja', 'ikoyi', 'ajah']) {
      if (lower.contains(loc)) {
        location = loc;
        break;
      }
    }
    final bedsMatch = RegExp(r'(\d+)\s*-?\s*bed').firstMatch(lower);
    final priceMatch =
        RegExp(r'(?:under|below|<)\s*₦?\s*(\d+(?:\.\d+)?)\s*m').firstMatch(lower);
    String? status;
    if (lower.contains('available')) status = 'Available';
    if (lower.contains('awaiting') && lower.contains('kyc')) {
      return SemanticIntent(
        raw: q,
        entityHint: 'investor',
        status: 'awaiting_kyc',
        location: location,
      );
    }
    return SemanticIntent(
      raw: q,
      location: location,
      minBedrooms: bedsMatch != null ? int.tryParse(bedsMatch.group(1)!) : null,
      maxPrice: priceMatch != null
          ? (double.tryParse(priceMatch.group(1)!) ?? 0) * 1000000
          : null,
      status: status,
      entityHint: lower.contains('investor')
          ? 'investor'
          : lower.contains('client')
              ? 'client'
              : null,
    );
  }
}

/// Seed / demo search index spanning modules (permission-aware at query time).
abstract final class EnterpriseSearchCatalog {
  static List<SearchIndexEntry> seedIndex() => const [
        SearchIndexEntry(
          id: 'prop-lekki-pearl',
          module: SearchResultModule.property,
          title: 'Lekki Pearl Residence',
          subtitle: 'Lekki Phase 1 · ₦185M · Available',
          path: '/properties',
          keywords: ['lekki', 'phase 1', 'apartment', '4 bedroom'],
          popularity: 95,
          preview: {
            'price': '₦185M',
            'location': 'Lekki Phase 1',
            'status': 'Available',
            'agent': 'Ada Okoro',
          },
          relatedIds: ['staff-ada', 'booking-lekki-1', 'doc-brochure-1'],
        ),
        SearchIndexEntry(
          id: 'prop-lekki-gardens',
          module: SearchResultModule.property,
          title: 'Lekki Gardens Duplex',
          subtitle: 'Lekki · ₦220M · Available',
          path: '/properties',
          keywords: ['lekki gardens', 'duplex', '4 bedroom'],
          popularity: 80,
          preview: {
            'price': '₦220M',
            'location': 'Lekki',
            'status': 'Available',
          },
        ),
        SearchIndexEntry(
          id: 'estate-lekki',
          module: SearchResultModule.estate,
          title: 'Lekki Phase 1 Estate',
          subtitle: 'Premium waterfront community',
          path: '/estates',
          keywords: ['lekki', 'estate', 'phase 1'],
          popularity: 70,
        ),
        SearchIndexEntry(
          id: 'blog-lekki-guide',
          module: SearchResultModule.blog,
          title: 'Investing in Lekki Properties',
          subtitle: 'Market insights',
          path: '/blog',
          keywords: ['lekki', 'investment', 'guide'],
          popularity: 40,
        ),
        SearchIndexEntry(
          id: 'client-john',
          module: SearchResultModule.client,
          title: 'John Doe',
          subtitle: 'Client · Assigned lead',
          path: '/dashboard/clients',
          keywords: ['john', 'doe', 'client'],
          permissionSlug: 'manage_crm',
          popularity: 50,
          preview: {
            'contact': '+234 800 000 0001',
            'agent': 'Ada Okoro',
          },
          relatedIds: ['booking-lekki-1'],
        ),
        SearchIndexEntry(
          id: 'investor-rima',
          module: SearchResultModule.investor,
          title: 'Rima Okoro',
          subtitle: 'Investor · KYC awaiting approval',
          path: '/dashboard/investors',
          keywords: ['rima', 'investor', 'kyc'],
          permissionSlug: 'view_investments',
          popularity: 55,
          preview: {'status': 'awaiting_kyc'},
        ),
        SearchIndexEntry(
          id: 'staff-ada',
          module: SearchResultModule.staff,
          title: 'Ada Okoro',
          subtitle: 'Sales Executive · Lagos',
          path: '/dashboard/organization',
          keywords: ['ada', 'sales', 'staff'],
          permissionSlug: 'view_users',
          popularity: 45,
        ),
        SearchIndexEntry(
          id: 'booking-lekki-1',
          module: SearchResultModule.booking,
          title: 'Inspection — Lekki Pearl',
          subtitle: 'Tomorrow 10:00',
          path: '/client/inspections',
          keywords: ['inspection', 'booking', 'lekki'],
          permissionSlug: 'manage_crm',
          popularity: 30,
        ),
        SearchIndexEntry(
          id: 'doc-brochure-1',
          module: SearchResultModule.document,
          title: 'Lekki Pearl Brochure',
          subtitle: 'PDF · Marketing',
          path: '/dashboard/media',
          keywords: ['brochure', 'document', 'lekki'],
          permissionSlug: 'view_properties',
          popularity: 25,
        ),
        SearchIndexEntry(
          id: 'inv-plan-a',
          module: SearchResultModule.investment,
          title: 'Lekki Investment Plan A',
          subtitle: 'ROI 18% · Active',
          path: '/investor/portfolio',
          keywords: ['investment', 'lekki', 'roi'],
          permissionSlug: 'view_investments',
          popularity: 60,
        ),
        SearchIndexEntry(
          id: 'report-sales',
          module: SearchResultModule.report,
          title: 'Sales Summary — Today',
          subtitle: 'Executive report',
          path: '/dashboard/reports',
          keywords: ['sales', 'report', 'today'],
          permissionSlug: 'manage_reports',
          popularity: 65,
        ),
        SearchIndexEntry(
          id: 'ticket-1',
          module: SearchResultModule.ticket,
          title: 'High Priority Support Ticket',
          subtitle: 'Open · Payment inquiry',
          path: '/dashboard/crm',
          keywords: ['support', 'ticket', 'priority'],
          permissionSlug: 'manage_tickets',
          popularity: 20,
        ),
        SearchIndexEntry(
          id: 'role-sales',
          module: SearchResultModule.role,
          title: 'Sales Team Role',
          subtitle: 'Permissions matrix',
          path: '/dashboard/roles',
          keywords: ['role', 'rbac', 'sales'],
          permissionSlug: 'manage_roles',
          popularity: 15,
        ),
        SearchIndexEntry(
          id: 'setting-prefs',
          module: SearchResultModule.setting,
          title: 'Preference Center',
          subtitle: 'Theme, accessibility, favorites',
          path: '/account/preferences',
          keywords: ['settings', 'preferences', 'theme'],
          popularity: 35,
        ),
        SearchIndexEntry(
          id: 'audit-cmd',
          module: SearchResultModule.audit,
          title: 'Activity Command Center',
          subtitle: 'Audit logs & alerts',
          path: '/dashboard/activity-logs',
          keywords: ['audit', 'logs', 'health'],
          permissionSlug: 'view_audit_logs',
          popularity: 28,
        ),
        SearchIndexEntry(
          id: 'ws-sales',
          module: SearchResultModule.workspace,
          title: 'Sales Workspace',
          subtitle: 'Smart Workspace Builder™',
          path: '/account/preferences',
          keywords: ['workspace', 'dashboard', 'sales'],
          popularity: 40,
        ),
        SearchIndexEntry(
          id: 'svc-survey',
          module: SearchResultModule.service,
          title: 'Land Survey Services',
          subtitle: 'Professional services',
          path: '/services',
          keywords: ['survey', 'services'],
          popularity: 22,
        ),
        SearchIndexEntry(
          id: 'cmd-create-property',
          module: SearchResultModule.command,
          title: 'Create Property',
          subtitle: 'Quick action',
          path: '/dashboard/properties',
          keywords: ['add', 'new', 'property', 'create'],
          permissionSlug: 'edit_property',
          popularity: 90,
        ),
        SearchIndexEntry(
          id: 'cmd-approve-kyc',
          module: SearchResultModule.command,
          title: 'Approve KYC',
          subtitle: 'Compliance action',
          path: '/dashboard/compliance',
          keywords: ['kyc', 'approve', 'compliance'],
          permissionSlug: 'manage_roles',
          popularity: 50,
        ),
        SearchIndexEntry(
          id: 'cmd-book-inspection',
          module: SearchResultModule.command,
          title: 'Book Inspection',
          subtitle: 'Schedule visit',
          path: '/book-inspection',
          keywords: ['book', 'inspection', 'schedule'],
          popularity: 85,
        ),
        SearchIndexEntry(
          id: 'cmd-exec-sales',
          module: SearchResultModule.command,
          title: "View today's sales summary",
          subtitle: 'Executive Command Center™',
          path: '/dashboard/reports',
          keywords: ['executive', 'sales', 'today'],
          permissionSlug: 'manage_reports',
          popularity: 75,
        ),
        SearchIndexEntry(
          id: 'cmd-system-health',
          module: SearchResultModule.command,
          title: 'Open system health dashboard',
          subtitle: 'Executive Command Center™',
          path: '/dashboard/activity-logs',
          keywords: ['health', 'system', 'observability'],
          permissionSlug: 'view_audit_logs',
          popularity: 55,
        ),
      ];

  static List<CommandPaletteAction> allCommands() {
    final fromCatalog = CommandPaletteCatalog.actions;
    final fromIndex = seedIndex()
        .where((e) => e.module == SearchResultModule.command)
        .map(
          (e) => CommandPaletteAction(
            id: e.id,
            label: e.title,
            routeOrKey: e.path,
            keywords: e.keywords,
            requiredPermission: e.permissionSlug,
            category: 'action',
          ),
        );
    return [...fromCatalog, ...fromIndex];
  }

  static List<SearchSuggestion> suggest(String partial) {
    final p = partial.trim().toLowerCase();
    if (p.isEmpty) {
      return const [
        SearchSuggestion(label: 'Lekki Phase 1', query: 'Lekki Phase 1'),
        SearchSuggestion(label: 'Create Property', query: 'Create Property', kind: 'command'),
        SearchSuggestion(
          label: 'Saved Search: Lekki Luxury Homes',
          query: 'Lekki Luxury',
          kind: 'saved',
        ),
      ];
    }
    final candidates = <SearchSuggestion>[
      const SearchSuggestion(label: 'Lekki Phase 1', query: 'Lekki Phase 1'),
      const SearchSuggestion(label: 'Lekki Gardens', query: 'Lekki Gardens'),
      const SearchSuggestion(label: 'Lekki Properties', query: 'Lekki properties'),
      const SearchSuggestion(label: 'Lekki Investments', query: 'Lekki investments'),
      const SearchSuggestion(label: 'Lekki Clients', query: 'Lekki clients'),
      const SearchSuggestion(
        label: 'Saved Search: Lekki Luxury Homes',
        query: 'Lekki Luxury',
        kind: 'saved',
      ),
    ];
    return candidates
        .where((s) => s.label.toLowerCase().contains(p) || p.length >= 2)
        .take(6)
        .toList();
  }
}
