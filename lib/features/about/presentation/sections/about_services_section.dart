import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/about/data/models/about_cms_content.dart';
import 'package:hdhomesproject/features/about/presentation/widgets/about_icons.dart';

/// Sections 8–9 — Why choose HD Homes and our services.
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
    final columns = context.isMobile ? 1 : context.isTablet ? 2 : 4;

    return Column(
      children: [
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'WHY HD HOMES',
                title: 'Why choose HD Homes',
              ),
              const SizedBox(height: AppSpacing.xxl),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width =
                      (constraints.maxWidth - (columns - 1) * AppSpacing.base) /
                          columns;
                  return Wrap(
                    spacing: AppSpacing.base,
                    runSpacing: AppSpacing.base,
                    children: whyChoose
                        .map(
                          (item) => SizedBox(
                            width: width,
                            child: _FeatureCard(
                              title: item.title,
                              description: item.description,
                              icon: AboutIcons.resolve(item.iconName),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'WHAT WE DO',
                title: 'Our services',
                subtitle: 'End-to-end real estate solutions for buyers, investors, and partners.',
              ),
              const SizedBox(height: AppSpacing.xxl),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width =
                      (constraints.maxWidth - (columns - 1) * AppSpacing.base) /
                          columns;
                  return Wrap(
                    spacing: AppSpacing.base,
                    runSpacing: AppSpacing.base,
                    children: services
                        .map(
                          (s) => SizedBox(
                            width: width,
                            child: _ServiceCard(
                              item: s,
                              onTap: () => context.go(s.route),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatefulWidget {
  const _FeatureCard({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: AppRadius.cardBorder,
          border: Border.all(color: _hovered ? AppColors.gold : AppColors.neutral200),
          boxShadow: _hovered ? AppShadows.md : AppShadows.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(widget.icon, color: AppColors.gold),
            const SizedBox(height: AppSpacing.base),
            Text(widget.title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(widget.description, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatefulWidget {
  const _ServiceCard({required this.item, required this.onTap});

  final AboutServiceItem item;
  final VoidCallback onTap;

  @override
  State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.cardBorder,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: AppRadius.cardBorder,
          child: AnimatedContainer(
            duration: AppDurations.fast,
            transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(AboutIcons.resolve(widget.item.iconName), color: AppColors.gold),
                const SizedBox(height: AppSpacing.base),
                Text(widget.item.title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                Text(widget.item.description, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: AppSpacing.sm),
                const Text('Learn more →', style: TextStyle(color: AppColors.gold)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
