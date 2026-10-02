import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/admin/presentation/widgets/admin_analytics_header.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/enterprise_search_models.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/enterprise_search_controller.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

String _prettyLabel(String raw) {
  final cleaned = raw.trim();
  if (cleaned.isEmpty) return cleaned;
  return cleaned
      .split(RegExp(r'[_\s]+'))
      .where((part) => part.isNotEmpty)
      .map((part) {
        if (part.length == 1) return part.toUpperCase();
        return '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}';
      })
      .join(' ');
}

/// Live, privacy-safe aggregate search analytics for administrators.
class SearchInsightsPage extends ConsumerStatefulWidget {
  const SearchInsightsPage({super.key});

  @override
  ConsumerState<SearchInsightsPage> createState() => _SearchInsightsPageState();
}

class _SearchInsightsPageState extends ConsumerState<SearchInsightsPage> {
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    ref.watch(enterpriseSearchRealtimeProvider);
    final realtime = ref.watch(searchAnalyticsRealtimeStateProvider);
    final analytics = ref.watch(searchAnalyticsProvider(_days));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: analytics.when(
        loading: () => const _LoadingState(),
        error: (error, _) => _ErrorState(
          message: userFacingError(
            error,
            fallback: 'Unable to load live search analytics.',
          ),
          onRetry: () => ref.invalidate(searchAnalyticsProvider(_days)),
        ),
        data: (snapshot) => _InsightsContent(
          snapshot: snapshot,
          selectedDays: _days,
          realtime: realtime,
          onDaysChanged: (days) => setState(() => _days = days),
          onRefresh: () => ref.invalidate(searchAnalyticsProvider(_days)),
        ),
      ),
    );
  }
}

class _InsightsContent extends StatelessWidget {
  const _InsightsContent({
    required this.snapshot,
    required this.selectedDays,
    required this.realtime,
    required this.onDaysChanged,
    required this.onRefresh,
  });

  final SearchAnalyticsSnapshot snapshot;
  final int selectedDays;
  final SearchAnalyticsRealtimeState realtime;
  final ValueChanged<int> onDaysChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        AdminAnalyticsHeader(
          section: AdminAnalyticsSection.search,
          title: 'Search performance',
          subtitle:
              'Anonymized aggregates only. No individual searcher identity is displayed.',
          onRefresh: onRefresh,
          status: _RealtimeBadge(state: realtime),
          trailing: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 7, label: Text('7D')),
              ButtonSegment(value: 30, label: Text('30D')),
              ButtonSegment(value: 90, label: Text('90D')),
            ],
            selected: {selectedDays},
            onSelectionChanged: (value) => onDaysChanged(value.first),
            showSelectedIcon: false,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (snapshot.isEmpty)
          const _EmptyState()
        else ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1000
                  ? 4
                  : constraints.maxWidth >= 560
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * AppSpacing.md) /
                  columns;
              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  _MetricCard(
                    width: width,
                    icon: LucideIcons.search,
                    label: 'Total searches',
                    value: _compact(snapshot.totalSearches),
                    detail: '${snapshot.periodDays}-day window',
                    color: AppColors.gold,
                  ),
                  _MetricCard(
                    width: width,
                    icon: LucideIcons.users,
                    label: 'Unique searchers',
                    value: _compact(snapshot.uniqueSearchers),
                    detail: 'Signed-in searchers',
                    color: AppColors.info,
                  ),
                  _MetricCard(
                    width: width,
                    icon: LucideIcons.timer,
                    label: 'Average latency',
                    value: '${snapshot.avgLatencyMs.toStringAsFixed(0)} ms',
                    detail: 'Submission to results',
                    color: AppColors.success,
                  ),
                  _MetricCard(
                    width: width,
                    icon: LucideIcons.alertCircle,
                    label: 'Zero-result rate',
                    value:
                        '${(snapshot.zeroResultRate * 100).toStringAsFixed(1)}%',
                    detail: '${_compact(snapshot.zeroResultCount)} searches',
                    color: AppColors.warning,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          _TrendPanel(points: snapshot.dailySeries),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
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
                      title: 'Top search terms',
                      icon: LucideIcons.search,
                      items: snapshot.topTerms,
                      emptyLabel: 'No search terms in this period',
                    ),
                  ),
                  SizedBox(
                    width: panelWidth,
                    child: _RankedPanel(
                      title: 'Search modes',
                      icon: LucideIcons.layers,
                      items: snapshot.popularModes,
                      emptyLabel: 'No mode activity in this period',
                    ),
                  ),
                  SizedBox(
                    width: panelWidth,
                    child: _RankedPanel(
                      title: 'Zero-result terms',
                      icon: LucideIcons.alertCircle,
                      items: snapshot.zeroResultTerms,
                      emptyLabel: 'Every submitted search returned a result',
                      accent: AppColors.warning,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  static String _compact(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;
  final String detail;
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
                      style: const TextStyle(color: Color(0xFF6E7682), fontSize: 11),
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

class _TrendPanel extends StatelessWidget {
  const _TrendPanel({required this.points});

  final List<SearchAnalyticsDailyPoint> points;

  @override
  Widget build(BuildContext context) {
    final maxSearches = points.fold<int>(
      0,
      (current, point) => point.searches > current ? point.searches : current,
    );
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Search trend',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                'Peak ${_InsightsContent._compact(maxSearches)} / day',
                style: const TextStyle(color: Color(0xFF9AA1AB), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Submitted searches and searches that returned nothing',
            style: TextStyle(color: Color(0xFF9AA1AB), fontSize: 12),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              _LegendDot(color: Color(0xFFF5E6B8), label: 'Searches'),
              SizedBox(width: 14),
              _LegendDot(color: Color(0xFFF59E0B), label: 'Zero results'),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 190,
            width: double.infinity,
            child: points.isEmpty
                ? const Center(
                    child: Text(
                      'No trend data available',
                      style: TextStyle(color: Color(0xFF9AA1AB)),
                    ),
                  )
                : CustomPaint(
                    painter: _TrendPainter(points: points),
                  ),
          ),
          if (points.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _dateLabel(points.first.date),
                  style: const TextStyle(color: Color(0xFF9AA1AB), fontSize: 11),
                ),
                Text(
                  _dateLabel(points.last.date),
                  style: const TextStyle(color: Color(0xFF9AA1AB), fontSize: 11),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _dateLabel(DateTime date) =>
      DateFormat('d MMM').format(date.toLocal());
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
        Text(label, style: const TextStyle(color: Color(0xFFC8CDD4), fontSize: 12)),
      ],
    );
  }
}

class _RankedPanel extends StatelessWidget {
  const _RankedPanel({
    required this.title,
    required this.icon,
    required this.items,
    required this.emptyLabel,
    this.accent = AppColors.gold,
  });

  final String title;
  final IconData icon;
  final List<SearchAnalyticsCount> items;
  final String emptyLabel;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final maximum = items.isEmpty ? 1 : items.first.count.clamp(1, 1 << 30);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
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
                      _prettyLabel(item.label),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${item.count}',
                    style: TextStyle(color: accent, fontWeight: FontWeight.w800),
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
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: child,
      ),
    );
  }
}

class _RealtimeBadge extends StatelessWidget {
  const _RealtimeBadge({required this.state});

  final SearchAnalyticsRealtimeState state;

  @override
  Widget build(BuildContext context) {
    final note = switch (state) {
      SearchAnalyticsRealtimeState.live => 'Your latest records are here.',
      SearchAnalyticsRealtimeState.connecting =>
        "We're gathering the latest records.",
      SearchAnalyticsRealtimeState.error ||
      SearchAnalyticsRealtimeState.disconnected =>
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

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.gold),
          SizedBox(height: AppSpacing.base),
          Text(
            'Loading search analytics…',
            style: TextStyle(color: Color(0xFF9AA1AB)),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

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
              const Icon(
                LucideIcons.alertCircle,
                color: AppColors.error,
                size: 32,
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Search analytics unavailable',
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const _Panel(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
        child: Column(
          children: [
            Icon(LucideIcons.search, size: 36, color: AppColors.gold),
            SizedBox(height: AppSpacing.md),
            Text(
              'No submitted searches in this period',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              'New searches appear here as soon as they are submitted.',
              style: TextStyle(color: Color(0xFF9AA1AB)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({required this.points});

  final List<SearchAnalyticsDailyPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final maximum = points.fold<int>(
      1,
      (value, point) => point.searches > value ? point.searches : value,
    );
    final gridPaint = Paint()
      ..color = AppColors.neutral500.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    for (var row = 0; row <= 3; row++) {
      final y = size.height * row / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    Path pathFor(int Function(SearchAnalyticsDailyPoint) valueOf) {
      final path = Path();
      for (var index = 0; index < points.length; index++) {
        final x = points.length == 1
            ? size.width / 2
            : size.width * index / (points.length - 1);
        final y =
            size.height -
            (valueOf(points[index]).clamp(0, maximum) / maximum) * size.height;
        if (index == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      return path;
    }

    final searches = pathFor((point) => point.searches);
    final fill = Path.from(searches)
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
    canvas
      ..drawPath(
        searches,
        Paint()
          ..color = const Color(0xFFF5E6B8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawPath(
        pathFor((point) => point.zeroResults),
        Paint()
          ..color = const Color(0xFFF59E0B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
