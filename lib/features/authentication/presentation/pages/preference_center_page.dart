import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/personalization_models.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/personalization_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Preference Center — appearance, dashboard, accessibility, favorites, searches.
class PreferenceCenterPage extends HookConsumerWidget {
  const PreferenceCenterPage({super.key, this.initialTab});

  /// Optional starting tab (0 Overview … 5 Searches). Accessibility = 3.
  final int? initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapAsync = ref.watch(personalizationSnapshotProvider);
    final ui = ref.watch(personalizationControllerProvider);
    final controller = ref.read(personalizationControllerProvider.notifier);
    final tab = useState(initialTab ?? ui.hubTab);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preference Center'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: () => ref.invalidate(personalizationSnapshotProvider),
          ),
        ],
      ),
      body: snapAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Unable to load preferences: $e')),
        data: (snap) {
          if (snap == null) {
            return const Center(child: Text('Sign in to personalize your experience.'));
          }
          return Column(
            children: [
              if (ui.message != null)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(ui.message!, style: const TextStyle(color: AppColors.success)),
                ),
              _WelcomeBanner(greeting: snap.greeting),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: [
                    for (final entry in const [
                      (0, 'Overview'),
                      (1, 'Appearance'),
                      (2, 'Dashboard'),
                      (3, 'Accessibility'),
                      (4, 'Favorites'),
                      (5, 'Searches'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: ChoiceChip(
                          label: Text(entry.$2),
                          selected: tab.value == entry.$1,
                          onSelected: (_) {
                            tab.value = entry.$1;
                            controller.setTab(entry.$1);
                          },
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: tab.value,
                  children: [
                    _OverviewTab(snap: snap),
                    _AppearanceTab(snap: snap),
                    _DashboardTab(snap: snap),
                    _AccessibilityTab(snap: snap),
                    _FavoritesTab(snap: snap),
                    _SearchesTab(snap: snap),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({required this.greeting});

  final WelcomeGreeting greeting;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${greeting.salutation}, ${greeting.displayName}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text('Welcome back.'),
          const SizedBox(height: AppSpacing.sm),
          ...greeting.highlights.map(
            (h) => Text('• $h', style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.snap});

  final PersonalizationSnapshot snap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final s in snap.shortcuts)
              ActionChip(label: Text(s.label), onPressed: () {}),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Recommendations', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        ...snap.recommendations.map(
          (r) => ListTile(
            dense: true,
            leading: const Icon(LucideIcons.sparkles, size: 18),
            title: Text(r),
          ),
        ),
        if (snap.suggestions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Adaptive Dashboard Intelligence',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          ...snap.suggestions.map(
            (s) => Card(
              elevation: 0,
              child: ListTile(
                leading: const Icon(LucideIcons.lightbulb),
                title: Text(s.message),
                subtitle: const Text('Requires your confirmation'),
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Text('Smart Workspaces™', style: Theme.of(context).textTheme.titleMedium),
        ...snap.workspaces.map(
          (w) => ListTile(
            leading: const Icon(LucideIcons.layoutDashboard),
            title: Text(w.name),
            subtitle: Text('${w.visibleWidgets.length} visible widgets'),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Continue where you left off', style: Theme.of(context).textTheme.titleMedium),
        ...snap.recentActivity.map(
          (a) => ListTile(
            dense: true,
            leading: const Icon(LucideIcons.history, size: 18),
            title: Text(a.title),
            subtitle: Text(a.activityType.replaceAll('_', ' ')),
          ),
        ),
      ],
    );
  }
}

class _AppearanceTab extends HookConsumerWidget {
  const _AppearanceTab({required this.snap});

  final PersonalizationSnapshot snap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = useState(snap.appearance.theme);
    final density = useState(snap.appearance.density);
    final motion = useState(snap.appearance.animationLevel);
    final locale = useTextEditingController(text: snap.appPreferences.locale);
    final currency = useTextEditingController(text: snap.appPreferences.currency);
    final timezone = useTextEditingController(text: snap.appPreferences.timezone);
    final ui = ref.watch(personalizationControllerProvider);
    final controller = ref.read(personalizationControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<AppThemeMode>(
          // ignore: deprecated_member_use
          value: theme.value,
          decoration: const InputDecoration(labelText: 'Theme'),
          items: [
            for (final t in AppThemeMode.values)
              DropdownMenuItem(value: t, child: Text(t.slug)),
          ],
          onChanged: (v) {
            if (v != null) theme.value = v;
          },
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<UiDensity>(
          // ignore: deprecated_member_use
          value: density.value,
          decoration: const InputDecoration(labelText: 'Density'),
          items: [
            for (final d in UiDensity.values)
              DropdownMenuItem(value: d, child: Text(d.slug)),
          ],
          onChanged: (v) {
            if (v != null) density.value = v;
          },
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<AnimationLevel>(
          // ignore: deprecated_member_use
          value: motion.value,
          decoration: const InputDecoration(labelText: 'Animation level'),
          items: [
            for (final a in AnimationLevel.values)
              DropdownMenuItem(value: a, child: Text(a.slug)),
          ],
          onChanged: (v) {
            if (v != null) motion.value = v;
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Save appearance',
          expand: true,
          isLoading: ui.isBusy,
          onPressed: ui.isBusy
              ? null
              : () => controller.saveAppearance(
                    AppearancePreferences(
                      theme: theme.value,
                      density: density.value,
                      animationLevel: motion.value,
                    ),
                  ),
        ),
        const Divider(height: AppSpacing.xxl),
        Text('Language & region', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        TextField(controller: locale, decoration: const InputDecoration(labelText: 'Language')),
        const SizedBox(height: AppSpacing.md),
        TextField(controller: currency, decoration: const InputDecoration(labelText: 'Currency')),
        const SizedBox(height: AppSpacing.md),
        TextField(controller: timezone, decoration: const InputDecoration(labelText: 'Timezone')),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Save localization',
          expand: true,
          variant: ButtonVariant.secondary,
          isLoading: ui.isBusy,
          onPressed: ui.isBusy
              ? null
              : () => controller.saveLocalization(
                    snap.appPreferences.copyWith(
                      locale: locale.text.trim(),
                      currency: currency.text.trim(),
                      timezone: timezone.text.trim(),
                      theme: theme.value.slug,
                    ),
                  ),
        ),
      ],
    );
  }
}

class _DashboardTab extends ConsumerWidget {
  const _DashboardTab({required this.snap});

  final PersonalizationSnapshot snap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(personalizationControllerProvider.notifier);
    final ui = ref.watch(personalizationControllerProvider);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                snap.layout.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton(
              onPressed: ui.isBusy ? null : controller.resetLayout,
              child: const Text('Reset to default'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text('Toggle widgets, pin favorites, and rearrange your workspace.'),
        const SizedBox(height: AppSpacing.lg),
        ...snap.layout.widgets.map(
          (w) => SwitchListTile(
            value: w.visible,
            title: Text(w.widgetId.label),
            subtitle: Text(
              [
                if (w.pinned) 'Pinned',
                'Order ${w.order + 1}',
              ].join(' · '),
            ),
            onChanged: ui.isBusy ? null : (_) => controller.toggleWidget(w.widgetId),
          ),
        ),
      ],
    );
  }
}

class _AccessibilityTab extends HookConsumerWidget {
  const _AccessibilityTab({required this.snap});

  final PersonalizationSnapshot snap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = useState(snap.accessibility);
    final ui = ref.watch(personalizationControllerProvider);
    final controller = ref.read(personalizationControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Text('Accessibility Center', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        SwitchListTile(
          title: const Text('High contrast'),
          value: settings.value.highContrast,
          onChanged: (v) =>
              settings.value = settings.value.copyWith(highContrast: v),
        ),
        SwitchListTile(
          title: const Text('Reduced motion'),
          value: settings.value.reducedMotion,
          onChanged: (v) =>
              settings.value = settings.value.copyWith(reducedMotion: v),
        ),
        SwitchListTile(
          title: const Text('Larger fonts'),
          value: settings.value.largerFonts,
          onChanged: (v) =>
              settings.value = settings.value.copyWith(largerFonts: v),
        ),
        SwitchListTile(
          title: const Text('Keyboard navigation'),
          value: settings.value.keyboardNavigation,
          onChanged: (v) =>
              settings.value = settings.value.copyWith(keyboardNavigation: v),
        ),
        SwitchListTile(
          title: const Text('Screen reader optimization'),
          value: settings.value.screenReaderOptimized,
          onChanged: (v) => settings.value =
              settings.value.copyWith(screenReaderOptimized: v),
        ),
        SwitchListTile(
          title: const Text('Focus highlighting'),
          value: settings.value.focusHighlighting,
          onChanged: (v) =>
              settings.value = settings.value.copyWith(focusHighlighting: v),
        ),
        ListTile(
          title: const Text('Font scale'),
          subtitle: Slider(
            value: settings.value.fontScale.clamp(0.8, 1.6),
            min: 0.8,
            max: 1.6,
            divisions: 8,
            label: settings.value.fontScale.toStringAsFixed(1),
            onChanged: (v) =>
                settings.value = settings.value.copyWith(fontScale: v),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Apply accessibility settings',
          expand: true,
          isLoading: ui.isBusy,
          icon: LucideIcons.accessibility,
          onPressed: ui.isBusy
              ? null
              : () => controller.saveAccessibility(settings.value),
        ),
      ],
    );
  }
}

class _FavoritesTab extends ConsumerWidget {
  const _FavoritesTab({required this.snap});

  final PersonalizationSnapshot snap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(personalizationControllerProvider.notifier);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Row(
          children: [
            Text('Favorites', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            TextButton.icon(
              onPressed: controller.addDemoFavorite,
              icon: const Icon(LucideIcons.bookmarkPlus, size: 16),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (snap.favorites.isEmpty)
          const Text('No favorites yet.')
        else
          ...snap.favorites.map(
            (f) => ListTile(
              leading: const Icon(LucideIcons.heart),
              title: Text(f.title),
              subtitle: Text(
                [
                  f.type.slug,
                  if (f.subtitle != null) f.subtitle!,
                ].join(' · '),
              ),
            ),
          ),
      ],
    );
  }
}

class _SearchesTab extends HookConsumerWidget {
  const _SearchesTab({required this.snap});

  final PersonalizationSnapshot snap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = useTextEditingController(text: 'Luxury Apartments');
    final location = useTextEditingController(text: 'Lagos');
    final price = useTextEditingController(text: '₦150M–₦250M');
    final controller = ref.read(personalizationControllerProvider.notifier);
    final cities = useTextEditingController(
      text: snap.interests.cities.join(', '),
    );
    final types = useTextEditingController(
      text: snap.interests.propertyTypes.join(', '),
    );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Text('Saved searches', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        ...snap.savedSearches.map(
          (s) => Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(LucideIcons.search),
              title: Text(s.name),
              subtitle: Text(
                '${s.summary}${s.alertsEnabled ? ' · Alerts on' : ''}',
              ),
            ),
          ),
        ),
        const Divider(height: AppSpacing.xxl),
        Text('Create saved search', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
        const SizedBox(height: AppSpacing.md),
        TextField(controller: location, decoration: const InputDecoration(labelText: 'Location')),
        const SizedBox(height: AppSpacing.md),
        TextField(controller: price, decoration: const InputDecoration(labelText: 'Price range')),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Save search',
          expand: true,
          onPressed: () => controller.createSavedSearch(
            name: name.text.trim(),
            criteria: {
              'location': location.text.trim(),
              'price_range': price.text.trim(),
              'bedrooms': 4,
              'status': 'Ready to Move',
            },
          ),
        ),
        const Divider(height: AppSpacing.xxl),
        Text('Property preferences', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: cities,
          decoration: const InputDecoration(
            labelText: 'Preferred cities (comma-separated)',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: types,
          decoration: const InputDecoration(
            labelText: 'Property types (comma-separated)',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Save interests',
          expand: true,
          variant: ButtonVariant.secondary,
          onPressed: () => controller.saveInterests(
            PropertyInterestProfile(
              cities: cities.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList(),
              propertyTypes: types.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}
