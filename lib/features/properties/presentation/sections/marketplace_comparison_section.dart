import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_property.dart';
import 'package:hdhomesproject/features/properties/data/providers/marketplace_controller.dart';
import 'package:hdhomesproject/features/properties/data/providers/marketplace_listings_provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Section 8 — Property comparison + estate explorer.
class MarketplaceComparisonSection extends ConsumerWidget {
  const MarketplaceComparisonSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final properties = ref.watch(comparePropertiesProvider);
    if (properties.isEmpty) return const SizedBox.shrink();

    return SectionWrapper(
      backgroundColor: AppColors.charcoal,
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: AnimatedSectionTitle(
                  overline: 'COMPARE',
                  title: 'Side-by-side comparison',
                  subtitle: 'Compare up to 4 properties. Export PDF coming soon.',
                  alignment: TextAlign.start,
                ),
              ),
              PrimaryButton(
                label: 'Clear',
                variant: ButtonVariant.ghost,
                onPressed: () =>
                    ref.read(marketplaceCompareProvider.notifier).state = [],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.darkSurface),
              columns: [
                const DataColumn(label: Text('Field', style: TextStyle(color: AppColors.white))),
                ...properties.map(
                  (p) => DataColumn(
                    label: SizedBox(
                      width: 140,
                      child: Text(p.title, style: const TextStyle(color: AppColors.gold)),
                    ),
                  ),
                ),
              ],
              rows: [
                _row('Price', properties.map((p) => p.price).toList()),
                _row('Location', properties.map((p) => p.location).toList()),
                _row('Type', properties.map((p) => p.type).toList()),
                _row('Bedrooms', properties.map((p) => '${p.bedrooms}').toList()),
                _row('Bathrooms', properties.map((p) => '${p.bathrooms}').toList()),
                _row('Land Size', properties.map((p) => p.landSize).toList()),
                _row('Status', properties.map((p) => p.status).toList()),
                _row('ROI', properties.map((p) => p.roiEstimate).toList()),
                _row('Match Score', properties.map((p) => '${p.matchScore}%').toList()),
                _row('Invest Score', properties.map((p) => '${p.investmentScore}').toList()),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Export PDF',
            icon: LucideIcons.download,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PDF export coming soon')),
              );
            },
          ),
        ],
      ),
    );
  }

  DataRow _row(String label, List<String> values) {
    return DataRow(
      cells: [
        DataCell(Text(label, style: const TextStyle(color: AppColors.textSecondaryDark))),
        ...values.map((v) => DataCell(Text(v, style: const TextStyle(color: AppColors.white)))),
      ],
    );
  }
}

/// Section 11 — Investment highlights.
class MarketplaceInvestmentSection extends ConsumerWidget {
  const MarketplaceInvestmentSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final investments = ref
        .watch(marketplaceListingsProvider)
        .where((p) => p.purpose == PropertyPurpose.invest || p.category == PropertyCategory.investment)
        .toList()
      ..sort((a, b) => b.investmentScore.compareTo(a.investmentScore));

    if (investments.isEmpty) return const SizedBox.shrink();

    return SectionWrapper(
      child: Column(
        children: [
          const AnimatedSectionTitle(
            overline: 'INVESTMENT',
            title: 'Investment opportunity ranking',
            subtitle: 'Dynamic investment scores based on appreciation, demand, and progress.',
          ),
          const SizedBox(height: AppSpacing.xl),
          ...investments.take(4).map((p) => _InvestmentRow(property: p)),
        ],
      ),
    );
  }
}

class _InvestmentRow extends StatelessWidget {
  const _InvestmentRow({required this.property});

  final MarketplaceProperty property;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.base),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.neutral200),
      ),
      child: context.isMobile
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: _cells(context))
          : Row(children: _cells(context)),
    );
  }

  List<Widget> _cells(BuildContext context) => [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(property.title, style: Theme.of(context).textTheme.titleSmall),
              Text(property.location, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        _metric('ROI', property.roiEstimate),
        _metric('Yield', property.rentalYield),
        _metric('Growth', property.capitalAppreciation),
        _metric('Risk', property.riskLevel),
        SizedBox(
          width: 72,
          child: Column(
            children: [
              Text(
                '${property.investmentScore}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.gold),
              ),
              const Text('Score', style: TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ];

  Widget _metric(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
