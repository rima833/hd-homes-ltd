import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Digital trust center — registrations, certifications, milestones.
class DigitalTrustCenter extends StatelessWidget {
  const DigitalTrustCenter({
    super.key,
    this.items = _defaultItems,
  });

  final List<TrustItem> items;

  static const _defaultItems = [
    TrustItem(
      icon: LucideIcons.badgeCheck,
      title: 'Registered Developer',
      subtitle: 'Corporate Affairs Commission verified',
    ),
    TrustItem(
      icon: LucideIcons.shieldCheck,
      title: 'Licensed & Insured',
      subtitle: 'Full regulatory compliance',
    ),
    TrustItem(
      icon: LucideIcons.award,
      title: 'Industry Awards',
      subtitle: 'Recognized excellence in development',
    ),
    TrustItem(
      icon: LucideIcons.hardHat,
      title: 'Construction Milestones',
      subtitle: 'Transparent project delivery',
    ),
    TrustItem(
      icon: LucideIcons.users,
      title: 'Verified Testimonials',
      subtitle: 'Real clients, real results',
    ),
    TrustItem(
      icon: LucideIcons.network,
      title: 'Partner Network',
      subtitle: 'Trusted institutional partners',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SectionWrapper(
      child: Column(
        children: [
          const AnimatedSectionTitle(
            overline: 'TRUST CENTER',
            title: 'Built on transparency and proven delivery',
            subtitle:
                'Every HD Homes project is backed by verifiable credentials, milestones, and partnerships.',
            alignment: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = context.isMobile
                  ? 1
                  : context.isTablet
                      ? 2
                      : 3;
              final itemWidth =
                  (constraints.maxWidth - (columns - 1) * AppSpacing.base) /
                      columns;

              return Wrap(
                spacing: AppSpacing.base,
                runSpacing: AppSpacing.base,
                children: items
                    .map(
                      (item) => SizedBox(
                        width: itemWidth,
                        child: _TrustCard(item: item),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class TrustItem {
  const TrustItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

class _TrustCard extends StatelessWidget {
  const _TrustCard({required this.item});

  final TrustItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.neutral200),
        boxShadow: AppShadows.md,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(item.icon, color: AppColors.gold, size: 22),
          ),
          const SizedBox(width: AppSpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  item.subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondaryLight,
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
