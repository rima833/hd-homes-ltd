import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
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
    final overview = detail.overview;
    final showOverview = overview.summary.trim().isNotEmpty ||
        overview.architecturalConcept.trim().isNotEmpty ||
        overview.investmentPotential.trim().isNotEmpty;
    final specs = _visibleSpecs(detail.specs);
    final showInvestment = _hasInvestmentCopy(detail.investment);

    return Column(
      children: [
        if (showOverview)
          SectionWrapper(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AnimatedSectionTitle(
                  overline: 'OVERVIEW',
                  title: 'Property overview',
                  alignment: TextAlign.start,
                ),
                if (overview.summary.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    overview.summary,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
                if (overview.architecturalConcept.trim().isNotEmpty)
                  ExpansionTile(
                    title: const Text('Architectural concept'),
                    children: [Text(overview.architecturalConcept)],
                  ),
                if (overview.investmentPotential.trim().isNotEmpty)
                  ExpansionTile(
                    title: const Text('Investment potential'),
                    children: [Text(overview.investmentPotential)],
                  ),
              ],
            ),
          ),
        if (specs.isNotEmpty)
          SectionWrapper(
            backgroundColor: Theme.of(context).colorScheme.surface,
            child: _SpecsGrid(items: specs),
          ),
        if (detail.pricing.basePrice > 0)
          SectionWrapper(
            child: _PricingSection(detail: detail),
          ),
        if (detail.pricing.showMortgageCalculator &&
            detail.pricing.basePrice > 0)
          SectionWrapper(
            backgroundColor: AppColors.charcoal,
            child: _MortgageCalculator(
              key: ValueKey(
                '${detail.listing.id}-'
                '${detail.pricing.basePrice}-'
                '${detail.pricing.mortgageDepositPercent}-'
                '${detail.pricing.mortgageInterestRate}-'
                '${detail.pricing.mortgageTermYears}',
              ),
              pricing: detail.pricing,
            ),
          ),
        if (showInvestment)
          SectionWrapper(
            child: _InvestmentSection(investment: detail.investment),
          ),
      ],
    );
  }
}

List<(String, String)> _visibleSpecs(PropertySpecs specs) {
  bool keep(String value) {
    final trimmed = value.trim();
    return trimmed.isNotEmpty && trimmed != '0' && trimmed != '—';
  }

  final items = <(String, String)>[
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
  return [
    for (final item in items)
      if (keep(item.$2)) item,
  ];
}

bool _hasInvestmentCopy(PropertyInvestmentDetail investment) {
  bool filled(String value) {
    final trimmed = value.trim();
    return trimmed.isNotEmpty && trimmed != '—' && trimmed != '-';
  }

  return filled(investment.expectedRoi) ||
      filled(investment.rentalYield) ||
      filled(investment.capitalAppreciation) ||
      filled(investment.paybackPeriod) ||
      filled(investment.occupancyForecast) ||
      filled(investment.riskLevel) ||
      investment.investmentScore > 0;
}

class _SpecsGrid extends StatelessWidget {
  const _SpecsGrid({required this.items});

  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardBorder,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.deepBlack,
                AppColors.charcoal,
                AppColors.gold.withValues(alpha: 0.28),
              ],
            ),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Base price',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
              ),
              Text(
                currency.format(detail.pricing.basePrice),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              if (detail.pricing.reservationFee > 0)
                Text(
                  'Reservation fee: ${currency.format(detail.pricing.reservationFee)}',
                  style: const TextStyle(color: AppColors.white),
                ),
              if (detail.pricing.taxesAndFees.trim().isNotEmpty)
                Text(
                  detail.pricing.taxesAndFees,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final plan in detail.paymentPlans)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.base),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: AppRadius.cardBorder,
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.deepBlack.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text('Down: ${currency.format(plan.downPayment)}'),
                Text(
                  'Monthly: ${currency.format(plan.monthlyInstallment)} · ${plan.durationMonths} months',
                ),
              ],
            ),
          ),
        if (detail.paymentPlans.isNotEmpty)
          PrimaryButton(
            label: 'Apply for Plan',
            onPressed: () => context.go(RoutePaths.paymentCalculator),
          ),
      ],
    );
  }
}

class _MortgageCalculator extends HookWidget {
  const _MortgageCalculator({super.key, required this.pricing});

  final PropertyPricing pricing;

  double _span(double min, double max, double fallback) {
    if (max > min) return max;
    return min + fallback;
  }

  @override
  Widget build(BuildContext context) {
    final price = pricing.basePrice.toDouble();
    final depositMinPct = pricing.mortgageDepositMinPercent.clamp(0, 90);
    final depositMaxPct = _span(
      depositMinPct.toDouble(),
      pricing.mortgageDepositMaxPercent,
      10,
    ).clamp(depositMinPct.toDouble(), 100).toDouble();
    final depositDefault = pricing.mortgageDepositPercent
        .clamp(depositMinPct, depositMaxPct)
        .toDouble();
    final rateMin = pricing.mortgageInterestMin.clamp(0, 100).toDouble();
    final rateMax = _span(rateMin, pricing.mortgageInterestMax, 1);
    final rateDefault =
        pricing.mortgageInterestRate.clamp(rateMin, rateMax).toDouble();
    final yearsMin = pricing.mortgageTermMinYears.clamp(1, 40).toDouble();
    final yearsMax = _span(yearsMin, pricing.mortgageTermMaxYears, 1);
    final yearsDefault =
        pricing.mortgageTermYears.clamp(yearsMin, yearsMax).toDouble();

    final deposit = useState(price * (depositDefault / 100));
    final rate = useState(rateDefault);
    final years = useState(yearsDefault);
    final currency = NumberFormat.currency(
      locale: 'en_NG',
      symbol: '₦',
      decimalDigits: 0,
    );

    final depositFloor = price * (depositMinPct / 100);
    final depositCeil = price * (depositMaxPct / 100);
    final principal = (price - deposit.value).clamp(0, price);
    final monthlyRate = rate.value / 100 / 12;
    final months = years.value * 12;
    final payment = principal <= 0
        ? 0.0
        : monthlyRate > 0
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
        Text(
          'Monthly: ${currency.format(payment)}',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.gold,
              ),
        ),
        Text(
          'Total repayment: ${currency.format(total)}',
          style: const TextStyle(color: AppColors.white),
        ),
        const SizedBox(height: AppSpacing.lg),
        _MortgageSlider(
          label: 'Deposit',
          valueLabel: currency.format(deposit.value),
          minLabel: currency.format(depositFloor),
          maxLabel: currency.format(depositCeil),
          value: deposit.value.clamp(depositFloor, depositCeil).toDouble(),
          min: depositFloor,
          max: depositCeil <= depositFloor ? depositFloor + 1 : depositCeil,
          onChanged: (v) => deposit.value = v,
        ),
        _MortgageSlider(
          label: 'Interest',
          valueLabel: '${rate.value.toStringAsFixed(1)}%',
          minLabel: '${rateMin.toStringAsFixed(0)}%',
          maxLabel: '${rateMax.toStringAsFixed(0)}%',
          value: rate.value.clamp(rateMin, rateMax).toDouble(),
          min: rateMin,
          max: rateMax,
          onChanged: (v) => rate.value = v,
        ),
        _MortgageSlider(
          label: 'Term',
          valueLabel: '${years.value.round()} years',
          minLabel: '${yearsMin.round()} yrs',
          maxLabel: '${yearsMax.round()} yrs',
          value: years.value.clamp(yearsMin, yearsMax).toDouble(),
          min: yearsMin,
          max: yearsMax,
          onChanged: (v) => years.value = v,
        ),
      ],
    );
  }
}

class _MortgageSlider extends StatelessWidget {
  const _MortgageSlider({
    required this.label,
    required this.valueLabel,
    required this.minLabel,
    required this.maxLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final String minLabel;
  final String maxLabel;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  valueLabel,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            activeColor: AppColors.gold,
            inactiveColor: Colors.white24,
            onChanged: onChanged,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                minLabel,
                style: const TextStyle(color: AppColors.white, fontSize: 12),
              ),
              Text(
                maxLabel,
                style: const TextStyle(color: AppColors.white, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
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
            if (_filled(investment.expectedRoi))
              _inv('Expected ROI', investment.expectedRoi),
            if (_filled(investment.rentalYield))
              _inv('Rental Yield', investment.rentalYield),
            if (_filled(investment.capitalAppreciation))
              _inv('Appreciation', investment.capitalAppreciation),
            if (_filled(investment.paybackPeriod))
              _inv('Payback', investment.paybackPeriod),
            if (_filled(investment.occupancyForecast))
              _inv('Occupancy', investment.occupancyForecast),
            if (investment.investmentScore > 0)
              _inv('Score', '${investment.investmentScore}/100'),
            if (_filled(investment.riskLevel))
              _inv('Risk', investment.riskLevel),
          ],
        ),
      ],
    );
  }

  bool _filled(String value) {
    final trimmed = value.trim();
    return trimmed.isNotEmpty && trimmed != '—' && trimmed != '-';
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
