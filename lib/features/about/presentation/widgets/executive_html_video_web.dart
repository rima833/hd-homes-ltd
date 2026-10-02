import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:web/web.dart' as web;

/// Native HTML5 `<video controls>` — reliable playback + sound on Flutter web.
class ExecutiveHtmlVideo extends StatefulWidget {
  const ExecutiveHtmlVideo({super.key, required this.url});

  final String url;

  @override
  State<ExecutiveHtmlVideo> createState() => _ExecutiveHtmlVideoState();
}

class _ExecutiveHtmlVideoState extends State<ExecutiveHtmlVideo> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType =
        'hd-exec-video-${identityHashCode(this)}-${DateTime.now().microsecondsSinceEpoch}';
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final video = web.HTMLVideoElement()
        ..src = widget.url
        ..controls = true
        ..autoplay = false
        ..preload = 'metadata'
        ..setAttribute('playsinline', 'true')
        ..setAttribute('controlslist', 'nodownload');
      video.style
        ..width = '100%'
        ..height = '100%'
        ..border = 'none'
        ..objectFit = 'cover'
        ..backgroundColor = '#0F1115';
      return video;
    });
  }

  @override
  Widget build(BuildContext context) {
    // HtmlElementView (platform views) can blank Flutter web canvases inside
    // nested scrollables. Prefer a safe poster + external play control.
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
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Color(0xFF0F1115)),
              HtmlElementView(viewType: _viewType),
            ],
          ),
        ),
      ),
    );
  }
}
