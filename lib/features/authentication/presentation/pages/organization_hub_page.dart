import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/permissions.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/core/widgets/feedback/app_dialogs.dart';
import 'package:hdhomesproject/features/admin/presentation/widgets/admin_desk_shell.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/mfa_models.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/organization_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/organization_service.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/staff_employee_form_dialog.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/staff_invite_wizard_dialog.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/org_structure_form_dialogs.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/platform_user_models.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/rbac_models.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/organization_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/platform_users_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/rbac_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/people_rbac_realtime_provider.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/people_rbac_security_gate.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/permission_gate.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Organization Hub — staff directory, departments, teams, and invites.
/// Platform auth accounts live at [RoutePaths.dashboardPlatformUsers].
class OrganizationHubPage extends HookConsumerWidget {
  const OrganizationHubPage({super.key});

  Future<void> _openAddStaff(
    BuildContext context,
    WidgetRef ref,
    OrganizationSnapshot snap,
  ) async {
    final controller = ref.read(organizationControllerProvider.notifier);
    final ui = ref.read(organizationControllerProvider);
    final session = ref.read(identitySessionProvider);
    final isSuperAdmin = session.hasRole(AppRole.superAdmin);
    final isAdmin = session.hasRole(AppRole.admin) || isSuperAdmin;
    final roleOptions = <(String, String)>[
      if (isSuperAdmin) ('admin', 'Admin'),
      if (isAdmin) ...[
        ('sales_team', 'Sales Team'),
        ('finance', 'Finance'),
        ('marketing', 'Marketing'),
        ('construction_manager', 'Construction Manager'),
      ],
    ];
    if (roleOptions.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to invite staff roles.'),
        ),
      );
      return;
    }
    final result = await showStaffInviteWizard(
      context: context,
      snap: snap,
      roleOptions: roleOptions,
      isBusy: ui.isBusy,
    );
    if (result == null) return;
    await controller.inviteStaff(
      email: result.email,
      roleSlug: result.roleSlug,
      firstName: result.firstName,
      lastName: result.lastName,
      phone: result.phone,
      departmentId: result.departmentId,
      teamId: result.teamId,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapAsync = ref.watch(organizationSnapshotProvider);
    final ui = ref.watch(organizationControllerProvider);
    final controller = ref.read(organizationControllerProvider.notifier);
    final tab = useState(ui.hubTab.clamp(0, 4));
    final configured = ref.watch(supabaseConfiguredProvider);
    final rt = ref.watch(peopleRbacRealtimeConnectionProvider);
    final rtEvent = ref.watch(peopleRbacRealtimeEventProvider);
    final live = rt == PeopleRbacRealtimeConnection.live;
    final rtLabel = switch (rt) {
      PeopleRbacRealtimeConnection.live => 'Your latest records are here.',
      PeopleRbacRealtimeConnection.connecting =>
        "We're gathering the latest records.",
      PeopleRbacRealtimeConnection.error =>
        "We'll refresh this when the connection is back.",
      PeopleRbacRealtimeConnection.offline =>
        "We'll refresh this when the connection is back.",
    };

    return snapAsync.when(
      loading: () => const ColoredBox(
        color: AdminDeskColors.bg,
        child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      ),
      error: (e, _) => ColoredBox(
        color: AdminDeskColors.bg,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.users, color: AppColors.error, size: 28),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  userFacingError(
                    e,
                    fallback: 'Unable to load organization data.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => ref.invalidate(organizationSnapshotProvider),
                icon: const Icon(LucideIcons.refreshCw, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (snap) {
        final pendingInvites = snap.analytics.pendingInvitations;
        final inviteBadge =
            snap.invitations.where((i) => i.isActionablePending).length +
            snap.portalInvitations.where((i) => i.isActionablePending).length;

        return AdminDeskPage(
          overline: 'People & organization',
          title: 'Organization & Staff',
          subtitle:
              'Manage your people, teams, departments and staff access in real time.',
          breadcrumb: const _OrgBreadcrumb(),
          showRemotePill: false,
          live: live,
          fromRemote: configured,
          liveLabel: rtLabel,
          remoteLabel: configured
              ? '${snap.employees.length} staff loaded'
              : 'Not connected',
          onRefresh: () => ref.invalidate(organizationSnapshotProvider),
          message: ui.message ?? rtEvent,
          onDismissMessage: () {
            controller.clearFeedback();
            ref.read(peopleRbacRealtimeEventProvider.notifier).state = null;
          },
          error: ui.error,
          kpis: [
            AdminDeskKpi(
              label: 'Total Employees',
              value: '${snap.analytics.totalEmployees}',
              subtitle: '+${snap.analytics.newHiresThisMonth} this month',
              icon: LucideIcons.users,
            ),
            AdminDeskKpi(
              label: 'Active Staff',
              value: '${snap.analytics.activeStaff}',
              subtitle:
                  '${snap.analytics.activeRate.toStringAsFixed(0)}% active',
              icon: LucideIcons.userCheck,
              accent: AdminDeskColors.green,
            ),
            AdminDeskKpi(
              label: 'Departments',
              value: '${snap.analytics.departmentsConfigured}',
              subtitle: 'Configured',
              icon: LucideIcons.building2,
              accent: const Color(0xFF3B82F6),
              onTap: () {
                tab.value = 1;
                controller.setTab(1);
              },
            ),
            AdminDeskKpi(
              label: 'On Leave',
              value: '${snap.analytics.onLeave}',
              subtitle: 'Currently',
              icon: LucideIcons.calendar,
              accent: const Color(0xFFA855F7),
            ),
            AdminDeskKpi(
              label: 'Pending Invitations',
              value: '$pendingInvites',
              subtitle: pendingInvites == 0 ? 'None waiting' : 'Require action',
              icon: LucideIcons.mail,
              accent: pendingInvites > 0
                  ? const Color(0xFF14B8A6)
                  : AdminDeskColors.muted,
              onTap: () {
                tab.value = 3;
                controller.setTab(3);
              },
            ),
          ],
          tabs: [
            const AdminDeskTab(label: 'Directory', icon: LucideIcons.users),
            const AdminDeskTab(
              label: 'Departments',
              icon: LucideIcons.building2,
            ),
            const AdminDeskTab(label: 'Teams', icon: LucideIcons.users2),
            AdminDeskTab(
              label: 'Invitations',
              icon: LucideIcons.mail,
              badge: inviteBadge > 0 ? inviteBadge : null,
            ),
            const AdminDeskTab(label: 'Attendance', icon: LucideIcons.clock),
          ],
          selectedTab: tab.value.clamp(0, 4),
          onTabSelected: (i) {
            tab.value = i;
            if (i <= 3) controller.setTab(i);
          },
          actions: [
            IconButton(
              tooltip: 'Audit logs',
              onPressed: () => context.go(peopleRbacActivityLogsPath()),
              style: IconButton.styleFrom(
                backgroundColor: AdminDeskColors.elevated,
                side: const BorderSide(color: AdminDeskColors.border),
              ),
              icon: const Icon(
                LucideIcons.barChart3,
                color: AdminDeskColors.muted,
                size: 18,
              ),
            ),
            Text(
              rtLabel,
              style: const TextStyle(
                color: AdminDeskColors.muted,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
            PermissionGateAny(
              permissions: const [
                PermissionSlugs.manageStaff,
                PermissionSlugs.manageOrganization,
                PermissionSlugs.manageUsers,
              ],
              child: FilledButton.icon(
                onPressed: ui.isBusy
                    ? null
                    : () => _openAddStaff(context, ref, snap),
                icon: const Icon(LucideIcons.userPlus, size: 16),
                label: const Text('Add Staff'),
                style: FilledButton.styleFrom(
                  backgroundColor: AdminDeskColors.gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
          body: switch (tab.value.clamp(0, 4)) {
            0 => _DirectoryTab(snap: snap, configured: configured),
            1 => _DepartmentsTab(snap: snap),
            2 => _TeamsTab(snap: snap),
            3 => _InvitesTab(snap: snap),
            _ => const _AttendanceLinkPanel(),
          },
        );
      },
    );
  }
}

class _OrgBreadcrumb extends StatelessWidget {
  const _OrgBreadcrumb();

  @override
  Widget build(BuildContext context) {
    TextStyle muted() => const TextStyle(
      color: AdminDeskColors.muted,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Dashboard', style: muted()),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(
            LucideIcons.chevronRight,
            size: 12,
            color: AdminDeskColors.muted,
          ),
        ),
        Text('Users', style: muted()),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(
            LucideIcons.chevronRight,
            size: 12,
            color: AdminDeskColors.muted,
          ),
        ),
        const Text(
          'Organization & Staff',
          style: TextStyle(
            color: AdminDeskColors.gold,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _AttendanceLinkPanel extends StatelessWidget {
  const _AttendanceLinkPanel();

  @override
  Widget build(BuildContext context) {
    return AdminDeskEmptyState(
      icon: LucideIcons.clock,
      title: 'Attendance',
      message:
          'Open any staff member in Directory to see today’s attendance status from the existing attendance records. The full attendance workspace is not duplicated here.',
    );
  }
}

class _DirectoryTab extends HookConsumerWidget {
  const _DirectoryTab({required this.snap, required this.configured});

  final OrganizationSnapshot snap;
  final bool configured;

  static const _tableMinWidth = 1080.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(staffDirectoryFilterProvider);
    final filterCtrl = ref.read(staffDirectoryFilterProvider.notifier);
    final filtered =
        ref.watch(filteredStaffProvider).valueOrNull ?? snap.employees;
    final paged = ref.watch(pagedStaffProvider).valueOrNull ?? filtered;
    final ui = ref.watch(organizationControllerProvider);
    final orgCtrl = ref.read(organizationControllerProvider.notifier);

    final queryCtrl = useTextEditingController(text: filter.query ?? '');
    final totalPages = filtered.isEmpty
        ? 1
        : (filtered.length / filter.pageSize).ceil();
    final rangeStart = filtered.isEmpty ? 0 : filter.page * filter.pageSize + 1;
    final rangeEnd = filtered.isEmpty
        ? 0
        : filter.page * filter.pageSize + paged.length;
    final hasActiveFilters =
        filter.query?.trim().isNotEmpty == true ||
        filter.status != null ||
        filter.departmentId != null ||
        filter.teamId != null ||
        filter.roleSlug != null ||
        filter.branchId != null;

    final roleFilters =
        snap.employees
            .map((e) => e.roleSlug)
            .whereType<String>()
            .where((r) => r.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final teamsForFilter = snap.teams
        .where(
          (t) =>
              filter.departmentId == null ||
              t.departmentId == filter.departmentId,
        )
        .toList();

    InputDecoration fieldDecoration({
      required String label,
      Widget? prefixIcon,
    }) {
      return InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AdminDeskColors.muted, fontSize: 12),
        prefixIcon: prefixIcon,
        isDense: true,
        filled: true,
        fillColor: AdminDeskColors.elevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AdminDeskColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AdminDeskColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AdminDeskColors.gold),
        ),
      );
    }

    Future<void> openDetailSheet(Employee e) async {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AdminDeskColors.bg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) => SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.9,
          child: _EmployeeDetail(
            employee: e,
            snap: snap,
            showCloseButton: true,
          ),
        ),
      );
    }

    void viewEmployee(Employee e) {
      orgCtrl.selectEmployee(e.id);
      openDetailSheet(e);
    }

    Future<void> editEmployee(Employee e) async {
      final result = await showStaffEmployeeFormDialog(
        context: context,
        snap: snap,
        employee: e,
        isBusy: ui.isBusy,
      );
      if (result == null) return;
      await orgCtrl.updateEmployee(
        employeeId: e.id,
        firstName: result.firstName,
        lastName: result.lastName,
        email: result.email,
        phone: result.phone,
        jobTitle: result.jobTitle,
        departmentId: result.departmentId,
        teamId: result.teamId,
        managerId: result.managerId,
        branchId: result.branchId,
        clearDepartment: result.clearDepartment,
        clearTeam: result.clearTeam,
        clearManager: result.clearManager,
        clearBranch: result.clearBranch,
      );
    }

    Future<void> toggleActive(Employee e, StaffStatus status) async {
      final inactive = status.isDeactivated || status == StaffStatus.inactive;
      if (inactive) {
        final ok = await AppDialogs.confirm(
          context,
          title: 'Reactivate ${e.displayName}?',
          message:
              'They will regain portal access according to their assigned role.',
          confirmLabel: 'Reactivate',
        );
        if (ok != true) return;
        await orgCtrl.reactivateEmployee(e.id);
        return;
      }
      final ok = await AppDialogs.confirm(
        context,
        title: 'Deactivate ${e.displayName}?',
        message:
            'Role: ${e.roleSlug ?? '—'} · Department: ${e.departmentName ?? '—'}\n\n'
            'This sets the employee inactive and revokes active portal role grants. '
            'Historical attendance, audit, and documents are preserved. You can reactivate later.',
        confirmLabel: 'Deactivate',
        destructive: true,
      );
      if (ok != true) return;
      await orgCtrl.deactivateEmployee(
        e.id,
        reason: 'Deactivated from Staff Directory',
      );
    }

    Widget pill(String? label, Color color) {
      final text = (label == null || label.trim().isEmpty) ? '—' : label;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    Color tagColor(String? key, {Color fallback = AdminDeskColors.muted}) {
      if (key == null || key.trim().isEmpty) return fallback;
      const palette = <Color>[
        Color(0xFF2563EB),
        Color(0xFF7C3AED),
        Color(0xFF0891B2),
        Color(0xFFDB2777),
        Color(0xFFCA8A04),
        Color(0xFF16A34A),
        Color(0xFFD97706),
      ];
      return palette[key.hashCode.abs() % palette.length];
    }

    Widget headerCell(String label, {int flex = 1, double? width}) {
      final child = Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AdminDeskColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      );
      if (width != null) {
        return SizedBox(width: width, child: child);
      }
      return Expanded(flex: flex, child: child);
    }

    Widget staffTable() {
      return LayoutBuilder(
        builder: (context, constraints) {
          final needsScroll = constraints.maxWidth < _tableMinWidth;
          final tableWidth = needsScroll
              ? _tableMinWidth
              : constraints.maxWidth;

          Widget buildRows() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 36,
                        child: Icon(
                          LucideIcons.square,
                          size: 14,
                          color: AdminDeskColors.muted,
                        ),
                      ),
                      headerCell('Staff', flex: 3),
                      headerCell('Department', flex: 2),
                      headerCell('Team', flex: 2),
                      headerCell('Role', flex: 2),
                      headerCell('Status', flex: 2),
                      headerCell('Last Active', flex: 2),
                      const SizedBox(
                        width: 48,
                        child: Text(
                          'ACTIONS',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: AdminDeskColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AdminDeskColors.border),
                Expanded(
                  child: filtered.isEmpty
                      ? AdminDeskEmptyState(
                          icon: LucideIcons.users,
                          title: configured && hasActiveFilters
                              ? 'No matching staff'
                              : configured
                              ? 'No staff records yet'
                              : "Can't load the directory right now",
                          message: configured && hasActiveFilters
                              ? 'Adjust your search or clear the active filters.'
                              : configured
                              ? 'Add a staff record or send an invite to populate the directory.'
                              : "Updates will refresh when you're back online.",
                          action: configured && hasActiveFilters
                              ? OutlinedButton.icon(
                                  onPressed: () {
                                    queryCtrl.clear();
                                    filterCtrl.clearAll();
                                  },
                                  icon: const Icon(
                                    LucideIcons.filterX,
                                    size: 16,
                                  ),
                                  label: const Text('Clear Filters'),
                                )
                              : null,
                        )
                      : ListView.separated(
                          itemCount: paged.length,
                          separatorBuilder: (_, _) => const Divider(
                            height: 1,
                            color: AdminDeskColors.border,
                          ),
                          itemBuilder: (context, index) {
                            final e = paged[index];
                            final status = ui.overrideStatus(e.id) ?? e.status;
                            final inactive =
                                status.isDeactivated ||
                                status == StaffStatus.inactive;
                            final isSelected = ui.selectedEmployeeId == e.id;
                            final roleLabel =
                                e.roleSlug?.replaceAll('_', ' ') ?? '—';
                            final hasPresence =
                                status.isOperational &&
                                e.userId != null &&
                                e.userId!.isNotEmpty;

                            return Material(
                              color: isSelected
                                  ? AdminDeskColors.gold.withValues(alpha: 0.08)
                                  : (index.isOdd
                                        ? AdminDeskColors.elevated.withValues(
                                            alpha: 0.35,
                                          )
                                        : Colors.transparent),
                              child: InkWell(
                                onTap: () => viewEmployee(e),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 36,
                                        child: Icon(
                                          isSelected
                                              ? LucideIcons.checkSquare
                                              : LucideIcons.square,
                                          size: 16,
                                          color: isSelected
                                              ? AdminDeskColors.gold
                                              : AdminDeskColors.muted,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 18,
                                              backgroundColor: status.color
                                                  .withValues(alpha: 0.15),
                                              backgroundImage:
                                                  e.avatarUrl != null
                                                  ? NetworkImage(e.avatarUrl!)
                                                  : null,
                                              child: e.avatarUrl == null
                                                  ? Text(
                                                      e.initials,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    )
                                                  : null,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    e.displayName,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  Text(
                                                    '${e.employeeCode} · ${e.email ?? '—'}',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color:
                                                          AdminDeskColors.muted,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: pill(
                                            e.departmentName,
                                            tagColor(
                                              e.departmentName ??
                                                  e.departmentId,
                                              fallback: const Color(0xFFCA8A04),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: pill(
                                            e.teamName,
                                            tagColor(
                                              e.teamName ?? e.teamId,
                                              fallback:
                                                  AdminDeskColors.elevated,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: pill(
                                            roleLabel == '—' ? null : roleLabel,
                                            tagColor(e.roleSlug),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: pill(
                                            status.label,
                                            status.color,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 7,
                                              height: 7,
                                              decoration: BoxDecoration(
                                                color: hasPresence
                                                    ? AdminDeskColors.green
                                                    : AdminDeskColors.muted,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                hasPresence ? 'Online' : 'N/A',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: hasPresence
                                                      ? Colors.white
                                                      : AdminDeskColors.muted,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: 48,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: PopupMenuButton<String>(
                                            tooltip: 'Actions',
                                            enabled: !ui.isBusy,
                                            icon: const Icon(
                                              LucideIcons.moreHorizontal,
                                              size: 18,
                                              color: AdminDeskColors.muted,
                                            ),
                                            color: AdminDeskColors.elevated,
                                            onSelected: (value) async {
                                              switch (value) {
                                                case 'view':
                                                  viewEmployee(e);
                                                case 'edit':
                                                  await editEmployee(e);
                                                case 'toggle':
                                                  await toggleActive(e, status);
                                              }
                                            },
                                            itemBuilder: (context) => [
                                              const PopupMenuItem(
                                                value: 'view',
                                                child: Text('View'),
                                              ),
                                              const PopupMenuItem(
                                                value: 'edit',
                                                child: Text('Edit'),
                                              ),
                                              PopupMenuItem(
                                                value: 'toggle',
                                                child: Text(
                                                  inactive
                                                      ? 'Reactivate'
                                                      : 'Deactivate',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          }

          final body = SizedBox(width: tableWidth, child: buildRows());
          if (!needsScroll) return body;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: body,
          );
        },
      );
    }

    final list = AdminDeskPanel(
      fill: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: queryCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration:
                        fieldDecoration(
                          label: 'Search',
                          prefixIcon: const Icon(
                            LucideIcons.search,
                            size: 16,
                            color: AdminDeskColors.muted,
                          ),
                        ).copyWith(
                          hintText: 'Search staff, email, employee ID…',
                          hintStyle: const TextStyle(
                            color: AdminDeskColors.muted,
                            fontSize: 13,
                          ),
                        ),
                    onChanged: filterCtrl.setQuery,
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<String?>(
                    value: filter.departmentId,
                    isExpanded: true,
                    dropdownColor: AdminDeskColors.elevated,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: fieldDecoration(label: 'All Departments'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Departments'),
                      ),
                      for (final d in snap.departments)
                        DropdownMenuItem<String?>(
                          value: d.id,
                          child: Text(d.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (id) {
                      filterCtrl.setDepartment(id);
                      filterCtrl.setTeam(null);
                    },
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<String?>(
                    value: filter.teamId,
                    isExpanded: true,
                    dropdownColor: AdminDeskColors.elevated,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: fieldDecoration(label: 'All Teams'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Teams'),
                      ),
                      for (final t in teamsForFilter)
                        DropdownMenuItem<String?>(
                          value: t.id,
                          child: Text(t.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: filterCtrl.setTeam,
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<String?>(
                    value: filter.roleSlug,
                    isExpanded: true,
                    dropdownColor: AdminDeskColors.elevated,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: fieldDecoration(label: 'All Roles'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Roles'),
                      ),
                      for (final r in roleFilters)
                        DropdownMenuItem<String?>(
                          value: r,
                          child: Text(
                            r.replaceAll('_', ' '),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: filterCtrl.setRole,
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<StaffStatus?>(
                    value: filter.status,
                    isExpanded: true,
                    dropdownColor: AdminDeskColors.elevated,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: fieldDecoration(label: 'All Statuses'),
                    items: [
                      const DropdownMenuItem<StaffStatus?>(
                        value: null,
                        child: Text('All Statuses'),
                      ),
                      for (final s in [
                        StaffStatus.invited,
                        StaffStatus.onboarding,
                        StaffStatus.active,
                        StaffStatus.onLeave,
                        StaffStatus.remote,
                        StaffStatus.probation,
                        StaffStatus.suspended,
                        StaffStatus.inactive,
                      ])
                        DropdownMenuItem<StaffStatus?>(
                          value: s,
                          child: Text(s.label),
                        ),
                    ],
                    onChanged: filterCtrl.setStatus,
                  ),
                ),
                if (snap.branches.isNotEmpty)
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<String?>(
                      value: filter.branchId,
                      isExpanded: true,
                      dropdownColor: AdminDeskColors.elevated,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: fieldDecoration(label: 'All Locations'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Locations'),
                        ),
                        for (final b in snap.branches)
                          DropdownMenuItem<String?>(
                            value: b.id,
                            child: Text(
                              b.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: filterCtrl.setBranch,
                    ),
                  ),
                TextButton.icon(
                  onPressed: hasActiveFilters
                      ? () {
                          queryCtrl.clear();
                          filterCtrl.clearAll();
                        }
                      : null,
                  icon: const Icon(LucideIcons.filterX, size: 16),
                  label: const Text('Clear Filters'),
                  style: TextButton.styleFrom(
                    foregroundColor: AdminDeskColors.gold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AdminDeskColors.border),
          Expanded(child: staffTable()),
          if (filtered.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Showing $rangeStart–$rangeEnd of ${filtered.length} staff',
                      style: const TextStyle(
                        color: AdminDeskColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Previous page',
                    onPressed: filter.page <= 0
                        ? null
                        : filterCtrl.previousPage,
                    icon: const Icon(LucideIcons.chevronLeft, size: 18),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AdminDeskColors.gold,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${filter.page + 1}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next page',
                    onPressed: filter.page + 1 >= totalPages
                        ? null
                        : () => filterCtrl.nextPage(filtered.length),
                    icon: const Icon(LucideIcons.chevronRight, size: 18),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    return list;
  }
}

class _StaffAdditionalRoles extends ConsumerWidget {
  const _StaffAdditionalRoles({required this.employee});

  final Employee employee;

  static const _staffSlugs = {
    'super_admin',
    'admin',
    'sales_team',
    'finance',
    'marketing',
    'construction_manager',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = employee.userId?.trim();
    if (userId == null || userId.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text(
          'This staff member has no login yet. Send an invite before adding extra access.',
          style: TextStyle(
            color: Color(0xFF8B929E),
            fontSize: 12,
            height: 1.35,
          ),
        ),
      );
    }

    final roles =
        ref.watch(rbacSnapshotProvider).valueOrNull?.roles ??
        const <RoleDefinition>[];
    final accounts =
        ref.watch(platformUsersSnapshotProvider).valueOrNull?.users ??
        const <PlatformUser>[];
    PlatformUser? match;
    for (final user in accounts) {
      if (user.id == userId) {
        match = user;
        break;
      }
    }
    final assignedIds = <String>{
      for (final role in match?.roles ?? const <PlatformUserRoleAssignment>[])
        role.roleId,
    };
    final current = match?.roles ?? const <PlatformUserRoleAssignment>[];
    final available = [
      for (final role in roles)
        if (_staffSlugs.contains(role.slug) && !assignedIds.contains(role.id))
          role,
    ];
    final busy = ref.watch(platformUsersControllerProvider).isBusy;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Additional access',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          const Text(
            'Add another staff role without removing the one they already have.',
            style: TextStyle(color: Color(0xFF8B929E), fontSize: 12),
          ),
          const SizedBox(height: 8),
          if (current.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final role in current)
                  Chip(
                    label: Text(
                      role.isPrimary
                          ? '${role.roleName} · primary'
                          : role.roleName,
                      style: const TextStyle(fontSize: 12),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          if (available.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Every staff role is already on this account.',
                style: TextStyle(color: Color(0xFF8B929E), fontSize: 12),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final role in available)
                    ActionChip(
                      avatar: const Icon(LucideIcons.plus, size: 14),
                      label: Text('Add ${role.name}'),
                      onPressed: busy
                          ? null
                          : () async {
                              final elevated = isElevatedRoleSlug(role.slug);
                              final ok = await AppDialogs.confirm(
                                context,
                                title: elevated
                                    ? 'Add elevated role?'
                                    : 'Add ${role.name}?',
                                message:
                                    'Give ${employee.displayName} ${role.name} in addition to their current access.',
                                confirmLabel: 'Add role',
                                destructive: elevated,
                              );
                              if (ok != true || !context.mounted) return;
                              if (elevated) {
                                final stepped = await ensurePeopleRbacStepUp(
                                  context: context,
                                  ref: ref,
                                  action: StepUpAction.createAdmin,
                                );
                                if (!stepped || !context.mounted) return;
                              }
                              await ref
                                  .read(
                                    platformUsersControllerProvider.notifier,
                                  )
                                  .assignRole(
                                    userId: userId,
                                    role: role,
                                    isPrimary: current.isEmpty,
                                  );
                            },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EmployeeDetail extends ConsumerWidget {
  const _EmployeeDetail({
    required this.employee,
    required this.snap,
    this.showCloseButton = false,
  });

  final Employee employee;
  final OrganizationSnapshot snap;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(organizationControllerProvider.notifier);
    final ui = ref.watch(organizationControllerProvider);
    final chain = OrganizationEngine.reportingChain(
      snap.employees,
      employee.id,
    );
    final reports = OrganizationEngine.directReports(
      snap.employees,
      employee.id,
    );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        if (showCloseButton)
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Close staff details',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(LucideIcons.x),
            ),
          ),
        Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.gold.withValues(alpha: 0.2),
              child: Text(
                employee.initials,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employee.displayName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    '${employee.positionTitle ?? 'Staff'} · ${employee.status.label}',
                    style: TextStyle(color: employee.status.color),
                  ),
                  if (employee.roleSlug != null)
                    Text(
                      'Role: ${employee.roleSlug}',
                      style: const TextStyle(
                        color: Color(0xFF8B929E),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            Flexible(
              child: PermissionGateAny(
                permissions: const [
                  PermissionSlugs.manageStaff,
                  PermissionSlugs.manageOrganization,
                ],
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: ui.isBusy
                          ? null
                          : () async {
                              final result = await showStaffEmployeeFormDialog(
                                context: context,
                                snap: snap,
                                employee: employee,
                                isBusy: ui.isBusy,
                              );
                              if (result == null) return;
                              await controller.updateEmployee(
                                employeeId: employee.id,
                                firstName: result.firstName,
                                lastName: result.lastName,
                                email: result.email,
                                phone: result.phone,
                                jobTitle: result.jobTitle,
                                departmentId: result.departmentId,
                                teamId: result.teamId,
                                managerId: result.managerId,
                                branchId: result.branchId,
                                clearDepartment: result.clearDepartment,
                                clearTeam: result.clearTeam,
                                clearManager: result.clearManager,
                                clearBranch: result.clearBranch,
                              );
                            },
                      icon: const Icon(LucideIcons.pencil, size: 14),
                      label: const Text('Edit'),
                    ),
                    if (employee.status.isDeactivated ||
                        employee.status == StaffStatus.inactive)
                      FilledButton.icon(
                        onPressed: ui.isBusy
                            ? null
                            : () => controller.reactivateEmployee(employee.id),
                        icon: const Icon(LucideIcons.userCheck, size: 14),
                        label: const Text('Reactivate'),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: ui.isBusy
                            ? null
                            : () async {
                                final ok = await AppDialogs.confirm(
                                  context,
                                  title: 'Deactivate ${employee.displayName}?',
                                  message:
                                      'Role: ${employee.roleSlug ?? '—'} · Department: ${employee.departmentName ?? '—'}\n\n'
                                      'This sets the employee inactive and revokes active portal role grants. Historical attendance, audit, and documents are preserved. You can reactivate later.',
                                  confirmLabel: 'Deactivate',
                                  destructive: true,
                                );
                                if (ok != true) return;
                                await controller.deactivateEmployee(
                                  employee.id,
                                  reason: 'Deactivated from Staff Directory',
                                );
                              },
                        icon: const Icon(LucideIcons.userX, size: 14),
                        label: const Text('Deactivate'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        PermissionGateAny(
          permissions: const [
            PermissionSlugs.manageStaff,
            PermissionSlugs.manageOrganization,
          ],
          child: _StaffAdditionalRoles(employee: employee),
        ),
        const SizedBox(height: AppSpacing.lg),
        _info('Employee ID', employee.employeeCode),
        _info('Department', employee.departmentName ?? '—'),
        _info('Team', employee.teamName ?? '—'),
        _info(
          'Reports to',
          employee.managerName ?? chain.firstOrNull?.displayName ?? '—',
        ),
        _info('Branch', employee.branchName ?? '—'),
        _info(
          'Joined',
          employee.joinedAt == null
              ? '—'
              : DateFormat('d MMM yyyy').format(employee.joinedAt!.toLocal()),
        ),
        if (employee.email != null) _info('Email', employee.email!),
        if (employee.phone != null) _info('Phone', employee.phone!),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Attendance today',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        ref
            .watch(staffAttendanceTodayProvider(employee.id))
            .when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: AppColors.gold,
                ),
              ),
              error: (e, _) => Text(
                userFacingError(e, fallback: 'Attendance unavailable.'),
                style: const TextStyle(color: Color(0xFF8B929E), fontSize: 13),
              ),
              data: (att) {
                final timeFmt = DateFormat('HH:mm');
                final clockIn = att.clockInAt == null
                    ? '—'
                    : timeFmt.format(att.clockInAt!.toLocal());
                final clockOut = att.clockOutAt == null
                    ? '—'
                    : timeFmt.format(att.clockOutAt!.toLocal());
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141820),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x22FFFFFF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        att.hasRecord ? att.stateLabel : 'No attendance today',
                        style: TextStyle(
                          color: att.hasRecord
                              ? AppColors.gold
                              : const Color(0xFF8B929E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        att.hasRecord
                            ? 'In $clockIn · Out $clockOut'
                                  '${att.isRemote ? ' · Remote' : ''}'
                            : 'Linked to the HD Homes attendance records when the staff member clocks in.',
                        style: const TextStyle(
                          color: Color(0xFF8B929E),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        const SizedBox(height: AppSpacing.lg),
        Text('Reporting chain', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (chain.isEmpty)
          const Text('Top of hierarchy')
        else
          ...chain.map(
            (m) => ListTile(
              dense: true,
              leading: const Icon(LucideIcons.arrowUp, size: 16),
              title: Text(m.displayName),
              subtitle: Text(m.positionTitle ?? ''),
            ),
          ),
        if (reports.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Direct reports',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ...reports.map(
            (r) => ListTile(
              dense: true,
              leading: const Icon(LucideIcons.arrowDown, size: 16),
              title: Text(r.displayName),
              subtitle: Text(r.positionTitle ?? ''),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text('Update status', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        PermissionGateAny(
          permissions: const [
            PermissionSlugs.manageStaff,
            PermissionSlugs.manageOrganization,
          ],
          child: Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final s in [
                StaffStatus.active,
                StaffStatus.onLeave,
                StaffStatus.remote,
                StaffStatus.probation,
                StaffStatus.suspended,
              ])
                ActionChip(
                  label: Text(s.label),
                  onPressed: ui.isBusy || employee.status == s
                      ? null
                      : () => controller.changeStatus(employee.id, s),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                letterSpacing: 0.6,
                color: AppColors.neutral500,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

class _DepartmentsTab extends HookConsumerWidget {
  const _DepartmentsTab({required this.snap});

  final OrganizationSnapshot snap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(organizationControllerProvider);
    final controller = ref.read(organizationControllerProvider.notifier);
    final selectedId = useState<String?>(
      snap.departments.isEmpty ? null : snap.departments.first.id,
    );
    final showArchived = useState(false);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final visibleDepartments = snap.departments
        .where(
          (d) => showArchived.value || d.status != OrgEntityStatus.archived,
        )
        .toList();

    Department? selected;
    for (final d in visibleDepartments) {
      if (d.id == selectedId.value) {
        selected = d;
        break;
      }
    }
    selected ??= visibleDepartments.isEmpty ? null : visibleDepartments.first;

    final teams = selected == null
        ? const <OrgTeam>[]
        : snap.teams.where((t) => t.departmentId == selected!.id).toList();
    final members = selected == null
        ? const <Employee>[]
        : snap.employees.where((e) => e.departmentId == selected!.id).toList();

    Future<void> openCreate() async {
      final result = await showDepartmentFormDialog(
        context: context,
        snap: snap,
        isBusy: ui.isBusy,
      );
      if (result == null) return;
      await controller.createDepartment(
        name: result.name,
        description: result.description,
        headEmployeeId: result.headEmployeeId,
      );
    }

    Future<void> openEdit(Department dept) async {
      final result = await showDepartmentFormDialog(
        context: context,
        snap: snap,
        department: dept,
        isBusy: ui.isBusy,
      );
      if (result == null) return;
      await controller.updateDepartment(
        departmentId: dept.id,
        name: result.name,
        description: result.description,
        headEmployeeId: result.headEmployeeId,
        status: result.status,
        clearHead: result.clearHead,
      );
    }

    Future<void> openAssign(Department dept) async {
      final result = await showReassignStaffDialog(
        context: context,
        snap: snap,
        preferredDepartmentId: dept.id,
        isBusy: ui.isBusy,
      );
      if (result == null) return;
      await controller.reassignEmployee(
        employeeId: result.employeeId,
        departmentId: result.departmentId,
        teamId: result.teamId,
        clearDepartment: result.clearDepartment,
        clearTeam: result.clearTeam,
      );
    }

    Future<void> openDelete(Department dept) async {
      final isArchived = dept.status == OrgEntityStatus.archived;
      final ok = await AppDialogs.confirm(
        context,
        title: isArchived ? 'Restore department?' : 'Delete department?',
        message: isArchived
            ? 'Restore “${dept.name}” to active so it appears in the org structure again.'
            : [
                'Archive “${dept.name}” so it is removed from the active org structure.',
                if (dept.memberCount > 0 || dept.teamCount > 0)
                  'It currently has ${dept.memberCount} staff and ${dept.teamCount} teams — reassign them if needed before archiving.',
                'You can restore it later from Edit → Status, or with Restore.',
              ].join(' '),
        confirmLabel: isArchived ? 'Restore' : 'Delete',
        destructive: !isArchived,
      );
      if (ok != true) return;
      await controller.updateDepartment(
        departmentId: dept.id,
        status: isArchived ? OrgEntityStatus.active : OrgEntityStatus.archived,
      );
      if (!isArchived) selectedId.value = null;
    }

    final list = AdminDeskPanel(
      fill: true,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Departments',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilterChip(
                  label: const Text('Archived'),
                  selected: showArchived.value,
                  onSelected: (v) {
                    showArchived.value = v;
                    selectedId.value = null;
                  },
                ),
                const SizedBox(width: 6),
                PermissionGateAny(
                  permissions: const [
                    PermissionSlugs.manageOrganization,
                    PermissionSlugs.manageStaff,
                  ],
                  child: TextButton.icon(
                    onPressed: ui.isBusy ? null : openCreate,
                    icon: const Icon(LucideIcons.plus, size: 14),
                    label: const Text('Add'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: visibleDepartments.isEmpty
                ? const Center(
                    child: Text(
                      'No departments yet. Add one to structure your org.',
                      style: TextStyle(color: Color(0xFF8B929E)),
                    ),
                  )
                : Scrollbar(
                    thumbVisibility: false,
                    child: ListView.builder(
                      primary: false,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: visibleDepartments.length,
                      itemBuilder: (context, index) {
                        final d = visibleDepartments[index];
                        return ListTile(
                          selected: selected?.id == d.id,
                          leading: const Icon(LucideIcons.building, size: 18),
                          title: Text(d.name),
                          subtitle: Text(
                            '${d.memberCount} staff · ${d.teamCount} teams',
                          ),
                          trailing: Text(
                            d.status.slug,
                            style: TextStyle(
                              color: d.status == OrgEntityStatus.active
                                  ? AppColors.success
                                  : const Color(0xFF8B929E),
                              fontSize: 11,
                            ),
                          ),
                          onTap: () => selectedId.value = d.id,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );

    final dept = selected;
    final detail = AdminDeskPanel(
      fill: true,
      margin: const EdgeInsets.fromLTRB(0, 4, 12, 12),
      child: dept == null
          ? const Center(child: Text('Select a department'))
          : Scrollbar(
              thumbVisibility: false,
              child: ListView(
                primary: false,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: [
                  Text(
                    dept.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dept.description ?? dept.slug,
                    style: const TextStyle(color: Color(0xFF8B929E)),
                  ),
                  const SizedBox(height: 12),
                  PermissionGateAny(
                    permissions: const [
                      PermissionSlugs.manageOrganization,
                      PermissionSlugs.manageStaff,
                    ],
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: ui.isBusy ? null : () => openEdit(dept),
                          icon: const Icon(LucideIcons.pencil, size: 14),
                          label: const Text('Edit'),
                        ),
                        OutlinedButton.icon(
                          onPressed: ui.isBusy ? null : () => openAssign(dept),
                          icon: const Icon(LucideIcons.userPlus, size: 14),
                          label: const Text('Assign staff'),
                        ),
                        OutlinedButton.icon(
                          onPressed: ui.isBusy
                              ? null
                              : () async {
                                  final result = await showTeamFormDialog(
                                    context: context,
                                    snap: snap,
                                    preferredDepartmentId: dept.id,
                                    isBusy: ui.isBusy,
                                  );
                                  if (result == null) return;
                                  await controller.createTeam(
                                    name: result.name,
                                    departmentId: result.departmentId,
                                    description: result.description,
                                    teamLeadId: result.teamLeadId,
                                    branchId: result.branchId,
                                  );
                                },
                          icon: const Icon(LucideIcons.users, size: 14),
                          label: const Text('Add team'),
                        ),
                        OutlinedButton.icon(
                          onPressed: ui.isBusy ? null : () => openDelete(dept),
                          icon: Icon(
                            dept.status == OrgEntityStatus.archived
                                ? LucideIcons.rotateCcw
                                : LucideIcons.trash2,
                            size: 14,
                            color: dept.status == OrgEntityStatus.archived
                                ? null
                                : AppColors.error,
                          ),
                          label: Text(
                            dept.status == OrgEntityStatus.archived
                                ? 'Restore'
                                : 'Delete',
                            style: TextStyle(
                              color: dept.status == OrgEntityStatus.archived
                                  ? null
                                  : AppColors.error,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: dept.status == OrgEntityStatus.archived
                                  ? AdminDeskColors.border
                                  : AppColors.error.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _deskInfo('Head', dept.headEmployeeName ?? '—'),
                  _deskInfo('Status', dept.status.slug),
                  _deskInfo('Staff', '${dept.memberCount}'),
                  _deskInfo('Teams', '${dept.teamCount}'),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Teams', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (teams.isEmpty)
                    const Text(
                      'No teams in this department yet.',
                      style: TextStyle(color: Color(0xFF8B929E)),
                    )
                  else
                    ...teams.map(
                      (t) => ListTile(
                        dense: true,
                        leading: const Icon(LucideIcons.users2, size: 16),
                        title: Text(t.name),
                        subtitle: Text(
                          'Lead: ${t.teamLeadName ?? '—'} · ${t.memberCount} members',
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Staff', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (members.isEmpty)
                    const Text(
                      'No staff assigned to this department.',
                      style: TextStyle(color: Color(0xFF8B929E)),
                    )
                  else
                    ...members.map(
                      (e) => ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          child: Text(
                            e.initials,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                        title: Text(e.displayName),
                        subtitle: Text(
                          '${e.positionTitle ?? 'Staff'} · ${e.teamName ?? 'No team'}',
                        ),
                        trailing: Text(e.status.label),
                      ),
                    ),
                  if (snap.branches.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Branches',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ...snap.branches.map(
                      (b) => ListTile(
                        dense: true,
                        leading: Icon(
                          b.isPrimary
                              ? LucideIcons.landmark
                              : LucideIcons.mapPin,
                          size: 16,
                          color: AppColors.gold,
                        ),
                        title: Text(b.name),
                        subtitle: Text(
                          [
                            if (b.isPrimary) 'Primary',
                            if (b.address != null) b.address!,
                          ].join(' · '),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );

    if (!wide) {
      return selected == null
          ? list
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 2, child: list),
                Expanded(flex: 3, child: detail),
              ],
            );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 340, child: list),
        Expanded(child: detail),
      ],
    );
  }
}

class _TeamsTab extends HookConsumerWidget {
  const _TeamsTab({required this.snap});

  final OrganizationSnapshot snap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(organizationControllerProvider);
    final controller = ref.read(organizationControllerProvider.notifier);
    final deptFilter = useState<String?>(null);
    final selectedId = useState<String?>(null);

    final filtered = snap.teams
        .where(
          (t) =>
              t.status != OrgEntityStatus.archived &&
              (deptFilter.value == null || t.departmentId == deptFilter.value),
        )
        .toList();

    OrgTeam? selected;
    for (final t in filtered) {
      if (t.id == selectedId.value) {
        selected = t;
        break;
      }
    }
    selected ??= filtered.isEmpty ? null : filtered.first;

    final members = selected == null
        ? const <Employee>[]
        : snap.employees.where((e) => e.teamId == selected!.id).toList();
    final wide = MediaQuery.sizeOf(context).width >= 900;

    Future<void> openCreate() async {
      final result = await showTeamFormDialog(
        context: context,
        snap: snap,
        preferredDepartmentId: deptFilter.value,
        isBusy: ui.isBusy,
      );
      if (result == null) return;
      await controller.createTeam(
        name: result.name,
        departmentId: result.departmentId,
        description: result.description,
        teamLeadId: result.teamLeadId,
        branchId: result.branchId,
      );
    }

    Future<void> openEdit(OrgTeam team) async {
      final result = await showTeamFormDialog(
        context: context,
        snap: snap,
        team: team,
        isBusy: ui.isBusy,
      );
      if (result == null) return;
      await controller.updateTeam(
        teamId: team.id,
        name: result.name,
        departmentId: result.departmentId,
        description: result.description,
        teamLeadId: result.teamLeadId,
        branchId: result.branchId,
        status: result.status,
        clearLead: result.clearLead,
        clearBranch: result.clearBranch,
      );
    }

    Future<void> openAssign(OrgTeam team) async {
      final result = await showReassignStaffDialog(
        context: context,
        snap: snap,
        preferredDepartmentId: team.departmentId,
        preferredTeamId: team.id,
        isBusy: ui.isBusy,
      );
      if (result == null) return;
      await controller.reassignEmployee(
        employeeId: result.employeeId,
        departmentId: result.departmentId,
        teamId: result.teamId,
        clearDepartment: result.clearDepartment,
        clearTeam: result.clearTeam,
      );
    }

    Future<void> openDelete(OrgTeam team) async {
      final isArchived = team.status == OrgEntityStatus.archived;
      final ok = await AppDialogs.confirm(
        context,
        title: isArchived ? 'Restore team?' : 'Delete team?',
        message: isArchived
            ? 'Restore “${team.name}” to active.'
            : [
                'Archive “${team.name}” so it leaves the active org structure.',
                if (team.memberCount > 0)
                  'It currently has ${team.memberCount} members — reassign them if needed.',
                'You can restore it later from Edit → Status, or with Restore.',
              ].join(' '),
        confirmLabel: isArchived ? 'Restore' : 'Delete',
        destructive: !isArchived,
      );
      if (ok != true) return;
      await controller.updateTeam(
        teamId: team.id,
        status: isArchived ? OrgEntityStatus.active : OrgEntityStatus.archived,
      );
      if (!isArchived) selectedId.value = null;
    }

    final activeDepartments = snap.departments
        .where((d) => d.status != OrgEntityStatus.archived)
        .toList();

    final list = AdminDeskPanel(
      fill: true,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Teams',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                PermissionGateAny(
                  permissions: const [
                    PermissionSlugs.manageOrganization,
                    PermissionSlugs.manageStaff,
                  ],
                  child: TextButton.icon(
                    onPressed: ui.isBusy ? null : openCreate,
                    icon: const Icon(LucideIcons.plus, size: 14),
                    label: const Text('Add'),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All depts'),
                  selected: deptFilter.value == null,
                  onSelected: (_) {
                    deptFilter.value = null;
                    selectedId.value = null;
                  },
                ),
                const SizedBox(width: 8),
                for (final d in activeDepartments)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(d.name),
                      selected: deptFilter.value == d.id,
                      onSelected: (sel) {
                        deptFilter.value = sel ? d.id : null;
                        selectedId.value = null;
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No teams yet. Create one under a department.',
                      style: TextStyle(color: Color(0xFF8B929E)),
                    ),
                  )
                : Scrollbar(
                    thumbVisibility: false,
                    child: ListView.builder(
                      primary: false,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final t = filtered[index];
                        return ListTile(
                          selected: selected?.id == t.id,
                          leading: const Icon(LucideIcons.users, size: 18),
                          title: Text(t.name),
                          subtitle: Text(
                            '${t.departmentName ?? 'Department'} · ${t.memberCount} members',
                          ),
                          trailing: Text(
                            t.status.slug,
                            style: TextStyle(
                              color: t.status == OrgEntityStatus.active
                                  ? AppColors.success
                                  : const Color(0xFF8B929E),
                              fontSize: 11,
                            ),
                          ),
                          onTap: () => selectedId.value = t.id,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );

    final detail = AdminDeskPanel(
      fill: true,
      margin: const EdgeInsets.fromLTRB(0, 4, 12, 12),
      child: selected == null
          ? const Center(child: Text('Select a team'))
          : Scrollbar(
              thumbVisibility: false,
              child: ListView(
                primary: false,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: [
                  Text(
                    selected.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    selected.description ?? 'No description',
                    style: const TextStyle(color: Color(0xFF8B929E)),
                  ),
                  const SizedBox(height: 12),
                  PermissionGateAny(
                    permissions: const [
                      PermissionSlugs.manageOrganization,
                      PermissionSlugs.manageStaff,
                    ],
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: ui.isBusy
                              ? null
                              : () => openEdit(selected!),
                          icon: const Icon(LucideIcons.pencil, size: 14),
                          label: const Text('Edit'),
                        ),
                        OutlinedButton.icon(
                          onPressed: ui.isBusy
                              ? null
                              : () => openAssign(selected!),
                          icon: const Icon(LucideIcons.userPlus, size: 14),
                          label: const Text('Assign staff'),
                        ),
                        OutlinedButton.icon(
                          onPressed: ui.isBusy
                              ? null
                              : () => openDelete(selected!),
                          icon: Icon(
                            selected.status == OrgEntityStatus.archived
                                ? LucideIcons.rotateCcw
                                : LucideIcons.trash2,
                            size: 14,
                            color: selected.status == OrgEntityStatus.archived
                                ? null
                                : AppColors.error,
                          ),
                          label: Text(
                            selected.status == OrgEntityStatus.archived
                                ? 'Restore'
                                : 'Delete',
                            style: TextStyle(
                              color: selected.status == OrgEntityStatus.archived
                                  ? null
                                  : AppColors.error,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: selected.status == OrgEntityStatus.archived
                                  ? AdminDeskColors.border
                                  : AppColors.error.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _deskInfo('Department', selected.departmentName ?? '—'),
                  _deskInfo('Lead', selected.teamLeadName ?? '—'),
                  _deskInfo('Status', selected.status.slug),
                  _deskInfo('Members', '${selected.memberCount}'),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Members',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (members.isEmpty)
                    const Text(
                      'No staff on this team yet. Use Assign staff.',
                      style: TextStyle(color: Color(0xFF8B929E)),
                    )
                  else
                    ...members.map(
                      (e) => ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          child: Text(
                            e.initials,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                        title: Text(e.displayName),
                        subtitle: Text(e.positionTitle ?? 'Staff'),
                        trailing: Text(e.status.label),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );

    if (!wide) {
      return selected == null
          ? list
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 2, child: list),
                Expanded(flex: 3, child: detail),
              ],
            );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 360, child: list),
        Expanded(child: detail),
      ],
    );
  }
}

Widget _deskInfo(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 0.6,
              color: AppColors.neutral500,
            ),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _InvitesTab extends HookConsumerWidget {
  const _InvitesTab({required this.snap});

  final OrganizationSnapshot snap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(organizationControllerProvider.notifier);
    final ui = ref.watch(organizationControllerProvider);
    final session = ref.watch(identitySessionProvider);
    final isSuperAdmin = session.hasRole(AppRole.superAdmin);
    final isAdmin = session.hasRole(AppRole.admin) || isSuperAdmin;

    final email = useTextEditingController();
    final first = useTextEditingController();
    final last = useTextEditingController();
    final phone = useTextEditingController();
    final role = useState<String>(isSuperAdmin ? 'admin' : 'sales_team');
    final lastPortalInvite = useState<PortalInvitation?>(null);
    final departments = snap.departments
        .where((d) => OrganizationService.isValidUuid(d.id))
        .toList();
    final deptId = useState<String?>(
      departments.isEmpty ? null : departments.first.id,
    );
    final teamId = useState<String?>(null);
    final statusFilter = useState<String?>('pending');
    final lastInvite = useState<StaffInvitation?>(null);
    final tokenCache = useState<Map<String, String>>({});

    final canInvitePortal = hasPermissionAny(ref, const [
      PermissionSlugs.manageUsers,
      PermissionSlugs.manageCrm,
      PermissionSlugs.crmWrite,
      PermissionSlugs.investorsWrite,
    ]);
    final canInviteClient = hasPermissionAny(ref, const [
      PermissionSlugs.manageUsers,
      PermissionSlugs.manageCrm,
      PermissionSlugs.crmWrite,
    ]);
    final canInviteInvestor = hasPermissionAny(ref, const [
      PermissionSlugs.manageUsers,
      PermissionSlugs.investorsWrite,
    ]);

    final roleOptions = <(String, String)>[
      if (isSuperAdmin) ('admin', 'Admin'),
      if (isAdmin) ...[
        ('sales_team', 'Sales Team'),
        ('finance', 'Finance'),
        ('marketing', 'Marketing'),
        ('construction_manager', 'Construction Manager'),
      ],
      if (canInviteClient) ('client', 'Client Portal'),
      if (canInviteInvestor) ('investor', 'Investor Portal'),
    ];
    final isPortalRole = role.value == 'client' || role.value == 'investor';

    final teamsForDept = snap.teams
        .where((t) => deptId.value == null || t.departmentId == deptId.value)
        .toList();

    final deptById = {for (final d in snap.departments) d.id: d.name};

    final filteredInvites = snap.invitations.where((invite) {
      final effective = invite.effectiveStatus();
      final filter = statusFilter.value;
      if (filter == null) return true;
      return effective == filter;
    }).toList();
    final filteredPortalInvites = snap.portalInvitations.where((invite) {
      final effective = invite.effectiveStatus();
      final filter = statusFilter.value;
      if (filter == null) return true;
      return effective == filter;
    }).toList();

    if (!hasPermissionAny(ref, const [
      PermissionSlugs.manageStaff,
      PermissionSlugs.manageOrganization,
      PermissionSlugs.manageUsers,
      PermissionSlugs.manageCrm,
      PermissionSlugs.crmWrite,
      PermissionSlugs.investorsWrite,
    ])) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'You do not have permission to invite or manage users.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (roleOptions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'No invite roles available for your account.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    Future<StaffInvitation> ensureToken(StaffInvitation invite) async {
      final cached = tokenCache.value[invite.id];
      if (cached != null && cached.isNotEmpty) {
        return invite.copyWith(token: cached);
      }
      if (invite.hasUsableToken) {
        tokenCache.value = {...tokenCache.value, invite.id: invite.token};
        return invite;
      }
      final revealed = await controller.revealInviteToken(invite.id);
      if (revealed == null || !revealed.hasUsableToken) {
        throw const DatabaseException('Unable to prepare invite link.');
      }
      tokenCache.value = {...tokenCache.value, invite.id: revealed.token};
      return invite.copyWith(token: revealed.token);
    }

    Future<PortalInvitation> ensurePortalToken(PortalInvitation invite) async {
      final cached = tokenCache.value[invite.id];
      if (cached != null && cached.isNotEmpty) {
        return invite.copyWith(token: cached);
      }
      if (invite.hasUsableToken) {
        tokenCache.value = {...tokenCache.value, invite.id: invite.token};
        return invite;
      }
      final revealed = await controller.revealPortalInviteToken(invite.id);
      if (revealed == null || !revealed.hasUsableToken) {
        throw const DatabaseException('Unable to prepare invite link.');
      }
      tokenCache.value = {...tokenCache.value, invite.id: revealed.token};
      return invite.copyWith(token: revealed.token);
    }

    Future<void> copyLink(StaffInvitation invite) async {
      try {
        final withToken = await ensureToken(invite);
        final path = withToken.status == 'accepted'
            ? OrganizationService.inviteLoginPath(withToken)
            : OrganizationService.inviteRegisterPath(withToken);
        final link = '${Uri.base.origin}/#$path';
        await Clipboard.setData(ClipboardData(text: link));
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invite link copied')));
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
      }
    }

    Future<void> copyPortalLink(PortalInvitation invite) async {
      try {
        final withToken = await ensurePortalToken(invite);
        final path = withToken.status == 'accepted'
            ? OrganizationService.portalInviteLoginPath(withToken)
            : OrganizationService.portalInviteRegisterPath(withToken);
        final link = '${Uri.base.origin}/#$path';
        await Clipboard.setData(ClipboardData(text: link));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Portal invite link copied')),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
      }
    }

    Color statusColor(String status) => switch (status) {
      'pending' => AppColors.gold,
      'accepted' => AppColors.success,
      'revoked' => AppColors.error,
      'expired' => const Color(0xFF8B929E),
      _ => const Color(0xFF8B929E),
    };

    final wide = MediaQuery.sizeOf(context).width >= 960;

    final form = AdminDeskPanel(
      fill: true,
      child: ListView(
        primary: false,
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            'Invite people',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            canInvitePortal
                ? 'Invite staff roles or grant Client / Investor portal access. Recipients set their own password — never share permanent passwords.'
                : isSuperAdmin
                ? 'Super Admin can assign Admin. Admin can invite Sales, Finance, Marketing, and Construction Manager. Existing accounts get the role immediately.'
                : 'Invite Sales, Finance, Marketing, or Construction Manager. Share the link for new users; existing accounts get the role instantly.',
            style: const TextStyle(color: Color(0xFF8B929E)),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: isPortalRole ? 'Email *' : 'Work email *',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: first,
                  decoration: const InputDecoration(labelText: 'First name'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  controller: last,
                  decoration: const InputDecoration(labelText: 'Last name'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: phone,
            decoration: const InputDecoration(labelText: 'Phone (optional)'),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: roleOptions.any((r) => r.$1 == role.value)
                ? role.value
                : roleOptions.first.$1,
            decoration: const InputDecoration(labelText: 'Role *'),
            items: [
              for (final r in roleOptions)
                DropdownMenuItem(value: r.$1, child: Text(r.$2)),
            ],
            onChanged: (v) {
              if (v != null) role.value = v;
            },
          ),
          if (!isPortalRole) ...[
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String?>(
              // ignore: deprecated_member_use
              value: deptId.value,
              decoration: const InputDecoration(labelText: 'Department'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Unassigned'),
                ),
                for (final d in departments)
                  DropdownMenuItem(value: d.id, child: Text(d.name)),
              ],
              onChanged: (v) {
                deptId.value = v;
                teamId.value = null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String?>(
              // ignore: deprecated_member_use
              value: teamId.value,
              decoration: const InputDecoration(labelText: 'Team'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Unassigned'),
                ),
                for (final t in teamsForDept)
                  DropdownMenuItem(value: t.id, child: Text(t.name)),
              ],
              onChanged: (v) => teamId.value = v,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: isPortalRole
                ? 'Send portal invite'
                : 'Send invite / assign role',
            expand: true,
            isLoading: ui.isBusy,
            icon: LucideIcons.userPlus,
            onPressed: ui.isBusy
                ? null
                : () async {
                    if (email.text.trim().isEmpty ||
                        !email.text.contains('@')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Enter a valid email address.'),
                        ),
                      );
                      return;
                    }
                    if (isPortalRole) {
                      final invite = await controller.invitePortalUser(
                        email: email.text.trim(),
                        roleSlug: role.value,
                        firstName: first.text.trim().isEmpty
                            ? null
                            : first.text.trim(),
                        lastName: last.text.trim().isEmpty
                            ? null
                            : last.text.trim(),
                        phone: phone.text.trim().isEmpty
                            ? null
                            : phone.text.trim(),
                      );
                      if (invite != null) {
                        lastPortalInvite.value = invite;
                        lastInvite.value = null;
                        if (invite.hasUsableToken) {
                          tokenCache.value = {
                            ...tokenCache.value,
                            invite.id: invite.token,
                          };
                        }
                        email.clear();
                        first.clear();
                        last.clear();
                        phone.clear();
                      }
                      return;
                    }
                    final invite = await controller.inviteStaff(
                      email: email.text.trim(),
                      roleSlug: role.value,
                      firstName: first.text.trim().isEmpty
                          ? null
                          : first.text.trim(),
                      lastName: last.text.trim().isEmpty
                          ? null
                          : last.text.trim(),
                      phone: phone.text.trim().isEmpty
                          ? null
                          : phone.text.trim(),
                      departmentId: deptId.value,
                      teamId: teamId.value,
                    );
                    if (invite != null) {
                      lastInvite.value = invite;
                      lastPortalInvite.value = null;
                      if (invite.hasUsableToken) {
                        tokenCache.value = {
                          ...tokenCache.value,
                          invite.id: invite.token,
                        };
                      }
                      email.clear();
                      first.clear();
                      last.clear();
                      phone.clear();
                    }
                  },
          ),
          if (lastInvite.value != null) ...[
            const SizedBox(height: AppSpacing.md),
            Material(
              color: AppColors.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                leading: const Icon(LucideIcons.link, color: AppColors.gold),
                title: Text(
                  '${lastInvite.value!.roleLabel} · ${lastInvite.value!.email}',
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  lastInvite.value!.status == 'accepted'
                      ? 'Role applied to existing account'
                      : 'Pending — share invite link',
                  style: const TextStyle(color: Color(0xFF8B929E)),
                ),
                trailing: lastInvite.value!.status == 'accepted'
                    ? null
                    : IconButton(
                        tooltip: 'Copy invite link',
                        icon: const Icon(LucideIcons.copy),
                        onPressed: () => copyLink(lastInvite.value!),
                      ),
              ),
            ),
          ],
          if (lastPortalInvite.value != null) ...[
            const SizedBox(height: AppSpacing.md),
            Material(
              color: AppColors.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                leading: const Icon(LucideIcons.link, color: AppColors.gold),
                title: Text(
                  '${lastPortalInvite.value!.roleLabel} · ${lastPortalInvite.value!.email}',
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  lastPortalInvite.value!.status == 'accepted'
                      ? 'Portal linked to existing account'
                      : 'Pending — share portal invite link',
                  style: const TextStyle(color: Color(0xFF8B929E)),
                ),
                trailing: lastPortalInvite.value!.status == 'accepted'
                    ? null
                    : IconButton(
                        tooltip: 'Copy portal invite link',
                        icon: const Icon(LucideIcons.copy),
                        onPressed: () =>
                            copyPortalLink(lastPortalInvite.value!),
                      ),
              ),
            ),
          ],
        ],
      ),
    );

    final tracking = AdminDeskPanel(
      fill: true,
      margin: const EdgeInsets.fromLTRB(0, 4, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Invitation tracking',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (final entry in [
                  (null, 'All'),
                  ('pending', 'Pending'),
                  ('accepted', 'Accepted'),
                  ('expired', 'Expired'),
                  ('revoked', 'Revoked'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(entry.$2),
                      selected: statusFilter.value == entry.$1,
                      onSelected: (_) => statusFilter.value = entry.$1,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: (filteredInvites.isEmpty && filteredPortalInvites.isEmpty)
                ? const Center(
                    child: Text(
                      'No invites in this filter.',
                      style: TextStyle(color: Color(0xFF8B929E)),
                    ),
                  )
                : ListView.separated(
                    primary: false,
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                    itemCount:
                        filteredInvites.length + filteredPortalInvites.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index < filteredInvites.length) {
                        final invite = filteredInvites[index];
                        final effective = invite.effectiveStatus();
                        final deptName = invite.departmentId == null
                            ? null
                            : deptById[invite.departmentId!];
                        final expiresLabel = invite.expiresAt == null
                            ? null
                            : DateFormat(
                                'd MMM yyyy',
                              ).format(invite.expiresAt!.toLocal());
                        return ListTile(
                          title: Text(
                            '${invite.roleLabel} · ${invite.email}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            [
                              'Staff',
                              effective,
                              if (deptName != null) deptName,
                              if (expiresLabel != null) 'Expires $expiresLabel',
                              if (invite.createdAt != null)
                                DateFormat(
                                  'd MMM yyyy',
                                ).format(invite.createdAt!.toLocal()),
                            ].join(' · '),
                            style: const TextStyle(
                              color: Color(0xFF8B929E),
                              fontSize: 12,
                            ),
                          ),
                          leading: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor(
                                effective,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              effective,
                              style: TextStyle(
                                color: statusColor(effective),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          trailing: Wrap(
                            spacing: 2,
                            children: [
                              if (invite.isActionablePending)
                                IconButton(
                                  tooltip: 'Copy / reveal link',
                                  icon: const Icon(LucideIcons.copy, size: 18),
                                  onPressed: ui.isBusy
                                      ? null
                                      : () => copyLink(invite),
                                ),
                              if (invite.isActionablePending)
                                PermissionGateAny(
                                  permissions: const [
                                    PermissionSlugs.manageStaff,
                                    PermissionSlugs.manageOrganization,
                                    PermissionSlugs.manageUsers,
                                  ],
                                  child: IconButton(
                                    tooltip: 'Resend invitation email',
                                    icon: const Icon(
                                      LucideIcons.mailPlus,
                                      size: 18,
                                    ),
                                    onPressed: ui.isBusy
                                        ? null
                                        : () async {
                                            final ok = await AppDialogs.confirm(
                                              context,
                                              title: 'Resend invitation?',
                                              message:
                                                  'Send another branded invite email to ${invite.email}? The same invitation record will be reused.',
                                              confirmLabel: 'Resend',
                                            );
                                            if (ok != true) return;
                                            await controller.resendInvite(
                                              invite.id,
                                            );
                                          },
                                  ),
                                ),
                              if (invite.isActionablePending)
                                PermissionGateAny(
                                  permissions: const [
                                    PermissionSlugs.manageStaff,
                                    PermissionSlugs.manageOrganization,
                                    PermissionSlugs.manageUsers,
                                  ],
                                  child: IconButton(
                                    tooltip: 'Revoke',
                                    icon: const Icon(
                                      LucideIcons.xCircle,
                                      size: 18,
                                    ),
                                    onPressed: ui.isBusy
                                        ? null
                                        : () async {
                                            final ok = await AppDialogs.confirm(
                                              context,
                                              title: 'Revoke invite?',
                                              message:
                                                  'Revoke the pending invite for ${invite.email}? They will no longer be able to use the link.',
                                              confirmLabel: 'Revoke',
                                              destructive: true,
                                            );
                                            if (ok != true) return;
                                            await controller.revokeInvite(
                                              invite.id,
                                            );
                                          },
                                  ),
                                ),
                            ],
                          ),
                        );
                      }

                      final invite =
                          filteredPortalInvites[index - filteredInvites.length];
                      final effective = invite.effectiveStatus();
                      final expiresLabel = invite.expiresAt == null
                          ? null
                          : DateFormat(
                              'd MMM yyyy',
                            ).format(invite.expiresAt!.toLocal());
                      return ListTile(
                        title: Text(
                          '${invite.roleLabel} · ${invite.email}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          [
                            'Portal',
                            effective,
                            if (expiresLabel != null) 'Expires $expiresLabel',
                            if (invite.createdAt != null)
                              DateFormat(
                                'd MMM yyyy',
                              ).format(invite.createdAt!.toLocal()),
                          ].join(' · '),
                          style: const TextStyle(
                            color: Color(0xFF8B929E),
                            fontSize: 12,
                          ),
                        ),
                        leading: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor(
                              effective,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            effective,
                            style: TextStyle(
                              color: statusColor(effective),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        trailing: Wrap(
                          spacing: 2,
                          children: [
                            if (invite.isPending && !invite.isExpiredAt())
                              IconButton(
                                tooltip: 'Copy / reveal link',
                                icon: const Icon(LucideIcons.copy, size: 18),
                                onPressed: ui.isBusy
                                    ? null
                                    : () => copyPortalLink(invite),
                              ),
                            if (invite.isPending && !invite.isExpiredAt())
                              IconButton(
                                tooltip: 'Revoke',
                                icon: const Icon(LucideIcons.xCircle, size: 18),
                                onPressed: ui.isBusy
                                    ? null
                                    : () async {
                                        final ok = await AppDialogs.confirm(
                                          context,
                                          title: 'Revoke portal invite?',
                                          message:
                                              'Revoke the pending portal invite for ${invite.email}?',
                                          confirmLabel: 'Revoke',
                                          destructive: true,
                                        );
                                        if (ok != true) return;
                                        await controller.revokePortalInvite(
                                          invite.id,
                                        );
                                      },
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    if (!wide) {
      return ListView(
        children: [
          SizedBox(height: 520, child: form),
          SizedBox(height: 420, child: tracking),
        ],
      );
    }

    return Row(
      children: [
        Expanded(flex: 5, child: form),
        Expanded(flex: 6, child: tracking),
      ],
    );
  }
}
