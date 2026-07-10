import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/about/data/models/about_cms_content.dart';

/// Section 3 — Our story (interactive chapters).
class AboutStorySection extends HookWidget {
  const AboutStorySection({super.key, required this.chapters});

  final List<AboutStoryChapter> chapters;

  @override
  Widget build(BuildContext context) {
    final selected = useState(0);
    final chapter = chapters[selected.value];

    return SectionWrapper(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AnimatedSectionTitle(
            overline: 'OUR JOURNEY',
            title: 'Our story',
            subtitle:
                'From a bold vision to a trusted national developer — the HD Homes journey.',
            alignment: TextAlign.start,
          ),
          const SizedBox(height: AppSpacing.xxl),
          context.isMobile
              ? Column(
                  children: [
                    _YearSelector(
                      chapters: chapters,
                      selected: selected.value,
                      onSelected: (i) => selected.value = i,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _StoryPanel(chapter: chapter),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 200,
                      child: _YearSelector(
                        chapters: chapters,
                        selected: selected.value,
                        onSelected: (i) => selected.value = i,
                        vertical: true,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xl),
                    Expanded(child: _StoryPanel(chapter: chapter)),
                  ],
                ),
        ],
      ),
    );
  }
}

class _YearSelector extends StatelessWidget {
  const _YearSelector({
    required this.chapters,
    required this.selected,
    required this.onSelected,
    this.vertical = false,
  });

  final List<AboutStoryChapter> chapters;
  final int selected;
  final ValueChanged<int> onSelected;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final children = List.generate(chapters.length, (i) {
      final isSelected = i == selected;
      return Padding(
        padding: EdgeInsets.only(
          right: vertical ? 0 : AppSpacing.sm,
          bottom: vertical ? AppSpacing.sm : 0,
        ),
        child: ChoiceChip(
          label: Text(chapters[i].year),
          selected: isSelected,
          onSelected: (_) => onSelected(i),
          selectedColor: AppColors.gold,
          labelStyle: TextStyle(
            color: isSelected ? AppColors.deepBlack : null,
            fontWeight: isSelected ? FontWeight.w700 : null,
          ),
        ),
      );
    });

    return vertical
        ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: children),
          );
  }
}

class _StoryPanel extends StatelessWidget {
  const _StoryPanel({required this.chapter});

  final AboutStoryChapter chapter;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppDurations.normal,
      child: Container(
        key: ValueKey(chapter.year),
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.cardBorder,
          boxShadow: AppShadows.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              chapter.year,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.gold,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(chapter.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.base),
            Text(chapter.body, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
