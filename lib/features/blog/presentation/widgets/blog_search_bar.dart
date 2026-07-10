import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Smart search bar for the Knowledge Center hub.
class BlogSearchBar extends StatelessWidget {
  const BlogSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onSubmitted,
    this.hintText = 'Search articles, guides, reports, authors…',
    this.popularSearches = const [],
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final String hintText;
  final List<String> popularSearches;

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
            hintText: hintText,
            prefixIcon: const Icon(LucideIcons.search, color: AppColors.gold),
            filled: true,
            fillColor: AppColors.charcoal.withValues(alpha: 0.6),
            border: OutlineInputBorder(
              borderRadius: AppRadius.cardBorder,
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (popularSearches.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              Text('Popular:', style: Theme.of(context).textTheme.labelSmall),
              ...popularSearches.take(5).map(
                    (term) => ActionChip(
                      label: Text(term),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        controller.text = term;
                        onChanged(term);
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
