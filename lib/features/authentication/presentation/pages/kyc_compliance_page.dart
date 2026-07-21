import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/kyc_models.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/kyc_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

/// Smart Compliance Workspace — admin / compliance officer review queue.
class KycCompliancePage extends HookConsumerWidget {
  const KycCompliancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(kycReviewQueueProvider);
    final ui = ref.watch(kycControllerProvider);
    final selected = useState<KycReviewQueueItem?>(null);
    final notes = useTextEditingController();
    final decision = useState(KycReviewDecision.approved);
    final level = useState(KycLevel.identity.rank);
    final docs = useState<List<KycDocument>>(const []);

    useEffect(() {
      final item = selected.value;
      if (item == null) {
        docs.value = const [];
        return null;
      }
      Future.microtask(() async {
        final list =
            await ref.read(kycServiceProvider).listDocuments(item.userId);
        docs.value = list;
      });
      return null;
    }, [selected.value?.userId]);

    return Scaffold(
      appBar: AppBar(title: const Text('Compliance Workspace')),
      body: queueAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Unable to load queue: $e')),
        data: (queue) {
          if (queue.isEmpty && selected.value == null) {
            return const Center(
              child: Text('No submissions awaiting review.'),
            );
          }
          return Row(
            children: [
              SizedBox(
                width: 320,
                child: ListView(
                  children: [
                    const ListTile(title: Text('Review queue')),
                    if (queue.isEmpty)
                      const ListTile(title: Text('Queue empty'))
                    else
                      ...queue.map(
                        (item) => ListTile(
                          selected: selected.value?.userId == item.userId,
                          leading: const Icon(LucideIcons.userCheck),
                          title: Text(item.displayName ?? item.email ?? item.userId),
                          subtitle: Text(
                            '${item.status.label} · ${item.documentCount} docs · ${item.level.label}',
                          ),
                          onTap: () => selected.value = item,
                        ),
                      ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: selected.value == null
                    ? const Center(child: Text('Select a submission to review.'))
                    : ListView(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        children: [
                          Text(
                            selected.value!.displayName ??
                                selected.value!.email ??
                                'Applicant',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Text(selected.value!.email ?? ''),
                          Text(
                            'Submitted: ${selected.value!.submittedAt?.toLocal() ?? '—'}',
                          ),
                          if (ui.message != null)
                            Text(ui.message!, style: const TextStyle(color: AppColors.success)),
                          if (ui.error != null)
                            Text(ui.error!, style: const TextStyle(color: AppColors.error)),
                          const Divider(height: AppSpacing.xxl),
                          Text('Documents', style: Theme.of(context).textTheme.titleMedium),
                          ...docs.value.map(
                            (d) => ListTile(
                              title: Text(d.documentType.label),
                              subtitle: Text(d.status.slug),
                              trailing: d.signedUrl == null
                                  ? null
                                  : IconButton(
                                      icon: const Icon(LucideIcons.externalLink),
                                      onPressed: () =>
                                          launchUrl(Uri.parse(d.signedUrl!)),
                                    ),
                            ),
                          ),
                          const Divider(height: AppSpacing.xxl),
                          DropdownButtonFormField<KycReviewDecision>(
                            // ignore: deprecated_member_use
                            value: decision.value,
                            decoration: const InputDecoration(labelText: 'Decision'),
                            items: KycReviewDecision.values
                                .map(
                                  (d) => DropdownMenuItem(
                                    value: d,
                                    child: Text(d.label),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) decision.value = v;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (decision.value == KycReviewDecision.approved)
                            DropdownButtonFormField<int>(
                              // ignore: deprecated_member_use
                              value: level.value,
                              decoration:
                                  const InputDecoration(labelText: 'Approve to level'),
                              items: KycLevel.values
                                  .where((l) => l.rank >= 1)
                                  .map(
                                    (l) => DropdownMenuItem(
                                      value: l.rank,
                                      child: Text(l.label),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) level.value = v;
                              },
                            ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: notes,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Reviewer notes (required)',
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          PrimaryButton(
                            label: 'Submit decision',
                            expand: true,
                            isLoading: ui.isBusy,
                            onPressed: ui.isBusy
                                ? null
                                : () async {
                                    if (notes.text.trim().isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Reviewer notes are required.'),
                                        ),
                                      );
                                      return;
                                    }
                                    final ok = await ref
                                        .read(kycControllerProvider.notifier)
                                        .review(
                                          userId: selected.value!.userId,
                                          decision: decision.value,
                                          notes: notes.text.trim(),
                                          approveLevel: level.value,
                                        );
                                    if (ok) {
                                      selected.value = null;
                                      notes.clear();
                                    }
                                  },
                          ),
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
