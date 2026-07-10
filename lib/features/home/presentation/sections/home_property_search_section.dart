import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

enum PropertySearchIntent { buy, invest, rent, land, commercial }

/// Section 5 — Smart property search beneath hero.
class HomePropertySearchSection extends HookConsumerWidget {
  const HomePropertySearchSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intent = useState(PropertySearchIntent.buy);
    final location = useTextEditingController();
    final budget = useState<String?>(null);
    final propertyType = useState<String?>(null);
    final bedrooms = useState<String?>(null);

    return Transform.translate(
      offset: const Offset(0, -40),
      child: SectionWrapper(
        padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
        animate: false,
        child: Material(
          elevation: 12,
          borderRadius: AppRadius.cardBorder,
          shadowColor: AppColors.deepBlack.withValues(alpha: 0.2),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: AppRadius.cardBorder,
              border: Border.all(color: AppColors.neutral200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Find Your Dream Property',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.base),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: PropertySearchIntent.values.map((item) {
                    final selected = intent.value == item;
                    return ChoiceChip(
                      label: Text(_intentLabel(item)),
                      selected: selected,
                      onSelected: (_) => intent.value = item,
                      selectedColor: AppColors.gold,
                      labelStyle: TextStyle(
                        color: selected ? AppColors.deepBlack : null,
                        fontWeight: selected ? FontWeight.w600 : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.lg),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isStacked = constraints.maxWidth < 720;
                    final fields = [
                      _SearchField(
                        controller: location,
                        label: 'Location',
                        hint: 'City, estate, or area',
                        icon: LucideIcons.mapPin,
                      ),
                      _DropdownField(
                        label: 'Budget',
                        value: budget.value,
                        items: const [
                          'Under ₦30M',
                          '₦30M – ₦60M',
                          '₦60M – ₦100M',
                          '₦100M+',
                        ],
                        onChanged: (v) => budget.value = v,
                      ),
                      _DropdownField(
                        label: 'Property Type',
                        value: propertyType.value,
                        items: const [
                          'Duplex',
                          'Terrace',
                          'Apartment',
                          'Bungalow',
                          'Commercial',
                        ],
                        onChanged: (v) => propertyType.value = v,
                      ),
                      _DropdownField(
                        label: 'Bedrooms',
                        value: bedrooms.value,
                        items: const ['1+', '2+', '3+', '4+', '5+'],
                        onChanged: (v) => bedrooms.value = v,
                      ),
                    ];

                    if (isStacked) {
                      return Column(
                        children: [
                          for (final field in fields) ...[
                            field,
                            const SizedBox(height: AppSpacing.base),
                          ],
                        ],
                      );
                    }

                    return Wrap(
                      spacing: AppSpacing.base,
                      runSpacing: AppSpacing.base,
                      children: fields
                          .map(
                            (f) => SizedBox(
                              width: (constraints.maxWidth - AppSpacing.base) / 2,
                              child: f,
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        label: 'Search Properties',
                        icon: LucideIcons.search,
                        expand: true,
                        onPressed: () => context.go(RoutePaths.properties),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.base),
                    PrimaryButton(
                      label: 'AI Recommend',
                      variant: ButtonVariant.secondary,
                      icon: LucideIcons.sparkles,
                      onPressed: () => context.go(RoutePaths.search),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _intentLabel(PropertySearchIntent intent) => switch (intent) {
        PropertySearchIntent.buy => 'Buy',
        PropertySearchIntent.invest => 'Invest',
        PropertySearchIntent.rent => 'Rent',
        PropertySearchIntent.land => 'Land',
        PropertySearchIntent.commercial => 'Commercial',
      };
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
    );
  }
}
