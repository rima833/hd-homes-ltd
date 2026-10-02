import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/trust/data/models/trust_center_content.dart';
import 'package:hdhomesproject/features/trust/presentation/widgets/trust_info_cards.dart';

/// Reusable trust pillar card.
class TrustPillarCard extends StatefulWidget {
  const TrustPillarCard({super.key, required this.pillar});

  final TrustPillar pillar;

  @override
  State<TrustPillarCard> createState() => _TrustPillarCardState();
}

class _TrustPillarCardState extends State<TrustPillarCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: AppRadius.cardBorder,
          boxShadow: _hovered ? AppShadows.md : AppShadows.sm,
          border: Border.all(
            color: AppColors.gold.withValues(alpha: _hovered ? 0.4 : 0.16),
          ),
        ),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.cardBorder,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    TrustIcons.resolve(widget.pillar.iconName),
                    color: AppColors.gold,
                    size: 22,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  widget.pillar.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Expanded(
                  child: Text(
                    widget.pillar.description,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
