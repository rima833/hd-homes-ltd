import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/about/data/models/about_cms_content.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

/// Premium About closing CTA matching the approved dark-luxury mockup.
class AboutPremiumCtaSection extends StatelessWidget {
  const AboutPremiumCtaSection({super.key, required this.cta});

  final AboutCtaContent cta;

  static const bg = Color(0xFF0F1117);
  static const card = Color(0xFF161A22);
  static const gold = Color(0xFFD4AF37);
  static const goldBright = Color(0xFFE8C56A);
  static const muted = Color(0xFF9A9A9A);

  @override
  Widget build(BuildContext context) {
    final primary = cta.actions.where((a) => a.isPrimary).firstOrNull;
    final secondaryActions = cta.actions.where((a) => !a.isPrimary).toList();
    final secondary = secondaryActions.isNotEmpty ? secondaryActions.first : null;
    final linkActions = secondaryActions;

    return SectionWrapper(
      backgroundColor: bg,
      padding: EdgeInsets.symmetric(
        horizontal: context.pagePadding,
        vertical: context.isMobile ? 40 : 64,
      ),
      child: Column(
        children: [
          _MainBanner(
            title: cta.title,
            subtitle: cta.subtitle,
            primary: primary,
            secondary: secondary,
          ),
          if (linkActions.isNotEmpty) ...[
            SizedBox(height: context.isMobile ? 28 : 36),
            _SecondaryActionsRow(actions: linkActions),
          ],
        ],
      ),
    );
  }
}

class _MainBanner extends StatelessWidget {
  const _MainBanner({
    required this.title,
    required this.subtitle,
    this.primary,
    this.secondary,
  });

  final String title;
  final String subtitle;
  final AboutCtaAction? primary;
  final AboutCtaAction? secondary;

  @override
  Widget build(BuildContext context) {
    final gold = AboutPremiumCtaSection.gold;
    final stacked = context.isMobile;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: stacked ? 0 : 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: AboutPremiumCtaSection.card,
        border: Border.all(color: gold.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: gold.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AboutPremiumCtaSection.card,
            const Color(0xFF1A1F2A),
            gold.withValues(alpha: 0.08),
          ],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: stacked ? 120 : 220,
            child: IgnorePointer(
              child: CustomPaint(painter: _SkylinePainter()),
            ),
          ),
          Positioned(
            top: 18,
            right: 22,
            child: IgnorePointer(child: CustomPaint(size: const Size(48, 40), painter: _DotGridPainter())),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: stacked ? 22 : 36,
              vertical: stacked ? 26 : 32,
            ),
            child: stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BannerCopy(title: title, subtitle: subtitle),
                      const SizedBox(height: 22),
                      _BannerButtons(primary: primary, secondary: secondary),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 7,
                        child: _BannerCopy(title: title, subtitle: subtitle),
                      ),
                      const SizedBox(width: 28),
                      Flexible(
                        flex: 5,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _BannerButtons(
                            primary: primary,
                            secondary: secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 480.ms).slideY(begin: 0.04, end: 0);
  }
}

class _BannerCopy extends StatelessWidget {
  const _BannerCopy({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final gold = AboutPremiumCtaSection.gold;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: gold.withValues(alpha: 0.65)),
          ),
          child: Icon(LucideIcons.home, color: gold, size: 18),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: GoogleFonts.playfairDisplay(
            color: Colors.white,
            fontSize: context.isMobile ? 26 : 34,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: GoogleFonts.manrope(
            color: AboutPremiumCtaSection.muted,
            fontSize: 14.5,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class _BannerButtons extends StatelessWidget {
  const _BannerButtons({this.primary, this.secondary});

  final AboutCtaAction? primary;
  final AboutCtaAction? secondary;

  @override
  Widget build(BuildContext context) {
    final gold = AboutPremiumCtaSection.gold;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.end,
      children: [
        if (primary != null)
          FilledButton.icon(
            onPressed: () => _open(context, primary!),
            style: FilledButton.styleFrom(
              backgroundColor: gold,
              foregroundColor: AboutPremiumCtaSection.bg,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              shadowColor: gold.withValues(alpha: 0.55),
              elevation: 8,
            ),
            icon: const Icon(LucideIcons.arrowRight, size: 16),
            label: Text(
              primary!.label,
              style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
            ),
            iconAlignment: IconAlignment.end,
          ),
        if (secondary != null)
          OutlinedButton.icon(
            onPressed: () => _open(context, secondary!),
            style: OutlinedButton.styleFrom(
              foregroundColor: gold,
              side: BorderSide(color: gold.withValues(alpha: 0.75)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(LucideIcons.arrowRight, size: 16),
            label: Text(
              secondary!.label,
              style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
            ),
            iconAlignment: IconAlignment.end,
          ),
      ],
    );
  }
}

class _SecondaryActionsRow extends StatelessWidget {
  const _SecondaryActionsRow({required this.actions});

  final List<AboutCtaAction> actions;

  @override
  Widget build(BuildContext context) {
    final stacked = context.isMobile;
    if (stacked) {
      return Column(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            _SecondaryActionTile(action: actions[i]),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 20),
          Expanded(child: _SecondaryActionTile(action: actions[i])),
        ],
      ],
    );
  }
}

class _SecondaryActionTile extends StatefulWidget {
  const _SecondaryActionTile({required this.action});

  final AboutCtaAction action;

  @override
  State<_SecondaryActionTile> createState() => _SecondaryActionTileState();
}

class _SecondaryActionTileState extends State<_SecondaryActionTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final gold = AboutPremiumCtaSection.gold;
    final action = widget.action;
    final description = action.description.trim().isNotEmpty
        ? action.description
        : _fallbackDescription(action.label);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _open(context, action),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: gold.withValues(alpha: _hover ? 0.9 : 0.55),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: gold.withValues(alpha: _hover ? 0.22 : 0.0),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Icon(
                  _iconFor(action.iconName, action.label),
                  color: gold,
                  size: 18,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.label,
                      style: GoogleFonts.manrope(
                        color: gold,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: GoogleFonts.manrope(
                        color: AboutPremiumCtaSection.muted,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                LucideIcons.arrowRight,
                color: gold.withValues(alpha: _hover ? 1 : 0.7),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkylinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final rng = math.Random(11);
    var x = size.width * 0.15;
    final base = size.height * 0.92;
    while (x < size.width) {
      final w = 16 + rng.nextDouble() * 26;
      final h = 28 + rng.nextDouble() * (size.height * 0.55);
      canvas.drawRect(Rect.fromLTWH(x, base - h, w, h), paint);
      x += w + 10;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.18);
    const cols = 5;
    const rows = 4;
    final dx = size.width / (cols - 1);
    final dy = size.height / (rows - 1);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        canvas.drawCircle(Offset(c * dx, r * dy), 1.4, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Future<void> _open(BuildContext context, AboutCtaAction action) async {
  final path = action.path.trim();
  if (path.startsWith('http://') || path.startsWith('https://')) {
    final uri = Uri.tryParse(path);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return;
  }
  context.go(path);
}

IconData _iconFor(String? iconName, String label) {
  final key = (iconName ?? '').trim().toLowerCase();
  if (key.isNotEmpty) {
    switch (key) {
      case 'user':
      case 'users':
      case 'investor':
        return LucideIcons.user;
      case 'calendar':
      case 'inspection':
        return LucideIcons.calendarDays;
      case 'file':
      case 'document':
      case 'download':
        return LucideIcons.fileText;
      case 'home':
        return LucideIcons.home;
    }
  }

  final lower = label.toLowerCase();
  if (lower.contains('investor')) return LucideIcons.user;
  if (lower.contains('inspection') || lower.contains('book')) {
    return LucideIcons.calendarDays;
  }
  if (lower.contains('download') || lower.contains('profile')) {
    return LucideIcons.fileText;
  }
  return LucideIcons.arrowRight;
}

String _fallbackDescription(String label) {
  final lower = label.toLowerCase();
  if (lower.contains('investor')) {
    return 'Join our growing network of investors.';
  }
  if (lower.contains('inspection') || lower.contains('book')) {
    return 'Schedule a visit and experience our developments firsthand.';
  }
  if (lower.contains('download') || lower.contains('profile')) {
    return 'Get insights into our projects, values, and track record.';
  }
  return 'Continue with HD Homes.';
}
