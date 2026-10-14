import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_filters.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_property.dart';
import 'package:hdhomesproject/features/properties/data/providers/marketplace_controller.dart';
import 'package:lucide_icons/lucide_icons.dart';

const _bg = Color(0xFF0A0A0A);
const _gold = Color(0xFFD4AF37);
const _goldBright = Color(0xFFE8C56A);
const _muted = Color(0xFF9A9A9A);
const _card = Color(0xFF141414);

/// Premium Browse-by-Category — featured card and category grid.
/// Listing counts update live from published marketplace inventory.
class MarketplaceCategoriesSection extends ConsumerWidget {
  const MarketplaceCategoriesSection({
    super.key,
    this.navigateOnSelect = false,
  });

  /// When true (homepage), tapping a category opens `/properties?category=…`
  /// instead of filtering in-place.
  final bool navigateOnSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(publishedPropertiesRealtimeProvider);
    final categories = ref.watch(marketplaceCmsProvider).categories;
    final activeKey = ref.watch(marketplaceFiltersProvider).categoryKey;
    final featured = categories.where((c) => c.isFeatured).firstOrNull ??
        (categories.isEmpty ? null : categories.first);
    final grid = categories.where((c) => !c.isFeatured).toList();

    return ColoredBox(
      color: _bg,
      child: SectionWrapper(
        backgroundColor: _bg,
        bandPadding: EdgeInsets.zero,
        compact: true,
        padding: EdgeInsets.fromLTRB(
          context.pagePadding,
          context.isMobile ? 36 : 48,
          context.pagePadding,
          context.isMobile ? 40 : 56,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 1,
                    color: _gold.withValues(alpha: 0.45),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    'DISCOVER',
                    style: GoogleFonts.manrope(
                      color: _gold,
                      fontSize: 11,
                      letterSpacing: 3.6,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 1,
                    color: _gold.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Colors.white, _goldBright, _gold],
              ).createShader(bounds),
              child: Text(
                'Browse by Category',
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  color: Colors.white,
                  fontSize: context.isMobile ? 30 : 40,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Text(
                'Find the perfect property that fits your lifestyle, goals, and investment vision.',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: _muted,
                  fontSize: 14.5,
                  height: 1.5,
                ),
              ),
            ),
            SizedBox(height: context.isMobile ? 28 : 36),
            if (featured != null)
              context.isMobile
                  ? Column(
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 11,
                          child: _FeaturedCategoryCard(
                            card: featured,
                            height: double.infinity,
                            selected: !navigateOnSelect &&
                                activeKey == featured.filterKey,
                            onTap: () => _onCategoryTap(
                              context,
                              ref,
                              featured.filterKey,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _CategoryGrid(
                          cards: grid,
                          activeKey: navigateOnSelect ? null : activeKey,
                          onTap: (key) => _onCategoryTap(context, ref, key),
                        ),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: AspectRatio(
                            aspectRatio: 0.92,
                            child: _FeaturedCategoryCard(
                              card: featured,
                              height: double.infinity,
                              selected: !navigateOnSelect &&
                                  activeKey == featured.filterKey,
                              onTap: () => _onCategoryTap(
                                context,
                                ref,
                                featured.filterKey,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 7,
                          child: _CategoryGrid(
                            cards: grid,
                            activeKey: navigateOnSelect ? null : activeKey,
                            onTap: (key) =>
                                _onCategoryTap(context, ref, key),
                          ),
                        ),
                      ],
                    ),
          ],
        ),
      ),
    );
  }

  void _onCategoryTap(BuildContext context, WidgetRef ref, String key) {
    if (navigateOnSelect) {
      // Investment category bridges into the investment hub (ROI / products).
      if (key == 'investment' || key == 'investments') {
        context.go(RoutePaths.investment);
        return;
      }
      context.go('${RoutePaths.properties}?category=$key');
      return;
    }
    final current = ref.read(marketplaceFiltersProvider);
    final togglingOff = current.categoryKey == key;
    ref.read(marketplaceFiltersProvider.notifier).state = current.copyWith(
      categoryKey: togglingOff ? null : key,
      clearCategoryKey: togglingOff,
      sort: key == 'new' || key == 'new_launches'
          ? MarketplaceSort.newest
          : key == 'hot'
              ? MarketplaceSort.popular
              : current.sort,
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.cards,
    required this.activeKey,
    required this.onTap,
  });

  final List<MarketplaceCategoryCard> cards;
  final String? activeKey;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final cols = context.isMobile ? 2 : 3;
    final extent = context.isMobile ? 148.0 : 168.0;
    if (cards.isEmpty) return const SizedBox.shrink();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisExtent: extent,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final card = cards[index];
        return _GridCategoryCard(
          card: card,
          selected: activeKey == card.filterKey,
          onTap: () => onTap(card.filterKey),
        );
      },
    );
  }
}

class _FeaturedCategoryCard extends StatefulWidget {
  const _FeaturedCategoryCard({
    required this.card,
    required this.onTap,
    this.selected = false,
    this.height,
  });

  final MarketplaceCategoryCard card;
  final VoidCallback onTap;
  final bool selected;
  final double? height;

  @override
  State<_FeaturedCategoryCard> createState() => _FeaturedCategoryCardState();
}

class _FeaturedCategoryCardState extends State<_FeaturedCategoryCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final image = card.imageUrl?.trim();
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: widget.height == null
              ? const BoxConstraints(minHeight: 360)
              : const BoxConstraints.expand(),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _gold.withValues(
                alpha: widget.selected || _hover ? 0.85 : 0.4,
              ),
              width: widget.selected ? 1.6 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _gold.withValues(alpha: _hover || widget.selected ? 0.28 : 0.12),
                blurRadius: 28,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image != null && image.isNotEmpty)
                MediaDeliveryImage(
                  url: image,
                  fit: BoxFit.cover,
                  errorWidget: Container(color: _card),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_card, _gold.withValues(alpha: 0.25)],
                    ),
                  ),
                ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.25),
                      Colors.black.withValues(alpha: 0.82),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _gold,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'FEATURED',
                        style: GoogleFonts.manrope(
                          color: _bg,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _gold, width: 1.4),
                        color: Colors.black.withValues(alpha: 0.35),
                      ),
                      child: Icon(_icon(card.iconName), color: _gold, size: 22),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      card.label,
                      style: GoogleFonts.playfairDisplay(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${card.count} Listings',
                      style: GoogleFonts.manrope(
                        color: _goldBright,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (card.description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        card.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 13.5,
                          height: 1.45,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Text(
                          'Explore Now',
                          style: GoogleFonts.manrope(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: _gold,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.arrowRight,
                            color: _bg,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _GridCategoryCard extends StatefulWidget {
  const _GridCategoryCard({
    required this.card,
    required this.onTap,
    this.selected = false,
  });

  final MarketplaceCategoryCard card;
  final VoidCallback onTap;
  final bool selected;

  @override
  State<_GridCategoryCard> createState() => _GridCategoryCardState();
}

class _GridCategoryCardState extends State<_GridCategoryCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final image = card.imageUrl?.trim();
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _gold.withValues(
                alpha: widget.selected || _hover ? 0.7 : 0.28,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: _gold.withValues(alpha: _hover ? 0.18 : 0.06),
                blurRadius: _hover ? 18 : 10,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image != null && image.isNotEmpty)
                ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.55),
                    BlendMode.darken,
                  ),
                  child: MediaDeliveryImage(
                    url: image,
                    fit: BoxFit.cover,
                    errorWidget: Container(color: _card),
                  ),
                )
              else
                Container(color: _card),
              Container(color: Colors.black.withValues(alpha: 0.45)),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _gold.withValues(alpha: 0.75)),
                      ),
                      child: Icon(_icon(card.iconName), color: _gold, size: 16),
                    ),
                    const Spacer(),
                    Text(
                      card.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.playfairDisplay(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${card.count} Listings',
                            style: GoogleFonts.manrope(
                              color: _muted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _gold.withValues(alpha: 0.55),
                            ),
                          ),
                          child: const Icon(
                            LucideIcons.arrowRight,
                            color: _gold,
                            size: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


IconData _icon(String name) => switch (name) {
      'crown' => LucideIcons.crown,
      'building' => LucideIcons.building2,
      'map' => LucideIcons.map,
      'trending' => LucideIcons.trendingUp,
      'sparkles' => LucideIcons.sparkles,
      'flame' => LucideIcons.flame,
      'users' => LucideIcons.users,
      _ => LucideIcons.home,
    };
