import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/client/domain/entities/client_models.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/client_portal_widgets.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Property card matching the Client Portal "My Properties" mockup.
class ClientPropertyCard extends StatelessWidget {
  const ClientPropertyCard({
    super.key,
    required this.property,
    this.onTap,
    this.onViewDetails,
    this.onScheduleInspection,
    this.showSaveButton = false,
    this.isSaved = false,
    this.onToggleSave,
    this.compareSelected = false,
    this.onCompareToggle,
    this.isGrid = true,
    this.onMore,
    this.imageHeight,
  });

  final ClientProperty property;
  final VoidCallback? onTap;
  final VoidCallback? onViewDetails;
  final VoidCallback? onScheduleInspection;
  final bool showSaveButton;
  final bool isSaved;
  final VoidCallback? onToggleSave;
  final bool compareSelected;
  final ValueChanged<bool>? onCompareToggle;
  final bool isGrid;
  final VoidCallback? onMore;

  /// When set on vertical cards, replaces the 16:10 aspect ratio with a fixed height.
  final double? imageHeight;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final horizontal = !isGrid || wide;

    return ClientPortalCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap ?? onViewDetails,
        borderRadius: AppRadius.cardBorder,
        child: horizontal
            ? _HorizontalBody(
                property: property,
                onViewDetails: onViewDetails,
                onScheduleInspection: onScheduleInspection,
                onMore: onMore,
                showSaveButton: showSaveButton,
                isSaved: isSaved,
                onToggleSave: onToggleSave,
              )
            : _VerticalBody(
                property: property,
                onViewDetails: onViewDetails,
                onScheduleInspection: onScheduleInspection,
                onMore: onMore,
                showSaveButton: showSaveButton,
                isSaved: isSaved,
                onToggleSave: onToggleSave,
                compareSelected: compareSelected,
                onCompareToggle: onCompareToggle,
                imageHeight: imageHeight,
              ),
      ),
    );
  }
}

class _HorizontalBody extends StatelessWidget {
  const _HorizontalBody({
    required this.property,
    this.onViewDetails,
    this.onScheduleInspection,
    this.onMore,
    this.showSaveButton = false,
    this.isSaved = false,
    this.onToggleSave,
  });

  final ClientProperty property;
  final VoidCallback? onViewDetails;
  final VoidCallback? onScheduleInspection;
  final VoidCallback? onMore;
  final bool showSaveButton;
  final bool isSaved;
  final VoidCallback? onToggleSave;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: MediaQuery.sizeOf(context).width >= 1100 ? 300 : 240,
            child: _HeroImage(
              imageUrl: property.imageUrl,
              badgeLabel: property.displayBadgeLabel,
              badgeSuccess: !property.isHandedOver,
              photoCount: property.photoCount,
              showSaveButton: showSaveButton,
              isSaved: isSaved,
              onToggleSave: onToggleSave,
              onMore: onMore,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(12),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
              child: _PropertyDetails(
                property: property,
                onViewDetails: onViewDetails,
                onScheduleInspection: onScheduleInspection,
                inspectLabel: 'Inspect Property',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalBody extends StatelessWidget {
  const _VerticalBody({
    required this.property,
    this.onViewDetails,
    this.onScheduleInspection,
    this.onMore,
    this.showSaveButton = false,
    this.isSaved = false,
    this.onToggleSave,
    this.compareSelected = false,
    this.onCompareToggle,
    this.imageHeight,
  });

  final ClientProperty property;
  final VoidCallback? onViewDetails;
  final VoidCallback? onScheduleInspection;
  final VoidCallback? onMore;
  final bool showSaveButton;
  final bool isSaved;
  final VoidCallback? onToggleSave;
  final bool compareSelected;
  final ValueChanged<bool>? onCompareToggle;
  final double? imageHeight;

  @override
  Widget build(BuildContext context) {
    final hero = _HeroImage(
      imageUrl: property.imageUrl,
      badgeLabel: property.displayBadgeLabel,
      badgeSuccess: !property.isHandedOver,
      photoCount: property.photoCount,
      showSaveButton: showSaveButton,
      isSaved: isSaved,
      onToggleSave: onToggleSave,
      compareSelected: compareSelected,
      onCompareToggle: onCompareToggle,
      onMore: onMore,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (imageHeight != null)
          SizedBox(
            height: imageHeight,
            width: double.infinity,
            child: hero,
          )
        else
          AspectRatio(
            aspectRatio: 16 / 10,
            child: hero,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: _PropertyDetails(
            property: property,
            onViewDetails: onViewDetails,
            onScheduleInspection: onScheduleInspection,
            inspectLabel: 'Inspect Property',
          ),
        ),
      ],
    );
  }
}

class _PropertyDetails extends StatelessWidget {
  const _PropertyDetails({
    required this.property,
    this.onViewDetails,
    this.onScheduleInspection,
    required this.inspectLabel,
  });

  final ClientProperty property;
  final VoidCallback? onViewDetails;
  final VoidCallback? onScheduleInspection;
  final String inspectLabel;

  @override
  Widget build(BuildContext context) {
    final due = property.nextDueDate;
    final dueLabel = due != null ? DateFormat.yMMMd().format(due) : '—';
    final celebration = property.celebrationMessage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          property.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
        ),
        if (property.location != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                LucideIcons.mapPin,
                size: 14,
                color: AppColors.slate400,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  property.location!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.slate400),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                property.formattedPrice,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            if (property.propertyCode != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.neutral800,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  property.propertyCode!,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: AppColors.slate400),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          property.paymentStyleLabel,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.gold.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
              ),
        ),
        if (celebration.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  LucideIcons.sparkles,
                  size: 16,
                  color: AppColors.success,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    celebration,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.white,
                          height: 1.35,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        _LabeledProgress(
          label: 'Payment Progress',
          percent: property.paymentProgressPct,
          color: AppColors.gold,
          detail:
              '${property.formattedAmountPaid} paid of ${property.formattedPrice}',
        ),
        const SizedBox(height: 12),
        _LabeledProgress(
          label: 'Construction Progress',
          percent: property.constructionProgressPct,
          color: AppColors.info,
          detail: property.constructionPhaseLabel,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _MetaCell(
                icon: LucideIcons.calendar,
                label: 'Due Date',
                value: dueLabel,
              ),
            ),
            Expanded(
              child: _MetaCell(
                icon: LucideIcons.home,
                label: 'Property Type',
                value: property.typeLabel,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _MetaCell(
                icon: LucideIcons.bedDouble,
                label: 'Unit',
                value: property.unitLabel,
              ),
            ),
            Expanded(
              child: _MetaCell(
                icon: LucideIcons.hardHat,
                label: 'Status',
                value: property.constructionStatusLabel,
              ),
            ),
          ],
        ),
        if (onViewDetails != null || onScheduleInspection != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              if (onViewDetails != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onViewDetails,
                    icon: const Icon(LucideIcons.eye, size: 16),
                    label: const Text('View Details'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.gold,
                      side: const BorderSide(color: AppColors.gold),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
              if (onViewDetails != null && onScheduleInspection != null)
                const SizedBox(width: 10),
              if (onScheduleInspection != null)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onScheduleInspection,
                    icon: const Icon(LucideIcons.calendar, size: 16),
                    label: Text(inspectLabel),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.charcoal,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _LabeledProgress extends StatelessWidget {
  const _LabeledProgress({
    required this.label,
    required this.percent,
    required this.color,
    required this.detail,
  });

  final String label;
  final double percent;
  final Color color;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.slate400,
                    ),
              ),
            ),
            Text(
              '${percent.clamp(0, 100).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClientProgressBar(
          label: '',
          percent: percent,
          color: color,
          height: 7,
          showLabel: false,
        ),
        const SizedBox(height: 4),
        Text(
          detail,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.slate500,
              ),
        ),
      ],
    );
  }
}

class _MetaCell extends StatelessWidget {
  const _MetaCell({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.gold),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.slate500,
                    ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({
    required this.imageUrl,
    required this.badgeLabel,
    required this.badgeSuccess,
    required this.photoCount,
    required this.showSaveButton,
    required this.isSaved,
    this.onToggleSave,
    this.compareSelected = false,
    this.onCompareToggle,
    this.onMore,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(12)),
  });

  final String? imageUrl;
  final String badgeLabel;
  final bool badgeSuccess;
  final int photoCount;
  final bool showSaveButton;
  final bool isSaved;
  final VoidCallback? onToggleSave;
  final bool compareSelected;
  final ValueChanged<bool>? onCompareToggle;
  final VoidCallback? onMore;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: borderRadius,
          child: imageUrl != null && imageUrl!.isNotEmpty
              ? MediaDeliveryImage(
                  url: imageUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  placeholder: _placeholder(),
                  errorWidget: _placeholder(),
                )
              : _placeholder(),
        ),
        Positioned(
          top: 10,
          left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.deepBlack.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: badgeSuccess ? AppColors.success : AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  badgeLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
        if (photoCount > 0)
          Positioned(
            bottom: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.deepBlack.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$photoCount Photos',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.white,
                    ),
              ),
            ),
          ),
        if (onMore != null)
          Positioned(
            top: 6,
            right: 6,
            child: IconButton(
              onPressed: onMore,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.deepBlack.withValues(alpha: 0.55),
              ),
              icon: const Icon(
                LucideIcons.moreVertical,
                color: AppColors.white,
                size: 18,
              ),
            ),
          ),
        if (onCompareToggle != null)
          Positioned(
            top: 8,
            left: 8,
            child: Material(
              color: AppColors.navy.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () => onCompareToggle!(!compareSelected),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        compareSelected
                            ? LucideIcons.checkSquare
                            : LucideIcons.square,
                        size: 16,
                        color:
                            compareSelected ? AppColors.gold : AppColors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Compare',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.white,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (showSaveButton && onToggleSave != null)
          Positioned(
            top: 8,
            right: 8,
            child: IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: AppColors.navy.withValues(alpha: 0.85),
              ),
              onPressed: onToggleSave,
              icon: Icon(
                LucideIcons.heart,
                color: isSaved ? AppColors.error : AppColors.white,
                size: 18,
              ),
            ),
          ),
      ],
    );
  }

  Widget _placeholder() => Container(
        color: const Color(0xFF2A3340),
        alignment: Alignment.center,
        child: const Icon(
          LucideIcons.home,
          size: 44,
          color: AppColors.white,
        ),
      );
}
