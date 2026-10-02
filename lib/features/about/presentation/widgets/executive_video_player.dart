import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/about/presentation/widgets/executive_html_video_stub.dart'
    if (dart.library.html) 'package:hdhomesproject/features/about/presentation/widgets/executive_html_video_web.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';

/// True when the URL is a browser-friendly video (MP4 / WebM).
bool isBrowserPlayableVideoUrl(String? url) {
  if (url == null || url.trim().isEmpty) return false;
  final uri = Uri.tryParse(url.trim());
  final path = (uri?.path ?? url).toLowerCase();
  return path.endsWith('.mp4') ||
      path.endsWith('.webm') ||
      path.endsWith('.ogg') ||
      path.endsWith('.ogv');
}

/// Public executive video surface — HTML5 on web, video_player elsewhere.
class ExecutiveVideoPlayer extends StatelessWidget {
  const ExecutiveVideoPlayer({super.key, required this.videoUrl});

  final String? videoUrl;

  @override
  Widget build(BuildContext context) {
    final url = videoUrl?.trim();
    if (url == null || url.isEmpty) {
      return const _EmptyVideoShell(
        icon: LucideIcons.video,
        message: 'Upload an MP4 video from Admin → Website → Pages → about.',
      );
    }

    if (!isBrowserPlayableVideoUrl(url)) {
      return _UnsupportedFormatShell(url: url);
    }

    if (kIsWeb) {
      return ExecutiveHtmlVideo(url: url);
    }

    return _IoVideoPlayer(url: url);
  }
}

class _EmptyVideoShell extends StatelessWidget {
  const _EmptyVideoShell({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _Shell(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.gold, size: 40),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.85),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnsupportedFormatShell extends StatelessWidget {
  const _UnsupportedFormatShell({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return _Shell(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.fileWarning, color: AppColors.gold, size: 40),
            const SizedBox(height: AppSpacing.md),
            Text(
              'This file type (.mov) cannot play in the browser.\n'
              'Please re-upload an MP4 or WebM from the admin panel.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.9),
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(LucideIcons.externalLink, size: 16),
              label: const Text('Open video file'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.deepBlack,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: ColoredBox(color: AppColors.darkSurface, child: child),
        ),
      ),
    );
  }
}

class _IoVideoPlayer extends StatefulWidget {
  const _IoVideoPlayer({required this.url});

  final String url;

  @override
  State<_IoVideoPlayer> createState() => _IoVideoPlayerState();
}

class _IoVideoPlayerState extends State<_IoVideoPlayer> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        _controller
          ..setLooping(true)
          ..setVolume(1);
        setState(() => _ready = true);
      }).catchError((Object e) {
        if (mounted) setState(() => _error = userFacingError(e));
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _EmptyVideoShell(
        icon: LucideIcons.videoOff,
        message: 'Video failed to load. Re-upload an MP4 from admin.',
      );
    }
    return _Shell(
      child: _ready
          ? Stack(
              fit: StackFit.expand,
              children: [
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
                Center(
                  child: IconButton(
                    iconSize: 56,
                    color: AppColors.gold,
                    onPressed: () {
                      setState(() {
                        if (_controller.value.isPlaying) {
                          _controller.pause();
                        } else {
                          _controller.play();
                        }
                      });
                    },
                    icon: Icon(
                      _controller.value.isPlaying
                          ? LucideIcons.pause
                          : LucideIcons.play,
                    ),
                  ),
                ),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            ),
    );
  }
}
