import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/personalization_models.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/profile_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/personalization_service.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/audit_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final personalizationServiceProvider = Provider<PersonalizationService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return PersonalizationService(
    audit: ref.watch(auditServiceProvider),
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final personalizationSnapshotProvider =
    FutureProvider<PersonalizationSnapshot?>((ref) async {
  final session = ref.watch(identitySessionProvider);
  final userId = session.userId;
  if (userId == null) return null;
  final name = [
    session.profile?.firstName,
    session.profile?.lastName,
  ].whereType<String>().where((e) => e.isNotEmpty).join(' ');
  return ref.watch(personalizationServiceProvider).load(
        userId,
        role: session.primaryRole,
        displayName: name.isEmpty ? (session.email ?? 'there') : name,
      );
});

final personalizationRealtimeProvider = Provider<void>((ref) {
  final session = ref.watch(identitySessionProvider);
  final userId = session.userId;
  if (userId == null) return;
  RealtimeChannel? channel;
  channel = ref.read(personalizationServiceProvider).subscribe(userId, () {
    ref.invalidate(personalizationSnapshotProvider);
  });
  ref.onDispose(() => channel?.unsubscribe());
});

class PersonalizationUiState {
  const PersonalizationUiState({
    this.isBusy = false,
    this.message,
    this.error,
    this.hubTab = 0,
  });

  final bool isBusy;
  final String? message;
  final String? error;
  final int hubTab;

  PersonalizationUiState copyWith({
    bool? isBusy,
    String? message,
    String? error,
    int? hubTab,
    bool clearMessage = false,
    bool clearError = false,
  }) {
    return PersonalizationUiState(
      isBusy: isBusy ?? this.isBusy,
      message: clearMessage ? null : (message ?? this.message),
      error: clearError ? null : (error ?? this.error),
      hubTab: hubTab ?? this.hubTab,
    );
  }
}

final personalizationControllerProvider =
    NotifierProvider<PersonalizationController, PersonalizationUiState>(
  PersonalizationController.new,
);

class PersonalizationController extends Notifier<PersonalizationUiState> {
  @override
  PersonalizationUiState build() {
    ref.watch(personalizationRealtimeProvider);
    return const PersonalizationUiState();
  }

  PersonalizationService get _service =>
      ref.read(personalizationServiceProvider);

  String? get _userId => ref.read(identitySessionProvider).userId;

  void setTab(int index) => state = state.copyWith(hubTab: index);

  Future<void> saveAppearance(AppearancePreferences prefs) async {
    final userId = _userId;
    if (userId == null) return;
    state = state.copyWith(isBusy: true, clearError: true);
    await _service.saveAppearance(userId, prefs);
    ref.invalidate(personalizationSnapshotProvider);
    state = state.copyWith(isBusy: false, message: 'Appearance saved.');
  }

  Future<void> saveAccessibility(AccessibilitySettings settings) async {
    final userId = _userId;
    if (userId == null) return;
    state = state.copyWith(isBusy: true);
    await _service.saveAccessibility(userId, settings);
    ref.invalidate(personalizationSnapshotProvider);
    state = state.copyWith(isBusy: false, message: 'Accessibility updated.');
  }

  Future<void> saveLayout(DashboardLayout layout) async {
    final userId = _userId;
    if (userId == null) return;
    state = state.copyWith(isBusy: true);
    await _service.saveLayout(userId, layout);
    ref.invalidate(personalizationSnapshotProvider);
    state = state.copyWith(isBusy: false, message: 'Dashboard layout saved.');
  }

  Future<void> toggleWidget(DashboardWidgetId id) async {
    final snap = ref.read(personalizationSnapshotProvider).valueOrNull;
    if (snap == null) return;
    final next = PreferenceEngine.toggleWidgetVisibility(snap.layout, id);
    await saveLayout(next);
  }

  Future<void> resetLayout() async {
    final session = ref.read(identitySessionProvider);
    final userId = session.userId;
    if (userId == null) return;
    final layout = PreferenceEngine.defaultLayoutForRole(session.primaryRole);
    await saveLayout(layout);
  }

  Future<void> saveLocalization(UserAppPreferences prefs) async {
    final userId = _userId;
    if (userId == null) return;
    state = state.copyWith(isBusy: true);
    await _service.saveLocalization(userId, prefs);
    ref.invalidate(personalizationSnapshotProvider);
    state = state.copyWith(isBusy: false, message: 'Language & region saved.');
  }

  Future<void> saveInterests(PropertyInterestProfile interests) async {
    final userId = _userId;
    if (userId == null) return;
    state = state.copyWith(isBusy: true);
    await _service.saveInterests(userId, interests);
    ref.invalidate(personalizationSnapshotProvider);
    state = state.copyWith(isBusy: false, message: 'Property interests saved.');
  }

  Future<void> addDemoFavorite() async {
    final userId = _userId;
    if (userId == null) return;
    await _service.addFavorite(
      userId: userId,
      type: FavoriteItemType.property,
      entityId: 'demo-property',
      title: 'Bookmarked property',
      subtitle: 'Added from Preference Center',
    );
    ref.invalidate(personalizationSnapshotProvider);
    state = state.copyWith(message: 'Favorite added.');
  }

  Future<void> createSavedSearch({
    required String name,
    required Map<String, dynamic> criteria,
  }) async {
    final userId = _userId;
    if (userId == null) return;
    await _service.saveSearch(
      userId: userId,
      name: name,
      criteria: criteria,
      alertsEnabled: true,
    );
    ref.invalidate(personalizationSnapshotProvider);
    state = state.copyWith(message: 'Search saved with alerts.');
  }
}
