import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/registration_models.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AccountTypeCards extends StatelessWidget {
  const AccountTypeCards({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final RegistrationAccountType? selected;
  final ValueChanged<RegistrationAccountType> onSelected;

  IconData _icon(RegistrationAccountType type) => switch (type) {
        RegistrationAccountType.client => LucideIcons.home,
        RegistrationAccountType.investor => LucideIcons.trendingUp,
        RegistrationAccountType.propertyOwner => LucideIcons.building2,
        RegistrationAccountType.businessPartner => LucideIcons.users,
        RegistrationAccountType.contractor => LucideIcons.hardHat,
        RegistrationAccountType.vendor => LucideIcons.package,
        RegistrationAccountType.estateManager => LucideIcons.mapPin,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose how you want to use HD Homes',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'You can expand your profile later — start with the role that fits today.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        ...RegistrationAccountType.selectable.map((type) {
          final isSelected = selected == type;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.base),
            child: Material(
              color: isSelected
                  ? AppColors.gold.withValues(alpha: 0.12)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: AppRadius.cardBorder,
              child: InkWell(
                onTap: () => onSelected(type),
                borderRadius: AppRadius.cardBorder,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.cardBorder,
                    border: Border.all(
                      color: isSelected ? AppColors.gold : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_icon(type), color: AppColors.gold),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(type.title, style: Theme.of(context).textTheme.titleMedium),
                          ),
                          if (isSelected)
                            const Icon(LucideIcons.checkCircle2, color: AppColors.gold),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(type.description),
                      const SizedBox(height: AppSpacing.sm),
                      ...type.benefits.map(
                        (b) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.check, size: 14, color: AppColors.gold),
                              const SizedBox(width: 6),
                              Expanded(child: Text(b, style: Theme.of(context).textTheme.bodySmall)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: AppSpacing.sm),
        Text('Coming soon', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: RegistrationAccountType.upcoming
              .map(
                (t) => Chip(
                  avatar: Icon(_icon(t), size: 16),
                  label: Text(t.title),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
