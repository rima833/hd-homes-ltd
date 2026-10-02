import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/about/presentation/widgets/executive_video_player.dart';
import 'package:hdhomesproject/features/home/data/models/home_cms_content.dart';

/// Executive message band for the About page (above WHO WE ARE).
class HomeExecutiveWelcomeSection extends StatelessWidget {
  const HomeExecutiveWelcomeSection({super.key, required this.executive});

  final HomeExecutiveWelcome executive;

  @override
  Widget build(BuildContext context) {
    return SectionWrapper(
      backgroundColor: AppColors.charcoal,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 900;
          final copy = _Copy(executive: executive);
          final video = ExecutiveVideoPlayer(videoUrl: executive.videoUrl);

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                copy,
                const SizedBox(height: AppSpacing.xl),
                video,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 9, child: copy),
              const SizedBox(width: AppSpacing.xxxl),
              Expanded(flex: 11, child: video),
            ],
          );
        },
      ),
    );
  }
}

class _Copy extends StatelessWidget {
  const _Copy({required this.executive});

  final HomeExecutiveWelcome executive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FROM THE MD',
          style: theme.labelSmall?.copyWith(
            color: AppColors.gold,
            letterSpacing: 3.0,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Executive video message',
          style: theme.headlineSmall?.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          executive.message,
          style: theme.bodyLarge?.copyWith(
            color: AppColors.white.withValues(alpha: 0.9),
            height: 1.65,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          '${executive.name} · ${executive.title}',
          style: theme.titleSmall?.copyWith(
            color: AppColors.gold,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
