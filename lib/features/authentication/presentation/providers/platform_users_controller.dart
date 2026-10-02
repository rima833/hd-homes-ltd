import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/account_status.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/platform_user_models.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/rbac_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/platform_users_service.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/audit_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/people_rbac_realtime_provider.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/rbac_controller.dart';

final platformUsersServiceProvider = Provider<PlatformUsersService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return PlatformUsersService(
    audit: ref.watch(auditServiceProvider),
    security: ref.watch(securityServiceProvider),
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final platformUsersSnapshotProvider =
    FutureProvider<PlatformUsersSnapshot>((ref) async {
  return ref.watch(platformUsersServiceProvider).loadSnapshot();
});

final platformUsersRealtimeProvider = Provider<void>((ref) {
  ref.watch(peopleRbacRealtimeHubProvider);
});

class PlatformUsersFilter {
  const PlatformUsersFilter({
    this.query,
    this.status,
    this.roleSlug,
    this.deskTab = 0,
  });

  final String? query;
  final AccountStatus? status;
  final String? roleSlug;

  /// 0 all · 1 needs roles · 2 linked staff · 3 restricted
  final int deskTab;

  PlatformUsersFilter copyWith({
    String? query,
    AccountStatus? status,
    String? roleSlug,
    int? deskTab,
    bool clearQuery = false,
    bool clearStatus = false,
    bool clearRole = false,
  }) {
    return PlatformUsersFilter(
      query: clearQuery ? null : (query ?? this.query),
      status: clearStatus ? null : (status ?? this.status),
      roleSlug: clearRole ? null : (roleSlug ?? this.roleSlug),
      deskTab: deskTab ?? this.deskTab,
    );
  }
}

final platformUsersFilterProvider =
    NotifierProvider<PlatformUsersFilterNotifier, PlatformUsersFilter>(
  PlatformUsersFilterNotifier.new,
);

class PlatformUsersFilterNotifier extends Notifier<PlatformUsersFilter> {
  @override
  PlatformUsersFilter build() => const PlatformUsersFilter();

  void setQuery(String? query) => state = state.copyWith(
        query: query,
        clearQuery: query == null || query.trim().isEmpty,
      );

  void setStatus(AccountStatus? status) => state = state.copyWith(
        status: status,
        clearStatus: status == null,
      );

  void setRoleSlug(String? slug) => state = state.copyWith(
        roleSlug: slug,
        clearRole: slug == null,
      );

  void setDeskTab(int index) =>
      state = state.copyWith(deskTab: index.clamp(0, 3));
}

List<PlatformUser> filterPlatformUsers(
  List<PlatformUser> users, {
  String? query,
  AccountStatus? status,
  String? roleSlug,
  int deskTab = 0,
}) {
  final q = query?.trim().toLowerCase();
  return users.where((u) {
    switch (deskTab) {
      case 1:
        if (u.roles.isNotEmpty) return false;
      case 2:
        if (!u.hasStaffRecord) return false;
      case 3:
        if (u.accountStatus != AccountStatus.suspended &&
            u.accountStatus != AccountStatus.inactive) {
          return false;
        }
      default:
        break;
    }
    if (status != null && u.accountStatus != status) return false;
    if (roleSlug != null && !u.roles.any((r) => r.roleSlug == roleSlug)) {
      return false;
    }
    if (q == null || q.isEmpty) return true;
    return u.displayName.toLowerCase().contains(q) ||
        u.email.toLowerCase().contains(q) ||
        (u.linkedEmployeeCode?.toLowerCase().contains(q) ?? false);
  }).toList();
}

final filteredPlatformUsersProvider =
    Provider<AsyncValue<List<PlatformUser>>>((ref) {
  final filter = ref.watch(platformUsersFilterProvider);
  return ref.watch(platformUsersSnapshotProvider).whenData((snap) {
    return filterPlatformUsers(
      snap.users,
      query: filter.query,
      status: filter.status,
      roleSlug: filter.roleSlug,
      deskTab: filter.deskTab,
    );
  });
});

class PlatformUsersUiState {
  const PlatformUsersUiState({
    this.isBusy = false,
    this.message,
    this.error,
    this.selectedUserId,
  });

  final bool isBusy;
  final String? message;
  final String? error;
  final String? selectedUserId;

  PlatformUsersUiState copyWith({
    bool? isBusy,
    String? message,
    String? error,
    String? selectedUserId,
    bool clearMessage = false,
    bool clearError = false,
  }) {
    return PlatformUsersUiState(
      isBusy: isBusy ?? this.isBusy,
      message: clearMessage ? null : (message ?? this.message),
      error: clearError ? null : (error ?? this.error),
      selectedUserId: selectedUserId ?? this.selectedUserId,
    );
  }
}

final platformUsersControllerProvider =
    NotifierProvider<PlatformUsersController, PlatformUsersUiState>(
  PlatformUsersController.new,
);

class PlatformUsersController extends Notifier<PlatformUsersUiState> {
  @override
  PlatformUsersUiState build() {
    ref.watch(platformUsersRealtimeProvider);
    return const PlatformUsersUiState();
  }

  PlatformUsersService get _service => ref.read(platformUsersServiceProvider);

  void selectUser(String? id) => state = state.copyWith(selectedUserId: id);

  void clearFeedback() =>
      state = state.copyWith(clearMessage: true, clearError: true);

  Future<void> assignRole({
    required String userId,
    required RoleDefinition role,
    bool isPrimary = false,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      await _service.assignRole(
        userId: userId,
        roleId: role.id,
        isPrimary: isPrimary,
        actorId: ref.read(identitySessionProvider).userId,
      );
      ref.invalidate(platformUsersSnapshotProvider);
      ref.invalidate(rbacSnapshotProvider);
      state = state.copyWith(
        isBusy: false,
        message: 'Assigned ${role.name} to account.',
      );
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e, fallback: 'Unable to assign role.'),
      );
    }
  }

  Future<void> revokeRole({
    required PlatformUserRoleAssignment assignment,
    required String userId,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      await _service.revokeRole(
        assignmentId: assignment.assignmentId,
        userId: userId,
        roleId: assignment.roleId,
        actorId: ref.read(identitySessionProvider).userId,
      );
      ref.invalidate(platformUsersSnapshotProvider);
      ref.invalidate(rbacSnapshotProvider);
      state = state.copyWith(
        isBusy: false,
        message: 'Removed ${assignment.roleName}.',
      );
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e, fallback: 'Unable to revoke role.'),
      );
    }
  }

  Future<void> setPrimaryRole({
    required String userId,
    required PlatformUserRoleAssignment assignment,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      await _service.setPrimaryRole(
        userId: userId,
        roleId: assignment.roleId,
        actorId: ref.read(identitySessionProvider).userId,
      );
      ref.invalidate(platformUsersSnapshotProvider);
      state = state.copyWith(
        isBusy: false,
        message: '${assignment.roleName} set as primary role.',
      );
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e, fallback: 'Unable to set primary role.'),
      );
    }
  }

  Future<void> updateAccountStatus({
    required String userId,
    required AccountStatus status,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      await _service.updateAccountStatus(
        userId: userId,
        status: status,
        actorId: ref.read(identitySessionProvider).userId,
      );
      ref.invalidate(platformUsersSnapshotProvider);
      state = state.copyWith(
        isBusy: false,
        message:
            'Account status updated to ${status.slug.replaceAll('_', ' ')}.',
      );
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e, fallback: 'Unable to update account status.'),
      );
    }
  }
}
