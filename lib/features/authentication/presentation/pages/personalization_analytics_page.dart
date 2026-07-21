import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/personalization_models.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Executive Personalization Analytics — anonymized product insights (Part 13).
class PersonalizationAnalyticsPage extends ConsumerWidget {
  const PersonalizationAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = PreferenceEngine.executiveAnalyticsDemo();
    return Scaffold(
      appBar: AppBar(title: const Text('Personalization Analytics')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Text(
            'Anonymized usage insights (no individual profiling)',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          ...metrics.map(
            (m) => Card(
              elevation: 0,
              child: ListTile(
                leading: const Icon(LucideIcons.barChart3),
                title: Text(m.label),
                trailing: Text(
                  m.value,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
