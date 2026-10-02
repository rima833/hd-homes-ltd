import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/about/data/models/about_cms_content.dart';
import 'package:hdhomesproject/features/about/presentation/widgets/about_icons.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Auto-advance interval for the journey slideshow.
const _storyAutoplayDuration = Duration(seconds: 3);

/// Section 3 — Our story / journey timeline (premium interactive mockup).
class AboutStorySection extends HookWidget {
  const AboutStorySection({super.key, required this.chapters});

  final List<AboutStoryChapter> chapters;

  @override
  Widget build(BuildContext context) {
    if (chapters.isEmpty) return const SizedBox.shrink();

    final selected = useState(0);
    final direction = useState(1); // 1 = forward in time, -1 = backward
    final autoplayPausedUntil = useRef<DateTime?>(null);

    void goToYear(int index, {required bool fromUser}) {
      final next = index % chapters.length;
      if (next == selected.value) return;
      // Wrap-around (last → first) still feels like moving forward in the loop.
      final wrappingForward =
          selected.value == chapters.length - 1 && next == 0;
      direction.value =
          wrappingForward || next > selected.value ? 1 : -1;
      selected.value = next;
      if (fromUser) {
        autoplayPausedUntil.value =
            DateTime.now().add(const Duration(seconds: 8));
      }
    }

    useEffect(() {
      if (chapters.length < 2) return null;
      final timer = Timer.periodic(_storyAutoplayDuration, (_) {
        final pauseUntil = autoplayPausedUntil.value;
        if (pauseUntil != null && DateTime.now().isBefore(pauseUntil)) {
          return;
        }
        goToYear(selected.value + 1, fromUser: false);
      });
      return timer.cancel;
    }, [chapters.length]);

    final safeIndex = selected.value.clamp(0, chapters.length - 1);
    final chapter = chapters[safeIndex];

    return SectionWrapper(
      backgroundColor: AppColors.deepBlack,
      padding: EdgeInsets.symmetric(
        horizontal: context.pagePadding,
        vertical: AppSpacing.section,
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: _JourneyBackdrop()),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _JourneyHeader(),
              const SizedBox(height: AppSpacing.xxl),
              if (context.isMobile)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TimelineRail(
                      chapters: chapters,
                      selected: safeIndex,
                      onSelected: (i) => goToYear(i, fromUser: true),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _StoryDetailCard(
                      chapter: chapter,
                      direction: direction.value,
                    ),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 320,
                      child: _TimelineRail(
                        chapters: chapters,
                        selected: safeIndex,
                        onSelected: (i) => goToYear(i, fromUser: true),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xxl),
                    Expanded(
                      child: _StoryDetailCard(
                        chapter: chapter,
                        direction: direction.value,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _JourneyBackdrop extends StatelessWidget {
  const _JourneyBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _TopoPainter()),
          Align(
            alignment: const Alignment(0.85, -0.55),
            child: Text(
              'HD',
              style: GoogleFonts.playfairDisplay(
                fontSize: 220,
                fontWeight: FontWeight.w700,
                height: 1,
                color: AppColors.gold.withValues(alpha: 0.05),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var i = 0; i < 8; i++) {
      final rect = Rect.fromCenter(
        center: Offset(size.width * 0.78, size.height * 0.35),
        width: 180.0 + (i * 70),
        height: 120.0 + (i * 48),
      );
      canvas.drawOval(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _JourneyHeader extends StatelessWidget {
  const _JourneyHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OUR JOURNEY',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.gold,
                letterSpacing: 2.4,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Our story',
          style: GoogleFonts.playfairDisplay(
            fontSize: context.isMobile ? 34 : 44,
            fontWeight: FontWeight.w700,
            color: AppColors.white,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: 88,
          height: 3,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            gradient: LinearGradient(
              colors: [
                AppColors.gold,
                AppColors.gold.withValues(alpha: 0.15),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.45),
                blurRadius: 12,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            'From a bold vision to a trusted national developer — the HD Homes journey.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondaryDark,
                  height: 1.5,
                ),
          ),
        ),
      ],
    );
  }
}

class _TimelineRail extends StatelessWidget {
  const _TimelineRail({
    required this.chapters,
    required this.selected,
    required this.onSelected,
  });

  final List<AboutStoryChapter> chapters;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < chapters.length; i++) ...[
          _TimelineNode(
            chapter: chapters[i],
            active: i == selected,
            isLast: i == chapters.length - 1,
            onTap: () => onSelected(i),
          ),
        ],
      ],
    );
  }
}

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({
    required this.chapter,
    required this.active,
    required this.isLast,
    required this.onTap,
  });

  final AboutStoryChapter chapter;
  final bool active;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutCubic,
                  width: active ? 14 : 12,
                  height: active ? 14 : 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? AppColors.gold : AppColors.deepBlack,
                    border: Border.all(
                      color: active
                          ? AppColors.gold
                          : AppColors.white.withValues(alpha: 0.35),
                      width: 2,
                    ),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.55),
                              blurRadius: 14,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
                if (!isLast)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutCubic,
                    width: 2,
                    height: 72,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          active
                              ? AppColors.gold.withValues(alpha: 0.55)
                              : AppColors.white.withValues(alpha: 0.12),
                          AppColors.white.withValues(alpha: 0.08),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.gold
                          : AppColors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: active
                            ? AppColors.gold
                            : AppColors.white.withValues(alpha: 0.14),
                      ),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: AppColors.gold.withValues(alpha: 0.4),
                                blurRadius: 18,
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(
                                scale: animation,
                                child: child,
                              ),
                            );
                          },
                          child: active
                              ? const Padding(
                                  key: ValueKey('check'),
                                  padding: EdgeInsets.only(right: 6),
                                  child: Icon(
                                    LucideIcons.check,
                                    size: 14,
                                    color: AppColors.deepBlack,
                                  ),
                                )
                              : const SizedBox(
                                  key: ValueKey('empty'),
                                  width: 0,
                                  height: 14,
                                ),
                        ),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 320),
                          style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color: active
                                        ? AppColors.deepBlack
                                        : AppColors.white,
                                    fontWeight: FontWeight.w800,
                                  ) ??
                              const TextStyle(),
                          child: Text(chapter.year),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 320),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: active ? AppColors.gold : AppColors.white,
                              fontWeight: FontWeight.w700,
                            ) ??
                        const TextStyle(),
                    child: Text(chapter.title),
                  ),
                  if ((chapter.summary ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      chapter.summary!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondaryDark,
                            height: 1.4,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryDetailCard extends StatelessWidget {
  const _StoryDetailCard({
    required this.chapter,
    required this.direction,
  });

  final AboutStoryChapter chapter;
  final int direction;

  @override
  Widget build(BuildContext context) {
    final features = chapter.displayFeatures;
    final slideIn = direction >= 0 ? 0.08 : -0.08;
    final slideOut = direction >= 0 ? -0.06 : 0.06;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 620),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            ...previousChildren,
            ?currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        final isIncoming = child.key == ValueKey(chapter.year);
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        final offsetAnimation = Tween<Offset>(
          begin: Offset(0, isIncoming ? slideIn : slideOut),
          end: Offset.zero,
        ).animate(curved);

        final scaleAnimation = Tween<double>(
          begin: isIncoming ? 0.96 : 1.02,
          end: 1,
        ).animate(curved);

        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: offsetAnimation,
            child: ScaleTransition(
              scale: scaleAnimation,
              child: child,
            ),
          ),
        );
      },
      child: Container(
        key: ValueKey(chapter.year),
        width: double.infinity,
        padding: EdgeInsets.all(context.isMobile ? AppSpacing.lg : AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.charcoal.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.55),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.12),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.xxl - 2),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.gold.withValues(alpha: 0.14),
                        Colors.transparent,
                        AppColors.gold.withValues(alpha: 0.06),
                      ],
                    ),
                  ),
                ),
              )
                  .animate(key: ValueKey('glow-${chapter.year}'))
                  .fadeIn(duration: 280.ms)
                  .then(delay: 120.ms)
                  .fadeOut(duration: 420.ms),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chapter.year,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                )
                    .animate(key: ValueKey('year-${chapter.year}'))
                    .fadeIn(duration: 360.ms, curve: Curves.easeOut)
                    .slideY(begin: 0.35 * direction, end: 0, duration: 480.ms)
                    .blurXY(begin: 6, end: 0, duration: 420.ms),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  chapter.title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: context.isMobile ? 28 : 34,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                )
                    .animate(key: ValueKey('title-${chapter.year}'))
                    .fadeIn(delay: 60.ms, duration: 400.ms)
                    .slideY(
                      begin: 0.28 * direction,
                      end: 0,
                      delay: 60.ms,
                      duration: 520.ms,
                      curve: Curves.easeOutCubic,
                    ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: 56,
                  height: 2,
                  color: AppColors.gold,
                )
                    .animate(key: ValueKey('rule-${chapter.year}'))
                    .fadeIn(delay: 120.ms, duration: 280.ms)
                    .scaleX(
                      begin: 0.2,
                      end: 1,
                      delay: 120.ms,
                      duration: 480.ms,
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.centerLeft,
                    ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  chapter.body,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.white.withValues(alpha: 0.88),
                        height: 1.55,
                      ),
                )
                    .animate(key: ValueKey('body-${chapter.year}'))
                    .fadeIn(delay: 140.ms, duration: 420.ms)
                    .slideY(
                      begin: 0.18 * direction,
                      end: 0,
                      delay: 140.ms,
                      duration: 520.ms,
                    ),
                if (features.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 560;
                      final shown = features.take(3).toList();
                      final cards = [
                        for (var i = 0; i < shown.length; i++)
                          _FeatureChip(
                            feature: shown[i],
                            delayMs: 220 + (i * 80),
                            yearKey: chapter.year,
                          ),
                      ];
                      if (stacked) {
                        return Column(
                          children: [
                            for (var i = 0; i < cards.length; i++) ...[
                              if (i > 0) const SizedBox(height: AppSpacing.sm),
                              cards[i],
                            ],
                          ],
                        );
                      }
                      return Row(
                        children: [
                          for (var i = 0; i < cards.length; i++) ...[
                            if (i > 0) const SizedBox(width: AppSpacing.sm),
                            Expanded(child: cards[i]),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({
    required this.feature,
    required this.delayMs,
    required this.yearKey,
  });

  final AboutStoryFeature feature;
  final int delayMs;
  final String yearKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.deepBlack.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            AboutIcons.resolve(feature.iconName),
            size: 18,
            color: AppColors.gold,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            feature.title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (feature.description.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              feature.description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondaryDark,
                    height: 1.35,
                  ),
            ),
          ],
        ],
      ),
    )
        .animate(key: ValueKey('feature-$yearKey-$delayMs'))
        .fadeIn(delay: delayMs.ms, duration: 380.ms)
        .slideY(
          begin: 0.22,
          end: 0,
          delay: delayMs.ms,
          duration: 480.ms,
          curve: Curves.easeOutCubic,
        )
        .scale(
          begin: const Offset(0.96, 0.96),
          end: const Offset(1, 1),
          delay: delayMs.ms,
          duration: 480.ms,
        );
  }
}
