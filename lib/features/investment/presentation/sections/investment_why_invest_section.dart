import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/investment/data/models/investment_hub_content.dart';
import 'package:hdhomesproject/features/investment/presentation/widgets/investment_icons.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Premium "Why invest with HD Homes" section — mockup-aligned 3×2 cards + KPI bar.
class InvestmentWhyInvestSection extends StatelessWidget {
  const InvestmentWhyInvestSection({
    super.key,
    required this.pillars,
    required this.statistics,
    this.overline = 'WHY INVEST',
    this.title = 'Why invest with HD Homes',
    this.subtitle =
        'Institutional-grade developments with transparent investor protections.',
  });

  final List<InvestmentPillar> pillars;
  final List<InvestmentStatistic> statistics;
  final String overline;
  final String title;
  final String subtitle;

  static const _bg = Color(0xFF050608);
  static const _card = Color(0xFF0C0E14);
  static const _gold = Color(0xFFD4AF37);
  static const _goldBright = Color(0xFFE8C56A);
  static const _muted = Color(0xFFB0B6C0);

  @override
  Widget build(BuildContext context) {
    if (pillars.isEmpty && statistics.isEmpty) {
      return const SizedBox.shrink();
    }

    final width = MediaQuery.sizeOf(context).width;
    final wide = !context.isMobile && width >= 980;
    final crossCount = context.isMobile ? 1 : (context.isTablet ? 2 : 3);

    return SectionWrapper(
      backgroundColor: _bg,
      padding: EdgeInsets.symmetric(
        horizontal: context.pagePadding,
        vertical: context.isMobile ? 52 : 88,
      ),
      child: Column(
        children: [
          Text(
            overline,
            style: GoogleFonts.manrope(
              color: _gold,
              fontSize: 11,
              letterSpacing: 3.4,
              fontWeight: FontWeight.w700,
            ),
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 18),
          _TitleRich(title: title)
              .animate()
              .fadeIn(delay: 50.ms, duration: 450.ms)
              .slideY(begin: 0.04, end: 0),
          const SizedBox(height: 18),
          _GoldFlare(width: wide ? 460 : 280),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: _muted,
                fontSize: context.isMobile ? 14 : 16,
                height: 1.6,
                fontWeight: FontWeight.w400,
              ),
            ),
          ).animate().fadeIn(delay: 100.ms, duration: 450.ms),
          if (pillars.isNotEmpty) ...[
            SizedBox(height: context.isMobile ? 36 : 52),
            LayoutBuilder(
              builder: (context, constraints) {
                final gap = context.isMobile ? 14.0 : 18.0;
                final colW =
                    (constraints.maxWidth - gap * (crossCount - 1)) / crossCount;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (var i = 0; i < pillars.length; i++)
                      SizedBox(
                        width: colW,
                        child: _PillarCard(pillar: pillars[i], index: i),
                      ),
                  ],
                );
              },
            ),
          ],
          if (statistics.isNotEmpty) ...[
            SizedBox(height: context.isMobile ? 28 : 36),
            _StatsBar(statistics: statistics, wide: wide),
          ],
        ],
      ),
    );
  }
}

class _GoldFlare extends StatelessWidget {
  const _GoldFlare({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 18,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: InvestmentWhyInvestSection._gold.withValues(alpha: 0.45),
                  blurRadius: 22,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          Container(
            height: 1.2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  InvestmentWhyInvestSection._goldBright,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleRich extends StatelessWidget {
  const _TitleRich({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.playfairDisplay(
      color: Colors.white,
      fontSize: context.isMobile ? 30 : 42,
      fontWeight: FontWeight.w600,
      height: 1.15,
    );
    final parts = title.split('invest');
    if (parts.length < 2) {
      return Text(title, textAlign: TextAlign.center, style: style);
    }

    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: parts.first),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Color(0xFFC9A227),
                  Color(0xFFF0D078),
                  Color(0xFFD4AF37),
                ],
              ).createShader(bounds),
              child: Text(
                'invest',
                style: style.copyWith(color: Colors.white),
              ),
            ),
          ),
          TextSpan(text: parts.sublist(1).join('invest')),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _PillarCard extends StatefulWidget {
  const _PillarCard({required this.pillar, required this.index});

  final InvestmentPillar pillar;
  final int index;

  @override
  State<_PillarCard> createState() => _PillarCardState();
}

class _PillarCardState extends State<_PillarCard> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final gold = InvestmentWhyInvestSection._gold;
    final borderAlpha = _hover ? 0.95 : 0.55;
    final glowAlpha = _hover ? 0.28 : 0.12;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
        decoration: BoxDecoration(
          color: InvestmentWhyInvestSection._card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: gold.withValues(alpha: borderAlpha), width: 1),
          boxShadow: [
            BoxShadow(
              color: gold.withValues(alpha: glowAlpha),
              blurRadius: _hover ? 28 : 18,
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    InvestmentIcons.resolve(widget.pillar.iconName),
                    size: 26,
                    color: InvestmentWhyInvestSection._goldBright,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.pillar.title,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.pillar.description,
                    style: GoogleFonts.inter(
                      color: InvestmentWhyInvestSection._muted,
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            _CardVisual(
              pillar: widget.pillar,
              index: widget.index,
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (70 * widget.index).ms, duration: 480.ms)
        .slideY(begin: 0.05, end: 0);
  }
}

class _CardVisual extends StatelessWidget {
  const _CardVisual({required this.pillar, required this.index});

  final InvestmentPillar pillar;
  final int index;

  @override
  Widget build(BuildContext context) {
    final height = context.isMobile ? 128.0 : 148.0;
    final url = pillar.imageUrl;

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url != null && url.isNotEmpty)
            MediaDeliveryImage(
              url: url,
              fit: BoxFit.cover,
              placeholder: _FallbackVisual(iconName: pillar.iconName, index: index),
              errorWidget: _FallbackVisual(
                iconName: pillar.iconName,
                index: index,
              ),
            )
          else
            _FallbackVisual(iconName: pillar.iconName, index: index),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  InvestmentWhyInvestSection._card,
                  InvestmentWhyInvestSection._card.withValues(alpha: 0.55),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.45),
                ],
                stops: const [0, 0.18, 0.55, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FallbackVisual extends StatelessWidget {
  const _FallbackVisual({required this.iconName, required this.index});

  final String iconName;
  final int index;

  @override
  Widget build(BuildContext context) {
    return switch (iconName) {
      'trendingUp' => const _CitySkylineVisual(),
      'fileBarChart' => const _ChartVisual(),
      'shield' => const _VaultVisual(),
      'percent' => const _RoiTrailVisual(),
      'pieChart' => const _PortfolioVisual(),
      'headphones' => const _SupportVisual(),
      _ => _AbstractGoldVisual(seed: index),
    };
  }
}

class _CitySkylineVisual extends StatelessWidget {
  const _CitySkylineVisual();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF0A0D14)),
        CustomPaint(painter: _SkylinePainter()),
      ],
    );
  }
}

class _ChartVisual extends StatelessWidget {
  const _ChartVisual();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Color(0xFF0A0E16)),
        CustomPaint(painter: _LineChartPainter()),
      ],
    );
  }
}

class _VaultVisual extends StatelessWidget {
  const _VaultVisual();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                InvestmentWhyInvestSection._gold.withValues(alpha: 0.38),
                const Color(0xFF0A0E16),
              ],
            ),
          ),
        ),
        Icon(
          LucideIcons.lock,
          size: 52,
          color: InvestmentWhyInvestSection._gold.withValues(alpha: 0.8),
        ),
      ],
    );
  }
}

class _RoiTrailVisual extends StatelessWidget {
  const _RoiTrailVisual();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TrailPainter(),
      child: const ColoredBox(color: Color(0xFF07090E)),
    );
  }
}

class _PortfolioVisual extends StatelessWidget {
  const _PortfolioVisual();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Color(0xFF0A0E16)),
        CustomPaint(painter: _BuildingsPainter()),
      ],
    );
  }
}

class _SupportVisual extends StatelessWidget {
  const _SupportVisual();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF121820)),
        Center(
          child: Icon(
            LucideIcons.headphones,
            size: 64,
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }
}

class _AbstractGoldVisual extends StatelessWidget {
  const _AbstractGoldVisual({required this.seed});
  final int seed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF101820 + (seed % 6) * 0x010101),
            const Color(0xFF0A0E16),
          ],
        ),
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.statistics, required this.wide});

  final List<InvestmentStatistic> statistics;
  final bool wide;

  IconData _iconFor(InvestmentStatistic stat) {
    final label = stat.label.toLowerCase();
    if (label.contains('asset')) return LucideIcons.coins;
    if (label.contains('investor')) return LucideIcons.users;
    if (label.contains('product')) return LucideIcons.building2;
    if (label.contains('satisfaction')) return LucideIcons.star;
    if (label.contains('track') || label.contains('year')) {
      return LucideIcons.award;
    }
    return LucideIcons.barChart2;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: wide ? 28 : 16,
        vertical: wide ? 22 : 18,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0C12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: InvestmentWhyInvestSection._gold.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: InvestmentWhyInvestSection._gold.withValues(alpha: 0.1),
            blurRadius: 24,
          ),
        ],
      ),
      child: wide
          ? Row(
              children: [
                for (var i = 0; i < statistics.length; i++) ...[
                  if (i > 0)
                    Container(
                      width: 1,
                      height: 42,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  Expanded(
                    child: _StatCell(
                      stat: statistics[i],
                      icon: _iconFor(statistics[i]),
                    ),
                  ),
                ],
              ],
            )
          : Wrap(
              spacing: 12,
              runSpacing: 18,
              children: statistics
                  .map(
                    (s) => SizedBox(
                      width: (MediaQuery.sizeOf(context).width - 72) / 2,
                      child: _StatCell(stat: s, icon: _iconFor(s)),
                    ),
                  )
                  .toList(),
            ),
    ).animate().fadeIn(delay: 180.ms, duration: 500.ms);
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.stat, required this.icon});

  final InvestmentStatistic stat;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 22,
          color: InvestmentWhyInvestSection._goldBright,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${stat.value}${stat.suffix ?? ''}',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                stat.label,
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 11.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SkylinePainter extends CustomPainter {
  const _SkylinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()..color = const Color(0xFF1A2230);
    final glow = Paint()
      ..color = InvestmentWhyInvestSection._gold.withValues(alpha: 0.4);

    final buildings = [
      Rect.fromLTWH(size.width * 0.05, size.height * 0.35, 28, size.height * 0.65),
      Rect.fromLTWH(size.width * 0.18, size.height * 0.22, 36, size.height * 0.78),
      Rect.fromLTWH(size.width * 0.32, size.height * 0.4, 24, size.height * 0.6),
      Rect.fromLTWH(size.width * 0.48, size.height * 0.15, 42, size.height * 0.85),
      Rect.fromLTWH(size.width * 0.65, size.height * 0.3, 30, size.height * 0.7),
      Rect.fromLTWH(size.width * 0.78, size.height * 0.38, 34, size.height * 0.62),
    ];

    for (final r in buildings) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(2)),
        base,
      );
      for (var row = 0; row < 4; row++) {
        for (var col = 0; col < 3; col++) {
          if ((row + col).isEven) {
            canvas.drawRect(
              Rect.fromLTWH(r.left + 6 + col * 8, r.top + 8 + row * 10, 4, 5),
              glow,
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = InvestmentWhyInvestSection._goldBright
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          InvestmentWhyInvestSection._gold.withValues(alpha: 0.28),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);

    final path = Path()
      ..moveTo(0, size.height * 0.72)
      ..lineTo(size.width * 0.15, size.height * 0.58)
      ..lineTo(size.width * 0.32, size.height * 0.65)
      ..lineTo(size.width * 0.48, size.height * 0.42)
      ..lineTo(size.width * 0.62, size.height * 0.48)
      ..lineTo(size.width * 0.78, size.height * 0.28)
      ..lineTo(size.width, size.height * 0.35);

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fillPath, fill);
    canvas.drawPath(path, line);
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.28),
      4,
      Paint()..color = InvestmentWhyInvestSection._goldBright,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TrailPainter extends CustomPainter {
  const _TrailPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = InvestmentWhyInvestSection._gold.withValues(alpha: 0.7)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final path = Path()
      ..moveTo(size.width * 0.05, size.height * 0.8)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.15,
        size.width * 0.95,
        size.height * 0.55,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BuildingsPainter extends CustomPainter {
  const _BuildingsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final house = Paint()..color = const Color(0xFF243040);
    final tower = Paint()..color = const Color(0xFF1A2432);
    final window = Paint()
      ..color = InvestmentWhyInvestSection._gold.withValues(alpha: 0.5);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.08,
          size.height * 0.42,
          size.width * 0.38,
          size.height * 0.5,
        ),
        const Radius.circular(4),
      ),
      house,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.52,
          size.height * 0.18,
          size.width * 0.35,
          size.height * 0.74,
        ),
        const Radius.circular(3),
      ),
      tower,
    );

    for (var i = 0; i < 6; i++) {
      canvas.drawRect(
        Rect.fromLTWH(size.width * 0.58, size.height * 0.28 + i * 12, 8, 6),
        window,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
