import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/page_container.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/properties/data/models/property_detail_content.dart';
import 'package:intl/intl.dart';

/// Sections 4–8 — Overview, specs, pricing, mortgage, ROI.
class PropertyDetailBodySections extends StatelessWidget {
  const PropertyDetailBodySections({super.key, required this.detail});

  final PropertyDetailContent detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionWrapper(
          child: PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AnimatedSectionTitle(
                  overline: 'OVERVIEW',
                  title: 'Property overview',
                  alignment: TextAlign.start,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(detail.overview.summary, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: AppSpacing.base),
                ExpansionTile(
                  title: const Text('Architectural concept'),
                  children: [Text(detail.overview.architecturalConcept)],
                ),
                ExpansionTile(
                  title: const Text('Investment potential'),
                  children: [Text(detail.overview.investmentPotential)],
                ),
              ],
            ),
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: PageContainer(child: _SpecsGrid(specs: detail.specs)),
        ),
        SectionWrapper(
          child: PageContainer(child: _PricingSection(detail: detail)),
        ),
        SectionWrapper(
          backgroundColor: AppColors.charcoal,
          child: PageContainer(child: _MortgageCalculator(pricing: detail.pricing)),
        ),
        if (detail.investment.isInvestmentProperty)
          SectionWrapper(
            child: PageContainer(child: _InvestmentSection(investment: detail.investment)),
          ),
      ],
    );
  }
}

class _SpecsGrid extends StatelessWidget {
  const _SpecsGrid({required this.specs});

  final PropertySpecs specs;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Bedrooms', '${specs.bedrooms}'),
      ('Bathrooms', '${specs.bathrooms}'),
      ('Toilets', '${specs.toilets}'),
      ('Kitchens', '${specs.kitchens}'),
      ('Parking', '${specs.parkingSpaces}'),
      ('Floor Area', specs.floorArea),
      ('Land Area', specs.landArea),
      ('Floors', '${specs.floors}'),
      ('Year Built', specs.yearBuilt),
      ('Power', specs.powerSupply),
      ('Water', specs.waterSupply),
      ('Internet', specs.internetConnectivity),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AnimatedSectionTitle(
          overline: 'SPECIFICATIONS',
          title: 'Property specifications',
          alignment: TextAlign.start,
        ),
        const SizedBox(height: AppSpacing.xl),
        Wrap(
          spacing: AppSpacing.base,
          runSpacing: AppSpacing.base,
          children: items
              .map(
                (e) => SizedBox(
                  width: context.isMobile ? double.infinity : 200,
                  child: _SpecCard(label: e.$1, value: e.$2),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _SpecCard extends StatelessWidget {
  const _SpecCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _PricingSection extends StatelessWidget {
  const _PricingSection({required this.detail});

  final PropertyDetailContent detail;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AnimatedSectionTitle(
          overline: 'PRICING',
          title: 'Pricing & payment plans',
          alignment: TextAlign.start,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Base price: ${currency.format(detail.pricing.basePrice)}',
            style: Theme.of(context).textTheme.titleLarge),
        Text('Reservation fee: ${currency.format(detail.pricing.reservationFee)}'),
        Text(detail.pricing.taxesAndFees),
        const SizedBox(height: AppSpacing.lg),
        for (final plan in detail.paymentPlans)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.base),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: AppRadius.cardBorder,
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.name, style: Theme.of(context).textTheme.titleMedium),
                Text('Down: ${currency.format(plan.downPayment)}'),
                Text('Monthly: ${currency.format(plan.monthlyInstallment)} · ${plan.durationMonths} months'),
              ],
            ),
          ),
        PrimaryButton(
          label: 'Apply for Plan',
          onPressed: () {},
        ),
      ],
    );
  }
}

class _MortgageCalculator extends HookWidget {
  const _MortgageCalculator({required this.pricing});

  final PropertyPricing pricing;

  @override
  Widget build(BuildContext context) {
    final deposit = useState(pricing.basePrice * 0.2);
    final rate = useState(14.0);
    final years = useState(20.0);
    final currency = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

    final principal = pricing.basePrice - deposit.value;
    final monthlyRate = rate.value / 100 / 12;
    final months = years.value * 12;
    final payment = monthlyRate > 0
        ? principal *
            (monthlyRate * math.pow(1 + monthlyRate, months)) /
            (math.pow(1 + monthlyRate, months) - 1)
        : principal / months;
    final total = deposit.value + payment * months;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AnimatedSectionTitle(
          overline: 'MORTGAGE',
          title: 'Mortgage calculator',
          alignment: TextAlign.start,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Monthly: ${currency.format(payment)}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.gold)),
        Text('Total repayment: ${currency.format(total)}',
            style: const TextStyle(color: AppColors.white)),
        const SizedBox(height: AppSpacing.lg),
        Slider(
          value: deposit.value,
          min: 0,
          max: pricing.basePrice * 0.5,
          onChanged: (v) => deposit.value = v,
        ),
        Slider(value: rate.value, min: 5, max: 25, onChanged: (v) => rate.value = v),
        Slider(value: years.value, min: 5, max: 30, onChanged: (v) => years.value = v),
      ],
    );
  }
}

class _InvestmentSection extends StatelessWidget {
  const _InvestmentSection({required this.investment});

  final PropertyInvestmentDetail investment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AnimatedSectionTitle(
          overline: 'INVESTMENT',
          title: 'ROI & investment analysis',
          alignment: TextAlign.start,
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.xl,
          runSpacing: AppSpacing.base,
          children: [
            _inv('Expected ROI', investment.expectedRoi),
            _inv('Rental Yield', investment.rentalYield),
            _inv('Appreciation', investment.capitalAppreciation),
            _inv('Payback', investment.paybackPeriod),
            _inv('Occupancy', investment.occupancyForecast),
            _inv('Score', '${investment.investmentScore}/100'),
            _inv('Risk', investment.riskLevel),
          ],
        ),
      ],
    );
  }

  Widget _inv(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.gold)),
      ],
    );
  }
}
