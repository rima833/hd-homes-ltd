import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:lucide_icons/lucide_icons.dart';

abstract final class SearchIcons {
  static IconData resolve(String name) => switch (name) {
        'home' => LucideIcons.home,
        'building' => LucideIcons.building2,
        'layers' => LucideIcons.layers,
        'grid' => LucideIcons.grid,
        'map' => LucideIcons.map,
        'briefcase' => LucideIcons.briefcase,
        'crown' => LucideIcons.crown,
        'sparkles' => LucideIcons.sparkles,
        'star' => LucideIcons.star,
        'key' => LucideIcons.key,
        'hardHat' => LucideIcons.hardHat,
        'trending' => LucideIcons.trendingUp,
        'users' => LucideIcons.users,
        'graduationCap' => LucideIcons.graduationCap,
        'trees' => LucideIcons.trees,
        'landmark' => LucideIcons.landmark,
        'waves' => LucideIcons.waves,
        'heart' => LucideIcons.heart,
        _ => LucideIcons.search,
      };
}

/// Universal search bar with autocomplete suggestions (Part 11).
class GlobalSearchBar extends StatelessWidget {
  const GlobalSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    this.popularSearches = const [],
    this.recentSearches = const [],
    this.onAiSearch,
    this.onVoiceSearch,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final List<String> popularSearches;
  final List<String> recentSearches;
  final VoidCallback? onAiSearch;
  final VoidCallback? onVoiceSearch;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: 'Search property, estate, city, code, landmark…',
            prefixIcon: const Icon(LucideIcons.search, color: AppColors.gold),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onAiSearch != null)
                  IconButton(
                    tooltip: 'AI Smart Search',
                    icon: const Icon(LucideIcons.sparkles, color: AppColors.gold),
                    onPressed: onAiSearch,
                  ),
                IconButton(
                  tooltip: 'Voice search (coming soon)',
                  icon: Icon(LucideIcons.mic, color: onVoiceSearch != null ? AppColors.gold : Colors.grey),
                  onPressed: onVoiceSearch,
                ),
              ],
            ),
            filled: true,
            fillColor: AppColors.charcoal.withValues(alpha: 0.5),
            border: OutlineInputBorder(borderRadius: AppRadius.cardBorder, borderSide: BorderSide.none),
          ),
        ),
        if (recentSearches.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              Text('Recent:', style: Theme.of(context).textTheme.labelSmall),
              ...recentSearches.map(
                (s) => ActionChip(
                  label: Text(s),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    controller.text = s;
                    onSubmitted(s);
                  },
                ),
              ),
            ],
          ),
        ],
        if (popularSearches.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              Text('Popular:', style: Theme.of(context).textTheme.labelSmall),
              ...popularSearches.take(5).map(
                    (s) => ActionChip(
                      label: Text(s),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        controller.text = s;
                        onSubmitted(s);
                      },
                    ),
                  ),
            ],
          ),
        ],
      ],
    );
  }
}
