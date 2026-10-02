import 'package:hdhomesproject/features/settings/data/repositories/platform_settings_repository_impl.dart';
import 'package:hdhomesproject/features/settings/domain/entities/platform_settings.dart';
import 'package:hdhomesproject/features/settings/domain/entities/portal_feature_gates.dart';
import 'package:hdhomesproject/features/settings/domain/repositories/platform_settings_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Application service over [PlatformSettingsRepository].
///
/// Prefer injecting the repository in new code; this class remains the
/// stable entry point for existing providers and the admin Settings page.
class PlatformSettingsService implements PlatformSettingsRepository {
  PlatformSettingsService({
    SupabaseClient? client,
    PlatformSettingsRepository? repository,
  }) : _client = client,
       _repository = repository;

  final SupabaseClient? _client;
  final PlatformSettingsRepository? _repository;

  static const managedKeys = SupabasePlatformSettingsRepository.managedKeys;
  static const staffOnlyKeys = SupabasePlatformSettingsRepository.staffOnlyKeys;

  PlatformSettingsRepository get _repo {
    final existing = _repository;
    if (existing != null) return existing;
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured');
    }
    return SupabasePlatformSettingsRepository(client: client);
  }

  @override
  Future<PlatformSettingsBundle> loadBundle({bool publicOnly = false}) =>
      _repo.loadBundle(publicOnly: publicOnly);

  @override
  Future<void> saveBundle(PlatformSettingsBundle bundle) =>
      _repo.saveBundle(bundle);

  @override
  Future<List<Map<String, dynamic>>> listRecentSettingsAudits({
    int limit = 20,
  }) =>
      _repo.listRecentSettingsAudits(limit: limit);

  @override
  Future<PortalFeatureFlags> fetchPortalFeatureFlags(String portal) =>
      _repo.fetchPortalFeatureFlags(portal);
}
