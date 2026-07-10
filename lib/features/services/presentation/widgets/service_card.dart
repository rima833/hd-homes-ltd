import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/core/widgets/feedback/app_badge.dart';
import 'package:hdhomesproject/features/services/data/models/service_models.dart';
import 'package:hdhomesproject/features/services/presentation/widgets/service_icons.dart';

/// Reusable service card for grids and featured sections.
class ServiceCard extends StatefulWidget {
  const ServiceCard({
    super.key,
    required this.service,
    this.compact = false,
    this.onTap,
  });

  final ServiceSummary service;
  final bool compact;
  final VoidCallback? onTap;

  @override
  State<ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<ServiceCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.service;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        transform: Matrix4.translationValues(0, _hovered ? -6 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: AppRadius.cardBorder,
          boxShadow: _hovered ? AppShadows.lg : AppShadows.md,
        ),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.cardBorder,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap ?? () => context.go('/services/${s.slug}'),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(ServiceIcons.resolve(s.iconName), color: AppColors.gold),
                      const Spacer(),
                      ...s.badges.map(_badge),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.base),
                  Text(s.name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    s.shortDescription,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: widget.compact ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!widget.compact && s.keyBenefits.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    ...s.keyBenefits.take(2).map(
                          (b) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                            child: Row(
                              children: [
                                const Icon(Icons.check_rounded, color: AppColors.gold, size: 14),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(child: Text(b, style: const TextStyle(fontSize: 12))),
                              ],
                            ),
                          ),
                        ),
                  ],
                  if (_hovered) ...[
                    const SizedBox(height: AppSpacing.base),
                    PrimaryButton(
                      label: 'Learn More',
                      expand: true,
                      onPressed: widget.onTap ?? () => context.go('/services/${s.slug}'),
                    ),
                  ] else ...[
                    const SizedBox(height: AppSpacing.sm),
                    const Text('Learn more →', style: TextStyle(color: AppColors.gold, fontSize: 13)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(ServiceBadge badge) {
    final label = switch (badge) {
      ServiceBadge.featured => 'Featured',
      ServiceBadge.popular => 'Popular',
      ServiceBadge.newService => 'New',
    };
    final variant = switch (badge) {
      ServiceBadge.featured => BadgeVariant.gold,
      ServiceBadge.popular => BadgeVariant.info,
      ServiceBadge.newService => BadgeVariant.success,
    };
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs),
      child: AppBadge(label: label, variant: variant),
    );
  }
}
