import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/about/data/models/about_cms_content.dart';
import 'package:hdhomesproject/features/about/presentation/widgets/about_icons.dart';
import 'package:hdhomesproject/features/home/presentation/widgets/animated_statistic.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Sections 10–14 — Awards, partners, CSR, sustainability, process.
class AboutImpactSection extends StatelessWidget {
  const AboutImpactSection({
    super.key,
    required this.awards,
    required this.partners,
    required this.csr,
    required this.sustainability,
    required this.process,
  });

  final List<AboutAwardItem> awards;
  final List<AboutPartnerItem> partners;
  final AboutCsrContent csr;
  final List<AboutSustainabilityItem> sustainability;
  final List<AboutProcessStep> process;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionWrapper(
          backgroundColor: AppColors.charcoal,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'RECOGNITION',
                title: 'Awards & certifications',
              ),
              const SizedBox(height: AppSpacing.xl),
              for (final award in awards)
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.gold,
                    child: Icon(LucideIcons.award, color: AppColors.deepBlack, size: 18),
                  ),
                  title: Text(award.title, style: const TextStyle(color: AppColors.white)),
                  subtitle: Text(
                    '${award.issuer} · ${award.year}\n${award.description}',
                    style: const TextStyle(color: AppColors.textSecondaryDark),
                  ),
                  isThreeLine: true,
                ),
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'PARTNERS',
                title: 'Partners & affiliations',
              ),
              const SizedBox(height: AppSpacing.xl),
              _PartnerCarousel(partners: partners),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedSectionTitle(
                overline: 'CSR',
                title: 'Corporate social responsibility',
                subtitle: 'Building communities beyond bricks and mortar.',
                alignment: TextAlign.start,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(csr.intro),
              const SizedBox(height: AppSpacing.xl),
              for (final initiative in csr.initiatives)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.base),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(LucideIcons.heartHandshake, color: AppColors.gold),
                    title: Text(initiative.title),
                    subtitle: Text(initiative.description),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.xl,
                children: csr.impactStats
                    .map(
                      (s) => AnimatedStatistic(
                        value: s.value,
                        label: s.label,
                        suffix: s.suffix,
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'SUSTAINABILITY',
                title: 'Building responsibly',
              ),
              const SizedBox(height: AppSpacing.xl),
              Wrap(
                spacing: AppSpacing.base,
                runSpacing: AppSpacing.base,
                children: sustainability
                    .map(
                      (s) => SizedBox(
                        width: context.isMobile ? double.infinity : 280,
                        child: _SustainabilityCard(item: s),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: AppColors.charcoal,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'HOW WE WORK',
                title: 'Our client journey',
                subtitle: 'A transparent process from first inquiry to after-sales support.',
              ),
              const SizedBox(height: AppSpacing.xxl),
              ...process.asMap().entries.map((entry) {
                final step = entry.value;
                final isLast = entry.key == process.length - 1;
                return _ProcessStepRow(step: step, showConnector: !isLast);
              }),
            ],
          ),
        ),
      ],
    );
  }
}

/// Auto-scrolling partner logo carousel.
class _PartnerCarousel extends StatefulWidget {
  const _PartnerCarousel({required this.partners});

  final List<AboutPartnerItem> partners;

  @override
  State<_PartnerCarousel> createState() => _PartnerCarouselState();
}

class _PartnerCarouselState extends State<_PartnerCarousel> {
  final _controller = ScrollController();
  Timer? _timer;
  bool _forward = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoScroll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!mounted || !_controller.hasClients) return;
      final max = _controller.position.maxScrollExtent;
      if (max <= 0) return;
      final next = _controller.offset + (_forward ? 1.0 : -1.0);
      if (next >= max) _forward = false;
      if (next <= 0) _forward = true;
      _controller.jumpTo(next.clamp(0, max));
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = [...widget.partners, ...widget.partners];

    return SizedBox(
      height: 80,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, index) => const SizedBox(width: AppSpacing.base),
        itemBuilder: (context, index) {
          final p = items[index];
          return _PartnerLogo(name: p.name, category: p.category);
        },
      ),
    );
  }
}

class _PartnerLogo extends StatelessWidget {
  const _PartnerLogo({required this.name, required this.category});

  final String name;
  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.neutral200),
        borderRadius: AppRadius.cardBorder,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(name, style: Theme.of(context).textTheme.labelLarge, textAlign: TextAlign.center),
          Text(category, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _SustainabilityCard extends StatelessWidget {
  const _SustainabilityCard({required this.item});

  final AboutSustainabilityItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Row(
        children: [
          Icon(AboutIcons.resolve(item.iconName), color: AppColors.gold),
          const SizedBox(width: AppSpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: Theme.of(context).textTheme.titleSmall),
                Text(item.description, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcessStepRow extends StatelessWidget {
  const _ProcessStepRow({required this.step, required this.showConnector});

  final AboutProcessStep step;
  final bool showConnector;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.gold,
              child: Icon(AboutIcons.resolve(step.iconName), color: AppColors.deepBlack, size: 18),
            ),
            if (showConnector)
              Container(
                width: 2,
                height: 48,
                color: AppColors.gold.withValues(alpha: 0.4),
              ),
          ],
        ),
        const SizedBox(width: AppSpacing.base),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        step.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.white,
                            ),
                      ),
                    ),
                    Text(
                      step.timeline,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.gold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  step.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
