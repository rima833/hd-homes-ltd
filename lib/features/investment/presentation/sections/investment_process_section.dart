import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/investment/data/models/investment_hub_content.dart';
import 'package:lucide_icons/lucide_icons.dart';

const _bg = Color(0xFF07080C);
const _card = Color(0xFF10131A);
const _gold = Color(0xFFD4AF37);
const _goldBright = Color(0xFFF0D078);
const _muted = Color(0xFFA8B0BC);

/// Cinematic "How investing works" process — pennant timeline + trust strip.
class InvestmentProcessSection extends StatefulWidget {
  const InvestmentProcessSection({
    super.key,
    required this.steps,
    this.overline = 'PROCESS',
    this.title = 'How investing works',
    this.subtitle = 'A structured journey from discovery to returns.',
  });

  final List<InvestmentProcessStep> steps;
  final String overline;
  final String title;
  final String subtitle;

  @override
  State<InvestmentProcessSection> createState() =>
      _InvestmentProcessSectionState();
}

class _InvestmentProcessSectionState extends State<InvestmentProcessSection>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _line;
  int _active = 0;
  Timer? _cycle;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _line = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reduce = MediaQuery.disableAnimationsOf(context);
      if (reduce) {
        _enter.value = 1;
        _line.value = 1;
        return;
      }
      _enter.forward();
      Future<void>.delayed(const Duration(milliseconds: 280), () {
        if (mounted) _line.forward();
      });
      _startCycle();
    });
  }

  void _startCycle() {
    _cycle?.cancel();
    if (widget.steps.length < 2) return;
    _cycle = Timer.periodic(const Duration(milliseconds: 3200), (_) {
      if (!mounted || _paused) return;
      setState(() => _active = (_active + 1) % widget.steps.length);
    });
  }

  @override
  void dispose() {
    _cycle?.cancel();
    _enter.dispose();
    _line.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mobile = context.isMobile;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1180
        ? 6
        : width >= 760
            ? 3
            : 1;

    return SectionWrapper(
      backgroundColor: _bg,
      animate: false,
      padding: EdgeInsets.symmetric(
        horizontal: context.pagePadding,
        vertical: mobile ? 56 : 88,
      ),
      child: AnimatedBuilder(
        animation: Listenable.merge([_enter, _line]),
        builder: (context, _) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              const Positioned.fill(
                child: IgnorePointer(child: _CinematicBackdrop()),
              ),
              Column(
                children: [
                  _Header(
                    overline: widget.overline,
                    title: widget.title,
                    subtitle: widget.subtitle,
                    progress: CurvedAnimation(
                      parent: _enter,
                      curve: const Interval(0, 0.45, curve: Curves.easeOutCubic),
                    ).value,
                    glow: 0.6,
                    reduce: reduce,
                  ),
                  SizedBox(height: mobile ? 36 : 52),
                  _Timeline(
                    steps: widget.steps,
                    columns: columns,
                    mobile: mobile,
                    active: _active,
                    enter: _enter.value,
                    line: _line.value,
                    glow: 0.6,
                    reduce: reduce,
                    onHover: (index, hovering) {
                      setState(() {
                        _paused = hovering;
                        if (hovering) _active = index;
                      });
                    },
                    onTap: (index) => setState(() {
                      _active = index;
                      _paused = true;
                    }),
                  ),
                  SizedBox(height: mobile ? 36 : 48),
                  Opacity(
                    opacity: CurvedAnimation(
                      parent: _enter,
                      curve: const Interval(0.55, 1, curve: Curves.easeOut),
                    ).value,
                    child: Transform.translate(
                      offset: Offset(
                        0,
                        (1 -
                                CurvedAnimation(
                                  parent: _enter,
                                  curve: const Interval(
                                    0.55,
                                    1,
                                    curve: Curves.easeOutCubic,
                                  ),
                                ).value) *
                            18,
                      ),
                      child: const _TrustBar(),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.overline,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.glow,
    required this.reduce,
  });

  final String overline;
  final String title;
  final String subtitle;
  final double progress;
  final double glow;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    final t = reduce ? 1.0 : progress;
    final pulse = 0.55 + (math.sin(glow * math.pi * 2) * 0.35);

    return Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(0, (1 - t) * 16),
        child: Column(
          children: [
            Text(
              overline.toUpperCase(),
              style: GoogleFonts.manrope(
                color: _gold,
                fontSize: 11,
                letterSpacing: 3.6,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'How '),
                  TextSpan(
                    text: 'investing',
                    style: GoogleFonts.playfairDisplay(
                      fontStyle: FontStyle.italic,
                      color: _goldBright,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(text: ' works'),
                ],
              ),
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                fontSize: context.isMobile ? 32 : 44,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: _muted,
                fontSize: context.isMobile ? 14 : 16,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: context.isMobile ? 240 : 420,
              height: 18,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: _gold.withValues(alpha: 0.22 * pulse),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 1.2,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          _goldBright,
                          Colors.transparent,
                        ],
                      ),
                    ),
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

class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.steps,
    required this.columns,
    required this.mobile,
    required this.active,
    required this.enter,
    required this.line,
    required this.glow,
    required this.reduce,
    required this.onHover,
    required this.onTap,
  });

  final List<InvestmentProcessStep> steps;
  final int columns;
  final bool mobile;
  final int active;
  final double enter;
  final double line;
  final double glow;
  final bool reduce;
  final void Function(int index, bool hovering) onHover;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    if (mobile) {
      return Column(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0)
              _VerticalConnector(
                filled: line >= (i / (steps.length - 1)).clamp(0.0, 1.0),
                glow: glow,
              ),
            _ProcessCard(
              step: steps[i],
              index: i,
              active: active == i,
              enter: _stagger(i, steps.length, enter),
              glow: glow,
              reduce: reduce,
              wide: true,
              onHover: (h) => onHover(i, h),
              onTap: () => onTap(i),
            ),
          ],
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = columns == 6 ? 14.0 : 18.0;
        final cardW =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: 28,
          children: [
            for (var i = 0; i < steps.length; i++)
              SizedBox(
                width: cardW,
                child: _ProcessCard(
                  step: steps[i],
                  index: i,
                  active: active == i,
                  enter: _stagger(i, steps.length, enter),
                  glow: glow,
                  reduce: reduce,
                  showConnector: columns == 6,
                  connectorProgress: line,
                  connectorIndex: i,
                  connectorCount: steps.length,
                  onHover: (h) => onHover(i, h),
                  onTap: () => onTap(i),
                ),
              ),
          ],
        );
      },
    );
  }

  double _stagger(int i, int total, double t) {
    if (reduce) return 1;
    final start = 0.12 + (i / total) * 0.55;
    final end = (start + 0.28).clamp(0.0, 1.0);
    if (t <= start) return 0;
    if (t >= end) return 1;
    return Curves.easeOutCubic.transform((t - start) / (end - start));
  }
}

class _VerticalConnector extends StatelessWidget {
  const _VerticalConnector({required this.filled, required this.glow});

  final bool filled;
  final double glow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: AnimatedContainer(
          duration: AppDurations.slow,
          width: 2,
          height: 22,
          decoration: BoxDecoration(
            color: filled
                ? _gold.withValues(alpha: 0.7 + glow * 0.15)
                : _gold.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
  }
}

class _ProcessCard extends StatefulWidget {
  const _ProcessCard({
    required this.step,
    required this.index,
    required this.active,
    required this.enter,
    required this.glow,
    required this.reduce,
    required this.onHover,
    required this.onTap,
    this.wide = false,
    this.showConnector = false,
    this.connectorProgress = 0,
    this.connectorIndex = 0,
    this.connectorCount = 1,
  });

  final InvestmentProcessStep step;
  final int index;
  final bool active;
  final double enter;
  final double glow;
  final bool reduce;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;
  final bool wide;
  final bool showConnector;
  final double connectorProgress;
  final int connectorIndex;
  final int connectorCount;

  @override
  State<_ProcessCard> createState() => _ProcessCardState();
}

class _ProcessCardState extends State<_ProcessCard> {
  bool _hovered = false;

  IconData get _icon {
    switch (widget.step.iconName) {
      case 'search':
        return LucideIcons.search;
      case 'users':
        return LucideIcons.users;
      case 'fileCheck':
        return LucideIcons.fileCheck;
      case 'shieldLock':
        return LucideIcons.shield;
      case 'lineChart':
        return LucideIcons.lineChart;
      case 'returns':
        return LucideIcons.refreshCw;
      default:
        return LucideIcons.circleDot;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.reduce ? 1.0 : widget.enter;
    final live = widget.active || _hovered;
    final lift = widget.reduce ? 0.0 : (live ? -8.0 : 0.0);

    return Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(0, (1 - t) * 28 + lift),
        child: MouseRegion(
          onEnter: (_) {
            setState(() => _hovered = true);
            widget.onHover(true);
          },
          onExit: (_) {
            setState(() => _hovered = false);
            widget.onHover(false);
          },
          child: GestureDetector(
            onTap: widget.onTap,
            child: Column(
              children: [
                SizedBox(
                  height: 28,
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (widget.showConnector)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _DashConnectorPainter(
                              progress: widget.connectorProgress,
                              index: widget.connectorIndex,
                              count: widget.connectorCount,
                            ),
                          ),
                        ),
                      _StepBadge(
                        number: widget.step.step,
                        active: live,
                        glow: widget.glow,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _PennantBody(
                  wide: widget.wide,
                  active: live,
                  glow: widget.glow,
                  icon: _icon,
                  title: widget.step.title,
                  description: widget.step.description,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({
    required this.number,
    required this.active,
    required this.glow,
  });

  final int number;
  final bool active;
  final double glow;

  @override
  Widget build(BuildContext context) {
    final pulse = 0.45 + math.sin(glow * math.pi * 2) * 0.25;
    return AnimatedContainer(
      duration: AppDurations.fast,
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF0C0E14),
        border: Border.all(
          color: active ? _goldBright : _gold,
          width: active ? 1.6 : 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: active ? 0.55 : 0.22 + pulse * 0.12),
            blurRadius: active ? 16 : 10,
          ),
        ],
      ),
      child: Text(
        '$number',
        style: GoogleFonts.manrope(
          color: _goldBright,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _PennantBody extends StatelessWidget {
  const _PennantBody({
    required this.wide,
    required this.active,
    required this.glow,
    required this.icon,
    required this.title,
    required this.description,
  });

  final bool wide;
  final bool active;
  final double glow;
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.fast,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: active ? 0.28 : 0.1),
            blurRadius: active ? 26 : 14,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipPath(
        clipper: const _PennantClipper(),
        child: CustomPaint(
          painter: _PennantBorderPainter(
            color: _gold.withValues(alpha: active ? 0.75 : 0.32),
          ),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              minHeight: wide ? 168 : 236,
            ),
            padding: EdgeInsets.fromLTRB(16, 22, 16, wide ? 36 : 42),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(
                    const Color(0xFF161A24),
                    const Color(0xFF1C1810),
                    active ? 0.7 : 0.15,
                  )!,
                  _card,
                ],
              ),
            ),
            child: Column(
              children: [
                Icon(icon, color: _goldBright, size: 26),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: _muted,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PennantClipper extends CustomClipper<Path> {
  const _PennantClipper();

  @override
  Path getClip(Size size) {
    const r = 16.0;
    const tip = 22.0;
    final path = Path()
      ..moveTo(r, 0)
      ..lineTo(size.width - r, 0)
      ..quadraticBezierTo(size.width, 0, size.width, r)
      ..lineTo(size.width, size.height - tip)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(0, size.height - tip)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _PennantBorderPainter extends CustomPainter {
  const _PennantBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = const _PennantClipper().getClip(size);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _PennantBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _DashConnectorPainter extends CustomPainter {
  const _DashConnectorPainter({
    required this.progress,
    required this.index,
    required this.count,
  });

  final double progress;
  final int index;
  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final paint = Paint()
      ..color = _gold.withValues(alpha: 0.55)
      ..strokeWidth = 1.15
      ..style = PaintingStyle.stroke;

    void dash(double x1, double x2) {
      const dashW = 5.0;
      const gap = 4.0;
      var x = x1;
      while (x < x2) {
        final end = math.min(x + dashW, x2);
        canvas.drawLine(Offset(x, y), Offset(end, y), paint);
        x += dashW + gap;
      }
    }

    final drawn = progress.clamp(0.0, 1.0);
    final mid = size.width / 2;
    if (index > 0) {
      final local = ((drawn * (count - 1)) - (index - 1)).clamp(0.0, 1.0);
      dash(0, mid * local);
    }
    if (index < count - 1) {
      final local = ((drawn * (count - 1)) - index).clamp(0.0, 1.0);
      dash(mid, mid + (size.width - mid) * local);
    }
  }

  @override
  bool shouldRepaint(covariant _DashConnectorPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _TrustBar extends StatelessWidget {
  const _TrustBar();

  static const items = [
    (
      LucideIcons.shieldCheck,
      'Secure & Regulated',
      'Your investments are protected through trusted partners and regulatory compliance.',
    ),
    (
      LucideIcons.target,
      'Transparent Process',
      'Every step is clear, structured, and tracked for your peace of mind.',
    ),
    (
      LucideIcons.headphones,
      'Expert Support',
      'Our dedicated team is with you at every stage of your investment journey.',
    ),
    (
      LucideIcons.gem,
      'Sustainable Value',
      'We build long-term value through quality projects and strategic partnerships.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final mobile = context.isMobile;
    Widget tile((IconData, String, String) item) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(item.$1, size: 18, color: _gold),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.$2,
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.$3,
                    style: GoogleFonts.inter(
                      color: _muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 8 : 6,
        vertical: mobile ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF10131A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gold.withValues(alpha: 0.22)),
      ),
      child: mobile
          ? Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) Divider(color: _gold.withValues(alpha: 0.12)),
                  tile(items[i]),
                ],
              ],
            )
          : Row(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Container(
                      width: 1,
                      height: 56,
                      color: _gold.withValues(alpha: 0.16),
                    ),
                  Expanded(child: tile(items[i])),
                ],
              ],
            ),
    );
  }
}

class _CinematicBackdrop extends StatelessWidget {
  const _CinematicBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BokehPainter());
  }
}

class _BokehPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
    glow.color = _gold.withValues(alpha: 0.05);
    canvas.drawCircle(Offset(size.width * 0.18, size.height * 0.2), 90, glow);
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.7), 110, glow);
    glow.color = _gold.withValues(alpha: 0.035);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.08), 70, glow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
