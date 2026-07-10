import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/growth/ai/investment_advisor.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/investment/data/providers/investment_cms_provider.dart';
import 'package:hdhomesproject/features/investment/presentation/widgets/investment_roi_calculator.dart';
import 'package:hdhomesproject/features/investment/presentation/widgets/investor_portal_cta.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Closing sections — ROI calculator, AI advisor, protection, testimonials, FAQ, downloads, CTA.
class InvestmentClosingSections extends HookConsumerWidget {
  const InvestmentClosingSections({
    super.key,
    this.calculatorKey,
    this.faqKey,
  });

  final GlobalKey? calculatorKey;
  final GlobalKey? faqKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cms = ref.watch(investmentHubCmsProvider);
    final insights = ref.watch(investmentInsightsProvider);
    final faqQuery = useState('');

    final filteredFaqs = cms.faqs
        .where(
          (f) =>
              faqQuery.value.isEmpty ||
              f.question.toLowerCase().contains(faqQuery.value.toLowerCase()) ||
              f.answer.toLowerCase().contains(faqQuery.value.toLowerCase()),
        )
        .toList();

    return Column(
      children: [
        SectionWrapper(
          key: calculatorKey,
          child: const InvestmentRoiCalculator(),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedSectionTitle(
                overline: 'AI ADVISOR',
                title: 'AI investment insights',
                subtitle: 'Personalized recommendations powered by the Growth Engine.',
              ),
              const SizedBox(height: AppSpacing.lg),
              ...insights.map(
                (insight) => Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.base),
                  child: ListTile(
                    leading: const Icon(LucideIcons.sparkles, color: AppColors.gold),
                    title: Text(insight.title),
                    subtitle: Text('${insight.value} · ${insight.trend}\n${insight.summary}'),
                    trailing: Chip(label: Text(insight.riskLevel)),
                  ),
                ),
              ),
            ],
          ),
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
              Text(cms.protectionSummary, style: Theme.of(context).textTheme.bodyLarge),
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
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'TESTIMONIALS',
                title: 'What our investors say',
              ),
              const SizedBox(height: AppSpacing.lg),
              ...cms.testimonials.map(
                (t) => Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.base),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('"${t.quote}"', style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: AppSpacing.sm),
                        Text(t.name, style: Theme.of(context).textTheme.titleSmall),
                        Text('${t.role} · ${t.portfolio}', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedSectionTitle(
                overline: 'DOWNLOADS',
                title: 'Investment packs & disclosures',
              ),
              const SizedBox(height: AppSpacing.lg),
              ...cms.downloads.map(
                (d) => ListTile(
                  leading: const Icon(LucideIcons.download, color: AppColors.gold),
                  title: Text(d.title),
                  trailing: Text('${d.type} · ${d.size}'),
                  onTap: () {},
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          key: faqKey,
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'FAQ',
                title: 'Investor FAQ',
                subtitle: 'Common questions about products, returns, and protections.',
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(LucideIcons.search),
                  hintText: 'Search investor questions…',
                ),
                onChanged: (v) => faqQuery.value = v,
              ),
              const SizedBox(height: AppSpacing.lg),
              ...filteredFaqs.map(
                (f) => ExpansionTile(
                  title: Text(f.question),
                  children: [Padding(padding: const EdgeInsets.all(AppSpacing.base), child: Text(f.answer))],
                ),
              ),
            ],
          ),
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
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Book a consultation with Investor Relations or download our investment overview pack.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondaryDark),
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
