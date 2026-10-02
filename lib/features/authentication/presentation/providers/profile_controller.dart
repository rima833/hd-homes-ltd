import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/media/media_providers.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/profile_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/profile_service.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/mfa_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/security_health_providers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final profileServiceProvider = Provider<ProfileService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return ProfileService(
    security: ref.watch(securityServiceProvider),
    client: configured ? ref.watch(supabaseClientProvider) : null,
    mediaService: ref.watch(mediaServiceProvider),
  );
});

void _invalidateProfileHub(Ref ref) {
  ref.invalidate(profileHubProvider);
}

/// Live invalidation for profile center sections.
final profileRealtimeProvider = Provider<void>((ref) {
  ref.keepAlive();
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  final channel = client.channel('admin-profile')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'profiles',
      callback: (_) => _invalidateProfileHub(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'company_profiles',
      callback: (_) => _invalidateProfileHub(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'notification_preferences',
      callback: (_) => _invalidateProfileHub(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'user_preferences',
      callback: (_) => _invalidateProfileHub(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'profile_activity',
      callback: (_) => _invalidateProfileHub(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'media',
      filter: userId == null
          ? null
          : PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'entity_id',
              value: userId,
            ),
      callback: (_) => _invalidateProfileHub(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'kyc_profiles',
      filter: userId == null
          ? null
          : PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
      callback: (_) => _invalidateProfileHub(ref),
    )
    ..subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

final profileHubProvider = FutureProvider<ProfileHubSnapshot?>((ref) async {
  ref.watch(profileRealtimeProvider);
  final session = ref.watch(identitySessionProvider);
  if (!session.isAuthenticated || session.profile == null) return null;
  final mfa = await ref.watch(mfaStatusProvider.future);
  final readiness = ref.watch(securityReadinessProvider);
  return ref.watch(profileServiceProvider).loadHub(
        role: session.primaryRole,
        emailVerified: session.emailConfirmed,
        mfaEnabled: mfa.enabled,
        securityReadiness: readiness,
      );
});

class ProfileUiState {
  const ProfileUiState({
    this.section = ProfileSection.overview,
    this.isBusy = false,
    this.message,
    this.error,
    this.optimisticAvatarUrl,
  });

  final ProfileSection section;
  final bool isBusy;
  final String? message;
  final String? error;
  /// Shown immediately after upload/remove until hub refetch completes.
  final String? optimisticAvatarUrl;

  ProfileUiState copyWith({
    ProfileSection? section,
    bool? isBusy,
    String? message,
    String? error,
    String? optimisticAvatarUrl,
    bool clearMessage = false,
    bool clearError = false,
    bool clearOptimisticAvatar = false,
  }) {
    return ProfileUiState(
      section: section ?? this.section,
      isBusy: isBusy ?? this.isBusy,
      message: clearMessage ? null : (message ?? this.message),
      error: clearError ? null : (error ?? this.error),
      optimisticAvatarUrl: clearOptimisticAvatar
          ? null
          : (optimisticAvatarUrl ?? this.optimisticAvatarUrl),
    );
  }
}

class ProfileController extends Notifier<ProfileUiState> {
  @override
  ProfileUiState build() => const ProfileUiState();

  ProfileService get _service => ref.read(profileServiceProvider);

  void selectSection(ProfileSection section) {
    state = state.copyWith(section: section, clearError: true, clearMessage: true);
  }

  Future<bool> savePersonal(ProfileDetails details) async {
    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      await _service.updatePersonal(details);
      await ref.read(identitySessionProvider.notifier).reloadProfile();
      ref.invalidate(profileHubProvider);
      state = state.copyWith(isBusy: false, message: 'Profile updated.');
      return true;
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e),
      );
      return false;
    }
  }

  Future<bool> saveCompany(String userId, CompanyProfile company) async {
    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      await _service.upsertCompany(userId, company);
      ref.invalidate(profileHubProvider);
      state = state.copyWith(isBusy: false, message: 'Company profile saved.');
      return true;
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e),
      );
      return false;
    }
  }

  Future<bool> saveCommunication(String userId, CommunicationPreferences prefs) async {
    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      await _service.saveCommunication(userId, prefs);
      ref.invalidate(profileHubProvider);
      state = state.copyWith(isBusy: false, message: 'Notification preferences saved.');
      return true;
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e),
      );
      return false;
    }
  }

  Future<bool> saveAppPreferences(String userId, UserAppPreferences prefs) async {
    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      await _service.saveAppPreferences(userId, prefs);
      ref.invalidate(profileHubProvider);
      state = state.copyWith(isBusy: false, message: 'Preferences saved.');
      return true;
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e),
      );
      return false;
    }
  }

  Future<bool> pickAndUploadAvatar(String userId) async {
    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (file == null) {
        state = state.copyWith(isBusy: false);
        return false;
      }
      final bytes = await file.readAsBytes();
      final mime = file.mimeType ?? 'image/jpeg';
      final url = await _service.uploadAvatar(
        userId: userId,
        bytes: bytes,
        contentType: mime,
      );
      state = state.copyWith(optimisticAvatarUrl: url);
      await ref.read(identitySessionProvider.notifier).reloadProfile();
      ref.invalidate(profileHubProvider);
      await ref.read(profileHubProvider.future);
      state = state.copyWith(
        isBusy: false,
        message: 'Profile photo updated.',
        clearOptimisticAvatar: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e),
        clearOptimisticAvatar: true,
      );
      return false;
    }
  }

  Future<void> removeAvatar(String userId) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _service.removeAvatar(userId);
      state = state.copyWith(optimisticAvatarUrl: '');
      await ref.read(identitySessionProvider.notifier).reloadProfile();
      ref.invalidate(profileHubProvider);
      await ref.read(profileHubProvider.future);
      state = state.copyWith(
        isBusy: false,
        message: 'Profile photo removed.',
        clearOptimisticAvatar: true,
      );
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e),
        clearOptimisticAvatar: true,
      );
    }
  }

  Future<void> requestDeactivation(String userId) async {
    await _service.requestDeactivation(userId);
    state = state.copyWith(
      message: 'Deactivation request recorded. Support will follow up.',
    );
  }
}

final profileControllerProvider =
    NotifierProvider<ProfileController, ProfileUiState>(ProfileController.new);
