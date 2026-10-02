import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/media/media_delivery.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Network image with Cloudinary transforms and legacy URL fallback.
class MediaDeliveryImage extends StatelessWidget {
  const MediaDeliveryImage({
    super.key,
    required this.url,
    this.secureUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.thumbnail = false,
    this.cacheWidth,
    this.placeholder,
    this.errorWidget,
  });

  final String url;
  final String? secureUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool thumbnail;
  final int? cacheWidth;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    // Layout may pass infinity; only finite sizes become Cloudinary transforms.
    final transformW =
        (width != null && width!.isFinite && width! > 0) ? width!.round() : null;
    final transformH = (height != null && height!.isFinite && height! > 0)
        ? height!.round()
        : null;
    final resolved = MediaDelivery.resolve(
      secureUrl: secureUrl,
      fileUrl: url,
      width: transformW,
      height: transformH,
      thumbnail: thumbnail,
    );
    if (resolved.isEmpty) {
      return errorWidget ?? _defaultPlaceholder();
    }
    // Never forward non-finite sizes to CachedNetworkImage (it may call .round()).
    final layoutW = (width != null && width!.isFinite) ? width : null;
    final layoutH = (height != null && height!.isFinite) ? height : null;
    return CachedNetworkImage(
      imageUrl: resolved,
      width: layoutW,
      height: layoutH,
      memCacheWidth: cacheWidth,
      fit: fit,
      placeholder: (_, __) => placeholder ?? _defaultPlaceholder(),
      errorWidget: (_, __, ___) => errorWidget ?? _defaultPlaceholder(),
    );
  }

  Widget _defaultPlaceholder() {
    return Container(
      color: AppColors.slate800,
      child: const Icon(LucideIcons.imageOff, color: AppColors.slate500),
    );
  }
}
