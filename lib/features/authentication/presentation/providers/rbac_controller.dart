import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/rbac_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/rbac_service.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/audit_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/people_rbac_realtime_provider.dart';

final rbacServiceProvider = Provider<RbacService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return RbacService(
    audit: ref.watch(auditServiceProvider),
    security: ref.watch(securityServiceProvider),
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final rbacSnapshotProvider = FutureProvider<RbacSnapshot>((ref) async {
  return ref.watch(rbacServiceProvider).loadSnapshot();
});

final rbacRealtimeProvider = Provider<void>((ref) {
  ref.watch(peopleRbacRealtimeHubProvider);
});

class RbacUiState {
  const RbacUiState({
    this.isBusy = false,
    this.message,
    this.error,
    this.selectedRoleId,
    this.hubTab = 0,
    this.matrixOverrides = const {},
    this.pendingMatrixKeys = const {},
  });

  final bool isBusy;
  final String? message;
  final String? error;
  final String? selectedRoleId;
  final int hubTab;

  /// Optimistic matrix cells: [PermissionMatrix.cellKey] → granted.
  final Map<String, bool> matrixOverrides;

  /// Cell keys currently awaiting RPC (blocks re-click).
  final Set<String> pendingMatrixKeys;

  RbacUiState copyWith({
    bool? isBusy,
    String? message,
    String? error,
    Object? selectedRoleId = _rbacUnset,
    int? hubTab,
    Map<String, bool>? matrixOverrides,
    Set<String>? pendingMatrixKeys,
    bool clearMessage = false,
    bool clearError = false,
    bool clearMatrixOverrides = false,
  }) {
    return RbacUiState(
      isBusy: isBusy ?? this.isBusy,
      message: clearMessage ? null : (message ?? this.message),
      error: clearError ? null : (error ?? this.error),
      selectedRoleId: identical(selectedRoleId, _rbacUnset)
          ? this.selectedRoleId
          : selectedRoleId as String?,
      hubTab: hubTab ?? this.hubTab,
      matrixOverrides: clearMatrixOverrides
          ? const {}
          : (matrixOverrides ?? this.matrixOverrides),
      pendingMatrixKeys: clearMatrixOverrides
          ? const {}
          : (pendingMatrixKeys ?? this.pendingMatrixKeys),
    );
  }

  bool? overrideGranted(String roleSlug, String permissionSlug) =>
      matrixOverrides[PermissionMatrix.cellKey(roleSlug, permissionSlug)];

  bool isMatrixPending(String roleSlug, String permissionSlug) =>
      pendingMatrixKeys.contains(
        PermissionMatrix.cellKey(roleSlug, permissionSlug),
      );
}

const Object _rbacUnset = Object();

final rbacControllerProvider =
    NotifierProvider<RbacController, RbacUiState>(RbacController.new);

class RbacController extends Notifier<RbacUiState> {
  @override
  RbacUiState build() {
    ref.watch(rbacRealtimeProvider);
    return const RbacUiState();
  }

  RbacService get _service => ref.read(rbacServiceProvider);

  void setTab(int index) => state = state.copyWith(hubTab: index);

  void selectRole(String? id) => state = state.copyWith(selectedRoleId: id);

  void clearFeedback() => state = state.copyWith(
        clearMessage: true,
        clearError: true,
      );

  void clearMatrixOverrides() =>
      state = state.copyWith(clearMatrixOverrides: true);

  Future<void> toggleMatrixCell({
    required String roleId,
    required String roleSlug,
    required String permissionSlug,
    required bool granted,
  }) async {
    final key = PermissionMatrix.cellKey(roleSlug, permissionSlug);
    if (state.pendingMatrixKeys.contains(key)) return;
    final previousOverrides = Map<String, bool>.from(state.matrixOverrides);
    final optimistic = Map<String, bool>.from(previousOverrides)..[key] = granted;
    final pending = Set<String>.from(state.pendingMatrixKeys)..add(key);
    state = state.copyWith(
      clearError: true,
      clearMessage: true,
      matrixOverrides: optimistic,
      pendingMatrixKeys: pending,
    );
    try {
      await _service.setRolePermission(
        roleId: roleId,
        roleSlug: roleSlug,
        permissionSlug: permissionSlug,
        granted: granted,
        actorId: ref.read(identitySessionProvider).userId,
      );
      ref.invalidate(rbacSnapshotProvider);
      final cleaned = Map<String, bool>.from(state.matrixOverrides)..remove(key);
      final pendingDone = Set<String>.from(state.pendingMatrixKeys)..remove(key);
      state = state.copyWith(
        matrixOverrides: cleaned,
        pendingMatrixKeys: pendingDone,
        message: granted ? 'Permission granted' : 'Permission revoked',
      );
    } catch (e) {
      final pendingDone = Set<String>.from(state.pendingMatrixKeys)..remove(key);
      state = state.copyWith(
        matrixOverrides: previousOverrides,
        pendingMatrixKeys: pendingDone,
        error: userFacingError(e, fallback: 'Unable to update permission.'),
      );
    }
  }

  Future<void> createRole({
    required String name,
    required String slug,
    String? description,
    String? cloneFromRoleId,
    String? parentRoleId,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      final role = await _service.createRole(
        name: name,
        slug: slug,
        description: description,
        cloneFromRoleId: cloneFromRoleId,
        parentRoleId: parentRoleId,
        actorId: ref.read(identitySessionProvider).userId,
      );
      ref.invalidate(rbacSnapshotProvider);
      state = state.copyWith(
        isBusy: false,
        message: 'Role ${role.name} created',
        selectedRoleId: role.id,
        hubTab: 0,
      );
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e, fallback: 'Unable to create role.'),
      );
    }
  }

  Future<void> updateRole({
    required String roleId,
    String? name,
    String? description,
    RoleLifecycle? lifecycle,
    String? parentRoleId,
    bool clearParent = false,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      final role = await _service.updateRole(
        roleId: roleId,
        name: name,
        description: description,
        lifecycle: lifecycle,
        parentRoleId: parentRoleId,
        clearParent: clearParent,
        actorId: ref.read(identitySessionProvider).userId,
      );
      ref.invalidate(rbacSnapshotProvider);
      state = state.copyWith(
        isBusy: false,
        message: 'Updated ${role.name}',
        selectedRoleId: role.id,
        hubTab: 0,
      );
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e, fallback: 'Unable to update role.'),
      );
    }
  }

  Future<void> createPermission({
    required String name,
    required String slug,
    required String module,
    String? description,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      final perm = await _service.createPermission(
        name: name,
        slug: slug,
        module: module,
        description: description,
        actorId: ref.read(identitySessionProvider).userId,
      );
      ref.invalidate(rbacSnapshotProvider);
      state = state.copyWith(
        isBusy: false,
        message: 'Permission ${perm.name} created',
        hubTab: 1,
      );
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e, fallback: 'Unable to create permission.'),
      );
    }
  }

  Future<void> applyGroup(RoleDefinition role, PermissionGroup group) async {
    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      await _service.assignGroupToRole(
        roleId: role.id,
        roleSlug: role.slug,
        group: group,
        actorId: ref.read(identitySessionProvider).userId,
      );
      ref.invalidate(rbacSnapshotProvider);
      state = state.copyWith(
        isBusy: false,
        message: 'Applied ${group.name} to ${role.name}',
      );
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e, fallback: 'Unable to apply permission group.'),
      );
    }
  }

  Future<void> setApprovalPolicyEnabled({
    required ApprovalPolicy policy,
    required bool enabled,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      await _service.setApprovalPolicyEnabled(
        policyId: policy.id,
        enabled: enabled,
      );
      ref.invalidate(rbacSnapshotProvider);
      state = state.copyWith(
        isBusy: false,
        message: enabled
            ? '${policy.name} enabled'
            : '${policy.name} disabled',
        hubTab: 3,
      );
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e, fallback: 'Unable to update approval policy.'),
      );
    }
  }

  Future<void> createAccessRequest({
    required String reason,
    String? permissionSlug,
    String? roleSlug,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      await _service.createAccessRequest(
        reason: reason,
        permissionSlug: permissionSlug,
        roleSlug: roleSlug,
      );
      ref.invalidate(rbacSnapshotProvider);
      state = state.copyWith(
        isBusy: false,
        message: 'Access request submitted',
        hubTab: 3,
      );
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e, fallback: 'Unable to submit access request.'),
      );
    }
  }

  Future<void> reviewAccessRequest({
    required AccessRequest request,
    required bool approve,
    String? note,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      await _service.reviewAccessRequest(
        requestId: request.id,
        approve: approve,
        note: note,
      );
      ref.invalidate(rbacSnapshotProvider);
      state = state.copyWith(
        isBusy: false,
        message: approve ? 'Request approved' : 'Request denied',
        hubTab: 3,
      );
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e, fallback: 'Unable to review access request.'),
      );
    }
  }

  Future<void> archiveRole(RoleDefinition role) async {
    if (role.isSystem) {
      state = state.copyWith(error: 'System roles cannot be archived');
      return;
    }
    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      await _service.archiveRole(
        role.id,
        role.slug,
        actorId: ref.read(identitySessionProvider).userId,
      );
      ref.invalidate(rbacSnapshotProvider);
      state = state.copyWith(
        isBusy: false,
        message: 'Role archived',
        selectedRoleId: null,
      );
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e, fallback: 'Unable to archive role.'),
      );
    }
  }
}
