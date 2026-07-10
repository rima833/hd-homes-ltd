import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/investment/data/models/investment_hub_content.dart';

class InvestmentOpportunityCard extends StatefulWidget {
  const InvestmentOpportunityCard({super.key, required this.opportunity});

  final InvestmentOpportunity opportunity;

  @override
  State<InvestmentOpportunityCard> createState() => _InvestmentOpportunityCardState();
}

class _InvestmentOpportunityCardState extends State<InvestmentOpportunityCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final o = widget.opportunity;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: AppRadius.cardBorder,
          boxShadow: _hovered ? AppShadows.lg : AppShadows.md,
        ),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.cardBorder,
          child: InkWell(
            onTap: () {
              if (o.estateSlug != null) {
                context.go('${RoutePaths.estates}/${o.estateSlug}');
              }
            },
            borderRadius: AppRadius.cardBorder,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Chip(
                        label: Text(o.type.label),
                        backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                      ),
                      const Spacer(),
                      Text(o.status, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(o.title, style: Theme.of(context).textTheme.titleMedium),
                  Text(o.location, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.sm),
                  Text(o.summary, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const Spacer(),
                  Wrap(
                    spacing: AppSpacing.base,
                    children: [
                      _Metric(label: 'ROI', value: o.roi),
                      _Metric(label: 'Duration', value: o.duration),
                      _Metric(label: 'Min', value: o.minInvestment),
                      _Metric(label: 'Risk', value: o.risk),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(value, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600, fontSize: 12)),
      ],
    );
  }
}
