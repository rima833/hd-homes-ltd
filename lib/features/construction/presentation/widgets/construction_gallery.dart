import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ConstructionGallery extends StatefulWidget {
  const ConstructionGallery({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  final List<String> imageUrls;
  final int initialIndex;

  @override
  State<ConstructionGallery> createState() => _ConstructionGalleryState();
}

class _ConstructionGalleryState extends State<ConstructionGallery> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.imageUrls.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls.where((u) => u.trim().isNotEmpty).toList();
    if (urls.isEmpty) return const SizedBox.shrink();

    final mobile = MediaQuery.sizeOf(context).width < 768;
    final featured = urls[_selected.clamp(0, urls.length - 1)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => _openLightbox(context, urls, _selected),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: mobile ? 4 / 3 : 16 / 9,
              child: _GalleryImage(url: featured, fit: BoxFit.cover),
            ),
          ),
        ),
        if (urls.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: urls.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final selected = i == _selected;
                return GestureDetector(
                  onTap: () => setState(() => _selected = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 96,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? AppColors.gold : AppColors.charcoal,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _GalleryImage(url: urls[i], fit: BoxFit.cover),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  void _openLightbox(BuildContext context, List<String> urls, int start) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (ctx) => _LightboxDialog(urls: urls, initialIndex: start),
    );
  }
}

class _GalleryImage extends StatelessWidget {
  const _GalleryImage({required this.url, required this.fit});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return MediaDeliveryImage(
      url: url,
      fit: fit,
      placeholder: ColoredBox(
        color: AppColors.charcoal.withValues(alpha: 0.3),
        child: const Center(
          child: CircularProgressIndicator(
            color: AppColors.gold,
            strokeWidth: 2,
          ),
        ),
      ),
      errorWidget: ColoredBox(
        color: AppColors.charcoal.withValues(alpha: 0.3),
        child: const Icon(LucideIcons.imageOff, color: AppColors.textSecondaryDark),
      ),
    );
  }
}

class _LightboxDialog extends StatefulWidget {
  const _LightboxDialog({required this.urls, required this.initialIndex});

  final List<String> urls;
  final int initialIndex;

  @override
  State<_LightboxDialog> createState() => _LightboxDialogState();
}

class _LightboxDialogState extends State<_LightboxDialog> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => InteractiveViewer(
              child: Center(
                child: MediaDeliveryImage(
                  url: widget.urls[i],
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: 12,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(LucideIcons.x, color: Colors.white),
            ),
          ),
          if (widget.urls.length > 1) ...[
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  onPressed: _index > 0
                      ? () => _controller.previousPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          )
                      : null,
                  icon: const Icon(LucideIcons.chevronLeft, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  onPressed: _index < widget.urls.length - 1
                      ? () => _controller.nextPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          )
                      : null,
                  icon: const Icon(LucideIcons.chevronRight, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Text(
                '${_index + 1} / ${widget.urls.length}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
