import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/core/constants/permissions.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/feedback/app_dialogs.dart';
import 'package:hdhomesproject/features/admin/presentation/widgets/admin_desk_shell.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/platform_user_models.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/rbac_models.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/permission_form_dialogs.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/role_form_dialogs.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/people_rbac_realtime_provider.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/platform_users_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/rbac_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/people_rbac_security_gate.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/permission_gate.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/mfa_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';

/// Roles & Permissions desk — real Supabase RBAC (no stub policies).
class RbacConsolePage extends HookConsumerWidget {
  const RbacConsolePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapAsync = ref.watch(rbacSnapshotProvider);
    final ui = ref.watch(rbacControllerProvider);
    final controller = ref.read(rbacControllerProvider.notifier);
    final tab = useState(ui.hubTab.clamp(0, 3));
    final configured = ref.watch(supabaseConfiguredProvider);
    final rt = ref.watch(peopleRbacRealtimeConnectionProvider);
    final rtEvent = ref.watch(peopleRbacRealtimeEventProvider);
    final live = rt == PeopleRbacRealtimeConnection.live;
    final fromRemote =
        configured &&
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

    return snapAsync.when(
      loading: () => const AdminDeskPage(
        overline: 'ACCESS CONTROL',
        title: 'Roles & Permissions',
        subtitle: 'Loading access control…',
        tabs: [
          AdminDeskTab(label: 'Roles', icon: LucideIcons.shield),
          AdminDeskTab(label: 'Matrix', icon: LucideIcons.layoutGrid),
          AdminDeskTab(label: 'Groups', icon: LucideIcons.layers),
          AdminDeskTab(label: 'Approvals', icon: LucideIcons.clipboardCheck),
        ],
        selectedTab: 0,
        onTabSelected: _noopTab,
        body: SizedBox.shrink(),
        isLoading: true,
      ),
      error: (e, _) => AdminDeskPage(
        overline: 'ACCESS CONTROL',
        title: 'Roles & Permissions',
        subtitle: 'Unable to load RBAC',
        tabs: const [
          AdminDeskTab(label: 'Roles', icon: LucideIcons.shield),
          AdminDeskTab(label: 'Matrix', icon: LucideIcons.layoutGrid),
          AdminDeskTab(label: 'Groups', icon: LucideIcons.layers),
          AdminDeskTab(label: 'Approvals', icon: LucideIcons.clipboardCheck),
        ],
        selectedTab: 0,
        onTabSelected: (_) {},
        error: userFacingError(e),
        onRefresh: () => ref.invalidate(rbacSnapshotProvider),
        body: Center(
          child: FilledButton.icon(
            onPressed: () => ref.invalidate(rbacSnapshotProvider),
            icon: const Icon(LucideIcons.refreshCw, size: 16),
            label: const Text('Retry'),
          ),
        ),
      ),
      data: (snap) {
        final pendingApprovals = snap.analytics.openApprovals;
        final tabs = [
          const AdminDeskTab(label: 'Roles', icon: LucideIcons.shield),
          const AdminDeskTab(label: 'Matrix', icon: LucideIcons.layoutGrid),
          AdminDeskTab(
            label: 'Groups',
            icon: LucideIcons.layers,
            badge: snap.groups.isEmpty ? null : snap.groups.length,
          ),
          AdminDeskTab(
            label: 'Approvals',
            icon: LucideIcons.clipboardCheck,
            badge: pendingApprovals == 0 ? null : pendingApprovals,
          ),
        ];
        final kpis = [
          AdminDeskKpi(
            label: 'Active roles',
            value: '${snap.analytics.rolesInUse}',
            subtitle: '${snap.analytics.systemRoles} system',
            icon: LucideIcons.shield,
          ),
          AdminDeskKpi(
            label: 'Permissions',
            value: '${snap.analytics.permissionCount}',
            subtitle: 'From catalog',
            icon: LucideIcons.key,
          ),
          AdminDeskKpi(
            label: 'Groups',
            value: '${snap.groups.length}',
            subtitle: 'Bundled grants',
            icon: LucideIcons.layers,
          ),
          AdminDeskKpi(
            label: 'Pending approvals',
            value: '$pendingApprovals',
            subtitle:
                '${snap.policies.where((p) => p.enabled).length} policies on',
            icon: LucideIcons.clipboardCheck,
          ),
        ];

        return AdminDeskPage(
          overline: 'ACCESS CONTROL',
          title: 'Roles & Permissions',
          subtitle:
              'Assign roles, apply groups, and review access requests in realtime.',
          tabs: tabs,
          selectedTab: tab.value,
          onTabSelected: (i) {
            tab.value = i;
            controller.setTab(i);
          },
          kpis: kpis,
          live: live,
          fromRemote: fromRemote,
          liveLabel: liveLabel,
          remoteLabel: configured
              ? (live
                  ? 'Your latest records are here.'
                  : "We're gathering the latest records.")
              : 'Not connected',
          onRefresh: () => ref.invalidate(rbacSnapshotProvider),
          message: ui.message ?? rtEvent,
          onDismissMessage: () {
            controller.clearFeedback();
            ref.read(peopleRbacRealtimeEventProvider.notifier).state = null;
          },
          error: ui.error,
          actions: [
            PermissionGate(
              permission: PermissionSlugs.configurePermissions,
              child: OutlinedButton.icon(
                onPressed: ui.isBusy
                    ? null
                    : () async {
                        final result = await showPermissionFormDialog(
                          context: context,
                          isBusy: ui.isBusy,
                        );
                        if (result == null) return;
                        await controller.createPermission(
                          name: result.name,
                          slug: result.slug,
                          module: result.module,
                          description: result.description,
                        );
                        tab.value = 1;
                      },
                icon: const Icon(LucideIcons.key, size: 16),
                label: const Text('Add permission'),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go(peopleRbacActivityLogsPath()),
              icon: const Icon(LucideIcons.history, size: 16),
              label: const Text('Audit logs'),
            ),
            OutlinedButton.icon(
              onPressed: ui.isBusy
                  ? null
                  : () async {
                      final ok = await _showAccessRequestDialog(
                        context: context,
                        snap: snap,
                        isBusy: ui.isBusy,
                      );
                      if (ok == null) return;
                      await controller.createAccessRequest(
                        reason: ok.reason,
                        permissionSlug: ok.permissionSlug,
                        roleSlug: ok.roleSlug,
                      );
                      tab.value = 3;
                    },
              icon: const Icon(LucideIcons.filePlus, size: 16),
              label: const Text('Request access'),
            ),
            PermissionGateAny(
              permissions: const [
                PermissionSlugs.manageRoles,
                PermissionSlugs.configurePermissions,
              ],
              child: FilledButton.icon(
                onPressed: ui.isBusy
                    ? null
                    : () async {
                        final roles = snap.roles;
                        final result = await showRoleFormDialog(
                          context: context,
                          roles: roles,
                          isBusy: ui.isBusy,
                        );
                        if (result == null) return;
                        await controller.createRole(
                          name: result.name,
                          slug: result.slug,
                          description: result.description,
                          cloneFromRoleId: result.cloneFromRoleId,
                          parentRoleId: result.parentRoleId,
                        );
                        tab.value = 0;
                      },
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Create role'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.charcoal,
                ),
              ),
            ),
          ],
          body: IndexedStack(
            index: tab.value,
            children: [
              _RolesTab(snap: snap),
              _MatrixTab(snap: snap),
              _GroupsTab(snap: snap),
              _ApprovalsTab(snap: snap),
            ],
          ),
        );
      },
    );
  }
}

void _noopTab(int _) {}

class _AccessRequestDraft {
  const _AccessRequestDraft({
    required this.reason,
    this.permissionSlug,
    this.roleSlug,
  });

  final String reason;
  final String? permissionSlug;
  final String? roleSlug;
}

Future<_AccessRequestDraft?> _showAccessRequestDialog({
  required BuildContext context,
  required RbacSnapshot snap,
  required bool isBusy,
}) async {
  final reasonCtrl = TextEditingController();
  String mode = 'role';
  String? roleSlug = snap.roles.where((r) => !r.isSystem).isEmpty
      ? null
      : snap.roles.where((r) => !r.isSystem).first.slug;
  String? permissionSlug = snap.permissions.isEmpty
      ? null
      : snap.permissions.first.effectiveDbSlug;

  final result = await showDialog<_AccessRequestDraft>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('Request access'),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'role', label: Text('Role')),
                      ButtonSegment(
                        value: 'permission',
                        label: Text('Permission'),
                      ),
                    ],
                    selected: {mode},
                    onSelectionChanged: (s) => setLocal(() => mode = s.first),
                  ),
                  const SizedBox(height: 12),
                  if (mode == 'role')
                    DropdownButtonFormField<String?>(
                      // ignore: deprecated_member_use
                      value: roleSlug,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: [
                        for (final r in snap.roles.where(
                          (r) => r.lifecycle == RoleLifecycle.active,
                        ))
                          DropdownMenuItem(value: r.slug, child: Text(r.name)),
                      ],
                      onChanged: (v) => setLocal(() => roleSlug = v),
                    )
                  else
                    DropdownButtonFormField<String?>(
                      // ignore: deprecated_member_use
                      value: permissionSlug,
                      decoration: const InputDecoration(
                        labelText: 'Permission',
                      ),
                      items: [
                        for (final p in snap.permissions)
                          DropdownMenuItem(
                            value: p.effectiveDbSlug,
                            child: Text('${p.name} (${p.effectiveDbSlug})'),
                          ),
                      ],
                      onChanged: (v) => setLocal(() => permissionSlug = v),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtrl,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      hintText: 'Why do you need this access?',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isBusy
                    ? null
                    : () {
                        final reason = reasonCtrl.text.trim();
                        if (reason.isEmpty) return;
                        if (mode == 'role' &&
                            (roleSlug == null || roleSlug!.isEmpty)) {
                          return;
                        }
                        if (mode == 'permission' &&
                            (permissionSlug == null ||
                                permissionSlug!.isEmpty)) {
                          return;
                        }
                        Navigator.of(ctx).pop(
                          _AccessRequestDraft(
                            reason: reason,
                            roleSlug: mode == 'role' ? roleSlug : null,
                            permissionSlug: mode == 'permission'
                                ? permissionSlug
                                : null,
                          ),
                        );
                      },
                child: const Text('Submit'),
              ),
            ],
          );
        },
      );
    },
  );
  reasonCtrl.dispose();
  return result;
}

class _MatrixTab extends HookConsumerWidget {
  const _MatrixTab({required this.snap});

  final RbacSnapshot snap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(rbacControllerProvider);
    final controller = ref.read(rbacControllerProvider.notifier);
    final roles = snap.matrix.roles
        .where((r) => r.lifecycle == RoleLifecycle.active)
        .toList();
    final modules = <String>{
      for (final p in snap.matrix.permissions) p.module,
    }.toList()..sort();
    final moduleFilter = useState<String?>(null);
    final query = useState('');
    final compact = MediaQuery.sizeOf(context).width < 720;
    final mobileRoleId = useState<String?>(
      roles.isEmpty ? null : roles.first.id,
    );
    RoleDefinition? mobileRole;
    for (final role in roles) {
      if (role.id == mobileRoleId.value) {
        mobileRole = role;
        break;
      }
    }
    mobileRole ??= roles.isEmpty ? null : roles.first;

    final perms = snap.matrix.permissions.where((p) {
      if (moduleFilter.value != null && p.module != moduleFilter.value) {
        return false;
      }
      final q = query.value.trim().toLowerCase();
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.effectiveDbSlug.toLowerCase().contains(q) ||
          p.module.toLowerCase().contains(q);
    }).toList();

    final inheritedByRole = <String, Set<String>>{
      for (final r in roles) r.id: roleInheritedPermissionSlugs(r, snap.roles),
    };

    Future<void> toggleCell({
      required RoleDefinition role,
      required PermissionDefinition perm,
      required bool granted,
      required bool direct,
      required bool inherited,
    }) async {
      if (ui.isMatrixPending(role.slug, perm.effectiveDbSlug)) return;
      if (!granted && inherited && !direct) {
        await AppDialogs.confirm(
          context,
          title: 'Inherited permission',
          message:
              '${perm.name} comes from a parent role. Change the parent '
              'or grant an override; it cannot be revoked here.',
          confirmLabel: 'OK',
        );
        return;
      }
      if (SensitivePermissions.isSensitive(perm.effectiveDbSlug)) {
        final ok = await AppDialogs.confirm(
          context,
          title: granted
              ? 'Grant sensitive permission?'
              : 'Revoke sensitive permission?',
          message:
              '${perm.name} (${perm.effectiveDbSlug}) on ${role.name}. '
              'This affects live RLS access.',
          confirmLabel: granted ? 'Grant' : 'Revoke',
          destructive: !granted,
        );
        if (ok != true) return;
        if (!context.mounted) return;
        final stepped = await ensurePeopleRbacStepUp(
          context: context,
          ref: ref,
          action: StepUpAction.modifyPermissions,
        );
        if (!stepped) return;
        if (!context.mounted) return;
      }
      await controller.toggleMatrixCell(
        roleId: role.id,
        roleSlug: role.slug,
        permissionSlug: perm.effectiveDbSlug,
        granted: granted,
      );
    }

    Widget compactPermissionTile(PermissionDefinition perm) {
      final role = mobileRole;
      if (role == null) return const SizedBox.shrink();
      final dbSlug = perm.effectiveDbSlug;
      final override = ui.overrideGranted(role.slug, dbSlug);
      final direct =
          override ??
          (snap.matrix.isGranted(role.slug, dbSlug) ||
              role.permissionSlugs.contains(dbSlug) ||
              role.permissionSlugs.contains(perm.slug));
      final inherited =
          (inheritedByRole[role.id] ?? const {}).contains(dbSlug) ||
          (inheritedByRole[role.id] ?? const {}).contains(perm.slug);
      final locked = role.isSuperAdmin;
      final effective = locked || direct || (override == null && inherited);
      final inheritedOnly =
          !locked &&
          override == null &&
          inherited &&
          !(snap.matrix.isGranted(role.slug, dbSlug) ||
              role.permissionSlugs.contains(dbSlug) ||
              role.permissionSlugs.contains(perm.slug));

      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        color: const Color(0xFF141820),
        child: CheckboxListTile(
          value: effective,
          enabled: !locked && !ui.isMatrixPending(role.slug, dbSlug),
          activeColor: inheritedOnly ? const Color(0xFF64748B) : AppColors.gold,
          controlAffinity: ListTileControlAffinity.trailing,
          title: Row(
            children: [
              Expanded(child: Text(perm.name)),
              if (SensitivePermissions.isSensitive(dbSlug))
                const Icon(
                  LucideIcons.alertTriangle,
                  size: 14,
                  color: Color(0xFFF59E0B),
                ),
            ],
          ),
          subtitle: Text(
            inheritedOnly
                ? '$dbSlug · inherited'
                : locked
                ? '$dbSlug · always granted'
                : dbSlug,
            style: const TextStyle(color: Color(0xFF8B929E), fontSize: 11),
          ),
          onChanged: locked
              ? null
              : (v) => toggleCell(
                  role: role,
                  perm: perm,
                  granted: v ?? false,
                  direct: direct,
                  inherited: inherited,
                ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String?>(
                  // ignore: deprecated_member_use
                  value: moduleFilter.value,
                  decoration: const InputDecoration(
                    labelText: 'Module',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All modules'),
                    ),
                    for (final m in modules)
                      DropdownMenuItem(value: m, child: Text(m)),
                  ],
                  onChanged: (v) => moduleFilter.value = v,
                ),
              ),
              if (compact && roles.isNotEmpty)
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: mobileRole?.id,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final role in roles)
                        DropdownMenuItem(
                          value: role.id,
                          child: Text(
                            role.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => mobileRoleId.value = value,
                  ),
                ),
              SizedBox(
                width: 260,
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search permissions',
                    isDense: true,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(LucideIcons.search, size: 16),
                  ),
                  onChanged: (v) => query.value = v,
                ),
              ),
              Text(
                '${perms.length} permissions · ${roles.length} roles',
                style: const TextStyle(color: Color(0xFF8B929E), fontSize: 12),
              ),
              if (ui.isBusy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.gold,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: perms.isEmpty
              ? const Center(
                  child: Text(
                    'No permissions match this filter.',
                    style: TextStyle(color: Color(0xFF8B929E)),
                  ),
                )
              : PermissionGateAny(
                  permissions: const [
                    PermissionSlugs.manageRoles,
                    PermissionSlugs.configurePermissions,
                  ],
                  fallback: const Center(
                    child: Text(
                      'You need manage_roles or configure_permissions to edit the matrix.',
                      style: TextStyle(color: Color(0xFF8B929E)),
                    ),
                  ),
                  child: compact
                      ? ListView.builder(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: perms.length,
                          itemBuilder: (context, index) =>
                              compactPermissionTile(perms[index]),
                        )
                      : _MatrixScroll(
                          child: DataTable(
                            columns: [
                              const DataColumn(label: Text('Permission')),
                              ...roles.map(
                                (r) => DataColumn(label: Text(r.name)),
                              ),
                            ],
                            rows: [
                              for (final perm in perms)
                                DataRow(
                                  cells: [
                                    DataCell(
                                      SizedBox(
                                        width: 200,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    perm.name,
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.bodySmall,
                                                  ),
                                                ),
                                                if (SensitivePermissions.isSensitive(
                                                  perm.effectiveDbSlug,
                                                )) ...[
                                                  const SizedBox(width: 4),
                                                  const Icon(
                                                    LucideIcons.alertTriangle,
                                                    size: 12,
                                                    color: Color(0xFFF59E0B),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            Text(
                                              perm.effectiveDbSlug,
                                              style: const TextStyle(
                                                color: Color(0xFF8B929E),
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    ...roles.map((role) {
                                      final dbSlug = perm.effectiveDbSlug;
                                      final override = ui.overrideGranted(
                                        role.slug,
                                        dbSlug,
                                      );
                                      final direct =
                                          override ??
                                          (snap.matrix.isGranted(
                                                role.slug,
                                                dbSlug,
                                              ) ||
                                              role.permissionSlugs.contains(
                                                dbSlug,
                                              ) ||
                                              role.permissionSlugs.contains(
                                                perm.slug,
                                              ));
                                      final inherited =
                                          (inheritedByRole[role.id] ?? const {})
                                              .contains(dbSlug) ||
                                          (inheritedByRole[role.id] ?? const {})
                                              .contains(perm.slug);
                                      final locked = role.isSuperAdmin;
                                      final effective =
                                          locked ||
                                          direct ||
                                          (override == null && inherited);
                                      final inheritedOnly =
                                          !locked &&
                                          override == null &&
                                          inherited &&
                                          !(snap.matrix.isGranted(
                                                role.slug,
                                                dbSlug,
                                              ) ||
                                              role.permissionSlugs.contains(
                                                dbSlug,
                                              ) ||
                                              role.permissionSlugs.contains(
                                                perm.slug,
                                              ));
                                      return DataCell(
                                        Tooltip(
                                          message: locked
                                              ? 'Super Admin is always granted'
                                              : override != null
                                              ? 'Saving…'
                                              : inheritedOnly
                                              ? 'Inherited from parent role'
                                              : direct
                                              ? 'Direct grant'
                                              : 'Not granted',
                                          child: Checkbox(
                                            value: effective,
                                            tristate: false,
                                            activeColor: inheritedOnly
                                                ? const Color(0xFF64748B)
                                                : null,
                                            onChanged:
                                                locked ||
                                                    ui.isMatrixPending(
                                                      role.slug,
                                                      dbSlug,
                                                    )
                                                ? null
                                                : (v) => toggleCell(
                                                    role: role,
                                                    perm: perm,
                                                    granted: v ?? false,
                                                    direct:
                                                        override ??
                                                        (snap.matrix.isGranted(
                                                              role.slug,
                                                              dbSlug,
                                                            ) ||
                                                            role.permissionSlugs
                                                                .contains(
                                                                  dbSlug,
                                                                ) ||
                                                            role.permissionSlugs
                                                                .contains(
                                                                  perm.slug,
                                                                )),
                                                    inherited: inherited,
                                                  ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                            ],
                          ),
                        ),
                ),
        ),
      ],
    );
  }
}

/// Lets the permission matrix move in both directions with the mouse.
///
/// The wheel moves down the permission list. Over the role columns on the
/// right, or with Shift held, the same wheel reveals the hidden roles.
/// Dragging the table moves it either way. No scrollbar track is drawn.
class _MatrixScroll extends StatefulWidget {
  const _MatrixScroll({required this.child});

  final Widget child;

  @override
  State<_MatrixScroll> createState() => _MatrixScrollState();
}

class _MatrixScrollState extends State<_MatrixScroll> {
  final _vertical = ScrollController();
  final _horizontal = ScrollController();
  final _viewportKey = GlobalKey();

  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  void _pan(ScrollController controller, double delta) {
    if (!controller.hasClients || delta == 0) return;
    final target = (controller.offset + delta).clamp(
      0.0,
      controller.position.maxScrollExtent,
    );
    if (target != controller.offset) controller.jumpTo(target);
  }

  bool _overRoleColumns(PointerScrollEvent event) {
    final viewport =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null || !viewport.hasSize) return false;
    final local = viewport.globalToLocal(event.position);
    return local.dx >= viewport.size.width * 0.42;
  }

  void _onSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (raw) {
      final signal = raw as PointerScrollEvent;
      final dx = signal.scrollDelta.dx;
      final dy = signal.scrollDelta.dy;
      final sideways = dx.abs() > dy.abs();
      final shift = HardwareKeyboard.instance.isShiftPressed;
      if (sideways || shift || _overRoleColumns(signal)) {
        _pan(_horizontal, sideways ? dx : dy);
      } else {
        _pan(_vertical, dy);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _viewportKey,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          scrollbars: false,
          dragDevices: const {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
            PointerDeviceKind.unknown,
          },
        ),
        child: SingleChildScrollView(
          controller: _vertical,
          primary: false,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: SingleChildScrollView(
            controller: _horizontal,
            primary: false,
            scrollDirection: Axis.horizontal,
            child: Listener(onPointerSignal: _onSignal, child: widget.child),
          ),
        ),
      ),
    );
  }
}

class _RolesTab extends HookConsumerWidget {
  const _RolesTab({required this.snap});

  final RbacSnapshot snap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(rbacControllerProvider);
    final controller = ref.read(rbacControllerProvider.notifier);
    final usersAsync = ref.watch(platformUsersSnapshotProvider);
    final users = usersAsync.asData?.value.users ?? const <PlatformUser>[];
    final usersCtrl = ref.read(platformUsersControllerProvider.notifier);
    final usersUi = ref.watch(platformUsersControllerProvider);

    final roles = [...snap.roles]
      ..sort((a, b) {
        if (a.isSystem != b.isSystem) return a.isSystem ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    RoleDefinition? selected;
    for (final r in roles) {
      if (r.id == ui.selectedRoleId) {
        selected = r;
        break;
      }
    }
    selected ??= roles.isEmpty ? null : roles.first;

    useEffect(() {
      if (selected != null && ui.selectedRoleId != selected.id) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          controller.selectRole(selected!.id);
        });
      }
      return null;
    }, [selected?.id]);

    final wide = MediaQuery.sizeOf(context).width >= 900;
    final busy = ui.isBusy || usersUi.isBusy;

    Future<void> openCreate() async {
      final result = await showRoleFormDialog(
        context: context,
        roles: roles,
        isBusy: busy,
      );
      if (result == null) return;
      await controller.createRole(
        name: result.name,
        slug: result.slug,
        description: result.description,
        cloneFromRoleId: result.cloneFromRoleId,
        parentRoleId: result.parentRoleId,
      );
    }

    Future<void> openEdit(RoleDefinition role) async {
      if (role.isSystem) return;
      final result = await showRoleFormDialog(
        context: context,
        roles: roles,
        role: role,
        isBusy: busy,
      );
      if (result == null) return;
      await controller.updateRole(
        roleId: role.id,
        name: result.name,
        description: result.description,
        parentRoleId: result.parentRoleId,
        clearParent: result.clearParent,
      );
    }

    Future<void> openAssign(RoleDefinition role) async {
      final userId = await showAssignRoleUserDialog(
        context: context,
        role: role,
        users: users,
        isBusy: busy,
      );
      if (userId == null) return;
      await usersCtrl.assignRole(userId: userId, role: role);
    }

    Future<void> confirmArchive(RoleDefinition role) async {
      if (role.isSystem) return;
      final ok = await AppDialogs.confirm(
        context,
        title: 'Archive ${role.name}?',
        message:
            'Custom roles are soft-archived and hidden from active matrices. '
            'Existing assignments should be reviewed before archiving.',
        confirmLabel: 'Archive',
        destructive: true,
      );
      if (ok != true) return;
      if (!context.mounted) return;
      final stepped = await ensurePeopleRbacStepUp(
        context: context,
        ref: ref,
        action: StepUpAction.modifyPermissions,
      );
      if (!stepped) return;
      if (!context.mounted) return;
      await controller.archiveRole(role);
    }

    final assignees = selected == null
        ? const <PlatformUser>[]
        : users.where((u) => u.hasRoleSlug(selected!.slug)).toList();

    final permDefs = <PermissionDefinition>[];
    if (selected != null) {
      for (final p in snap.permissions) {
        if (selected.permissionSlugs.contains(p.slug) ||
            selected.permissionSlugs.contains(p.effectiveDbSlug) ||
            (p.legacySlug != null &&
                selected.permissionSlugs.contains(p.legacySlug))) {
          permDefs.add(p);
        }
      }
      // Fallback: show raw slugs missing from catalog
      final known = {
        for (final p in permDefs) ...[
          p.slug,
          p.effectiveDbSlug,
          if (p.legacySlug != null) p.legacySlug!,
        ],
      };
      for (final slug in selected.permissionSlugs) {
        if (!known.contains(slug)) {
          permDefs.add(
            PermissionDefinition(
              slug: slug,
              name: slug,
              module: 'other',
              action: slug,
            ),
          );
        }
      }
    }
    permDefs.sort((a, b) {
      final m = a.module.compareTo(b.module);
      return m != 0 ? m : a.name.compareTo(b.name);
    });

    final list = AdminDeskPanel(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Roles',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                PermissionGateAny(
                  permissions: const [
                    PermissionSlugs.manageRoles,
                    PermissionSlugs.configurePermissions,
                  ],
                  child: TextButton.icon(
                    onPressed: busy ? null : openCreate,
                    icon: const Icon(LucideIcons.plus, size: 14),
                    label: const Text('Create'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: roles.isEmpty
                ? const Center(
                    child: Text(
                      'No roles yet. Create a custom role to get started.',
                      style: TextStyle(color: Color(0xFF8B929E)),
                    ),
                  )
                : ListView.builder(
                    itemCount: roles.length,
                    itemBuilder: (context, index) {
                      final r = roles[index];
                      final isSelected = selected?.id == r.id;
                      return ListTile(
                        selected: isSelected,
                        leading: Icon(
                          r.isSystem ? LucideIcons.lock : LucideIcons.shield,
                          size: 18,
                          color: AppColors.gold,
                        ),
                        title: Text(r.name),
                        subtitle: Text(
                          '${r.permissionSlugs.length} permissions · '
                          '${r.memberCount} members'
                          '${r.isSystem ? ' · system' : ' · custom'}',
                        ),
                        trailing: Text(
                          r.lifecycle.slug,
                          style: TextStyle(
                            color: r.lifecycle == RoleLifecycle.active
                                ? AppColors.success
                                : const Color(0xFF8B929E),
                            fontSize: 11,
                          ),
                        ),
                        onTap: () => controller.selectRole(r.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    final detail = selected == null
        ? const Center(
            child: Text(
              'Select a role',
              style: TextStyle(color: Color(0xFF8B929E)),
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selected.name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          selected.slug,
                          style: const TextStyle(color: Color(0xFF8B929E)),
                        ),
                      ],
                    ),
                  ),
                  PermissionGateAny(
                    permissions: const [
                      PermissionSlugs.manageRoles,
                      PermissionSlugs.configurePermissions,
                    ],
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (!selected.isSystem)
                          OutlinedButton.icon(
                            onPressed: busy ? null : () => openEdit(selected!),
                            icon: const Icon(LucideIcons.pencil, size: 14),
                            label: const Text('Edit'),
                          ),
                        OutlinedButton.icon(
                          onPressed: busy ? null : () => openAssign(selected!),
                          icon: const Icon(LucideIcons.userPlus, size: 14),
                          label: const Text('Assign'),
                        ),
                        if (!selected.isSystem)
                          OutlinedButton.icon(
                            onPressed: busy
                                ? null
                                : () => confirmArchive(selected!),
                            icon: const Icon(LucideIcons.archive, size: 14),
                            label: const Text('Archive'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                selected.description?.trim().isNotEmpty == true
                    ? selected.description!
                    : 'No description provided.',
                style: const TextStyle(color: Color(0xFF8B929E)),
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _RoleMetaChip(
                    icon: selected.isSystem
                        ? LucideIcons.lock
                        : LucideIcons.userCog,
                    label: selected.isSystem ? 'System role' : 'Custom role',
                  ),
                  _RoleMetaChip(
                    icon: LucideIcons.activity,
                    label: selected.lifecycle.slug,
                  ),
                  _RoleMetaChip(
                    icon: LucideIcons.key,
                    label: '${selected.permissionSlugs.length} permissions',
                  ),
                  _RoleMetaChip(
                    icon: LucideIcons.users,
                    label: '${selected.memberCount} members',
                  ),
                  if (selected.parentRoleId != null)
                    _RoleMetaChip(
                      icon: LucideIcons.gitBranch,
                      label: () {
                        for (final r in roles) {
                          if (r.id == selected!.parentRoleId) {
                            return 'Inherits ${r.name}';
                          }
                        }
                        return 'Has parent role';
                      }(),
                    ),
                ],
              ),
              if (snap.groups.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Apply permission group',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                PermissionGateAny(
                  permissions: const [
                    PermissionSlugs.manageRoles,
                    PermissionSlugs.configurePermissions,
                  ],
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final g in snap.groups)
                        OutlinedButton.icon(
                          onPressed: busy || selected.isSuperAdmin
                              ? null
                              : () async {
                                  final role = selected!;
                                  final ok = await AppDialogs.confirm(
                                    context,
                                    title: 'Apply ${g.name}?',
                                    message:
                                        'Grants ${g.permissionSlugs.length} permissions '
                                        'to ${role.name}. Existing grants are kept.',
                                    confirmLabel: 'Apply',
                                  );
                                  if (ok != true) return;
                                  await controller.applyGroup(role, g);
                                },
                          icon: const Icon(LucideIcons.layers, size: 14),
                          label: Text(g.name),
                        ),
                    ],
                  ),
                ),
              ],
              if (usersUi.message != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  usersUi.message!,
                  style: const TextStyle(color: AppColors.success),
                ),
              ],
              if (usersUi.error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  usersUi.error!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Permissions on this role',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                'Direct grants shown below. Gray matrix checks may be inherited from a parent.',
                style: TextStyle(color: Color(0xFF8B929E), fontSize: 12),
              ),
              const SizedBox(height: 8),
              if (permDefs.isEmpty)
                const Text(
                  'No direct permissions on this role yet.',
                  style: TextStyle(color: Color(0xFF8B929E)),
                )
              else
                ..._groupedPermissionTiles(permDefs),
              Builder(
                builder: (context) {
                  final inherited = roleInheritedPermissionSlugs(
                    selected!,
                    roles,
                  ).difference(selected.permissionSlugs);
                  if (inherited.isEmpty) return const SizedBox.shrink();
                  final inheritedDefs = <PermissionDefinition>[];
                  for (final p in snap.permissions) {
                    if (inherited.contains(p.slug) ||
                        inherited.contains(p.effectiveDbSlug) ||
                        (p.legacySlug != null &&
                            inherited.contains(p.legacySlug))) {
                      inheritedDefs.add(p);
                    }
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Inherited permissions',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Resolved from parent roles via RLS helpers.',
                        style: TextStyle(
                          color: Color(0xFF8B929E),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (inheritedDefs.isEmpty)
                        Text(
                          '${inherited.length} inherited slug(s)',
                          style: const TextStyle(color: Color(0xFF8B929E)),
                        )
                      else
                        ..._groupedPermissionTiles(inheritedDefs),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Assigned users',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (usersAsync.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(color: AppColors.gold),
                )
              else if (assignees.isEmpty)
                const Text(
                  'No platform users currently hold this role.',
                  style: TextStyle(color: Color(0xFF8B929E)),
                )
              else
                ...assignees.take(40).map((u) {
                  PlatformUserRoleAssignment? assignment;
                  for (final a in u.roles) {
                    if (a.roleId == selected!.id ||
                        a.roleSlug == selected.slug) {
                      assignment = a;
                      break;
                    }
                  }
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      child: Text(
                        u.initials,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    title: Text(u.displayName),
                    subtitle: Text(u.email),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          assignment?.isPrimary == true
                              ? 'Primary'
                              : 'Assigned',
                          style: const TextStyle(
                            color: Color(0xFF8B929E),
                            fontSize: 11,
                          ),
                        ),
                        if (assignment != null)
                          PermissionGateAny(
                            permissions: const [
                              PermissionSlugs.manageRoles,
                              PermissionSlugs.manageUsers,
                            ],
                            child: IconButton(
                              tooltip: 'Revoke role',
                              icon: const Icon(
                                LucideIcons.userMinus,
                                size: 16,
                                color: AppColors.error,
                              ),
                              onPressed: busy
                                  ? null
                                  : () async {
                                      final ok = await AppDialogs.confirm(
                                        context,
                                        title: 'Revoke ${selected!.name}?',
                                        message:
                                            'Remove this role from ${u.displayName}.',
                                        confirmLabel: 'Revoke',
                                        destructive: true,
                                      );
                                      if (ok != true) return;
                                      await usersCtrl.revokeRole(
                                        assignment: assignment!,
                                        userId: u.id,
                                      );
                                    },
                            ),
                          ),
                      ],
                    ),
                  );
                }),
            ],
          );

    if (!wide) {
      return selected == null
          ? list
          : Column(
              children: [
                Expanded(flex: 2, child: list),
                const Divider(height: 1),
                Expanded(flex: 3, child: detail),
              ],
            );
    }

    return Row(
      children: [
        SizedBox(width: 340, child: list),
        const VerticalDivider(width: 1),
        Expanded(child: detail),
      ],
    );
  }

  List<Widget> _groupedPermissionTiles(List<PermissionDefinition> perms) {
    final byModule = <String, List<PermissionDefinition>>{};
    for (final p in perms) {
      byModule.putIfAbsent(p.module, () => []).add(p);
    }
    final modules = byModule.keys.toList()..sort();
    return [
      for (final module in modules) ...[
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            module.toUpperCase(),
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...byModule[module]!.map(
          (p) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              LucideIcons.check,
              size: 14,
              color: AppColors.success,
            ),
            title: Text(p.name),
            subtitle: Text(
              p.effectiveDbSlug,
              style: const TextStyle(color: Color(0xFF8B929E), fontSize: 11),
            ),
          ),
        ),
      ],
    ];
  }
}

class _RoleMetaChip extends StatelessWidget {
  const _RoleMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x18FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.gold),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _GroupsTab extends HookConsumerWidget {
  const _GroupsTab({required this.snap});

  final RbacSnapshot snap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(rbacControllerProvider);
    final controller = ref.read(rbacControllerProvider.notifier);
    final selectedId = useState<String?>(
      snap.groups.isEmpty ? null : snap.groups.first.id,
    );

    PermissionGroup? selected;
    for (final g in snap.groups) {
      if (g.id == selectedId.value) {
        selected = g;
        break;
      }
    }
    selected ??= snap.groups.isEmpty ? null : snap.groups.first;

    final applyRoles = snap.roles
        .where((r) => r.lifecycle == RoleLifecycle.active && !r.isSuperAdmin)
        .toList();

    final targetRoleId = useState<String?>(
      applyRoles.isEmpty ? null : applyRoles.first.id,
    );
    final permDefs = <PermissionDefinition>[];
    if (selected != null) {
      for (final p in snap.permissions) {
        if (selected.permissionSlugs.contains(p.slug) ||
            selected.permissionSlugs.contains(p.effectiveDbSlug) ||
            (p.legacySlug != null &&
                selected.permissionSlugs.contains(p.legacySlug))) {
          permDefs.add(p);
        }
      }
    }

    final list = AdminDeskPanel(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Permission groups',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Expanded(
            child: snap.groups.isEmpty
                ? const Center(
                    child: Text(
                      'No permission groups loaded. Check RLS on permission_group_items.',
                      style: TextStyle(color: Color(0xFF8B929E)),
                    ),
                  )
                : ListView.builder(
                    itemCount: snap.groups.length,
                    itemBuilder: (context, index) {
                      final g = snap.groups[index];
                      return ListTile(
                        selected: selected?.id == g.id,
                        leading: const Icon(LucideIcons.layers, size: 18),
                        title: Text(g.name),
                        subtitle: Text(
                          '${g.permissionSlugs.length} permissions · ${g.slug}',
                        ),
                        onTap: () => selectedId.value = g.id,
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    final detail = selected == null
        ? const Center(
            child: Text(
              'Select a group',
              style: TextStyle(color: Color(0xFF8B929E)),
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              Text(
                selected.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                selected.description ?? selected.slug,
                style: const TextStyle(color: Color(0xFF8B929E)),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Apply to role',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              PermissionGateAny(
                permissions: const [
                  PermissionSlugs.manageRoles,
                  PermissionSlugs.configurePermissions,
                ],
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        // ignore: deprecated_member_use
                        value: targetRoleId.value,
                        decoration: const InputDecoration(
                          labelText: 'Target role',
                          isDense: true,
                        ),
                        items: [
                          for (final r in applyRoles)
                            DropdownMenuItem(value: r.id, child: Text(r.name)),
                        ],
                        onChanged: ui.isBusy
                            ? null
                            : (v) => targetRoleId.value = v,
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: ui.isBusy || targetRoleId.value == null
                          ? null
                          : () async {
                              RoleDefinition? role;
                              for (final r in applyRoles) {
                                if (r.id == targetRoleId.value) {
                                  role = r;
                                  break;
                                }
                              }
                              if (role == null) return;
                              final ok = await AppDialogs.confirm(
                                context,
                                title: 'Apply ${selected!.name}?',
                                message:
                                    'Grant ${selected.permissionSlugs.length} permissions '
                                    'to ${role.name}.',
                                confirmLabel: 'Apply',
                              );
                              if (ok != true) return;
                              await controller.applyGroup(role, selected);
                            },
                      icon: const Icon(LucideIcons.check, size: 16),
                      label: const Text('Apply'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.charcoal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Permissions in group',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (selected.permissionSlugs.isEmpty)
                const Text(
                  'This group has no permissions (items may be blocked by RLS).',
                  style: TextStyle(color: Color(0xFF8B929E)),
                )
              else if (permDefs.isEmpty)
                ...selected.permissionSlugs.map(
                  (s) => ListTile(
                    dense: true,
                    leading: const Icon(LucideIcons.key, size: 14),
                    title: Text(s),
                  ),
                )
              else
                ...permDefs.map(
                  (p) => ListTile(
                    dense: true,
                    leading: const Icon(
                      LucideIcons.check,
                      size: 14,
                      color: AppColors.success,
                    ),
                    title: Text(p.name),
                    subtitle: Text(
                      p.effectiveDbSlug,
                      style: const TextStyle(
                        color: Color(0xFF8B929E),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
            ],
          );

    final wide = MediaQuery.sizeOf(context).width >= 900;
    if (!wide) {
      return Column(
        children: [
          Expanded(flex: 2, child: list),
          const Divider(height: 1),
          Expanded(flex: 3, child: detail),
        ],
      );
    }
    return Row(
      children: [
        SizedBox(width: 340, child: list),
        const VerticalDivider(width: 1),
        Expanded(child: detail),
      ],
    );
  }
}

class _ApprovalsTab extends HookConsumerWidget {
  const _ApprovalsTab({required this.snap});

  final RbacSnapshot snap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(rbacControllerProvider);
    final controller = ref.read(rbacControllerProvider.notifier);
    final pane = useState('requests');
    final selectedRequestId = useState<String?>(
      snap.accessRequests.isEmpty ? null : snap.accessRequests.first.id,
    );
    final selectedPolicyId = useState<String?>(
      snap.policies.isEmpty ? null : snap.policies.first.id,
    );

    final pending = snap.accessRequests.where((r) => r.isPending).toList();
    final reviewed = snap.accessRequests.where((r) => !r.isPending).toList();
    final orderedRequests = [...pending, ...reviewed];

    AccessRequest? selectedRequest;
    for (final r in orderedRequests) {
      if (r.id == selectedRequestId.value) {
        selectedRequest = r;
        break;
      }
    }
    selectedRequest ??= orderedRequests.isEmpty ? null : orderedRequests.first;

    ApprovalPolicy? selectedPolicy;
    for (final p in snap.policies) {
      if (p.id == selectedPolicyId.value) {
        selectedPolicy = p;
        break;
      }
    }
    selectedPolicy ??= snap.policies.isEmpty ? null : snap.policies.first;

    final list = AdminDeskPanel(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'requests',
                        label: Text(
                          pending.isEmpty
                              ? 'Requests'
                              : 'Requests (${pending.length})',
                        ),
                      ),
                      const ButtonSegment(
                        value: 'policies',
                        label: Text('Policies'),
                      ),
                    ],
                    selected: {pane.value},
                    onSelectionChanged: (s) => pane.value = s.first,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: pane.value == 'requests'
                ? (orderedRequests.isEmpty
                      ? const AdminDeskEmptyState(
                          icon: LucideIcons.clipboardCheck,
                          title: 'No access requests',
                          message:
                              'Submit a request from the toolbar, or wait for staff to ask for roles/permissions.',
                        )
                      : ListView.builder(
                          itemCount: orderedRequests.length,
                          itemBuilder: (context, index) {
                            final r = orderedRequests[index];
                            return ListTile(
                              selected: selectedRequest?.id == r.id,
                              leading: Icon(
                                r.isPending
                                    ? LucideIcons.clock
                                    : r.status == 'approved'
                                    ? LucideIcons.checkCircle
                                    : LucideIcons.xCircle,
                                size: 18,
                                color: r.isPending
                                    ? AppColors.gold
                                    : r.status == 'approved'
                                    ? AppColors.success
                                    : const Color(0xFF8B929E),
                              ),
                              title: Text(r.targetLabel),
                              subtitle: Text(
                                '${r.requesterName ?? r.requesterEmail ?? r.requesterId} · ${r.status}',
                              ),
                              onTap: () => selectedRequestId.value = r.id,
                            );
                          },
                        ))
                : (snap.policies.isEmpty
                      ? const AdminDeskEmptyState(
                          icon: LucideIcons.shield,
                          title: 'No approval policies',
                          message:
                              'Policies appear from approval_policies when seeded or created.',
                        )
                      : ListView.builder(
                          itemCount: snap.policies.length,
                          itemBuilder: (context, index) {
                            final p = snap.policies[index];
                            return ListTile(
                              selected: selectedPolicy?.id == p.id,
                              leading: Icon(
                                LucideIcons.shield,
                                size: 18,
                                color: p.enabled
                                    ? AppColors.success
                                    : const Color(0xFF8B929E),
                              ),
                              title: Text(p.name),
                              subtitle: Text(
                                '${p.enabled ? 'Enabled' : 'Disabled'} · approver ${p.approverRoleSlug}',
                              ),
                              onTap: () => selectedPolicyId.value = p.id,
                            );
                          },
                        )),
          ),
        ],
      ),
    );

    final Widget detail;
    if (pane.value == 'requests') {
      detail = selectedRequest == null
          ? const Center(
              child: Text(
                'Select a request',
                style: TextStyle(color: Color(0xFF8B929E)),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                Text(
                  selectedRequest.targetLabel,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Status · ${selectedRequest.status}',
                  style: const TextStyle(color: Color(0xFF8B929E)),
                ),
                const SizedBox(height: AppSpacing.lg),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(LucideIcons.user, size: 18),
                  title: Text(
                    selectedRequest.requesterName ??
                        selectedRequest.requesterEmail ??
                        'Requester',
                  ),
                  subtitle: Text(selectedRequest.requesterId),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(LucideIcons.messageSquare, size: 18),
                  title: const Text('Reason'),
                  subtitle: Text(selectedRequest.reason),
                ),
                if (selectedRequest.reviewedAt != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(LucideIcons.calendar, size: 18),
                    title: const Text('Reviewed'),
                    subtitle: Text(
                      selectedRequest.reviewedAt!.toLocal().toString(),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                if (selectedRequest.isPending)
                  PermissionGateAny(
                    permissions: const [
                      PermissionSlugs.manageRoles,
                      PermissionSlugs.configurePermissions,
                    ],
                    child: Row(
                      children: [
                        FilledButton.icon(
                          onPressed: ui.isBusy
                              ? null
                              : () async {
                                  final ok = await AppDialogs.confirm(
                                    context,
                                    title: 'Approve access?',
                                    message:
                                        'Approve ${selectedRequest!.targetLabel} for '
                                        '${selectedRequest.requesterName ?? 'this user'}. '
                                        'Role/permission grants apply immediately.',
                                    confirmLabel: 'Approve',
                                  );
                                  if (ok != true) return;
                                  await controller.reviewAccessRequest(
                                    request: selectedRequest,
                                    approve: true,
                                  );
                                },
                          icon: const Icon(LucideIcons.check, size: 16),
                          label: const Text('Approve'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: AppColors.charcoal,
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: ui.isBusy
                              ? null
                              : () async {
                                  final ok = await AppDialogs.confirm(
                                    context,
                                    title: 'Deny access?',
                                    message:
                                        'Deny ${selectedRequest!.targetLabel}.',
                                    confirmLabel: 'Deny',
                                    destructive: true,
                                  );
                                  if (ok != true) return;
                                  await controller.reviewAccessRequest(
                                    request: selectedRequest,
                                    approve: false,
                                  );
                                },
                          icon: const Icon(LucideIcons.x, size: 16),
                          label: const Text('Deny'),
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    'This request was ${selectedRequest.status}.',
                    style: const TextStyle(color: Color(0xFF8B929E)),
                  ),
              ],
            );
    } else {
      detail = selectedPolicy == null
          ? const Center(
              child: Text(
                'Select a policy',
                style: TextStyle(color: Color(0xFF8B929E)),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                Text(
                  selectedPolicy.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  selectedPolicy.description ?? selectedPolicy.actionType.name,
                  style: const TextStyle(color: Color(0xFF8B929E)),
                ),
                const SizedBox(height: AppSpacing.lg),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Approver role'),
                  subtitle: Text(selectedPolicy.approverRoleSlug),
                ),
                if (selectedPolicy.thresholdAmount != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Threshold'),
                    subtitle: Text(
                      selectedPolicy.thresholdAmount!.toStringAsFixed(0),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                PermissionGateAny(
                  permissions: const [
                    PermissionSlugs.manageRoles,
                    PermissionSlugs.configurePermissions,
                  ],
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Policy enabled'),
                    subtitle: Text(
                      selectedPolicy.enabled
                          ? 'High-risk actions require approval'
                          : 'Policy is off — no approval gate',
                    ),
                    value: selectedPolicy.enabled,
                    onChanged: ui.isBusy
                        ? null
                        : (v) => controller.setApprovalPolicyEnabled(
                            policy: selectedPolicy!,
                            enabled: v,
                          ),
                  ),
                ),
              ],
            );
    }

    final wide = MediaQuery.sizeOf(context).width >= 900;
    if (!wide) {
      return Column(
        children: [
          Expanded(flex: 2, child: list),
          const Divider(height: 1),
          Expanded(flex: 3, child: detail),
        ],
      );
    }
    return Row(
      children: [
        SizedBox(width: 360, child: list),
        const VerticalDivider(width: 1),
        Expanded(child: detail),
      ],
    );
  }
}
