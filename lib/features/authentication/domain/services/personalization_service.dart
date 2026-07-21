import 'dart:async';

import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/observability_models.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/personalization_models.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/profile_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/audit_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized Preference / Personalization Engine service.
class PersonalizationService {
  PersonalizationService({
    required AuditService audit,
    SupabaseClient? client,
  })  : _audit = audit,
        _client = client;

  final AuditService _audit;
  final SupabaseClient? _client;

  final Map<String, PersonalizationSnapshot> _local = {};

  bool get isConfigured => _client != null;

  Future<PersonalizationSnapshot> load(
    String userId, {
    AppRole? role,
    String? displayName,
  }) async {
    if (_local.containsKey(userId) && _client == null) {
      return _local[userId]!;
    }

    final appPrefs = await _loadAppPreferences(userId);
    final appearance = await _loadAppearance(userId, appPrefs);
    final accessibility = await _loadAccessibility(userId);
    final layout = await _loadLayout(userId, role);
    final workspaces = await _loadWorkspaces(userId, role);
    final favorites = await listFavorites(userId);
    final searches = await listSavedSearches(userId);
    final recent = await listRecentActivity(userId);
    final shortcuts = await listShortcuts(userId);
    final interests = await _loadInterests(userId);
    final greeting = PreferenceEngine.buildGreeting(
      displayName: displayName ?? 'there',
      now: DateTime.now(),
      newMatches: searches.length,
      unreadMessages: 0,
      upcomingInspections: 0,
    );
    final suggestions = PreferenceEngine.suggestFromBehavior(
      investmentReportViews: recent
          .where((r) => r.activityType.contains('report'))
          .length,
      lekkiSearches: searches
          .where((s) => s.summary.toLowerCase().contains('lekki'))
          .length,
      unusedWidgetDays: 0,
    );
    final recommendations =
        PreferenceEngine.recommendProperties(interests);

    final snap = PersonalizationSnapshot(
      appPreferences: appPrefs,
      appearance: appearance,
      accessibility: accessibility,
      layout: layout,
      workspaces: workspaces,
      favorites: favorites,
      savedSearches: searches,
      recentActivity: recent,
      shortcuts: shortcuts,
      interests: interests,
      greeting: greeting,
      suggestions: suggestions,
      recommendations: recommendations,
    );
    _local[userId] = snap;
    return snap;
  }

  Future<AppearancePreferences> saveAppearance(
    String userId,
    AppearancePreferences appearance,
  ) async {
    await _upsertPreferenceBucket(userId, 'appearance', appearance.toJson());
    await _mirrorTheme(userId, appearance.theme.slug);
    await _auditPref(userId, 'appearance_updated', appearance.toJson());
    return appearance;
  }

  Future<AccessibilitySettings> saveAccessibility(
    String userId,
    AccessibilitySettings settings,
  ) async {
    final client = _client;
    if (client == null) {
      _patchLocal(userId, accessibility: settings);
      return settings;
    }
    try {
      await client.from('accessibility_settings').upsert({
        'user_id': userId,
        ...settings.toJson(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {
      await _upsertPreferenceBucket(
        userId,
        'accessibility',
        settings.toJson(),
      );
    }
    await _auditPref(userId, 'accessibility_updated', settings.toJson());
    return settings;
  }

  Future<DashboardLayout> saveLayout(
    String userId,
    DashboardLayout layout,
  ) async {
    final client = _client;
    if (client == null) {
      _patchLocal(userId, layout: layout);
      return layout;
    }
    try {
      await client.from('dashboard_layouts').upsert({
        'id': layout.id,
        'user_id': userId,
        'name': layout.name,
        'is_default': layout.isDefault,
        'workspace_slug': layout.workspaceSlug,
        'widgets': layout.widgets.map((w) => w.toJson()).toList(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {
      await _upsertPreferenceBucket(userId, 'dashboard_layout', layout.toJson());
    }
    await _auditPref(userId, 'dashboard_layout_updated', {
      'layout': layout.name,
      'widgets': layout.widgets.length,
    });
    return layout;
  }

  Future<FavoriteItem> addFavorite({
    required String userId,
    required FavoriteItemType type,
    required String entityId,
    required String title,
    String? subtitle,
  }) async {
    final client = _client;
    if (client == null) {
      final item = FavoriteItem(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        type: type,
        entityId: entityId,
        title: title,
        subtitle: subtitle,
        createdAt: DateTime.now().toUtc(),
      );
      final snap = _local[userId];
      if (snap != null) {
        _local[userId] = PersonalizationSnapshot(
          appPreferences: snap.appPreferences,
          appearance: snap.appearance,
          accessibility: snap.accessibility,
          layout: snap.layout,
          workspaces: snap.workspaces,
          favorites: [...snap.favorites, item],
          savedSearches: snap.savedSearches,
          recentActivity: snap.recentActivity,
          shortcuts: snap.shortcuts,
          interests: snap.interests,
          greeting: snap.greeting,
          suggestions: snap.suggestions,
          recommendations: snap.recommendations,
        );
      }
      return item;
    }

    final row = await client.from('favorite_items').insert({
      'user_id': userId,
      'item_type': type.slug,
      'entity_id': entityId,
      'title': title,
      'subtitle': subtitle,
    }).select().single();
    await _auditPref(userId, 'favorite_added', {
      'type': type.slug,
      'entity_id': entityId,
    });
    return FavoriteItem.fromRow(Map<String, dynamic>.from(row));
  }

  Future<void> removeFavorite(String userId, String favoriteId) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from('favorite_items').delete().eq('id', favoriteId);
      await _auditPref(userId, 'favorite_removed', {'id': favoriteId});
    } catch (_) {}
  }

  Future<List<FavoriteItem>> listFavorites(String userId) async {
    final client = _client;
    if (client == null) {
      return _local[userId]?.favorites ??
          const [
            FavoriteItem(
              id: 'demo-1',
              type: FavoriteItemType.property,
              entityId: 'prop-1',
              title: 'Ocean View Residence',
              subtitle: 'Victoria Island · ₦185M',
            ),
          ];
    }
    try {
      final rows = await client
          .from('favorite_items')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);
      return (rows as List)
          .map((e) => FavoriteItem.fromRow(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<SavedSearch> saveSearch({
    required String userId,
    required String name,
    required Map<String, dynamic> criteria,
    bool alertsEnabled = false,
  }) async {
    final client = _client;
    if (client == null) {
      return SavedSearch(
        id: 'local-search',
        name: name,
        criteria: criteria,
        alertsEnabled: alertsEnabled,
        createdAt: DateTime.now().toUtc(),
      );
    }
    final row = await client.from('saved_searches').insert({
      'user_id': userId,
      'name': name,
      'criteria': criteria,
      'alerts_enabled': alertsEnabled,
    }).select().single();
    await _auditPref(userId, 'saved_search_created', {'name': name});
    return SavedSearch.fromRow(Map<String, dynamic>.from(row));
  }

  Future<List<SavedSearch>> listSavedSearches(String userId) async {
    final client = _client;
    if (client == null) {
      return const [
        SavedSearch(
          id: 'demo-search',
          name: 'Luxury Apartments',
          criteria: {
            'location': 'Lagos',
            'price_range': '₦150M–₦250M',
            'bedrooms': 4,
            'status': 'Ready to Move',
          },
          alertsEnabled: true,
        ),
      ];
    }
    try {
      final rows = await client
          .from('saved_searches')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((e) => SavedSearch.fromRow(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<RecentActivityItem>> listRecentActivity(String userId) async {
    final client = _client;
    if (client == null) {
      return [
        RecentActivityItem(
          id: 'r1',
          activityType: 'property_view',
          title: 'Viewed Lekki Pearl Estate',
          createdAt: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
        ),
        RecentActivityItem(
          id: 'r2',
          activityType: 'search',
          title: 'Searched 4-bed apartments in Lagos',
          createdAt: DateTime.now().toUtc().subtract(const Duration(days: 1)),
        ),
      ];
    }
    try {
      final rows = await client
          .from('personalization_recent_activity')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(30);
      return (rows as List)
          .map(
            (e) =>
                RecentActivityItem.fromRow(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<UserShortcut>> listShortcuts(String userId) async {
    final client = _client;
    if (client == null) {
      return const [
        UserShortcut(
          id: 's1',
          label: 'Book Inspection',
          actionKey: 'book_inspection',
          order: 0,
        ),
        UserShortcut(
          id: 's2',
          label: 'Contact Support',
          actionKey: 'contact_support',
          order: 1,
        ),
      ];
    }
    try {
      final rows = await client
          .from('user_shortcuts')
          .select()
          .eq('user_id', userId)
          .order('sort_order');
      return (rows as List)
          .map((e) => UserShortcut.fromRow(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<PropertyInterestProfile> saveInterests(
    String userId,
    PropertyInterestProfile interests,
  ) async {
    await _upsertPreferenceBucket(userId, 'property_interests', interests.toJson());
    await _auditPref(userId, 'interests_updated', interests.toJson());
    return interests;
  }

  Future<UserAppPreferences> saveLocalization(
    String userId,
    UserAppPreferences prefs,
  ) async {
    final client = _client;
    if (client == null) return prefs;
    try {
      await client.from('user_preferences').upsert(prefs.toUpsertMap(userId));
    } catch (_) {}
    await _auditPref(userId, 'localization_updated', {
      'locale': prefs.locale,
      'currency': prefs.currency,
      'timezone': prefs.timezone,
    });
    return prefs;
  }

  RealtimeChannel? subscribe(String userId, void Function() onChange) {
    final client = _client;
    if (client == null) return null;
    final channel = client.channel('personalization-$userId');
    for (final table in [
      'user_preferences',
      'dashboard_layouts',
      'favorite_items',
      'saved_searches',
      'accessibility_settings',
    ]) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => onChange(),
      );
    }
    channel.subscribe();
    return channel;
  }

  Future<UserAppPreferences> _loadAppPreferences(String userId) async {
    final client = _client;
    if (client == null) return const UserAppPreferences();
    try {
      final row = await client
          .from('user_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      return UserAppPreferences.fromJson(row);
    } catch (_) {
      return const UserAppPreferences();
    }
  }

  Future<AppearancePreferences> _loadAppearance(
    String userId,
    UserAppPreferences app,
  ) async {
    final bucket = await _readPreferenceBucket(userId, 'appearance');
    if (bucket != null) return AppearancePreferences.fromJson(bucket);
    return AppearancePreferences(theme: AppThemeMode.fromSlug(app.theme));
  }

  Future<AccessibilitySettings> _loadAccessibility(String userId) async {
    final client = _client;
    if (client != null) {
      try {
        final row = await client
            .from('accessibility_settings')
            .select()
            .eq('user_id', userId)
            .maybeSingle();
        if (row != null) {
          return AccessibilitySettings.fromJson(
            Map<String, dynamic>.from(row),
          );
        }
      } catch (_) {}
    }
    final bucket = await _readPreferenceBucket(userId, 'accessibility');
    return AccessibilitySettings.fromJson(bucket);
  }

  Future<DashboardLayout> _loadLayout(String userId, AppRole? role) async {
    final client = _client;
    if (client != null) {
      try {
        final row = await client
            .from('dashboard_layouts')
            .select()
            .eq('user_id', userId)
            .eq('is_default', true)
            .maybeSingle();
        if (row != null) {
          return DashboardLayout.fromJson(Map<String, dynamic>.from(row));
        }
      } catch (_) {}
    }
    final bucket = await _readPreferenceBucket(userId, 'dashboard_layout');
    if (bucket != null) return DashboardLayout.fromJson(bucket);
    return PreferenceEngine.defaultLayoutForRole(role);
  }

  Future<List<DashboardLayout>> _loadWorkspaces(
    String userId,
    AppRole? role,
  ) async {
    final defaults = [
      PreferenceEngine.defaultLayoutForRole(role),
      DashboardLayout(
        id: 'workspace-investor-analysis',
        name: 'Investor Analysis',
        workspaceSlug: 'investor_analysis',
        widgets: PreferenceEngine.defaultWidgetsForRole(AppRole.investor),
      ),
      DashboardLayout(
        id: 'workspace-sales',
        name: 'Sales Workspace',
        workspaceSlug: 'sales',
        widgets: PreferenceEngine.defaultWidgetsForRole(AppRole.salesTeam),
      ),
    ];
    final client = _client;
    if (client == null) return defaults;
    try {
      final rows = await client
          .from('dashboard_layouts')
          .select()
          .eq('user_id', userId)
          .order('name');
      final list = (rows as List)
          .map((e) => DashboardLayout.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return list.isEmpty ? defaults : list;
    } catch (_) {
      return defaults;
    }
  }

  Future<PropertyInterestProfile> _loadInterests(String userId) async {
    final bucket = await _readPreferenceBucket(userId, 'property_interests');
    return PropertyInterestProfile.fromJson(bucket);
  }

  Future<Map<String, dynamic>?> _readPreferenceBucket(
    String userId,
    String key,
  ) async {
    final client = _client;
    if (client == null) return null;
    try {
      final row = await client
          .from('user_preferences')
          .select('extras')
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return null;
      final extras = Map<String, dynamic>.from(
        (row['extras'] as Map?)?.cast<String, dynamic>() ?? {},
      );
      final value = extras[key];
      if (value is Map) return Map<String, dynamic>.from(value);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _upsertPreferenceBucket(
    String userId,
    String key,
    Map<String, dynamic> value,
  ) async {
    final client = _client;
    if (client == null) return;
    try {
      final existing = await client
          .from('user_preferences')
          .select('extras')
          .eq('user_id', userId)
          .maybeSingle();
      final extras = Map<String, dynamic>.from(
        (existing?['extras'] as Map?)?.cast<String, dynamic>() ?? {},
      );
      extras[key] = value;
      await client.from('user_preferences').upsert({
        'user_id': userId,
        'extras': extras,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  Future<void> _mirrorTheme(String userId, String theme) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from('user_preferences').upsert({
        'user_id': userId,
        'theme': theme,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  void _patchLocal(
    String userId, {
    AccessibilitySettings? accessibility,
    DashboardLayout? layout,
  }) {
    final snap = _local[userId];
    if (snap == null) return;
    _local[userId] = PersonalizationSnapshot(
      appPreferences: snap.appPreferences,
      appearance: snap.appearance,
      accessibility: accessibility ?? snap.accessibility,
      layout: layout ?? snap.layout,
      workspaces: snap.workspaces,
      favorites: snap.favorites,
      savedSearches: snap.savedSearches,
      recentActivity: snap.recentActivity,
      shortcuts: snap.shortcuts,
      interests: snap.interests,
      greeting: snap.greeting,
      suggestions: snap.suggestions,
      recommendations: snap.recommendations,
    );
  }

  Future<void> _auditPref(
    String userId,
    String action,
    Map<String, dynamic> metadata,
  ) async {
    unawaited(
      _audit.publish(
        AuditPublishRequest(
          action: action,
          module: 'personalization',
          category: AuditEventCategory.user,
          userId: userId,
          severity: AuditSeverity.info,
          metadata: metadata,
          visibleToUser: true,
        ),
      ),
    );
  }
}
