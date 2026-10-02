import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/published_faq_section.dart';
import 'package:hdhomesproject/core/website/components/published_testimonials_section.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/investment/data/providers/investment_cms_provider.dart';
import 'package:hdhomesproject/features/investment/presentation/widgets/investment_roi_calculator.dart';
import 'package:hdhomesproject/features/investment/presentation/widgets/investor_portal_cta.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Closing sections — ROI calculator, protection, testimonials, FAQ, CTA.
class InvestmentClosingSections extends ConsumerWidget {
  const InvestmentClosingSections({super.key, this.calculatorKey, this.faqKey});

  final GlobalKey? calculatorKey;
  final GlobalKey? faqKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cms = ref.watch(investmentHubCmsProvider);

    return Column(
      children: [
        SectionWrapper(
          key: calculatorKey,
          backgroundColor: const Color(0xFF0A0A0A),
          child: const InvestmentRoiCalculator(),
        ),
        SectionWrapper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedSectionTitle(
                overline: 'PROTECTION',
                title: 'Investor protection',
                subtitle: 'Escrow, due diligence, and contractual safeguards.',
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                cms.protectionSummary,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'View Trust Center',
                icon: LucideIcons.shield,
                variant: ButtonVariant.secondary,
                onPressed: () => context.go(RoutePaths.trust),
              ),
            ],
          ),
        ),
        const PublishedTestimonialsSection(
          backgroundColor: AppColors.charcoal,
          title: 'What our investors say',
          subtitle:
              'Verified experiences from portfolio partners and diaspora investors.',
        ),
        PublishedFaqSection(
          sectionKey: faqKey,
          title: 'Frequently asked questions',
          subtitle:
              'Answers published from the website FAQ desk.',
        ),
        const InvestorPortalCtaSection(),
        SectionWrapper(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xxl),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.charcoal, AppColors.deepBlack],
              ),
              borderRadius: AppRadius.cardBorder,
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text(
                  'Ready to build your property portfolio?',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(color: AppColors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Book a consultation with Investor Relations or explore current opportunities.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                Wrap(
                  spacing: AppSpacing.base,
                  runSpacing: AppSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    PrimaryButton(
                      label: 'Book Investor Consultation',
                      icon: LucideIcons.calendar,
                      onPressed: () => context.go(RoutePaths.contact),
                    ),
                    PrimaryButton(
                      label: 'Explore Estates',
                      variant: ButtonVariant.secondary,
                      icon: LucideIcons.building2,
                      onPressed: () => context.go(RoutePaths.estates),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
