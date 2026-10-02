import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:lucide_icons/lucide_icons.dart';

enum AdminAnalyticsSection { overview, search, personalization }

/// Shared header and section switcher for the three live admin analytics pages.
class AdminAnalyticsHeader extends StatelessWidget {
  const AdminAnalyticsHeader({
    super.key,
    required this.section,
    required this.title,
    required this.subtitle,
    required this.status,
    this.onRefresh,
    this.trailing,
  });

  final AdminAnalyticsSection section;
  final String title;
  final String subtitle;
  final Widget status;
  final VoidCallback? onRefresh;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.darkElevated,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.22)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final copy = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondaryDark,
                        height: 1.35,
                      ),
                    ),
                  ],
                );
                final actions = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    status,
                    ?trailing,
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: onRefresh,
                      icon: const Icon(LucideIcons.refreshCw, size: 18),
                    ),
                  ],
                );
                if (constraints.maxWidth < 760) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [copy, const SizedBox(height: 14), actions],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: copy),
                    const SizedBox(width: 16),
                    actions,
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 14),
        _SectionTabs(current: section),
      ],
    );
  }
}

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({required this.current});

  final AdminAnalyticsSection current;

  void _open(BuildContext context, String path) {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    router.go(path);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Tab(
            label: 'Overview',
            icon: LucideIcons.layoutDashboard,
            selected: current == AdminAnalyticsSection.overview,
            onTap: () => _open(context, RoutePaths.dashboardAnalytics),
          ),
          const SizedBox(width: 8),
          _Tab(
            label: 'Search insights',
            icon: LucideIcons.search,
            selected: current == AdminAnalyticsSection.search,
            onTap: () => _open(context, RoutePaths.searchInsights),
          ),
          const SizedBox(width: 8),
          _Tab(
            label: 'Personalization',
            icon: LucideIcons.slidersHorizontal,
            selected: current == AdminAnalyticsSection.personalization,
            onTap: () => _open(context, RoutePaths.personalizationAnalytics),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? const Color(0xFF1C1915) : AppColors.slate400;
    return Material(
      color: selected ? AppColors.gold : AppColors.darkElevated,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: selected ? null : onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppColors.gold
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: foreground),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminAnalyticsStatusPill extends StatelessWidget {
  const AdminAnalyticsStatusPill({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}
