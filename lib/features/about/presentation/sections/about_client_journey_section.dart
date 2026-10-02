import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/about/data/models/about_cms_content.dart';
import 'package:hdhomesproject/features/about/presentation/widgets/about_icons.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:lucide_icons/lucide_icons.dart';

const _journeyBg = Color(0xFF0F1117);
const _cardBg = Color(0xFF151821);
const _cardBgHover = Color(0xFF1A1D26);
const _iconWell = Color(0xFF10131A);

/// Premium serpentine "Our client journey" — CMS-backed with seeded fallbacks.
///
/// Desktop path (logical order always 01 Inquiry → 09 After-Sales):
/// ```
/// 01 → 02 → 03
///           ↓
/// 06 ← 05 ← 04
/// ↓
/// 07 → 08 → 09 →
/// ```
class AboutClientJourneySection extends ConsumerWidget {
  const AboutClientJourneySection({
    super.key,
    required this.fallbackSteps,
  });

  final List<AboutProcessStep> fallbackSteps;

  static const _defaultBenefits = <AboutJourneyBenefit>[
    AboutJourneyBenefit(
      title: 'Transparent Process',
      description: 'Clear communication at every step.',
      iconName: 'shield',
    ),
    AboutJourneyBenefit(
      title: 'Client First',
      description: 'Your goals drive everything we do.',
      iconName: 'award',
    ),
    AboutJourneyBenefit(
      title: 'On-Time Delivery',
      description: 'Committed to timelines and quality.',
      iconName: 'target',
    ),
    AboutJourneyBenefit(
      title: 'Lifetime Support',
      description: "We're with you, always.",
      iconName: 'heart_handshake',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(clientJourneyRealtimeProvider);
    final cmsSteps =
        ref.watch(publishedClientJourneyStepsProvider).valueOrNull ?? const [];
    final cmsBenefits =
        ref.watch(publishedJourneyBenefitsProvider).valueOrNull ?? const [];

    // Canonical public order: ascending sort_order (01 Inquiry → 09 After-Sales).
    final sortedCms = [...cmsSteps]
      ..sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        if (byOrder != 0) return byOrder;
        return a.title.compareTo(b.title);
      });

    final steps = sortedCms.isNotEmpty
        ? [
            for (final s in sortedCms)
              AboutProcessStep(
                title: s.title,
                description: s.description,
                timeline: s.timeline,
                iconName: s.iconName,
              ),
          ]
        : List<AboutProcessStep>.from(fallbackSteps);

    final sortedBenefits = [...cmsBenefits]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final benefits = sortedBenefits.isNotEmpty
        ? [
            for (final b in sortedBenefits)
              AboutJourneyBenefit(
                title: b.title,
                description: b.description,
                iconName: b.iconName,
              ),
          ]
        : _defaultBenefits;

    if (steps.isEmpty) return const SizedBox.shrink();

    return SectionWrapper(
      backgroundColor: _journeyBg,
      child: Column(
        children: [
          const _JourneyHeader(),
          const SizedBox(height: AppSpacing.xxxl),
          if (context.isMobile || context.isTablet)
            _MobileJourney(steps: steps)
          else
            _SerpentineJourney(steps: steps),
          const SizedBox(height: AppSpacing.xxxl),
          _BenefitsStrip(benefits: benefits),
        ],
      ),
    );
  }
}

class AboutJourneyBenefit {
  const AboutJourneyBenefit({
    required this.title,
    required this.description,
    required this.iconName,
  });

  final String title;
  final String description;
  final String iconName;
}

class _JourneyHeader extends StatelessWidget {
  const _JourneyHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 1,
              color: AppColors.gold.withValues(alpha: 0.75),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'HOW WE WORK',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.gold,
                    letterSpacing: 2.8,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              width: 40,
              height: 1,
              color: AppColors.gold.withValues(alpha: 0.75),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Our client journey',
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(
            fontSize: context.isMobile ? 34 : 44,
            fontWeight: FontWeight.w700,
            color: AppColors.white,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            'A transparent process from first inquiry to after-sales support.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondaryDark,
                  height: 1.55,
                ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        CustomPaint(
          size: const Size(72, 12),
          painter: _DiamondFlourishPainter(),
        ),
      ],
    );
  }
}

class _DiamondFlourishPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    final midY = size.height / 2;
    canvas.drawLine(Offset(0, midY), Offset(size.width * 0.38, midY), paint);
    canvas.drawLine(
      Offset(size.width * 0.62, midY),
      Offset(size.width, midY),
      paint,
    );
    final cx = size.width / 2;
    final path = Path()
      ..moveTo(cx, midY - 4)
      ..lineTo(cx + 4, midY)
      ..lineTo(cx, midY + 4)
      ..lineTo(cx - 4, midY)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Desktop S-curve grid. Step index `i` is always logical order (0 = first).
class _SerpentineJourney extends StatefulWidget {
  const _SerpentineJourney({required this.steps});

  final List<AboutProcessStep> steps;

  /// Visual top-left of each logical step in the serpentine grid.
  static List<Offset> layoutOrigins({
    required int count,
    required double cardW,
    required double cardH,
    required double gap,
    required double rowGap,
    int cols = 3,
  }) {
    final origins = <Offset>[];
    for (var i = 0; i < count; i++) {
      final row = i ~/ cols;
      final colInRow = i % cols;
      // Odd rows flow right→left so the path snakes continuously.
      final col = row.isOdd ? (cols - 1 - colInRow) : colInRow;
      origins.add(Offset(col * (cardW + gap), row * (cardH + rowGap)));
    }
    return origins;
  }

  @override
  State<_SerpentineJourney> createState() => _SerpentineJourneyState();
}

class _SerpentineJourneyState extends State<_SerpentineJourney>
    with SingleTickerProviderStateMixin {
  late final AnimationController _timeline;
  late final Animation<double> _reveal;
  late final Animation<double> _ambient;

  @override
  void initState() {
    super.initState();
    _timeline = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1850),
    );
    _reveal = CurvedAnimation(
      parent: _timeline,
      curve: const Interval(0.0, 0.78, curve: Curves.easeOutCubic),
    );
    _ambient = CurvedAnimation(parent: _timeline, curve: Curves.easeInOutSine);
    _timeline.forward();
  }

  @override
  void dispose() {
    _timeline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const cols = 3;
        const gap = 28.0;
        const rowGap = 52.0;
        const cardH = 168.0;
        const pathPadTop = 14.0;
        const pathPadEnd = 28.0;

        final maxW = constraints.maxWidth;
        final cardW = ((maxW - gap * (cols - 1) - pathPadEnd) / cols)
            .clamp(220.0, 360.0);
        final rows = ((widget.steps.length + cols - 1) / cols).floor();
        final gridW = cardW * cols + gap * (cols - 1);
        final gridH = pathPadTop + cardH * rows + rowGap * math.max(0, rows - 1);

        final origins = _SerpentineJourney.layoutOrigins(
          count: widget.steps.length,
          cardW: cardW,
          cardH: cardH,
          gap: gap,
          rowGap: rowGap,
        );

        // Peg anchors sit on the top edge of each card (path runs above).
        final pegs = [
          for (final o in origins)
            Offset(o.dx + cardW / 2, pathPadTop + o.dy),
        ];

        return AnimatedBuilder(
          animation: _timeline,
          builder: (context, _) => Center(
            child: SizedBox(
              width: gridW + pathPadEnd,
              height: gridH,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Subtle ambient glow drift for a cinematic feel.
                  Positioned(
                    left: 80 + 28 * _ambient.value,
                    top: -22,
                    child: _AmbientOrb(
                      size: 170,
                      color: AppColors.gold.withValues(alpha: 0.09),
                    ),
                  ),
                  Positioned(
                    right: 90 + 22 * (1 - _ambient.value),
                    bottom: 6,
                    child: _AmbientOrb(
                      size: 140,
                      color: AppColors.gold.withValues(alpha: 0.07),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _SerpentinePathPainter(
                        pegs: pegs,
                        progress: _reveal.value,
                        shimmer: _ambient.value,
                      ),
                    ),
                  ),
                  for (var i = 0; i < widget.steps.length; i++)
                    Positioned(
                      left: origins[i].dx,
                      top: pathPadTop + origins[i].dy,
                      width: cardW,
                      height: cardH,
                      child: _JourneyStepCard(
                        step: widget.steps[i],
                        number: i + 1,
                        delayMs: 100 + (i * 85).clamp(0, 760),
                        showTopPeg: true,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Continuous gold path through card-top pegs, with row U-turns and end arrow.
class _SerpentinePathPainter extends CustomPainter {
  _SerpentinePathPainter({
    required this.pegs,
    required this.progress,
    required this.shimmer,
  });

  final List<Offset> pegs;
  final double progress;
  final double shimmer;

  @override
  void paint(Canvas canvas, Size size) {
    if (pegs.length < 2) return;

    final path = Path()..moveTo(pegs.first.dx, pegs.first.dy);

    for (var i = 0; i < pegs.length - 1; i++) {
      final a = pegs[i];
      final b = pegs[i + 1];
      final sameRow = (a.dy - b.dy).abs() < 1;

      if (sameRow) {
        path.lineTo(b.dx, b.dy);
      } else {
        // Soft outward U-turn between rows.
        final midY = (a.dy + b.dy) / 2;
        final goingDownRight = b.dx >= a.dx;
        final bulge = goingDownRight ? 36.0 : -36.0;
        path.cubicTo(
          a.dx + bulge,
          midY,
          b.dx + bulge,
          midY,
          b.dx,
          b.dy,
        );
      }
    }

    // Small lead-out past the final peg.
    final last = pegs.last;
    final tip = Offset(last.dx + 22, last.dy);
    path.lineTo(tip.dx, tip.dy);

    final glow = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.32)
      ..strokeWidth = 5.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final line = Paint()
      ..shader = ui.Gradient.linear(
        pegs.first,
        tip,
        [
          AppColors.gold.withValues(alpha: 0.45),
          AppColors.gold,
          AppColors.gold.withValues(alpha: 0.55),
        ],
        const [0.0, 0.5, 1.0],
      )
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final metrics = path.computeMetrics().toList();
    final totalLength = metrics.fold<double>(0, (sum, m) => sum + m.length);
    final revealLength = totalLength * progress.clamp(0.0, 1.0);
    var drawn = 0.0;

    final visible = Path();
    for (final metric in metrics) {
      if (drawn >= revealLength) break;
      final remaining = revealLength - drawn;
      final take = remaining.clamp(0.0, metric.length);
      visible.addPath(metric.extractPath(0, take), Offset.zero);
      drawn += metric.length;
    }

    canvas.drawPath(visible, glow);
    canvas.drawPath(visible, line);

    if (progress > 0.35) {
      final pulse = (math.sin(shimmer * math.pi * 2) + 1) * 0.5;
      final flare = Paint()
        ..color = AppColors.gold.withValues(alpha: 0.28 + pulse * 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawPath(visible, flare);
    }

    final pegPaint = Paint()..color = AppColors.gold;
    final pegRing = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final visiblePegs = (pegs.length * progress).ceil().clamp(0, pegs.length);
    for (var i = 0; i < visiblePegs; i++) {
      final p = pegs[i];
      canvas.drawCircle(p, 5.5, pegRing);
      canvas.drawCircle(p, 3.2, pegPaint);
    }

    // Arrowhead at the end of the journey.
    final arrow = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - 10, tip.dy - 5)
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - 10, tip.dy + 5);
    canvas.drawPath(
      arrow,
      Paint()
        ..color = AppColors.gold
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SerpentinePathPainter oldDelegate) =>
      oldDelegate.pegs != pegs ||
      oldDelegate.progress != progress ||
      oldDelegate.shimmer != shimmer;
}

class _AmbientOrb extends StatelessWidget {
  const _AmbientOrb({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, Colors.transparent],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}

class _MobileJourney extends StatelessWidget {
  const _MobileJourney({required this.steps});

  final List<AboutProcessStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          _JourneyStepCard(
            step: steps[i],
            number: i + 1,
            delayMs: (i * 40).clamp(0, 360),
          ),
          if (i < steps.length - 1)
            SizedBox(
              height: 36,
              width: double.infinity,
              child: CustomPaint(painter: _MobileConnectorPainter()),
            ),
        ],
      ],
    );
  }
}

class _MobileConnectorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final paint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.85)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x, 4), Offset(x, size.height - 4), paint);
    final dot = Paint()..color = AppColors.gold;
    canvas.drawCircle(Offset(x, 4), 3.2, dot);
    canvas.drawCircle(Offset(x, size.height - 4), 3.2, dot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _JourneyStepCard extends StatefulWidget {
  const _JourneyStepCard({
    required this.step,
    required this.number,
    required this.delayMs,
    this.showTopPeg = false,
  });

  final AboutProcessStep step;
  final int number;
  final int delayMs;
  final bool showTopPeg;

  @override
  State<_JourneyStepCard> createState() => _JourneyStepCardState();
}

class _JourneyStepCardState extends State<_JourneyStepCard>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late final AnimationController _enter;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(vsync: this, duration: AppDurations.slow);
    _fade = CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic);
    Future<void>.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _enter.forward();
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    final n = widget.number.toString().padLeft(2, '0');

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(_fade),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedContainer(
            duration: AppDurations.fast,
            transformAlignment: Alignment.center,
            transform: Matrix4.translationValues(0, _hovered ? -5 : 0, 0),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
            decoration: BoxDecoration(
              color: _hovered ? _cardBgHover : _cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _hovered
                    ? AppColors.gold.withValues(alpha: 0.75)
                    : AppColors.gold.withValues(alpha: 0.28),
                width: _hovered ? 1.4 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(
                    alpha: _hovered ? 0.28 : 0.1,
                  ),
                  blurRadius: _hovered ? 28 : 16,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (widget.showTopPeg)
                  Positioned(
                    top: -24,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.gold,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.55),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final bounded = constraints.maxHeight.isFinite;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedScale(
                              scale: _hovered ? 1.08 : 1,
                              duration: AppDurations.fast,
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _iconWell,
                                  border: Border.all(
                                    color:
                                        AppColors.gold.withValues(alpha: 0.7),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.gold.withValues(
                                        alpha: _hovered ? 0.55 : 0.28,
                                      ),
                                      blurRadius: _hovered ? 18 : 12,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  AboutIcons.resolve(step.iconName),
                                  color: AppColors.gold,
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 26,
                                        height: 26,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.gold,
                                          ),
                                          color: AppColors.gold
                                              .withValues(alpha: 0.1),
                                        ),
                                        child: Text(
                                          n,
                                          style: const TextStyle(
                                            color: AppColors.gold,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          step.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                color: AppColors.gold,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    step.description,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppColors.textSecondaryDark,
                                          height: 1.4,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (bounded)
                          const Spacer()
                        else
                          const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.clock,
                                size: 12,
                                color: AppColors.gold.withValues(alpha: 0.95),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                step.timeline,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: AppColors.gold,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BenefitsStrip extends StatelessWidget {
  const _BenefitsStrip({required this.benefits});

  final List<AboutJourneyBenefit> benefits;

  @override
  Widget build(BuildContext context) {
    final stacked = context.screenWidth < 900;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: stacked ? AppSpacing.lg : AppSpacing.xl,
        vertical: AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: stacked
          ? Column(
              children: [
                for (var i = 0; i < benefits.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.lg),
                  _BenefitItem(benefit: benefits[i]),
                ],
              ],
            )
          : Row(
              children: [
                for (var i = 0; i < benefits.length; i++) ...[
                  if (i > 0)
                    Container(
                      width: 1,
                      height: 56,
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      color: AppColors.gold.withValues(alpha: 0.18),
                    ),
                  Expanded(child: _BenefitItem(benefit: benefits[i])),
                ],
              ],
            ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  const _BenefitItem({required this.benefit});

  final AboutJourneyBenefit benefit;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          AboutIcons.resolve(benefit.iconName),
          color: AppColors.gold,
          size: 22,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                benefit.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                benefit.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondaryDark,
                      height: 1.4,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
