import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:video_player/video_player.dart';

/// Shared CMS-driven hero media: prefers looping muted video, then image,
/// then a dark brand gradient fallback (mirrors homepage hero behaviour).
class CmsHeroMediaBackground extends StatefulWidget {
  const CmsHeroMediaBackground({
    super.key,
    this.imageUrl,
    this.videoUrl,
    this.fallbackColors = const [
      Color(0xFF1A1510),
      AppColors.charcoal,
      AppColors.deepBlack,
    ],
    this.fallbackChild,
  });

  final String? imageUrl;
  final String? videoUrl;
  final List<Color> fallbackColors;
  final Widget? fallbackChild;

  @override
  State<CmsHeroMediaBackground> createState() => _CmsHeroMediaBackgroundState();
}

class _CmsHeroMediaBackgroundState extends State<CmsHeroMediaBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kenBurns;
  VideoPlayerController? _video;
  String? _loadedVideoUrl;

  @override
  void initState() {
    super.initState();
    _kenBurns = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    if (!kIsWeb) {
      _kenBurns.repeat(reverse: true);
    }
    _syncVideo();
  }

  @override
  void didUpdateWidget(covariant CmsHeroMediaBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _syncVideo();
    }
  }

  Future<void> _syncVideo() async {
    final url = widget.videoUrl?.trim();
    if (url == null || url.isEmpty) {
      await _video?.dispose();
      _video = null;
      _loadedVideoUrl = null;
      if (mounted) setState(() {});
      return;
    }
    if (url == _loadedVideoUrl && _video != null) return;

    await _video?.dispose();
    _video = null;
    _loadedVideoUrl = url;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _video = controller);
    } catch (_) {
      await controller.dispose();
      if (mounted) setState(() => _video = null);
    }
  }

  @override
  void deactivate() {
    _video?.pause();
    super.deactivate();
  }

  @override
  void dispose() {
    _kenBurns.dispose();
    _video?.dispose();
    _video = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo = _video != null && _video!.value.isInitialized;
    final imageUrl = widget.imageUrl?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    Widget media;
    if (hasVideo) {
      media = FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _video!.value.size.width,
          height: _video!.value.size.height,
          child: VideoPlayer(_video!),
        ),
      );
    } else if (hasImage) {
      media = MediaDeliveryImage(
        url: imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: const ColoredBox(color: AppColors.deepBlack),
        errorWidget: _fallback(),
      );
    } else {
      media = _fallback();
    }

    if (kIsWeb || hasVideo) return media;

    return AnimatedBuilder(
      animation: _kenBurns,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_kenBurns.value * 0.04),
          child: child,
        );
      },
      child: media,
    );
  }

  Widget _fallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.fallbackColors,
        ),
      ),
      child: widget.fallbackChild,
    );
  }
}
