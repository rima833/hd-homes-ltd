import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/website/components/web_safe_backdrop.dart';
import 'package:hdhomesproject/features/home/data/models/home_cms_content.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

/// The HD Homes Experience — mockup-accurate premium Why Choose band.
class HomeWhyChooseSection extends StatelessWidget {
  const HomeWhyChooseSection({
    super.key,
    required this.items,
    required this.stats,
    required this.about,
    required this.executiveWelcome,
  });

  final List<HomeWhyChooseItem> items;
  final List<HomeStatItem> stats;
  final HomeAboutContent about;
  final HomeExecutiveWelcome executiveWelcome;

  static const bg = Color(0xFF050505);
  static const panel = Color(0xFF101010);
  static const gold = Color(0xFFD4AF37);
  static const goldBright = Color(0xFFE8C547);
  static const muted = Color(0xFFA0A0A0);

  static const _heroFallback =
      '';
  static const _buildImage =
      '';
  static const _investImage =
      '';
  static const _liveImage =
      '';

  @override
  Widget build(BuildContext context) {
    final pillars = _pillarsFrom(items);
    final displayStats = stats.take(4).toList();
    final quote = executiveWelcome.message.trim();
    final heroImage = (about.backgroundImageUrl?.trim().isNotEmpty ?? false)
        ? about.backgroundImageUrl!.trim()
        : _heroFallback;
    final stacked = context.isMobile || context.screenWidth < 980;

    return SectionWrapper(
      backgroundColor: bg,
      padding: EdgeInsets.symmetric(
        horizontal: context.pagePadding,
        vertical: context.isMobile ? 40 : 64,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -60,
            top: -20,
            child: IgnorePointer(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      gold.withValues(alpha: 0.14),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: -40,
            bottom: 120,
            child: IgnorePointer(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      gold.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ExperienceHero(
                stacked: stacked,
                story: about.story,
                heroImageUrl: heroImage,
                quote: quote,
                showQuote: quote.isNotEmpty,
                executiveName: executiveWelcome.name,
                executiveTitle: executiveWelcome.title,
                onExplore: () => context.go(RoutePaths.estates),
                onWatchStory: () => _watchStory(context),
              ),
              SizedBox(height: stacked ? 36 : 52),
              _PillarsRow(pillars: pillars, stacked: stacked),
              if (displayStats.isNotEmpty) ...[
                SizedBox(height: stacked ? 28 : 40),
                _StatsBar(stats: displayStats, stacked: stacked),
              ],
              SizedBox(height: stacked ? 28 : 40),
              _BottomCtaBar(stacked: stacked),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _watchStory(BuildContext context) async {
    final url = executiveWelcome.videoUrl?.trim();
    if (url != null && url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    if (context.mounted) context.go(RoutePaths.about);
  }

  List<_PillarData> _pillarsFrom(List<HomeWhyChooseItem> items) {
    String titleAt(int index, String fallback) {
      if (index >= 0 && index < items.length) {
        final title = items[index].title.trim();
        if (title.isNotEmpty) return title;
      }
      return fallback;
    }

    String descriptionAt(int index, String fallback) {
      if (index >= 0 && index < items.length) {
        final description = items[index].description.trim();
        if (description.isNotEmpty) return description;
      }
      return fallback;
    }

    return [
      _PillarData(
        number: '01',
        title: titleAt(0, 'Build with Confidence'),
        description: descriptionAt(
          0,
          'Premium materials. World-class craftsmanship. Rigorous quality '
          'control. Built to stand the test of time.',
        ),
        icon: LucideIcons.hardHat,
        imageUrl: _buildImage,
        route: RoutePaths.about,
      ),
      _PillarData(
        number: '02',
        title: titleAt(1, 'Invest with Confidence'),
        description: descriptionAt(
          1,
          'High-growth locations. Strong ROI. Flexible payment plans '
          'designed for smart investors.',
        ),
        icon: LucideIcons.trendingUp,
        imageUrl: _investImage,
        route: RoutePaths.investment,
      ),
      _PillarData(
        number: '03',
        title: titleAt(2, 'Live with Confidence'),
        description: descriptionAt(
          2,
          'Thoughtfully designed spaces. Secure communities. Exceptional '
          'lifestyle for you and your family.',
        ),
        icon: LucideIcons.home,
        imageUrl: _liveImage,
        route: RoutePaths.properties,
      ),
    ];
  }
}

// ─── Hero ───────────────────────────────────────────────────────────────────

class _ExperienceHero extends StatelessWidget {
  const _ExperienceHero({
    required this.stacked,
    required this.story,
    required this.heroImageUrl,
    required this.quote,
    required this.showQuote,
    required this.executiveName,
    required this.executiveTitle,
    required this.onExplore,
    required this.onWatchStory,
  });

  final bool stacked;
  final String story;
  final String heroImageUrl;
  final String quote;
  final bool showQuote;
  final String executiveName;
  final String executiveTitle;
  final VoidCallback onExplore;
  final VoidCallback onWatchStory;

  @override
  Widget build(BuildContext context) {
    final copy = _HeroCopy(
      story: story,
      onExplore: onExplore,
      onWatchStory: onWatchStory,
      centered: stacked,
    );
    final quoteCard = _QuoteCard(
      message: quote,
      name: executiveName,
      title: executiveTitle,
    );

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          copy,
          const SizedBox(height: 28),
          SizedBox(
            height: 360,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: _HeroMedia(imageUrl: heroImageUrl),
                ),
                if (showQuote)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: quoteCard,
                  ),
              ],
            ),
          ),
        ],
      );
    }

    return SizedBox(
      height: 460,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: Align(
              alignment: Alignment.centerLeft,
              child: copy,
            ),
          ),
          const SizedBox(width: 28),
          Expanded(
            flex: 8,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: _HeroMedia(imageUrl: heroImageUrl),
                ),
                if (showQuote)
                  Positioned(
                    top: 28,
                    right: 24,
                    width: 280,
                    child: quoteCard,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({
    required this.story,
    required this.onExplore,
    required this.onWatchStory,
    required this.centered,
  });

  final String story;
  final VoidCallback onExplore;
  final VoidCallback onWatchStory;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final align =
        centered ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final textAlign = centered ? TextAlign.center : TextAlign.start;

    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: centered ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Container(
              width: 28,
              height: 1.5,
              color: HomeWhyChooseSection.gold,
            ),
            const SizedBox(width: 12),
            Text(
              'WHY HD HOMES',
              style: GoogleFonts.manrope(
                color: HomeWhyChooseSection.gold,
                fontSize: 11,
                letterSpacing: 2.8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text.rich(
          TextSpan(
            style: GoogleFonts.playfairDisplay(
              fontSize: centered ? 34 : 48,
              fontWeight: FontWeight.w600,
              height: 1.12,
              color: Colors.white,
            ),
            children: const [
              TextSpan(text: 'The HD Homes\n'),
              TextSpan(
                text: 'Experience',
                style: TextStyle(color: HomeWhyChooseSection.gold),
              ),
            ],
          ),
          textAlign: textAlign,
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            story.trim().isNotEmpty
                ? story
                : "We don't just build properties, we create lasting value, "
                    'vibrant communities, and generational legacies.',
            textAlign: textAlign,
            style: GoogleFonts.manrope(
              color: HomeWhyChooseSection.muted,
              fontSize: 14.5,
              height: 1.65,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: centered ? WrapAlignment.center : WrapAlignment.start,
          children: [
            _GoldButton(
              label: 'Explore Developments',
              trailing: LucideIcons.arrowRight,
              onTap: onExplore,
            ),
            _OutlineButton(
              label: 'Watch Our Story',
              leading: LucideIcons.play,
              onTap: onWatchStory,
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroMedia extends StatelessWidget {
  const _HeroMedia({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        fit: StackFit.expand,
        children: [
          MediaDeliveryImage(
            url: imageUrl,
            fit: BoxFit.cover,
            placeholder: Container(color: HomeWhyChooseSection.panel),
            errorWidget: Container(color: HomeWhyChooseSection.panel),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.25),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: HomeWhyChooseSection.gold.withValues(alpha: 0.18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    required this.message,
    required this.name,
    required this.title,
  });

  final String message;
  final String name;
  final String title;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: webSafeBackdropBlur(
        sigma: 16,
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          decoration: BoxDecoration(
            color: const Color(0xE6101010),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: HomeWhyChooseSection.gold.withValues(alpha: 0.55),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: HomeWhyChooseSection.gold.withValues(alpha: 0.22),
                blurRadius: 28,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.quote,
                color: HomeWhyChooseSection.gold,
                size: 28,
              ),
              const SizedBox(height: 14),
              Text(
                message,
                style: GoogleFonts.manrope(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 13.5,
                  height: 1.6,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                name,
                style: GoogleFonts.greatVibes(
                  color: HomeWhyChooseSection.gold,
                  fontSize: 28,
                  height: 1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$name, $title',
                style: GoogleFonts.manrope(
                  color: HomeWhyChooseSection.muted,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Pillars ────────────────────────────────────────────────────────────────

class _PillarsRow extends StatelessWidget {
  const _PillarsRow({required this.pillars, required this.stacked});

  final List<_PillarData> pillars;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    if (stacked) {
      return Column(
        children: [
          for (var i = 0; i < pillars.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _PillarCard(pillar: pillars[i]),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < pillars.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(child: _PillarCard(pillar: pillars[i])),
        ],
      ],
    );
  }
}

class _PillarCard extends StatelessWidget {
  const _PillarCard({required this.pillar});

  final _PillarData pillar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(pillar.route),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 340,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: HomeWhyChooseSection.gold.withValues(alpha: 0.16),
                blurRadius: 22,
                spreadRadius: 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                MediaDeliveryImage(
                  url: pillar.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: Container(color: HomeWhyChooseSection.panel),
                  errorWidget: Container(color: HomeWhyChooseSection.panel),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xCC0A0A0A),
                        Colors.black.withValues(alpha: 0.35),
                        Colors.black.withValues(alpha: 0.92),
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: HomeWhyChooseSection.gold.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: Text(
                          pillar.number,
                          style: GoogleFonts.manrope(
                            color: HomeWhyChooseSection.gold,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: HomeWhyChooseSection.gold
                                .withValues(alpha: 0.7),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: HomeWhyChooseSection.gold
                                  .withValues(alpha: 0.25),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                        child: Icon(
                          pillar.icon,
                          color: HomeWhyChooseSection.gold,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        pillar.title,
                        style: GoogleFonts.playfairDisplay(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        pillar.description,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 13,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Learn more',
                            style: GoogleFonts.manrope(
                              color: HomeWhyChooseSection.gold,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            LucideIcons.arrowRight,
                            size: 15,
                            color: HomeWhyChooseSection.gold,
                          ),
                        ],
                      ),
                    ],
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

// ─── Stats ──────────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.stats, required this.stacked});

  final List<HomeStatItem> stats;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: stacked ? 16 : 8,
        vertical: stacked ? 18 : 22,
      ),
      decoration: BoxDecoration(
        color: HomeWhyChooseSection.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: HomeWhyChooseSection.gold.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: HomeWhyChooseSection.gold.withValues(alpha: 0.1),
            blurRadius: 20,
          ),
        ],
      ),
      child: stacked
          ? Column(
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0) ...[
                    const SizedBox(height: 14),
                    Divider(
                      color: Colors.white.withValues(alpha: 0.08),
                      height: 1,
                    ),
                    const SizedBox(height: 14),
                  ],
                  _StatCell(stat: stats[i]),
                ],
              ],
            )
          : Row(
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0)
                    Container(
                      width: 1,
                      height: 64,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  Expanded(child: _StatCell(stat: stats[i])),
                ],
              ],
            ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.stat});

  final HomeStatItem stat;

  @override
  Widget build(BuildContext context) {
    final caption = (stat.caption?.trim().isNotEmpty ?? false)
        ? stat.caption!
        : stat.description;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: HomeWhyChooseSection.gold.withValues(alpha: 0.55),
              ),
            ),
            child: Icon(
              _iconFor(stat.iconName, stat.label),
              color: HomeWhyChooseSection.gold,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatValue(stat),
                  style: GoogleFonts.playfairDisplay(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                Text(
                  stat.label,
                  style: GoogleFonts.manrope(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (caption.isNotEmpty)
                  Text(
                    caption,
                    style: GoogleFonts.manrope(
                      color: HomeWhyChooseSection.muted,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatValue(HomeStatItem stat) {
    final suffix = stat.suffix ?? '';
    final lower = stat.label.toLowerCase();
    if (lower.contains('portfolio') || lower.contains('investment')) {
      if (stat.value >= 1e9) {
        return '₦${(stat.value / 1e9).toStringAsFixed(0)}B$suffix';
      }
      return '₦${NumberFormat.compact(locale: 'en').format(stat.value)}$suffix';
    }
    return '${NumberFormat.decimalPattern().format(stat.value)}$suffix';
  }

  IconData _iconFor(String? iconName, String label) {
    final key = (iconName ?? '').trim().toLowerCase();
    switch (key) {
      case 'trophy':
      case 'calendar':
        return LucideIcons.calendarCheck;
      case 'building':
      case 'home':
        return LucideIcons.home;
      case 'users':
      case 'user':
        return LucideIcons.users;
      case 'wallet':
      case 'coins':
        return LucideIcons.coins;
      default:
        break;
    }
    final lower = label.toLowerCase();
    if (lower.contains('year')) return LucideIcons.calendarCheck;
    if (lower.contains('home')) return LucideIcons.home;
    if (lower.contains('client')) return LucideIcons.users;
    if (lower.contains('portfolio') || lower.contains('investment')) {
      return LucideIcons.coins;
    }
    return LucideIcons.barChart2;
  }
}

// ─── CTA ────────────────────────────────────────────────────────────────────

class _BottomCtaBar extends StatelessWidget {
  const _BottomCtaBar({required this.stacked});

  final bool stacked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(stacked ? 20 : 24),
      decoration: BoxDecoration(
        color: HomeWhyChooseSection.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: HomeWhyChooseSection.gold.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: HomeWhyChooseSection.gold.withValues(alpha: 0.1),
            blurRadius: 18,
          ),
        ],
      ),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CtaHeadline(),
                const SizedBox(height: 12),
                _CtaSubtext(),
                const SizedBox(height: 18),
                _GoldButton(
                  label: 'Become an Investor',
                  trailing: LucideIcons.arrowRight,
                  onTap: () => context.go(RoutePaths.investment),
                ),
                const SizedBox(height: 10),
                _OutlineButton(
                  label: 'Talk to Our Team',
                  leading: LucideIcons.headphones,
                  onTap: () => context.go(RoutePaths.contact),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(flex: 4, child: _CtaHeadline()),
                const SizedBox(width: 16),
                Expanded(flex: 4, child: _CtaSubtext()),
                const SizedBox(width: 16),
                Flexible(
                  flex: 5,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: _GoldButton(
                          label: 'Become an Investor',
                          trailing: LucideIcons.arrowRight,
                          onTap: () => context.go(RoutePaths.investment),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: _OutlineButton(
                          label: 'Talk to Our Team',
                          leading: LucideIcons.headphones,
                          onTap: () => context.go(RoutePaths.contact),
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

class _CtaHeadline extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: HomeWhyChooseSection.gold.withValues(alpha: 0.45),
            ),
          ),
          child: const Icon(
            LucideIcons.phone,
            color: HomeWhyChooseSection.gold,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: GoogleFonts.playfairDisplay(
                fontSize: context.isMobile ? 17 : 19,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.3,
              ),
              children: const [
                TextSpan(text: "Let's help you find the right "),
                TextSpan(
                  text: 'opportunity.',
                  style: TextStyle(color: HomeWhyChooseSection.gold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CtaSubtext extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'Whether you want to buy, invest, or partner with us, our team is '
      'ready to assist you.',
      style: GoogleFonts.manrope(
        color: HomeWhyChooseSection.muted,
        fontSize: 13,
        height: 1.5,
      ),
    );
  }
}

// ─── Buttons ────────────────────────────────────────────────────────────────

class _GoldButton extends StatelessWidget {
  const _GoldButton({
    required this.label,
    required this.trailing,
    required this.onTap,
  });

  final String label;
  final IconData trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                HomeWhyChooseSection.goldBright,
                HomeWhyChooseSection.gold,
              ],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    color: const Color(0xFF1A1408),
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(trailing, size: 15, color: const Color(0xFF1A1408)),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({
    required this.label,
    required this.leading,
    required this.onTap,
  });

  final String label;
  final IconData leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: HomeWhyChooseSection.gold.withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(leading, size: 15, color: HomeWhyChooseSection.gold),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    color: HomeWhyChooseSection.gold,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillarData {
  const _PillarData({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
    required this.imageUrl,
    required this.route,
  });

  final String number;
  final String title;
  final String description;
  final IconData icon;
  final String imageUrl;
  final String route;
}
