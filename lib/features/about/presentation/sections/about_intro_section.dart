import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/about/data/models/about_cms_content.dart';
import 'package:hdhomesproject/features/about/presentation/widgets/about_icons.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Company overview (premium Who We Are mockup) — shown on the Home page.
class AboutIntroSection extends StatelessWidget {
  const AboutIntroSection({super.key, required this.content});

  final AboutIntroContent content;

  @override
  Widget build(BuildContext context) {
    return SectionWrapper(
      backgroundColor: const Color(0xFF080B12),
      padding: EdgeInsets.symmetric(
        horizontal: context.pagePadding,
        vertical: AppSpacing.section,
      ),
      child: context.screenWidth < 900
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IntroCopy(content: content),
                const SizedBox(height: AppSpacing.xxl),
                _IntroShowcase(content: content),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 11, child: _IntroCopy(content: content)),
                const SizedBox(width: AppSpacing.xxl),
                Expanded(flex: 10, child: _IntroShowcase(content: content)),
              ],
            ),
    );
  }
}

class _IntroCopy extends StatelessWidget {
  const _IntroCopy({required this.content});

  final AboutIntroContent content;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WHO WE ARE',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.gold,
                letterSpacing: 2.4,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Company overview',
          style: GoogleFonts.playfairDisplay(
            fontSize: context.isMobile ? 34 : 44,
            fontWeight: FontWeight.w700,
            color: AppColors.white,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: 96,
          height: 3,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            gradient: LinearGradient(
              colors: [
                AppColors.gold.withValues(alpha: 0.2),
                AppColors.gold,
                AppColors.gold.withValues(alpha: 0.2),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.45),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          content.description,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.white.withValues(alpha: 0.9),
                height: 1.65,
              ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _YearsBadge(years: content.yearsOperating),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Specializations',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final tag in content.specializations)
              _GoldOutlineTag(
                icon: AboutIcons.resolve(tag.iconName),
                label: tag.label,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Geographic presence',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final city in content.geographicPresence)
              _GoldOutlineTag(
                icon: LucideIcons.mapPin,
                label: city,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Philosophy',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        _PhilosophyCard(text: content.philosophy),
      ],
    );
  }
}

class _YearsBadge extends StatelessWidget {
  const _YearsBadge({required this.years});

  final int years;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.7)),
        color: AppColors.gold.withValues(alpha: 0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.calendar, size: 16, color: AppColors.gold),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              '$years+ years of operation',
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoldOutlineTag extends StatelessWidget {
  const _GoldOutlineTag({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
        color: AppColors.white.withValues(alpha: 0.02),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.gold),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhilosophyCard extends StatelessWidget {
  const _PhilosophyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.deepBlack.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            LucideIcons.quote,
            size: 28,
            color: AppColors.gold.withValues(alpha: 0.9),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            text,
            style: GoogleFonts.playfairDisplay(
              fontSize: context.isMobile ? 18 : 20,
              fontStyle: FontStyle.italic,
              height: 1.5,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroShowcase extends StatelessWidget {
  const _IntroShowcase({required this.content});

  final AboutIntroContent content;

  @override
  Widget build(BuildContext context) {
    final imageUrl = content.imageUrl?.trim();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
        color: AppColors.charcoal.withValues(alpha: 0.55),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.1),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 11,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl != null && imageUrl.isNotEmpty)
                  MediaDeliveryImage(
                    url: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: const ColoredBox(color: AppColors.deepBlack),
                    errorWidget: const ColoredBox(color: AppColors.deepBlack),
                  )
                else
                  const ColoredBox(color: AppColors.deepBlack),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.deepBlack.withValues(alpha: 0.15),
                        AppColors.deepBlack.withValues(alpha: 0.72),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: _DotGrid(),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    width: 54,
                    height: 54,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.gold, width: 1.4),
                      color: AppColors.deepBlack.withValues(alpha: 0.45),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.35),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      AppTheme.logoAsset,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: -1,
                  child: CustomPaint(
                    size: const Size(double.infinity, 36),
                    painter: _GoldSwooshPainter(),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              children: [
                for (var i = 0; i < content.achievements.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.sm),
                  _StatRow(stat: content.achievements[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DotGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 40,
      child: Wrap(
        spacing: 5,
        runSpacing: 5,
        children: List.generate(
          12,
          (_) => Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.gold.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoldSwooshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.gold.withValues(alpha: 0.05),
          AppColors.gold,
          AppColors.gold.withValues(alpha: 0.15),
        ],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6);

    final path = Path()
      ..moveTo(0, size.height * 0.75)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.1,
        size.width * 0.7,
        size.height * 0.55,
      )
      ..quadraticBezierTo(
        size.width * 0.88,
        size.height * 0.85,
        size.width,
        size.height * 0.4,
      );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.stat});

  final AboutIntroStat stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.deepBlack.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.gold.withValues(alpha: 0.12),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
            ),
            child: Icon(
              AboutIcons.resolve(stat.iconName),
              size: 18,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: stat.value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  if (stat.label.trim().isNotEmpty)
                    TextSpan(
                      text: ' ${stat.label}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
