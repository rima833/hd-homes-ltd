import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/properties/data/providers/marketplace_controller.dart';
import 'package:hdhomesproject/features/properties/presentation/sections/marketplace_comparison_section.dart';
import 'package:hdhomesproject/features/properties/presentation/widgets/marketplace_property_card.dart';
import 'package:hdhomesproject/features/search/data/providers/search_cms_provider.dart';
import 'package:hdhomesproject/features/search/data/providers/search_intelligence_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Closing sections — recommendations, recently viewed, saved searches, alerts, analytics, enterprise.
class SearchClosingSections extends HookConsumerWidget {
  const SearchClosingSections({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cms = ref.watch(searchHubCmsProvider);
    final recommended = ref.watch(aiMatchedPropertiesProvider);
    final recentlyViewed = ref.watch(recentlyViewedPropertiesProvider);
    final saved = ref.watch(savedSearchesProvider);
    final alerts = ref.watch(propertyAlertsProvider);
    final history = ref.watch(searchHistoryProvider);
    final analytics = ref.watch(searchAnalyticsProvider);
    final favorites = ref.watch(marketplaceFavoritesProvider);
    final compare = ref.watch(marketplaceCompareProvider);
    final income = useState('1500000');
    final savings = useState('10000000');
    final commitments = useState('400000');
    final dreamStep = useState(0);
    final affordability = useMemoized(
      () => calculateAffordability(
        monthlyIncome: double.tryParse(income.value.replaceAll(',', '')) ?? 0,
        savings: double.tryParse(savings.value.replaceAll(',', '')) ?? 0,
        commitments: double.tryParse(commitments.value.replaceAll(',', '')) ?? 0,
      ),
      [income.value, savings.value, commitments.value],
    );

    return Column(
      children: [
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'AI MATCHING',
                title: 'Recommended for you',
                subtitle: 'Based on search history, budget, and lifestyle preferences.',
              ),
              const SizedBox(height: AppSpacing.xl),
              Wrap(
                spacing: AppSpacing.base,
                runSpacing: AppSpacing.base,
                children: recommended
                    .take(4)
                    .map(
                      (p) => SizedBox(
                        width: context.isMobile ? double.infinity : 300,
                        child: MarketplacePropertyCard(
                          property: p,
                          isFavorite: favorites.contains(p.id),
                          isCompared: compare.contains(p.id),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(overline: 'RECENT', title: 'Recently viewed'),
              const SizedBox(height: AppSpacing.lg),
              if (recentlyViewed.isEmpty)
                const Text('Browse properties to build your history.')
              else
                Wrap(
                  spacing: AppSpacing.base,
                  children: recentlyViewed
                      .map((p) => SizedBox(width: 280, child: MarketplacePropertyCard(property: p)))
                      .toList(),
                ),
            ],
          ),
        ),
        const MarketplaceComparisonSection(),
        SectionWrapper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedSectionTitle(overline: 'SAVED', title: 'Saved searches'),
              const SizedBox(height: AppSpacing.lg),
              ...saved.map(
                (s) => ListTile(
                  leading: const Icon(LucideIcons.bookmark, color: AppColors.gold),
                  title: Text(s.name),
                  subtitle: Text('Created ${s.createdAt.day}/${s.createdAt.month}/${s.createdAt.year}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () {
                      ref.read(marketplaceFiltersProvider.notifier).state = s.filters;
                    },
                  ),
                ),
              ),
              PrimaryButton(
                label: 'Save current search',
                icon: LucideIcons.plus,
                onPressed: () => saveCurrentSearch(ref, 'My search ${saved.length + 1}'),
              ),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedSectionTitle(overline: 'ALERTS', title: 'Property alerts'),
              const SizedBox(height: AppSpacing.lg),
              ...alerts.map(
                (a) => SwitchListTile(
                  title: Text(a.label),
                  subtitle: Text('${a.trigger} · ${a.channel}'),
                  value: a.active,
                  onChanged: (_) {},
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedSectionTitle(overline: 'ANALYTICS', title: 'Your search analytics'),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.base,
                children: [
                  _stat('Searches', '${analytics.searchesPerformed}'),
                  _stat('Saved', '${analytics.savedSearches}'),
                  _stat('Viewed', '${analytics.propertiesViewed}'),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Favorite locations: ${analytics.favoriteLocations.join(', ')}'),
              Text('Tip: ${analytics.suggestedImprovement}'),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedSectionTitle(overline: 'HISTORY', title: 'Search history'),
              ...history.take(5).map(
                    (h) => ListTile(
                      title: Text(h.query),
                      subtitle: Text('${h.filterSummary} · ${h.resultsCount} results'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          ref.read(searchHistoryProvider.notifier).update(
                                (list) => list.where((e) => e.id != h.id).toList(),
                              );
                        },
                      ),
                    ),
                  ),
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'DREAM HOME',
                title: 'AI Dream Home Finder',
                subtitle: 'Conversational questionnaire → personalized shortlist.',
              ),
              const SizedBox(height: AppSpacing.lg),
              if (dreamStep.value < cms.dreamHomeQuestions.length)
                Text(cms.dreamHomeQuestions[dreamStep.value], style: Theme.of(context).textTheme.titleMedium)
              else
                const Text('Your personalized shortlist is ready — see recommendations above.'),
              const SizedBox(height: AppSpacing.base),
              if (dreamStep.value < cms.dreamHomeQuestions.length)
                Row(
                  children: [
                    Expanded(child: TextField(decoration: const InputDecoration(hintText: 'Your answer…'))),
                    const SizedBox(width: AppSpacing.sm),
                    PrimaryButton(
                      label: 'Next',
                      onPressed: () => dreamStep.value++,
                    ),
                  ],
                ),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedSectionTitle(overline: 'AFFORDABILITY', title: 'Smart affordability analyzer'),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.base,
                children: [
                  SizedBox(width: 180, child: TextField(decoration: const InputDecoration(labelText: 'Monthly income ₦'), onChanged: (v) => income.value = v)),
                  SizedBox(width: 180, child: TextField(decoration: const InputDecoration(labelText: 'Savings ₦'), onChanged: (v) => savings.value = v)),
                  SizedBox(width: 180, child: TextField(decoration: const InputDecoration(labelText: 'Commitments ₦'), onChanged: (v) => commitments.value = v)),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Comfortable budget: ${affordability.comfortableBudget}'),
              Text('Mortgage eligible: ${affordability.mortgageEligible ? 'Yes' : 'Review options'}'),
              Text('Installment: ${affordability.installmentAffordable}'),
              Text('Recommended: ${affordability.recommendedPlan}'),
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'NEIGHBORHOODS',
                title: 'AI Neighborhood Matcher',
              ),
              const SizedBox(height: AppSpacing.lg),
              ...cms.neighborhoods.map(
                (n) => Card(
                  child: ListTile(
                    title: Text('${n.name}, ${n.city}'),
                    subtitle: Text('${n.summary} · ${n.propertyCount} listings'),
                    trailing: Chip(label: Text('${n.lifestyleScore}/100')),
                  ),
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedSectionTitle(overline: 'DISCOVERY', title: 'Personalized discovery feed'),
              const SizedBox(height: AppSpacing.lg),
              ...cms.discoveryFeed.map(
                (item) => ListTile(
                  leading: Icon(_feedIcon(item.type), color: AppColors.gold),
                  title: Text(item.title),
                  subtitle: Text(item.subtitle),
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              Text(
                'Image search & voice search — future-ready placeholders.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        SectionWrapper(
          child: PrimaryButton(
            label: 'Book inspection for shortlisted property',
            icon: LucideIcons.calendarCheck,
            onPressed: () => context.go(RoutePaths.bookInspection),
          ),
        ),
      ],
    );
  }

  Widget _stat(String label, String value) {
    return Chip(label: Text('$label: $value'));
  }

  IconData _feedIcon(String type) => switch (type) {
        'property' => LucideIcons.home,
        'investment' => LucideIcons.trendingUp,
        'article' => LucideIcons.newspaper,
        'event' => LucideIcons.calendar,
        _ => LucideIcons.sparkles,
      };
}
