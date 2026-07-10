import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/media/data/models/media_content.dart';
import 'package:hdhomesproject/features/media/presentation/widgets/media_icons.dart';

/// Reusable featured media card.
class MediaFeaturedCardWidget extends StatefulWidget {
  const MediaFeaturedCardWidget({
    super.key,
    required this.card,
    this.onTap,
  });

  final MediaFeaturedCard card;
  final VoidCallback? onTap;

  @override
  State<MediaFeaturedCardWidget> createState() => _MediaFeaturedCardWidgetState();
}

class _MediaFeaturedCardWidgetState extends State<MediaFeaturedCardWidget> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.card;

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
            onTap: widget.onTap,
            borderRadius: AppRadius.cardBorder,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(MediaIcons.resolve(c.iconName), color: AppColors.gold, size: 32),
                  const SizedBox(height: AppSpacing.base),
                  Text(c.title, style: Theme.of(context).textTheme.titleMedium),
                  Text('${c.count} items · Updated ${c.lastUpdated}',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.sm),
                  Text(c.cta, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
