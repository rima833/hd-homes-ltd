import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/utils/provider_lifecycle.dart';
import 'package:hdhomesproject/features/settings/domain/entities/platform_health.dart';
import 'package:hdhomesproject/features/settings/domain/entities/platform_settings.dart';
import 'package:hdhomesproject/features/settings/domain/entities/portal_feature_gates.dart';
import 'package:hdhomesproject/features/settings/data/repositories/platform_settings_repository_impl.dart';
import 'package:hdhomesproject/features/settings/domain/repositories/platform_settings_repository.dart';
import 'package:hdhomesproject/features/settings/domain/services/platform_health_service.dart';
import 'package:hdhomesproject/features/settings/domain/services/platform_settings_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final platformSettingsRepositoryProvider =
    Provider<PlatformSettingsRepository?>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return null;
  return SupabasePlatformSettingsRepository(
    client: ref.watch(supabaseClientProvider),
  );
});

final platformSettingsServiceProvider = Provider<PlatformSettingsService>((
  ref,
) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return PlatformSettingsService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
    repository: ref.watch(platformSettingsRepositoryProvider),
  );
});

final platformSettingsTickProvider = StateProvider<int>((ref) => 0);

/// Live state of the `app_settings` Realtime channel.
enum PlatformSettingsRealtimePhase { idle, connecting, live, failed }

class PlatformSettingsRealtimeState {
  const PlatformSettingsRealtimeState({
    this.phase = PlatformSettingsRealtimePhase.idle,
    this.detail,
  });

  final PlatformSettingsRealtimePhase phase;
  final String? detail;

  bool get subscribed => phase == PlatformSettingsRealtimePhase.live;

  bool get pending =>
      phase == PlatformSettingsRealtimePhase.idle ||
      phase == PlatformSettingsRealtimePhase.connecting;
}

final platformSettingsRealtimeStateProvider =
    StateProvider<PlatformSettingsRealtimeState>(
  (ref) => const PlatformSettingsRealtimeState(),
);

/// True while the `app_settings` Realtime channel is subscribed.
final platformSettingsRealtimeSubscribedProvider = Provider<bool>((ref) {
  return ref.watch(platformSettingsRealtimeStateProvider).subscribed;
});

final platformSettingsRealtimeProvider = Provider<void>((ref) {
  ref.keepAlive();
  if (!ref.watch(supabaseConfiguredProvider)) {
    deferProviderMutation(() {
      ref.read(platformSettingsRealtimeStateProvider.notifier).state =
          const PlatformSettingsRealtimeState(
        phase: PlatformSettingsRealtimePhase.idle,
        detail: 'Supabase is not configured',
      );
    });
    return;
  }

  final client = ref.watch(supabaseClientProvider);
  var generation = 0;
  var retries = 0;
  var sawLive = false;
  RealtimeChannel? channel;

  void publish(PlatformSettingsRealtimeState next) {
    deferProviderMutation(() {
      ref.read(platformSettingsRealtimeStateProvider.notifier).state = next;
    });
  }

  void attach() {
    final ticket = ++generation;
    final token = client.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      final stale = channel;
      channel = null;
      if (stale != null) unawaited(client.removeChannel(stale));
      sawLive = false;
      publish(
        const PlatformSettingsRealtimeState(
          phase: PlatformSettingsRealtimePhase.idle,
          detail: 'Waiting for a signed-in session',
        ),
      );
      return;
    }

    publish(
      const PlatformSettingsRealtimeState(
        phase: PlatformSettingsRealtimePhase.connecting,
        detail: 'Connecting to app_settings',
      ),
    );

    unawaited(() async {
      try {
        await client.realtime.setAuth(token);
      } catch (_) {
        // A stale token is replaced by the next auth event.
      }
      if (ticket != generation) return;

      final stale = channel;
      channel = null;
      if (stale != null) {
        await client.removeChannel(stale);
      }
      if (ticket != generation) return;

      final next = client.channel('platform-settings-live').onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'app_settings',
        callback: (_) {
          deferProviderMutation(() {
            ref.read(platformSettingsTickProvider.notifier).state++;
          });
        },
      );
      channel = next;
      next.subscribe((status, [error]) {
        if (ticket != generation) return;
        switch (status) {
          case RealtimeSubscribeStatus.subscribed:
            retries = 0;
            sawLive = true;
            publish(
              const PlatformSettingsRealtimeState(
                phase: PlatformSettingsRealtimePhase.live,
                detail: 'app_settings channel subscribed',
              ),
            );
          case RealtimeSubscribeStatus.channelError:
          case RealtimeSubscribeStatus.timedOut:
            final message = _realtimeFailure(status, error);
            if (retries < 1) {
              retries++;
              attach();
              return;
            }
            sawLive = false;
            publish(
              PlatformSettingsRealtimeState(
                phase: PlatformSettingsRealtimePhase.failed,
                detail: message,
              ),
            );
          case RealtimeSubscribeStatus.closed:
            if (sawLive) {
              publish(
                const PlatformSettingsRealtimeState(
                  phase: PlatformSettingsRealtimePhase.connecting,
                  detail: "We're gathering the latest settings.",
                ),
              );
              return;
            }
            if (retries < 1) {
              retries++;
              attach();
              return;
            }
            publish(
              const PlatformSettingsRealtimeState(
                phase: PlatformSettingsRealtimePhase.failed,
                detail: 'Settings channel closed before it subscribed',
              ),
            );
        }
      });
    }());
  }

  final authSub = client.auth.onAuthStateChange.listen((data) {
    switch (data.event) {
      case AuthChangeEvent.initialSession:
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.userUpdated:
        attach();
      case AuthChangeEvent.signedOut:
        generation++;
        final stale = channel;
        channel = null;
        sawLive = false;
        retries = 0;
        if (stale != null) unawaited(client.removeChannel(stale));
        publish(
          const PlatformSettingsRealtimeState(
            phase: PlatformSettingsRealtimePhase.idle,
            detail: 'Waiting for a signed-in session',
          ),
        );
      case AuthChangeEvent.tokenRefreshed:
      case AuthChangeEvent.passwordRecovery:
      case AuthChangeEvent.mfaChallengeVerified:
      case AuthChangeEvent.userDeleted:
        break;
    }
  });

  if (client.auth.currentSession != null) {
    attach();
  } else {
    publish(
      const PlatformSettingsRealtimeState(
        phase: PlatformSettingsRealtimePhase.idle,
        detail: 'Waiting for a signed-in session',
      ),
    );
  }

  ref.onDispose(() {
    generation++;
    unawaited(authSub.cancel());
    final stale = channel;
    channel = null;
    if (stale != null) unawaited(client.removeChannel(stale));
    deferProviderMutation(() {
      ref.read(platformSettingsRealtimeStateProvider.notifier).state =
          const PlatformSettingsRealtimeState();
    });
  });
});

String _realtimeFailure(RealtimeSubscribeStatus status, Object? error) {
  final raw = error?.toString().trim();
  if (raw != null && raw.isNotEmpty && raw != 'null') {
    return raw.replaceFirst('Exception: ', '');
  }
  return switch (status) {
    RealtimeSubscribeStatus.timedOut =>
      'Settings channel timed out while subscribing',
    RealtimeSubscribeStatus.channelError =>
      'Settings channel rejected the subscription',
    _ => 'Settings Realtime channel is not subscribed in this session',
  };
}

final adminPlatformSettingsProvider = FutureProvider<PlatformSettingsBundle>((
  ref,
) async {
  ref.watch(platformSettingsTickProvider);
  ref.watch(platformSettingsRealtimeProvider);
  if (!ref.watch(supabaseConfiguredProvider)) {
    return const PlatformSettingsBundle();
  }
  return ref.watch(platformSettingsServiceProvider).loadBundle();
});

final publishedPlatformSettingsProvider =
    FutureProvider<PlatformSettingsBundle>((ref) async {
      ref.watch(platformSettingsTickProvider);
      ref.watch(platformSettingsRealtimeProvider);
      if (!ref.watch(supabaseConfiguredProvider)) {
        return const PlatformSettingsBundle();
      }
      return ref
          .watch(platformSettingsServiceProvider)
          .loadBundle(publicOnly: true);
    });

/// Compatibility map for existing public consumers that expect company_* keys.
final publishedCompanySettingsCompatProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
      final bundle = await ref.watch(publishedPlatformSettingsProvider.future);
      return bundle.toCompanyCompatibilityMap();
    });

final platformHealthServiceProvider = Provider<PlatformHealthService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  // Ensure Realtime provider is mounted so subscription state is accurate.
  ref.watch(platformSettingsRealtimeProvider);
  final realtime = ref.watch(platformSettingsRealtimeStateProvider);
  return PlatformHealthService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
    realtimeSubscribed: realtime.subscribed,
    realtimePending: realtime.pending,
    realtimeDetail: realtime.detail,
  );
});

/// Real health signals for Settings Overview (no invented "connected").
final platformHealthProvider = FutureProvider<PlatformHealthSnapshot>((
  ref,
) async {
  ref.watch(platformSettingsTickProvider);
  return ref.watch(platformHealthServiceProvider).loadSnapshot();
});

final recentSettingsAuditsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
      ref.watch(platformSettingsTickProvider);
      if (!ref.watch(supabaseConfiguredProvider)) return const [];
      return ref
          .watch(platformSettingsServiceProvider)
          .listRecentSettingsAudits();
    });

/// Parsed brand colors from `app_settings.theme` (optional consumers).
class PublishedBrandColors {
  const PublishedBrandColors({
    required this.primary,
    required this.accent,
  });

  final Color? primary;
  final Color? accent;

  static Color? parseHex(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('#')) value = value.substring(1);
    if (value.length == 6) value = 'FF$value';
    if (value.length != 8) return null;
    final intVal = int.tryParse(value, radix: 16);
    if (intVal == null) return null;
    return Color(intVal);
  }
}

final publishedBrandColorsProvider = Provider<PublishedBrandColors>((ref) {
  final bundle = ref.watch(publishedPlatformSettingsProvider).valueOrNull;
  return PublishedBrandColors(
    primary: PublishedBrandColors.parseHex(bundle?.brandPrimary ?? ''),
    accent: PublishedBrandColors.parseHex(bundle?.brandAccent ?? ''),
  );
});

/// Authenticated portal module flags (`portal_feature_flags` RPC).
///
/// Family key is `client` or `investor`. Fail-open to empty flags (modules on)
/// so a transient RPC error does not blank the portal chrome.
final portalFeatureFlagsProvider =
    FutureProvider.family<PortalFeatureFlags, String>((ref, portal) async {
  ref.watch(platformSettingsTickProvider);
  ref.watch(platformSettingsRealtimeProvider);
  if (!ref.watch(supabaseConfiguredProvider)) {
    return PortalFeatureFlags(portal: portal, flags: const {});
  }
  try {
    return await ref
        .watch(platformSettingsServiceProvider)
        .fetchPortalFeatureFlags(portal);
  } catch (_) {
    return PortalFeatureFlags(portal: portal, flags: const {});
  }
});

final clientPortalFeatureFlagsProvider = Provider<PortalFeatureFlags>((ref) {
  return ref.watch(portalFeatureFlagsProvider('client')).valueOrNull ??
      const PortalFeatureFlags(portal: 'client', flags: {});
});

final investorPortalFeatureFlagsProvider = Provider<PortalFeatureFlags>((ref) {
  return ref.watch(portalFeatureFlagsProvider('investor')).valueOrNull ??
      const PortalFeatureFlags(portal: 'investor', flags: {});
});
