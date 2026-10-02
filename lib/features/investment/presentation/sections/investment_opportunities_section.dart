import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/growth/analytics/analytics_events.dart';
import 'package:hdhomesproject/core/growth/analytics/analytics_service.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/investment/presentation/widgets/investment_opportunity_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

/// Premium, CMS-driven Current Investment Opportunities section.
class InvestmentOpportunitiesSection extends HookConsumerWidget {
  const InvestmentOpportunitiesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(websiteInvestmentOpportunitiesRealtimeProvider);
    ref.watch(websiteInvestmentCategoriesRealtimeProvider);

    final asyncItems =
        ref.watch(publishedWebsiteInvestmentOpportunitiesProvider);
    final asyncCategories =
        ref.watch(publishedWebsiteInvestmentCategoriesProvider);
    final page = ref.watch(publishedPageBySlugProvider('investment')).valueOrNull;
    final content = page?.content ?? const <String, dynamic>{};

    final overline = _pick(content, const [
          'opportunitiesOverline',
          'opportunities_overline',
        ]) ??
        'OPPORTUNITIES';
    final title = _pick(content, const [
          'opportunitiesTitle',
          'opportunities_title',
        ]) ??
        'Current investment opportunities';
    final subtitle = _pick(content, const [
          'opportunitiesSubtitle',
          'opportunities_subtitle',
        ]) ??
        'Off-plan, rental income, land banking, commercial, and fractional products.';

    String? initialCategory;
    try {
      initialCategory =
          GoRouterState.of(context).uri.queryParameters['category'];
    } catch (_) {
      initialCategory = null;
    }

    final selectedSlug = useState<String?>(
      (initialCategory == null || initialCategory.isEmpty)
          ? null
          : initialCategory,
    );
    final query = useState('');
    final searchCtrl = useTextEditingController();

    final mobile = context.isMobile;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return SectionWrapper(
      backgroundColor: kInvestmentHubBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InvestmentSectionHeader(
            overline: overline,
            title: title,
            subtitle: subtitle,
            mobile: mobile,
          ),
          const SizedBox(height: AppSpacing.xl),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 720;
              final search = SizedBox(
                width: stacked ? double.infinity : 280,
                child: TextField(
                  controller: searchCtrl,
                  onChanged: (v) => query.value = v,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search investments',
                    hintStyle: const TextStyle(color: kInvestmentMuted),
                    prefixIcon: const Icon(
                      LucideIcons.search,
                      size: 16,
                      color: kInvestmentMuted,
                    ),
                    filled: true,
                    fillColor: kInvestmentCardBg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide(
                        color: kInvestmentGold.withValues(alpha: 0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide(
                        color: kInvestmentGold.withValues(alpha: 0.2),
                      ),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                      borderSide: BorderSide(color: kInvestmentGold),
                    ),
                  ),
                ),
              );
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    search,
                    const SizedBox(height: 14),
                    InvestmentFilterBar(
                      categories: asyncCategories.valueOrNull ?? const [],
                      selectedSlug: selectedSlug.value,
                      onSelected: (slug) {
                        selectedSlug.value = slug;
                        _syncCategoryQuery(context, slug);
                      },
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: InvestmentFilterBar(
                      categories: asyncCategories.valueOrNull ?? const [],
                      selectedSlug: selectedSlug.value,
                      onSelected: (slug) {
                        selectedSlug.value = slug;
                        _syncCategoryQuery(context, slug);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  search,
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          asyncItems.when(
            loading: () => LayoutBuilder(
              builder: (context, constraints) {
                final cross = constraints.maxWidth < 800 ? 1 : 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 4,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cross,
                    mainAxisSpacing: 18,
                    crossAxisSpacing: 18,
                    mainAxisExtent: mobile ? 460 : 300,
                  ),
                  itemBuilder: (context, index) => const InvestmentCardSkeleton(),
                );
              },
            ),
            error: (err, _) => InvestmentEmptyState(
              title: 'Unable to load opportunities',
              message: '$err',
            ),
            data: (items) {
              final filtered = _filter(
                items,
                categorySlug: selectedSlug.value,
                categories: asyncCategories.valueOrNull ?? const [],
                query: query.value,
              );
              if (filtered.isEmpty) {
                return InvestmentEmptyState(
                  title: items.isEmpty
                      ? 'No investment opportunities are currently available.'
                      : 'No matching investment opportunities.',
                  message: items.isEmpty
                      ? 'Published opportunities from the HD Homes Admin Panel appear here in real time.'
                      : 'Try another category or search term.',
                );
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  final cross = constraints.maxWidth < 800 ? 1 : 2;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cross,
                      mainAxisSpacing: 18,
                      crossAxisSpacing: 18,
                      mainAxisExtent: mobile ? 520 : 310,
                    ),
                    itemBuilder: (context, i) {
                      final card = PremiumInvestmentCard(
                        item: filtered[i],
                        mobile: mobile,
                        onView: () => _openOpportunity(context, ref, filtered[i]),
                      );
                      if (reduceMotion) return card;
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(milliseconds: 420 + (i * 60)),
                        curve: Curves.easeOutCubic,
                        builder: (context, t, child) => Opacity(
                          opacity: t,
                          child: Transform.translate(
                            offset: Offset(0, (1 - t) * 16),
                            child: child,
                          ),
                        ),
                        child: card,
                      );
                    },
                  );
                },
              );
            },
          ),
          const SizedBox(height: AppSpacing.xxl),
          InvestmentTrustStrip(mobile: mobile),
        ],
      ),
    );
  }

  List<CmsWebsiteInvestmentOpportunity> _filter(
    List<CmsWebsiteInvestmentOpportunity> items, {
    required String? categorySlug,
    required List<CmsWebsiteInvestmentCategory> categories,
    required String query,
  }) {
    final q = query.trim().toLowerCase();
    return items.where((item) {
      if (categorySlug != null && categorySlug.isNotEmpty) {
        final cat = categories.where((c) => c.id == item.categoryId).firstOrNull;
        final matchesId = cat?.slug == categorySlug;
        final matchesLabel = item.categorySlug == categorySlug;
        if (!matchesId && !matchesLabel) return false;
      }
      if (q.isEmpty) return true;
      final hay = [
        item.projectName,
        item.locationDisplay,
        item.city,
        item.shortDescription,
        item.categoryLabel,
        item.opportunityStatus,
        item.riskLevel,
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  void _syncCategoryQuery(BuildContext context, String? slug) {
    try {
      final uri = GoRouterState.of(context).uri;
      if (uri.path != RoutePaths.investment) return;
      final next = Map<String, String>.from(uri.queryParameters);
      if (slug == null || slug.isEmpty) {
        next.remove('category');
      } else {
        next['category'] = slug;
      }
      context.go(
        uri.replace(queryParameters: next).toString(),
      );
    } catch (_) {}
  }

  Future<void> _openOpportunity(
    BuildContext context,
    WidgetRef ref,
    CmsWebsiteInvestmentOpportunity item,
  ) async {
    ref.read(analyticsProvider.notifier).track(
          AnalyticsEvent(
            type: AnalyticsEventType.custom,
            name: 'investment_cta_clicked',
            timestamp: DateTime.now(),
            path: item.detailPath,
            entityId: item.id,
            properties: {'slug': item.slug, 'cta': item.ctaLabel},
          ),
        );
    final custom = item.ctaLink?.trim();
    if (custom != null &&
        custom.isNotEmpty &&
        custom != '#' &&
        (custom.startsWith('http://') || custom.startsWith('https://'))) {
      final uri = Uri.tryParse(custom);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    if (!context.mounted) return;
    context.go(item.detailPath);
  }

  String? _pick(Map<String, dynamic> content, List<String> keys) {
    for (final key in keys) {
      final v = content[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }
}

class PremiumInvestmentCard extends StatefulWidget {
  const PremiumInvestmentCard({
    super.key,
    required this.item,
    required this.mobile,
    required this.onView,
  });

  final CmsWebsiteInvestmentOpportunity item;
  final bool mobile;
  final VoidCallback onView;

  @override
  State<PremiumInvestmentCard> createState() => _PremiumInvestmentCardState();
}

class _PremiumInvestmentCardState extends State<PremiumInvestmentCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: reduceMotion ? Duration.zero : AppDurations.fast,
        transform: Matrix4.translationValues(
          0,
          (!reduceMotion && _hovered) ? -4 : 0,
          0,
        ),
        decoration: BoxDecoration(
          color: kInvestmentCardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: kInvestmentGold.withValues(alpha: _hovered ? 0.55 : 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: kInvestmentGold.withValues(alpha: _hovered ? 0.16 : 0.04),
              blurRadius: _hovered ? 28 : 12,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onView,
            child: widget.mobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Cover(item: item, hovered: _hovered, height: 170),
                      Expanded(child: _CardBody(item: item, onView: widget.onView)),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        flex: 11,
                        child: _CardBody(item: item, onView: widget.onView),
                      ),
                      Expanded(
                        flex: 9,
                        child: _Cover(
                          item: item,
                          hovered: _hovered,
                          fadeLeft: true,
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

class _Cover extends StatelessWidget {
  const _Cover({
    required this.item,
    required this.hovered,
    this.fadeLeft = false,
    this.height,
  });

  final CmsWebsiteInvestmentOpportunity item;
  final bool hovered;
  final bool fadeLeft;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final url = item.coverImageUrl?.trim();
    Widget image = url == null || url.isEmpty
        ? const ColoredBox(
            color: Color(0xFF12151C),
            child: Center(
              child: Icon(LucideIcons.building2, color: kInvestmentGold, size: 36),
            ),
          )
        : MediaDeliveryImage(
            url: url,
            fit: BoxFit.cover,
            errorWidget: const ColoredBox(
              color: Color(0xFF12151C),
              child: Center(
                child: Icon(
                  LucideIcons.imageOff,
                  color: kInvestmentMuted,
                  size: 28,
                ),
              ),
            ),
          );

    image = AnimatedScale(
      scale: hovered ? 1.05 : 1,
      duration: AppDurations.normal,
      child: image,
    );

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          image,
          if (fadeLeft)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    kInvestmentCardBg,
                    Color(0xCC171A21),
                    Color(0x00171A21),
                  ],
                  stops: [0, 0.28, 0.72],
                ),
              ),
            ),
          if (item.isFeatured)
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: kInvestmentGold,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item.featuredBadge.isEmpty ? 'Featured' : item.featuredBadge,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({required this.item, required this.onView});

  final CmsWebsiteInvestmentOpportunity item;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InvestmentCategoryBadge(label: item.categoryLabel),
              const Spacer(),
              InvestmentStatusBadge(
                status: item.opportunityStatus,
                label: item.statusLabel,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            item.projectName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          if (item.locationDisplay.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(LucideIcons.mapPin, size: 13, color: kInvestmentMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.locationDisplay,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kInvestmentMuted,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            item.shortDescription,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: kInvestmentMuted,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          if (item.showProgress && item.progressPct > 0) ...[
            const SizedBox(height: 12),
            InvestmentProgressBar(progress: item.progressFraction),
          ],
          const Spacer(),
          Row(
            children: [
              InvestmentMetric(
                label: 'ROI',
                value: item.roiDisplay,
                icon: LucideIcons.barChart3,
              ),
              InvestmentMetric(
                label: 'Duration',
                value: item.duration,
                icon: LucideIcons.calendar,
              ),
              InvestmentMetric(
                label: 'Min',
                value: item.minimumInvestment,
                icon: LucideIcons.coins,
              ),
              InvestmentMetric(
                label: 'Risk',
                value: item.riskLevel,
                icon: LucideIcons.shield,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onView,
              style: TextButton.styleFrom(
                foregroundColor: kInvestmentGold,
                padding: EdgeInsets.zero,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.ctaLabel.isEmpty ? 'View Opportunity' : item.ctaLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 6),
                  const Icon(LucideIcons.arrowRight, size: 15),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
