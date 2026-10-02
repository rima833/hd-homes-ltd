import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/home/data/providers/roi_calculator_provider.dart';
import 'package:hdhomesproject/features/home/domain/roi_calculator_math.dart';
import 'package:hdhomesproject/features/settings/presentation/providers/platform_settings_providers.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Homepage / shared ROI calculator — CMS-backed premium UI.
class HomeRoiCalculatorSection extends ConsumerWidget {
  const HomeRoiCalculatorSection({
    super.key,
    this.wrapInSection = true,
  });

  /// When false, skip [SectionWrapper] (parent already provides a section band).
  final bool wrapInSection;

  static const bg = Color(0xFF0A0A0A);
  static const panel = Color(0xFF121212);
  static const card = Color(0xFF161616);
  static const gold = Color(0xFFD4AF37);
  static const muted = Color(0xFF8A8A8A);
  static const success = Color(0xFF3DDC97);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref
            .watch(publishedPlatformSettingsProvider)
            .valueOrNull
            ?.enableRoiCalculator ??
        true;
    if (!enabled) return const SizedBox.shrink();

    ref.watch(roiCalculatorRealtimeProvider);
    final settingsAsync = ref.watch(publishedRoiCalculatorSettingsProvider);
    final state = ref.watch(roiCalculatorControllerProvider);
    final controller = ref.read(roiCalculatorControllerProvider.notifier);

    final body = settingsAsync.when(
      loading: () => const SizedBox(
        height: 240,
        child: Center(
          child: CircularProgressIndicator(color: gold),
        ),
      ),
      error: (e, _) => _ErrorBox(message: '$e'),
      data: (settings) {
        if (!settings.isEnabled) return const SizedBox.shrink();
        if (state == null) {
          return const SizedBox(
            height: 240,
            child: Center(
              child: CircularProgressIndicator(color: gold),
            ),
          );
        }
        final estimate = controller.estimate!;
        final stacked = context.isMobile || context.screenWidth < 920;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              settings.overline.toUpperCase(),
              style: GoogleFonts.manrope(
                color: gold,
                fontSize: 11,
                letterSpacing: 3.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              settings.title,
              style: GoogleFonts.playfairDisplay(
                color: Colors.white,
                fontSize: context.isMobile ? 30 : 40,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              settings.subtitle,
              style: GoogleFonts.manrope(
                color: muted,
                fontSize: 14.5,
              ),
            ),
            const SizedBox(height: 28),
            stacked
                ? Column(
                    children: [
                      _InputsCard(
                        settings: settings,
                        state: state,
                        controller: controller,
                      ),
                      const SizedBox(height: 20),
                      _ResultsCard(
                        settings: settings,
                        estimate: estimate,
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 10,
                        child: _InputsCard(
                          settings: settings,
                          state: state,
                          controller: controller,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 12,
                        child: _ResultsCard(
                          settings: settings,
                          estimate: estimate,
                        ),
                      ),
                    ],
                  ),
          ],
        ).animate().fadeIn(duration: 420.ms);
      },
    );

    if (!wrapInSection) return body;

    return SectionWrapper(
      backgroundColor: bg,
      padding: EdgeInsets.symmetric(
        horizontal: context.pagePadding,
        vertical: context.isMobile ? 36 : 56,
      ),
      child: body,
    );
  }
}

class _InputsCard extends StatelessWidget {
  const _InputsCard({
    required this.settings,
    required this.state,
    required this.controller,
  });

  final CmsRoiCalculatorSettings settings;
  final RoiCalculatorState state;
  final RoiCalculatorController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: HomeRoiCalculatorSection.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.calculator,
                color: HomeRoiCalculatorSection.gold,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  settings.inputsTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            settings.inputsSubtitle,
            style: GoogleFonts.manrope(
              color: HomeRoiCalculatorSection.muted,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 22),
          _RoiSlider(
            icon: LucideIcons.wallet,
            label: 'Investment amount',
            display: _moneyShort(state.amount, settings.currencySymbol),
            value: state.amount,
            min: settings.amountMin,
            max: settings.amountMax,
            markers: [
              _moneyShort(settings.amountMin, settings.currencySymbol),
              _moneyShort(settings.amountMax, settings.currencySymbol),
            ],
            onChanged: controller.setAmount,
          ),
          _RoiSlider(
            icon: LucideIcons.trendingUp,
            label: 'Expected annual growth',
            display: '${state.growth.toStringAsFixed(1)}%',
            value: state.growth,
            min: settings.growthMin,
            max: settings.growthMax,
            markers: [
              '${settings.growthMin.toStringAsFixed(0)}%',
              '${settings.growthMax.toStringAsFixed(0)}%',
            ],
            onChanged: controller.setGrowth,
          ),
          _RoiSlider(
            icon: LucideIcons.calendarDays,
            label: 'Holding period (years)',
            display:
                '${state.years.round()} ${state.years.round() == 1 ? 'year' : 'years'}',
            value: state.years,
            min: settings.yearsMin,
            max: settings.yearsMax,
            divisions:
                (settings.yearsMax - settings.yearsMin).round().clamp(1, 40),
            markers: [
              '${settings.yearsMin.round()} yr',
              '${settings.yearsMax.round()} yr',
            ],
            onChanged: controller.setYears,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: Material(
              color: HomeRoiCalculatorSection.gold,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(LucideIcons.barChart3, size: 16, color: Colors.black),
                    const SizedBox(width: 8),
                    Text(
                      'Calculate ROI',
                      style: GoogleFonts.manrope(
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(LucideIcons.arrowRight, size: 16, color: Colors.black),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton.icon(
              onPressed: () => controller.reset(settings),
              icon: const Icon(LucideIcons.rotateCcw, size: 14),
              label: const Text('Reset'),
              style: TextButton.styleFrom(
                foregroundColor: HomeRoiCalculatorSection.muted,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F0F),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  LucideIcons.info,
                  size: 14,
                  color: HomeRoiCalculatorSection.gold,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    settings.infoText,
                    style: GoogleFonts.manrope(
                      color: HomeRoiCalculatorSection.muted,
                      fontSize: 12,
                      height: 1.45,
                    ),
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

class _ResultsCard extends StatelessWidget {
  const _ResultsCard({
    required this.settings,
    required this.estimate,
  });

  final CmsRoiCalculatorSettings settings;
  final RoiEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_NG',
      symbol: settings.currencySymbol,
      decimalDigits: 0,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: HomeRoiCalculatorSection.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.coins,
                color: HomeRoiCalculatorSection.gold,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  settings.resultsTitle,
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: HomeRoiCalculatorSection.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: HomeRoiCalculatorSection.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Estimate',
                      style: GoogleFonts.manrope(
                        color: HomeRoiCalculatorSection.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PROJECTED VALUE',
                      style: GoogleFonts.manrope(
                        color: HomeRoiCalculatorSection.muted,
                        fontSize: 11,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currency.format(estimate.projectedValue),
                      key: ValueKey(estimate.projectedValue),
                      style: GoogleFonts.playfairDisplay(
                        color: HomeRoiCalculatorSection.gold,
                        fontSize: context.isMobile ? 28 : 34,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'at the end of ${estimate.years.round()} years',
                        style: GoogleFonts.manrope(
                          color: HomeRoiCalculatorSection.muted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _RoiGauge(percent: estimate.totalRoiPercent),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 420;
              final tiles = [
                _MetricTile(
                  icon: LucideIcons.wallet,
                  label: 'Initial investment',
                  value: currency.format(estimate.amount),
                ),
                _MetricTile(
                  icon: LucideIcons.coins,
                  label: 'Profit earned',
                  value: currency.format(estimate.netProfit),
                  valueColor: HomeRoiCalculatorSection.success,
                ),
                _MetricTile(
                  icon: LucideIcons.pieChart,
                  label: 'Total value',
                  value: currency.format(estimate.projectedValue),
                ),
                _MetricTile(
                  icon: LucideIcons.barChart3,
                  label: 'Annualized return',
                  value:
                      '${estimate.annualizedReturnPercent.toStringAsFixed(1)}% avg',
                ),
              ];
              if (wide) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: tiles[0]),
                        const SizedBox(width: 10),
                        Expanded(child: tiles[1]),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: tiles[2]),
                        const SizedBox(width: 10),
                        Expanded(child: tiles[3]),
                      ],
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < tiles.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    tiles[i],
                  ],
                ],
              );
            },
          ),
          if (settings.showChart) ...[
            const SizedBox(height: 20),
            Text(
              'Projected Growth Over Time',
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              width: double.infinity,
              child: _GrowthChart(
                points: estimate.chartPoints,
                symbol: settings.currencySymbol,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                LucideIcons.shieldCheck,
                size: 14,
                color: HomeRoiCalculatorSection.muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  settings.disclaimerText,
                  style: GoogleFonts.manrope(
                    color: HomeRoiCalculatorSection.muted,
                    fontSize: 11.5,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: Material(
              color: const Color(0xFF1A1408),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () {
                  final path = settings.ctaPath.trim();
                  if (path.isEmpty) return;
                  context.go(path);
                },
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      settings.ctaLabel,
                      style: GoogleFonts.manrope(
                        color: HomeRoiCalculatorSection.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      LucideIcons.arrowRight,
                      size: 16,
                      color: HomeRoiCalculatorSection.gold,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoiGauge extends StatelessWidget {
  const _RoiGauge({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    final t = (percent / 100).clamp(0.0, 1.0);
    return SizedBox(
      width: 92,
      height: 92,
      child: CustomPaint(
        painter: _GaugePainter(progress: t),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'TOTAL ROI',
                style: GoogleFonts.manrope(
                  color: HomeRoiCalculatorSection.muted,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${percent.toStringAsFixed(1)}%',
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    LucideIcons.arrowUpRight,
                    size: 12,
                    color: HomeRoiCalculatorSection.success,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    final bg = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final fg = Paint()
      ..color = HomeRoiCalculatorSection.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2,
      false,
      bg,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: HomeRoiCalculatorSection.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.manrope(
                    color: HomeRoiCalculatorSection.muted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  key: ValueKey(value),
                  style: GoogleFonts.manrope(
                    color: valueColor ?? Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
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

class _GrowthChart extends StatelessWidget {
  const _GrowthChart({
    required this.points,
    required this.symbol,
  });

  final List<RoiChartPoint> points;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GrowthChartPainter(points: points, symbol: symbol),
      child: const SizedBox.expand(),
    );
  }
}

class _GrowthChartPainter extends CustomPainter {
  _GrowthChartPainter({required this.points, required this.symbol});

  final List<RoiChartPoint> points;
  final String symbol;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final maxV = points.map((p) => p.value).reduce(math.max);
    final minV = 0.0;
    final range = (maxV - minV).clamp(1, double.infinity);

    final path = Path();
    final fill = Path();
    for (var i = 0; i < points.length; i++) {
      final x = size.width * (i / (points.length - 1).clamp(1, 100));
      final y = size.height - ((points[i].value - minV) / range) * (size.height - 24) - 8;
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(x, size.height);
        fill.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }
    fill.lineTo(size.width, size.height);
    fill.close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            HomeRoiCalculatorSection.gold.withValues(alpha: 0.28),
            HomeRoiCalculatorSection.gold.withValues(alpha: 0.02),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = HomeRoiCalculatorSection.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    for (var i = 0; i < points.length; i++) {
      final x = size.width * (i / (points.length - 1).clamp(1, 100));
      final y = size.height - ((points[i].value - minV) / range) * (size.height - 24) - 8;
      canvas.drawCircle(
        Offset(x, y),
        3.5,
        Paint()..color = HomeRoiCalculatorSection.gold,
      );
      final label = points[i].value >= 1e6
          ? '$symbol${(points[i].value / 1e6).toStringAsFixed(2)}M'
          : '$symbol${points[i].value.toStringAsFixed(0)}';
      textPainter.text = TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xFFB0B0B0),
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          (x - textPainter.width / 2).clamp(0, size.width - textPainter.width),
          (y - 16).clamp(0, size.height - 12),
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GrowthChartPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.symbol != symbol;
}

class _RoiSlider extends StatelessWidget {
  const _RoiSlider({
    required this.icon,
    required this.label,
    required this.display,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.markers,
    this.divisions,
  });

  final IconData icon;
  final String label;
  final String display;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final List<String> markers;
  final int? divisions;

  @override
  Widget build(BuildContext context) {
    final safeMax = max <= min ? min + 1 : max;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: HomeRoiCalculatorSection.gold.withValues(alpha: 0.7),
                  ),
                ),
                child: Icon(icon, size: 14, color: HomeRoiCalculatorSection.gold),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ),
              Text(
                display,
                style: GoogleFonts.manrope(
                  color: HomeRoiCalculatorSection.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: HomeRoiCalculatorSection.gold,
              inactiveTrackColor: Colors.white12,
              thumbColor: HomeRoiCalculatorSection.gold,
              overlayColor:
                  HomeRoiCalculatorSection.gold.withValues(alpha: 0.16),
              trackHeight: 3.5,
            ),
            child: Slider(
              value: value.clamp(min, safeMax),
              min: min,
              max: safeMax,
              divisions: divisions ?? 40,
              onChanged: onChanged,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final m in markers)
                Text(
                  m,
                  style: GoogleFonts.manrope(
                    color: HomeRoiCalculatorSection.muted,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: HomeRoiCalculatorSection.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: HomeRoiCalculatorSection.gold.withValues(alpha: 0.25),
        ),
      ),
      child: Text(message, style: GoogleFonts.manrope(color: Colors.white70)),
    );
  }
}

String _moneyShort(double value, String symbol) {
  if (value >= 1000000) {
    return '$symbol${(value / 1000000).toStringAsFixed(1)}M';
  }
  return NumberFormat.currency(
    locale: 'en_NG',
    symbol: symbol,
    decimalDigits: 0,
  ).format(value);
}
