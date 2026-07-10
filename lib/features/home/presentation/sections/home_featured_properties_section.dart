import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/core/widgets/cards/property_card.dart';
import 'package:hdhomesproject/features/home/data/models/home_cms_content.dart';

/// Section 10 — Featured properties.
class HomeFeaturedPropertiesSection extends StatelessWidget {
  const HomeFeaturedPropertiesSection({super.key, required this.properties});

  final List<HomePropertyItem> properties;

  @override
  Widget build(BuildContext context) {
    final columns = context.gridColumns.clamp(1, 3);

    return SectionWrapper(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: AnimatedSectionTitle(
                  overline: 'CURATED LISTINGS',
                  title: 'Featured properties',
                  subtitle: 'Handpicked homes ready for inspection and purchase.',
                  alignment: TextAlign.start,
                ),
              ),
              if (!context.isMobile)
                PrimaryButton(
                  label: 'Browse All',
                  variant: ButtonVariant.ghost,
                  onPressed: () => context.go(RoutePaths.properties),
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
                children: properties
                    .map(
                      (p) => SizedBox(
                        width: width,
                        child: PropertyCard(
                          title: p.title,
                          price: p.price,
                          location: p.location,
                          bedrooms: p.bedrooms,
                          bathrooms: p.bathrooms,
                          landSize: p.landSize,
                          status: p.status,
                          imageUrl: p.imageUrl,
                          onTap: () => context.go(p.route),
                          onBookInspection: () =>
                              context.go(RoutePaths.bookInspection),
                          onFavorite: () {},
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
