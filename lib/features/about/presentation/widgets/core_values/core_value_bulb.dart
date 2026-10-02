import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hdhomesproject/features/about/data/models/about_cms_content.dart';

/// Official HD Homes Core Values lightbulb with cinematic entrance + idle glow.
class CoreValueBulb extends StatefulWidget {
  const CoreValueBulb({
    super.key,
    required this.values,
    this.maxWidth = 720,
  });

  final List<AboutValueItem> values;
  final double maxWidth;

  static const assetPath = 'assets/images/illustrations/hd_core_values.png';

  /// Exact navy sampled from the brand artwork edges.
  static const artworkNavy = Color(0xFF050B17);

  @override
  State<CoreValueBulb> createState() => _CoreValueBulbState();
}

class _CoreValueBulbState extends State<CoreValueBulb>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _pulse;
  late final AnimationController _shimmer;
  late final AnimationController _float;

  bool _triggered = false;
  bool _frameCheckQueued = false;
  ScrollPosition? _scrollPosition;

  /// Vertical bands revealed top → bottom like stacking plates.
  static const _bands = <(double, double)>[
    (0.000, 0.145),
    (0.120, 0.335),
    (0.310, 0.495),
    (0.470, 0.650),
    (0.625, 0.790),
    (0.765, 0.920),
    (0.900, 1.000),
  ];

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800),
    );
    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _attachScrollWatch();
      // Never leave the section blank if scroll detection misses.
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        if (mounted && !_triggered) _playEntrance();
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-bind after route/shell changes without InheritedWidget dependency.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _attachScrollWatch();
    });
  }

  void _attachScrollWatch() {
    // Prefer ancestor lookup over Scrollable.maybeOf so we do not register
    // an InheritedWidget dependency (avoids _dependents.isEmpty on route change).
    final position =
        context.findAncestorStateOfType<ScrollableState>()?.position;
    if (position == null) {
      // No scroll ancestor (or not ready) — play immediately so art always shows.
      _playEntrance();
      return;
    }
    if (identical(position, _scrollPosition)) {
      _onScroll();
      return;
    }
    _scrollPosition?.removeListener(_onScroll);
    _scrollPosition = position;
    _scrollPosition?.addListener(_onScroll);
    _onScroll();
  }

  void _onScroll() {
    if (_triggered || !mounted) return;
    if (_isMostlyVisible()) _playEntrance();
  }

  bool _isMostlyVisible() {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return false;
    final size = MediaQuery.sizeOf(context);
    final topLeft = renderObject.localToGlobal(Offset.zero);
    final bottom = topLeft.dy + renderObject.size.height;
    // Trigger when any meaningful slice enters the viewport (not only 22%).
    final visibleTop = math.max(topLeft.dy, 0.0);
    final visibleBottom = math.min(bottom, size.height);
    final visible = (visibleBottom - visibleTop).clamp(0.0, double.infinity);
    final nearViewport =
        topLeft.dy < size.height * 0.92 && bottom > size.height * 0.08;
    return nearViewport || visible >= renderObject.size.height * 0.12;
  }

  void _playEntrance() {
    if (_triggered) return;
    _triggered = true;
    _enter.forward();
    _pulse.repeat(reverse: true);
    _shimmer.repeat();
    _float.repeat(reverse: true);
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_onScroll);
    _enter.dispose();
    _pulse.dispose();
    _shimmer.dispose();
    _float.dispose();
    super.dispose();
  }

  String get _semanticsLabel {
    final buffer = StringBuffer('Core Values. ');
    for (final value in widget.values.take(5)) {
      buffer.write('${value.title}. ');
      final subtitle = value.subtitle?.trim();
      if (subtitle != null && subtitle.isNotEmpty) {
        buffer.write('$subtitle. ');
      }
      buffer.write('${value.description} ');
    }
    return buffer.toString().trim();
  }

  double _bandProgress(int index, double enter) {
    final start = index * 0.095;
    final end = start + 0.32;
    return Curves.easeOutCubic.transform(
      ((enter - start) / (end - start)).clamp(0.0, 1.0),
    );
  }

  void _queueVisibilityCheck() {
    if (_triggered || _frameCheckQueued) return;
    _frameCheckQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _frameCheckQueued = false;
      _onScroll();
    });
  }

  @override
  Widget build(BuildContext context) {
    _queueVisibilityCheck();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.clamp(260.0, widget.maxWidth);

        return Semantics(
          image: true,
          label: _semanticsLabel,
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _enter,
              _pulse,
              _shimmer,
              _float,
            ]),
            builder: (context, _) {
              final enter = _enter.value;
              final glow = _triggered ? _pulse.value : 0.0;
              final shimmer = _triggered ? _shimmer.value : 0.0;
              final float = _triggered ? _float.value : 0.0;
              final overall = Curves.easeOutCubic.transform(
                (enter / 0.22).clamp(0.0, 1.0),
              );
              final breathe = 1.0 + (math.sin(float * math.pi) * 0.008);
              final lift = _triggered ? (1 - overall) * 36.0 : 0.0;
              // Before trigger: full opacity so the section is never a blank navy band.
              final fade = _triggered ? (0.15 + overall * 0.85) : 1.0;

              return Opacity(
                opacity: fade,
                child: Transform.translate(
                  offset: Offset(0, lift - (float - 0.5) * 4),
                  child: Transform.scale(
                    scale: _triggered
                        ? (0.90 + overall * 0.10) * breathe
                        : 1.0,
                    child: SizedBox(
                      width: width,
                      child: AspectRatio(
                        aspectRatio: 768 / 1024,
                        child: Stack(
                          fit: StackFit.expand,
                          clipBehavior: Clip.none,
                          children: [
                            // Always-visible base so the section is never blank
                            // if scroll-trigger is delayed or missed.
                            Positioned.fill(
                              child: Opacity(
                                opacity: _triggered ? 0.0 : 1.0,
                                child: Image.asset(
                                  CoreValueBulb.assetPath,
                                  fit: BoxFit.fill,
                                  filterQuality: FilterQuality.high,
                                  gaplessPlayback: true,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(
                                      child: Text(
                                        'Core Values',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 22,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    center: const Alignment(0, -0.08),
                                    radius: 0.78 + glow * 0.10,
                                    colors: [
                                      const Color(0xFFFFC933).withValues(
                                        alpha: (0.10 + glow * 0.16) * overall,
                                      ),
                                      const Color(0xFFFFC933).withValues(
                                        alpha: (0.04 + glow * 0.05) * overall,
                                      ),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.42, 1.0],
                                  ),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    center: Alignment.center,
                                    radius: 0.95,
                                    colors: [
                                      Colors.transparent,
                                      CoreValueBulb.artworkNavy.withValues(
                                        alpha: 0.35,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            for (var i = 0; i < _bands.length; i++)
                              _PlateReveal(
                                band: _bands[i],
                                progress: _bandProgress(i, enter),
                                child: Image.asset(
                                  CoreValueBulb.assetPath,
                                  fit: BoxFit.fill,
                                  filterQuality: FilterQuality.high,
                                  gaplessPlayback: true,
                                ),
                              ),
                            if (overall > 0.55)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: ClipRect(
                                    child: Opacity(
                                      opacity: (0.10 + glow * 0.08) *
                                          ((enter - 0.45) / 0.55)
                                              .clamp(0.0, 1.0),
                                      child: Transform.translate(
                                        offset: Offset(
                                          (shimmer * 2 - 1) * width * 0.65,
                                          0,
                                        ),
                                        child: Transform.rotate(
                                          angle: -0.42,
                                          child: Container(
                                            width: width * 0.18,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.centerLeft,
                                                end: Alignment.centerRight,
                                                colors: [
                                                  Colors.transparent,
                                                  Colors.white.withValues(
                                                    alpha: 0.45,
                                                  ),
                                                  Colors.transparent,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (overall > 0.7)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Opacity(
                                    opacity: (0.25 + glow * 0.35) *
                                        ((enter - 0.65) / 0.35)
                                            .clamp(0.0, 1.0),
                                    child: CustomPaint(
                                      painter: _RimGlowPainter(glow: glow),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _PlateReveal extends StatelessWidget {
  const _PlateReveal({
    required this.band,
    required this.progress,
    required this.child,
  });

  final (double, double) band;
  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (progress <= 0) return const SizedBox.shrink();

    final slide = (1 - progress) * 28.0;
    final scaleY = 0.88 + progress * 0.12;

    return Positioned.fill(
      child: Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, slide),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateX((1 - progress) * 0.18),
            child: Transform.scale(
              scaleY: scaleY,
              alignment: Alignment.center,
              child: ClipRect(
                clipper: _BandClipper(band.$1, band.$2),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BandClipper extends CustomClipper<Rect> {
  _BandClipper(this.y0, this.y1);

  final double y0;
  final double y1;

  @override
  Rect getClip(Size size) {
    final top = (size.height * y0) - 2;
    final bottom = (size.height * y1) + 2;
    return Rect.fromLTRB(0, top, size.width, bottom);
  }

  @override
  bool shouldReclip(covariant _BandClipper oldClipper) =>
      oldClipper.y0 != y0 || oldClipper.y1 != y1;
}

class _RimGlowPainter extends CustomPainter {
  _RimGlowPainter({required this.glow});

  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.48;
    final rx = size.width * 0.38;
    final ry = size.height * 0.36;

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 + glow * 2
        ..color = const Color(0xFFFFC933).withValues(alpha: 0.18 + glow * 0.12)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 + glow * 8),
    );

    final rayPaint = Paint()
      ..color = const Color(0xFFFFC933).withValues(alpha: 0.35 + glow * 0.25)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 + glow * 2);

    for (final side in [-1.0, 1.0]) {
      for (var i = 0; i < 3; i++) {
        final y = cy + (i - 1) * size.height * 0.055;
        final x0 = cx + side * (rx + 8);
        final len = size.width * (0.05 + glow * 0.015);
        canvas.drawLine(
          Offset(x0, y),
          Offset(x0 + side * len, y - len * 0.35),
          rayPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RimGlowPainter oldDelegate) =>
      oldDelegate.glow != glow;
}
