import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/digital_trust_center.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/home/data/models/home_cms_content.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Section 18 — Client success stories.
class HomeTestimonialsSection extends StatelessWidget {
  const HomeTestimonialsSection({super.key, required this.items});

  final List<HomeTestimonialItem> items;

  @override
  Widget build(BuildContext context) {
    return SectionWrapper(
      child: Column(
        children: [
          const AnimatedSectionTitle(
            overline: 'CLIENT STORIES',
            title: 'Success stories',
            subtitle: 'Verified experiences from homeowners and investors.',
          ),
          const SizedBox(height: AppSpacing.xxl),
          SizedBox(
            height: context.isMobile ? 260 : 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.base),
              itemBuilder: (context, index) {
                final item = items[index];
                return SizedBox(
                  width: 360,
                  child: _TestimonialCard(item: item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  const _TestimonialCard({required this.item});

  final HomeTestimonialItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.cardBorder,
        boxShadow: AppShadows.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ...List.generate(
                5,
                (i) => Icon(
                  i < item.rating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: AppColors.gold,
                  size: 18,
                ),
              ),
              const Spacer(),
              if (item.verified)
                const Row(
                  children: [
                    Icon(LucideIcons.badgeCheck, size: 14, color: AppColors.gold),
                    SizedBox(width: 4),
                    Text('Verified', style: TextStyle(fontSize: 12)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          Expanded(
            child: Text(
              '"${item.quote}"',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          Text(item.name, style: Theme.of(context).textTheme.titleSmall),
          Text(item.role, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Section 19 — Partners (wraps trust center partners strip).
class HomePartnersSection extends StatelessWidget {
  const HomePartnersSection({super.key, required this.partners});

  final List<HomePartnerItem> partners;

  @override
  Widget build(BuildContext context) {
    return SectionWrapper(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          const AnimatedSectionTitle(
            overline: 'PARTNERS & CERTIFICATIONS',
            title: 'Trusted partnerships',
          ),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.base,
            runSpacing: AppSpacing.base,
            alignment: WrapAlignment.center,
            children: partners
                .map(
                  (p) => Chip(
                    avatar: const Icon(LucideIcons.building2, size: 16),
                    label: Text('${p.name} · ${p.category}'),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: AppSpacing.section),
          const DigitalTrustCenter(),
        ],
      ),
    );
  }
}

/// Section 20 — Company awards.
class HomeAwardsSection extends StatelessWidget {
  const HomeAwardsSection({super.key, required this.awards});

  final List<HomeAwardItem> awards;

  @override
  Widget build(BuildContext context) {
    return SectionWrapper(
      child: Column(
        children: [
          const AnimatedSectionTitle(
            overline: 'RECOGNITION',
            title: 'Awards & achievements',
          ),
          const SizedBox(height: AppSpacing.xxl),
          for (final award in awards)
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.gold,
                child: Icon(LucideIcons.award, color: AppColors.deepBlack, size: 18),
              ),
              title: Text(award.title),
              subtitle: Text('${award.issuer} · ${award.year}'),
            ),
        ],
      ),
    );
  }
}
