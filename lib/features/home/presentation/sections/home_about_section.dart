import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/home/data/models/home_cms_content.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// About HD Homes — luxury glass mockup (Mission/Vision, values, highlights, CTA).
/// Shown on the About page (moved from Home).
class HomeAboutSection extends StatelessWidget {
  const HomeAboutSection({super.key, required this.content});

  final HomeAboutContent content;

  static const _bg = Color(0xFF000000);
  static const _gold = Color(0xFFD4AF37);
  static const _body = Color(0xFFCCCCCC);
  static const _glass = Color(0x0DFFFFFF);
  static const _glassBorder = Color(0x33D4AF37);

  static const _highlightImage =
      '';

  @override
  Widget build(BuildContext context) {
    final mobile = context.screenWidth < 900;
    return SectionWrapper(
      backgroundColor: _bg,
      child: Column(
        children: [
          if (mobile) ...[
            _LeftColumn(content: content),
            const SizedBox(height: 28),
            _HighlightsPanel(
              content: content,
              imageUrl: content.backgroundImageUrl ?? _highlightImage,
            ),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 11, child: _LeftColumn(content: content)),
                const SizedBox(width: 28),
                Expanded(
                  flex: 9,
                  child: _HighlightsPanel(
                    content: content,
                    imageUrl: content.backgroundImageUrl ?? _highlightImage,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 28),
          const _ContactBanner(),
        ],
      ),
    );
  }
}

class _LeftColumn extends StatelessWidget {
  const _LeftColumn({required this.content});
  final HomeAboutContent content;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'ABOUT HD HOMES',
              style: GoogleFonts.inter(
                color: HomeAboutSection._gold,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.4,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      HomeAboutSection._gold.withValues(alpha: 0.9),
                      HomeAboutSection._gold.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _LuxuryTitle(title: content.title),
        const SizedBox(height: 14),
        Text(
          content.story,
          style: GoogleFonts.inter(
            color: HomeAboutSection._body,
            fontSize: 15,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 22),
        _MissionVisionCard(
          index: '01',
          title: 'Our Mission',
          body: content.mission,
          icon: LucideIcons.flag,
        ),
        const SizedBox(height: 14),
        _MissionVisionCard(
          index: '02',
          title: 'Our Vision',
          body: content.vision,
          icon: LucideIcons.eye,
        ),
        const SizedBox(height: 28),
        Text(
          'OUR CORE VALUES',
          style: GoogleFonts.inter(
            color: HomeAboutSection._gold,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.2,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 16),
        _CoreValuesRow(values: content.values),
        const SizedBox(height: 28),
        Wrap(
          spacing: 16,
          runSpacing: 14,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _GoldCtaButton(
              label: content.ctaLabel.trim().isEmpty
                  ? 'Learn More About Us'
                  : (content.ctaLabel == 'Learn More'
                      ? 'Learn More About Us'
                      : content.ctaLabel),
              onPressed: () => context.go(content.ctaPath),
            ),
            _WatchVideoButton(
              onPressed: () => context.go(RoutePaths.about),
            ),
          ],
        ),
      ],
    );
  }
}

class _LuxuryTitle extends StatelessWidget {
  const _LuxuryTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final mobile = context.isMobile;
    final size = mobile ? 32.0 : 42.0;
    // Mockup: "Building More Than" + gold "Properties"
    const highlight = 'Properties';
    final clean = title.replaceAll(',', '').trim();
    String lead = clean;
    String accent = highlight;
    if (clean.toLowerCase().contains(highlight.toLowerCase())) {
      final i = clean.toLowerCase().indexOf(highlight.toLowerCase());
      lead = clean.substring(0, i).trimRight();
      accent = clean.substring(i, i + highlight.length);
    }

    return Text.rich(
      TextSpan(
        style: GoogleFonts.inter(
          color: AppColors.white,
          fontSize: size,
          fontWeight: FontWeight.w700,
          height: 1.15,
        ),
        children: [
          TextSpan(text: lead.isEmpty ? '' : '$lead '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Color(0xFFF4C978),
                  Color(0xFFD4AF37),
                  Color(0xFFB8860B),
                ],
              ).createShader(bounds),
              child: Text(
                accent,
                style: GoogleFonts.playfairDisplay(
                  color: Colors.white,
                  fontSize: size + 4,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  shadows: [
                    Shadow(
                      color: HomeAboutSection._gold.withValues(alpha: 0.45),
                      blurRadius: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionVisionCard extends StatelessWidget {
  const _MissionVisionCard({
    required this.index,
    required this.title,
    required this.body,
    required this.icon,
  });

  final String index;
  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: HomeAboutSection._glass,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: HomeAboutSection._glassBorder),
        boxShadow: [
          BoxShadow(
            color: HomeAboutSection._gold.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 4,
            top: 0,
            child: Text(
              index,
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.08),
                fontSize: 48,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: HomeAboutSection._gold, width: 1.4),
                  color: HomeAboutSection._gold.withValues(alpha: 0.08),
                ),
                child: Icon(icon, color: HomeAboutSection._gold, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.playfairDisplay(
                        color: HomeAboutSection._gold,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      body,
                      style: GoogleFonts.inter(
                        color: AppColors.white.withValues(alpha: 0.88),
                        fontSize: 13.5,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoreValuesRow extends StatelessWidget {
  const _CoreValuesRow({required this.values});
  final List<String> values;

  IconData _iconFor(String label) {
    switch (label.toLowerCase()) {
      case 'integrity':
        return LucideIcons.shield;
      case 'energy':
        return LucideIcons.zap;
      case 'innovation':
        return LucideIcons.lightbulb;
      case 'drive':
        return LucideIcons.target;
      case 'commitment':
        return LucideIcons.heart;
      default:
        return LucideIcons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = values.isEmpty
        ? const ['Integrity', 'Energy', 'Innovation', 'Drive', 'Commitment']
        : values;
    return LayoutBuilder(
      builder: (context, c) {
        final tight = c.maxWidth < 520;
        if (tight) {
          return Wrap(
            spacing: 18,
            runSpacing: 16,
            alignment: WrapAlignment.start,
            children: [
              for (final v in items) _valueItem(v),
            ],
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final v in items) Expanded(child: _valueItem(v)),
          ],
        );
      },
    );
  }

  Widget _valueItem(String label) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: HomeAboutSection._gold, width: 1.3),
            boxShadow: [
              BoxShadow(
                color: HomeAboutSection._gold.withValues(alpha: 0.2),
                blurRadius: 14,
              ),
            ],
          ),
          child: Icon(_iconFor(label), color: HomeAboutSection._gold, size: 22),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: AppColors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _GoldCtaButton extends StatefulWidget {
  const _GoldCtaButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  State<_GoldCtaButton> createState() => _GoldCtaButtonState();
}

class _GoldCtaButtonState extends State<_GoldCtaButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? 1.02 : 1,
        duration: const Duration(milliseconds: 180),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFF4C978),
                    Color(0xFFD4AF37),
                    Color(0xFFB8860B),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: HomeAboutSection._gold
                        .withValues(alpha: _hover ? 0.55 : 0.35),
                    blurRadius: _hover ? 28 : 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF0F1115),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      LucideIcons.arrowRight,
                      size: 16,
                      color: Color(0xFF0F1115),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WatchVideoButton extends StatelessWidget {
  const _WatchVideoButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: HomeAboutSection._gold, width: 1.4),
              ),
              child: const Icon(
                LucideIcons.play,
                size: 16,
                color: HomeAboutSection._gold,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Watch Company Video',
              style: GoogleFonts.inter(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightsPanel extends StatelessWidget {
  const _HighlightsPanel({
    required this.content,
    required this.imageUrl,
  });

  final HomeAboutContent content;
  final String imageUrl;

  IconData _iconFor(String name) {
    switch (name) {
      case 'badge':
        return LucideIcons.badgeCheck;
      case 'map_pin':
        return LucideIcons.mapPin;
      case 'wallet':
        return LucideIcons.wallet;
      case 'hard_hat':
        return LucideIcons.hammer;
      default:
        return LucideIcons.sparkles;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0C10),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: HomeAboutSection._glassBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: HomeAboutSection._gold.withValues(alpha: 0.18),
            blurRadius: 36,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.sparkles,
                  color: HomeAboutSection._gold,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(
                  'Company Highlights',
                  style: GoogleFonts.inter(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 8),
            child: Column(
              children: [
                for (final item in content.highlights)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: HomeAboutSection._gold,
                              width: 1.2,
                            ),
                            color: HomeAboutSection._gold
                                .withValues(alpha: 0.08),
                          ),
                          child: Icon(
                            _iconFor(item.iconName),
                            color: HomeAboutSection._gold,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: GoogleFonts.inter(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.description,
                                style: GoogleFonts.inter(
                                  color: HomeAboutSection._body,
                                  fontSize: 12.5,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: (imageUrl.trim().isEmpty)
                    ? Container(
                        color: const Color(0xFF1A1D24),
                        child: const Center(
                          child: Icon(
                            LucideIcons.building2,
                            color: HomeAboutSection._gold,
                            size: 36,
                          ),
                        ),
                      )
                    : MediaDeliveryImage(
                        url: imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: Container(
                          color: const Color(0xFF1A1D24),
                          child: const Center(
                            child: Icon(
                              LucideIcons.building2,
                              color: HomeAboutSection._gold,
                              size: 36,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
            child: Row(
              children: const [
                Expanded(
                  child: _StatCell(
                    icon: LucideIcons.home,
                    value: '1,000+',
                    label: 'Homes Delivered',
                  ),
                ),
                Expanded(
                  child: _StatCell(
                    icon: LucideIcons.award,
                    value: '15+',
                    label: 'Years Experience',
                  ),
                ),
                Expanded(
                  child: _StatCell(
                    icon: LucideIcons.users,
                    value: '500+',
                    label: 'Happy Clients',
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

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Icon(icon, color: HomeAboutSection._gold, size: 16),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              color: AppColors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: HomeAboutSection._body,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactBanner extends StatelessWidget {
  const _ContactBanner();

  @override
  Widget build(BuildContext context) {
    final mobile = context.isMobile;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 18 : 24,
        vertical: mobile ? 18 : 20,
      ),
      decoration: BoxDecoration(
        color: HomeAboutSection._glass,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: HomeAboutSection._glassBorder),
        boxShadow: [
          BoxShadow(
            color: HomeAboutSection._gold.withValues(alpha: 0.1),
            blurRadius: 20,
          ),
        ],
      ),
      child: mobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bannerLead(),
                const SizedBox(height: 16),
                _contactButton(context),
              ],
            )
          : Row(
              children: [
                Expanded(child: _bannerLead()),
                const SizedBox(width: 16),
                _contactButton(context),
              ],
            ),
    );
  }

  Widget _bannerLead() {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: HomeAboutSection._gold, width: 1.4),
            color: HomeAboutSection._gold.withValues(alpha: 0.1),
          ),
          child: const Icon(
            LucideIcons.headphones,
            color: HomeAboutSection._gold,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Have questions? Let's talk.",
                style: GoogleFonts.inter(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Speak with our advisors about homes, investments, and next steps.',
                style: GoogleFonts.inter(
                  color: HomeAboutSection._body,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _contactButton(BuildContext context) {
    return OutlinedButton(
      onPressed: () => context.go(RoutePaths.contact),
      style: OutlinedButton.styleFrom(
        foregroundColor: HomeAboutSection._gold,
        side: const BorderSide(color: HomeAboutSection._gold, width: 1.3),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Contact Us',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          const Icon(LucideIcons.arrowRight, size: 16),
        ],
      ),
    );
  }
}
