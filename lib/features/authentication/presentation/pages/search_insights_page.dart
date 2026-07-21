import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/enterprise_search_controller.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Search Insights Dashboard — anonymized search analytics (Part 14).
class SearchInsightsPage extends ConsumerWidget {
  const SearchInsightsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapAsync = ref.watch(enterpriseSearchSnapshotProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Insights'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: () => ref.invalidate(enterpriseSearchSnapshotProvider),
          ),
        ],
      ),
      body: snapAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Unable to load insights: $e')),
        data: (snap) {
          final a = snap.analytics;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              Text(
                'Privacy-aware search adoption across HD Homes',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              _MetricTile(
                icon: LucideIcons.timer,
                label: 'Avg search latency',
                value: '${a.avgLatencyMs.toStringAsFixed(0)} ms',
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Most searched terms',
                  style: Theme.of(context).textTheme.titleMedium),
              ...a.topTerms.map(
                (t) => ListTile(
                  leading: const Icon(LucideIcons.search),
                  title: Text(t.label),
                  trailing: Text('${t.count}'),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Zero-result searches',
                  style: Theme.of(context).textTheme.titleMedium),
              ...a.zeroResultTerms.map(
                (t) => ListTile(
                  dense: true,
                  leading: const Icon(LucideIcons.alertCircle, size: 18),
                  title: Text(t),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Popular commands',
                  style: Theme.of(context).textTheme.titleMedium),
              ...a.popularCommands.map(
                (t) => ListTile(
                  leading: const Icon(LucideIcons.zap),
                  title: Text(t.label),
                  trailing: Text('${t.count}'),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Adoption by department',
                  style: Theme.of(context).textTheme.titleMedium),
              ...a.adoptionByDepartment.map(
                (t) => ListTile(
                  leading: const Icon(LucideIcons.building),
                  title: Text(t.department),
                  trailing: Text('${t.searches} searches'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: Text(value, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}
