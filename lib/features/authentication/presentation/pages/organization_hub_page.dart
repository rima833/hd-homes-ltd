import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/organization_models.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/organization_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Organization Hub — staff directory, teams, org chart, branches, onboarding.
class OrganizationHubPage extends HookConsumerWidget {
  const OrganizationHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapAsync = ref.watch(organizationSnapshotProvider);
    final ui = ref.watch(organizationControllerProvider);
    final controller = ref.read(organizationControllerProvider.notifier);
    final tab = useState(ui.hubTab);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Organization & Staff'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: () {
              ref.invalidate(organizationSnapshotProvider);
              ref.invalidate(orgChartProvider);
            },
          ),
        ],
      ),
      body: snapAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Unable to load organization: $e')),
        data: (snap) {
          return Column(
            children: [
              if (ui.message != null)
                MaterialBanner(
                  content: Text(ui.message!),
                  actions: [
                    TextButton(
                      onPressed: () => controller.setTab(tab.value),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              if (ui.error != null)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(ui.error!, style: const TextStyle(color: AppColors.error)),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xl,
                  0,
                ),
                child: _AnalyticsStrip(analytics: snap.analytics),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    for (final entry in const [
                      (0, 'Directory'),
                      (1, 'Departments'),
                      (2, 'Teams'),
                      (3, 'Org Chart'),
                      (4, 'Onboarding'),
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
                    _DirectoryTab(snap: snap),
                    _DepartmentsTab(snap: snap),
                    _TeamsTab(snap: snap),
                    const _OrgChartTab(),
                    _OnboardingTab(snap: snap),
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

class _AnalyticsStrip extends StatelessWidget {
  const _AnalyticsStrip({required this.analytics});

  final StaffAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        _StatCard(
          label: 'Total employees',
          value: '${analytics.totalEmployees}',
          subtitle: '+${analytics.newHiresThisMonth} this month',
          icon: LucideIcons.users,
        ),
        _StatCard(
          label: 'Active staff',
          value: '${analytics.activeStaff}',
          subtitle: '${analytics.activeRate.toStringAsFixed(0)}% active',
          icon: LucideIcons.userCheck,
          accent: AppColors.success,
        ),
        _StatCard(
          label: 'Departments',
          value: '${analytics.departmentsConfigured}',
          subtitle: 'Configured',
          icon: LucideIcons.building,
        ),
        _StatCard(
          label: 'On leave',
          value: '${analytics.onLeave}',
          subtitle: 'Currently',
          icon: LucideIcons.calendar,
          accent: analytics.onLeave > 0 ? AppColors.info : null,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.accent,
  });

  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.gold;
    return SizedBox(
      width: 160,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: AppSpacing.sm),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
              ),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              Text(subtitle, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectoryTab extends HookConsumerWidget {
  const _DirectoryTab({required this.snap});

  final OrganizationSnapshot snap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(staffDirectoryFilterProvider);
    final filterCtrl = ref.read(staffDirectoryFilterProvider.notifier);
    final filtered = ref.watch(filteredStaffProvider).valueOrNull ?? snap.employees;
    final selectedId = ref.watch(organizationControllerProvider).selectedEmployeeId;
    Employee? selected;
    if (selectedId != null) {
      for (final e in filtered) {
        if (e.id == selectedId) {
          selected = e;
          break;
        }
      }
    }
    selected ??= filtered.isEmpty ? null : filtered.first;
    final queryCtrl = useTextEditingController(text: filter.query ?? '');
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final list = Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: TextField(
            controller: queryCtrl,
            decoration: const InputDecoration(
              hintText: 'Search name, email, employee ID…',
              prefixIcon: Icon(LucideIcons.search),
            ),
            onChanged: filterCtrl.setQuery,
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              FilterChip(
                label: const Text('All statuses'),
                selected: filter.status == null,
                onSelected: (_) => filterCtrl.setStatus(null),
              ),
              const SizedBox(width: AppSpacing.sm),
              for (final s in [
                StaffStatus.active,
                StaffStatus.onLeave,
                StaffStatus.remote,
                StaffStatus.probation,
              ])
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: FilterChip(
                    label: Text(s.label),
                    selected: filter.status == s,
                    onSelected: (sel) => filterCtrl.setStatus(sel ? s : null),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final e = filtered[index];
              return ListTile(
                selected: selected?.id == e.id,
                leading: CircleAvatar(
                  backgroundColor: e.status.color.withValues(alpha: 0.15),
                  child: Text(e.initials),
                ),
                title: Text(e.displayName),
                subtitle: Text(
                  '${e.positionTitle ?? 'Staff'} · ${e.departmentName ?? '—'}',
                ),
                trailing: Chip(
                  label: Text(e.status.label),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: e.status.color.withValues(alpha: 0.12),
                ),
                onTap: () => ref
                    .read(organizationControllerProvider.notifier)
                    .selectEmployee(e.id),
              );
            },
          ),
        ),
      ],
    );

    final detail = selected == null
        ? const Center(child: Text('Select a staff member'))
        : _EmployeeDetail(employee: selected, snap: snap);

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
        SizedBox(width: 360, child: list),
        const VerticalDivider(width: 1),
        Expanded(child: detail),
      ],
    );
  }
}

class _EmployeeDetail extends ConsumerWidget {
  const _EmployeeDetail({required this.employee, required this.snap});

  final Employee employee;
  final OrganizationSnapshot snap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(organizationControllerProvider.notifier);
    final chain = OrganizationEngine.reportingChain(snap.employees, employee.id);
    final reports =
        OrganizationEngine.directReports(snap.employees, employee.id);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
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
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _info('Employee ID', employee.employeeCode),
        _info('Department', employee.departmentName ?? '—'),
        _info('Team', employee.teamName ?? '—'),
        _info('Reports to', employee.managerName ?? chain.firstOrNull?.displayName ?? '—'),
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
          Text('Direct reports', style: Theme.of(context).textTheme.titleMedium),
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
        Wrap(
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
                onPressed: () => controller.changeStatus(employee.id, s),
              ),
          ],
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

class _DepartmentsTab extends StatelessWidget {
  const _DepartmentsTab({required this.snap});

  final OrganizationSnapshot snap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Text('Core departments', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        ...snap.departments.map(
          (d) => Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(LucideIcons.building),
              title: Text(d.name),
              subtitle: Text(d.description ?? d.slug),
              trailing: Text('${d.memberCount} staff'),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Branches', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        ...snap.branches.map(
          (b) => Card(
            elevation: 0,
            child: ListTile(
              leading: Icon(
                b.isPrimary ? LucideIcons.landmark : LucideIcons.mapPin,
                color: AppColors.gold,
              ),
              title: Text(b.name),
              subtitle: Text(
                [
                  if (b.isPrimary) 'Primary Office',
                  if (b.address != null) b.address!,
                  if (b.phone != null) b.phone!,
                ].join(' · '),
              ),
              trailing: Text(b.status.slug),
            ),
          ),
        ),
      ],
    );
  }
}

class _TeamsTab extends StatelessWidget {
  const _TeamsTab({required this.snap});

  final OrganizationSnapshot snap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Text('Teams', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        ...snap.teams.map(
          (t) => Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(LucideIcons.users),
              title: Text(t.name),
              subtitle: Text(
                '${t.departmentName ?? 'Department'} · ${t.description ?? ''}',
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${t.memberCount} members'),
                  Text(t.status.slug, style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OrgChartTab extends ConsumerWidget {
  const _OrgChartTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chartAsync = ref.watch(orgChartProvider);
    return chartAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (nodes) {
        if (nodes.isEmpty) {
          return const Center(child: Text('No reporting hierarchy yet.'));
        }
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Text(
              'Reporting hierarchy',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            ...nodes.map((n) => _OrgNodeView(node: n, depth: 0)),
          ],
        );
      },
    );
  }
}

class _OrgNodeView extends StatelessWidget {
  const _OrgNodeView({required this.node, required this.depth});

  final OrgChartNode node;
  final int depth;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: depth * 20.0, bottom: AppSpacing.sm),
          child: Card(
            elevation: 0,
            color: depth == 0
                ? AppColors.gold.withValues(alpha: 0.08)
                : Theme.of(context).colorScheme.surfaceContainerLowest,
            child: ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                child: Text(node.employee.initials, style: const TextStyle(fontSize: 11)),
              ),
              title: Text(node.employee.displayName),
              subtitle: Text(
                '${node.employee.positionTitle ?? 'Staff'} · ${node.employee.departmentName ?? ''}',
              ),
              trailing: Text(
                node.employee.status.label,
                style: TextStyle(color: node.employee.status.color, fontSize: 12),
              ),
            ),
          ),
        ),
        ...node.directReports.map(
          (c) => _OrgNodeView(node: c, depth: depth + 1),
        ),
      ],
    );
  }
}

class _OnboardingTab extends HookConsumerWidget {
  const _OnboardingTab({required this.snap});

  final OrganizationSnapshot snap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final first = useTextEditingController();
    final last = useTextEditingController();
    final email = useTextEditingController();
    final phone = useTextEditingController();
    final deptId = useState<String?>(
      snap.departments.isEmpty ? null : snap.departments.first.id,
    );
    final ui = ref.watch(organizationControllerProvider);
    final controller = ref.read(organizationControllerProvider.notifier);
    final selectedId = ui.selectedEmployeeId;
    final onboarding = useState<OnboardingProgress?>(null);

    useEffect(() {
      if (selectedId == null) {
        onboarding.value = null;
        return null;
      }
      Future.microtask(() async {
        final p = await ref
            .read(organizationServiceProvider)
            .loadOnboarding(selectedId);
        onboarding.value = p;
      });
      return null;
    }, [selectedId]);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Text(
          'Staff onboarding',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Create employee account → assign department & team → roles → '
          'welcome credentials → profile → MFA → activate',
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: first,
          decoration: const InputDecoration(labelText: 'First name'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: last,
          decoration: const InputDecoration(labelText: 'Last name'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: email,
          decoration: const InputDecoration(labelText: 'Work email'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: phone,
          decoration: const InputDecoration(labelText: 'Phone'),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: deptId.value,
          decoration: const InputDecoration(labelText: 'Department'),
          items: [
            for (final d in snap.departments)
              DropdownMenuItem(value: d.id, child: Text(d.name)),
          ],
          onChanged: (v) => deptId.value = v,
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Create employee record',
          expand: true,
          isLoading: ui.isBusy,
          icon: LucideIcons.userPlus,
          onPressed: ui.isBusy
              ? null
              : () async {
                  await controller.createEmployee(
                    firstName: first.text.trim(),
                    lastName: last.text.trim(),
                    email: email.text.trim().isEmpty ? null : email.text.trim(),
                    phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
                    departmentId: deptId.value,
                  );
                  first.clear();
                  last.clear();
                  email.clear();
                  phone.clear();
                },
        ),
        if (selectedId != null && onboarding.value != null) ...[
          const Divider(height: AppSpacing.xxl),
          Text(
            'Onboarding checklist',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(value: onboarding.value!.percentComplete),
          const SizedBox(height: AppSpacing.md),
          ...OnboardingStep.values.map((step) {
            final done = onboarding.value!.completedSteps.contains(step);
            return CheckboxListTile(
              value: done,
              title: Text(step.label),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: done
                  ? null
                  : (_) async {
                      await controller.advanceOnboarding(selectedId, step);
                      final p = await ref
                          .read(organizationServiceProvider)
                          .loadOnboarding(selectedId);
                      onboarding.value = p;
                    },
            );
          }),
        ],
      ],
    );
  }
}
