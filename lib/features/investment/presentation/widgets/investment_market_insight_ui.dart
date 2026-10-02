import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/investment/presentation/widgets/investment_opportunity_ui.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

IconData marketInsightIcon(String name) {
  switch (name) {
    case 'lineChart':
      return LucideIcons.lineChart;
    case 'barChart':
      return LucideIcons.barChart3;
    case 'building2':
      return LucideIcons.building2;
    case 'percent':
      return LucideIcons.percent;
    case 'map':
      return LucideIcons.mapPin;
    case 'pieChart':
      return LucideIcons.pieChart;
    case 'trendingUp':
    default:
      return LucideIcons.trendingUp;
  }
}

Color marketTrendColor(String direction) {
  switch (direction) {
    case 'down':
      return const Color(0xFFF87171);
    case 'neutral':
      return kInvestmentMuted;
    default:
      return const Color(0xFF4ADE80);
  }
}

class MarketInsightsSectionHeader extends StatelessWidget {
  const MarketInsightsSectionHeader({
    super.key,
    required this.overline,
    required this.title,
    required this.subtitle,
    required this.centered,
  });

  final String overline;
  final String title;
  final String subtitle;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final cross = centered
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    final align = centered ? TextAlign.center : TextAlign.start;

    return Column(
      crossAxisAlignment: cross,
      children: [
        Text(
          overline.toUpperCase(),
          textAlign: align,
          style: const TextStyle(
            color: kInvestmentGold,
            letterSpacing: 3.2,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: align,
          style: GoogleFonts.playfairDisplay(
            color: Colors.white,
            fontSize: centered ? 38 : 34,
            fontWeight: FontWeight.w600,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: centered ? 120 : 80,
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                kInvestmentGold.withValues(alpha: 0.9),
                Colors.transparent,
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Text(
            subtitle,
            textAlign: align,
            style: const TextStyle(
              color: kInvestmentMuted,
              fontSize: 15,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }
}

class MarketInsightCard extends StatefulWidget {
  const MarketInsightCard({
    super.key,
    required this.insight,
    this.compact = false,
    this.animateValue = true,
    this.animationDelay = Duration.zero,
  });

  final CmsWebsiteMarketInsight insight;
  final bool compact;
  final bool animateValue;
  final Duration animationDelay;

  @override
  State<MarketInsightCard> createState() => _MarketInsightCardState();
}

class _MarketInsightCardState extends State<MarketInsightCard>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  bool _highlight = false;
  late AnimationController _highlightCtrl;

  @override
  void initState() {
    super.initState();
    _highlightCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didUpdateWidget(covariant MarketInsightCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.insight.value != widget.insight.value &&
        widget.animateValue) {
      _highlight = true;
      _highlightCtrl.forward(from: 0).whenComplete(() {
        if (mounted) setState(() => _highlight = false);
      });
    }
  }

  @override
  void dispose() {
    _highlightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insight = widget.insight;
    final compact = widget.compact;
    final trendColor = marketTrendColor(insight.trendDirection);
    final showArrow =
        insight.trendDirection == 'up' || insight.trendDirection == 'down';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()
          ..setTranslationRaw(0, _hovered ? -4.0 : 0.0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: kInvestmentCardBg,
          border: Border.all(
            color: _highlight
                ? kInvestmentGold.withValues(alpha: 0.75)
                : _hovered
                ? kInvestmentGold.withValues(alpha: 0.55)
                : kInvestmentGold.withValues(alpha: 0.18),
          ),
          boxShadow: [
            if (_hovered || _highlight)
              BoxShadow(
                color: kInvestmentGold.withValues(
                  alpha: _highlight ? 0.22 : 0.12,
                ),
                blurRadius: _highlight ? 28 : 24,
                offset: const Offset(0, 10),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned(
                right: compact ? -20 : -10,
                bottom: compact ? -20 : -10,
                width: compact ? 140 : 180,
                height: compact ? 120 : 150,
                child: Opacity(
                  opacity: 0.85,
                  child: _MarketInsightVisual(
                    insight: insight,
                    compact: compact,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(compact ? 16 : 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: compact ? 34 : 40,
                          height: compact ? 34 : 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: kInvestmentGold.withValues(alpha: 0.12),
                            border: Border.all(
                              color: kInvestmentGold.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Icon(
                            marketInsightIcon(insight.icon),
                            size: compact ? 16 : 18,
                            color: kInvestmentGold,
                          ),
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (showArrow)
                                  Icon(
                                    insight.trendDirection == 'up'
                                        ? LucideIcons.triangle
                                        : LucideIcons.triangle,
                                    size: 10,
                                    color: trendColor,
                                  ),
                                if (showArrow) const SizedBox(width: 4),
                                AnimatedSwitcher(
                                  duration: AppDurations.fast,
                                  transitionBuilder: (child, anim) =>
                                      FadeTransition(
                                        opacity: anim,
                                        child: SlideTransition(
                                          position: Tween<Offset>(
                                            begin: const Offset(0, 0.15),
                                            end: Offset.zero,
                                          ).animate(anim),
                                          child: child,
                                        ),
                                      ),
                                  child: Text(
                                    insight.value,
                                    key: ValueKey(insight.value),
                                    style: TextStyle(
                                      color: kInvestmentGold,
                                      fontWeight: FontWeight.w800,
                                      fontSize: compact ? 14 : 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 12 : 16),
                    Text(
                      insight.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: compact ? 15 : 17,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (insight.trend.trim().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: kInvestmentGold.withValues(alpha: 0.45),
                          ),
                          color: Colors.black.withValues(alpha: 0.25),
                        ),
                        child: Text(
                          insight.trend.toUpperCase(),
                          style: const TextStyle(
                            color: kInvestmentGoldSoft,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    SizedBox(height: compact ? 10 : 14),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: compact ? 220 : 280,
                      ),
                      child: Text(
                        insight.summary,
                        maxLines: compact ? 3 : 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: kInvestmentMuted,
                          fontSize: compact ? 12 : 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                    if (insight.location.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            LucideIcons.mapPin,
                            size: 12,
                            color: kInvestmentGold.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              insight.location,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: compact ? 11 : 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (insight.hasDetailLink) ...[
                      const SizedBox(height: 14),
                      Semantics(
                        button: true,
                        label: 'View source for ${insight.title}',
                        child: InkWell(
                          onTap: () => _openDetail(insight.sourceUrl!),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View Source',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                LucideIcons.arrowRight,
                                size: 14,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDetail(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _MarketInsightVisual extends StatelessWidget {
  const _MarketInsightVisual({required this.insight, required this.compact});

  final CmsWebsiteMarketInsight insight;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (insight.visualType == 'image' &&
        (insight.coverImageUrl?.trim().isNotEmpty ?? false)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: MediaDeliveryImage(
          url: insight.coverImageUrl!.trim(),
          fit: BoxFit.cover,
          errorWidget: _ChartVisual(type: insight.visualType),
        ),
      );
    }
    return _ChartVisual(type: insight.visualType, value: insight.value);
  }
}

class _ChartVisual extends StatelessWidget {
  const _ChartVisual({required this.type, this.value = ''});

  final String type;
  final String value;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _InsightChartPainter(type: type, value: value),
      child: const SizedBox.expand(),
    );
  }
}

class _InsightChartPainter extends CustomPainter {
  _InsightChartPainter({required this.type, required this.value});

  final String type;
  final String value;

  @override
  void paint(Canvas canvas, Size size) {
    switch (type) {
      case 'bar_chart':
        _paintBars(canvas, size);
      case 'gauge':
        _paintGauge(canvas, size);
      case 'image':
        _paintLine(canvas, size);
      default:
        _paintLine(canvas, size);
    }
  }

  void _paintLine(Canvas canvas, Size size) {
    final path = Path();
    final points = [
      Offset(size.width * 0.05, size.height * 0.75),
      Offset(size.width * 0.25, size.height * 0.55),
      Offset(size.width * 0.45, size.height * 0.62),
      Offset(size.width * 0.65, size.height * 0.35),
      Offset(size.width * 0.9, size.height * 0.2),
    ];
    path.moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    final paint = Paint()
      ..color = kInvestmentGold.withValues(alpha: 0.85)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);
    for (final p in points) {
      canvas.drawCircle(p, 3, Paint()..color = kInvestmentGoldSoft);
    }
  }

  void _paintBars(Canvas canvas, Size size) {
    final bars = [0.45, 0.62, 0.55, 0.78, 0.92];
    final barW = size.width / (bars.length * 2);
    for (var i = 0; i < bars.length; i++) {
      final h = size.height * bars[i];
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(barW + i * barW * 2, size.height - h, barW, h),
        const Radius.circular(4),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              kInvestmentGold.withValues(alpha: 0.35),
              kInvestmentGoldSoft,
            ],
          ).createShader(rect.outerRect),
      );
    }
  }

  void _paintGauge(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.55);
    final radius = math.min(size.width, size.height) * 0.34;
    final bg = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    final fg = Paint()
      ..color = kInvestmentGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      math.pi * 1.5,
      false,
      bg,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      math.pi * 0.95,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _InsightChartPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.value != value;
}

class MarketInsightCardSkeleton extends StatelessWidget {
  const MarketInsightCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: kInvestmentCardBg,
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              const Spacer(),
              Container(
                width: 72,
                height: 16,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: 180,
            height: 14,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: 90,
            height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 220,
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
        ],
      ),
    );
  }
}

class MarketInsightsEmptyState extends StatelessWidget {
  const MarketInsightsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: kInvestmentCardBg,
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Icon(
            LucideIcons.lineChart,
            size: 32,
            color: kInvestmentGold.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 12),
          const Text(
            'Market insights are currently being updated.',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Check back soon for the latest investment outlook.',
            textAlign: TextAlign.center,
            style: TextStyle(color: kInvestmentMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class MarketInsightsErrorState extends StatelessWidget {
  const MarketInsightsErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: kInvestmentCardBg,
        border: Border.all(
          color: const Color(0xFFF87171).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.wifiOff, size: 32, color: Color(0xFFF87171)),
          const SizedBox(height: 12),
          const Text(
            'Market insights could not be loaded.',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: kInvestmentMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class MarketInsightsTrustStrip extends StatelessWidget {
  const MarketInsightsTrustStrip({
    super.key,
    required this.stats,
    required this.mobile,
  });

  final List<({String value, String label, IconData icon})> stats;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();

    final tiles = [
      for (final stat in stats)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kInvestmentGold.withValues(alpha: 0.12),
                    border: Border.all(
                      color: kInvestmentGold.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(stat.icon, size: 16, color: kInvestmentGold),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stat.value,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        stat.label,
                        style: const TextStyle(
                          color: kInvestmentMuted,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 10 : 16,
        vertical: mobile ? 12 : 18,
      ),
      decoration: BoxDecoration(
        color: kInvestmentCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kInvestmentGold.withValues(alpha: 0.14)),
      ),
      child: mobile
          ? Column(
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  tiles[i],
                  if (i < tiles.length - 1)
                    Divider(
                      color: Colors.white.withValues(alpha: 0.06),
                      height: 16,
                    ),
                ],
              ],
            )
          : Row(children: tiles),
    );
  }
}

IconData companyStatIcon(String name) {
  switch (name) {
    case 'users':
      return LucideIcons.users;
    case 'lineChart':
      return LucideIcons.lineChart;
    case 'building':
      return LucideIcons.building2;
    case 'shield':
      return LucideIcons.shieldCheck;
    case 'award':
      return LucideIcons.award;
    default:
      return LucideIcons.barChart3;
  }
}
