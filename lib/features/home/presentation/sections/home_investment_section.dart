import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/home/data/models/home_cms_content.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

const _investBg = Color(0xFF0F1117);
const _cardBg = Color(0xFF151821);
const _cardBgHover = Color(0xFF1A1D26);
const _metricBg = Color(0xFF10131A);

/// Premium CMS-backed Investment Opportunities section (homepage).
class HomeInvestmentSection extends ConsumerStatefulWidget {
  const HomeInvestmentSection({
    super.key,
    this.fallbackItems = const [],
  });

  final List<HomeInvestmentItem> fallbackItems;

  @override
  ConsumerState<HomeInvestmentSection> createState() =>
      _HomeInvestmentSectionState();
}

class _HomeInvestmentSectionState extends ConsumerState<HomeInvestmentSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  List<CmsWebsiteInvestmentOpportunity> _fallbackAsCms() {
    return [
      for (var i = 0; i < widget.fallbackItems.length; i++)
        CmsWebsiteInvestmentOpportunity(
          id: 'fallback-$i',
          projectName: widget.fallbackItems[i].title,
          slug: 'opportunity-${i + 1}',
          shortDescription: widget.fallbackItems[i].type,
          fullDescription: widget.fallbackItems[i].type,
          investmentType: 'Real Estate Fund',
          typeLabel: widget.fallbackItems[i].type,
          roiMin: _parseRoi(widget.fallbackItems[i].roi).$1,
          roiMax: _parseRoi(widget.fallbackItems[i].roi).$2,
          duration: widget.fallbackItems[i].duration,
          riskLevel: widget.fallbackItems[i].risk,
          growthPotential: widget.fallbackItems[i].growth,
          ctaLink: widget.fallbackItems[i].route,
          isFeatured: i == 0,
          demandBadge: i == 1 ? 'High Demand' : null,
          sortOrder: (i + 1) * 10,
        ),
    ];
  }

  (double, double) _parseRoi(String raw) {
    final nums = RegExp(r'(\d+(?:\.\d+)?)')
        .allMatches(raw)
        .map((m) => double.tryParse(m.group(1)!) ?? 0)
        .toList();
    if (nums.isEmpty) return (0, 0);
    if (nums.length == 1) return (nums.first, nums.first);
    return (nums[0], nums[1]);
  }

  Future<void> _openOpportunity(CmsWebsiteInvestmentOpportunity item) async {
    final custom = item.ctaLink?.trim();
    if (custom != null &&
        custom.isNotEmpty &&
        custom != '#' &&
        (custom.startsWith('http://') || custom.startsWith('https://'))) {
      final uri = Uri.tryParse(custom);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    if (!mounted) return;
    context.go(item.detailPath);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(websiteInvestmentOpportunitiesRealtimeProvider);
    final cms =
        ref.watch(publishedWebsiteInvestmentOpportunitiesProvider).valueOrNull;
    final items = (cms != null && cms.isNotEmpty) ? cms : _fallbackAsCms();
    if (items.isEmpty) return const SizedBox.shrink();

    final mobile = context.screenWidth < 900;

    return SectionWrapper(
      backgroundColor: _investBg,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(
            child: IgnorePointer(child: _SkylineBackdrop()),
          ),
          Column(
            children: [
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: _enter,
                  curve: const Interval(0, 0.4, curve: Curves.easeOutCubic),
                ),
                child: const _SectionHeader(),
              ),
              const SizedBox(height: AppSpacing.xxl),
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.lg),
                FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _enter,
                    curve: Interval(
                      math.min(0.2 + i * 0.15, 0.7),
                      math.min(0.55 + i * 0.15, 1.0),
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.06),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _enter,
                        curve: Interval(
                          math.min(0.2 + i * 0.15, 0.7),
                          math.min(0.55 + i * 0.15, 1.0),
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                    ),
                    child: _OpportunityCard(
                      item: items[i],
                      mobile: mobile,
                      solidCta: items[i].isFeatured || i == 0,
                      onView: () => _openOpportunity(items[i]),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: _enter,
                  curve: const Interval(0.65, 1, curve: Curves.easeOutCubic),
                ),
                child: const _ValuePropsBar(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SkylineBackdrop extends StatelessWidget {
  const _SkylineBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _SkylinePainter());
  }
}

class _SkylinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final baseY = size.height * 0.78;
    final path = Path()..moveTo(size.width * 0.55, baseY);
    final towers = <(double, double)>[
      (0.58, 0.42),
      (0.64, 0.28),
      (0.70, 0.48),
      (0.76, 0.22),
      (0.82, 0.38),
      (0.88, 0.30),
      (0.94, 0.50),
    ];
    for (final t in towers) {
      final x = size.width * t.$1;
      final top = size.height * t.$2;
      path
        ..lineTo(x, baseY)
        ..lineTo(x, top)
        ..lineTo(x + size.width * 0.035, top)
        ..lineTo(x + size.width * 0.035, baseY);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
            color: _cardBg.withValues(alpha: 0.7),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.lineChart,
                size: 14,
                color: AppColors.gold.withValues(alpha: 0.95),
              ),
              const SizedBox(width: 8),
              Text(
                'INVEST WITH HD HOMES',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.gold,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Investment opportunities',
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(
            fontSize: context.isMobile ? 34 : 44,
            fontWeight: FontWeight.w700,
            color: AppColors.white,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Structured products designed for capital growth and income',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondaryDark,
              ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: const [
            _Pill(icon: LucideIcons.shieldCheck, label: 'Trusted Developer'),
            _Pill(icon: LucideIcons.building2, label: 'Asset Backed'),
            _Pill(icon: LucideIcons.lineChart, label: 'Transparent Returns'),
          ],
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
        color: _metricBg,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.gold),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _OpportunityCard extends StatefulWidget {
  const _OpportunityCard({
    required this.item,
    required this.mobile,
    required this.solidCta,
    required this.onView,
  });

  final CmsWebsiteInvestmentOpportunity item;
  final bool mobile;
  final bool solidCta;
  final VoidCallback onView;

  @override
  State<_OpportunityCard> createState() => _OpportunityCardState();
}

class _OpportunityCardState extends State<_OpportunityCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final progress = (item.progressPct / 100).clamp(0.0, 1.0);

    final media = _CoverMedia(item: item);
    final metrics = _MetricsRow(item: item, mobile: widget.mobile);
    final actions = widget.mobile
        ? _ActionColumn(
            item: item,
            solidCta: widget.solidCta,
            onView: widget.onView,
            progress: progress,
          )
        : const SizedBox.shrink();

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: EdgeInsets.all(widget.mobile ? 14 : 18),
        decoration: BoxDecoration(
          color: _hovered ? _cardBgHover : _cardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: _hovered ? 0.5 : 0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: _hovered ? 0.16 : 0.06),
              blurRadius: _hovered ? 28 : 16,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: widget.mobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  media,
                  const SizedBox(height: 14),
                  _TitleBlock(item: item),
                  const SizedBox(height: 12),
                  metrics,
                  const SizedBox(height: 14),
                  actions,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 220, child: media),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _TitleBlock(item: item),
                            const SizedBox(height: 14),
                            _ActionRow(
                              item: item,
                              solidCta: widget.solidCta,
                              onView: widget.onView,
                              progress: progress,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  metrics,
                ],
              ),
      ),
    );
  }
}

class _CoverMedia extends StatelessWidget {
  const _CoverMedia({required this.item});

  final CmsWebsiteInvestmentOpportunity item;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 11,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.coverImageUrl != null && item.coverImageUrl!.isNotEmpty)
                            MediaDeliveryImage(
                              url: item.coverImageUrl!,
                              fit: BoxFit.cover,
                              errorWidget: const _CoverFallback(),
                            )
            else
              const _CoverFallback(),
            if (item.isFeatured)
              Positioned(
                top: 10,
                right: 10,
                child: _BadgeChip(
                  icon: LucideIcons.crown,
                  label: item.featuredBadge,
                  gold: true,
                ),
              ),
            if ((item.demandBadge ?? '').trim().isNotEmpty)
              Positioned(
                top: 10,
                left: 10,
                child: _BadgeChip(
                  icon: LucideIcons.flame,
                  label: item.demandBadge!,
                  gold: false,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.gold.withValues(alpha: 0.25),
            const Color(0xFF1A2030),
          ],
        ),
      ),
      child: const Center(
        child: Icon(LucideIcons.building2, color: AppColors.gold, size: 36),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({
    required this.icon,
    required this.label,
    required this.gold,
  });

  final IconData icon;
  final String label;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: gold
            ? AppColors.gold
            : const Color(0xFF2A4A6A).withValues(alpha: 0.92),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: gold ? Colors.black : Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: gold ? Colors.black : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.item});

  final CmsWebsiteInvestmentOpportunity item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              item.projectName,
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.white,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.45),
                ),
              ),
              child: Text(
                item.investmentType,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          item.shortDescription,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondaryDark,
                height: 1.4,
              ),
        ),
      ],
    );
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({required this.item, required this.mobile});

  final CmsWebsiteInvestmentOpportunity item;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricData(LucideIcons.percent, 'Expected ROI', item.roiDisplay),
      _MetricData(LucideIcons.briefcase, 'Type', item.typeLabel),
      _MetricData(LucideIcons.clock, 'Duration', item.duration),
      _MetricData(LucideIcons.shield, 'Risk Level', item.riskLevel),
      _MetricData(LucideIcons.trendingUp, 'Growth Potential', item.growthPotential),
    ];

    if (mobile) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final tileW = (constraints.maxWidth - 8) / 2;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in metrics)
                SizedBox(
                  width: tileW,
                  child: _MetricTile(data: m),
                ),
            ],
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1100) {
          final tileW = (constraints.maxWidth - 8) / 2;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in metrics)
                SizedBox(
                  width: tileW,
                  child: _MetricTile(data: m),
                ),
            ],
          );
        }
        // Full-width row under the card header — equal columns, stable alignment.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < metrics.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: _MetricTile(data: metrics[i])),
            ],
          ],
        );
      },
    );
  }
}

class _MetricData {
  const _MetricData(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: _metricBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, size: 14, color: AppColors.gold),
          const SizedBox(height: 8),
          Text(
            data.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            data.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.item,
    required this.solidCta,
    required this.onView,
    required this.progress,
  });

  final CmsWebsiteInvestmentOpportunity item;
  final bool solidCta;
  final VoidCallback onView;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.fullDescription.isNotEmpty
              ? item.fullDescription
              : item.shortDescription,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondaryDark,
                height: 1.45,
              ),
        ),
        if (item.progressPct > 0) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Raised',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
              ),
              const Spacer(),
              Text(
                '${item.progressPct.toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.gold.withValues(alpha: 0.12),
              color: AppColors.gold,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: _CtaButton(
              label: item.ctaLabel,
              solid: solidCta,
              onPressed: onView,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Learn more and start investing.',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondaryDark,
              ),
        ),
      ],
    );
  }
}

class _ActionColumn extends StatelessWidget {
  const _ActionColumn({
    required this.item,
    required this.solidCta,
    required this.onView,
    required this.progress,
  });

  final CmsWebsiteInvestmentOpportunity item;
  final bool solidCta;
  final VoidCallback onView;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          item.fullDescription.isNotEmpty
              ? item.fullDescription
              : item.shortDescription,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondaryDark,
                height: 1.45,
              ),
        ),
        if (item.progressPct > 0) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Raised',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
              ),
              const Spacer(),
              Text(
                '${item.progressPct.toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.gold.withValues(alpha: 0.12),
              color: AppColors.gold,
            ),
          ),
        ],
        const SizedBox(height: 14),
        _CtaButton(
          label: item.ctaLabel,
          solid: solidCta,
          onPressed: onView,
        ),
        const SizedBox(height: 8),
        Text(
          'Learn more and start investing.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondaryDark,
              ),
        ),
      ],
    );
  }
}

class _CtaButton extends StatefulWidget {
  const _CtaButton({
    required this.label,
    required this.solid,
    required this.onPressed,
  });

  final String label;
  final bool solid;
  final VoidCallback onPressed;

  @override
  State<_CtaButton> createState() => _CtaButtonState();
}

class _CtaButtonState extends State<_CtaButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.02 : 1,
        duration: AppDurations.fast,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: widget.solid ? AppColors.gold : Colors.transparent,
                border: Border.all(color: AppColors.gold, width: 1.4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: widget.solid ? Colors.black : AppColors.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    LucideIcons.arrowRight,
                    size: 16,
                    color: widget.solid ? Colors.black : AppColors.gold,
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

class _ValuePropsBar extends StatelessWidget {
  const _ValuePropsBar();

  @override
  Widget build(BuildContext context) {
    final items = const [
      (LucideIcons.trendingUp, 'Attractive Returns', 'Competitive and consistent ROI'),
      (LucideIcons.shieldCheck, 'Secure Investments', 'Backed by real assets'),
      (LucideIcons.lineChart, 'Long-term Growth', 'Build wealth for the future'),
      (LucideIcons.users, 'Expert Advisory', 'Our team guides you every step'),
    ];

    if (context.isMobile) {
      return Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _ValueProp(
              icon: items[i].$1,
              title: items[i].$2,
              subtitle: items[i].$3,
            ),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            Container(
              width: 1,
              height: 52,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: AppColors.gold.withValues(alpha: 0.18),
            ),
          Expanded(
            child: _ValueProp(
              icon: items[i].$1,
              title: items[i].$2,
              subtitle: items[i].$3,
            ),
          ),
        ],
      ],
    );
  }
}

class _ValueProp extends StatelessWidget {
  const _ValueProp({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
            color: _metricBg,
          ),
          child: Icon(icon, size: 18, color: AppColors.gold),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
