import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/website/components/web_safe_backdrop.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Shared display model for Awards & Certifications (home + about).
class AwardRecognitionItem {
  const AwardRecognitionItem({
    required this.title,
    required this.year,
    required this.issuer,
    this.description = '',
    this.iconName = 'award',
  });

  final String title;
  final String year;
  final String issuer;
  final String description;
  final String iconName;
}

/// Pixel recreation of the HD Homes Awards & Certifications mockup.
class AwardsRecognitionsSection extends StatelessWidget {
  const AwardsRecognitionsSection({
    super.key,
    required this.awards,
    this.title = 'Awards & certifications',
    this.subtitle =
        'Honouring our commitment to excellence, innovation, and client satisfaction.',
    this.showTrustBar = true,
    this.showTrophy = true,
  });

  static const trophyAsset =
      'assets/images/illustrations/hd_awards_trophy.png';

  final List<AwardRecognitionItem> awards;
  final String title;
  final String subtitle;
  final bool showTrustBar;
  final bool showTrophy;

  /// Matches brand artwork navy from the awards mockup.
  static const _bg = Color(0xFF050B17);
  static const _gold = Color(0xFFD4AF37);
  static const _goldBright = Color(0xFFE8C56A);
  static const _muted = Color(0xFF9A9A9A);
  static const _cardFill = Color(0xFF0A101C);

  @override
  Widget build(BuildContext context) {
    if (awards.isEmpty) return const SizedBox.shrink();

    return SectionWrapper(
      backgroundColor: _bg,
      padding: EdgeInsets.symmetric(
        horizontal: context.pagePadding,
        vertical: context.isMobile ? 52 : 80,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _ArchitectureWirePainter()),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.42, 0.05),
                    radius: 1.1,
                    colors: [
                      _gold.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Column(
            children: [
              _RecognitionHeader(title: title, subtitle: subtitle)
                  .animate()
                  .fadeIn(duration: 520.ms)
                  .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
              SizedBox(height: context.isMobile ? 40 : 52),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked =
                      constraints.maxWidth < 900 || !showTrophy;
                  final list = _AwardsList(awards: awards);
                  if (stacked) {
                    return Column(
                      children: [
                        list,
                        const SizedBox(height: 40),
                        const _TrophyPanel(),
                      ],
                    );
                  }
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 11, child: list),
                        const SizedBox(width: 36),
                        const Expanded(flex: 10, child: _TrophyPanel()),
                      ],
                    ),
                  );
                },
              ),
              if (showTrustBar) ...[
                SizedBox(height: context.isMobile ? 40 : 52),
                const _TrustBar()
                    .animate()
                    .fadeIn(delay: 260.ms, duration: 520.ms)
                    .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RecognitionHeader extends StatelessWidget {
  const _RecognitionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ornamentLine(flip: true),
            const SizedBox(width: 16),
            Text(
              'RECOGNITION',
              style: GoogleFonts.manrope(
                color: AwardsRecognitionsSection._gold,
                fontSize: 11,
                letterSpacing: 4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 16),
            _ornamentLine(flip: false),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(
            fontSize: context.isMobile ? 34 : 46,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: AwardsRecognitionsSection._muted,
              fontSize: 14.5,
              height: 1.55,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _ornamentLine({required bool flip}) {
    return SizedBox(
      width: 56,
      height: 10,
      child: CustomPaint(painter: _GoldOrnamentPainter(flip: flip)),
    );
  }
}

class _GoldOrnamentPainter extends CustomPainter {
  _GoldOrnamentPainter({required this.flip});

  final bool flip;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AwardsRecognitionsSection._gold
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;

    final y = size.height / 2;
    final start = flip ? size.width : 0.0;
    final end = flip ? 10.0 : size.width - 10.0;
    canvas.drawLine(Offset(start, y), Offset(end, y), paint);

    final cx = flip ? 5.0 : size.width - 5.0;
    final diamond = Path()
      ..moveTo(cx, y - 3.4)
      ..lineTo(cx + 3.4, y)
      ..lineTo(cx, y + 3.4)
      ..lineTo(cx - 3.4, y)
      ..close();
    canvas.drawPath(
      diamond,
      Paint()..color = AwardsRecognitionsSection._gold,
    );
  }

  @override
  bool shouldRepaint(covariant _GoldOrnamentPainter oldDelegate) =>
      oldDelegate.flip != flip;
}

class _AwardsList extends StatelessWidget {
  const _AwardsList({required this.awards});

  final List<AwardRecognitionItem> awards;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < awards.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          _AwardGlassCard(award: awards[i], index: i)
              .animate()
              .fadeIn(delay: (100 * i).ms, duration: 520.ms)
              .slideX(
                begin: -0.035,
                end: 0,
                delay: (100 * i).ms,
                duration: 520.ms,
                curve: Curves.easeOutCubic,
              ),
        ],
      ],
    );
  }
}

class _AwardGlassCard extends StatefulWidget {
  const _AwardGlassCard({required this.award, required this.index});

  final AwardRecognitionItem award;
  final int index;

  @override
  State<_AwardGlassCard> createState() => _AwardGlassCardState();
}

class _AwardGlassCardState extends State<_AwardGlassCard> {
  bool _hover = false;

  IconData get _icon {
    switch (widget.award.iconName.toLowerCase()) {
      case 'trophy':
        return LucideIcons.trophy;
      case 'star':
        return LucideIcons.star;
      case 'badge':
      case 'shield':
        return LucideIcons.shieldCheck;
      case 'medal':
        return LucideIcons.medal;
      default:
        return LucideIcons.award;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gold = AwardsRecognitionsSection._gold;
    final glow = _hover ? 0.28 : 0.14;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: gold.withValues(alpha: glow),
              blurRadius: _hover ? 28 : 18,
              spreadRadius: _hover ? 1 : 0,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: webSafeBackdropBlur(
            sigma: 10,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    gold.withValues(alpha: _hover ? 0.18 : 0.12),
                    AwardsRecognitionsSection._cardFill.withValues(alpha: 0.88),
                    const Color(0xFF05080F).withValues(alpha: 0.94),
                  ],
                  stops: const [0.0, 0.14, 1.0],
                ),
                border: Border.all(
                  color: gold.withValues(alpha: _hover ? 0.55 : 0.34),
                ),
              ),
              child: Stack(
                children: [
                  // Top-edge gold shimmer (mockup rim light)
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 0,
                    height: 1.5,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            gold.withValues(alpha: 0.85),
                            AwardsRecognitionsSection._goldBright,
                            gold.withValues(alpha: 0.85),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 20, 18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: gold.withValues(alpha: 0.06),
                            border: Border.all(
                              color: gold.withValues(alpha: 0.9),
                              width: 1.4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: gold.withValues(alpha: 0.4),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                          child: Icon(_icon, color: gold, size: 20),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 12,
                          height: 48,
                          child: CustomPaint(
                            painter: _TimelineDividerPainter(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.award.title,
                                style: GoogleFonts.manrope(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${widget.award.issuer} • ${widget.award.year}',
                                style: GoogleFonts.manrope(
                                  color: gold,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (widget.award.description
                                  .trim()
                                  .isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Text(
                                  widget.award.description,
                                  style: GoogleFonts.manrope(
                                    color: AwardsRecognitionsSection._muted,
                                    fontSize: 12.5,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineDividerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gold = AwardsRecognitionsSection._gold;
    final cx = size.width / 2;
    final line = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          gold.withValues(alpha: 0.1),
          gold.withValues(alpha: 0.9),
          gold.withValues(alpha: 0.1),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), line);
    canvas.drawCircle(
      Offset(cx, size.height / 2),
      2.6,
      Paint()..color = gold,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TrophyPanel extends StatelessWidget {
  const _TrophyPanel();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 420),
        child: AspectRatio(
          aspectRatio: 400 / 310,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 40,
                right: 40,
                bottom: 18,
                height: 70,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        AwardsRecognitionsSection._gold.withValues(alpha: 0.28),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Image.asset(
                  AwardsRecognitionsSection.trophyAsset,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (context, error, stackTrace) =>
                      const _TrophyFallback(),
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 140.ms, duration: 700.ms)
        .scale(
          begin: const Offset(0.94, 0.94),
          end: const Offset(1, 1),
          delay: 140.ms,
          duration: 700.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

class _TrophyFallback extends StatelessWidget {
  const _TrophyFallback();

  @override
  Widget build(BuildContext context) {
    final gold = AwardsRecognitionsSection._gold;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: gold.withValues(alpha: 0.45), width: 1.5),
            boxShadow: [
              BoxShadow(color: gold.withValues(alpha: 0.28), blurRadius: 48),
            ],
          ),
          child: Icon(LucideIcons.trophy, size: 72, color: gold),
        ),
        const SizedBox(height: 18),
        Text(
          'HD HOMES',
          style: GoogleFonts.manrope(
            color: gold,
            letterSpacing: 3.2,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            5,
            (_) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Icon(LucideIcons.star, size: 14, color: gold),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Building trust.\nDelivering value.\nCreating legacy.',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            color: Colors.white70,
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _TrustBar extends StatelessWidget {
  const _TrustBar();

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        LucideIcons.shieldCheck,
        'Trusted by Hundreds',
        'Homeowners, investors & partners',
      ),
      (
        LucideIcons.trophy,
        'Proven Track Record',
        'Excellence across every project',
      ),
      (
        LucideIcons.badgeCheck,
        'Committed to Standards',
        'Quality. Compliance. Integrity.',
      ),
    ];

    final gold = AwardsRecognitionsSection._gold;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.isMobile ? 16 : 28,
        vertical: 22,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF080E18),
        border: Border.all(color: gold.withValues(alpha: 0.34)),
        boxShadow: [
          BoxShadow(
            color: gold.withValues(alpha: 0.08),
            blurRadius: 22,
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 760;
          if (stacked) {
            return Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) ...[
                    const SizedBox(height: 14),
                    Divider(color: gold.withValues(alpha: 0.22), height: 1),
                    const SizedBox(height: 14),
                  ],
                  _TrustItem(
                    icon: items[i].$1,
                    title: items[i].$2,
                    subtitle: items[i].$3,
                  ),
                ],
              ],
            );
          }
          return Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0)
                  Container(
                    width: 1,
                    height: 48,
                    margin: const EdgeInsets.symmetric(horizontal: 18),
                    color: gold.withValues(alpha: 0.28),
                  ),
                Expanded(
                  child: _TrustItem(
                    icon: items[i].$1,
                    title: items[i].$2,
                    subtitle: items[i].$3,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TrustItem extends StatelessWidget {
  const _TrustItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final gold = AwardsRecognitionsSection._gold;
    return Row(
      children: [
        Icon(icon, color: gold, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.manrope(
                  color: AwardsRecognitionsSection._muted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Soft architectural skyline wireframe behind the awards composition.
class _ArchitectureWirePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AwardsRecognitionsSection._gold.withValues(alpha: 0.07)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Tall modern tower on the right (matches mockup wireframe placement).
    final originX = size.width * 0.58;
    final baseY = size.height * 0.78;
    final buildings = <(double, double, double)>[
      (originX, 48, size.height * 0.52),
      (originX + 58, 36, size.height * 0.38),
      (originX + 104, 42, size.height * 0.46),
      (originX + 156, 28, size.height * 0.30),
    ];

    for (final (x, w, h) in buildings) {
      final top = baseY - h;
      final path = Path()
        ..moveTo(x, baseY)
        ..lineTo(x, top + 16)
        ..lineTo(x + w * 0.35, top)
        ..lineTo(x + w, top + 20)
        ..lineTo(x + w, baseY);
      canvas.drawPath(path, paint);

      for (var wy = top + 24; wy < baseY - 10; wy += 16) {
        canvas.drawLine(Offset(x + 8, wy), Offset(x + w - 8, wy), paint);
      }
      for (var wx = x + 12; wx < x + w - 8; wx += 14) {
        canvas.drawLine(Offset(wx, top + 20), Offset(wx, baseY - 8), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
