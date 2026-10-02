import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/website/seo/seo_binder.dart';
import 'package:hdhomesproject/core/website/seo/seo_config.dart';
import 'package:hdhomesproject/core/website/seo/seo_metadata.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Dynamic investment opportunity detail page (`/investment/:slug`).
class InvestmentOpportunityDetailPage extends ConsumerWidget {
  const InvestmentOpportunityDetailPage({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(websiteInvestmentOpportunitiesRealtimeProvider);
    final async = ref.watch(publishedWebsiteInvestmentBySlugProvider(slug));

    return async.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        body: Center(
          child: Text(
            userFacingError(err, fallback: 'Unable to load opportunity.'),
          ),
        ),
      ),
      data: (item) {
        if (item == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Opportunity not found'),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go(RoutePaths.investment),
                    child: const Text('Back to investments'),
                  ),
                ],
              ),
            ),
          );
        }

        final mobile = context.isMobile;
        final progress = (item.progressPct / 100).clamp(0.0, 1.0);

        return SeoBinder(
          metadata: SeoMetadata(
            title: item.seoTitle,
            description: item.seoDescription,
            canonicalUrl: SeoConfig.canonicalFor(item.detailPath),
            ogImageUrl: item.coverImageUrl,
            keywords: [
              'investment',
              item.categoryLabel,
              item.locationDisplay,
              'HD Homes',
            ],
          ),
          child: Scaffold(
          backgroundColor: const Color(0xFF0F1117),
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: const Color(0xFF0F1117),
                foregroundColor: AppColors.white,
                pinned: true,
                title: Text(item.projectName),
                leading: IconButton(
                  icon: const Icon(LucideIcons.arrowLeft),
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(RoutePaths.home);
                    }
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: SectionWrapper(
                  backgroundColor: const Color(0xFF0F1117),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.coverImageUrl != null &&
                          item.coverImageUrl!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: AspectRatio(
                            aspectRatio: mobile ? 16 / 10 : 21 / 9,
                            child: MediaDeliveryImage(
                              url: item.coverImageUrl!,
                              fit: BoxFit.cover,
                              errorWidget: Container(
                                color: const Color(0xFF12151C),
                                alignment: Alignment.center,
                                child: const Icon(LucideIcons.imageOff, color: Color(0xFF8B909A)),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.xl),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          if (item.isFeatured)
                            _Chip(
                              label: item.featuredBadge,
                              gold: true,
                              icon: LucideIcons.crown,
                            ),
                          if ((item.demandBadge ?? '').isNotEmpty)
                            _Chip(
                              label: item.demandBadge!,
                              gold: false,
                              icon: LucideIcons.flame,
                            ),
                          _Chip(
                            label: item.investmentType,
                            gold: false,
                          ),
                          _Chip(
                            label: item.opportunityStatus
                                .replaceAll('_', ' ')
                                .toUpperCase(),
                            gold: false,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        item.projectName,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: mobile ? 32 : 44,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                      if (item.locationDisplay.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.mapPin,
                              size: 16,
                              color: AppColors.gold,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              item.locationDisplay,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(color: AppColors.textSecondaryDark),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        item.shortDescription,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.textSecondaryDark,
                              height: 1.45,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _StatCard(label: 'Expected ROI', value: item.roiDisplay),
                          _StatCard(label: 'Type', value: item.typeLabel),
                          _StatCard(label: 'Duration', value: item.duration),
                          _StatCard(label: 'Risk', value: item.riskLevel),
                          _StatCard(label: 'Growth', value: item.growthPotential),
                          if (item.minimumInvestment.isNotEmpty)
                            _StatCard(
                              label: 'Minimum',
                              value: item.minimumInvestment,
                            ),
                        ],
                      ),
                      if (item.progressPct > 0) ...[
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          'Funding progress',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (item.amountRaised.isNotEmpty)
                              Text(
                                '${item.amountRaised} raised',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: AppColors.textSecondaryDark),
                              ),
                            const Spacer(),
                            Text(
                              '${item.progressPct.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor:
                                AppColors.gold.withValues(alpha: 0.12),
                            color: AppColors.gold,
                          ),
                        ),
                        if (item.targetAmount.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Target ${item.targetAmount}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondaryDark,
                                ),
                          ),
                        ],
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'About this opportunity',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        item.fullDescription.isNotEmpty
                            ? item.fullDescription
                            : item.shortDescription,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.textSecondaryDark,
                              height: 1.6,
                            ),
                      ),
                      if (item.galleryImages.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          'Gallery',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          height: 160,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: item.galleryImages.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, i) => ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: AspectRatio(
                                aspectRatio: 4 / 3,
                                child: MediaDeliveryImage(
                                  url: item.galleryImages[i],
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xxl),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed: item.isOpenForEnquiry
                                ? () => context.go(
                                      Uri(
                                        path: RoutePaths.bookConsultation,
                                        queryParameters: {
                                          'property': item.projectName,
                                          'interest': 'Investment enquiry',
                                          'source': 'investment',
                                          'slug': item.slug,
                                        },
                                      ).toString(),
                                    )
                                : null,
                            icon: const Icon(LucideIcons.messageSquare),
                            label: Text(
                              item.secondaryCtaLabel.trim().isNotEmpty
                                  ? item.secondaryCtaLabel
                                  : item.isOpenForEnquiry
                                      ? 'Request Information'
                                      : 'Currently ${item.statusLabel}',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.gold,
                              foregroundColor: Colors.black,
                              disabledBackgroundColor:
                                  AppColors.gold.withValues(alpha: 0.25),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 16,
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => context.go(
                              Uri(
                                path: RoutePaths.bookInspection,
                                queryParameters: {
                                  'estate': item.slug,
                                },
                              ).toString(),
                            ),
                            icon: const Icon(LucideIcons.calendarCheck),
                            label: const Text('Book Inspection'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.gold,
                              side: const BorderSide(color: AppColors.gold),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 16,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                context.go(RoutePaths.investment),
                            child: const Text('All opportunities'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.gold,
    this.icon,
  });

  final String label;
  final bool gold;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: gold ? AppColors.gold : const Color(0xFF151821),
        border: gold
            ? null
            : Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: gold ? Colors.black : AppColors.gold),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: gold ? Colors.black : AppColors.gold,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: context.isMobile ? double.infinity : 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF151821),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
