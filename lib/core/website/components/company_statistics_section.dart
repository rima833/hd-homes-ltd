import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Shared display model for company statistics.
class CompanyStatItem {
  const CompanyStatItem({
    required this.value,
    required this.label,
    this.suffix = '',
    this.description = '',
    this.iconName = 'barChart',
    this.logoUrl,
    this.placement = 'orbit',
  });

  final int value;
  final String label;
  final String suffix;
  final String description;
  final String iconName;
  final String? logoUrl;
  final String placement;

  bool get isSummary => placement == 'summary';
}

/// Premium circular Company Statistics hub with HD logo center + summary row.
class CompanyStatisticsSection extends StatelessWidget {
  const CompanyStatisticsSection({
    super.key,
    required this.stats,
    this.title = 'Company statistics',
    this.overline = 'BY THE NUMBERS',
  });

  final List<CompanyStatItem> stats;
  final String title;
  final String overline;

  static const _bg = Color(0xFF0F1117);
  static const _gold = Color(0xFFD4AF37);
  static const _muted = Color(0xFF9A9A9A);
  static const _card = Color(0xFF161A22);

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();

    final orbit = stats.where((s) => !s.isSummary).toList();
    final summary = stats.where((s) => s.isSummary).toList();
    final orbitStats = orbit.isNotEmpty ? orbit : stats;

    return SectionWrapper(
      backgroundColor: _bg,
      padding: EdgeInsets.symmetric(
        horizontal: context.pagePadding,
        vertical: context.isMobile ? 52 : 80,
      ),
      child: Column(
        children: [
          Text(
            overline,
            style: GoogleFonts.manrope(
              color: _gold,
              fontSize: 11,
              letterSpacing: 3.6,
              fontWeight: FontWeight.w700,
            ),
          )
              .animate()
              .fadeIn(duration: 420.ms)
              .slideY(begin: 0.04, end: 0),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              color: Colors.white,
              fontSize: context.isMobile ? 30 : 40,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          )
              .animate()
              .fadeIn(delay: 60.ms, duration: 460.ms)
              .slideY(begin: 0.04, end: 0),
          SizedBox(height: context.isMobile ? 36 : 52),
          if (context.isMobile || context.isTablet)
            _StatsGrid(stats: orbitStats)
          else
            _OrbitHub(stats: orbitStats),
          if (summary.isNotEmpty) ...[
            SizedBox(height: context.isMobile ? 36 : 48),
            _SummaryRow(stats: summary),
          ],
        ],
      ),
    );
  }
}

class _OrbitHub extends StatefulWidget {
  const _OrbitHub({required this.stats});

  final List<CompanyStatItem> stats;

  @override
  State<_OrbitHub> createState() => _OrbitHubState();
}

class _OrbitHubState extends State<_OrbitHub>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePlay());
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  void _maybePlay() {
    if (_triggered || !mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      Future<void>.delayed(const Duration(milliseconds: 400), _maybePlay);
      return;
    }
    final size = MediaQuery.sizeOf(context);
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    if (top < size.height * 0.92 && bottom > size.height * 0.08) {
      _triggered = true;
      _enter.forward();
    } else {
      Future<void>.delayed(const Duration(milliseconds: 250), _maybePlay);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _enter,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_enter.value);
        return LayoutBuilder(
          builder: (context, constraints) {
            final size = math.min(720.0, constraints.maxWidth);
            final radius = size * 0.36;
            final cardW = 148.0;
            final cardH = 108.0;
            final n = widget.stats.length;

            return SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  CustomPaint(
                    size: Size(size, size),
                    painter: _OrbitRingsPainter(progress: t),
                  ),
                  for (var i = 0; i < n; i++)
                    Builder(
                      builder: (context) {
                        final angle = -math.pi / 2 + (2 * math.pi * i / n);
                        final dx = math.cos(angle) * radius;
                        final dy = math.sin(angle) * radius;
                        return Transform.translate(
                          offset: Offset(dx * t, dy * t),
                          child: Opacity(
                            opacity: t.clamp(0.0, 1.0),
                            child: SizedBox(
                              width: cardW,
                              height: cardH,
                              child: _OrbitCard(
                                stat: widget.stats[i],
                                animate: t > 0.55,
                                delayMs: 80 * i,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  _CenterLogo(scale: 0.86 + t * 0.14),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _OrbitRingsPainter extends CustomPainter {
  _OrbitRingsPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final gold = CompanyStatisticsSection._gold;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = gold.withValues(alpha: 0.18 * progress);
    canvas.drawCircle(c, size.width * 0.18, paint);
    canvas.drawCircle(c, size.width * 0.30, paint);
    canvas.drawCircle(
      c,
      size.width * 0.36,
      paint..color = gold.withValues(alpha: 0.28 * progress),
    );

    // Soft connector spokes
    final spoke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = gold.withValues(alpha: 0.12 * progress);
    for (var i = 0; i < 8; i++) {
      final a = -math.pi / 2 + (2 * math.pi * i / 8);
      canvas.drawLine(
        Offset(
          c.dx + math.cos(a) * size.width * 0.12,
          c.dy + math.sin(a) * size.width * 0.12,
        ),
        Offset(
          c.dx + math.cos(a) * size.width * 0.34,
          c.dy + math.sin(a) * size.width * 0.34,
        ),
        spoke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitRingsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _CenterLogo extends StatelessWidget {
  const _CenterLogo({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final gold = CompanyStatisticsSection._gold;
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 132,
        height: 132,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: CompanyStatisticsSection._card,
          border: Border.all(color: gold.withValues(alpha: 0.45), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: gold.withValues(alpha: 0.22),
              blurRadius: 36,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(22),
        child: Image.asset(
          AppTheme.logoAsset,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Text(
            'HD',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: gold,
              fontWeight: FontWeight.w800,
              fontSize: 28,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbitCard extends StatefulWidget {
  const _OrbitCard({
    required this.stat,
    required this.animate,
    required this.delayMs,
  });

  final CompanyStatItem stat;
  final bool animate;
  final int delayMs;

  @override
  State<_OrbitCard> createState() => _OrbitCardState();
}

class _OrbitCardState extends State<_OrbitCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final gold = CompanyStatisticsSection._gold;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: CompanyStatisticsSection._card.withValues(alpha: 0.92),
          border: Border.all(
            color: gold.withValues(alpha: _hover ? 0.55 : 0.28),
          ),
          boxShadow: [
            BoxShadow(
              color: gold.withValues(alpha: _hover ? 0.22 : 0.08),
              blurRadius: _hover ? 22 : 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StatIcon(stat: widget.stat, size: 16),
            const SizedBox(height: 6),
            _CountUp(
              value: widget.stat.value,
              suffix: widget.stat.suffix,
              play: widget.animate,
              delayMs: widget.delayMs,
              style: GoogleFonts.manrope(
                color: gold,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.stat.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final List<CompanyStatItem> stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth < 420 ? 2 : 3;
        final gap = 14.0;
        final w = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < stats.length; i++)
              SizedBox(
                width: w,
                child: _OrbitCard(
                  stat: stats[i],
                  animate: true,
                  delayMs: 70 * i,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.stats});

  final List<CompanyStatItem> stats;

  @override
  Widget build(BuildContext context) {
    final stacked = context.isMobile;
    if (stacked) {
      return Column(
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _SummaryCard(stat: stats[i], delayMs: 90 * i),
          ],
        ],
      );
    }
    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(child: _SummaryCard(stat: stats[i], delayMs: 90 * i)),
        ],
      ],
    );
  }
}

class _SummaryCard extends StatefulWidget {
  const _SummaryCard({required this.stat, required this.delayMs});

  final CompanyStatItem stat;
  final int delayMs;

  @override
  State<_SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<_SummaryCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final gold = CompanyStatisticsSection._gold;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              gold.withValues(alpha: _hover ? 0.16 : 0.1),
              CompanyStatisticsSection._card,
            ],
          ),
          border: Border.all(
            color: gold.withValues(alpha: _hover ? 0.5 : 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: gold.withValues(alpha: _hover ? 0.2 : 0.08),
              blurRadius: _hover ? 28 : 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatIcon(stat: widget.stat, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: _CountUp(
                    value: widget.stat.value,
                    suffix: widget.stat.suffix,
                    play: true,
                    delayMs: widget.delayMs,
                    style: GoogleFonts.manrope(
                      color: gold,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              widget.stat.label,
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (widget.stat.description.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                widget.stat.description,
                style: GoogleFonts.manrope(
                  color: CompanyStatisticsSection._muted,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ],
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: widget.delayMs.ms, duration: 480.ms)
        .slideY(begin: 0.06, end: 0);
  }
}

class _CountUp extends StatefulWidget {
  const _CountUp({
    required this.value,
    required this.suffix,
    required this.play,
    required this.delayMs,
    required this.style,
  });

  final int value;
  final String suffix;
  final bool play;
  final int delayMs;
  final TextStyle style;

  @override
  State<_CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<_CountUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _animation = Tween<double>(begin: 0, end: widget.value.toDouble()).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(covariant _CountUp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation =
          Tween<double>(begin: 0, end: widget.value.toDouble()).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      if (_started) {
        _controller.forward(from: 0);
      }
    }
    if (!_started && widget.play) _start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _start() {
    if (_started) return;
    _started = true;
    Future<void>.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.play && !_started) _start();
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final display = _animation.value.round();
        return Text('$display${widget.suffix}', style: widget.style);
      },
    );
  }
}

class _StatIcon extends StatelessWidget {
  const _StatIcon({required this.stat, required this.size});

  final CompanyStatItem stat;
  final double size;

  IconData get _icon {
    switch (stat.iconName.toLowerCase()) {
      case 'home':
        return LucideIcons.home;
      case 'users':
        return LucideIcons.users;
      case 'calendar':
        return LucideIcons.calendar;
      case 'building':
        return LucideIcons.building2;
      case 'trendingup':
        return LucideIcons.trendingUp;
      case 'hardhat':
        return LucideIcons.hardHat;
      case 'briefcase':
        return LucideIcons.briefcase;
      case 'handshake':
        return LucideIcons.heartHandshake;
      case 'award':
        return LucideIcons.award;
      case 'shield':
        return LucideIcons.shieldCheck;
      case 'heart':
        return LucideIcons.heart;
      default:
        return LucideIcons.barChart3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gold = CompanyStatisticsSection._gold;
    final url = stat.logoUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return SizedBox(
        width: size + 4,
        height: size + 4,
        child: MediaDeliveryImage(
          url: url,
          fit: BoxFit.contain,
          errorWidget: Icon(_icon, color: gold, size: size),
        ),
      );
    }
    return Icon(_icon, color: gold, size: size);
  }
}
