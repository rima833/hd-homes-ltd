import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/organization_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/organization_service.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/audit_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/people_rbac_realtime_provider.dart';

final organizationServiceProvider = Provider<OrganizationService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return OrganizationService(
    audit: ref.watch(auditServiceProvider),
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final organizationSnapshotProvider =
    FutureProvider<OrganizationSnapshot>((ref) async {
  return ref.watch(organizationServiceProvider).loadSnapshot();
});

final orgChartProvider = FutureProvider<List<OrgChartNode>>((ref) async {
  return ref.watch(organizationServiceProvider).loadOrgChart();
});

final staffAttendanceTodayProvider =
    FutureProvider.family<StaffAttendanceSummary, String>((ref, employeeId) {
  return ref
      .watch(organizationServiceProvider)
      .loadStaffAttendanceToday(employeeId);
});

final staffDirectoryFilterProvider =
    NotifierProvider<StaffDirectoryFilterNotifier, StaffDirectoryFilter>(
  StaffDirectoryFilterNotifier.new,
);

class StaffDirectoryFilter {
  const StaffDirectoryFilter({
    this.query,
    this.departmentId,
    this.teamId,
    this.roleSlug,
    this.status,
    this.branchId,
    this.page = 0,
    this.pageSize = 40,
  });

  final String? query;
  final String? departmentId;
  final String? teamId;
  final String? roleSlug;
  final StaffStatus? status;
  final String? branchId;
  final int page;
  final int pageSize;

  StaffDirectoryFilter copyWith({
    String? query,
    String? departmentId,
    String? teamId,
    String? roleSlug,
    StaffStatus? status,
    String? branchId,
    int? page,
    int? pageSize,
    bool clearQuery = false,
    bool clearDepartment = false,
    bool clearTeam = false,
    bool clearRole = false,
    bool clearStatus = false,
    bool clearBranch = false,
  }) {
    return StaffDirectoryFilter(
      query: clearQuery ? null : (query ?? this.query),
      departmentId:
          clearDepartment ? null : (departmentId ?? this.departmentId),
      teamId: clearTeam ? null : (teamId ?? this.teamId),
      roleSlug: clearRole ? null : (roleSlug ?? this.roleSlug),
      status: clearStatus ? null : (status ?? this.status),
      branchId: clearBranch ? null : (branchId ?? this.branchId),
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }
}

class StaffDirectoryFilterNotifier extends Notifier<StaffDirectoryFilter> {
  @override
  StaffDirectoryFilter build() => const StaffDirectoryFilter();

  void setQuery(String? query) => state = state.copyWith(
        query: query,
        clearQuery: query == null || query.trim().isEmpty,
        page: 0,
      );

  void setDepartment(String? id) => state = state.copyWith(
        departmentId: id,
        clearDepartment: id == null,
        page: 0,
      );

  void setTeam(String? id) => state = state.copyWith(
        teamId: id,
        clearTeam: id == null,
        page: 0,
      );

  void setRole(String? slug) => state = state.copyWith(
        roleSlug: slug,
        clearRole: slug == null || slug.trim().isEmpty,
        page: 0,
      );

  void setStatus(StaffStatus? status) => state = state.copyWith(
        status: status,
        clearStatus: status == null,
        page: 0,
      );

  void setBranch(String? id) =>
      state = state.copyWith(branchId: id, clearBranch: id == null, page: 0);

  void clearAll() => state = const StaffDirectoryFilter();

  void setPage(int page) => state = state.copyWith(page: page < 0 ? 0 : page);

  void nextPage(int totalCount) {
    final maxPage = (totalCount / state.pageSize).ceil() - 1;
    if (state.page < maxPage) {
      state = state.copyWith(page: state.page + 1);
    }
  }

  void previousPage() {
    if (state.page > 0) {
      state = state.copyWith(page: state.page - 1);
    }
  }
}

final filteredStaffProvider = Provider<AsyncValue<List<Employee>>>((ref) {
  final filter = ref.watch(staffDirectoryFilterProvider);
  return ref.watch(organizationSnapshotProvider).whenData((snap) {
    return OrganizationEngine.searchDirectory(
      snap.employees,
      query: filter.query,
      departmentId: filter.departmentId,
      teamId: filter.teamId,
      roleSlug: filter.roleSlug,
      status: filter.status,
      branchId: filter.branchId,
    );
  });
});

final pagedStaffProvider = Provider<AsyncValue<List<Employee>>>((ref) {
  final filter = ref.watch(staffDirectoryFilterProvider);
  return ref.watch(filteredStaffProvider).whenData((all) {
    final start = filter.page * filter.pageSize;
    if (start >= all.length) return const [];
    final end = (start + filter.pageSize).clamp(0, all.length);
    return all.sublist(start, end);
  });
});

final organizationRealtimeProvider = Provider<void>((ref) {
  ref.watch(peopleRbacRealtimeHubProvider);
});

class OrganizationUiState {
  const OrganizationUiState({
    this.isBusy = false,
    this.message,
    this.error,
    this.selectedEmployeeId,
    this.hubTab = 0,
    this.statusOverrides = const {},
  });

  final bool isBusy;
  final String? message;
  final String? error;
  final String? selectedEmployeeId;
  final int hubTab;

  /// Optimistic staff status chips: employeeId → status.
  final Map<String, StaffStatus> statusOverrides;

  OrganizationUiState copyWith({
    bool? isBusy,
    String? message,
    String? error,
    String? selectedEmployeeId,
    int? hubTab,
    Map<String, StaffStatus>? statusOverrides,
    bool clearMessage = false,
    bool clearError = false,
    bool clearStatusOverrides = false,
  }) {
    return OrganizationUiState(
      isBusy: isBusy ?? this.isBusy,
      message: clearMessage ? null : (message ?? this.message),
      error: clearError ? null : (error ?? this.error),
      selectedEmployeeId: selectedEmployeeId ?? this.selectedEmployeeId,
      hubTab: hubTab ?? this.hubTab,
      statusOverrides: clearStatusOverrides
          ? const {}
          : (statusOverrides ?? this.statusOverrides),
    );
  }

  StaffStatus? overrideStatus(String employeeId) => statusOverrides[employeeId];
}

final organizationControllerProvider =
    NotifierProvider<OrganizationController, OrganizationUiState>(
  OrganizationController.new,
);

class OrganizationController extends Notifier<OrganizationUiState> {
  @override
  OrganizationUiState build() {
    ref.watch(organizationRealtimeProvider);
    return const OrganizationUiState();
  }

  OrganizationService get _service => ref.read(organizationServiceProvider);

  void setTab(int index) => state = state.copyWith(hubTab: index);

  void selectEmployee(String? id) =>
      state = state.copyWith(selectedEmployeeId: id);

  void clearFeedback() => state = state.copyWith(
        clearMessage: true,
        clearError: true,
      );

  void clearStatusOverrides() =>
      state = state.copyWith(clearStatusOverrides: true);

  Future<void> createEmployee({
    required String firstName,
    required String lastName,
    String? email,
    String? phone,
    String? jobTitle,
    String? departmentId,
    String? teamId,
    String? managerId,
    String? branchId,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      final actorId = ref.read(identitySessionProvider).userId;
      final employee = await _service.upsertStaffRecord(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        jobTitle: jobTitle,
        departmentId: departmentId,
        teamId: teamId,
        managerId: managerId,
        branchId: branchId,
        actorId: actorId,
      );
      ref.invalidate(organizationSnapshotProvider);
      ref.invalidate(orgChartProvider);
      state = state.copyWith(
        isBusy: false,
        message: 'Created ${employee.employeeCode} — ${employee.displayName}',
        selectedEmployeeId: employee.id,
        hubTab: 0,
      );
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e, fallback: 'Unable to create staff record.'),
      );
    }
  }

  Future<void> updateEmployee({
    required String employeeId,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? jobTitle,
    String? departmentId,
    String? teamId,
    String? managerId,
    String? branchId,
    bool clearDepartment = false,
    bool clearTeam = false,
    bool clearManager = false,
    bool clearBranch = false,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      final employee = await _service.updateStaffRecord(
        employeeId: employeeId,
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        jobTitle: jobTitle,
        departmentId: departmentId,
        teamId: teamId,
        managerId: managerId,
        branchId: branchId,
        clearDepartment: clearDepartment,
        clearTeam: clearTeam,
        clearManager: clearManager,
        clearBranch: clearBranch,
        actorId: ref.read(identitySessionProvider).userId,
      );
      ref.invalidate(organizationSnapshotProvider);
      ref.invalidate(orgChartProvider);
      state = state.copyWith(
        isBusy: false,
        message: employee == null
            ? 'Staff record updated'
            : 'Updated ${employee.displayName}',
        selectedEmployeeId: employeeId,
      );
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e, fallback: 'Unable to update staff record.'),
      );
    }
  }

  Future<void> changeStatus(String employeeId, StaffStatus status) async {
    final previous = Map<String, StaffStatus>.from(state.statusOverrides);
    final optimistic = Map<String, StaffStatus>.from(previous)
      ..[employeeId] = status;
    state = state.copyWith(
      isBusy: true,
      clearError: true,
      clearMessage: true,
      statusOverrides: optimistic,
    );
    try {
      await _service.updateStaffStatus(
        employeeId,
        status,
        actorId: ref.read(identitySessionProvider).userId,
      );
      ref.invalidate(organizationSnapshotProvider);
      ref.invalidate(orgChartProvider);
      final cleaned = Map<String, StaffStatus>.from(state.statusOverrides)
        ..remove(employeeId);
      state = state.copyWith(
        isBusy: false,
        statusOverrides: cleaned,
        message: 'Status updated to ${status.label}',
      );
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        statusOverrides: previous,
        error: userFacingError(e, fallback: 'Unable to update status.'),
      );
    }
  }

  Future<void> deactivateEmployee(String employeeId, {String? reason}) async {
    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      await _service.deactivateEmployee(employeeId, reason: reason);
      ref.invalidate(organizationSnapshotProvider);
      ref.invalidate(orgChartProvider);
      state = state.copyWith(
        isBusy: false,
        message: 'Employee deactivated. Linked portal roles were revoked.',
        selectedEmployeeId: employeeId,
      );
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e, fallback: 'Unable to deactivate employee.'),
      );
    }
  }

  Future<void> reactivateEmployee(String employeeId) async {
    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      await _service.reactivateEmployee(employeeId);
      ref.invalidate(organizationSnapshotProvider);
      ref.invalidate(orgChartProvider);
      state = state.copyWith(
        isBusy: false,
        message: 'Employee reactivated. Re-assign roles if portal access is needed.',
        selectedEmployeeId: employeeId,
      );
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e, fallback: 'Unable to reactivate employee.'),
      );
    }
  }

  Future<void> createDepartment({
    required String name,
    String? description,
    String? headEmployeeId,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      final dept = await _service.createDepartment(
        name: name,
        description: description,
        headEmployeeId: headEmployeeId,
        actorId: ref.read(identitySessionProvider).userId,
      );
      ref.invalidate(organizationSnapshotProvider);
      state = state.copyWith(
        isBusy: false,
        message: 'Created department ${dept.name}',
        hubTab: 1,
      );
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e, fallback: 'Unable to create department.'),
      );
    }
  }

  Future<void> updateDepartment({
    required String departmentId,
    String? name,
    String? description,
    String? headEmployeeId,
    OrgEntityStatus? status,
    bool clearHead = false,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      final dept = await _service.updateDepartment(
        departmentId: departmentId,
        name: name,
        description: description,
        headEmployeeId: headEmployeeId,
        status: status,
        clearHead: clearHead,
        actorId: ref.read(identitySessionProvider).userId,
      );
      ref.invalidate(organizationSnapshotProvider);
      final archived = status == OrgEntityStatus.archived;
      state = state.copyWith(
        isBusy: false,
        message: archived
            ? 'Deleted department ${dept.name}'
            : 'Updated department ${dept.name}',
        hubTab: 1,
      );
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e, fallback: 'Unable to update department.'),
      );
    }
  }

  Future<void> createTeam({
    required String name,
    required String departmentId,
    String? description,
    String? teamLeadId,
    String? branchId,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      final team = await _service.createTeam(
        name: name,
        departmentId: departmentId,
        description: description,
        teamLeadId: teamLeadId,
        branchId: branchId,
        actorId: ref.read(identitySessionProvider).userId,
      );
      ref.invalidate(organizationSnapshotProvider);
      state = state.copyWith(
        isBusy: false,
        message: 'Created team ${team.name}',
        hubTab: 2,
      );
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e, fallback: 'Unable to create team.'),
      );
    }
  }

  Future<void> updateTeam({
    required String teamId,
    String? name,
    String? departmentId,
    String? description,
    String? teamLeadId,
    String? branchId,
    OrgEntityStatus? status,
    bool clearLead = false,
    bool clearBranch = false,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      final team = await _service.updateTeam(
        teamId: teamId,
        name: name,
        departmentId: departmentId,
        description: description,
        teamLeadId: teamLeadId,
        branchId: branchId,
        status: status,
        clearLead: clearLead,
        clearBranch: clearBranch,
        actorId: ref.read(identitySessionProvider).userId,
      );
      ref.invalidate(organizationSnapshotProvider);
      final archived = status == OrgEntityStatus.archived;
      state = state.copyWith(
        isBusy: false,
        message: archived
            ? 'Deleted team ${team.name}'
            : 'Updated team ${team.name}',
        hubTab: 2,
      );
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e, fallback: 'Unable to update team.'),
      );
    }
  }

  Future<void> reassignEmployee({
    required String employeeId,
    String? departmentId,
    String? teamId,
    bool clearDepartment = false,
    bool clearTeam = false,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      await _service.reassignEmployee(
        employeeId: employeeId,
        departmentId: departmentId,
        teamId: teamId,
        clearDepartment: clearDepartment,
        clearTeam: clearTeam,
        actorId: ref.read(identitySessionProvider).userId,
      );
      ref.invalidate(organizationSnapshotProvider);
      ref.invalidate(orgChartProvider);
      state = state.copyWith(
        isBusy: false,
        message: 'Staff assignment updated',
        selectedEmployeeId: employeeId,
      );
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e, fallback: 'Unable to reassign staff.'),
      );
    }
  }

  Future<void> advanceOnboarding(String employeeId, OnboardingStep step) async {
    state = state.copyWith(isBusy: true);
    final progress = await _service.completeOnboardingStep(
      employeeId,
      step,
      actorId: ref.read(identitySessionProvider).userId,
    );
    ref.invalidate(organizationSnapshotProvider);
    state = state.copyWith(
      isBusy: false,
      message: progress.isComplete
          ? 'Onboarding complete — account activated'
          : 'Completed: ${step.label}',
    );
  }

  Future<StaffInvitation?> inviteStaff({
    required String email,
    required String roleSlug,
    String? firstName,
    String? lastName,
    String? phone,
    String? departmentId,
    String? teamId,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      final invite = await _service.inviteStaff(
        email: email,
        roleSlug: roleSlug,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        departmentId: departmentId,
        teamId: teamId,
      );
      ref.invalidate(organizationSnapshotProvider);
      final msg = invite.status == 'accepted'
          ? 'Role assigned to existing account ${invite.email} (${invite.roleLabel}).'
          : 'Invitation sent to ${invite.email} as ${invite.roleLabel}. Directory will update in realtime.';
      state = state.copyWith(
        isBusy: false,
        message: msg,
        hubTab: 3,
      );
      return invite;
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e, fallback: 'Unable to complete staff invite.'),
      );
      return null;
    }
  }

  Future<PortalInvitation?> invitePortalUser({
    required String email,
    required String roleSlug,
    String? firstName,
    String? lastName,
    String? phone,
    String? crmClientId,
    String? investorId,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      final invite = await _service.invitePortalUser(
        email: email,
        roleSlug: roleSlug,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        crmClientId: crmClientId,
        investorId: investorId,
      );
      ref.invalidate(organizationSnapshotProvider);
      final msg = invite.status == 'accepted'
          ? 'Portal access linked for ${invite.email} (${invite.roleLabel}).'
          : 'Portal invite ready for ${invite.email} (${invite.roleLabel}). Copy the link to share.';
      state = state.copyWith(
        isBusy: false,
        message: msg,
        hubTab: 3,
      );
      return invite;
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e, fallback: 'Unable to complete portal invite.'),
      );
      return null;
    }
  }

  Future<StaffInvitation?> revealInviteToken(String inviteId) async {
    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      final revealed = await _service.revealStaffInviteToken(inviteId);
      state = state.copyWith(
        isBusy: false,
        message: 'Invite link ready — copy and share securely.',
      );
      return revealed;
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e, fallback: 'Unable to reveal invite link.'),
      );
      return null;
    }
  }

  Future<PortalInvitation?> revealPortalInviteToken(String inviteId) async {
    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      final revealed = await _service.revealPortalInviteToken(inviteId);
      state = state.copyWith(
        isBusy: false,
        message: 'Portal invite link ready — copy and share securely.',
      );
      return revealed;
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e, fallback: 'Unable to reveal portal invite link.'),
      );
      return null;
    }
  }

  Future<void> revokeInvite(String inviteId) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _service.revokeStaffInvite(inviteId);
      ref.invalidate(organizationSnapshotProvider);
      state = state.copyWith(isBusy: false, message: 'Invite revoked.');
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: e is AppException ? e.message : e.toString(),
      );
    }
  }

  Future<StaffInvitation?> resendInvite(String inviteId) async {
    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      final invite = await _service.resendStaffInvite(inviteId);
      ref.invalidate(organizationSnapshotProvider);
      state = state.copyWith(
        isBusy: false,
        message: 'Invitation resent to ${invite.email}.',
        hubTab: 3,
      );
      return invite;
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e, fallback: 'Unable to resend invitation.'),
      );
      return null;
    }
  }

  Future<void> revokePortalInvite(String inviteId) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _service.revokePortalInvite(inviteId);
      ref.invalidate(organizationSnapshotProvider);
      state = state.copyWith(isBusy: false, message: 'Portal invite revoked.');
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: e is AppException ? e.message : e.toString(),
      );
    }
  }
}
