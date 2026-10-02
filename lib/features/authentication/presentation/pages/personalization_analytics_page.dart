import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/admin/presentation/widgets/admin_analytics_header.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/personalization_models.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/personalization_controller.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Live, anonymous aggregate personalization insights for administrators.
class PersonalizationAnalyticsPage extends ConsumerWidget {
  const PersonalizationAnalyticsPage({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(personalizationAnalyticsProvider);
    await ref.read(personalizationAnalyticsProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(personalizationAnalyticsRealtimeProvider);
    final analytics = ref.watch(personalizationAnalyticsProvider);
    final realtime = ref.watch(personalizationAnalyticsRealtimeStateProvider);
    final days = ref.watch(personalizationAnalyticsDaysProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: analytics.when(
        loading: () => const _LoadingView(),
        error: (error, _) => _ErrorView(
          message: userFacingError(
            error,
            fallback: 'Unable to load personalization analytics.',
          ),
          onRetry: () => _refresh(ref),
        ),
        data: (snapshot) => snapshot.isEmpty
            ? _EmptyView(realtime: realtime, onRefresh: () => _refresh(ref))
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: [
                  AdminAnalyticsHeader(
                    section: AdminAnalyticsSection.personalization,
                    title: 'Preference center adoption',
                    subtitle:
                        'Anonymous totals for appearance, accessibility, layouts, favorites, and saved searches. Updated ${DateFormat.yMMMd().add_jm().format(snapshot.loadedAt)}',
                    onRefresh: () => _refresh(ref),
                    status: _RealtimeBadge(state: realtime),
                    trailing: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 7, label: Text('7D')),
                        ButtonSegment(value: 30, label: Text('30D')),
                        ButtonSegment(value: 90, label: Text('90D')),
                      ],
                      selected: {days},
                      showSelectedIcon: false,
                      onSelectionChanged: (value) {
                        ref
                                .read(
                                  personalizationAnalyticsDaysProvider.notifier,
                                )
                                .state =
                            value.first;
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _KpiGrid(snapshot: snapshot),
                  const SizedBox(height: AppSpacing.xl),
                  _AdoptionPanels(snapshot: snapshot),
                  const SizedBox(height: AppSpacing.md),
                  _TrendCard(series: snapshot.dailySeries),
                ],
              ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.snapshot});

  final PersonalizationAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final number = NumberFormat.decimalPattern();
    final items = [
      (
        'Preference profiles',
        number.format(snapshot.preferenceProfiles),
        'Saved appearance settings',
        LucideIcons.palette,
        AppColors.gold,
      ),
      (
        'Accessibility',
        '${snapshot.accessibilityAdoptionPct.toStringAsFixed(1)}%',
        snapshot.accessibilityAdoptionPct == 0
            ? 'No accessibility tools saved'
            : 'Profiles using accessibility tools',
        LucideIcons.accessibility,
        AppColors.info,
      ),
      (
        'Saved searches',
        number.format(snapshot.savedSearches),
        snapshot.savedSearches == 0
            ? 'None saved yet'
            : 'Reusable discovery criteria',
        LucideIcons.search,
        AppColors.success,
      ),
      (
        'Favorites',
        number.format(snapshot.favorites),
        snapshot.favorites == 0
            ? 'None saved yet'
            : 'Items saved from the site',
        LucideIcons.heart,
        const Color(0xFFFCA5A5),
      ),
      (
        'Dashboard layouts',
        number.format(snapshot.dashboardLayouts),
        snapshot.dashboardLayouts == 0
            ? 'No custom layouts yet'
            : 'Personalized workspace layouts',
        LucideIcons.layoutDashboard,
        AppColors.warning,
      ),
      (
        'Workspace switches',
        number.format(snapshot.workspaceSwitchesToday),
        snapshot.workspaceSwitchesToday == 0
            ? 'None recorded today'
            : 'Anonymous switches today',
        LucideIcons.panelTop,
        const Color(0xFFF5E6B8),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 3
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        final width =
            (constraints.maxWidth - AppSpacing.md * (columns - 1)) / columns;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final item in items)
              _MetricCard(
                width: width,
                label: item.$1,
                value: item.$2,
                detail: item.$3,
                icon: item.$4,
                color: item.$5,
              ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final double width;
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF141820),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
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
                      value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6E7682),
                        fontSize: 11,
                      ),
                    ),
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

class _AdoptionPanels extends StatelessWidget {
  const _AdoptionPanels({required this.snapshot});

  final PersonalizationAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final panelWidth = constraints.maxWidth >= 840
            ? (constraints.maxWidth - AppSpacing.md) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            SizedBox(
              width: panelWidth,
              child: _RankedPanel(
                title: 'Appearance',
                subtitle: 'Theme saved in Preference Center',
                icon: LucideIcons.palette,
                items: snapshot.themeDistribution,
                emptyLabel: 'No theme preferences saved yet',
              ),
            ),
            SizedBox(
              width: panelWidth,
              child: _RankedPanel(
                title: 'Saved favorites',
                subtitle: 'Item types saved from the site',
                icon: LucideIcons.heart,
                items: snapshot.favoriteTypes,
                emptyLabel: 'No favorites saved yet',
                accent: const Color(0xFFFCA5A5),
              ),
            ),
            if (snapshot.eventsByType.isNotEmpty)
              SizedBox(
                width: panelWidth,
                child: _RankedPanel(
                  title: 'Preference changes',
                  subtitle: 'Anonymous actions in this period',
                  icon: LucideIcons.activity,
                  items: snapshot.eventsByType,
                  emptyLabel: 'No preference changes in this period',
                  accent: AppColors.info,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RankedPanel extends StatelessWidget {
  const _RankedPanel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.items,
    required this.emptyLabel,
    this.accent = AppColors.gold,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<PersonalizationMetricBreakdown> items;
  final String emptyLabel;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final maximum = items.fold<int>(
      1,
      (largest, item) => item.count > largest ? item.count : largest,
    );
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF9AA1AB), fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.base),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(
                child: Text(
                  emptyLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF9AA1AB)),
                ),
              ),
            )
          else
            for (final item in items) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.displayLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    NumberFormat.decimalPattern().format(item.count),
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              LinearProgressIndicator(
                value: item.count / maximum,
                color: accent,
                backgroundColor: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                minHeight: 5,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.series});

  final List<PersonalizationDailyMetric> series;

  @override
  Widget build(BuildContext context) {
    final total = series.fold<int>(0, (sum, item) => sum + item.events);
    final peak = series.fold<int>(
      0,
      (current, item) => item.events > current ? item.events : current,
    );
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Activity',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                total == 0
                    ? 'None in this period'
                    : 'Peak ${_compact(peak)} / day',
                style: const TextStyle(color: Color(0xFF9AA1AB), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Theme, accessibility, layout, favorite, and saved-search actions',
            style: TextStyle(color: Color(0xFF9AA1AB), fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (total == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'Changes appear here as soon as someone updates Preference Center.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF9AA1AB)),
                ),
              ),
            )
          else ...[
            const _LegendDot(color: Color(0xFFF5E6B8), label: 'Changes'),
            const SizedBox(height: 10),
            Semantics(
              label:
                  '$total personalization events across ${series.length} days',
              child: SizedBox(
                height: 190,
                width: double.infinity,
                child: CustomPaint(painter: _TrendPainter(series: series)),
              ),
            ),
          ],
          if (series.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat.MMMd().format(series.first.date),
                  style: const TextStyle(color: Color(0xFF9AA1AB), fontSize: 11),
                ),
                Text(
                  DateFormat.MMMd().format(series.last.date),
                  style: const TextStyle(color: Color(0xFF9AA1AB), fontSize: 11),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _compact(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
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
  const _TrendPainter({required this.series});

  final List<PersonalizationDailyMetric> series;

  @override
  void paint(Canvas canvas, Size size) {
    final maximum = series.fold<int>(
      1,
      (value, item) => item.events > value ? item.events : value,
    );
    final gridPaint = Paint()
      ..color = AppColors.neutral500.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    for (var row = 0; row <= 3; row++) {
      final y = size.height * row / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final path = Path();
    for (var index = 0; index < series.length; index++) {
      final x = series.length == 1
          ? size.width / 2
          : size.width * index / (series.length - 1);
      final y =
          size.height - (series[index].events.clamp(0, maximum) / maximum) * size.height;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fill = Path.from(path)
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
      path,
      Paint()
        ..color = const Color(0xFFF5E6B8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.series != series;
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF141820),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x18FFFFFF)),
      ),
      child: Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: child),
    );
  }
}

class _RealtimeBadge extends StatelessWidget {
  const _RealtimeBadge({required this.state});

  final PersonalizationAnalyticsRealtimeState state;

  @override
  Widget build(BuildContext context) {
    final note = switch (state) {
      PersonalizationAnalyticsRealtimeState.live =>
        'Your latest records are here.',
      PersonalizationAnalyticsRealtimeState.connecting =>
        "We're gathering the latest records.",
      PersonalizationAnalyticsRealtimeState.error ||
      PersonalizationAnalyticsRealtimeState.offline =>
        "We'll refresh this when the connection is back.",
    };
    return Text(
      note,
      style: const TextStyle(
        color: Color(0xFF9AA1AB),
        fontSize: 12,
        height: 1.35,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.gold),
          SizedBox(height: AppSpacing.base),
          Text(
            'Loading personalization analytics…',
            style: TextStyle(color: Color(0xFF9AA1AB)),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: _Panel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.alertCircle, color: AppColors.error, size: 32),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Personalization analytics unavailable',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF9AA1AB)),
              ),
              const SizedBox(height: AppSpacing.base),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(LucideIcons.refreshCw, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.realtime, required this.onRefresh});

  final PersonalizationAnalyticsRealtimeState realtime;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        AdminAnalyticsHeader(
          section: AdminAnalyticsSection.personalization,
          title: 'Preference center adoption',
          subtitle:
              'Anonymous totals for appearance, accessibility, layouts, favorites, and saved searches.',
          onRefresh: onRefresh,
          status: _RealtimeBadge(state: realtime),
        ),
        const SizedBox(height: AppSpacing.xl),
        const _Panel(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
            child: Column(
              children: [
                Icon(LucideIcons.palette, size: 36, color: AppColors.gold),
                SizedBox(height: AppSpacing.md),
                Text(
                  'No preference profiles yet',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  'Appearance, favorites, and saved searches will appear here as people use Preference Center.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF9AA1AB)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
