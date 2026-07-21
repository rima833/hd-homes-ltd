import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/observability_models.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/audit_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Executive Command Center — live operational + security observability.
class ObservabilityCommandCenterPage extends ConsumerWidget {
  const ObservabilityCommandCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final centerAsync = ref.watch(commandCenterProvider);
    final searchAsync = ref.watch(adminAuditSearchProvider);
    final ui = ref.watch(auditControllerProvider);
    final controller = ref.read(auditControllerProvider.notifier);
    final filter = ref.watch(observabilityFilterProvider);
    final filterCtrl = ref.read(observabilityFilterProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Observability Command Center'),
        actions: [
          IconButton(
            tooltip: 'Publish probe',
            icon: const Icon(LucideIcons.activity),
            onPressed: ui.isBusy ? null : controller.publishDemoEvent,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: () {
              ref.invalidate(commandCenterProvider);
              ref.invalidate(adminAuditSearchProvider);
            },
          ),
        ],
      ),
      body: centerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Command center unavailable: $e')),
        data: (snap) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: [
                  if (ui.message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Text(
                        ui.message!,
                        style: const TextStyle(color: AppColors.success),
                      ),
                    ),
                  if (ui.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Text(
                        ui.error!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  Text(
                    'Executive Command Center',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Live activity, security posture, and system health',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: [
                      _MetricCard(
                        label: "Today's activity",
                        value: '${snap.todayActivity}',
                        icon: LucideIcons.activity,
                      ),
                      _MetricCard(
                        label: 'Active users',
                        value: '${snap.activeUsersEstimate}',
                        icon: LucideIcons.users,
                      ),
                      _MetricCard(
                        label: 'Failed logins',
                        value: '${snap.failedLogins}',
                        icon: LucideIcons.shieldAlert,
                        accent: snap.failedLogins > 0
                            ? AppColors.warning
                            : null,
                      ),
                      _MetricCard(
                        label: 'Open alerts',
                        value: '${snap.openAlerts}',
                        icon: LucideIcons.bell,
                      ),
                      _MetricCard(
                        label: 'Critical alerts',
                        value: '${snap.criticalAlerts}',
                        icon: LucideIcons.siren,
                        accent: snap.criticalAlerts > 0
                            ? AppColors.error
                            : null,
                      ),
                      _MetricCard(
                        label: 'Security score',
                        value: '${snap.securityScore}',
                        icon: LucideIcons.shieldCheck,
                        accent: snap.securityScore >= 80
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'System health',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final h in snap.health)
                        Chip(
                          avatar: CircleAvatar(
                            backgroundColor: h.status.color,
                            radius: 6,
                          ),
                          label: Text(
                            '${h.label}${h.latencyMs != null ? ' · ${h.latencyMs}ms' : ''}',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _AlertsPanel(snap: snap, controller: controller)),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(child: _RecentPanel(records: snap.recentActivity)),
                      ],
                    )
                  else ...[
                    _AlertsPanel(snap: snap, controller: controller),
                    const SizedBox(height: AppSpacing.lg),
                    _RecentPanel(records: snap.recentActivity),
                  ],
                  const Divider(height: AppSpacing.xxl),
                  Text(
                    'Audit search',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      for (final preset in [
                        ActivityDatePreset.today,
                        ActivityDatePreset.last7Days,
                        ActivityDatePreset.last30Days,
                      ])
                        FilterChip(
                          label: Text(preset.label),
                          selected: filter.preset == preset,
                          onSelected: (_) => filterCtrl.setPreset(preset),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  searchAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Search failed: $e'),
                    data: (rows) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Text('${rows.length} records'),
                              const Spacer(),
                              PrimaryButton(
                                label: 'Export CSV',
                                icon: LucideIcons.download,
                                isLoading: ui.isBusy,
                                onPressed: rows.isEmpty
                                    ? null
                                    : () async {
                                        await controller.exportVisible(rows);
                                        final csv = ref
                                            .read(auditControllerProvider)
                                            .exportedCsv;
                                        if (csv != null && context.mounted) {
                                          await Clipboard.setData(
                                            ClipboardData(text: csv),
                                          );
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'CSV copied to clipboard',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          ...rows.take(40).map(
                                (r) => ListTile(
                                  dense: true,
                                  leading: Icon(
                                    r.severity.icon,
                                    color: r.severity.color,
                                    size: 20,
                                  ),
                                  title: Text(r.timelineTitle),
                                  subtitle: Text(
                                    '${r.module} · ${r.category.label} · '
                                    '${DateFormat('MMM d HH:mm').format(r.createdAt.toLocal())}',
                                  ),
                                  trailing: Text(r.status.slug),
                                ),
                              ),
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: 160,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: AppSpacing.sm),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertsPanel extends StatelessWidget {
  const _AlertsPanel({required this.snap, required this.controller});

  final CommandCenterSnapshot snap;
  final AuditController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Security alerts', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (snap.alerts.isEmpty)
          const Text('No open alerts.')
        else
          ...snap.alerts.map(
            (a) => Card(
              elevation: 0,
              child: ListTile(
                leading: Icon(a.severity.icon, color: a.severity.color),
                title: Text(a.title),
                subtitle: Text(a.description ?? a.lifecycle.slug),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: 'Acknowledge',
                      icon: const Icon(LucideIcons.check, size: 18),
                      onPressed: () => controller.acknowledgeAlert(a.id),
                    ),
                    IconButton(
                      tooltip: 'Resolve',
                      icon: const Icon(LucideIcons.checkCheck, size: 18),
                      onPressed: () => controller.resolveAlert(a.id),
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

class _RecentPanel extends StatelessWidget {
  const _RecentPanel({required this.records});

  final List<AuditRecord> records;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent activity', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (records.isEmpty)
          const Text('No recent audit events.')
        else
          ...records.take(12).map(
                (r) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(r.severity.icon, color: r.severity.color, size: 18),
                  title: Text(r.timelineTitle),
                  subtitle: Text(
                    DateFormat('MMM d · HH:mm').format(r.createdAt.toLocal()),
                  ),
                ),
              ),
      ],
    );
  }
}
