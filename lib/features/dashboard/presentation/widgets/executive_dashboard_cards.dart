import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/config/ai_features.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/offline_updates_note.dart';
import 'package:hdhomesproject/features/dashboard/domain/entities/executive_dashboard_models.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ExecutiveDashHeader extends StatelessWidget {
  const ExecutiveDashHeader({
    super.key,
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
    this.dashboardTitle = 'Mission Control',
    this.showPresentationControls = true,
    this.showAiShortcut = true,
  });

  final String greeting;
  final String role;
  final String dashboardTitle;
  final String dateLabel;
  final String timeLabel;
  final String ticker;
  final bool presentationMode;
  final bool autoRefresh;
  final bool fromRemote;
  final bool showPresentationControls;
  final bool showAiShortcut;
  final VoidCallback onTogglePresentation;
  final VoidCallback onToggleAutoRefresh;
  final VoidCallback onSearch;
  final VoidCallback onAi;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
        decoration: BoxDecoration(
          borderRadius: AppRadius.cardBorder,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1C1F27), Color(0xFF12141A)],
          ),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                      const SizedBox(height: 4),
                      Text(
                        role,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Today is $dateLabel · $timeLabel',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondaryDark,
                            ),
                      ),
                    ],
                  ),
                ),
                if (!fromRemote)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: OfflineUpdatesNote(color: Color(0xFFB9C7DA)),
                  ),
                IconButton(
                  tooltip: 'Global search',
                  onPressed: onSearch,
                  icon: const Icon(LucideIcons.search, color: AppColors.white),
                ),
                if (kAiFeaturesEnabled && showAiShortcut)
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
                    color: autoRefresh ? AppColors.gold : AppColors.white,
                  ),
                ),
                if (showPresentationControls)
                  IconButton(
                    tooltip: presentationMode
                        ? 'Exit presentation mode'
                        : '$dashboardTitle presentation',
                    onPressed: onTogglePresentation,
                    icon: Icon(
                      presentationMode ? LucideIcons.minimize : LucideIcons.maximize,
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
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.activity, size: 16, color: AppColors.gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ticker,
                      style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!fromRemote)
                    const OfflineUpdatesNote(color: Color(0xFFB9C7DA)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExecutiveDashBriefing extends StatelessWidget {
  const ExecutiveDashBriefing({
    super.key,
    required this.text,
    required this.live,
  });

  final String text;
  // ignore: unused_field
  final bool live;

  @override
  Widget build(BuildContext context) {
    return ExecutiveDashCard(
      title: 'Executive summary',
      icon: LucideIcons.sparkles,
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondaryDark,
              height: 1.45,
            ),
      ),
    );
  }
}

class ExecutiveDashCard extends StatelessWidget {
  const ExecutiveDashCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.action,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: AppRadius.cardBorder,
          border: Border.all(color: AppColors.white.withValues(alpha: 0.06)),
        ),
        child: ClipRRect(
          borderRadius: AppRadius.cardBorder,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 3, color: AppColors.gold.withValues(alpha: 0.85)),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 18, color: AppColors.gold),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        if (action != null) action!,
                      ],
                    ),
                    const SizedBox(height: 14),
                    child,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExecutiveDashHealth extends StatelessWidget {
  const ExecutiveDashHealth({super.key, required this.health});

  final BusinessHealthScore health;

  @override
  Widget build(BuildContext context) {
    final color = switch (health.status) {
      BusinessHealthStatus.excellent => const Color(0xFF4ADE80),
      BusinessHealthStatus.good => AppColors.gold,
      BusinessHealthStatus.needsAttention => Colors.orange,
      BusinessHealthStatus.critical => Colors.redAccent,
    };
    return ExecutiveDashCard(
      title: 'Business Health Score',
      icon: LucideIcons.heartPulse,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          final score = Column(
            children: [
              SizedBox(
                width: 112,
                height: 112,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: health.overallScore / 100,
                        strokeWidth: 9,
                        color: color,
                        backgroundColor: AppColors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${health.overallScore}',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        Text(
                          health.status.label,
                          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
          final bars = Column(
            children: health.factors
                .map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(f.label, style: const TextStyle(fontSize: 13))),
                            Text(
                              '${f.score}',
                              style: const TextStyle(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: LinearProgressIndicator(
                            value: f.score / 100,
                            minHeight: 7,
                            color: AppColors.gold,
                            backgroundColor: AppColors.white.withValues(alpha: 0.08),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          );
          if (!wide) {
            return Column(children: [score, const SizedBox(height: 20), bars]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              score,
              const SizedBox(width: 28),
              Expanded(child: bars),
            ],
          );
        },
      ),
    );
  }
}

class ExecutiveDashKpis extends StatelessWidget {
  const ExecutiveDashKpis({super.key, required this.kpis});

  final List<KpiCard> kpis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.gauge, size: 18, color: AppColors.gold),
              const SizedBox(width: 8),
              Text(
                'KPI Overview',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final cols = w >= 1180
                  ? 4
                  : w >= 780
                      ? 3
                      : 2;
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
          ),
        ],
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.kpi});

  final KpiCard kpi;

  @override
  Widget build(BuildContext context) {
    final hasChange = kpi.changePct != null && kpi.changePct != 0;
    final up = kpi.isUp;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kpi.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            kpi.displayValue,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.white,
                ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (hasChange) ...[
                Icon(
                  up ? LucideIcons.trendingUp : LucideIcons.trendingDown,
                  size: 14,
                  color: up ? const Color(0xFF4ADE80) : Colors.redAccent,
                ),
                const SizedBox(width: 4),
                Text(
                  '${kpi.changePct!.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: up ? const Color(0xFF4ADE80) : Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else
                const Text(
                  'Current total',
                  style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              const Spacer(),
              SizedBox(
                width: 56,
                height: 22,
                child: CustomPaint(
                  painter: _SparklinePainter(
                    kpi.series,
                    color: hasChange && !up ? Colors.redAccent : AppColors.gold,
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
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

class ExecutiveDashTwoCol extends StatelessWidget {
  const ExecutiveDashTwoCol({super.key, this.left, this.right});

  final Widget? left;
  final Widget? right;

  @override
  Widget build(BuildContext context) {
    if (left == null && right == null) return const SizedBox.shrink();
    final wide = MediaQuery.sizeOf(context).width >= 960;
    if (!wide) {
      return Column(
        children: [if (left != null) left!, if (right != null) right!],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left ?? const SizedBox.shrink()),
        Expanded(child: right ?? const SizedBox.shrink()),
      ],
    );
  }
}

class ExecutiveDashMetrics extends StatelessWidget {
  const ExecutiveDashMetrics({
    super.key,
    required this.block,
    required this.icon,
  });

  final ModuleAnalyticsBlock block;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final entries = block.metrics.entries.toList();
    return ExecutiveDashCard(
      title: block.title,
      icon: icon,
      child: entries.isEmpty
          ? const _EmptyNote('No live rows yet for this module.')
          : LayoutBuilder(
              builder: (context, constraints) {
                final cols = constraints.maxWidth >= 420 ? 2 : 1;
                final gap = 10.0;
                final itemW = cols == 1
                    ? constraints.maxWidth
                    : (constraints.maxWidth - gap) / 2;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: entries
                      .map(
                        (e) => SizedBox(
                          width: itemW,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.darkElevated,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.key,
                                  style: const TextStyle(
                                    color: AppColors.textSecondaryDark,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  e.value,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
    );
  }
}

class ExecutiveDashInsights extends StatelessWidget {
  const ExecutiveDashInsights({super.key, required this.insights});

  final List<AiExecutiveInsight> insights;

  @override
  Widget build(BuildContext context) {
    return ExecutiveDashCard(
      title: 'Insights',
      icon: LucideIcons.brain,
      child: insights.isEmpty
          ? const _EmptyNote('Insights appear as the catalog and ops tables fill.')
          : Column(
              children: [
                for (var i = 0; i < insights.length; i++) ...[
                  if (i > 0) const Divider(height: 20),
                  _InsightRow(item: insights[i]),
                ],
              ],
            ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.item});

  final AiExecutiveInsight item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          item.severity == NotificationSeverity.critical
              ? LucideIcons.alertTriangle
              : LucideIcons.sparkles,
          color: AppColors.gold,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                item.body,
                style: const TextStyle(color: AppColors.textSecondaryDark, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ExecutiveDashRisks extends StatelessWidget {
  const ExecutiveDashRisks({super.key, required this.risks});

  final List<OperationalRisk> risks;

  @override
  Widget build(BuildContext context) {
    return ExecutiveDashCard(
      title: 'Operational Risk Monitor',
      icon: LucideIcons.shieldAlert,
      child: risks.isEmpty
          ? const _EmptyNote('No live risks. Queues and delays will appear here.')
          : Column(
              children: risks
                  .map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.darkElevated,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              LucideIcons.alertTriangle,
                              size: 18,
                              color: switch (r.severity) {
                                NotificationSeverity.critical => Colors.redAccent,
                                NotificationSeverity.warning => Colors.orange,
                                _ => AppColors.gold,
                              },
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Owner: ${r.owner}',
                                    style: const TextStyle(
                                      color: AppColors.textSecondaryDark,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    'Next: ${r.nextAction}',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class ExecutiveDashActivity extends StatelessWidget {
  const ExecutiveDashActivity({super.key, required this.items});

  final List<ActivityFeedItem> items;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('HH:mm');
    return ExecutiveDashCard(
      title: 'Activity',
      icon: LucideIcons.list,
      child: items.isEmpty
          ? const _EmptyNote('Activity from listings, inspections, payments, and the website will land here.')
          : Column(
              children: [
                for (var i = 0; i < items.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: AppColors.gold,
                                shape: BoxShape.circle,
                              ),
                            ),
                            if (i < items.length - 1)
                              Container(
                                width: 1,
                                height: 36,
                                color: AppColors.gold.withValues(alpha: 0.25),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(items[i].summary, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(
                                '${items[i].actorName ?? 'System'} · ${items[i].module}'
                                '${items[i].createdAt != null ? ' · ${fmt.format(items[i].createdAt!)}' : ''}',
                                style: const TextStyle(
                                  color: AppColors.textSecondaryDark,
                                  fontSize: 12,
                                ),
                              ),
                            ],
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

class ExecutiveDashNotifications extends StatelessWidget {
  const ExecutiveDashNotifications({
    super.key,
    required this.items,
    required this.onRead,
  });

  final List<ExecutiveNotificationItem> items;
  final Future<void> Function(String id) onRead;

  @override
  Widget build(BuildContext context) {
    return ExecutiveDashCard(
      title: 'Executive Notification Center',
      icon: LucideIcons.bell,
      child: items.isEmpty
          ? const _EmptyNote('Alerts from publish queues, KYC, and support appear here.')
          : Column(
              children: items
                  .map(
                    (n) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.darkElevated,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              n.isPinned ? LucideIcons.pin : LucideIcons.bellRing,
                              color: AppColors.gold,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(n.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  if (n.body != null)
                                    Text(
                                      n.body!,
                                      style: const TextStyle(
                                        color: AppColors.textSecondaryDark,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (!n.isRead && n.id.startsWith('n-') == false)
                              TextButton(
                                onPressed: () => onRead(n.id),
                                child: const Text('Read'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class ExecutiveDashSchedule extends StatelessWidget {
  const ExecutiveDashSchedule({super.key, required this.items});

  final List<ScheduleItem> items;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEE d MMM · HH:mm');
    return ExecutiveDashCard(
      title: 'Upcoming Schedule',
      icon: LucideIcons.calendar,
      child: items.isEmpty
          ? const _EmptyNote('Booked inspections and project dates will show here in realtime.')
          : Column(
              children: items
                  .map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.gold,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text(
                                  '${s.category} · ${fmt.format(s.when)}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondaryDark,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
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

class ExecutiveDashForecasts extends StatelessWidget {
  const ExecutiveDashForecasts({super.key, required this.forecasts});

  final List<PredictiveForecast> forecasts;

  @override
  Widget build(BuildContext context) {
    return ExecutiveDashCard(
      title: 'Predictive Business Intelligence',
      icon: LucideIcons.orbit,
      child: Column(
        children: forecasts
            .map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.darkElevated,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(f.prediction),
                      const SizedBox(height: 4),
                      Text(
                        f.disclaimer,
                        style: const TextStyle(
                          color: AppColors.textSecondaryDark,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class ExecutiveDashQuickActions extends StatelessWidget {
  const ExecutiveDashQuickActions({
    super.key,
    required this.actions,
    required this.onTap,
  });

  final List<QuickActionItem> actions;
  final void Function(String path) onTap;

  @override
  Widget build(BuildContext context) {
    return ExecutiveDashCard(
      title: 'Quick Actions',
      icon: LucideIcons.zap,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: actions
            .map(
              (a) => ActionChip(
                avatar: const Icon(LucideIcons.arrowUpRight, size: 14, color: AppColors.gold),
                label: Text(a.label),
                side: BorderSide(color: AppColors.gold.withValues(alpha: 0.45)),
                onPressed: () => onTap(a.routeOrKey),
              ),
            )
            .toList(),
      ),
    );
  }
}

class ExecutiveDashReports extends StatelessWidget {
  const ExecutiveDashReports({
    super.key,
    required this.types,
    required this.onGenerate,
    this.onBriefing,
  });

  final List<ExecutiveReportType> types;
  final void Function(String id) onGenerate;
  final VoidCallback? onBriefing;

  @override
  Widget build(BuildContext context) {
    return ExecutiveDashCard(
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
              if (onBriefing != null)
                FilledButton.icon(
                  onPressed: onBriefing,
                  icon: const Icon(LucideIcons.scrollText, size: 16),
                  label: const Text('Executive Briefing Generator™'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Briefings pull from live listings, CRM, finance, and website inboxes.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
          ),
        ],
      ),
    );
  }
}

class ExecutiveDashStrategy extends StatelessWidget {
  const ExecutiveDashStrategy({super.key, required this.initiatives});

  final List<StrategyInitiative> initiatives;

  @override
  Widget build(BuildContext context) {
    return ExecutiveDashCard(
      title: 'Executive Strategy Workspace',
      icon: LucideIcons.target,
      child: Column(
        children: initiatives
            .map(
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(i.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        Text(
                          i.status,
                          style: TextStyle(
                            color: i.status == 'At risk' ? Colors.orange : AppColors.gold,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: LinearProgressIndicator(
                        value: i.progressPct / 100,
                        minHeight: 8,
                        color: AppColors.gold,
                        backgroundColor: AppColors.white.withValues(alpha: 0.08),
                      ),
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

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.textSecondaryDark, height: 1.4),
      ),
    );
  }
}
