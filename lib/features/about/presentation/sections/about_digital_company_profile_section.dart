import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/about/data/models/about_cms_content.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

const _profileBg = Color(0xFF0B0D12);
const _cardBg = Color(0xFF151821);
const _cardBgHover = Color(0xFF1A1D26);
const _iconWell = Color(0xFF10131A);

/// Premium Digital Company Profile — CMS-backed with seeded fallbacks.
///
/// Trust KPIs prefer live `company_statistics` (Admin → Website → Statistics)
/// with realtime refresh, then the digital-profile singleton, then fallbacks.
class AboutDigitalCompanyProfileSection extends ConsumerStatefulWidget {
  const AboutDigitalCompanyProfileSection({
    super.key,
    required this.fallback,
  });

  final AboutCompanyProfile fallback;

  @override
  ConsumerState<AboutDigitalCompanyProfileSection> createState() =>
      _AboutDigitalCompanyProfileSectionState();
}

class _AboutDigitalCompanyProfileSectionState
    extends ConsumerState<AboutDigitalCompanyProfileSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  List<AboutProfileTrustStat> _trustFromCompanyStats(
    List<CmsCompanyStat> stats,
  ) {
    if (stats.isEmpty) return const [];
    final summary = stats.where((s) => s.placement == 'summary').toList();
    final source = summary.length >= 2 ? summary : stats;
    return [
      for (final s in source.take(4))
        AboutProfileTrustStat(
          value: '${s.value}${s.suffix}',
          label: s.label,
        ),
    ];
  }

  List<AboutProfileTrustStat> _trustFromDigitalProfile(
    CmsDigitalCompanyProfile cms,
  ) =>
      [
        AboutProfileTrustStat(
          value: '${cms.yearsValue}${cms.yearsSuffix}',
          label: cms.yearsLabel,
        ),
        AboutProfileTrustStat(
          value: '${cms.homesValue}${cms.homesSuffix}',
          label: cms.homesLabel,
        ),
        AboutProfileTrustStat(
          value: '${cms.clientsValue}${cms.clientsSuffix}',
          label: cms.clientsLabel,
        ),
        AboutProfileTrustStat(
          value: '${cms.projectsValue}${cms.projectsSuffix}',
          label: cms.projectsLabel,
        ),
      ];

  AboutCompanyProfile _resolve(
    CmsDigitalCompanyProfile? cms,
    List<CmsCompanyStat> liveStats,
  ) {
    final liveTrust = _trustFromCompanyStats(liveStats);
    if (cms == null) {
      if (liveTrust.isEmpty) return widget.fallback;
      return AboutCompanyProfile(
        overline: widget.fallback.overline,
        title: widget.fallback.title,
        description: widget.fallback.description,
        cardTitle: widget.fallback.cardTitle,
        cardDescription: widget.fallback.cardDescription,
        features: widget.fallback.features,
        ctaLabel: widget.fallback.ctaLabel,
        downloadUrl: widget.fallback.downloadUrl,
        viewUrl: widget.fallback.viewUrl,
        mockupImageUrl: widget.fallback.mockupImageUrl,
        pdfLabel: widget.fallback.pdfLabel,
        pdfMeta: widget.fallback.pdfMeta,
        brochureLabel: widget.fallback.brochureLabel,
        brochureUrl: widget.fallback.brochureUrl,
        brochureMeta: widget.fallback.brochureMeta,
        trustMessage: widget.fallback.trustMessage,
        trustStats: liveTrust,
      );
    }
    return AboutCompanyProfile(
      overline: cms.overline,
      title: cms.title,
      description: cms.subtitle,
      cardTitle: cms.cardTitle,
      cardDescription: cms.cardDescription,
      features: cms.features,
      ctaLabel: cms.ctaLabel,
      viewUrl: cms.viewUrl,
      downloadUrl: cms.pdfUrl,
      mockupImageUrl: cms.mockupImageUrl,
      pdfLabel: cms.pdfLabel,
      pdfMeta: cms.pdfMeta,
      brochureLabel: cms.brochureLabel,
      brochureUrl: cms.brochureUrl,
      brochureMeta: cms.brochureMeta,
      trustMessage: cms.trustMessage,
      trustStats: liveTrust.isNotEmpty
          ? liveTrust
          : _trustFromDigitalProfile(cms),
    );
  }

  Future<void> _open(String raw) async {
    final value = raw.trim();
    if (value.isEmpty || value == '#') return;
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Animation<double> _interval(double begin, double end) => CurvedAnimation(
        parent: _enter,
        curve: Interval(begin, end, curve: Curves.easeOutCubic),
      );

  @override
  Widget build(BuildContext context) {
    ref.watch(digitalCompanyProfileRealtimeProvider);
    ref.watch(companyStatsRealtimeProvider);
    ref.listen(publishedCompanyStatsAboutProvider, (prev, next) {
      final had = prev?.valueOrNull ?? const <CmsCompanyStat>[];
      final now = next.valueOrNull ?? const <CmsCompanyStat>[];
      if (now.isEmpty) return;
      if (had.map((s) => '${s.value}${s.suffix}${s.label}').join() ==
          now.map((s) => '${s.value}${s.suffix}${s.label}').join()) {
        return;
      }
      _enter.forward(from: 0);
    });
    final cms = ref.watch(publishedDigitalCompanyProfileProvider).valueOrNull;
    final liveStats =
        ref.watch(publishedCompanyStatsAboutProvider).valueOrNull ??
            const <CmsCompanyStat>[];
    final profile = _resolve(cms, liveStats);
    final mobile = context.isMobile;

    return SectionWrapper(
      backgroundColor: _profileBg,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(child: IgnorePointer(child: _AmbientBackdrop())),
          Column(
            children: [
              FadeTransition(
                opacity: _interval(0.0, 0.35),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.04),
                    end: Offset.zero,
                  ).animate(_interval(0.0, 0.35)),
                  child: _ProfileHeader(profile: profile),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              FadeTransition(
                opacity: _interval(0.12, 0.55),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(_interval(0.12, 0.55)),
                  child: _MainProfileCard(
                    profile: profile,
                    mobile: mobile,
                    onView: () => _open(profile.viewUrl),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              FadeTransition(
                opacity: _interval(0.35, 0.75),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.05),
                    end: Offset.zero,
                  ).animate(_interval(0.35, 0.75)),
                  child: _DownloadsRow(
                    profile: profile,
                    mobile: mobile,
                    onPdf: () => _open(profile.downloadUrl),
                    onBrochure: () => _open(profile.brochureUrl),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              FadeTransition(
                opacity: _interval(0.5, 1.0),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.05),
                    end: Offset.zero,
                  ).animate(_interval(0.5, 1.0)),
                  child: _TrustStatsBar(
                    profile: profile,
                    mobile: mobile,
                    progress: CurvedAnimation(
                      parent: _enter,
                      curve: const Interval(0.55, 1.0, curve: Curves.easeOutCubic),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AmbientBackdrop extends StatelessWidget {
  const _AmbientBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _AmbientPainter());
  }
}

class _AmbientPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.6, -0.8),
        radius: 1.1,
        colors: [
          AppColors.gold.withValues(alpha: 0.07),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, glow);

    final line = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.045)
      ..strokeWidth = 1;
    for (var i = 0; i < 10; i++) {
      final x = size.width * (0.08 + i * 0.09);
      canvas.drawLine(Offset(x, size.height * 0.08), Offset(x, size.height * 0.92), line);
    }

    final spark = Paint()..color = AppColors.gold.withValues(alpha: 0.18);
    final rnd = math.Random(7);
    for (var i = 0; i < 18; i++) {
      final dx = rnd.nextDouble() * size.width;
      final dy = rnd.nextDouble() * size.height;
      canvas.drawCircle(Offset(dx, dy), rnd.nextDouble() * 1.6 + 0.4, spark);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final AboutCompanyProfile profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.diamond,
              size: 10,
              color: AppColors.gold.withValues(alpha: 0.9),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              profile.overline.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.gold,
                    letterSpacing: 2.8,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              LucideIcons.diamond,
              size: 10,
              color: AppColors.gold.withValues(alpha: 0.9),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          profile.title,
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(
            fontSize: context.isMobile ? 34 : 44,
            fontWeight: FontWeight.w700,
            color: AppColors.white,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            profile.description,
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

class _MainProfileCard extends StatefulWidget {
  const _MainProfileCard({
    required this.profile,
    required this.mobile,
    required this.onView,
  });

  final AboutCompanyProfile profile;
  final bool mobile;
  final VoidCallback onView;

  @override
  State<_MainProfileCard> createState() => _MainProfileCardState();
}

class _MainProfileCardState extends State<_MainProfileCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _iconWell,
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.28),
                blurRadius: 16,
              ),
            ],
          ),
          child: const Icon(
            LucideIcons.building2,
            color: AppColors.gold,
            size: 24,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          profile.cardTitle,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          profile.cardDescription,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondaryDark,
                height: 1.5,
              ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _FeatureGrid(features: profile.features, mobile: widget.mobile),
        const SizedBox(height: AppSpacing.xl),
        _GoldCtaButton(label: profile.ctaLabel, onPressed: widget.onView),
      ],
    );

    final visual = _MockupVisual(imageUrl: profile.mockupImageUrl);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: EdgeInsets.all(widget.mobile ? AppSpacing.lg : AppSpacing.xxl),
        decoration: BoxDecoration(
          color: _hovered ? _cardBgHover : _cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: _hovered ? 0.6 : 0.34),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.gold.withValues(alpha: _hovered ? 0.1 : 0.05),
              _hovered ? _cardBgHover : _cardBg,
              _cardBg,
            ],
            stops: const [0.0, 0.28, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: _hovered ? 0.22 : 0.1),
              blurRadius: _hovered ? 36 : 22,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: widget.mobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  content,
                  const SizedBox(height: AppSpacing.xl),
                  visual,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 11, child: content),
                  const SizedBox(width: AppSpacing.xxl),
                  Expanded(flex: 9, child: visual),
                ],
              ),
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.features, required this.mobile});

  final List<String> features;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final items = features.take(6).toList();
    if (mobile) {
      return Column(
        children: [
          for (final f in items) ...[
            _FeatureItem(label: f),
            const SizedBox(height: 10),
          ],
        ],
      );
    }
    final left = <String>[];
    final right = <String>[];
    for (var i = 0; i < items.length; i++) {
      (i.isEven ? left : right).add(items[i]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              for (final f in left) ...[
                _FeatureItem(label: f),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            children: [
              for (final f in right) ...[
                _FeatureItem(label: f),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.85)),
            color: AppColors.gold.withValues(alpha: 0.1),
          ),
          child: Icon(
            LucideIcons.check,
            size: 11,
            color: AppColors.gold.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.white.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w500,
                ),
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
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFFE0B35C),
                    Color(0xFFD4A34E),
                    Color(0xFFB8873A),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.eye, size: 18, color: Colors.black),
                    const SizedBox(width: 10),
                    Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      LucideIcons.arrowRight,
                      size: 16,
                      color: Colors.black,
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

class _MockupVisual extends StatelessWidget {
  const _MockupVisual({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final custom = imageUrl?.trim();
    if (custom != null && custom.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: MediaDeliveryImage(
            url: custom,
            fit: BoxFit.cover,
            errorWidget: const _DefaultMockup(),
          ),
        ),
      );
    }
    return const _DefaultMockup();
  }
}

class _DefaultMockup extends StatelessWidget {
  const _DefaultMockup();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _MockupPainter()),
            Align(
              alignment: const Alignment(-0.55, 0.35),
              child: Transform.rotate(
                angle: -0.12,
                child: Container(
                  width: 78,
                  height: 108,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFF12151C),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.65),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 16,
                        offset: const Offset(4, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HD HOMES',
                        style: GoogleFonts.playfairDisplay(
                          color: AppColors.gold,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'COMPANY\nPROFILE',
                        style: TextStyle(
                          color: AppColors.white.withValues(alpha: 0.85),
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        height: 28,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: AppColors.gold.withValues(alpha: 0.16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: const Alignment(0.45, 0.05),
              child: Container(
                width: 170,
                height: 108,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFF1A2030),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.45),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.18),
                      blurRadius: 20,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HD HOMES',
                      style: GoogleFonts.playfairDisplay(
                        color: AppColors.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'BUILDING LEGACIES.\nCREATING VALUE.',
                      style: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.9),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      height: 28,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          colors: [
                            AppColors.gold.withValues(alpha: 0.35),
                            AppColors.gold.withValues(alpha: 0.08),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MockupPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.2, -0.2),
        radius: 1.1,
        colors: [
          AppColors.gold.withValues(alpha: 0.12),
          const Color(0xFF10131A),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    final line = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (var i = 0; i < 8; i++) {
      final y = size.height * (0.15 + i * 0.1);
      canvas.drawLine(Offset(16, y), Offset(size.width - 16, y), line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// PDF | OR | Brochure — matches mockup.
class _DownloadsRow extends StatelessWidget {
  const _DownloadsRow({
    required this.profile,
    required this.mobile,
    required this.onPdf,
    required this.onBrochure,
  });

  final AboutCompanyProfile profile;
  final bool mobile;
  final VoidCallback onPdf;
  final VoidCallback onBrochure;

  @override
  Widget build(BuildContext context) {
    final pdf = _DownloadCard(
      title: profile.pdfLabel,
      meta: profile.pdfMeta,
      icon: LucideIcons.fileText,
      onTap: onPdf,
    );
    final brochure = _DownloadCard(
      title: profile.brochureLabel,
      meta: profile.brochureMeta,
      icon: LucideIcons.bookOpen,
      onTap: onBrochure,
    );

    if (mobile) {
      return Column(
        children: [
          pdf,
          const SizedBox(height: AppSpacing.md),
          const _OrBadge(),
          const SizedBox(height: AppSpacing.md),
          brochure,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: pdf),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: _OrBadge(),
        ),
        Expanded(child: brochure),
      ],
    );
  }
}

class _OrBadge extends StatelessWidget {
  const _OrBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
        color: _cardBg,
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.18),
            blurRadius: 12,
          ),
        ],
      ),
      child: Text(
        'OR',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.gold,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

class _DownloadCard extends StatefulWidget {
  const _DownloadCard({
    required this.title,
    required this.meta,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String meta;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_DownloadCard> createState() => _DownloadCardState();
}

class _DownloadCardState extends State<_DownloadCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.015 : 1,
        duration: AppDurations.fast,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: _hovered ? _cardBgHover : _cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.gold.withValues(
                    alpha: _hovered ? 0.65 : 0.32,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(
                      alpha: _hovered ? 0.16 : 0.06,
                    ),
                    blurRadius: _hovered ? 18 : 10,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _iconWell,
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.65),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.22),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Icon(widget.icon, color: AppColors.gold, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.meta,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondaryDark,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    LucideIcons.download,
                    color: AppColors.gold.withValues(alpha: 0.95),
                    size: 18,
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

class _TrustStatsBar extends StatelessWidget {
  const _TrustStatsBar({
    required this.profile,
    required this.mobile,
    required this.progress,
  });

  final AboutCompanyProfile profile;
  final bool mobile;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    final stats = profile.trustStats.take(4).toList();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? AppSpacing.lg : AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: _cardBg.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(mobile ? 22 : 999),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: mobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TrustMessage(message: profile.trustMessage),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.md,
                  children: [
                    for (final s in stats)
                      _StatCell(stat: s, progress: progress),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: _TrustMessage(message: profile.trustMessage)),
                const SizedBox(width: AppSpacing.xl),
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0)
                    Container(
                      width: 1,
                      height: 42,
                      margin: const EdgeInsets.symmetric(horizontal: 18),
                      color: AppColors.gold.withValues(alpha: 0.18),
                    ),
                  _StatCell(stat: stats[i], progress: progress),
                ],
              ],
            ),
    );
  }
}

class _TrustMessage extends StatelessWidget {
  const _TrustMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          LucideIcons.shieldCheck,
          color: AppColors.gold,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.white.withValues(alpha: 0.9),
                  height: 1.35,
                ),
          ),
        ),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.stat,
    required this.progress,
  });

  final AboutProfileTrustStat stat;
  final Animation<double> progress;

  static (int, String) _parse(String raw) {
    final match = RegExp(r'^(\d+)(.*)$').firstMatch(raw.trim());
    if (match == null) return (0, raw);
    return (int.tryParse(match.group(1)!) ?? 0, match.group(2) ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final (target, suffix) = _parse(stat.value);
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final shown = (target * progress.value).round();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$shown$suffix',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              stat.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.85),
                  ),
            ),
          ],
        );
      },
    );
  }
}
