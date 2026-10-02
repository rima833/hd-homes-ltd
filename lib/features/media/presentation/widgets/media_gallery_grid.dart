import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/media/data/models/media_content.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// HD image gallery with live published photos, category chips, and lightbox.
class MediaGalleryGrid extends HookWidget {
  const MediaGalleryGrid({super.key, required this.images});

  final List<MediaGalleryImage> images;

  @override
  Widget build(BuildContext context) {
    final category = useState<MediaGalleryCategory?>(null);
    final lightboxIndex = useState<int?>(null);

    if (images.isEmpty) {
      return Text(
        'No published photos for this showroom yet.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.slate500,
            ),
      );
    }

    final availableCategories = MediaGalleryCategory.values
        .where((c) => images.any((image) => image.category == c))
        .toList();
    final filtered = category.value == null
        ? images
        : images.where((i) => i.category == category.value).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (availableCategories.length > 1)
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              FilterChip(
                label: const Text('All'),
                selected: category.value == null,
                onSelected: (_) => category.value = null,
              ),
              ...availableCategories.map(
                (c) => FilterChip(
                  label: Text(c.label),
                  selected: category.value == c,
                  onSelected: (_) =>
                      category.value = category.value == c ? null : c,
                ),
              ),
            ],
          ),
        if (availableCategories.length > 1) const SizedBox(height: AppSpacing.lg),
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
              child: ClipRRect(
                borderRadius: AppRadius.cardBorder,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _GalleryPhoto(url: img.imageUrl),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              AppColors.deepBlack.withValues(alpha: 0.75),
                            ],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: Text(
                            img.caption,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ),
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

class _GalleryPhoto extends StatelessWidget {
  const _GalleryPhoto({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return ColoredBox(
        color: AppColors.charcoal,
        child: const Center(
          child: Icon(LucideIcons.image, color: AppColors.gold, size: 32),
        ),
      );
    }
    return MediaDeliveryImage(
      url: url!,
      fit: BoxFit.cover,
      placeholder: const ColoredBox(
        color: AppColors.charcoal,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.gold,
            ),
          ),
        ),
      ),
      errorWidget: const ColoredBox(
        color: AppColors.charcoal,
        child: Center(
          child: Icon(LucideIcons.image, color: AppColors.gold, size: 32),
        ),
      ),
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
              Expanded(
                child: Text(
                  image.caption,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: onClose),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          ClipRRect(
            borderRadius: AppRadius.cardBorder,
            child: SizedBox(
              height: 320,
              width: double.infinity,
              child: _GalleryPhoto(url: image.imageUrl),
            ),
          ),
        ],
      ),
    );
  }
}
