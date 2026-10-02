import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/personalization_models.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/personalization_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/account_portal_scaffold.dart';
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

    return AccountPortalScaffold(
      title: 'Preference Center',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(LucideIcons.refreshCw),
          onPressed: () => ref.invalidate(personalizationSnapshotProvider),
        ),
      ],
      body: snapAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.gold),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              userFacingError(e, fallback: 'Unable to load preferences.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ),
        data: (snap) {
          if (snap == null) {
            return const Center(
              child: Text(
                'Sign in to personalize your experience.',
                style: TextStyle(color: AppColors.slate400),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (ui.message != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    0,
                  ),
                  child: Text(
                    ui.message!,
                    style: const TextStyle(color: AppColors.success),
                  ),
                ),
              _WelcomeBanner(greeting: snap.greeting),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    for (final entry in [
                      (0, 'Overview', LucideIcons.layoutDashboard),
                      (1, 'Appearance', LucideIcons.palette),
                      (2, 'Dashboard', LucideIcons.layout),
                      (3, 'Accessibility', LucideIcons.accessibility),
                      (4, 'Favorites', LucideIcons.heart),
                      (5, 'Searches', LucideIcons.search),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: ChoiceChip(
                          avatar: Icon(
                            entry.$3,
                            size: 16,
                            color: tab.value == entry.$1
                                ? AppColors.gold
                                : AppColors.slate400,
                          ),
                          label: Text(entry.$2),
                          selected: tab.value == entry.$1,
                          onSelected: (_) {
                            tab.value = entry.$1;
                            controller.setTab(entry.$1);
                          },
                          selectedColor: AppColors.gold.withValues(alpha: 0.22),
                          backgroundColor: AppColors.darkSurface,
                          labelStyle: TextStyle(
                            color: tab.value == entry.$1
                                ? AppColors.gold
                                : AppColors.slate400,
                            fontWeight: FontWeight.w600,
                          ),
                          side: BorderSide(
                            color: tab.value == entry.$1
                                ? AppColors.gold
                                : AppColors.slate700,
                          ),
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
    return AccountPortalCard(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      accentEdge: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${greeting.salutation}, ${greeting.displayName}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Welcome back. Tune how HD Homes looks and works for you.',
            style: TextStyle(color: AppColors.slate400),
          ),
          if (greeting.highlights.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            ...greeting.highlights.map(
              (h) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      LucideIcons.sparkles,
                      size: 14,
                      color: AppColors.gold,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        h,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.slate400,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.snap});

  final PersonalizationSnapshot snap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(personalizationControllerProvider.notifier);
    final isBusy = ref.watch(
      personalizationControllerProvider.select((state) => state.isBusy),
    );
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final s in snap.shortcuts)
              ActionChip(
                label: Text(s.label),
                onPressed: () {},
                backgroundColor: AppColors.darkSurface,
                side: BorderSide(color: AppColors.gold.withValues(alpha: 0.35)),
                labelStyle: const TextStyle(color: AppColors.gold),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Recommendations',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...snap.recommendations.map(
          (r) => AccountPortalCard(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const Icon(LucideIcons.sparkles, size: 18, color: AppColors.gold),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    r,
                    style: const TextStyle(color: AppColors.slate400),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (snap.suggestions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Adaptive Dashboard Intelligence',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...snap.suggestions.map(
            (s) => AccountPortalCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(LucideIcons.lightbulb, color: AppColors.gold),
                title: Text(s.message, style: const TextStyle(color: AppColors.white)),
                subtitle: const Text(
                  'Requires your confirmation',
                  style: TextStyle(color: AppColors.slate400),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Smart Workspaces™',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...snap.workspaces.map(
          (w) => AccountPortalCard(
            margin: const EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(LucideIcons.layoutDashboard, color: AppColors.gold),
              title: Text(w.name, style: const TextStyle(color: AppColors.white)),
              subtitle: Text(
                '${w.visibleWidgets.length} visible widgets · Select workspace',
                style: const TextStyle(color: AppColors.slate400),
              ),
              trailing: w.id == snap.layout.id
                  ? const Icon(LucideIcons.check, color: AppColors.success)
                  : const Icon(LucideIcons.chevronRight, color: AppColors.slate400),
              onTap: isBusy || w.id == snap.layout.id
                  ? null
                  : () => controller.switchWorkspace(w),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Continue where you left off',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
        ...snap.recentActivity.map(
          (a) => ListTile(
            dense: true,
            leading: const Icon(LucideIcons.history, size: 18, color: AppColors.gold),
            title: Text(a.title, style: const TextStyle(color: AppColors.white)),
            subtitle: Text(
              a.activityType.replaceAll('_', ' '),
              style: const TextStyle(color: AppColors.slate400),
            ),
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
    final currency = useTextEditingController(
      text: snap.appPreferences.currency,
    );
    final timezone = useTextEditingController(
      text: snap.appPreferences.timezone,
    );
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
        Text(
          'Language & region',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: locale,
          decoration: const InputDecoration(labelText: 'Language'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: currency,
          decoration: const InputDecoration(labelText: 'Currency'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: timezone,
          decoration: const InputDecoration(labelText: 'Timezone'),
        ),
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
        const Text(
          'Toggle widgets, pin favorites, and rearrange your workspace.',
        ),
        const SizedBox(height: AppSpacing.lg),
        ...snap.layout.widgets.map(
          (w) => SwitchListTile(
            value: w.visible,
            title: Text(w.widgetId.label),
            subtitle: Text(
              [if (w.pinned) 'Pinned', 'Order ${w.order + 1}'].join(' · '),
            ),
            onChanged: ui.isBusy
                ? null
                : (_) => controller.toggleWidget(w.widgetId),
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
        Text(
          'Accessibility Center',
          style: Theme.of(context).textTheme.titleLarge,
        ),
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
          onChanged: (v) => settings.value = settings.value.copyWith(
            screenReaderOptimized: v,
          ),
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
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Row(
          children: [
            Text('Favorites', style: Theme.of(context).textTheme.titleLarge),
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
                [f.type.slug, if (f.subtitle != null) f.subtitle!].join(' · '),
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
        Text(
          'Create saved search',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: location,
          decoration: const InputDecoration(labelText: 'Location'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: price,
          decoration: const InputDecoration(labelText: 'Price range'),
        ),
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
        Text(
          'Property preferences',
          style: Theme.of(context).textTheme.titleMedium,
        ),
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
