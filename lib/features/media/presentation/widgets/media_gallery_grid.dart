import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/media/data/models/media_content.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// HD image gallery with categories, lightbox, and lazy-loading placeholders.
class MediaGalleryGrid extends HookWidget {
  const MediaGalleryGrid({super.key, required this.images});

  final List<MediaGalleryImage> images;

  @override
  Widget build(BuildContext context) {
    final category = useState<MediaGalleryCategory?>(null);
    final lightboxIndex = useState<int?>(null);

    final filtered = category.value == null
        ? images
        : images.where((i) => i.category == category.value).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          children: [
            FilterChip(
              label: const Text('All'),
              selected: category.value == null,
              onSelected: (_) => category.value = null,
            ),
            ...MediaGalleryCategory.values.map(
              (c) => FilterChip(
                label: Text(c.label),
                selected: category.value == c,
                onSelected: (_) => category.value = category.value == c ? null : c,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: context.isMobile ? 2 : 3,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.2,
          ),
          itemCount: filtered.length,
          itemBuilder: (_, i) {
            final img = filtered[i];
            return InkWell(
              onTap: () => lightboxIndex.value = i,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: AppRadius.cardBorder,
                  gradient: LinearGradient(
                    colors: [AppColors.charcoal, AppColors.gold.withValues(alpha: 0.12)],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(LucideIcons.image, color: AppColors.gold, size: 32),
                    const SizedBox(height: AppSpacing.xs),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      child: Text(
                        img.caption,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (lightboxIndex.value != null)
          _Lightbox(
            image: filtered[lightboxIndex.value!],
            onClose: () => lightboxIndex.value = null,
          ),
      ],
    );
  }
}

class _Lightbox extends StatelessWidget {
  const _Lightbox({required this.image, required this.onClose});

  final MediaGalleryImage image;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.deepBlack,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(image.caption, style: Theme.of(context).textTheme.titleMedium)),
              IconButton(icon: const Icon(Icons.close), onPressed: onClose),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          Container(
            height: 280,
            width: double.infinity,
            color: AppColors.charcoal,
            child: const Center(child: Icon(LucideIcons.maximize2, color: AppColors.gold, size: 48)),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('${image.category.label} · Fullscreen · Zoom · Slideshow'),
        ],
      ),
    );
  }
}
