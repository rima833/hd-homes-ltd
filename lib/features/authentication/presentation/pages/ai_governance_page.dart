import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/ai_workspace_controller.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// AI Governance & Insights Dashboard — admin oversight.
class AiGovernancePage extends ConsumerWidget {
  const AiGovernancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(aiWorkspaceSnapshotProvider).valueOrNull;
    final g = snap?.governance ??
        ref.watch(aiGatewayProvider).governanceDemo();

    return Scaffold(
      appBar: AppBar(title: const Text('AI Governance & Insights')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Text(
            'Responsible AI oversight for HD Homes — usage, quality, and policy events.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              _Metric(
                icon: LucideIcons.messagesSquare,
                label: 'Conversations today',
                value: '${g.conversationsToday}',
              ),
              _Metric(
                icon: LucideIcons.timer,
                label: 'Avg latency',
                value: '${g.avgLatencyMs.toStringAsFixed(0)} ms',
              ),
              _Metric(
                icon: LucideIcons.thumbsUp,
                label: 'Helpful rate',
                value: '${(g.helpfulRate * 100).toStringAsFixed(0)}%',
              ),
              _Metric(
                icon: LucideIcons.coins,
                label: 'Est. tokens',
                value: '${g.estimatedTokens}',
              ),
              _Metric(
                icon: LucideIcons.alertTriangle,
                label: 'Error rate',
                value: '${(g.errorRate * 100).toStringAsFixed(1)}%',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Usage by department',
              style: Theme.of(context).textTheme.titleMedium),
          ...g.usageByDepartment.map(
            (d) => ListTile(
              leading: const Icon(LucideIcons.building2),
              title: Text(d.department),
              trailing: Text('${d.count}'),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Most-used AI features',
              style: Theme.of(context).textTheme.titleMedium),
          ...g.topFeatures.map(
            (f) => ListTile(
              leading: const Icon(LucideIcons.sparkles),
              title: Text(f.feature),
              trailing: Text('${f.count}'),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Security & policy events',
              style: Theme.of(context).textTheme.titleMedium),
          ...g.policyEvents.map(
            (e) => ListTile(
              dense: true,
              leading: const Icon(LucideIcons.shieldAlert, size: 18),
              title: Text(e),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Card(
        elevation: 0,
        child: ListTile(
          leading: Icon(icon),
          title: Text(label, style: Theme.of(context).textTheme.bodySmall),
          subtitle: Text(value, style: Theme.of(context).textTheme.titleMedium),
        ),
      ),
    );
  }
}
