import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/admin/presentation/widgets/admin_analytics_header.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hdhomesproject/features/biadw/domain/entities/biadw_models.dart';
import 'package:hdhomesproject/features/biadw/presentation/providers/biadw_controller.dart';
import 'package:intl/intl.dart';

/// Live, permission-scoped operational overview for administrators.
class BiCommandCenterPage extends ConsumerWidget {
  const BiCommandCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(biadwControllerProvider);
    final snapshot = ref.watch(biadwSnapshotProvider);
    final connected = ref.watch(biadwRealtimeConnectedProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: snapshot.when(
        loading: () => _LoadingState(connected: connected),
        error: (error, _) => _ErrorState(
          error: error,
          connected: connected,
          onRetry: () => ref.invalidate(biadwSnapshotProvider),
        ),
        data: (data) {
          if (data.isEmpty) {
            return _EmptyState(
              connected: connected,
              onRefresh: () => ref.invalidate(biadwSnapshotProvider),
            );
          }
          return _Overview(
            snapshot: data,
            connected: connected,
            onRefresh: () => ref.invalidate(biadwSnapshotProvider),
          );
        },
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({
    required this.snapshot,
    required this.connected,
    required this.onRefresh,
  });

  final BiadwCommandCenterSnapshot snapshot;
  final bool connected;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _PageFrame(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.base,
                  AppSpacing.base,
                  AppSpacing.base,
                  0,
                ),
                child: _Header(
                  connected: connected,
                  periodDays: snapshot.periodDays,
                  onRefresh: onRefresh,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _PageFrame(child: _KpiGrid(kpis: snapshot.kpis)),
          ),
          SliverToBoxAdapter(
            child: _PageFrame(
              child: _ResponsivePanels(
                dailySeries: snapshot.dailySeries,
                leadStatuses: snapshot.leadStatuses,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _PageFrame(child: _ModuleGrid(modules: snapshot.modules)),
          ),
          SliverToBoxAdapter(
            child: _PageFrame(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.base,
                  0,
                  AppSpacing.base,
                  AppSpacing.xxl,
                ),
                child: _ActivityPanel(items: snapshot.recentActivity),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1440),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.connected,
    required this.periodDays,
    required this.onRefresh,
  });

  final bool connected;
  final int? periodDays;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return AdminAnalyticsHeader(
      section: AdminAnalyticsSection.overview,
      title: 'Admin Analytics',
      subtitle: periodDays == null
          ? "We're gathering operational insights."
          : 'Operational insights for the last $periodDays days.',
      onRefresh: onRefresh,
      status: Text(
        connected
            ? 'Your latest records are here.'
            : "We're gathering the latest records.",
        style: const TextStyle(
          color: Color(0xFF9AA1AB),
          fontSize: 12,
          height: 1.35,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.kpis});

  final List<BiadwKpi> kpis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        0,
        AppSpacing.base,
        AppSpacing.base,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1180
              ? 4
              : constraints.maxWidth >= 680
              ? 2
              : 1;
          final width =
              (constraints.maxWidth - (columns - 1) * AppSpacing.md) / columns;
          return Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: kpis
                .map(
                  (kpi) => SizedBox(
                    width: width,
                    child: _MetricCard(kpi: kpi),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.kpi});

  final BiadwKpi kpi;

  @override
  Widget build(BuildContext context) {
    final caption = switch (kpi.key) {
      'revenue_mtd' when kpi.value == 0 => 'No collections this month',
      'revenue_mtd' => 'Paid this month',
      'project_progress' => 'Average across projects',
      _ => 'Current total',
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF141820),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_kpiIcon(kpi.key), color: AppColors.gold, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kpi.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF9AA1AB),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    kpi.displayValue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      fontFamily: kpi.unit == 'currency' ? 'Roboto' : null,
                      fontFamilyFallback: kpi.unit == 'currency'
                          ? const ['Segoe UI', 'Arial', 'sans-serif']
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF6E7682), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponsivePanels extends StatelessWidget {
  const _ResponsivePanels({
    required this.dailySeries,
    required this.leadStatuses,
  });

  final List<BiadwDailyPoint> dailySeries;
  final List<BiadwLeadStatus> leadStatuses;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        0,
        AppSpacing.base,
        AppSpacing.base,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trend = _Panel(
            title: 'Operational trend',
            subtitle: 'Leads and applications by day',
            child: _TrendChart(points: dailySeries),
          );
          final statuses = _Panel(
            title: 'Lead pipeline',
            subtitle: 'Current CRM status distribution',
            child: _StatusBars(items: leadStatuses),
          );
          if (constraints.maxWidth < 900) {
            return Column(
              children: [
                trend,
                const SizedBox(height: AppSpacing.md),
                statuses,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: trend),
              const SizedBox(width: AppSpacing.md),
              Expanded(flex: 2, child: statuses),
            ],
          );
        },
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF141820),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x18FFFFFF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF9AA1AB), fontSize: 12),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points});

  final List<BiadwDailyPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox(
        height: 190,
        child: Center(child: Text('No trend data for this period')),
      );
    }
    return Column(
      children: [
        const Row(
          children: [
            _LegendDot(color: Color(0xFFF5E6B8), label: 'Leads'),
            SizedBox(width: 14),
            _LegendDot(color: AppColors.gold, label: 'Applications'),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 190,
          width: double.infinity,
          child: CustomPaint(
            painter: _TrendPainter(points: points),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('MMM d').format(points.first.date),
              style: const TextStyle(color: Color(0xFF9AA1AB), fontSize: 11),
            ),
            Text(
              DateFormat('MMM d').format(points.last.date),
              style: const TextStyle(color: Color(0xFF9AA1AB), fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Color(0xFFC8CDD4), fontSize: 12),
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({required this.points});

  final List<BiadwDailyPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = AppColors.neutral400.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    for (var row = 0; row <= 3; row++) {
      final y = size.height * row / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final peak = points.fold<int>(
      1,
      (value, point) =>
          math.max(value, math.max(point.leads, point.applications)),
    );
    Path pathFor(int Function(BiadwDailyPoint) valueOf) {
      final path = Path();
      for (var index = 0; index < points.length; index++) {
        final x = points.length == 1
            ? size.width / 2
            : size.width * index / (points.length - 1);
        final y =
            size.height -
            (valueOf(points[index]) / peak) * (size.height - AppSpacing.sm);
        index == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      return path;
    }

    final leads = pathFor((point) => point.leads);
    final fill = Path.from(leads)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x55F5E6B8), Color(0x00F5E6B8)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      leads,
      Paint()
        ..color = const Color(0xFFF5E6B8)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      pathFor((point) => point.applications),
      Paint()
        ..color = AppColors.gold
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.points != points;
}

class _StatusBars extends StatelessWidget {
  const _StatusBars({required this.items});

  final List<BiadwLeadStatus> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox(
        height: 190,
        child: Center(child: Text('No lead status data')),
      );
    }
    final maximum = items.fold<int>(
      1,
      (value, item) => math.max(value, item.value),
    );
    return Column(
      children: items.take(7).map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${item.value}',
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              LinearProgressIndicator(
                value: item.value / maximum,
                minHeight: 7,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                color: AppColors.gold,
                backgroundColor: const Color(0x22FFFFFF),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ModuleGrid extends StatelessWidget {
  const _ModuleGrid({required this.modules});

  final List<BiadwModuleMetric> modules;

  @override
  Widget build(BuildContext context) {
    if (modules.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        0,
        AppSpacing.base,
        AppSpacing.base,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Business modules',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1100
                  ? 3
                  : constraints.maxWidth >= 600
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * AppSpacing.md) /
                  columns;
              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: modules
                    .map(
                      (module) => SizedBox(
                        width: width,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFF141820),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0x18FFFFFF)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            leading: Icon(
                              _moduleIcon(module.key),
                              color: AppColors.gold,
                              size: 18,
                            ),
                            title: Text(
                              module.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              module.detail,
                              style: const TextStyle(
                                color: Color(0xFF9AA1AB),
                                fontSize: 12,
                              ),
                            ),
                            trailing: Text(
                              BiadwKpi(
                                key: module.key,
                                label: module.label,
                                value: module.value,
                                unit: 'count',
                              ).displayValue,
                              style: const TextStyle(
                                color: AppColors.gold,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel({required this.items});

  final List<BiadwActivity> items;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Recent operational activity',
      subtitle: 'Latest events across live source systems',
      child: items.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(child: Text('No recent activity')),
            )
          : Column(
              children: items.map((activity) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.gold.withValues(alpha: 0.14),
                    child: Icon(
                      _activityIcon(activity.type),
                      color: AppColors.gold,
                      size: 16,
                    ),
                  ),
                  title: Text(
                    activity.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '${_activityType(activity.type)} · '
                    '${DateFormat('MMM d, HH:mm').format(activity.occurredAt.toLocal())}',
                    style: const TextStyle(color: Color(0xFF9AA1AB), fontSize: 12),
                  ),
                );
              }).toList(),
            ),
    );
  }
}

String _activityType(String value) {
  if (value.isEmpty) return 'Activity';
  return '${value[0].toUpperCase()}${value.substring(1)}';
}

IconData _kpiIcon(String key) {
  return switch (key) {
    'crm_leads' => LucideIcons.barChart3,
    'qualified_leads' => LucideIcons.badgeCheck,
    'clients' => LucideIcons.users,
    'revenue_mtd' => LucideIcons.wallet,
    'applications' => LucideIcons.fileText,
    'inspections' => LucideIcons.clipboardCheck,
    'project_progress' => LucideIcons.hardHat,
    'open_tickets' => LucideIcons.ticket,
    _ => LucideIcons.activity,
  };
}

IconData _moduleIcon(String key) {
  return switch (key) {
    'sales' => LucideIcons.badgePercent,
    'finance' => LucideIcons.landmark,
    'construction' => LucideIcons.hardHat,
    'support' => LucideIcons.headphones,
    'properties' => LucideIcons.building2,
    'investors' => LucideIcons.trendingUp,
    _ => LucideIcons.layers,
  };
}

IconData _activityIcon(String type) {
  return switch (type) {
    'lead' => LucideIcons.userPlus,
    'payment' => LucideIcons.wallet,
    'application' => LucideIcons.fileText,
    'inspection' => LucideIcons.calendarCheck,
    _ => LucideIcons.zap,
  };
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.base),
      children: [
        _Header(
          connected: connected,
          periodDays: null,
          onRefresh: null,
        ),
        const SizedBox(height: AppSpacing.xxxl),
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: AppSpacing.base),
        const Center(child: Text('Loading operational analytics…')),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.error,
    required this.connected,
    required this.onRetry,
  });

  final Object error;
  final bool connected;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.base),
      children: [
        _Header(
          connected: connected,
          periodDays: null,
          onRefresh: onRetry,
        ),
        const SizedBox(height: AppSpacing.xxl),
        Icon(
          Icons.cloud_off_outlined,
          size: 48,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Operational analytics unavailable',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          error.toString(),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.connected,
    required this.onRefresh,
  });

  final bool connected;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.base),
      children: [
        _Header(
          connected: connected,
          periodDays: 30,
          onRefresh: onRefresh,
        ),
        const SizedBox(height: AppSpacing.xxl),
        const Icon(Icons.inbox_outlined, size: 52),
        const SizedBox(height: AppSpacing.md),
        Text(
          'No operational data yet',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'The live analytics query completed successfully but returned no '
          'metrics, trends, module totals, or activity.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ),
      ],
    );
  }
}
