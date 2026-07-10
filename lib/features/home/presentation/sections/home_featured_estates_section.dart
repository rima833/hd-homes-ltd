import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/home/data/models/home_cms_content.dart';
import 'package:hdhomesproject/features/home/presentation/widgets/estate_card.dart';

/// Section 9 — Featured estates.
class HomeFeaturedEstatesSection extends StatelessWidget {
  const HomeFeaturedEstatesSection({super.key, required this.estates});

  final List<HomeEstateItem> estates;

  @override
  Widget build(BuildContext context) {
    final columns = context.isMobile ? 1 : context.isTablet ? 2 : 3;

    return SectionWrapper(
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: AnimatedSectionTitle(
                  overline: 'FLAGSHIP ESTATES',
                  title: 'Featured estates',
                  subtitle: 'Explore our signature developments across Nigeria.',
                  alignment: TextAlign.start,
                ),
              ),
              if (!context.isMobile)
                PrimaryButton(
                  label: 'View All Estates',
                  variant: ButtonVariant.ghost,
                  onPressed: () => context.go(RoutePaths.estates),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          LayoutBuilder(
            builder: (context, constraints) {
              final width =
                  (constraints.maxWidth - (columns - 1) * AppSpacing.base) /
                      columns;
              return Wrap(
                spacing: AppSpacing.base,
                runSpacing: AppSpacing.base,
                children: estates
                    .map((e) => SizedBox(width: width, child: EstateCard(estate: e)))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
