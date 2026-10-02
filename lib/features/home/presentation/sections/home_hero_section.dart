import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/home/data/models/home_cms_content.dart';
import 'package:hdhomesproject/core/website/l10n/app_strings.dart';
import 'package:video_player/video_player.dart';

/// Section 4 — Premium hero with CMS-driven image/video background.
class HomeHeroSection extends StatelessWidget {
  const HomeHeroSection({super.key, required this.content});

  final HomeHeroContent content;

  @override
  Widget build(BuildContext context) {
    final height = context.isMobile ? 620 : 760;

    return SizedBox(
      height: height.toDouble(),
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _HeroBackground(content: content),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.deepBlack.withValues(alpha: 0.15),
                  AppColors.deepBlack.withValues(
                    alpha: content.overlayOpacity.clamp(0.35, 0.92),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.pagePadding,
              context.isMobile ? 100 : 120,
              context.pagePadding,
              AppSpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  AppStrings.tagline.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.gold,
                        letterSpacing: 2.5,
                      ),
                ).animate().fadeIn(duration: 600.ms),
                const SizedBox(height: AppSpacing.base),
                Text(
                  content.headline,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: AppColors.white,
                        height: 1.05,
                        fontSize: context.isMobile ? 36 : 52,
                      ),
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.08, end: 0),
                const SizedBox(height: AppSpacing.lg),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 580),
                  child: Text(
                    content.subheadline,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondaryDark,
                        ),
                  ),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: AppSpacing.xxl),
                Wrap(
                  spacing: AppSpacing.base,
                  runSpacing: AppSpacing.base,
                  children: [
                    PrimaryButton(
                      label: content.primaryCtaLabel,
                      onPressed: () => context.go(content.primaryCtaPath),
                    ),
                    PrimaryButton(
                      label: content.secondaryCtaLabel,
                      variant: ButtonVariant.secondary,
                      onPressed: () => context.go(content.secondaryCtaPath),
                    ),
                    PrimaryButton(
                      label: content.tertiaryCtaLabel,
                      variant: ButtonVariant.ghost,
                      onPressed: () => context.go(content.tertiaryCtaPath),
                    ),
                  ],
                ).animate().fadeIn(delay: 300.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBackground extends StatefulWidget {
  const _HeroBackground({required this.content});

  final HomeHeroContent content;

  @override
  State<_HeroBackground> createState() => _HeroBackgroundState();
}

class _HeroBackgroundState extends State<_HeroBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  VideoPlayerController? _video;
  String? _loadedVideoUrl;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
      lowerBound: 0,
      upperBound: 1,
    );
    if (!kIsWeb) {
      _controller.repeat(reverse: true);
    }
    _syncVideo();
  }

  @override
  void didUpdateWidget(covariant _HeroBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content.backgroundVideoUrl !=
        widget.content.backgroundVideoUrl) {
      _syncVideo();
    }
  }

  Future<void> _syncVideo() async {
    final url = widget.content.backgroundVideoUrl?.trim();
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
    _controller.dispose();
    _video?.dispose();
    _video = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo = _video != null && _video!.value.isInitialized;
    final imageUrl = widget.content.backgroundImageUrl?.trim();
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
        errorWidget: _fallbackGradient(),
      );
    } else {
      media = _fallbackGradient();
    }

    if (kIsWeb || hasVideo) return media;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_controller.value * 0.04),
          child: child,
        );
      },
      child: media,
    );
  }

  Widget _fallbackGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A1510),
            AppColors.charcoal,
            AppColors.deepBlack,
          ],
        ),
      ),
      child: CustomPaint(painter: _HeroPatternPainter()),
    );
  }
}

class _HeroPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 6; i++) {
      canvas.drawLine(
        Offset(0, size.height * i / 6),
        Offset(size.width, size.height * (i + 1) / 6),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
