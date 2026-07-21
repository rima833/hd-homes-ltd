import 'package:flutter/foundation.dart';
import 'package:hdhomesproject/core/auth/models/security_event.dart';
import 'package:hdhomesproject/core/auth/services/security_service.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/profile_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Enterprise User Profile Platform — PostgreSQL profile hub + Storage avatars.
class ProfileService {
  ProfileService({
    required SecurityService security,
    SupabaseClient? client,
  })  : _security = security,
        _client = client;

  final SecurityService _security;
  final SupabaseClient? _client;

  bool get isConfigured => _client != null;

  static const _profileSelect = '''
    id, email, first_name, middle_name, last_name, preferred_name, gender,
    date_of_birth, nationality, occupation, biography, phone, secondary_phone,
    whatsapp, country, state, city, address, postal_code, avatar_url,
    preferred_language, account_status, phone_verified, created_at, last_login_at
  ''';

  static const _profileSelectBasic = '''
    id, email, first_name, last_name, phone, avatar_url, address,
    preferred_language, account_status, phone_verified, created_at, last_login_at,
    country, state, city
  ''';

  Future<ProfileHubSnapshot> loadHub({
    required AppRole? role,
    required bool emailVerified,
    required bool mfaEnabled,
    required int securityReadiness,
  }) async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      throw const AuthenticationException('Sign in to manage your profile.');
    }

    final profile = await _fetchProfile(
      userId,
      emailVerified: emailVerified,
      primaryRole: role,
    );
    final company = await _fetchCompany(userId);
    final communication = await _fetchCommunication(userId);
    final prefs = await _fetchAppPreferences(userId);
    final activity = await _fetchActivity(userId);

    final completion = ProfileCompletionEngine.evaluate(
      profile: profile,
      company: company,
      communication: communication,
      mfaEnabled: mfaEnabled,
      isInvestor: role == AppRole.investor,
    );
    final health = AccountHealthScore.compute(
      profileCompletionPercent: completion.percent,
      emailVerified: emailVerified,
      phoneVerified: profile.phoneVerified,
      mfaEnabled: mfaEnabled,
      securityReadiness: securityReadiness,
    );

    return ProfileHubSnapshot(
      profile: profile,
      company: company,
      communication: communication,
      appPreferences: prefs,
      completion: completion,
      accountHealth: health,
      activity: activity,
      mfaEnabled: mfaEnabled,
    );
  }

  Future<ProfileDetails> updatePersonal(ProfileDetails details) async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null || userId != details.id) {
      throw const AuthenticationException('Unable to update profile.');
    }
    try {
      await client.from('profiles').update(details.toUpdateMap()).eq('id', userId);
      await _audit('profile_updated', {'section': 'personal'});
      return details;
    } catch (e) {
      // Fallback when Part 7 columns not yet migrated.
      await client.from('profiles').update({
        'first_name': details.firstName?.trim(),
        'last_name': details.lastName?.trim(),
        'phone': details.phone?.trim(),
        'address': details.address?.trim(),
        'country': details.country?.trim(),
        'state': details.state?.trim(),
        'city': details.city?.trim(),
        'preferred_language': details.preferredLanguage,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);
      await _audit('profile_updated', {'section': 'personal', 'partial': true});
      return details;
    }
  }

  Future<CompanyProfile> upsertCompany(String userId, CompanyProfile company) async {
    final client = _client;
    if (client == null) {
      throw const AuthenticationException('Authentication is not configured.');
    }
    try {
      await client.from('company_profiles').upsert(company.toUpsertMap(userId));
      await _audit('company_updated', {'section': 'company'});
      return company;
    } catch (_) {
      throw const ValidationException(
        'Company profiles require the Part 7 database migration.',
      );
    }
  }

  Future<CommunicationPreferences> saveCommunication(
    String userId,
    CommunicationPreferences prefs,
  ) async {
    final client = _client;
    if (client == null) {
      throw const AuthenticationException('Authentication is not configured.');
    }
    await client.from('notification_preferences').upsert(prefs.toUpsertMap(userId));
    await _audit('preferences_updated', {'section': 'communication'});
    return prefs;
  }

  Future<UserAppPreferences> saveAppPreferences(
    String userId,
    UserAppPreferences prefs,
  ) async {
    final client = _client;
    if (client == null) {
      throw const AuthenticationException('Authentication is not configured.');
    }
    await client.from('user_preferences').upsert(prefs.toUpsertMap(userId));
    await _audit('preferences_updated', {
      'section': 'app',
      'theme': prefs.theme,
      'locale': prefs.locale,
    });
    return prefs;
  }

  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final client = _client;
    if (client == null) {
      throw const AuthenticationException('Authentication is not configured.');
    }
    final ext = contentType.contains('png')
        ? 'png'
        : contentType.contains('webp')
            ? 'webp'
            : 'jpg';
    final path = '$userId/avatar.$ext';
    await client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: contentType,
          ),
        );
    final publicUrl = client.storage.from('avatars').getPublicUrl(path);
    // Cache-bust so UI refreshes immediately.
    final url = '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
    await client.from('profiles').update({
      'avatar_url': url,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', userId);
    await _audit('photo_changed', {'action': 'upload'});
    return url;
  }

  Future<void> removeAvatar(String userId) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.storage.from('avatars').remove([
        '$userId/avatar.jpg',
        '$userId/avatar.png',
        '$userId/avatar.webp',
      ]);
    } catch (_) {}
    await client.from('profiles').update({
      'avatar_url': null,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', userId);
    await _audit('photo_changed', {'action': 'remove'});
  }

  Future<void> requestDeactivation(String userId, {String? reason}) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from('profile_activity').insert({
        'user_id': userId,
        'event_type': 'deactivation_requested',
        'metadata': {'reason': reason},
      });
    } catch (_) {}
    await _audit('deactivation_requested', {'reason': reason});
  }

  Future<ProfileDetails> _fetchProfile(
    String userId, {
    required bool emailVerified,
    AppRole? primaryRole,
  }) async {
    final client = _client!;
    try {
      final row = await client
          .from('profiles')
          .select(_profileSelect)
          .eq('id', userId)
          .maybeSingle();
      if (row == null) {
        throw const AuthenticationException('Profile not found.');
      }
      return ProfileDetails.fromJson(
        Map<String, dynamic>.from(row),
        emailVerified: emailVerified,
        primaryRole: primaryRole,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      final row = await client
          .from('profiles')
          .select(_profileSelectBasic)
          .eq('id', userId)
          .maybeSingle();
      if (row == null) {
        throw const AuthenticationException('Profile not found.');
      }
      return ProfileDetails.fromJson(
        Map<String, dynamic>.from(row),
        emailVerified: emailVerified,
        primaryRole: primaryRole,
      );
    }
  }

  Future<CompanyProfile> _fetchCompany(String userId) async {
    final client = _client!;
    try {
      final row = await client
          .from('company_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      return CompanyProfile.fromJson(
        row == null ? null : Map<String, dynamic>.from(row),
      );
    } catch (_) {
      return const CompanyProfile();
    }
  }

  Future<CommunicationPreferences> _fetchCommunication(String userId) async {
    final client = _client!;
    try {
      final row = await client
          .from('notification_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      return CommunicationPreferences.fromJson(
        row == null ? null : Map<String, dynamic>.from(row),
      );
    } catch (_) {
      return const CommunicationPreferences();
    }
  }

  Future<UserAppPreferences> _fetchAppPreferences(String userId) async {
    final client = _client!;
    try {
      final row = await client
          .from('user_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      return UserAppPreferences.fromJson(
        row == null ? null : Map<String, dynamic>.from(row),
      );
    } catch (_) {
      return const UserAppPreferences();
    }
  }

  Future<List<ProfileActivityItem>> _fetchActivity(String userId) async {
    final client = _client!;
    try {
      final rows = await client
          .from('profile_activity')
          .select('event_type, created_at, metadata')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(20);
      return (rows as List)
          .map((r) => ProfileActivityItem.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _audit(String action, Map<String, dynamic> metadata) async {
    _security.record(
      SecurityEvent(
        type: SecurityEventType.profileUpdated,
        timestamp: DateTime.now(),
        userId: _client?.auth.currentUser?.id,
        userAgent: kIsWeb ? 'web' : defaultTargetPlatform.name,
        metadata: {'action': action, ...metadata},
      ),
    );
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return;
    // ignore: unawaited_futures
    client.from('profile_activity').insert({
      'user_id': userId,
      'event_type': action,
      'metadata': metadata,
      'user_agent': kIsWeb ? 'web' : defaultTargetPlatform.name,
    }).then((_) {}, onError: (_) {});
  }
}
