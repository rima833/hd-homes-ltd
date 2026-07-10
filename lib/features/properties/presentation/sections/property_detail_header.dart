import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/breadcrumbs.dart';
import 'package:hdhomesproject/core/website/components/page_container.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/core/widgets/feedback/app_badge.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_property.dart';
import 'package:hdhomesproject/features/properties/data/models/property_detail_content.dart';
import 'package:hdhomesproject/features/properties/data/providers/marketplace_controller.dart';
import 'package:hdhomesproject/features/properties/presentation/widgets/marketplace_badges.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Sections 2–3 — Summary + quick actions.
class PropertyDetailHeader extends ConsumerWidget {
  const PropertyDetailHeader({super.key, required this.detail});

  final PropertyDetailContent detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = detail.listing;
    final favorites = ref.watch(marketplaceFavoritesProvider);
    final isFavorite = favorites.contains(p.id);
    final currency = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WebsiteBreadcrumbs(
            items: [
              const BreadcrumbItem(label: 'Home', path: RoutePaths.home),
              const BreadcrumbItem(label: 'Properties', path: RoutePaths.properties),
              BreadcrumbItem(label: p.title),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          context.isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _content(context, ref, p, currency, isFavorite),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _content(context, ref, p, currency, isFavorite),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xl),
                    SizedBox(
                      width: 320,
                      child: PropertyStickyActions(detail: detail),
                    ),
                  ],
                ),
          if (context.isMobile) ...[
            const SizedBox(height: AppSpacing.lg),
            PropertyStickyActions(detail: detail, compact: true),
          ],
        ],
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    WidgetRef ref,
    MarketplaceProperty p,
    NumberFormat currency,
    bool isFavorite,
  ) =>
      [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            if (p.isFeatured) const AppBadge(label: 'Featured', variant: BadgeVariant.gold),
            if (p.isNew) const AppBadge(label: 'New', variant: BadgeVariant.success),
            if (p.isVerified) const AppBadge(label: 'Verified', variant: BadgeVariant.info),
            if (p.purpose == PropertyPurpose.invest)
              const AppBadge(label: 'Investment', variant: BadgeVariant.gold),
            MatchScoreBadge(score: p.matchScore),
          ],
        ),
        const SizedBox(height: AppSpacing.base),
        Text(p.title, style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${p.propertyCode} · ${p.estate} · ${p.location}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondaryLight,
              ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          p.price,
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: AppColors.gold,
                fontWeight: FontWeight.w800,
              ),
        ),
        if (detail.pricing.promotionalPrice != null)
          Text(
            'Promo: ${currency.format(detail.pricing.promotionalPrice)}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            _meta(Icons.home_work_outlined, p.type),
            _meta(Icons.flag_outlined, p.status),
            _meta(Icons.update_rounded, 'Updated ${_formatDate(detail.lastUpdated)}'),
          ],
        ),
        const SizedBox(height: AppSpacing.base),
        AvailabilityMeter(level: p.availability),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            IconButton(
              onPressed: () {
                final set = {...ref.read(marketplaceFavoritesProvider)};
                isFavorite ? set.remove(p.id) : set.add(p.id);
                ref.read(marketplaceFavoritesProvider.notifier).state = set;
              },
              icon: Icon(isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded),
              color: AppColors.gold,
            ),
            IconButton(
              onPressed: () => Share.share('${p.title} — ${p.price}\n${p.location}'),
              icon: const Icon(LucideIcons.share2),
            ),
          ],
        ),
      ];

  Widget _meta(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.lg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.gold),
          const SizedBox(width: AppSpacing.xs),
          Text(text, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';
}

class PropertyStickyActions extends StatelessWidget {
  const PropertyStickyActions({super.key, required this.detail, this.compact = false});

  final PropertyDetailContent detail;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.cardBorder,
        boxShadow: AppShadows.lg,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: compact ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
        children: [
          Text('Quick actions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.base),
          PrimaryButton(
            label: 'Book Inspection',
            icon: LucideIcons.calendar,
            expand: true,
            onPressed: () => context.go(RoutePaths.bookInspection),
          ),
          const SizedBox(height: AppSpacing.sm),
          PrimaryButton(
            label: 'Reserve Property',
            variant: ButtonVariant.secondary,
            expand: true,
            onPressed: () => context.go(RoutePaths.contact),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (!compact)
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _actionChip(context, 'WhatsApp', LucideIcons.messageCircle, () {
                  launchUrl(Uri.parse('https://wa.me/'));
                }),
                _actionChip(context, 'Call', LucideIcons.phone, () {
                  launchUrl(Uri.parse('tel:'));
                }),
                _actionChip(context, 'Brochure', LucideIcons.download, () {}),
              ],
            ),
        ],
      ),
    );
  }

  Widget _actionChip(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onPressed: onTap,
    );
  }
}
