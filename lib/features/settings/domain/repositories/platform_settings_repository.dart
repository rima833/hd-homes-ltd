import 'package:hdhomesproject/features/settings/domain/entities/platform_settings.dart';
import 'package:hdhomesproject/features/settings/domain/entities/portal_feature_gates.dart';

/// Persistence boundary for Platform Control Center settings.
///
/// Supabase RLS + `upsert_app_setting` remain authoritative; this layer never
/// uses elevated keys and never invents secrets.
abstract interface class PlatformSettingsRepository {
  Future<PlatformSettingsBundle> loadBundle({bool publicOnly = false});

  Future<void> saveBundle(PlatformSettingsBundle bundle);

  Future<List<Map<String, dynamic>>> listRecentSettingsAudits({int limit = 20});

  /// Portal module flags via `portal_feature_flags` RPC (authenticated).
  Future<PortalFeatureFlags> fetchPortalFeatureFlags(String portal);
}
