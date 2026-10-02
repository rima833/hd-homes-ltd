import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/core/constants/permissions.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/feedback/app_dialogs.dart';
import 'package:hdhomesproject/features/admin/presentation/widgets/admin_desk_shell.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/account_status.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/mfa_models.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/platform_user_models.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/rbac_models.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/people_rbac_realtime_provider.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/platform_users_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/rbac_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/people_rbac_security_gate.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/permission_gate.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';

/// Platform auth accounts — dedicated AdminDesk route (`/dashboard/platform-users`).
class PlatformUsersTab extends HookConsumerWidget {
  const PlatformUsersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configured = ref.watch(supabaseConfiguredProvider);
    final snapAsync = ref.watch(platformUsersSnapshotProvider);
    final ui = ref.watch(platformUsersControllerProvider);
    final filter = ref.watch(platformUsersFilterProvider);
    final filterCtrl = ref.read(platformUsersFilterProvider.notifier);
    final rolesAsync = ref.watch(rbacSnapshotProvider);
    final rt = ref.watch(peopleRbacRealtimeConnectionProvider);
    final rtEvent = ref.watch(peopleRbacRealtimeEventProvider);
    final live = rt == PeopleRbacRealtimeConnection.live;
    final fromRemote = configured &&
        (rt == PeopleRbacRealtimeConnection.live ||
            rt == PeopleRbacRealtimeConnection.connecting);
    final liveLabel = switch (rt) {
      PeopleRbacRealtimeConnection.live => 'Your latest records are here.',
      PeopleRbacRealtimeConnection.connecting =>
        "We're gathering the latest records.",
      PeopleRbacRealtimeConnection.error =>
        "We'll refresh this when the connection is back.",
      PeopleRbacRealtimeConnection.offline =>
        "We'll refresh this when the connection is back.",
    };

    final deskTabs = [
      const AdminDeskTab(label: 'All', icon: LucideIcons.users),
      AdminDeskTab(
        label: 'Needs roles',
        icon: LucideIcons.shieldOff,
        badge: snapAsync.valueOrNull?.users
            .where((u) => u.roles.isEmpty)
            .length,
      ),
      AdminDeskTab(
        label: 'Linked staff',
        icon: LucideIcons.link,
        badge: snapAsync.valueOrNull?.analytics.linkedToStaff,
      ),
      AdminDeskTab(
        label: 'Restricted',
        icon: LucideIcons.userX,
        badge: snapAsync.valueOrNull?.analytics.suspendedAccounts,
      ),
    ];

    return snapAsync.when(
      loading: () => AdminDeskPage(
        overline: 'ACCESS CONTROL',
        title: 'Platform Users',
        subtitle: 'Loading auth accounts…',
        tabs: deskTabs,
        selectedTab: filter.deskTab,
        onTabSelected: filterCtrl.setDeskTab,
        body: const SizedBox.shrink(),
        isLoading: true,
      ),
      error: (e, _) => AdminDeskPage(
        overline: 'ACCESS CONTROL',
        title: 'Platform Users',
        subtitle: 'Unable to load platform accounts',
        tabs: deskTabs,
        selectedTab: filter.deskTab,
        onTabSelected: filterCtrl.setDeskTab,
        error: userFacingError(e),
        onRefresh: () => ref.invalidate(platformUsersSnapshotProvider),
        body: Center(
          child: FilledButton.icon(
            onPressed: () => ref.invalidate(platformUsersSnapshotProvider),
            icon: const Icon(LucideIcons.refreshCw, size: 16),
            label: const Text('Retry'),
          ),
        ),
      ),
      data: (snap) {
        final roles = rolesAsync.valueOrNull?.roles
                .where((r) => r.lifecycle == RoleLifecycle.active)
                .toList() ??
            const <RoleDefinition>[];
        final needsRoles =
            snap.users.where((u) => u.roles.isEmpty).length;
        final tabs = [
          const AdminDeskTab(label: 'All', icon: LucideIcons.users),
          AdminDeskTab(
            label: 'Needs roles',
            icon: LucideIcons.shieldOff,
            badge: needsRoles == 0 ? null : needsRoles,
          ),
          AdminDeskTab(
            label: 'Linked staff',
            icon: LucideIcons.link,
            badge: snap.analytics.linkedToStaff == 0
                ? null
                : snap.analytics.linkedToStaff,
          ),
          AdminDeskTab(
            label: 'Restricted',
            icon: LucideIcons.userX,
            badge: snap.analytics.suspendedAccounts == 0
                ? null
                : snap.analytics.suspendedAccounts,
          ),
        ];
        final kpis = [
          AdminDeskKpi(
            label: 'Accounts',
            value: '${snap.analytics.totalAccounts}',
            subtitle: '${snap.analytics.withRoles} with roles',
            icon: LucideIcons.userCircle,
          ),
          AdminDeskKpi(
            label: 'Active',
            value: '${snap.analytics.activeAccounts}',
            subtitle: 'Verified & active',
            icon: LucideIcons.userCheck,
            accent: AppColors.success,
          ),
          AdminDeskKpi(
            label: 'Pending',
            value: '${snap.analytics.pendingVerification}',
            subtitle: 'Awaiting email',
            icon: LucideIcons.mail,
            accent: AppColors.warning,
          ),
          AdminDeskKpi(
            label: 'Restricted',
            value: '${snap.analytics.suspendedAccounts}',
            subtitle: 'Suspended / inactive',
            icon: LucideIcons.userX,
            accent: snap.analytics.suspendedAccounts > 0
                ? AppColors.error
                : null,
          ),
        ];

        return AdminDeskPage(
          overline: 'ACCESS CONTROL',
          title: 'Platform Users',
          subtitle:
              'Manage auth accounts and assign platform roles without re-inviting.',
          tabs: tabs,
          selectedTab: filter.deskTab,
          onTabSelected: filterCtrl.setDeskTab,
          kpis: kpis,
          live: live,
          fromRemote: fromRemote,
          liveLabel: liveLabel,
          remoteLabel: configured
              ? (live
                  ? '${snap.users.length} accounts loaded'
                  : "We're gathering the latest records.")
              : 'Not connected',
          onRefresh: () {
            ref.invalidate(platformUsersSnapshotProvider);
            ref.invalidate(rbacSnapshotProvider);
          },
          message: ui.message ?? rtEvent,
          onDismissMessage: () {
            ref.read(platformUsersControllerProvider.notifier).clearFeedback();
            ref.read(peopleRbacRealtimeEventProvider.notifier).state = null;
          },
          error: ui.error,
          body: PermissionGate(
            permission: PermissionSlugs.manageUsers,
            fallback: const AdminDeskEmptyState(
              icon: LucideIcons.lock,
              title: 'Manage users permission required',
              message:
                  'Platform account and role assignment is restricted to administrators with manage_users access.',
            ),
            child: _PlatformUsersSplitView(
              configured: configured,
              roles: roles,
              isBusy: ui.isBusy,
            ),
          ),
        );
      },
    );
  }
}

class _PlatformUsersSplitView extends HookConsumerWidget {
  const _PlatformUsersSplitView({
    required this.configured,
    required this.roles,
    required this.isBusy,
  });

  final bool configured;
  final List<RoleDefinition> roles;
  final bool isBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(platformUsersFilterProvider);
    final filterCtrl = ref.read(platformUsersFilterProvider.notifier);
    final filtered =
        ref.watch(filteredPlatformUsersProvider).valueOrNull ?? const [];
    final selectedId =
        ref.watch(platformUsersControllerProvider).selectedUserId;
    PlatformUser? selected;
    if (selectedId != null) {
      for (final u in filtered) {
        if (u.id == selectedId) {
          selected = u;
          break;
        }
      }
    }
    selected ??= filtered.isEmpty ? null : filtered.first;
    final queryCtrl = useTextEditingController(text: filter.query ?? '');
    final wide = MediaQuery.sizeOf(context).width >= 960;
    final dateFmt = DateFormat.yMMMd().add_jm();

    final listPanel = AdminDeskPanel(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: queryCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search name, email, employee code…',
                hintStyle: const TextStyle(color: AdminDeskColors.muted),
                prefixIcon: const Icon(
                  LucideIcons.search,
                  color: AdminDeskColors.muted,
                ),
                filled: true,
                fillColor: AdminDeskColors.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
              ),
              onChanged: filterCtrl.setQuery,
            ),
          ),
          if (roles.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('All roles'),
                    selected: filter.roleSlug == null,
                    onSelected: (_) => filterCtrl.setRoleSlug(null),
                  ),
                  const SizedBox(width: 8),
                  for (final role in roles.take(8))
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(role.name),
                        selected: filter.roleSlug == role.slug,
                        onSelected: (sel) =>
                            filterCtrl.setRoleSlug(sel ? role.slug : null),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: filtered.isEmpty
                ? AdminDeskEmptyState(
                    icon: LucideIcons.userCircle,
                    title: configured
                        ? 'No accounts in this view'
                        : "Can't load accounts right now",
                    message: configured
                        ? 'Accounts appear when users register or accept a staff invite. Use Invites in Organization for new staff.'
                        : "Updates will refresh when you're back online.",
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final user = filtered[index];
                      final isSelected = selected?.id == user.id;
                      return Material(
                        color: isSelected
                            ? AppColors.gold.withValues(alpha: 0.08)
                            : Colors.transparent,
                        child: ListTile(
                          selected: isSelected,
                          leading: CircleAvatar(
                            backgroundColor: _statusColor(user.accountStatus)
                                .withValues(alpha: 0.15),
                            child: Text(user.initials),
                          ),
                          title: Text(
                            user.displayName,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            user.roles.isEmpty
                                ? user.email
                                : '${user.email} · ${user.roles.map((r) => r.roleName).join(', ')}',
                            style: const TextStyle(
                              color: AdminDeskColors.muted,
                              fontSize: 12,
                            ),
                          ),
                          trailing: _StatusChip(status: user.accountStatus),
                          onTap: () => ref
                              .read(platformUsersControllerProvider.notifier)
                              .selectUser(user.id),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    final detail = selected == null
        ? const AdminDeskEmptyState(
            icon: LucideIcons.user,
            title: 'Select an account',
            message: 'Choose a platform user to review roles and status.',
          )
        : _PlatformUserDetail(
            user: selected,
            roles: roles,
            isBusy: isBusy,
            dateFmt: dateFmt,
          );

    if (!wide) {
      return selected == null
          ? listPanel
          : Column(
              children: [
                Expanded(flex: 2, child: listPanel),
                const Divider(height: 1, color: AdminDeskColors.border),
                Expanded(flex: 3, child: detail),
              ],
            );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 380, child: listPanel),
        const VerticalDivider(width: 1, color: AdminDeskColors.border),
        Expanded(child: detail),
      ],
    );
  }
}

class _PlatformUserDetail extends ConsumerWidget {
  const _PlatformUserDetail({
    required this.user,
    required this.roles,
    required this.isBusy,
    required this.dateFmt,
  });

  final PlatformUser user;
  final List<RoleDefinition> roles;
  final bool isBusy;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(platformUsersControllerProvider.notifier);
    final assignedRoleIds = user.roles.map((r) => r.roleId).toSet();
    final availableRoles =
        roles.where((r) => !assignedRoleIds.contains(r.id)).toList();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.gold.withValues(alpha: 0.18),
              backgroundImage:
                  user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
              child: user.avatarUrl == null
                  ? Text(
                      user.initials,
                      style: Theme.of(context).textTheme.headlineSmall,
                    )
                  : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    user.email,
                    style: const TextStyle(color: AdminDeskColors.muted),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatusChip(status: user.accountStatus),
                      if (user.hasStaffRecord)
                        Chip(
                          avatar: const Icon(LucideIcons.briefcase, size: 14),
                          label: Text(
                            'Staff ${user.linkedEmployeeCode ?? user.linkedEmployeeId!.substring(0, 8)}',
                          ),
                          visualDensity: VisualDensity.compact,
                          backgroundColor:
                              AppColors.info.withValues(alpha: 0.12),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _DetailSection(
          title: 'Account',
          icon: LucideIcons.user,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(label: 'User ID', value: user.id),
              if (user.phone != null)
                _DetailRow(label: 'Phone', value: user.phone!),
              _DetailRow(
                label: 'Last login',
                value: user.lastLoginAt != null
                    ? dateFmt.format(user.lastLoginAt!.toLocal())
                    : 'Never',
              ),
              _DetailRow(
                label: 'Created',
                value: user.createdAt != null
                    ? dateFmt.format(user.createdAt!.toLocal())
                    : '—',
              ),
              const SizedBox(height: 12),
              const Text(
                'Account status',
                style: TextStyle(color: AdminDeskColors.muted),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in AccountStatus.values)
                    if (s != AccountStatus.deleted)
                      ChoiceChip(
                        label: Text(_statusLabel(s)),
                        selected: user.accountStatus == s,
                        onSelected: isBusy || user.accountStatus == s
                            ? null
                            : (_) async {
                                final ok = await AppDialogs.confirm(
                                  context,
                                  title: 'Change account status?',
                                  message:
                                      'Set ${user.displayName} to ${_statusLabel(s)}. '
                                      'This affects login and portal access.',
                                  confirmLabel: 'Update status',
                                  destructive: s == AccountStatus.suspended ||
                                      s == AccountStatus.inactive,
                                );
                                if (ok != true) return;
                                if (!context.mounted) return;
                                if (s == AccountStatus.suspended ||
                                    s == AccountStatus.inactive) {
                                  final stepped = await ensurePeopleRbacStepUp(
                                    context: context,
                                    ref: ref,
                                    action: StepUpAction.modifyPermissions,
                                  );
                                  if (!stepped) return;
                                  if (!context.mounted) return;
                                }
                                await controller.updateAccountStatus(
                                  userId: user.id,
                                  status: s,
                                );
                              },
                      ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _DetailSection(
          title: 'Platform roles',
          icon: LucideIcons.shield,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (user.roles.isEmpty)
                const Text(
                  'No roles assigned — add a role below to grant platform access.',
                  style: TextStyle(color: AdminDeskColors.muted),
                ),
              for (final assignment in user.roles)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AdminDeskColors.elevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: assignment.isPrimary
                          ? AppColors.gold.withValues(alpha: 0.45)
                          : AdminDeskColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        assignment.isPrimary
                            ? LucideIcons.star
                            : LucideIcons.shield,
                        size: 16,
                        color: assignment.isPrimary
                            ? AppColors.gold
                            : AdminDeskColors.muted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              assignment.roleName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              assignment.roleSlug,
                              style: const TextStyle(
                                color: AdminDeskColors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!assignment.isPrimary)
                        TextButton(
                          onPressed: isBusy
                              ? null
                              : () => controller.setPrimaryRole(
                                    userId: user.id,
                                    assignment: assignment,
                                  ),
                          child: const Text('Set primary'),
                        ),
                      IconButton(
                        tooltip: 'Remove role',
                        onPressed: isBusy
                            ? null
                            : () async {
                                final ok = await AppDialogs.confirm(
                                  context,
                                  title: 'Revoke ${assignment.roleName}?',
                                  message:
                                      'Remove this role from ${user.displayName}. '
                                      'Access changes apply immediately via RLS.',
                                  confirmLabel: 'Revoke',
                                  destructive: true,
                                );
                                if (ok != true) return;
                                if (!context.mounted) return;
                                if (isElevatedRoleSlug(assignment.roleSlug)) {
                                  final stepped = await ensurePeopleRbacStepUp(
                                    context: context,
                                    ref: ref,
                                    action: StepUpAction.createAdmin,
                                  );
                                  if (!stepped) return;
                                  if (!context.mounted) return;
                                }
                                await controller.revokeRole(
                                  assignment: assignment,
                                  userId: user.id,
                                );
                              },
                        icon: const Icon(
                          LucideIcons.trash2,
                          size: 16,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              if (availableRoles.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Assign role',
                  style: TextStyle(color: AdminDeskColors.muted),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final role in availableRoles)
                      ActionChip(
                        avatar: const Icon(LucideIcons.plus, size: 14),
                        label: Text(role.name),
                        onPressed: isBusy
                            ? null
                            : () async {
                                final elevated = isElevatedRoleSlug(role.slug);
                                final ok = await AppDialogs.confirm(
                                  context,
                                  title: elevated
                                      ? 'Assign elevated role?'
                                      : 'Assign ${role.name}?',
                                  message: elevated
                                      ? 'Grant ${role.name} to ${user.displayName}. '
                                          'Elevated roles unlock admin capabilities.'
                                      : 'Grant ${role.name} to ${user.displayName}.',
                                  confirmLabel: 'Assign',
                                  destructive: elevated,
                                );
                                if (ok != true) return;
                                if (!context.mounted) return;
                                if (elevated) {
                                  final stepped = await ensurePeopleRbacStepUp(
                                    context: context,
                                    ref: ref,
                                    action: StepUpAction.createAdmin,
                                  );
                                  if (!stepped) return;
                                  if (!context.mounted) return;
                                }
                                await controller.assignRole(
                                  userId: user.id,
                                  role: role,
                                  isPrimary: user.roles.isEmpty,
                                );
                              },
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (isBusy)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: LinearProgressIndicator(color: AppColors.gold),
          ),
      ],
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminDeskColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminDeskColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.gold),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: AdminDeskColors.muted),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final AccountStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String _statusLabel(AccountStatus status) => switch (status) {
      AccountStatus.pendingVerification => 'Pending',
      AccountStatus.active => 'Active',
      AccountStatus.inactive => 'Inactive',
      AccountStatus.suspended => 'Suspended',
      AccountStatus.deleted => 'Deleted',
    };

Color _statusColor(AccountStatus status) => switch (status) {
      AccountStatus.active => AppColors.success,
      AccountStatus.pendingVerification => AppColors.warning,
      AccountStatus.suspended => AppColors.error,
      AccountStatus.inactive => AdminDeskColors.muted,
      AccountStatus.deleted => AppColors.error,
    };
