import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/profile_models.dart';

enum AppThemeMode {
  system,
  light,
  dark;

  String get slug => name;

  static AppThemeMode fromSlug(String? raw) {
    return switch ((raw ?? 'system').toLowerCase()) {
      'light' => AppThemeMode.light,
      'dark' => AppThemeMode.dark,
      _ => AppThemeMode.system,
    };
  }
}

enum UiDensity {
  compact,
  comfortable,
  spacious;

  String get slug => name;

  static UiDensity fromSlug(String? raw) {
    return switch ((raw ?? 'comfortable').toLowerCase()) {
      'compact' => UiDensity.compact,
      'spacious' => UiDensity.spacious,
      _ => UiDensity.comfortable,
    };
  }
}

enum AnimationLevel {
  full,
  reduced,
  none;

  String get slug => name;

  static AnimationLevel fromSlug(String? raw) {
    return switch ((raw ?? 'full').toLowerCase()) {
      'reduced' => AnimationLevel.reduced,
      'none' => AnimationLevel.none,
      _ => AnimationLevel.full,
    };
  }
}

enum FavoriteItemType {
  property,
  estate,
  blog,
  document,
  investment,
  report,
  staff,
  search;

  String get slug => name;

  static FavoriteItemType fromSlug(String? raw) {
    return FavoriteItemType.values.firstWhere(
      (e) => e.name == (raw ?? 'property').toLowerCase(),
      orElse: () => FavoriteItemType.property,
    );
  }
}

enum DashboardWidgetId {
  savedProperties,
  recentlyViewed,
  recommendations,
  upcomingBookings,
  messages,
  notifications,
  portfolioValue,
  roi,
  investmentPerformance,
  marketUpdates,
  financialReports,
  documents,
  assignedTasks,
  leads,
  calendar,
  teamActivity,
  performance,
  executiveKpis,
  sales,
  revenue,
  activeProjects,
  investorActivity,
  organizationHealth;

  String get slug => name;

  String get label => switch (this) {
        DashboardWidgetId.savedProperties => 'Saved Properties',
        DashboardWidgetId.recentlyViewed => 'Recently Viewed',
        DashboardWidgetId.recommendations => 'Recommendations',
        DashboardWidgetId.upcomingBookings => 'Upcoming Bookings',
        DashboardWidgetId.messages => 'Messages',
        DashboardWidgetId.notifications => 'Notifications',
        DashboardWidgetId.portfolioValue => 'Portfolio Value',
        DashboardWidgetId.roi => 'ROI',
        DashboardWidgetId.investmentPerformance => 'Investment Performance',
        DashboardWidgetId.marketUpdates => 'Market Updates',
        DashboardWidgetId.financialReports => 'Financial Reports',
        DashboardWidgetId.documents => 'Documents',
        DashboardWidgetId.assignedTasks => 'Assigned Tasks',
        DashboardWidgetId.leads => 'Leads',
        DashboardWidgetId.calendar => 'Calendar',
        DashboardWidgetId.teamActivity => 'Team Activity',
        DashboardWidgetId.performance => 'Performance',
        DashboardWidgetId.executiveKpis => 'Executive KPIs',
        DashboardWidgetId.sales => 'Sales',
        DashboardWidgetId.revenue => 'Revenue',
        DashboardWidgetId.activeProjects => 'Active Projects',
        DashboardWidgetId.investorActivity => 'Investor Activity',
        DashboardWidgetId.organizationHealth => 'Organization Health',
      };

  static DashboardWidgetId fromSlug(String? raw) {
    return DashboardWidgetId.values.firstWhere(
      (e) => e.slug == (raw ?? ''),
      orElse: () => DashboardWidgetId.notifications,
    );
  }
}

class AccessibilitySettings {
  const AccessibilitySettings({
    this.highContrast = false,
    this.reducedMotion = false,
    this.largerFonts = false,
    this.keyboardNavigation = true,
    this.screenReaderOptimized = false,
    this.focusHighlighting = true,
    this.fontScale = 1.0,
  });

  final bool highContrast;
  final bool reducedMotion;
  final bool largerFonts;
  final bool keyboardNavigation;
  final bool screenReaderOptimized;
  final bool focusHighlighting;
  final double fontScale;

  AccessibilitySettings copyWith({
    bool? highContrast,
    bool? reducedMotion,
    bool? largerFonts,
    bool? keyboardNavigation,
    bool? screenReaderOptimized,
    bool? focusHighlighting,
    double? fontScale,
  }) {
    return AccessibilitySettings(
      highContrast: highContrast ?? this.highContrast,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      largerFonts: largerFonts ?? this.largerFonts,
      keyboardNavigation: keyboardNavigation ?? this.keyboardNavigation,
      screenReaderOptimized:
          screenReaderOptimized ?? this.screenReaderOptimized,
      focusHighlighting: focusHighlighting ?? this.focusHighlighting,
      fontScale: fontScale ?? this.fontScale,
    );
  }

  Map<String, dynamic> toJson() => {
        'high_contrast': highContrast,
        'reduced_motion': reducedMotion,
        'larger_fonts': largerFonts,
        'keyboard_navigation': keyboardNavigation,
        'screen_reader_optimized': screenReaderOptimized,
        'focus_highlighting': focusHighlighting,
        'font_scale': fontScale,
      };

  factory AccessibilitySettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AccessibilitySettings();
    return AccessibilitySettings(
      highContrast: json['high_contrast'] as bool? ?? false,
      reducedMotion: json['reduced_motion'] as bool? ?? false,
      largerFonts: json['larger_fonts'] as bool? ?? false,
      keyboardNavigation: json['keyboard_navigation'] as bool? ?? true,
      screenReaderOptimized: json['screen_reader_optimized'] as bool? ?? false,
      focusHighlighting: json['focus_highlighting'] as bool? ?? true,
      fontScale: (json['font_scale'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class AppearancePreferences {
  const AppearancePreferences({
    this.theme = AppThemeMode.system,
    this.accentColor = 'gold',
    this.density = UiDensity.comfortable,
    this.animationLevel = AnimationLevel.full,
    this.cardStyle = 'elevated',
  });

  final AppThemeMode theme;
  final String accentColor;
  final UiDensity density;
  final AnimationLevel animationLevel;
  final String cardStyle;

  AppearancePreferences copyWith({
    AppThemeMode? theme,
    String? accentColor,
    UiDensity? density,
    AnimationLevel? animationLevel,
    String? cardStyle,
  }) {
    return AppearancePreferences(
      theme: theme ?? this.theme,
      accentColor: accentColor ?? this.accentColor,
      density: density ?? this.density,
      animationLevel: animationLevel ?? this.animationLevel,
      cardStyle: cardStyle ?? this.cardStyle,
    );
  }

  Map<String, dynamic> toJson() => {
        'theme': theme.slug,
        'accent_color': accentColor,
        'density': density.slug,
        'animation_level': animationLevel.slug,
        'card_style': cardStyle,
      };

  factory AppearancePreferences.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AppearancePreferences();
    return AppearancePreferences(
      theme: AppThemeMode.fromSlug(json['theme'] as String?),
      accentColor: json['accent_color'] as String? ?? 'gold',
      density: UiDensity.fromSlug(json['density'] as String?),
      animationLevel: AnimationLevel.fromSlug(json['animation_level'] as String?),
      cardStyle: json['card_style'] as String? ?? 'elevated',
    );
  }
}

class DashboardWidgetConfig {
  const DashboardWidgetConfig({
    required this.widgetId,
    this.visible = true,
    this.pinned = false,
    this.order = 0,
    this.width = 1,
    this.height = 1,
  });

  final DashboardWidgetId widgetId;
  final bool visible;
  final bool pinned;
  final int order;
  final int width;
  final int height;

  DashboardWidgetConfig copyWith({
    bool? visible,
    bool? pinned,
    int? order,
    int? width,
    int? height,
  }) {
    return DashboardWidgetConfig(
      widgetId: widgetId,
      visible: visible ?? this.visible,
      pinned: pinned ?? this.pinned,
      order: order ?? this.order,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  Map<String, dynamic> toJson() => {
        'widget_id': widgetId.slug,
        'visible': visible,
        'pinned': pinned,
        'order': order,
        'width': width,
        'height': height,
      };

  factory DashboardWidgetConfig.fromJson(Map<String, dynamic> json) {
    return DashboardWidgetConfig(
      widgetId: DashboardWidgetId.fromSlug(json['widget_id'] as String?),
      visible: json['visible'] as bool? ?? true,
      pinned: json['pinned'] as bool? ?? false,
      order: (json['order'] as num?)?.toInt() ?? 0,
      width: (json['width'] as num?)?.toInt() ?? 1,
      height: (json['height'] as num?)?.toInt() ?? 1,
    );
  }
}

class DashboardLayout {
  const DashboardLayout({
    required this.id,
    required this.name,
    required this.widgets,
    this.isDefault = false,
    this.workspaceSlug,
  });

  final String id;
  final String name;
  final List<DashboardWidgetConfig> widgets;
  final bool isDefault;
  final String? workspaceSlug;

  List<DashboardWidgetConfig> get visibleWidgets =>
      widgets.where((w) => w.visible).toList()
        ..sort((a, b) => a.order.compareTo(b.order));

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'is_default': isDefault,
        'workspace_slug': workspaceSlug,
        'widgets': widgets.map((w) => w.toJson()).toList(),
      };

  factory DashboardLayout.fromJson(Map<String, dynamic> json) {
    final rawWidgets = (json['widgets'] as List?) ?? const [];
    return DashboardLayout(
      id: json['id'] as String? ?? 'default',
      name: json['name'] as String? ?? 'Default',
      isDefault: json['is_default'] as bool? ?? false,
      workspaceSlug: json['workspace_slug'] as String?,
      widgets: rawWidgets
          .map((e) => DashboardWidgetConfig.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList(),
    );
  }
}

class FavoriteItem {
  const FavoriteItem({
    required this.id,
    required this.type,
    required this.entityId,
    required this.title,
    this.subtitle,
    this.createdAt,
  });

  final String id;
  final FavoriteItemType type;
  final String entityId;
  final String title;
  final String? subtitle;
  final DateTime? createdAt;

  factory FavoriteItem.fromRow(Map<String, dynamic> row) {
    return FavoriteItem(
      id: row['id'] as String,
      type: FavoriteItemType.fromSlug(row['item_type'] as String?),
      entityId: row['entity_id'] as String? ?? '',
      title: row['title'] as String? ?? 'Favorite',
      subtitle: row['subtitle'] as String?,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String).toUtc()
          : null,
    );
  }
}

class SavedSearch {
  const SavedSearch({
    required this.id,
    required this.name,
    required this.criteria,
    this.alertsEnabled = false,
    this.createdAt,
  });

  final String id;
  final String name;
  final Map<String, dynamic> criteria;
  final bool alertsEnabled;
  final DateTime? createdAt;

  String get summary {
    final loc = criteria['location'] ?? criteria['city'];
    final price = criteria['price_range'] ?? criteria['price'];
    final beds = criteria['bedrooms'];
    return [
      if (loc != null) '$loc',
      if (price != null) '$price',
      if (beds != null) '$beds+ beds',
    ].join(' · ');
  }

  factory SavedSearch.fromRow(Map<String, dynamic> row) {
    return SavedSearch(
      id: row['id'] as String,
      name: row['name'] as String? ?? 'Saved search',
      criteria: Map<String, dynamic>.from(
        (row['criteria'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      alertsEnabled: row['alerts_enabled'] as bool? ?? false,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String).toUtc()
          : null,
    );
  }
}

class RecentActivityItem {
  const RecentActivityItem({
    required this.id,
    required this.activityType,
    required this.title,
    this.entityType,
    this.entityId,
    this.createdAt,
  });

  final String id;
  final String activityType;
  final String title;
  final String? entityType;
  final String? entityId;
  final DateTime? createdAt;

  factory RecentActivityItem.fromRow(Map<String, dynamic> row) {
    return RecentActivityItem(
      id: row['id'] as String,
      activityType: row['activity_type'] as String? ?? 'view',
      title: row['title'] as String? ?? 'Activity',
      entityType: row['entity_type'] as String?,
      entityId: row['entity_id'] as String?,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String).toUtc()
          : null,
    );
  }
}

class UserShortcut {
  const UserShortcut({
    required this.id,
    required this.label,
    required this.actionKey,
    this.order = 0,
  });

  final String id;
  final String label;
  final String actionKey;
  final int order;

  factory UserShortcut.fromRow(Map<String, dynamic> row) {
    return UserShortcut(
      id: row['id'] as String,
      label: row['label'] as String? ?? 'Action',
      actionKey: row['action_key'] as String? ?? '',
      order: (row['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class PropertyInterestProfile {
  const PropertyInterestProfile({
    this.propertyTypes = const [],
    this.cities = const [],
    this.estates = const [],
    this.minPrice,
    this.maxPrice,
    this.minBedrooms,
    this.amenities = const [],
    this.investmentTypes = const [],
  });

  final List<String> propertyTypes;
  final List<String> cities;
  final List<String> estates;
  final double? minPrice;
  final double? maxPrice;
  final int? minBedrooms;
  final List<String> amenities;
  final List<String> investmentTypes;

  Map<String, dynamic> toJson() => {
        'property_types': propertyTypes,
        'cities': cities,
        'estates': estates,
        'min_price': minPrice,
        'max_price': maxPrice,
        'min_bedrooms': minBedrooms,
        'amenities': amenities,
        'investment_types': investmentTypes,
      };

  factory PropertyInterestProfile.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PropertyInterestProfile();
    List<String> list(dynamic v) =>
        (v as List?)?.map((e) => e.toString()).toList() ?? const [];
    return PropertyInterestProfile(
      propertyTypes: list(json['property_types']),
      cities: list(json['cities']),
      estates: list(json['estates']),
      minPrice: (json['min_price'] as num?)?.toDouble(),
      maxPrice: (json['max_price'] as num?)?.toDouble(),
      minBedrooms: (json['min_bedrooms'] as num?)?.toInt(),
      amenities: list(json['amenities']),
      investmentTypes: list(json['investment_types']),
    );
  }
}

class AdaptiveSuggestion {
  const AdaptiveSuggestion({
    required this.id,
    required this.message,
    required this.actionKey,
  });

  final String id;
  final String message;
  final String actionKey;
}

class WelcomeGreeting {
  const WelcomeGreeting({
    required this.salutation,
    required this.displayName,
    required this.highlights,
  });

  final String salutation;
  final String displayName;
  final List<String> highlights;
}

class PersonalizationSnapshot {
  const PersonalizationSnapshot({
    required this.appPreferences,
    required this.appearance,
    required this.accessibility,
    required this.layout,
    required this.workspaces,
    required this.favorites,
    required this.savedSearches,
    required this.recentActivity,
    required this.shortcuts,
    required this.interests,
    required this.greeting,
    required this.suggestions,
    required this.recommendations,
  });

  final UserAppPreferences appPreferences;
  final AppearancePreferences appearance;
  final AccessibilitySettings accessibility;
  final DashboardLayout layout;
  final List<DashboardLayout> workspaces;
  final List<FavoriteItem> favorites;
  final List<SavedSearch> savedSearches;
  final List<RecentActivityItem> recentActivity;
  final List<UserShortcut> shortcuts;
  final PropertyInterestProfile interests;
  final WelcomeGreeting greeting;
  final List<AdaptiveSuggestion> suggestions;
  final List<String> recommendations;
}

/// Preference Engine — role templates, greetings, adaptive suggestions.
abstract final class PreferenceEngine {
  static List<DashboardWidgetConfig> defaultWidgetsForRole(AppRole? role) {
    final ids = switch (role) {
      AppRole.investor => const [
          DashboardWidgetId.portfolioValue,
          DashboardWidgetId.roi,
          DashboardWidgetId.investmentPerformance,
          DashboardWidgetId.marketUpdates,
          DashboardWidgetId.financialReports,
          DashboardWidgetId.documents,
          DashboardWidgetId.notifications,
        ],
      AppRole.superAdmin || AppRole.admin => const [
          DashboardWidgetId.executiveKpis,
          DashboardWidgetId.sales,
          DashboardWidgetId.revenue,
          DashboardWidgetId.activeProjects,
          DashboardWidgetId.investorActivity,
          DashboardWidgetId.organizationHealth,
          DashboardWidgetId.notifications,
        ],
      AppRole.salesTeam ||
      AppRole.finance ||
      AppRole.marketing ||
      AppRole.constructionManager =>
        const [
          DashboardWidgetId.assignedTasks,
          DashboardWidgetId.leads,
          DashboardWidgetId.calendar,
          DashboardWidgetId.notifications,
          DashboardWidgetId.teamActivity,
          DashboardWidgetId.performance,
        ],
      _ => const [
          DashboardWidgetId.savedProperties,
          DashboardWidgetId.recentlyViewed,
          DashboardWidgetId.recommendations,
          DashboardWidgetId.upcomingBookings,
          DashboardWidgetId.messages,
          DashboardWidgetId.notifications,
        ],
    };
    return [
      for (var i = 0; i < ids.length; i++)
        DashboardWidgetConfig(widgetId: ids[i], order: i, visible: true),
    ];
  }

  static DashboardLayout defaultLayoutForRole(AppRole? role) {
    final name = switch (role) {
      AppRole.investor => 'Investor Dashboard',
      AppRole.superAdmin || AppRole.admin => 'Executive Dashboard',
      AppRole.salesTeam => 'Sales Workspace',
      AppRole.marketing => 'Marketing Workspace',
      AppRole.finance => 'Finance Workspace',
      _ => 'My Dashboard',
    };
    return DashboardLayout(
      id: 'default-${role?.slug ?? 'client'}',
      name: name,
      isDefault: true,
      widgets: defaultWidgetsForRole(role),
    );
  }

  static WelcomeGreeting buildGreeting({
    required String displayName,
    required DateTime now,
    int newMatches = 0,
    int unreadMessages = 0,
    int upcomingInspections = 0,
  }) {
    final hour = now.hour;
    final salutation = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final first = displayName.trim().split(RegExp(r'\s+')).first;
    final highlights = <String>[
      if (newMatches > 0) '$newMatches new property matches',
      if (unreadMessages > 0) '$unreadMessages unread messages',
      if (upcomingInspections > 0) '$upcomingInspections upcoming inspection(s)',
    ];
    if (highlights.isEmpty) {
      highlights.add('Welcome back — your workspace is ready.');
    }
    return WelcomeGreeting(
      salutation: salutation,
      displayName: first.isEmpty ? 'there' : first,
      highlights: highlights,
    );
  }

  static List<AdaptiveSuggestion> suggestFromBehavior({
    required int investmentReportViews,
    required int lekkiSearches,
    required int unusedWidgetDays,
  }) {
    final out = <AdaptiveSuggestion>[];
    if (investmentReportViews >= 5) {
      out.add(
        const AdaptiveSuggestion(
          id: 'qa-investment-reports',
          message:
              'You frequently access Investment Reports. Add it to your Quick Actions?',
          actionKey: 'add_shortcut_investment_reports',
        ),
      );
    }
    if (lekkiSearches >= 3) {
      out.add(
        const AdaptiveSuggestion(
          id: 'save-lekki-search',
          message:
              'You often search for Lekki properties. Save this as a favorite search?',
          actionKey: 'save_search_lekki',
        ),
      );
    }
    if (unusedWidgetDays >= 60) {
      out.add(
        const AdaptiveSuggestion(
          id: 'hide-stale-widget',
          message:
              "You haven't used this widget in 60 days. Hide it?",
          actionKey: 'hide_stale_widget',
        ),
      );
    }
    return out;
  }

  static List<String> recommendProperties(PropertyInterestProfile interests) {
    final city = interests.cities.isNotEmpty ? interests.cities.first : 'Lagos';
    final type =
        interests.propertyTypes.isNotEmpty ? interests.propertyTypes.first : 'apartment';
    return [
      'Featured $type in $city',
      if (interests.minBedrooms != null)
        '${interests.minBedrooms}+ bedroom homes near you',
      'New listings matching your saved searches',
    ];
  }

  static DashboardLayout toggleWidgetVisibility(
    DashboardLayout layout,
    DashboardWidgetId id,
  ) {
    return DashboardLayout(
      id: layout.id,
      name: layout.name,
      isDefault: layout.isDefault,
      workspaceSlug: layout.workspaceSlug,
      widgets: [
        for (final w in layout.widgets)
          if (w.widgetId == id) w.copyWith(visible: !w.visible) else w,
      ],
    );
  }

  static DashboardLayout reorderWidget(
    DashboardLayout layout,
    DashboardWidgetId id,
    int newOrder,
  ) {
    final widgets = [...layout.widgets];
    final idx = widgets.indexWhere((w) => w.widgetId == id);
    if (idx < 0) return layout;
    final item = widgets.removeAt(idx);
    final clamped = newOrder.clamp(0, widgets.length);
    widgets.insert(clamped, item.copyWith(order: clamped));
    return DashboardLayout(
      id: layout.id,
      name: layout.name,
      isDefault: layout.isDefault,
      workspaceSlug: layout.workspaceSlug,
      widgets: [
        for (var i = 0; i < widgets.length; i++)
          widgets[i].copyWith(order: i),
      ],
    );
  }

  /// Demo anonymized metrics for Executive Personalization Analytics.
  static List<({String label, String value})> executiveAnalyticsDemo() {
    return const [
      (label: 'Most-used theme', value: 'System / Light'),
      (label: 'Top dashboard widget', value: 'Saved Properties'),
      (label: 'Accessibility adoption', value: '12%'),
      (label: 'Saved searches / week', value: '184'),
      (label: 'Workspace switches / day', value: '46'),
      (label: 'Favorite property category', value: 'Apartments · Lagos'),
    ];
  }
}
