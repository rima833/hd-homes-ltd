import 'package:hdhomesproject/features/settings/domain/entities/platform_settings.dart';
import 'package:hdhomesproject/features/settings/domain/entities/portal_feature_gates.dart';
import 'package:hdhomesproject/features/settings/domain/repositories/platform_settings_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabasePlatformSettingsRepository implements PlatformSettingsRepository {
  SupabasePlatformSettingsRepository({required SupabaseClient client})
      : _client = client;

  final SupabaseClient _client;

  /// Keys loaded for admin Control Center. Public loads filter via [publicOnly].
  static const managedKeys = <String>[
    'company',
    'contact',
    'theme',
    'seo',
    'social',
    'website_features',
    'maintenance',
    'portal_features',
    'integrations',
  ];

  /// Keys that must never be served to anonymous / public clients.
  static const staffOnlyKeys = <String>{
    'portal_features',
    'integrations',
  };

  @override
  Future<PlatformSettingsBundle> loadBundle({bool publicOnly = false}) async {
    final keys = publicOnly
        ? managedKeys.where((k) => !staffOnlyKeys.contains(k)).toList()
        : managedKeys;

    var query = _client
        .from('app_settings')
        .select(
          'key, value, category, is_public, description, updated_at, updated_by',
        )
        .eq('is_deleted', false)
        .inFilter('key', keys);
    if (publicOnly) {
      query = query.eq('is_public', true);
    }
    final rows = await query;
    final records = (rows as List)
        .map(
          (row) => PlatformSettingRecord.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
    return PlatformSettingsBundle.fromRecords(records);
  }

  @override
  Future<void> saveBundle(PlatformSettingsBundle bundle) async {
    final payloads = <Map<String, dynamic>>[
      {
        'key': 'company',
        'value': bundle.company,
        'category': 'general',
        'is_public': true,
        'description': 'Company business profile',
      },
      {
        'key': 'contact',
        'value': bundle.contact,
        'category': 'general',
        'is_public': true,
        'description': 'Public contact channels',
      },
      {
        'key': 'theme',
        'value': bundle.theme,
        'category': 'branding',
        'is_public': true,
        'description': 'Brand color references',
      },
      {
        'key': 'seo',
        'value': bundle.seo,
        'category': 'seo',
        'is_public': true,
        'description': 'Default SEO metadata',
      },
      {
        'key': 'social',
        'value': bundle.social,
        'category': 'branding',
        'is_public': true,
        'description': 'Public social profile links',
      },
      {
        'key': 'website_features',
        'value': bundle.websiteFeatures,
        'category': 'website',
        'is_public': true,
        'description': 'Public website feature toggles',
      },
      {
        'key': 'maintenance',
        'value': bundle.maintenance,
        'category': 'ops',
        'is_public': true,
        'description': 'Maintenance mode and public banners',
      },
    ];

    // Never wipe portal/integration seeds with empty maps from older callers.
    if (bundle.portalFeatures.isNotEmpty) {
      payloads.add({
        'key': 'portal_features',
        'value': bundle.portalFeatures,
        'category': 'portals',
        'is_public': false,
        'description':
            'Client and investor portal module visibility (staff-managed)',
      });
    }
    if (bundle.integrations.isNotEmpty) {
      payloads.add({
        'key': 'integrations',
        'value': bundle.integrations,
        'category': 'integrations',
        'is_public': false,
        'description': 'Integration registry status (no secrets)',
      });
    }

    for (final payload in payloads) {
      await _client.rpc(
        'upsert_app_setting',
        params: {
          'p_key': payload['key'],
          'p_value': payload['value'],
          'p_category': payload['category'],
          'p_is_public': payload['is_public'],
          'p_description': payload['description'],
        },
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listRecentSettingsAudits({
    int limit = 20,
  }) async {
    final rows = await _client
        .from('audit_logs')
        .select(
          'id, action, entity_id, old_values, new_values, metadata, '
          'created_at, user_id, result_status',
        )
        .eq('module', 'platform_settings')
        .eq('is_deleted', false)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  @override
  Future<PortalFeatureFlags> fetchPortalFeatureFlags(String portal) async {
    final raw = await _client.rpc(
      'portal_feature_flags',
      params: {'p_portal': portal},
    );
    if (raw is Map) {
      return PortalFeatureFlags.fromRpc(Map<String, dynamic>.from(raw));
    }
    return PortalFeatureFlags(portal: portal, flags: const {});
  }
}
