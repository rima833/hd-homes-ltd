import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/experience_modes.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/home/data/models/home_cms_content.dart';

/// Enterprise — Lifestyle explorer.
class HomeLifestyleExplorerSection extends StatelessWidget {
  const HomeLifestyleExplorerSection({super.key, required this.items});

  final List<HomeLifestyleItem> items;

  @override
  Widget build(BuildContext context) {
    return SectionWrapper(
      child: Column(
        children: [
          const AnimatedSectionTitle(
            overline: 'EXPLORE BY LIFESTYLE',
            title: 'Find a home that fits your life',
            subtitle:
                'Browse developments by the way you want to live, invest, or work.',
          ),
          const SizedBox(height: AppSpacing.xl),
          const ExperienceModesBar(),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: context.isMobile ? 200 : 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.base),
              itemBuilder: (context, index) {
                final item = items[index];
                return SizedBox(
                  width: 240,
                  child: _LifestyleCard(
                    item: item,
                    onTap: () => context.go(item.route),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LifestyleCard extends StatefulWidget {
  const _LifestyleCard({required this.item, required this.onTap});

  final HomeLifestyleItem item;
  final VoidCallback onTap;

  @override
  State<_LifestyleCard> createState() => _LifestyleCardState();
}

class _LifestyleCardState extends State<_LifestyleCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.02 : 1,
        duration: AppDurations.fast,
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.cardBorder,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: AppRadius.cardBorder,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.gold,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      widget.item.description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
