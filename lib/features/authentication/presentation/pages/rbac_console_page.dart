import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/rbac_models.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/rbac_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Enterprise RBAC console — roles, permission matrix, groups, approvals.
class RbacConsolePage extends HookConsumerWidget {
  const RbacConsolePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapAsync = ref.watch(rbacSnapshotProvider);
    final ui = ref.watch(rbacControllerProvider);
    final controller = ref.read(rbacControllerProvider.notifier);
    final tab = useState(ui.hubTab);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Roles & Permissions'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: () => ref.invalidate(rbacSnapshotProvider),
          ),
        ],
      ),
      body: snapAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Unable to load RBAC: $e')),
        data: (snap) {
          return Column(
            children: [
              if (ui.message != null)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    ui.message!,
                    style: const TextStyle(color: AppColors.success),
                  ),
                ),
              if (ui.error != null)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    ui.error!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xl,
                  0,
                ),
                child: Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    _Metric(
                      label: 'Roles in use',
                      value: '${snap.analytics.rolesInUse}',
                      icon: LucideIcons.shield,
                    ),
                    _Metric(
                      label: 'Permissions',
                      value: '${snap.analytics.permissionCount}',
                      icon: LucideIcons.key,
                    ),
                    _Metric(
                      label: 'Custom roles',
                      value: '${snap.analytics.customRoles}',
                      icon: LucideIcons.userCog,
                    ),
                    _Metric(
                      label: 'Access denied',
                      value: '${snap.analytics.accessDeniedEvents}',
                      icon: LucideIcons.shieldOff,
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    for (final entry in const [
                      (0, 'Matrix'),
                      (1, 'Roles'),
                      (2, 'Groups'),
                      (3, 'Approvals'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: ChoiceChip(
                          label: Text(entry.$2),
                          selected: tab.value == entry.$1,
                          onSelected: (_) {
                            tab.value = entry.$1;
                            controller.setTab(entry.$1);
                          },
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: tab.value,
                  children: [
                    _MatrixTab(snap: snap),
                    _RolesTab(snap: snap),
                    _GroupsTab(snap: snap),
                    _ApprovalsTab(snap: snap),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: AppColors.gold),
              const SizedBox(height: AppSpacing.sm),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatrixTab extends ConsumerWidget {
  const _MatrixTab({required this.snap});

  final RbacSnapshot snap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(rbacControllerProvider.notifier);
    final roles = snap.matrix.roles
        .where((r) => r.lifecycle == RoleLifecycle.active)
        .take(6)
        .toList();
    final perms = snap.matrix.permissions;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: [
            const DataColumn(label: Text('Permission')),
            ...roles.map((r) => DataColumn(label: Text(r.name))),
          ],
          rows: [
            for (final perm in perms)
              DataRow(
                cells: [
                  DataCell(
                    SizedBox(
                      width: 180,
                      child: Text(
                        perm.name,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                  ...roles.map((role) {
                    final granted = snap.matrix.isGranted(
                      role.slug,
                      perm.effectiveDbSlug,
                    );
                    final locked = role.isSuperAdmin;
                    return DataCell(
                      Checkbox(
                        value: locked ? true : granted,
                        onChanged: locked
                            ? null
                            : (v) => controller.toggleMatrixCell(
                                  roleId: role.id,
                                  roleSlug: role.slug,
                                  permissionSlug: perm.effectiveDbSlug,
                                  granted: v ?? false,
                                ),
                      ),
                    );
                  }),
                ],
              ),
          ],
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
    final name = useTextEditingController();
    final slug = useTextEditingController();
    final desc = useTextEditingController();
    final cloneFrom = useState<String?>(null);
    final ui = ref.watch(rbacControllerProvider);
    final controller = ref.read(rbacControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Text('Smart Permission Builder™', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        const Text('Create or clone roles without deploying code.'),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Role name'),
          onChanged: (v) {
            if (slug.text.isEmpty || slug.text == _slugify(name.text)) {
              slug.text = _slugify(v);
            }
          },
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: slug,
          decoration: const InputDecoration(labelText: 'Slug'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: desc,
          decoration: const InputDecoration(labelText: 'Description'),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String?>(
          // ignore: deprecated_member_use
          value: cloneFrom.value,
          decoration: const InputDecoration(labelText: 'Clone from (optional)'),
          items: [
            const DropdownMenuItem(value: null, child: Text('None')),
            ...snap.roles.map(
              (r) => DropdownMenuItem(value: r.id, child: Text(r.name)),
            ),
          ],
          onChanged: (v) => cloneFrom.value = v,
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Create role',
          expand: true,
          isLoading: ui.isBusy,
          icon: LucideIcons.shield,
          onPressed: ui.isBusy
              ? null
              : () async {
                  await controller.createRole(
                    name: name.text.trim(),
                    slug: slug.text.trim(),
                    description: desc.text.trim().isEmpty ? null : desc.text.trim(),
                    cloneFromRoleId: cloneFrom.value,
                  );
                  name.clear();
                  slug.clear();
                  desc.clear();
                },
        ),
        const Divider(height: AppSpacing.xxl),
        ...snap.roles.map(
          (r) => Card(
            elevation: 0,
            child: ListTile(
              leading: Icon(
                r.isSystem ? LucideIcons.lock : LucideIcons.shield,
                color: AppColors.gold,
              ),
              title: Text(r.name),
              subtitle: Text(
                '${r.slug} · ${r.permissionSlugs.length} permissions'
                '${r.isSystem ? ' · system' : ''}',
              ),
              trailing: r.isSystem
                  ? null
                  : IconButton(
                      tooltip: 'Archive',
                      icon: const Icon(LucideIcons.archive),
                      onPressed: () => controller.archiveRole(r),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  String _slugify(String input) => input
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}

class _GroupsTab extends ConsumerWidget {
  const _GroupsTab({required this.snap});

  final RbacSnapshot snap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(rbacControllerProvider.notifier);
    final selectedRole = snap.roles.isEmpty ? null : snap.roles.first;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Text('Permission groups', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Assign a group to grant all included permissions in one action.',
        ),
        const SizedBox(height: AppSpacing.lg),
        ...snap.groups.map(
          (g) => Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(LucideIcons.layers),
              title: Text(g.name),
              subtitle: Text(
                '${g.permissionSlugs.length} permissions · ${g.slug}',
              ),
              trailing: selectedRole == null
                  ? null
                  : TextButton(
                      onPressed: () => controller.applyGroup(selectedRole, g),
                      child: Text('Apply to ${selectedRole.name}'),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ApprovalsTab extends StatelessWidget {
  const _ApprovalsTab({required this.snap});

  final RbacSnapshot snap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Text('Approval policies', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'High-risk actions require configured approvers before completing.',
        ),
        const SizedBox(height: AppSpacing.lg),
        ...snap.policies.map(
          (p) => Card(
            elevation: 0,
            child: ListTile(
              leading: Icon(
                p.enabled ? LucideIcons.gitPullRequest : LucideIcons.pause,
                color: AppColors.gold,
              ),
              title: Text(p.name),
              subtitle: Text(
                [
                  p.description ?? p.actionType.slug,
                  'Approver: ${p.approverRoleSlug}',
                  if (p.thresholdAmount != null)
                    'Threshold: ₦${p.thresholdAmount!.toStringAsFixed(0)}',
                ].join(' · '),
              ),
              trailing: Text(p.enabled ? 'Active' : 'Off'),
            ),
          ),
        ),
        const Divider(height: AppSpacing.xxl),
        Text(
          'Enterprise controls',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const ListTile(
          leading: Icon(LucideIcons.siren),
          title: Text('Break-Glass Mode'),
          subtitle: Text(
            'Temporary elevation with mandatory reason, expiry, and audit vault',
          ),
        ),
        const ListTile(
          leading: Icon(LucideIcons.clipboardCheck),
          title: Text('Access Review & Certification'),
          subtitle: Text(
            'Scheduled department head reviews with revocation recommendations',
          ),
        ),
      ],
    );
  }
}
