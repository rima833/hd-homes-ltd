import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/layout/portal_shell.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/dashboard/domain/entities/executive_dashboard_models.dart';
import 'package:hdhomesproject/features/dashboard/presentation/providers/executive_dashboard_controller.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Volume 4 Part 1 — Executive Mission Control™ dashboard.
class ExecutiveDashboardPage extends ConsumerWidget {
  const ExecutiveDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSnap = ref.watch(executiveDashboardSnapshotProvider);
    final ui = ref.watch(executiveDashboardControllerProvider);
    final controller = ref.read(executiveDashboardControllerProvider.notifier);
    final session = ref.watch(identitySessionProvider);
    final permissions = session.permissions;
    final profile = session.profile;
    final name = [
      profile?.firstName,
      profile?.lastName,
    ].whereType<String>().where((e) => e.trim().isNotEmpty).join(' ');
    final displayName = name.isEmpty ? (session.email ?? 'Executive') : name;
    final role = session.primaryRole?.name ?? 'Administrator';

    return Scaffold(
      backgroundColor: ui.presentationMode ? AppColors.deepBlack : null,
      body: asyncSnap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load Mission Control: $e')),
        data: (snap) {
          final greeting = _greeting(DateTime.now());
          final dateLabel = DateFormat('EEEE, d MMMM y').format(DateTime.now());
          final timeLabel = DateFormat('HH:mm').format(DateTime.now());
          final tickerKpis = snap.kpis;
          final ticker = tickerKpis.isEmpty
              ? 'Mission Control live'
              : '${tickerKpis[ui.tickerIndex % tickerKpis.length].label}: '
                  '${tickerKpis[ui.tickerIndex % tickerKpis.length].displayValue}';

          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _ExecutiveHeader(
                    greeting: '$greeting, $displayName',
                    role: role,
                    dateLabel: dateLabel,
                    timeLabel: timeLabel,
                    ticker: ticker,
                    presentationMode: ui.presentationMode,
                    autoRefresh: ui.autoRefresh,
                    fromRemote: snap.fromRemote,
                    onTogglePresentation: controller.togglePresentationMode,
                    onToggleAutoRefresh: () =>
                        controller.setAutoRefresh(!ui.autoRefresh),
                    onSearch: () => CommandPaletteScope.maybeOf(context)?.open(),
                    onAi: () => context.go(RoutePaths.aiGovernance),
                    onRefresh: controller.refresh,
                  ),
                ),
                if (ui.lastReportMessage != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Material(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        borderRadius: AppRadius.cardBorder,
                        child: ListTile(
                          leading: const Icon(LucideIcons.fileCheck, color: AppColors.gold),
                          title: Text(ui.lastReportMessage!),
                          dense: true,
                        ),
                      ),
                    ),
                  ),
                if (snap.briefingSummary != null)
                  SliverToBoxAdapter(
                    child: _SectionCard(
                      title: 'AI Executive Summary',
                      icon: LucideIcons.sparkles,
                      child: Text(snap.briefingSummary!),
                    ),
                  ),
                if (!_hidden(ui, 'health'))
                  SliverToBoxAdapter(
                    child: _HealthBanner(health: snap.health),
                  ),
                if (!_hidden(ui, 'kpis'))
                  SliverToBoxAdapter(
                    child: _SectionCard(
                      title: 'KPI Overview',
                      icon: LucideIcons.gauge,
                      child: _KpiGrid(kpis: snap.kpis),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: _TwoCol(
                    left: !_hidden(ui, 'sales')
                        ? _MetricsCard(block: snap.sales, icon: LucideIcons.trendingUp)
                        : null,
                    right: !_hidden(ui, 'finance')
                        ? _MetricsCard(block: snap.finance, icon: LucideIcons.wallet)
                        : null,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _TwoCol(
                    left: !_hidden(ui, 'properties')
                        ? _MetricsCard(
                            block: snap.properties, icon: LucideIcons.building2)
                        : null,
                    right: !_hidden(ui, 'investors')
                        ? _MetricsCard(
                            block: snap.investors, icon: LucideIcons.lineChart)
                        : null,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _TwoCol(
                    left: !_hidden(ui, 'crm')
                        ? _MetricsCard(block: snap.crm, icon: LucideIcons.users)
                        : null,
                    right: !_hidden(ui, 'construction')
                        ? _MetricsCard(
                            block: snap.construction,
                            icon: LucideIcons.hardHat,
                          )
                        : null,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _TwoCol(
                    left: !_hidden(ui, 'marketing')
                        ? _MetricsCard(
                            block: snap.marketing, icon: LucideIcons.megaphone)
                        : null,
                    right: !_hidden(ui, 'support')
                        ? _MetricsCard(
                            block: snap.support, icon: LucideIcons.lifeBuoy)
                        : null,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _TwoCol(
                    left: !_hidden(ui, 'insights')
                        ? _InsightsPanel(insights: snap.insights)
                        : null,
                    right: !_hidden(ui, 'risks')
                        ? _RiskPanel(risks: snap.risks)
                        : null,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _TwoCol(
                    left: !_hidden(ui, 'activity')
                        ? _ActivityPanel(items: snap.activity)
                        : null,
                    right: !_hidden(ui, 'notifications')
                        ? _NotificationsPanel(
                            items: snap.notifications,
                            onRead: controller.markRead,
                          )
                        : null,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _TwoCol(
                    left: !_hidden(ui, 'schedule')
                        ? _SchedulePanel(items: snap.schedule)
                        : null,
                    right: !_hidden(ui, 'forecasts')
                        ? _ForecastPanel(forecasts: snap.forecasts)
                        : null,
                  ),
                ),
                if (!_hidden(ui, 'actions'))
                  SliverToBoxAdapter(
                    child: _QuickActionsPanel(
                      actions: snap.quickActions
                          .where((a) => a.allowedFor(permissions))
                          .toList(),
                      onTap: (path) => context.go(path),
                    ),
                  ),
                if (!_hidden(ui, 'reports'))
                  SliverToBoxAdapter(
                    child: _ReportsPanel(
                      types: snap.reportTypes,
                      onGenerate: (id) => controller.generateReport(id),
                      onBriefing: () {
                        final text = controller.briefingText(snap);
                        showDialog<void>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Executive Briefing Generator™'),
                            content: SingleChildScrollView(child: Text(text)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Close'),
                              ),
                              FilledButton(
                                onPressed: () {
                                  controller.generateReport('briefing');
                                  Navigator.pop(ctx);
                                },
                                child: const Text('Queue export'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                if (!_hidden(ui, 'strategy'))
                  SliverToBoxAdapter(
                    child: _StrategyPanel(initiatives: snap.initiatives),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          );
        },
      ),
    );
  }

  static bool _hidden(ExecutiveDashboardUiState ui, String key) =>
      ui.hiddenModules.contains(key);

  static String _greeting(DateTime now) {
    final h = now.hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _ExecutiveHeader extends StatelessWidget {
  const _ExecutiveHeader({
    required this.greeting,
    required this.role,
    required this.dateLabel,
    required this.timeLabel,
    required this.ticker,
    required this.presentationMode,
    required this.autoRefresh,
    required this.fromRemote,
    required this.onTogglePresentation,
    required this.onToggleAutoRefresh,
    required this.onSearch,
    required this.onAi,
    required this.onRefresh,
  });

  final String greeting;
  final String role;
  final String dateLabel;
  final String timeLabel;
  final String ticker;
  final bool presentationMode;
  final bool autoRefresh;
  final bool fromRemote;
  final VoidCallback onTogglePresentation;
  final VoidCallback onToggleAutoRefresh;
  final VoidCallback onSearch;
  final VoidCallback onAi;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.charcoal,
            AppColors.deepBlack.withValues(alpha: 0.9),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: AppColors.gold.withValues(alpha: 0.25)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      role,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.gold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Today is $dateLabel · $timeLabel',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Global search / Command palette',
                onPressed: onSearch,
                icon: const Icon(LucideIcons.search, color: AppColors.white),
              ),
              IconButton(
                tooltip: 'AI Assistant',
                onPressed: onAi,
                icon: const Icon(LucideIcons.sparkles, color: AppColors.gold),
              ),
              IconButton(
                tooltip: autoRefresh ? 'Auto-refresh on' : 'Auto-refresh off',
                onPressed: onToggleAutoRefresh,
                icon: Icon(
                  autoRefresh ? LucideIcons.refreshCw : LucideIcons.pause,
                  color: AppColors.white,
                ),
              ),
              IconButton(
                tooltip: presentationMode
                    ? 'Exit presentation mode'
                    : 'Mission Control presentation',
                onPressed: onTogglePresentation,
                icon: Icon(
                  presentationMode
                      ? LucideIcons.minimize
                      : LucideIcons.maximize,
                  color: AppColors.white,
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => onRefresh(),
                icon: const Icon(LucideIcons.rotateCcw, color: AppColors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.12),
              borderRadius: AppRadius.cardBorder,
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.activity, size: 16, color: AppColors.gold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ticker,
                    style: const TextStyle(color: AppColors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  fromRemote ? 'LIVE' : 'DEMO',
                  style: TextStyle(
                    color: fromRemote ? Colors.greenAccent : AppColors.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.icon,
  });

  final String title;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.cardBorder,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: AppColors.gold),
                    const SizedBox(width: 8),
                  ],
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthBanner extends StatelessWidget {
  const _HealthBanner({required this.health});

  final BusinessHealthScore health;

  @override
  Widget build(BuildContext context) {
    final color = switch (health.status) {
      BusinessHealthStatus.excellent => Colors.green,
      BusinessHealthStatus.good => AppColors.gold,
      BusinessHealthStatus.needsAttention => Colors.orange,
      BusinessHealthStatus.critical => Colors.redAccent,
    };
    return _SectionCard(
      title: 'Business Health Score',
      icon: LucideIcons.heartPulse,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${health.overallScore}',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(width: 12),
              Chip(
                label: Text(health.status.label),
                backgroundColor: color.withValues(alpha: 0.2),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: health.factors
                .map(
                  (f) => Chip(
                    avatar: CircleAvatar(
                      backgroundColor: AppColors.gold.withValues(alpha: 0.2),
                      child: Text('${f.score}', style: const TextStyle(fontSize: 10)),
                    ),
                    label: Text(f.label),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.kpis});

  final List<KpiCard> kpis;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = w >= 1100 ? 4 : w >= 700 ? 3 : 2;
        final gap = 12.0;
        final itemW = (w - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: kpis
              .map(
                (k) => SizedBox(
                  width: itemW,
                  child: _KpiTile(kpi: k),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.kpi});

  final KpiCard kpi;

  @override
  Widget build(BuildContext context) {
    final up = kpi.isUp;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.gray.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kpi.label,
            style: Theme.of(context).textTheme.labelMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            kpi.displayValue,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                up ? LucideIcons.trendingUp : LucideIcons.trendingDown,
                size: 14,
                color: up ? Colors.greenAccent : Colors.redAccent,
              ),
              const SizedBox(width: 4),
              Text(
                '${kpi.changePct?.toStringAsFixed(1) ?? '0'}%',
                style: TextStyle(
                  color: up ? Colors.greenAccent : Colors.redAccent,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 48,
                height: 20,
                child: CustomPaint(
                  painter: _SparklinePainter(
                    kpi.series,
                    color: up ? Colors.greenAccent : Colors.redAccent,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.values, {required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 0.001 ? 1.0 : maxV - minV;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - ((values[i] - minV) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

class _TwoCol extends StatelessWidget {
  const _TwoCol({this.left, this.right});

  final Widget? left;
  final Widget? right;

  @override
  Widget build(BuildContext context) {
    if (left == null && right == null) return const SizedBox.shrink();
    final wide = MediaQuery.sizeOf(context).width >= 900;
    if (!wide) {
      return Column(
        children: [
          if (left != null) left!,
          if (right != null) right!,
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left ?? const SizedBox.shrink()),
          Expanded(child: right ?? const SizedBox.shrink()),
        ],
      ),
    );
  }
}

class _MetricsCard extends StatelessWidget {
  const _MetricsCard({required this.block, required this.icon});

  final ModuleAnalyticsBlock block;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: block.title,
      icon: icon,
      child: Column(
        children: block.metrics.entries
            .map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(e.key)),
                    Text(
                      e.value,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _InsightsPanel extends StatelessWidget {
  const _InsightsPanel({required this.insights});

  final List<AiExecutiveInsight> insights;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'AI Executive Insights',
      icon: LucideIcons.brain,
      child: Column(
        children: insights
            .map(
              (i) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  i.isAiGenerated ? LucideIcons.sparkles : LucideIcons.barChart3,
                  color: AppColors.gold,
                ),
                title: Text(i.title),
                subtitle: Text(
                  '${i.body}\n'
                  '${i.isAiGenerated ? 'AI-generated' : 'Fact'}'
                  '${i.confidence != null ? ' · confidence ${(i.confidence! * 100).toStringAsFixed(0)}%' : ''}',
                ),
                isThreeLine: true,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _RiskPanel extends StatelessWidget {
  const _RiskPanel({required this.risks});

  final List<OperationalRisk> risks;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Operational Risk Monitor',
      icon: LucideIcons.shieldAlert,
      child: Column(
        children: risks
            .map(
              (r) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  LucideIcons.alertTriangle,
                  color: switch (r.severity) {
                    NotificationSeverity.critical => Colors.redAccent,
                    NotificationSeverity.warning => Colors.orange,
                    _ => AppColors.gold,
                  },
                ),
                title: Text(r.title),
                subtitle: Text('Owner: ${r.owner}\nNext: ${r.nextAction}'),
                isThreeLine: true,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel({required this.items});

  final List<ActivityFeedItem> items;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('HH:mm');
    return _SectionCard(
      title: 'Live Activity Feed',
      icon: LucideIcons.radio,
      child: Column(
        children: items
            .map(
              (a) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(LucideIcons.dot, color: AppColors.gold),
                title: Text(a.summary),
                subtitle: Text(
                  '${a.actorName ?? 'System'} · ${a.module}'
                  '${a.createdAt != null ? ' · ${fmt.format(a.createdAt!)}' : ''}',
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _NotificationsPanel extends StatelessWidget {
  const _NotificationsPanel({
    required this.items,
    required this.onRead,
  });

  final List<ExecutiveNotificationItem> items;
  final Future<void> Function(String id) onRead;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Executive Notification Center',
      icon: LucideIcons.bell,
      child: Column(
        children: items
            .map(
              (n) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  n.isPinned ? LucideIcons.pin : LucideIcons.bellRing,
                  color: AppColors.gold,
                ),
                title: Text(n.title),
                subtitle: Text(n.body ?? n.category),
                trailing: n.isRead
                    ? null
                    : TextButton(
                        onPressed: () => onRead(n.id),
                        child: const Text('Read'),
                      ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SchedulePanel extends StatelessWidget {
  const _SchedulePanel({required this.items});

  final List<ScheduleItem> items;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEE d MMM · HH:mm');
    return _SectionCard(
      title: 'Upcoming Schedule',
      icon: LucideIcons.calendar,
      child: Column(
        children: items
            .map(
              (s) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(s.title),
                subtitle: Text('${s.category} · ${fmt.format(s.when)}'),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ForecastPanel extends StatelessWidget {
  const _ForecastPanel({required this.forecasts});

  final List<PredictiveForecast> forecasts;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Predictive Business Intelligence',
      icon: LucideIcons.orbit,
      child: Column(
        children: forecasts
            .map(
              (f) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(f.label),
                subtitle: Text(
                  '${f.prediction}\n${f.disclaimer}',
                ),
                isThreeLine: true,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _QuickActionsPanel extends StatelessWidget {
  const _QuickActionsPanel({
    required this.actions,
    required this.onTap,
  });

  final List<QuickActionItem> actions;
  final void Function(String path) onTap;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Quick Actions',
      icon: LucideIcons.zap,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: actions
            .map(
              (a) => ActionChip(
                avatar: const Icon(LucideIcons.arrowUpRight, size: 14),
                label: Text(a.label),
                onPressed: () => onTap(a.routeOrKey),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ReportsPanel extends StatelessWidget {
  const _ReportsPanel({
    required this.types,
    required this.onGenerate,
    required this.onBriefing,
  });

  final List<ExecutiveReportType> types;
  final void Function(String id) onGenerate;
  final VoidCallback onBriefing;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Executive Reports',
      icon: LucideIcons.fileBarChart,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...types.where((t) => t.id != 'briefing').map(
                    (t) => OutlinedButton(
                      onPressed: () => onGenerate(t.id),
                      child: Text(t.label),
                    ),
                  ),
              FilledButton.icon(
                onPressed: onBriefing,
                icon: const Icon(LucideIcons.scrollText, size: 16),
                label: const Text('Executive Briefing Generator™'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Exports: PDF · Excel · CSV (adapters expand with Finance ops).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _StrategyPanel extends StatelessWidget {
  const _StrategyPanel({required this.initiatives});

  final List<StrategyInitiative> initiatives;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Executive Strategy Workspace',
      icon: LucideIcons.target,
      child: Column(
        children: initiatives
            .map(
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(i.title)),
                        Text(i.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: i.progressPct / 100,
                      color: AppColors.gold,
                      backgroundColor: AppColors.gray.withValues(alpha: 0.2),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
