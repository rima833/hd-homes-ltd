import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/about/data/models/about_cms_content.dart';
import 'package:hdhomesproject/features/about/presentation/widgets/about_icons.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Why choose HD Homes + Our services — premium dark/gold mockup layout.
class AboutServicesSection extends StatelessWidget {
  const AboutServicesSection({
    super.key,
    required this.whyChoose,
    required this.services,
  });

  final List<AboutWhyChooseItem> whyChoose;
  final List<AboutServiceItem> services;

  @override
  Widget build(BuildContext context) {
    return _WhyChooseBand(items: whyChoose);
  }
}

// ─── Why choose ──────────────────────────────────────────────────────────────

class _WhyChooseBand extends StatelessWidget {
  const _WhyChooseBand({required this.items});

  final List<AboutWhyChooseItem> items;

  @override
  Widget build(BuildContext context) {
    final stacked = context.isMobile || context.isTablet;

    return SectionWrapper(
      backgroundColor: AppColors.deepBlack,
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _WhyChooseIntro(),
                const SizedBox(height: AppSpacing.xxl),
                _WhyChooseGrid(items: items),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(flex: 5, child: _WhyChooseIntro()),
                const SizedBox(width: AppSpacing.lg),
                const SizedBox(
                  width: 28,
                  height: 420,
                  child: CustomPaint(painter: _GoldArcPainter()),
                ),
                const SizedBox(width: AppSpacing.xl),
                Expanded(
                  flex: 12,
                  child: _WhyChooseGrid(items: items),
                ),
              ],
            ),
    );
  }
}

class _WhyChooseIntro extends StatelessWidget {
  const _WhyChooseIntro();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: CustomPaint(painter: _WireframePainter()),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WHY HD HOMES',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.gold,
                      letterSpacing: 2.8,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Why choose\nHD Homes',
                style: GoogleFonts.playfairDisplay(
                  fontSize: context.isMobile ? 34 : 44,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                width: 72,
                height: 2,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  gradient: AppColors.goldGradient,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'We build with integrity, deliver with excellence, '
                'and create lasting value for every client and investor.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondaryDark,
                      height: 1.6,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GoldArcPainter extends CustomPainter {
  const _GoldArcPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height <= 0 || size.width <= 0) return;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.gold.withValues(alpha: 0.05),
          AppColors.gold.withValues(alpha: 0.85),
          AppColors.gold.withValues(alpha: 0.05),
        ],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);

    final path = Path()
      ..moveTo(size.width * 0.7, 0)
      ..quadraticBezierTo(
        -size.width * 0.8,
        size.height * 0.5,
        size.width * 0.7,
        size.height,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WireframePainter extends CustomPainter {
  const _WireframePainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height <= 0 || size.width <= 0) return;
    final paint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final baseY = size.height * 0.72;
    canvas.drawLine(Offset(8, baseY), Offset(size.width * 0.9, baseY), paint);

    final heights = [0.35, 0.55, 0.42, 0.62, 0.48];
    var x = 16.0;
    for (final h in heights) {
      final top = baseY - size.height * h;
      final w = size.width * 0.12;
      canvas.drawRect(Rect.fromLTWH(x, top, w, baseY - top), paint);
      canvas.drawLine(Offset(x, top), Offset(x + w * 0.35, top - 12), paint);
      canvas.drawLine(Offset(x + w, top), Offset(x + w * 1.35, top - 12), paint);
      canvas.drawLine(
        Offset(x + w * 0.35, top - 12),
        Offset(x + w * 1.35, top - 12),
        paint,
      );
      x += w + 10;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WhyChooseGrid extends StatelessWidget {
  const _WhyChooseGrid({required this.items});

  final List<AboutWhyChooseItem> items;

  @override
  Widget build(BuildContext context) {
    final columns = context.isMobile
        ? 1
        : context.isTablet
            ? 2
            : 4;
    const gap = AppSpacing.md;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: gap,
        crossAxisSpacing: gap,
        childAspectRatio: context.isMobile ? 1.55 : 0.95,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return _WhyFeatureCard(
          title: item.title,
          description: item.description,
          icon: AboutIcons.resolve(item.iconName),
        );
      },
    );
  }
}

class _WhyFeatureCard extends StatefulWidget {
  const _WhyFeatureCard({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  State<_WhyFeatureCard> createState() => _WhyFeatureCardState();
}

class _WhyFeatureCardState extends State<_WhyFeatureCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        transformAlignment: Alignment.center,
        transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
        constraints: const BoxConstraints(minHeight: 168),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: _hovered
              ? AppColors.white.withValues(alpha: 0.08)
              : AppColors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: _hovered
                ? AppColors.gold.withValues(alpha: 0.55)
                : AppColors.white.withValues(alpha: 0.12),
          ),
          boxShadow: [
            if (_hovered)
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.7),
                ),
              ),
              child: Icon(widget.icon, size: 18, color: AppColors.gold),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondaryDark,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.bottomRight,
              child: Icon(
                LucideIcons.arrowRight,
                size: 16,
                color: AppColors.gold.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Our services ────────────────────────────────────────────────────────────

class _ServicesBand extends StatelessWidget {
  const _ServicesBand({required this.items});

  final List<AboutServiceItem> items;

  @override
  Widget build(BuildContext context) {
    return SectionWrapper(
      backgroundColor: AppColors.charcoal,
      child: Column(
        children: [
          const _ServicesHeader(),
          const SizedBox(height: AppSpacing.xxxl),
          if (context.isMobile || context.isTablet)
            _ServicesGrid(items: items)
          else
            _ServicesChevronRow(items: items),
        ],
      ),
    );
  }
}

class _ServicesHeader extends StatelessWidget {
  const _ServicesHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.diamond, size: 10, color: AppColors.gold),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'WHAT WE DO',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.gold,
                    letterSpacing: 2.8,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(LucideIcons.diamond, size: 10, color: AppColors.gold),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Our services',
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(
            fontSize: context.isMobile ? 34 : 44,
            fontWeight: FontWeight.w700,
            color: AppColors.white,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        CustomPaint(
          size: const Size(120, 14),
          painter: _FlourishPainter(),
        ),
        const SizedBox(height: AppSpacing.md),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            'End-to-end real estate solutions for buyers, investors, and partners.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondaryDark,
                  height: 1.55,
                ),
          ),
        ),
      ],
    );
  }
}

class _FlourishPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    final midY = size.height * 0.55;
    final path = Path()
      ..moveTo(0, midY)
      ..quadraticBezierTo(size.width * 0.25, midY - 8, size.width * 0.5, midY)
      ..quadraticBezierTo(size.width * 0.75, midY + 8, size.width, midY);
    canvas.drawPath(path, paint);
    canvas.drawCircle(Offset(size.width * 0.5, midY), 2.2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ServicesGrid extends StatelessWidget {
  const _ServicesGrid({required this.items});

  final List<AboutServiceItem> items;

  @override
  Widget build(BuildContext context) {
    final columns = context.isMobile ? 1 : 2;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        if (!maxW.isFinite || maxW <= 0) {
          return const SizedBox.shrink();
        }
        final gap = AppSpacing.md;
        final width =
            ((maxW - (columns - 1) * gap) / columns).clamp(120.0, maxW);
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < items.length; i++)
              SizedBox(
                width: width,
                height: 200,
                child: _ServiceGlassCard(
                  item: items[i],
                  index: i + 1,
                  chevron: false,
                  onTap: () => context.go(items[i].route),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ServicesChevronRow extends StatelessWidget {
  const _ServicesChevronRow({required this.items});

  final List<AboutServiceItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = items.length;
        if (count == 0) return const SizedBox.shrink();

        const overlap = 18.0;
        const height = 220.0;
        final available = constraints.maxWidth;
        if (!available.isFinite || available <= 0) {
          return const SizedBox.shrink();
        }

        final cardWidth =
            ((available + overlap * (count - 1)) / count).clamp(148.0, 200.0);
        final totalWidth = cardWidth * count - overlap * (count - 1);
        final step = cardWidth - overlap;

        final flow = SizedBox(
          width: totalWidth,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < count; i++)
                Positioned(
                  left: i * step,
                  top: 0,
                  width: cardWidth,
                  height: height,
                  child: _ServiceGlassCard(
                    item: items[i],
                    index: i + 1,
                    chevron: true,
                    onTap: () => context.go(items[i].route),
                  ),
                ),
            ],
          ),
        );

        if (totalWidth > available) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: flow,
          );
        }

        return Center(child: flow);
      },
    );
  }
}

class _ServiceGlassCard extends StatefulWidget {
  const _ServiceGlassCard({
    required this.item,
    required this.index,
    required this.chevron,
    required this.onTap,
  });

  final AboutServiceItem item;
  final int index;
  final bool chevron;
  final VoidCallback onTap;

  @override
  State<_ServiceGlassCard> createState() => _ServiceGlassCardState();
}

class _ServiceGlassCardState extends State<_ServiceGlassCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: EdgeInsets.fromLTRB(
        widget.chevron ? AppSpacing.xl : AppSpacing.lg,
        AppSpacing.lg,
        widget.chevron ? AppSpacing.xxl : AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Stack(
        children: [
          Positioned(
            right: widget.chevron ? 4 : 0,
            bottom: 0,
            child: Text(
              widget.index.toString().padLeft(2, '0'),
              style: GoogleFonts.playfairDisplay(
                fontSize: 42,
                fontWeight: FontWeight.w700,
                color: AppColors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                AboutIcons.resolve(widget.item.iconName),
                color: AppColors.gold,
                size: 22,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                widget.item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: Text(
                  widget.item.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondaryDark,
                        height: 1.4,
                      ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Learn more →',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ],
      ),
    );

    final card = widget.chevron
        ? ClipPath(
            clipper: const _ChevronClipper(),
            child: ColoredBox(
              color: _hovered ? AppColors.darkElevated : AppColors.darkSurface,
              child: body,
            ),
          )
        : AnimatedContainer(
            duration: AppDurations.fast,
            decoration: BoxDecoration(
              color: _hovered ? AppColors.darkElevated : AppColors.darkSurface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: _hovered
                    ? AppColors.gold.withValues(alpha: 0.45)
                    : AppColors.white.withValues(alpha: 0.1),
              ),
            ),
            child: body,
          );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        transformAlignment: Alignment.center,
        transform: Matrix4.translationValues(0, _hovered ? -3 : 0, 0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius:
                widget.chevron ? null : BorderRadius.circular(AppRadius.lg),
            child: card,
          ),
        ),
      ),
    );
  }
}

class _ChevronClipper extends CustomClipper<Path> {
  const _ChevronClipper();

  @override
  Path getClip(Size size) {
    const notch = 22.0;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width - notch, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width - notch, size.height)
      ..lineTo(0, size.height)
      ..lineTo(notch, size.height / 2)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
