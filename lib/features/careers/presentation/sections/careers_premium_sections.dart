import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/careers/data/models/careers_hub_content.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

/// Premium Careers hub matching the approved dark-luxury mockup.
class CareersPremiumSections extends StatelessWidget {
  const CareersPremiumSections({
    super.key,
    required this.cms,
    required this.rolesKey,
    required this.onApply,
    required this.onViewRoles,
    required this.onSubmitCv,
    this.includeHero = true,
    this.dense = false,
    this.onViewAll,
  });

  final CareersHubCms cms;
  final GlobalKey rolesKey;
  final ValueChanged<CareerJob> onApply;
  final VoidCallback onViewRoles;
  final VoidCallback onSubmitCv;
  final bool includeHero;
  /// Tighter vertical rhythm for embedding on About (and similar).
  final bool dense;
  final VoidCallback? onViewAll;

  static const bg = Color(0xFF0F1117);
  static const gold = Color(0xFFD4AF37);
  static const goldBright = Color(0xFFE8C56A);
  static const muted = Color(0xFF9A9A9A);
  static const card = Color(0xFF161A22);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (includeHero)
          _CareersHero(
            cms: cms,
            onViewRoles: onViewRoles,
            dense: dense,
          ),
        _CareersStatsBar(stats: cms.stats, dense: dense),
        _WhyJoinSection(benefits: cms.benefits, dense: dense),
        KeyedSubtree(
          key: rolesKey,
          child: _OpportunitiesSection(
            jobs: cms.jobs,
            onApply: onApply,
            primaryLabel: cms.ctaPrimaryLabel,
            secondaryLabel: cms.ctaSecondaryLabel,
            onViewAll: onViewAll ?? onViewRoles,
            onSubmitCv: onSubmitCv,
            dense: dense,
          ),
        ),
        _CvBanner(
          text: cms.cvBannerText,
          ctaLabel: cms.cvBannerCtaLabel,
          email: cms.cvEmail,
          dense: dense,
        ),
      ],
    );
  }
}

class _CareersHero extends StatelessWidget {
  const _CareersHero({
    required this.cms,
    required this.onViewRoles,
    this.dense = false,
  });

  final CareersHubCms cms;
  final VoidCallback onViewRoles;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final stacked = context.isMobile || context.isTablet;
    final vPad = dense
        ? (context.isMobile ? 28.0 : 40.0)
        : (context.isMobile ? 40.0 : 56.0);
    return SectionWrapper(
      backgroundColor: CareersPremiumSections.bg,
      compact: true,
      bandPadding: EdgeInsets.zero,
      padding: EdgeInsets.symmetric(
        horizontal: context.pagePadding,
        vertical: vPad,
      ),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroCopy(cms: cms),
                SizedBox(height: dense ? 20 : 28),
                _HeroOpenCard(
                  count: cms.openPositionsCount,
                  onViewRoles: onViewRoles,
                  imageUrl: cms.heroImageUrl,
                  dense: dense,
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 11, child: _HeroCopy(cms: cms)),
                SizedBox(width: dense ? 28 : 36),
                Expanded(
                  flex: 10,
                  child: _HeroOpenCard(
                    count: cms.openPositionsCount,
                    onViewRoles: onViewRoles,
                    imageUrl: cms.heroImageUrl,
                    dense: dense,
                  ),
                ),
              ],
            ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.cms});

  final CareersHubCms cms;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              cms.heroOverline,
              style: GoogleFonts.manrope(
                color: CareersPremiumSections.gold,
                fontSize: 11,
                letterSpacing: 3.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 1,
                color: CareersPremiumSections.gold.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${cms.heroTitleLine1}\n',
                style: GoogleFonts.playfairDisplay(
                  color: Colors.white,
                  fontSize: context.isMobile ? 36 : 52,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
              TextSpan(
                text: cms.heroTitleLine2,
                style: GoogleFonts.playfairDisplay(
                  color: CareersPremiumSections.gold,
                  fontSize: context.isMobile ? 36 : 52,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          cms.heroBody,
          style: GoogleFonts.manrope(
            color: CareersPremiumSections.muted,
            fontSize: 15,
            height: 1.6,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.04, end: 0);
  }
}

class _HeroOpenCard extends StatelessWidget {
  const _HeroOpenCard({
    required this.count,
    required this.onViewRoles,
    this.imageUrl,
    this.dense = false,
  });

  final int count;
  final VoidCallback onViewRoles;
  final String? imageUrl;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final gold = CareersPremiumSections.gold;
    final hasImage = imageUrl?.trim().isNotEmpty ?? false;
    return Container(
      height: dense ? 240 : 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: gold.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(color: gold.withValues(alpha: 0.14), blurRadius: 28),
        ],
        gradient: hasImage
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  CareersPremiumSections.card,
                  gold.withValues(alpha: 0.18),
                ],
              ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImage)
                        MediaDeliveryImage(
                          url: imageUrl!.trim(),
                          fit: BoxFit.cover,
                          errorWidget: const SizedBox.shrink(),
                        ),
          if (hasImage) Container(color: Colors.black.withValues(alpha: 0.5)),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: gold, width: 1.4),
                    ),
                    child: Icon(LucideIcons.users, color: gold, size: 22),
                  ),
                  const Spacer(),
                  Text(
                    '$count',
                    style: GoogleFonts.manrope(
                      color: gold,
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Open positions',
                    style: GoogleFonts.manrope(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: onViewRoles,
                    style: FilledButton.styleFrom(
                      backgroundColor: gold,
                      foregroundColor: CareersPremiumSections.bg,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    icon: const Icon(LucideIcons.arrowRight, size: 16),
                    label: const Text('View Careers'),
                    iconAlignment: IconAlignment.end,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 80.ms, duration: 560.ms);
  }
}

class _CareersStatsBar extends StatelessWidget {
  const _CareersStatsBar({required this.stats, this.dense = false});

  final List<CareerStatItem> stats;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();
    return SectionWrapper(
      backgroundColor: CareersPremiumSections.bg,
      compact: true,
      bandPadding: EdgeInsets.zero,
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        dense ? 4 : 8,
        context.pagePadding,
        dense
            ? (context.isMobile ? 20 : 28)
            : (context.isMobile ? 28 : 36),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cols = constraints.maxWidth < 700
              ? 2
              : math.min(4, stats.length);
          final gap = 14.0;
          final safeWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : 1200.0;
          final w = math.max(
            120.0,
            (safeWidth - gap * (cols - 1)) / math.max(cols, 1),
          );
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (var i = 0; i < stats.length; i++)
                SizedBox(
                  width: w,
                  child: _StatCard(stat: stats[i], delayMs: 60 * i),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat, required this.delayMs});

  final CareerStatItem stat;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    final gold = CareersPremiumSections.gold;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: CareersPremiumSections.card.withValues(alpha: 0.92),
        border: Border.all(color: gold.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(color: gold.withValues(alpha: 0.22), blurRadius: 22),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 2,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: LinearGradient(
                colors: [
                  gold.withValues(alpha: 0.15),
                  gold,
                  gold.withValues(alpha: 0.15),
                ],
              ),
              boxShadow: [
                BoxShadow(color: gold.withValues(alpha: 0.7), blurRadius: 12),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: gold.withValues(alpha: 0.8)),
                ),
                child: Icon(_icon(stat.iconName), color: gold, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stat.value,
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stat.label,
                      style: GoogleFonts.manrope(
                        color: gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: delayMs.ms, duration: 420.ms)
        .slideY(begin: 0.05, end: 0);
  }
}

class _WhyJoinSection extends StatelessWidget {
  const _WhyJoinSection({required this.benefits, this.dense = false});

  final List<CareerBenefitCard> benefits;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    if (benefits.isEmpty) return const SizedBox.shrink();
    return SectionWrapper(
      backgroundColor: CareersPremiumSections.bg,
      compact: true,
      bandPadding: EdgeInsets.zero,
      padding: EdgeInsets.symmetric(
        horizontal: context.pagePadding,
        vertical: dense
            ? (context.isMobile ? 24 : 32)
            : (context.isMobile ? 32 : 40),
      ),
      child: Column(
        children: [
          const _SectionHeading(title: 'Why Join HD Homes?'),
          SizedBox(height: dense ? 20 : 28),
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth < 720 ? 1 : 2;
              final gap = 14.0;
              final safeWidth = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : 1000.0;
              final w = math.max(
                220.0,
                (safeWidth - gap * (cols - 1)) / math.max(cols, 1),
              );
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (var i = 0; i < benefits.length; i++)
                    SizedBox(
                      width: w,
                      child: _BenefitCard(item: benefits[i], delayMs: 50 * i),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BenefitCard extends StatefulWidget {
  const _BenefitCard({required this.item, required this.delayMs});

  final CareerBenefitCard item;
  final int delayMs;

  @override
  State<_BenefitCard> createState() => _BenefitCardState();
}

class _BenefitCardState extends State<_BenefitCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final gold = CareersPremiumSections.gold;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: CareersPremiumSections.card.withValues(alpha: 0.92),
          border: Border.all(
            color: gold.withValues(alpha: _hover ? 0.55 : 0.28),
          ),
          boxShadow: [
            BoxShadow(
              color: gold.withValues(alpha: _hover ? 0.18 : 0.06),
              blurRadius: _hover ? 22 : 12,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: gold.withValues(alpha: 0.7)),
              ),
              child: Icon(_icon(widget.item.iconName), color: gold, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.title,
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.item.description,
                    style: GoogleFonts.manrope(
                      color: CareersPremiumSections.muted,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: widget.delayMs.ms, duration: 420.ms);
  }
}

class _OpportunitiesSection extends StatefulWidget {
  const _OpportunitiesSection({
    required this.jobs,
    required this.onApply,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onViewAll,
    required this.onSubmitCv,
    this.dense = false,
  });

  final List<CareerJob> jobs;
  final ValueChanged<CareerJob> onApply;
  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback onViewAll;
  final VoidCallback onSubmitCv;
  final bool dense;

  @override
  State<_OpportunitiesSection> createState() => _OpportunitiesSectionState();
}

class _OpportunitiesSectionState extends State<_OpportunitiesSection> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scroll(bool forward) {
    if (!_controller.hasClients) return;
    final delta = forward ? 320.0 : -320.0;
    _controller.animateTo(
      (_controller.offset + delta).clamp(
        0.0,
        _controller.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.jobs.isEmpty) return const SizedBox.shrink();
    final gold = CareersPremiumSections.gold;

    return SectionWrapper(
      backgroundColor: CareersPremiumSections.bg,
      compact: true,
      bandPadding: EdgeInsets.zero,
      padding: EdgeInsets.symmetric(
        horizontal: context.pagePadding,
        vertical: widget.dense
            ? (context.isMobile ? 24 : 32)
            : (context.isMobile ? 32 : 40),
      ),
      child: Column(
        children: [
          const _SectionHeading(title: 'Current Opportunities'),
          SizedBox(height: widget.dense ? 18 : 24),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: widget.dense ? 260 : 278,
                child: ListView.separated(
                  controller: _controller,
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.jobs.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 16),
                  itemBuilder: (context, i) {
                    return SizedBox(
                      width: context.isMobile ? 280 : 300,
                      child: _JobCard(
                        job: widget.jobs[i],
                        onApply: () => widget.onApply(widget.jobs[i]),
                      ),
                    );
                  },
                ),
              ),
              if (!context.isMobile) ...[
                Positioned(
                  left: 0,
                  child: _NavCircle(
                    icon: LucideIcons.chevronLeft,
                    onTap: () => _scroll(false),
                  ),
                ),
                Positioned(
                  right: 0,
                  child: _NavCircle(
                    icon: LucideIcons.chevronRight,
                    onTap: () => _scroll(true),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: widget.dense ? 18 : 24),
          Wrap(
            spacing: 14,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: widget.onViewAll,
                style: FilledButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: CareersPremiumSections.bg,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                icon: const Icon(LucideIcons.arrowRight, size: 16),
                label: Text(widget.primaryLabel),
                iconAlignment: IconAlignment.end,
              ),
              OutlinedButton.icon(
                onPressed: widget.onSubmitCv,
                style: OutlinedButton.styleFrom(
                  foregroundColor: gold,
                  side: BorderSide(color: gold.withValues(alpha: 0.7)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                icon: const Icon(LucideIcons.upload, size: 16),
                label: Text(widget.secondaryLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavCircle extends StatelessWidget {
  const _NavCircle({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CareersPremiumSections.gold,
      shape: const CircleBorder(),
      elevation: 8,
      shadowColor: CareersPremiumSections.gold.withValues(alpha: 0.45),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: CareersPremiumSections.bg, size: 18),
        ),
      ),
    );
  }
}

class _JobCard extends StatefulWidget {
  const _JobCard({required this.job, required this.onApply});

  final CareerJob job;
  final VoidCallback onApply;

  @override
  State<_JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<_JobCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final gold = CareersPremiumSections.gold;
    final job = widget.job;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: CareersPremiumSections.card,
          border: Border.all(
            color: gold.withValues(alpha: _hover ? 0.55 : 0.28),
          ),
          boxShadow: [
            BoxShadow(
              color: gold.withValues(alpha: _hover ? 0.28 : 0.14),
              blurRadius: _hover ? 28 : 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 2,
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                gradient: LinearGradient(
                  colors: [
                    gold.withValues(alpha: 0.1),
                    gold,
                    gold.withValues(alpha: 0.1),
                  ],
                ),
                boxShadow: [
                  BoxShadow(color: gold.withValues(alpha: 0.65), blurRadius: 10),
                ],
              ),
            ),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: gold.withValues(alpha: 0.55)),
                  ),
                  child: Icon(_icon(job.iconName), color: gold, size: 16),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: gold.withValues(alpha: 0.45)),
                  ),
                  child: Text(
                    job.employmentType,
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              job.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(LucideIcons.mapPin, size: 13, color: gold),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    job.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      color: CareersPremiumSections.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 12,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: Colors.white24,
                ),
                Icon(LucideIcons.building2, size: 13, color: gold),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    job.department,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      color: CareersPremiumSections.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Text(
                job.summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  color: CareersPremiumSections.muted,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ),
            TextButton(
              onPressed: widget.onApply,
              style: TextButton.styleFrom(
                foregroundColor: gold,
                padding: EdgeInsets.zero,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Apply Now'),
                  SizedBox(width: 6),
                  Icon(LucideIcons.arrowRight, size: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CvBanner extends StatelessWidget {
  const _CvBanner({
    required this.text,
    required this.ctaLabel,
    required this.email,
    this.dense = false,
  });

  final String text;
  final String ctaLabel;
  final String email;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final gold = CareersPremiumSections.gold;
    return SectionWrapper(
      backgroundColor: CareersPremiumSections.bg,
      compact: true,
      bandPadding: EdgeInsets.zero,
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        dense ? 4 : 8,
        context.pagePadding,
        dense
            ? (context.isMobile ? 28 : 36)
            : (context.isMobile ? 36 : 48),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _SkylinePainter()),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.isMobile ? 18 : 28,
              vertical: 20,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: CareersPremiumSections.card.withValues(alpha: 0.92),
              border: Border.all(color: gold.withValues(alpha: 0.3)),
            ),
            child: context.isMobile
                ? Column(
                    children: [
                      Icon(LucideIcons.mail, color: gold),
                      const SizedBox(height: 10),
                      Text(
                        text,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                      TextButton(
                        onPressed: () => launchUrl(Uri.parse('mailto:$email')),
                        child: Text(
                          ctaLabel,
                          style: GoogleFonts.manrope(
                            color: gold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: gold.withValues(alpha: 0.55)),
                        ),
                        child: Icon(LucideIcons.mail, color: gold, size: 18),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          text,
                          style: GoogleFonts.manrope(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            launchUrl(Uri.parse('mailto:$email')),
                        child: Row(
                          children: [
                            Text(
                              ctaLabel,
                              style: GoogleFonts.manrope(
                                color: gold,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(LucideIcons.arrowRight, color: gold, size: 16),
                          ],
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

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final gold = CareersPremiumSections.gold;
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: gold.withValues(alpha: 0.35))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              color: Colors.white,
              fontSize: context.isMobile ? 26 : 34,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: gold.withValues(alpha: 0.35))),
      ],
    );
  }
}

class _SkylinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    var x = size.width * 0.05;
    final base = size.height * 0.92;
    final rng = math.Random(3);
    while (x < size.width * 0.95) {
      final w = 18 + rng.nextDouble() * 28;
      final h = 20 + rng.nextDouble() * 50;
      canvas.drawRect(Rect.fromLTWH(x, base - h, w, h), paint);
      x += w + 8;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

IconData _icon(String name) {
  switch (name.toLowerCase()) {
    case 'users':
      return LucideIcons.users;
    case 'award':
      return LucideIcons.award;
    case 'mappin':
      return LucideIcons.mapPin;
    case 'trendingup':
      return LucideIcons.trendingUp;
    case 'graduationcap':
      return LucideIcons.graduationCap;
    case 'heart':
      return LucideIcons.heart;
    case 'clock':
      return LucideIcons.clock;
    case 'home':
      return LucideIcons.home;
    case 'wallet':
      return LucideIcons.wallet;
    case 'hardhat':
      return LucideIcons.hardHat;
    case 'pentool':
      return LucideIcons.penTool;
    case 'megaphone':
      return LucideIcons.megaphone;
    case 'calculator':
      return LucideIcons.calculator;
    case 'sparkles':
      return LucideIcons.sparkles;
    default:
      return LucideIcons.briefcase;
  }
}
