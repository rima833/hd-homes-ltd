import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/properties/data/models/property_detail_content.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

/// Section 1 — Hero media gallery with carousel and fullscreen.
class PropertyMediaGallery extends StatefulWidget {
  const PropertyMediaGallery({super.key, required this.media, required this.title});

  final PropertyMediaBundle media;
  final String title;

  @override
  State<PropertyMediaGallery> createState() => _PropertyMediaGalleryState();
}

class _PropertyMediaGalleryState extends State<PropertyMediaGallery> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final count = widget.media.images.length;

    return Stack(
      children: [
        CarouselSlider.builder(
          itemCount: count,
          options: CarouselOptions(
            height: MediaQuery.sizeOf(context).width < 720 ? 320 : 480,
            viewportFraction: 1,
            enlargeCenterPage: false,
            onPageChanged: (i, _) => setState(() => _index = i),
          ),
          itemBuilder: (context, index, _) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.charcoal,
                    AppColors.gold.withValues(alpha: 0.15 + index * 0.02),
                  ],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      index == 0 && widget.media.hasDroneFootage
                          ? LucideIcons.plane
                          : LucideIcons.image,
                      size: 48,
                      color: AppColors.gold,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Gallery ${index + 1} of $count',
                      style: const TextStyle(color: AppColors.white),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        Positioned(
          bottom: AppSpacing.base,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              count,
              (i) => Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _index ? AppColors.gold : AppColors.white.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: AppSpacing.base,
          right: AppSpacing.base,
          child: Row(
            children: [
              _GalleryButton(
                icon: LucideIcons.maximize2,
                onTap: () => _openFullscreen(context),
              ),
              const SizedBox(width: AppSpacing.sm),
              _GalleryButton(
                icon: LucideIcons.share2,
                onTap: () => Share.share(widget.title),
              ),
              if (widget.media.hasVirtualTour) ...[
                const SizedBox(width: AppSpacing.sm),
                _GalleryButton(
                  icon: LucideIcons.rotate3d,
                  onTap: () {},
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _openFullscreen(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Stack(
          children: [
            Container(color: AppColors.deepBlack),
            Center(
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.white,
                    ),
              ),
            ),
            Positioned(
              top: AppSpacing.base,
              right: AppSpacing.base,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryButton extends StatelessWidget {
  const _GalleryButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.deepBlack.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(AppRadius.badge),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.badge),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Icon(icon, color: AppColors.white, size: 18),
        ),
      ),
    );
  }
}
