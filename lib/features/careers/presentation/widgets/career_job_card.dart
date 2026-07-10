import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/careers/data/models/careers_hub_content.dart';

class CareerJobCard extends StatefulWidget {
  const CareerJobCard({
    super.key,
    required this.job,
    this.onApply,
  });

  final CareerJob job;
  final VoidCallback? onApply;

  @override
  State<CareerJobCard> createState() => _CareerJobCardState();
}

class _CareerJobCardState extends State<CareerJobCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final job = widget.job;

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
            onTap: widget.onApply,
            borderRadius: AppRadius.cardBorder,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Chip(
                        label: Text(job.department.label),
                        backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Chip(label: Text(job.employmentType.label)),
                      if (job.featured) ...[
                        const Spacer(),
                        const Text('Featured', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600)),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(job.title, style: Theme.of(context).textTheme.titleMedium),
                  Text('${job.location}${job.salaryRange != null ? ' · ${job.salaryRange}' : ''}'),
                  const SizedBox(height: AppSpacing.sm),
                  Text(job.summary, maxLines: 3, overflow: TextOverflow.ellipsis),
                  const Spacer(),
                  TextButton(
                    onPressed: widget.onApply,
                    child: const Text('Apply now'),
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
