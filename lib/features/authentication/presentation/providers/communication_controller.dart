import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/email/email.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/utils/provider_lifecycle.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/notification_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/communication_service.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final communicationServiceProvider = Provider<CommunicationService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return CommunicationService(
    security: ref.watch(securityServiceProvider),
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final emailServiceProvider = Provider<EmailService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return EmailService(configured ? ref.watch(supabaseClientProvider) : null);
});

final emailConfigProvider = Provider<EmailConfig>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return EmailConfig(configured ? ref.watch(supabaseClientProvider) : null);
});

final notificationCenterProvider = FutureProvider<NotificationCenterSnapshot?>((
  ref,
) async {
  final session = ref.watch(identitySessionProvider);
  final userId = session.userId;
  if (userId == null) return null;
  return ref.watch(communicationServiceProvider).loadCenter(userId);
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationCenterProvider).valueOrNull?.unreadCount ?? 0;
});

final adminAnnouncementsProvider = FutureProvider<List<AnnouncementPost>>((
  ref,
) async {
  ref.watch(adminAnnouncementsTickProvider);
  if (!ref.watch(supabaseConfiguredProvider)) return const [];
  return ref.watch(communicationServiceProvider).listAnnouncements();
});

final adminCommunicationStatsProvider = FutureProvider<CommunicationAdminStats>(
  (ref) async {
    ref.watch(adminAnnouncementsTickProvider);
    if (!ref.watch(supabaseConfiguredProvider)) {
      return const CommunicationAdminStats();
    }
    return ref.watch(communicationServiceProvider).loadAdminStats();
  },
);

final publishedPublicAnnouncementProvider = FutureProvider<AnnouncementPost?>((
  ref,
) async {
  ref.watch(publicAnnouncementTickProvider);
  if (!ref.watch(supabaseConfiguredProvider)) return null;
  return ref.watch(communicationServiceProvider).latestPublicAnnouncement();
});

final adminAnnouncementsTickProvider = StateProvider<int>((ref) => 0);
final publicAnnouncementTickProvider = StateProvider<int>((ref) => 0);
final announcementsRealtimeConnectedProvider = StateProvider<bool>(
  (ref) => false,
);
final notificationRealtimeConnectedProvider = StateProvider<bool>(
  (ref) => false,
);

final adminAnnouncementsRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final connected = ref.read(announcementsRealtimeConnectedProvider.notifier);
  RealtimeChannel? channel;
  channel = ref
      .read(communicationServiceProvider)
      .subscribeAnnouncements(
        () {
          deferProviderMutation(() {
            ref.read(adminAnnouncementsTickProvider.notifier).state++;
            ref.read(publicAnnouncementTickProvider.notifier).state++;
          });
        },
        onStatus: (status, error) {
          deferProviderMutation(() {
            connected.state = status == RealtimeSubscribeStatus.subscribed;
          });
        },
      );
  ref.onDispose(() {
    deferProviderMutation(() => connected.state = false);
    channel?.unsubscribe();
  });
});

final publicAnnouncementRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  ref.watch(adminAnnouncementsRealtimeProvider);
});

/// Keeps a live subscription and invalidates the center on inserts.
final notificationRealtimeProvider = Provider<void>((ref) {
  final session = ref.watch(identitySessionProvider);
  final userId = session.userId;
  if (userId == null) return;

  final connected = ref.read(notificationRealtimeConnectedProvider.notifier);
  RealtimeChannel? channel;
  channel = ref
      .read(communicationServiceProvider)
      .subscribe(
        userId,
        (_) => deferProviderMutation(
          () => ref.invalidate(notificationCenterProvider),
        ),
        onStatus: (status, error) {
          deferProviderMutation(() {
            connected.state = status == RealtimeSubscribeStatus.subscribed;
          });
        },
      );

  ref.onDispose(() {
    deferProviderMutation(() => connected.state = false);
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
    state = state.copyWith(filter: category, clearFilter: category == null);
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
    state = state.copyWith(
      isBusy: false,
      message: 'All notifications marked read.',
    );
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
        error: userFacingError(e),
      );
    }
  }

  Future<void> publishAnnouncement({
    required String title,
    required String body,
    String audience = 'everyone',
    bool surfacePublicSite = true,
    bool queueEmail = false,
  }) async {
    final actorId = ref.read(identitySessionProvider).userId;
    if (actorId == null) return;
    if (title.trim().isEmpty || body.trim().isEmpty) {
      state = state.copyWith(error: 'Title and message are required.');
      return;
    }
    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      final result = await _service.publishAnnouncement(
        title: title.trim(),
        body: body.trim(),
        actorId: actorId,
        targetAudience: audience,
        surfacePublicSite: surfacePublicSite,
        queueEmail: queueEmail,
      );
      ref.invalidate(notificationCenterProvider);
      ref.read(adminAnnouncementsTickProvider.notifier).state++;
      ref.read(publicAnnouncementTickProvider.notifier).state++;
      ref.invalidate(publishedActiveBannersProvider);
      final reach = result.inAppCount + result.investorInboxCount;
      final publicNote = result.surfacesPublicSite
          ? ' Public site banner updated.'
          : '';
      final emailNote = result.emailQueuedCount > 0
          ? ' ${result.emailQueuedCount} emails queued.'
          : '';
      state = state.copyWith(
        isBusy: false,
        message:
            'Published to ${result.targetAudience} — $reach recipients reached.$publicNote$emailNote',
      );
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e),
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
