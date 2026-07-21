import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/notification_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/communication_service.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final communicationServiceProvider = Provider<CommunicationService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return CommunicationService(
    security: ref.watch(securityServiceProvider),
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final notificationCenterProvider =
    FutureProvider<NotificationCenterSnapshot?>((ref) async {
  final session = ref.watch(identitySessionProvider);
  final userId = session.userId;
  if (userId == null) return null;
  return ref.watch(communicationServiceProvider).loadCenter(userId);
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationCenterProvider).valueOrNull?.unreadCount ?? 0;
});

/// Keeps a live subscription and invalidates the center on inserts.
final notificationRealtimeProvider = Provider<void>((ref) {
  final session = ref.watch(identitySessionProvider);
  final userId = session.userId;
  if (userId == null) return;

  RealtimeChannel? channel;
  channel = ref.read(communicationServiceProvider).subscribe(userId, (_) {
    ref.invalidate(notificationCenterProvider);
  });

  ref.onDispose(() {
    channel?.unsubscribe();
  });
});

class CommunicationUiState {
  const CommunicationUiState({
    this.isBusy = false,
    this.message,
    this.error,
    this.filter,
  });

  final bool isBusy;
  final String? message;
  final String? error;
  final NotificationCategory? filter;

  CommunicationUiState copyWith({
    bool? isBusy,
    String? message,
    String? error,
    NotificationCategory? filter,
    bool clearFilter = false,
    bool clearMessage = false,
    bool clearError = false,
  }) {
    return CommunicationUiState(
      isBusy: isBusy ?? this.isBusy,
      message: clearMessage ? null : (message ?? this.message),
      error: clearError ? null : (error ?? this.error),
      filter: clearFilter ? null : (filter ?? this.filter),
    );
  }
}

class CommunicationController extends Notifier<CommunicationUiState> {
  @override
  CommunicationUiState build() {
    // Warm realtime listener
    ref.watch(notificationRealtimeProvider);
    return const CommunicationUiState();
  }

  CommunicationService get _service => ref.read(communicationServiceProvider);

  void setFilter(NotificationCategory? category) {
    state = state.copyWith(
      filter: category,
      clearFilter: category == null,
    );
  }

  Future<void> markRead(String id) async {
    await _service.markRead(id);
    ref.invalidate(notificationCenterProvider);
  }

  Future<void> markAllRead() async {
    final userId = ref.read(identitySessionProvider).userId;
    if (userId == null) return;
    state = state.copyWith(isBusy: true);
    await _service.markAllRead(userId);
    ref.invalidate(notificationCenterProvider);
    state = state.copyWith(isBusy: false, message: 'All notifications marked read.');
  }

  Future<void> archive(String id) async {
    await _service.archive(id);
    ref.invalidate(notificationCenterProvider);
  }

  Future<void> togglePin(String id, bool pinned) async {
    await _service.togglePin(id, pinned);
    ref.invalidate(notificationCenterProvider);
  }

  Future<void> delete(String id) async {
    await _service.deleteNotification(id);
    ref.invalidate(notificationCenterProvider);
  }

  Future<void> savePrefs(CommunicationChannelPrefs prefs) async {
    final userId = ref.read(identitySessionProvider).userId;
    if (userId == null) return;
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _service.savePrefs(userId, prefs);
      ref.invalidate(notificationCenterProvider);
      state = state.copyWith(isBusy: false, message: 'Preferences saved.');
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), ''),
      );
    }
  }

  Future<void> publishAnnouncement({
    required String title,
    required String body,
    String audience = 'everyone',
  }) async {
    final actorId = ref.read(identitySessionProvider).userId;
    if (actorId == null) return;
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _service.publishAnnouncement(
        title: title,
        body: body,
        actorId: actorId,
        targetAudience: audience,
      );
      ref.invalidate(notificationCenterProvider);
      state = state.copyWith(isBusy: false, message: 'Announcement published.');
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), ''),
      );
    }
  }

  /// Helper for other modules: dispatch via orchestrator.
  Future<void> notify({
    required String userId,
    required String templateSlug,
    Map<String, String> variables = const {},
    NotificationPriority priority = NotificationPriority.normal,
    String? actionUrl,
  }) async {
    await _service.dispatch(
      CommunicationDispatchRequest(
        userId: userId,
        templateSlug: templateSlug,
        variables: variables,
        priority: priority,
        actionUrl: actionUrl,
      ),
    );
    ref.invalidate(notificationCenterProvider);
  }
}

final communicationControllerProvider =
    NotifierProvider<CommunicationController, CommunicationUiState>(
  CommunicationController.new,
);
