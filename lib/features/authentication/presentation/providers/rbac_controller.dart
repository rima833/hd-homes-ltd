import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/rbac_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/rbac_service.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/audit_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final rbacServiceProvider = Provider<RbacService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return RbacService(
    audit: ref.watch(auditServiceProvider),
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final rbacSnapshotProvider = FutureProvider<RbacSnapshot>((ref) async {
  return ref.watch(rbacServiceProvider).loadSnapshot();
});

final rbacRealtimeProvider = Provider<void>((ref) {
  RealtimeChannel? channel;
  channel = ref.read(rbacServiceProvider).subscribeRbac(() {
    ref.invalidate(rbacSnapshotProvider);
  });
  ref.onDispose(() => channel?.unsubscribe());
});

class RbacUiState {
  const RbacUiState({
    this.isBusy = false,
    this.message,
    this.error,
    this.selectedRoleId,
    this.hubTab = 0,
  });

  final bool isBusy;
  final String? message;
  final String? error;
  final String? selectedRoleId;
  final int hubTab;

  RbacUiState copyWith({
    bool? isBusy,
    String? message,
    String? error,
    String? selectedRoleId,
    int? hubTab,
    bool clearMessage = false,
    bool clearError = false,
  }) {
    return RbacUiState(
      isBusy: isBusy ?? this.isBusy,
      message: clearMessage ? null : (message ?? this.message),
      error: clearError ? null : (error ?? this.error),
      selectedRoleId: selectedRoleId ?? this.selectedRoleId,
      hubTab: hubTab ?? this.hubTab,
    );
  }
}

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

  Future<void> toggleMatrixCell({
    required String roleId,
    required String roleSlug,
    required String permissionSlug,
    required bool granted,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true);
    await _service.setRolePermission(
      roleId: roleId,
      roleSlug: roleSlug,
      permissionSlug: permissionSlug,
      granted: granted,
      actorId: ref.read(identitySessionProvider).userId,
    );
    ref.invalidate(rbacSnapshotProvider);
    state = state.copyWith(
      isBusy: false,
      message: granted ? 'Permission granted' : 'Permission revoked',
    );
  }

  Future<void> createRole({
    required String name,
    required String slug,
    String? description,
    String? cloneFromRoleId,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true);
    final role = await _service.createRole(
      name: name,
      slug: slug,
      description: description,
      cloneFromRoleId: cloneFromRoleId,
      actorId: ref.read(identitySessionProvider).userId,
    );
    ref.invalidate(rbacSnapshotProvider);
    state = state.copyWith(
      isBusy: false,
      message: role == null ? 'Unable to create role' : 'Role ${role.name} created',
      selectedRoleId: role?.id,
      error: role == null ? 'Create role failed' : null,
    );
  }

  Future<void> applyGroup(RoleDefinition role, PermissionGroup group) async {
    state = state.copyWith(isBusy: true);
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
  }

  Future<void> archiveRole(RoleDefinition role) async {
    if (role.isSystem) {
      state = state.copyWith(error: 'System roles cannot be archived');
      return;
    }
    await _service.archiveRole(
      role.id,
      role.slug,
      actorId: ref.read(identitySessionProvider).userId,
    );
    ref.invalidate(rbacSnapshotProvider);
    state = state.copyWith(message: 'Role archived');
  }
}
