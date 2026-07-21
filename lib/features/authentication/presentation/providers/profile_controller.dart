import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/profile_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/profile_service.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/mfa_controller.dart';
import 'package:image_picker/image_picker.dart';

final profileServiceProvider = Provider<ProfileService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return ProfileService(
    security: ref.watch(securityServiceProvider),
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final profileHubProvider = FutureProvider<ProfileHubSnapshot?>((ref) async {
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
  });

  final ProfileSection section;
  final bool isBusy;
  final String? message;
  final String? error;

  ProfileUiState copyWith({
    ProfileSection? section,
    bool? isBusy,
    String? message,
    String? error,
    bool clearMessage = false,
    bool clearError = false,
  }) {
    return ProfileUiState(
      section: section ?? this.section,
      isBusy: isBusy ?? this.isBusy,
      message: clearMessage ? null : (message ?? this.message),
      error: clearError ? null : (error ?? this.error),
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
        error: e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), ''),
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
        error: e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), ''),
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
        error: e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), ''),
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
        error: e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), ''),
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
      await _service.uploadAvatar(
        userId: userId,
        bytes: bytes,
        contentType: mime,
      );
      await ref.read(identitySessionProvider.notifier).reloadProfile();
      ref.invalidate(profileHubProvider);
      state = state.copyWith(isBusy: false, message: 'Profile photo updated.');
      return true;
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), ''),
      );
      return false;
    }
  }

  Future<void> removeAvatar(String userId) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _service.removeAvatar(userId);
      await ref.read(identitySessionProvider.notifier).reloadProfile();
      ref.invalidate(profileHubProvider);
      state = state.copyWith(isBusy: false, message: 'Profile photo removed.');
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), ''),
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
