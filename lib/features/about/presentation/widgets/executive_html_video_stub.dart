import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';

/// Non-web placeholder — [ExecutiveVideoPlayer] uses video_player instead.
class ExecutiveHtmlVideo extends StatelessWidget {
  const ExecutiveHtmlVideo({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: AppColors.darkSurface,
        child: Center(
          child: Text(
            'Video preview requires web or mobile runtime.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.white,
                ),
          ),
        ),
      ),
    );
  }
}
