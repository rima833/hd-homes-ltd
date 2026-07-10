import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/page_container.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/estates/data/providers/estate_listings_provider.dart';
import 'package:hdhomesproject/features/estates/presentation/widgets/estate_summary_card.dart';

/// Estate listings index — links to individual estate showcases.
class EstatesListingPage extends ConsumerWidget {
  const EstatesListingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estates = ref.watch(estateListingsProvider);
    final columns = context.gridColumns.clamp(1, 3);

    return Column(
      children: [
        SectionWrapper(
          backgroundColor: AppColors.charcoal,
          child: PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AnimatedSectionTitle(
                  overline: 'ESTATES',
                  title: 'Flagship developments',
                  subtitle:
                      'Explore entire communities — master plans, amenities, inventory, and investment potential.',
                  alignment: TextAlign.start,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${estates.length} estates across Nigeria',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                ),
              ],
            ),
          ),
        ),
        SectionWrapper(
          child: PageContainer(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = (constraints.maxWidth - (columns - 1) * AppSpacing.base) / columns;
                return Wrap(
                  spacing: AppSpacing.base,
                  runSpacing: AppSpacing.base,
                  children: estates
                      .map((e) => SizedBox(width: w, child: EstateSummaryCard(estate: e)))
                      .toList(),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
