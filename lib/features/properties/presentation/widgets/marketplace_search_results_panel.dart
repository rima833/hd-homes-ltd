import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_property.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Live property matches shown beneath the marketplace search bar.
class MarketplaceSearchResultsPanel extends StatelessWidget {
  const MarketplaceSearchResultsPanel({
    super.key,
    required this.query,
    required this.results,
    required this.totalCount,
    this.loading = false,
    this.onSeeAll,
  });

  final String query;
  final List<MarketplaceProperty> results;
  final int totalCount;
  final bool loading;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      decoration: BoxDecoration(
        color: const Color(0xFF12151C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: loading
                      ? Text(
                          'Searching published listings…',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: AppColors.slate500,
                              ),
                        )
                      : Text.rich(
                          TextSpan(
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppColors.slate500,
                                ),
                            children: [
                              TextSpan(text: '$totalCount ${totalCount == 1 ? 'property' : 'properties'} match your search '),
                              TextSpan(
                                text: "'$trimmed'",
                                style: const TextStyle(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                if (!loading && totalCount > 0)
                  TextButton(
                    onPressed: onSeeAll,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('See all results'),
                        SizedBox(width: 4),
                        Icon(LucideIcons.arrowRight, size: 14),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.gold,
                  ),
                ),
              ),
            )
          else if (results.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'No published properties match that search. Try a city, estate, property name, or code.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.slate500,
                      height: 1.45,
                    ),
              ),
            )
          else ...[
            for (var i = 0; i < results.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              _PropertySearchResultTile(property: results[i]),
            ],
          ],
          if (!loading && totalCount > results.length) ...[
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "Can't find what you're looking for?",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.slate500,
                          ),
                    ),
                  ),
                  TextButton(
                    onPressed: onSeeAll,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('View all properties'),
                        SizedBox(width: 4),
                        Icon(LucideIcons.arrowRight, size: 14),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PropertySearchResultTile extends StatelessWidget {
  const _PropertySearchResultTile({required this.property});

  final MarketplaceProperty property;

  String get _locationLabel {
    final parts = <String>[];
    if (property.estate.isNotEmpty) parts.add(property.estate);
    if (property.city.isNotEmpty) parts.add(property.city);
    if (parts.isEmpty && property.location.isNotEmpty) return property.location;
    return parts.join(', ');
  }

  String get _categoryLabel => switch (property.category) {
        PropertyCategory.commercial => 'Commercial',
        PropertyCategory.land => 'Land',
        PropertyCategory.investment => 'Investment',
        PropertyCategory.residential => 'Residential',
      };

  void _open(BuildContext context) {
    final slug = property.slug.isNotEmpty ? property.slug : property.id;
    context.go('/properties/$slug');
  }

  @override
  Widget build(BuildContext context) {
    final specs = <String>[
      if (property.bedrooms > 0) '${property.bedrooms} Beds',
      if (property.bathrooms > 0) '${property.bathrooms} Baths',
      if (property.buildingSize.isNotEmpty && property.buildingSize != '—')
        property.buildingSize
      else if (property.landSize.isNotEmpty && property.landSize != '—')
        property.landSize,
    ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 88,
                  height: 72,
                  child: property.imageUrl != null
                      ? MediaDeliveryImage(
                          url: property.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: const ColoredBox(
                            color: AppColors.charcoal,
                            child: Center(
                              child: Icon(
                                LucideIcons.home,
                                color: AppColors.gold,
                                size: 22,
                              ),
                            ),
                          ),
                          errorWidget: const ColoredBox(
                            color: AppColors.charcoal,
                            child: Center(
                              child: Icon(
                                LucideIcons.home,
                                color: AppColors.gold,
                                size: 22,
                              ),
                            ),
                          ),
                        )
                      : const ColoredBox(
                          color: AppColors.charcoal,
                          child: Center(
                            child: Icon(
                              LucideIcons.home,
                              color: AppColors.gold,
                              size: 22,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (property.isFeatured)
                      Text(
                        'FEATURED',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.gold,
                              letterSpacing: 1.4,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    Text(
                      property.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.playfairDisplay(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.mapPin,
                          size: 12,
                          color: AppColors.slate500,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _locationLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.slate500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (specs.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: specs
                            .map(
                              (spec) => Text(
                                spec,
                                style: const TextStyle(
                                  color: AppColors.slate500,
                                  fontSize: 11,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Text(
                      _categoryLabel,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'From',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.slate500,
                        ),
                  ),
                  Text(
                    property.price,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  const Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: AppColors.gold,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
