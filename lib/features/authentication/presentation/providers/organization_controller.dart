import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/organization_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/organization_service.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/audit_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

final staffDirectoryFilterProvider =
    NotifierProvider<StaffDirectoryFilterNotifier, StaffDirectoryFilter>(
  StaffDirectoryFilterNotifier.new,
);

class StaffDirectoryFilter {
  const StaffDirectoryFilter({
    this.query,
    this.departmentId,
    this.status,
    this.branchId,
  });

  final String? query;
  final String? departmentId;
  final StaffStatus? status;
  final String? branchId;

  StaffDirectoryFilter copyWith({
    String? query,
    String? departmentId,
    StaffStatus? status,
    String? branchId,
    bool clearQuery = false,
    bool clearDepartment = false,
    bool clearStatus = false,
    bool clearBranch = false,
  }) {
    return StaffDirectoryFilter(
      query: clearQuery ? null : (query ?? this.query),
      departmentId:
          clearDepartment ? null : (departmentId ?? this.departmentId),
      status: clearStatus ? null : (status ?? this.status),
      branchId: clearBranch ? null : (branchId ?? this.branchId),
    );
  }
}

class StaffDirectoryFilterNotifier extends Notifier<StaffDirectoryFilter> {
  @override
  StaffDirectoryFilter build() => const StaffDirectoryFilter();

  void setQuery(String? query) => state = state.copyWith(
        query: query,
        clearQuery: query == null || query.trim().isEmpty,
      );

  void setDepartment(String? id) => state = state.copyWith(
        departmentId: id,
        clearDepartment: id == null,
      );

  void setStatus(StaffStatus? status) => state = state.copyWith(
        status: status,
        clearStatus: status == null,
      );

  void setBranch(String? id) =>
      state = state.copyWith(branchId: id, clearBranch: id == null);
}

final filteredStaffProvider = Provider<AsyncValue<List<Employee>>>((ref) {
  final filter = ref.watch(staffDirectoryFilterProvider);
  return ref.watch(organizationSnapshotProvider).whenData((snap) {
    return OrganizationEngine.searchDirectory(
      snap.employees,
      query: filter.query,
      departmentId: filter.departmentId,
      status: filter.status,
      branchId: filter.branchId,
    );
  });
});

final organizationRealtimeProvider = Provider<void>((ref) {
  RealtimeChannel? channel;
  channel = ref.read(organizationServiceProvider).subscribeOrgChanges(() {
    ref.invalidate(organizationSnapshotProvider);
    ref.invalidate(orgChartProvider);
  });
  ref.onDispose(() => channel?.unsubscribe());
});

class OrganizationUiState {
  const OrganizationUiState({
    this.isBusy = false,
    this.message,
    this.error,
    this.selectedEmployeeId,
    this.hubTab = 0,
  });

  final bool isBusy;
  final String? message;
  final String? error;
  final String? selectedEmployeeId;
  final int hubTab;

  OrganizationUiState copyWith({
    bool? isBusy,
    String? message,
    String? error,
    String? selectedEmployeeId,
    int? hubTab,
    bool clearMessage = false,
    bool clearError = false,
  }) {
    return OrganizationUiState(
      isBusy: isBusy ?? this.isBusy,
      message: clearMessage ? null : (message ?? this.message),
      error: clearError ? null : (error ?? this.error),
      selectedEmployeeId: selectedEmployeeId ?? this.selectedEmployeeId,
      hubTab: hubTab ?? this.hubTab,
    );
  }
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

  Future<void> createEmployee({
    required String firstName,
    required String lastName,
    String? email,
    String? phone,
    String? departmentId,
    String? teamId,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final actorId = ref.read(identitySessionProvider).userId;
      final employee = await _service.upsertStaffRecord(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        departmentId: departmentId,
        teamId: teamId,
        actorId: actorId,
      );
      ref.invalidate(organizationSnapshotProvider);
      ref.invalidate(orgChartProvider);
      state = state.copyWith(
        isBusy: false,
        message: 'Created ${employee.employeeCode} — ${employee.displayName}',
        selectedEmployeeId: employee.id,
      );
    } catch (e) {
      state = state.copyWith(isBusy: false, error: e.toString());
    }
  }

  Future<void> changeStatus(String employeeId, StaffStatus status) async {
    state = state.copyWith(isBusy: true);
    await _service.updateStaffStatus(
      employeeId,
      status,
      actorId: ref.read(identitySessionProvider).userId,
    );
    ref.invalidate(organizationSnapshotProvider);
    ref.invalidate(orgChartProvider);
    state = state.copyWith(
      isBusy: false,
      message: 'Status updated to ${status.label}',
    );
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
}
