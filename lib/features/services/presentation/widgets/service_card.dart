import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/core/widgets/feedback/app_badge.dart';
import 'package:hdhomesproject/features/services/data/models/service_models.dart';
import 'package:hdhomesproject/features/services/presentation/widgets/service_cta.dart';
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
  bool _navigating = false;

  Future<void> _open() async {
    if (_navigating) return;
    setState(() => _navigating = true);
    try {
      if (widget.onTap != null) {
        widget.onTap!();
      } else {
        await openServiceLearnMore(context, widget.service);
      }
    } finally {
      if (mounted) setState(() => _navigating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.service;
    final ctaLabel = s.ctaLabel.trim().isEmpty ? 'Learn More' : s.ctaLabel;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bounded = constraints.hasBoundedHeight &&
              constraints.maxHeight.isFinite &&
              constraints.maxHeight < double.infinity;
          final lift = !bounded && _hovered;

          final body = Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(ServiceIcons.resolve(s.iconName),
                        color: AppColors.gold),
                    const Spacer(),
                    ...s.badges.map(_badge),
                  ],
                ),
                const SizedBox(height: AppSpacing.base),
                Text(
                  s.name,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: Row(
                            children: [
                              const Icon(Icons.check_rounded,
                                  color: AppColors.gold, size: 14),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  b,
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
                const SizedBox(height: AppSpacing.base),
                // Button is the only gesture target — avoids nested InkWell
                // + button double-navigation freezes on Flutter web.
                PrimaryButton(
                  label: ctaLabel,
                  expand: true,
                  isLoading: _navigating,
                  onPressed: _navigating ? null : _open,
                ),
              ],
            ),
          );

          return AnimatedContainer(
            duration: AppDurations.fast,
            transform: Matrix4.translationValues(0, lift ? -6 : 0, 0),
            decoration: BoxDecoration(
              borderRadius: AppRadius.cardBorder,
              boxShadow: _hovered ? AppShadows.lg : AppShadows.md,
            ),
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: AppRadius.cardBorder,
              clipBehavior: Clip.antiAlias,
              child: bounded
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        child: body,
                      ),
                    )
                  : body,
            ),
          );
        },
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
