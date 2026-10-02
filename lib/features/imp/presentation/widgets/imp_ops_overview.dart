import 'package:flutter/material.dart';
import 'package:hdhomesproject/features/admin/presentation/widgets/admin_desk_shell.dart';
import 'package:hdhomesproject/features/imp/domain/entities/imp_models.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Compact jump chips from Overview into focused desks.
class ImpOpsQueueShortcuts extends StatelessWidget {
  const ImpOpsQueueShortcuts({
    super.key,
    required this.queues,
    required this.onOpenPayments,
    required this.onOpenKyc,
    required this.onOpenInvestments,
    required this.onOpenAlerts,
    this.onOpenSupport,
  });

  final ImpWorkQueues? queues;
  final VoidCallback onOpenPayments;
  final VoidCallback onOpenKyc;
  final VoidCallback onOpenInvestments;
  final VoidCallback onOpenAlerts;
  final VoidCallback? onOpenSupport;

  @override
  Widget build(BuildContext context) {
    final payments = queues?.payments.length ?? 0;
    final kyc = queues?.kyc.length ?? 0;
    final tasks = queues?.tasks.length ?? 0;
    final unassigned = queues?.unassigned.length ?? 0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _ShortcutChip(
            label: 'Payments',
            count: payments,
            icon: LucideIcons.wallet,
            onTap: onOpenPayments,
            warn: payments > 0,
          ),
          const SizedBox(width: 8),
          _ShortcutChip(
            label: 'KYC',
            count: kyc,
            icon: LucideIcons.shieldCheck,
            onTap: onOpenKyc,
            warn: kyc > 0,
          ),
          const SizedBox(width: 8),
          _ShortcutChip(
            label: 'Investments',
            count: tasks + unassigned,
            icon: LucideIcons.briefcase,
            onTap: onOpenInvestments,
          ),
          const SizedBox(width: 8),
          _ShortcutChip(
            label: 'Alerts',
            count: null,
            icon: LucideIcons.bell,
            onTap: onOpenAlerts,
          ),
          if (onOpenSupport != null) ...[
            const SizedBox(width: 8),
            _ShortcutChip(
              label: 'Support',
              count: null,
              icon: LucideIcons.headphones,
              onTap: onOpenSupport!,
            ),
          ],
        ],
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.count,
    this.warn = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final int? count;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final accent = warn ? AdminDeskColors.amber : AdminDeskColors.gold;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AdminDeskColors.elevated,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: accent),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Overview ops surface: portfolio mix (real holdings) + alerts + activity.
/// Work queues remain the primary work surface above/beside these panels.
class ImpOpsOverviewExtras extends StatelessWidget {
  const ImpOpsOverviewExtras({
    super.key,
    required this.holdings,
    required this.alerts,
    required this.activities,
    this.onAlertStatusChanged,
  });

  final List<ImpHolding> holdings;
  final List<ImpAlert> alerts;
  final List<ImpActivity> activities;
  final void Function(ImpAlert alert, String status)? onAlertStatusChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 960;
        final portfolio = _PortfolioMixCard(holdings: holdings);
        final alertsCard = _OpsPanel(
          title: 'Open alerts',
          icon: LucideIcons.bell,
          child: _OverviewAlertList(
            alerts: alerts,
            onStatusChanged: onAlertStatusChanged,
          ),
        );
        final activityCard = _OpsPanel(
          title: 'Recent activity',
          icon: LucideIcons.gitBranch,
          child: _OverviewActivityList(activities: activities),
        );

        if (!wide) {
          return Column(
            children: [
              portfolio,
              const SizedBox(height: 12),
              alertsCard,
              const SizedBox(height: 12),
              activityCard,
            ],
          );
        }

        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: portfolio),
                const SizedBox(width: 12),
                Expanded(child: alertsCard),
              ],
            ),
            const SizedBox(height: 12),
            activityCard,
          ],
        );
      },
    );
  }
}

class _PortfolioMixCard extends StatelessWidget {
  const _PortfolioMixCard({required this.holdings});
  final List<ImpHolding> holdings;

  @override
  Widget build(BuildContext context) {
    final total = holdings.fold<double>(0, (s, h) => s + h.currentValue);
    final slices = <({String label, double value, Color color})>[];
    if (total > 0) {
      final colors = [
        AdminDeskColors.gold,
        AdminDeskColors.green,
        const Color(0xFF60A5FA),
        AdminDeskColors.amber,
        const Color(0xFFA78BFA),
      ];
      final byLabel = <String, double>{};
      for (final h in holdings) {
        final key = h.label.trim().isEmpty ? 'Holding' : h.label.trim();
        byLabel[key] = (byLabel[key] ?? 0) + h.currentValue;
      }
      var i = 0;
      final ranked = byLabel.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final e in ranked.take(5)) {
        slices.add((
          label: e.key,
          value: e.value,
          color: colors[i % colors.length],
        ));
        i++;
      }
    }

    return _OpsPanel(
      title: 'Portfolio mix',
      icon: LucideIcons.pieChart,
      child: total <= 0
          ? const _OpsEmpty(
              message:
                  'No holding values yet. Mix appears when portfolio holdings have current value.',
            )
          : Column(
              children: [
                for (final slice in slices)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: slice.color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            slice.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${((slice.value / total) * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: AdminDeskColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          formatImpMoney(slice.value),
                          style: TextStyle(
                            color: slice.color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Book value ${formatImpMoney(total)} across ${holdings.length} holdings',
                    style: const TextStyle(
                      color: AdminDeskColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _OpsPanel extends StatelessWidget {
  const _OpsPanel({
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
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminDeskColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminDeskColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AdminDeskColors.gold),
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

class _OpsEmpty extends StatelessWidget {
  const _OpsEmpty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: const TextStyle(color: AdminDeskColors.muted, height: 1.4),
    );
  }
}

class _OverviewAlertList extends StatelessWidget {
  const _OverviewAlertList({required this.alerts, this.onStatusChanged});

  final List<ImpAlert> alerts;
  final void Function(ImpAlert alert, String status)? onStatusChanged;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return const _OpsEmpty(message: 'No open investor alerts.');
    }
    final items = alerts.take(6).toList();
    return Column(
      children: [
        for (final a in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(
              LucideIcons.bell,
              size: 16,
              color:
                  a.severity == AlertSeverity.critical ||
                      a.severity == AlertSeverity.high
                  ? AdminDeskColors.red
                  : AdminDeskColors.gold,
            ),
            title: Text(
              a.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            subtitle: Text(
              a.severity.label,
              style: const TextStyle(
                color: AdminDeskColors.muted,
                fontSize: 11,
              ),
            ),
            trailing: onStatusChanged == null
                ? null
                : PopupMenuButton<String>(
                    onSelected: (status) => onStatusChanged!(a, status),
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'acknowledged',
                        child: Text('Acknowledge'),
                      ),
                      PopupMenuItem(value: 'resolved', child: Text('Resolve')),
                      PopupMenuItem(value: 'dismissed', child: Text('Dismiss')),
                    ],
                  ),
          ),
      ],
    );
  }
}

class _OverviewActivityList extends StatelessWidget {
  const _OverviewActivityList({required this.activities});
  final List<ImpActivity> activities;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return const _OpsEmpty(message: 'No recent investor activity.');
    }
    return Column(
      children: [
        for (final a in activities.take(8))
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const Icon(
              LucideIcons.activity,
              size: 16,
              color: AdminDeskColors.muted,
            ),
            title: Text(
              a.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            subtitle: Text(
              a.description ?? a.eventType,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AdminDeskColors.muted,
                fontSize: 11,
              ),
            ),
          ),
      ],
    );
  }
}
