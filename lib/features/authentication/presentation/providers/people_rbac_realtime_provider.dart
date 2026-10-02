import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/utils/provider_lifecycle.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/organization_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/platform_users_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/rbac_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Live connection state for People / Roles / Permissions realtime.
enum PeopleRbacRealtimeConnection { offline, connecting, live, error }

/// Tables covered by the people/RBAC hub (must stay in realtime publication).
const peopleRbacRealtimeTables = <String>[
  'employees',
  'teams',
  'departments',
  'leave_records',
  'staff_invitations',
  'portal_invitations',
  'roles',
  'role_permissions',
  'permissions',
  'user_roles',
  'permission_groups',
  'permission_group_items',
  'approval_policies',
  'access_requests',
  'profiles',
];

/// Connection badge for Staff + Roles desks.
final peopleRbacRealtimeConnectionProvider =
    StateProvider<PeopleRbacRealtimeConnection>(
      (ref) => PeopleRbacRealtimeConnection.offline,
    );

/// Last human-readable realtime event (cleared after a short delay).
final peopleRbacRealtimeEventProvider = StateProvider<String?>((ref) => null);

enum _PeopleRtBucket { org, rbac, platformUsers, identity }

/// Single hub channel for Staff directory, invites, platform users, and RBAC.
///
/// Replaces naive per-feature channels with status callbacks, debounce,
/// cross-invalidation, and session permission refresh.
final peopleRbacRealtimeHubProvider = Provider<void>((ref) {
  ref.keepAlive();

  void setConnection(PeopleRbacRealtimeConnection value) {
    deferProviderMutation(
      () =>
          ref.read(peopleRbacRealtimeConnectionProvider.notifier).state = value,
    );
  }

  if (!ref.watch(supabaseConfiguredProvider)) {
    setConnection(PeopleRbacRealtimeConnection.offline);
    return;
  }

  final userId = ref.watch(identitySessionProvider.select((s) => s.userId));
  if (userId == null || userId.isEmpty) {
    setConnection(PeopleRbacRealtimeConnection.offline);
    return;
  }

  setConnection(PeopleRbacRealtimeConnection.connecting);

  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('people-rbac-hub');
  Timer? debounce;
  Timer? eventClear;
  final pending = <_PeopleRtBucket>{};

  void emitEvent(String? label) {
    if (label == null || label.isEmpty) return;
    deferProviderMutation(
      () => ref.read(peopleRbacRealtimeEventProvider.notifier).state = label,
    );
    eventClear?.cancel();
    eventClear = Timer(const Duration(seconds: 4), () {
      try {
        final current = ref.read(peopleRbacRealtimeEventProvider);
        if (current == label) {
          ref.read(peopleRbacRealtimeEventProvider.notifier).state = null;
        }
      } catch (_) {}
    });
  }

  void flush() {
    final buckets = Set<_PeopleRtBucket>.from(pending);
    pending.clear();
    if (buckets.isEmpty) return;

    var orgBusy = false;
    var rbacBusy = false;
    var usersBusy = false;
    try {
      orgBusy = ref.read(organizationControllerProvider).isBusy;
      rbacBusy = ref.read(rbacControllerProvider).isBusy;
      usersBusy = ref.read(platformUsersControllerProvider).isBusy;
    } catch (_) {}
    final conflict = orgBusy || rbacBusy || usersBusy;

    deferProviderMutation(() {
      try {
        if (buckets.contains(_PeopleRtBucket.org)) {
          ref.invalidate(organizationSnapshotProvider);
          ref.invalidate(orgChartProvider);
          try {
            ref
                .read(organizationControllerProvider.notifier)
                .clearStatusOverrides();
          } catch (_) {}
        }
        if (buckets.contains(_PeopleRtBucket.rbac)) {
          ref.invalidate(rbacSnapshotProvider);
          ref.invalidate(platformUsersSnapshotProvider);
          try {
            ref.read(rbacControllerProvider.notifier).clearMatrixOverrides();
          } catch (_) {}
        }
        if (buckets.contains(_PeopleRtBucket.platformUsers)) {
          ref.invalidate(platformUsersSnapshotProvider);
          ref.invalidate(rbacSnapshotProvider);
        }
        if (buckets.contains(_PeopleRtBucket.identity)) {
          unawaited(
            ref.read(identitySessionProvider.notifier).refreshPermissions(),
          );
        }
        if (conflict) {
          emitEvent('Updated elsewhere — syncing…');
        }
      } catch (_) {}
    });
  }

  void listenOnce(
    String table,
    Set<_PeopleRtBucket> buckets, {
    String? eventLabel,
  }) {
    assert(
      peopleRbacRealtimeTables.contains(table),
      'Realtime table $table missing from peopleRbacRealtimeTables',
    );
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: table,
      callback: (_) {
        pending.addAll(buckets);
        emitEvent(eventLabel);
        debounce?.cancel();
        debounce = Timer(const Duration(milliseconds: 350), flush);
      },
    );
  }

  listenOnce('employees', {
    _PeopleRtBucket.org,
  }, eventLabel: 'Staff directory updated');
  listenOnce('teams', {_PeopleRtBucket.org}, eventLabel: 'Teams updated');
  listenOnce('departments', {
    _PeopleRtBucket.org,
  }, eventLabel: 'Departments updated');
  listenOnce('leave_records', {_PeopleRtBucket.org});
  listenOnce('staff_invitations', {
    _PeopleRtBucket.org,
  }, eventLabel: 'Invites updated');
  listenOnce('portal_invitations', {
    _PeopleRtBucket.org,
  }, eventLabel: 'Invites updated');

  listenOnce('roles', {_PeopleRtBucket.rbac}, eventLabel: 'Roles updated');
  listenOnce('role_permissions', {
    _PeopleRtBucket.rbac,
    _PeopleRtBucket.identity,
  }, eventLabel: 'Permissions updated');
  listenOnce('permissions', {
    _PeopleRtBucket.rbac,
  }, eventLabel: 'Permission catalog updated');
  listenOnce('user_roles', {
    _PeopleRtBucket.rbac,
    _PeopleRtBucket.platformUsers,
    _PeopleRtBucket.identity,
  }, eventLabel: 'Role assignments updated');
  listenOnce('permission_groups', {
    _PeopleRtBucket.rbac,
  }, eventLabel: 'Permission groups updated');
  listenOnce('permission_group_items', {
    _PeopleRtBucket.rbac,
  }, eventLabel: 'Permission groups updated');
  listenOnce('approval_policies', {
    _PeopleRtBucket.rbac,
  }, eventLabel: 'Approval policies updated');
  listenOnce('access_requests', {
    _PeopleRtBucket.rbac,
  }, eventLabel: 'Access requests updated');
  listenOnce('profiles', {
    _PeopleRtBucket.platformUsers,
  }, eventLabel: 'Platform users updated');

  setConnection(PeopleRbacRealtimeConnection.connecting);
  channel.subscribe((status, error) {
    switch (status) {
      case RealtimeSubscribeStatus.subscribed:
        setConnection(PeopleRbacRealtimeConnection.live);
      case RealtimeSubscribeStatus.timedOut:
      case RealtimeSubscribeStatus.channelError:
        setConnection(PeopleRbacRealtimeConnection.error);
        emitEvent("We'll refresh this when the connection is back.");
      case RealtimeSubscribeStatus.closed:
        setConnection(PeopleRbacRealtimeConnection.offline);
    }
  });

  ref.onDispose(() {
    debounce?.cancel();
    eventClear?.cancel();
    unawaited(channel.unsubscribe());
    setConnection(PeopleRbacRealtimeConnection.offline);
  });
});
