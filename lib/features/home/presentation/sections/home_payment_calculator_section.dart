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
import 'package:intl/intl.dart';

/// Section 13 — Payment plan calculator.
class HomePaymentCalculatorSection extends HookWidget {
  const HomePaymentCalculatorSection({super.key});

  @override
  Widget build(BuildContext context) {
    final price = useState(50000000.0);
    final deposit = useState(10000000.0);
    final months = useState(24.0);
    final rate = useState(12.0);

    final principal = (price.value - deposit.value).clamp(0, double.infinity);
    final monthlyRate = rate.value / 100 / 12;
    final monthlyPayment = monthlyRate > 0
        ? principal *
            (monthlyRate * math.pow(1 + monthlyRate, months.value)) /
            (math.pow(1 + monthlyRate, months.value) - 1)
        : principal / months.value;
    final total = deposit.value + monthlyPayment * months.value;
    final currency = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

    return SectionWrapper(
      child: context.isMobile
          ? Column(children: _children(context, price, deposit, months, rate,
              currency, monthlyPayment, total))
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _inputs(context, price, deposit, months, rate),
                ),
                const SizedBox(width: AppSpacing.xxl),
                Expanded(
                  child: _results(
                    context,
                    currency,
                    monthlyPayment,
                    total,
                    months.value.toInt(),
                  ),
                ),
              ],
            ),
    );
  }

  List<Widget> _children(
    BuildContext context,
    ValueNotifier<double> price,
    ValueNotifier<double> deposit,
    ValueNotifier<double> months,
    ValueNotifier<double> rate,
    NumberFormat currency,
    double monthlyPayment,
    double total,
  ) =>
      [
        _inputs(context, price, deposit, months, rate),
        const SizedBox(height: AppSpacing.xl),
        _results(context, currency, monthlyPayment, total, months.value.toInt()),
      ];

  Widget _inputs(
    BuildContext context,
    ValueNotifier<double> price,
    ValueNotifier<double> deposit,
    ValueNotifier<double> months,
    ValueNotifier<double> rate,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AnimatedSectionTitle(
          overline: 'PAYMENT PLANS',
          title: 'Payment plan calculator',
          subtitle: 'Estimate monthly installments for your dream home.',
          alignment: TextAlign.start,
        ),
        const SizedBox(height: AppSpacing.lg),
        _SliderField(
          label: 'Property Price',
          value: price.value,
          min: 10000000,
          max: 200000000,
          divisions: 19,
          display: '₦${(price.value / 1e6).toStringAsFixed(1)}M',
          onChanged: (v) => price.value = v,
        ),
        _SliderField(
          label: 'Deposit',
          value: deposit.value,
          min: 0,
          max: price.value,
          divisions: 20,
          display: '₦${(deposit.value / 1e6).toStringAsFixed(1)}M',
          onChanged: (v) => deposit.value = v,
        ),
        _SliderField(
          label: 'Duration (months)',
          value: months.value,
          min: 6,
          max: 48,
          divisions: 14,
          display: '${months.value.toInt()} months',
          onChanged: (v) => months.value = v,
        ),
        _SliderField(
          label: 'Interest (%)',
          value: rate.value,
          min: 0,
          max: 24,
          divisions: 24,
          display: '${rate.value.toStringAsFixed(1)}%',
          onChanged: (v) => rate.value = v,
        ),
      ],
    );
  }

  Widget _results(
    BuildContext context,
    NumberFormat currency,
    double monthly,
    double total,
    int months,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: AppColors.goldGradient,
        borderRadius: AppRadius.cardBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your estimate', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          _ResultRow(label: 'Monthly payment', value: currency.format(monthly)),
          _ResultRow(label: 'Total cost', value: currency.format(total)),
          _ResultRow(label: 'Installments', value: '$months months'),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Apply for Plan',
            onPressed: () => context.go(RoutePaths.contact),
          ),
        ],
      ),
    );
  }

}

class _SliderField extends StatelessWidget {
  const _SliderField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(label, style: Theme.of(context).textTheme.labelLarge)),
              Text(
                display,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.gold,
                    ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
