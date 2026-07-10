import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/cta_banner.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/core/widgets/inputs/app_text_field.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_property.dart';
import 'package:hdhomesproject/features/properties/data/providers/marketplace_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Sections 12, 14, 15, 16 — Insights, alerts, FAQ, CTA.
class MarketplaceClosingSection extends HookConsumerWidget {
  const MarketplaceClosingSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cms = ref.watch(marketplaceCmsProvider);
    final email = useTextEditingController();

    return Column(
      children: [
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'MARKET DATA',
                title: 'Market insights',
              ),
              const SizedBox(height: AppSpacing.xl),
              Wrap(
                spacing: AppSpacing.base,
                runSpacing: AppSpacing.base,
                children: cms.insights
                    .map(
                      (i) => SizedBox(
                        width: context.isMobile ? double.infinity : 280,
                        child: _InsightCard(insight: i),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedSectionTitle(
                overline: 'PROPERTY ALERTS',
                title: 'Get notified',
                subtitle: 'Subscribe to new listings, price drops, and investment opportunities.',
                alignment: TextAlign.start,
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  'New Listings',
                  'Price Drops',
                  'Investment Opportunities',
                  'New Estates',
                ].map((t) => FilterChip(label: Text(t), onSelected: (_) {})).toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: email,
                      hint: 'Email address',
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.base),
                  PrimaryButton(
                    label: 'Subscribe',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Alert subscription saved')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: AppColors.charcoal,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'FAQ',
                title: 'Frequently asked questions',
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final faq in cms.faqs)
                ExpansionTile(
                  title: Text(faq.question, style: const TextStyle(color: AppColors.white)),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        faq.answer,
                        style: const TextStyle(color: AppColors.textSecondaryDark),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.pagePadding,
            vertical: AppSpacing.section,
          ),
          child: CtaBanner(
            title: 'Ready to find your property?',
            subtitle: 'Book an inspection, talk to sales, or explore investment opportunities.',
            primaryLabel: 'Book Inspection',
            primaryPath: RoutePaths.bookInspection,
            secondaryLabel: 'Contact Sales',
            secondaryPath: RoutePaths.contact,
          ),
        ),
        SectionWrapper(
          child: Wrap(
            spacing: AppSpacing.base,
            alignment: WrapAlignment.center,
            children: [
              PrimaryButton(
                label: 'Become an Investor',
                icon: LucideIcons.trendingUp,
                onPressed: () => context.go(RoutePaths.investment),
              ),
              PrimaryButton(
                label: 'Request Callback',
                variant: ButtonVariant.secondary,
                onPressed: () => context.go(RoutePaths.contact),
              ),
              PrimaryButton(
                label: 'Register',
                variant: ButtonVariant.ghost,
                onPressed: () => context.go(RoutePaths.register),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});

  final MarketplaceInsight insight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(insight.title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(
            insight.value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.gold),
          ),
          Text('${insight.trend} · ${insight.summary}',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
