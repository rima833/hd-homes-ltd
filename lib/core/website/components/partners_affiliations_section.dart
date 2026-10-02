import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Shared display model for Partners & Affiliations (home + about).
class PartnerAffiliationItem {
  const PartnerAffiliationItem({
    required this.name,
    required this.category,
    this.tagline = '',
    this.logoUrl,
    this.iconName = 'building',
  });

  final String name;
  final String category;
  final String tagline;
  final String? logoUrl;
  final String iconName;
}

/// Premium Partners & Affiliations section matching the HD Homes mockup.
class PartnersAffiliationsSection extends StatelessWidget {
  const PartnersAffiliationsSection({
    super.key,
    required this.partners,
    this.title = 'Partners & affiliations',
    this.subtitle = 'Strong partnerships. Shared values. Exceptional results.',
    this.showPromise = true,
  });

  static const promiseAsset =
      'assets/images/illustrations/hd_partners_promise.png';

  final List<PartnerAffiliationItem> partners;
  final String title;
  final String subtitle;
  final bool showPromise;

  static const _bg = Color(0xFF050505);
  static const _gold = Color(0xFFD4AF37);
  static const _goldBright = Color(0xFFE8C56A);
  static const _muted = Color(0xFF9A9A9A);
  static const _panel = Color(0xFF0A0A0A);

  @override
  Widget build(BuildContext context) {
    if (partners.isEmpty) return const SizedBox.shrink();

    return SectionWrapper(
      backgroundColor: _bg,
      padding: EdgeInsets.symmetric(
        horizontal: context.pagePadding,
        vertical: context.isMobile ? 52 : 80,
      ),
      child: Column(
        children: [
          _PartnersHeader(title: title, subtitle: subtitle)
              .animate()
              .fadeIn(duration: 520.ms)
              .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
          SizedBox(height: context.isMobile ? 36 : 48),
          _PartnersStrip(partners: partners)
              .animate()
              .fadeIn(delay: 80.ms, duration: 560.ms)
              .slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic),
          if (showPromise) ...[
            SizedBox(height: context.isMobile ? 36 : 48),
            const _PartnershipPromise()
                .animate()
                .fadeIn(delay: 160.ms, duration: 600.ms)
                .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
          ],
        ],
      ),
    );
  }
}

class _PartnersHeader extends StatelessWidget {
  const _PartnersHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _line(),
            const SizedBox(width: 16),
            Text(
              'PARTNERS',
              style: GoogleFonts.manrope(
                color: PartnersAffiliationsSection._gold,
                fontSize: 11,
                letterSpacing: 4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 16),
            _line(),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(
            fontSize: context.isMobile ? 32 : 44,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            height: 1.12,
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: PartnersAffiliationsSection._muted,
              fontSize: 14.5,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }

  Widget _line() {
    return Container(
      width: 48,
      height: 1,
      color: PartnersAffiliationsSection._gold.withValues(alpha: 0.85),
    );
  }
}

class _PartnersStrip extends StatelessWidget {
  const _PartnersStrip({required this.partners});

  final List<PartnerAffiliationItem> partners;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: PartnersAffiliationsSection._panel.withValues(alpha: 0.92),
        border: Border.all(
          color: PartnersAffiliationsSection._gold.withValues(alpha: 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: PartnersAffiliationsSection._gold.withValues(alpha: 0.1),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: 24,
            right: 24,
            top: 0,
            height: 1.5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    PartnersAffiliationsSection._gold.withValues(alpha: 0.9),
                    PartnersAffiliationsSection._goldBright,
                    PartnersAffiliationsSection._gold.withValues(alpha: 0.9),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 980;
              if (wide && partners.length <= 7) {
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < partners.length; i++) ...[
                        if (i > 0)
                          Container(
                            width: 1,
                            margin: const EdgeInsets.symmetric(vertical: 22),
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        Expanded(
                          child: _PartnerCell(partner: partners[i], index: i),
                        ),
                      ],
                    ],
                  ),
                );
              }
              return SizedBox(
                height: 168,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: partners.length,
                  separatorBuilder: (_, _) => Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(vertical: 18),
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  itemBuilder: (context, i) {
                    return SizedBox(
                      width: math.min(168.0, constraints.maxWidth * 0.42),
                      child: _PartnerCell(partner: partners[i], index: i),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PartnerCell extends StatefulWidget {
  const _PartnerCell({required this.partner, required this.index});

  final PartnerAffiliationItem partner;
  final int index;

  @override
  State<_PartnerCell> createState() => _PartnerCellState();
}

class _PartnerCellState extends State<_PartnerCell> {
  bool _hover = false;

  IconData get _icon {
    switch (widget.partner.iconName.toLowerCase()) {
      case 'landmark':
      case 'bank':
        return LucideIcons.landmark;
      case 'hardhat':
      case 'construction':
        return LucideIcons.hardHat;
      case 'shield':
        return LucideIcons.shield;
      case 'badge':
        return LucideIcons.badgeCheck;
      case 'compass':
      case 'survey':
        return LucideIcons.compass;
      default:
        return LucideIcons.building2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gold = PartnersAffiliationsSection._gold;
    final logo = widget.partner.logoUrl?.trim();

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        decoration: BoxDecoration(
          color: _hover
              ? gold.withValues(alpha: 0.06)
              : Colors.transparent,
          boxShadow: _hover
              ? [
                  BoxShadow(
                    color: gold.withValues(alpha: 0.18),
                    blurRadius: 22,
                  ),
                ]
              : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 44,
                child: logo != null && logo.isNotEmpty
                    ? MediaDeliveryImage(
                      url: logo,
                      fit: BoxFit.contain,
                      errorWidget: Icon(_icon, color: gold, size: 28),
                    )
                    : Icon(_icon, color: gold, size: 28),
              ),
              if (widget.partner.tagline.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  widget.partner.tagline,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                widget.partner.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.partner.category,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                color: PartnersAffiliationsSection._muted,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (60 * widget.index).ms, duration: 420.ms);
  }
}

class _PartnershipPromise extends StatelessWidget {
  const _PartnershipPromise();

  @override
  Widget build(BuildContext context) {
    final gold = PartnersAffiliationsSection._gold;
    final stacked = context.isMobile || context.isTablet;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF080808),
        border: Border.all(color: gold.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: gold.withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: 20,
            right: 20,
            top: 0,
            height: 1.6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    gold.withValues(alpha: 0.95),
                    PartnersAffiliationsSection._goldBright,
                    gold.withValues(alpha: 0.95),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              stacked ? 22 : 36,
              stacked ? 28 : 36,
              stacked ? 22 : 28,
              stacked ? 28 : 36,
            ),
            child: stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _PromiseCopy(),
                      const SizedBox(height: 28),
                      const _PromiseVisual(),
                    ],
                  )
                : const Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(flex: 11, child: _PromiseCopy()),
                      SizedBox(width: 28),
                      Expanded(flex: 10, child: _PromiseVisual()),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _PromiseCopy extends StatelessWidget {
  const _PromiseCopy();

  @override
  Widget build(BuildContext context) {
    final gold = PartnersAffiliationsSection._gold;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OUR PARTNERSHIP PROMISE',
          style: GoogleFonts.manrope(
            color: gold,
            fontSize: 11,
            letterSpacing: 2.8,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Built on trust.\nDriven by excellence.',
          style: GoogleFonts.playfairDisplay(
            color: Colors.white,
            fontSize: context.isMobile ? 28 : 36,
            fontWeight: FontWeight.w500,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'We collaborate with leading institutions and professionals to deliver outstanding value, quality, and long-term impact for our clients and communities.',
          style: GoogleFonts.manrope(
            color: PartnersAffiliationsSection._muted,
            fontSize: 14,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 22,
          runSpacing: 14,
          children: [
            _PromisePill(
              icon: LucideIcons.shieldCheck,
              label: 'Vetted & Trusted Partners',
            ),
            _PromisePill(
              icon: LucideIcons.heartHandshake,
              label: 'Shared Vision, Shared Growth',
            ),
            _PromisePill(
              icon: LucideIcons.medal,
              label: 'Committed to Excellence',
            ),
          ],
        ),
      ],
    );
  }
}

class _PromisePill extends StatelessWidget {
  const _PromisePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final gold = PartnersAffiliationsSection._gold;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: gold, size: 16),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.manrope(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PromiseVisual extends StatelessWidget {
  const _PromiseVisual();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.55,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.2, 0.1),
                  radius: 0.9,
                  colors: [
                    PartnersAffiliationsSection._gold.withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Image.asset(
              PartnersAffiliationsSection.promiseAsset,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) =>
                  const _PromiseVisualFallback(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromiseVisualFallback extends StatelessWidget {
  const _PromiseVisualFallback();

  @override
  Widget build(BuildContext context) {
    final gold = PartnersAffiliationsSection._gold;
    return Center(
      child: Text(
        'HD',
        style: GoogleFonts.manrope(
          color: gold,
          fontSize: 72,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
        ),
      ),
    );
  }
}
