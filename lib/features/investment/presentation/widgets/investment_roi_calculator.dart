import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:intl/intl.dart';

/// Interactive ROI calculator for the Investment Hub.
class InvestmentRoiCalculator extends HookWidget {
  const InvestmentRoiCalculator({super.key});

  @override
  Widget build(BuildContext context) {
    final amount = useState(15000000.0);
    final growth = useState(18.0);
    final years = useState(4.0);

    final projected = amount.value * math.pow(1 + growth.value / 100, years.value);
    final roi = ((projected - amount.value) / amount.value) * 100;
    final currency = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

    return context.isMobile
        ? Column(
            children: [
              _inputs(amount, growth, years),
              const SizedBox(height: AppSpacing.xl),
              _results(context, currency, amount.value, projected, roi, years.value),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _inputs(amount, growth, years)),
              const SizedBox(width: AppSpacing.xxl),
              Expanded(child: _results(context, currency, amount.value, projected, roi, years.value)),
            ],
          );
  }

  Widget _inputs(
    ValueNotifier<double> amount,
    ValueNotifier<double> growth,
    ValueNotifier<double> years,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AnimatedSectionTitle(
          overline: 'CALCULATOR',
          title: 'Investment ROI calculator',
          subtitle: 'Model projected returns across HD Homes products.',
          alignment: TextAlign.start,
        ),
        const SizedBox(height: AppSpacing.lg),
        _SliderField(
          label: 'Investment amount',
          value: amount.value,
          min: 2000000,
          max: 200000000,
          display: '₦${(amount.value / 1e6).toStringAsFixed(1)}M',
          onChanged: (v) => amount.value = v,
        ),
        _SliderField(
          label: 'Expected annual growth',
          value: growth.value,
          min: 8,
          max: 30,
          display: '${growth.value.toStringAsFixed(1)}%',
          onChanged: (v) => growth.value = v,
        ),
        _SliderField(
          label: 'Holding period (years)',
          value: years.value,
          min: 1,
          max: 10,
          display: '${years.value.toInt()} years',
          onChanged: (v) => years.value = v,
        ),
      ],
    );
  }

  Widget _results(
    BuildContext context,
    NumberFormat currency,
    double amount,
    double projected,
    double roi,
    double years,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.charcoal,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Projected returns', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.white)),
          const SizedBox(height: AppSpacing.lg),
          _Row(label: 'Projected value', value: currency.format(projected)),
          _Row(label: 'Total ROI', value: '${roi.toStringAsFixed(1)}%'),
          _Row(label: 'Annualized return', value: '${(roi / years).toStringAsFixed(1)}% avg'),
          _Row(label: 'Profit', value: currency.format(projected - amount)),
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
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: Text(label)), Text(display, style: const TextStyle(color: AppColors.gold))]),
          Slider(value: value, min: min, max: max, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSecondaryDark))),
          Text(value, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
