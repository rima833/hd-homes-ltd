import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
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
    final selectedId = useState<String?>(null);
    final needsActionOnly = useState(false);
    final search = useTextEditingController();
    final query = useState('');
    final notes = useTextEditingController();
    final decision = useState(KycReviewDecision.approved);
    final level = useState(KycLevel.identity.rank);

    useEffect(() {
      void onSearch() => query.value = search.text.trim().toLowerCase();
      search.addListener(onSearch);
      return () => search.removeListener(onSearch);
    }, [search]);

    return Scaffold(
      appBar: AppBar(title: const Text('Compliance Workspace')),
      body: queueAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              userFacingError(e, fallback: 'Unable to load review queue.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ),
        data: (queue) {
          final visible = queue.where((item) {
            if (needsActionOnly.value && !item.status.needsStaffAction) {
              return false;
            }
            if (query.value.isEmpty) return true;
            final haystack =
                '${item.displayName ?? ''} ${item.email ?? ''} ${item.status.label}'
                    .toLowerCase();
            return haystack.contains(query.value);
          }).toList();

          return Row(
            children: [
              SizedBox(
                width: 320,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: TextField(
                        controller: search,
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'Search submissions',
                          prefixIcon: Icon(LucideIcons.search, size: 16),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('All')),
                          ButtonSegment(value: true, label: Text('Needs action')),
                        ],
                        selected: {needsActionOnly.value},
                        onSelectionChanged: (value) {
                          needsActionOnly.value = value.first;
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: visible.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(AppSpacing.lg),
                                child: Text(
                                  'No KYC submissions match this view.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: visible.length,
                              itemBuilder: (context, index) {
                                final item = visible[index];
                                return ListTile(
                                  selected: selectedId.value == item.userId,
                                  leading: const Icon(LucideIcons.userCheck),
                                  title: Text(
                                    item.displayName ??
                                        item.email ??
                                        item.userId,
                                  ),
                                  subtitle: Text(
                                    '${item.status.label} · ${item.documentCount} docs',
                                  ),
                                  onTap: () => selectedId.value = item.userId,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: selectedId.value == null
                    ? const Center(
                        child: Text('Select a submission to review the full record.'),
                      )
                    : _CasePane(
                        userId: selectedId.value!,
                        ui: ui,
                        notes: notes,
                        decision: decision,
                        level: level,
                        onReviewed: () => notes.clear(),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CasePane extends ConsumerWidget {
  const _CasePane({
    required this.userId,
    required this.ui,
    required this.notes,
    required this.decision,
    required this.level,
    required this.onReviewed,
  });

  final String userId;
  final KycUiState ui;
  final TextEditingController notes;
  final ValueNotifier<KycReviewDecision> decision;
  final ValueNotifier<int> level;
  final VoidCallback onReviewed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caseAsync = ref.watch(kycReviewCaseProvider(userId));
    return caseAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            userFacingError(e, fallback: 'Unable to load this submission.'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.error),
          ),
        ),
      ),
      data: (record) => ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Text(
            record.identity.displayName ?? record.identity.email ?? 'Applicant',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(record.identity.email ?? 'No email on file'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(label: record.status.label),
              _Chip(label: 'Current ${record.currentLevel.label}'),
              _Chip(label: 'Target ${record.targetLevel.label}'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _Section(
            title: 'Identity',
            child: Column(
              children: [
                _Fact(label: 'Phone', value: _phone(record.identity)),
                _Fact(label: 'Date of birth', value: record.identity.dateOfBirth),
                _Fact(label: 'Gender', value: record.identity.gender),
                _Fact(label: 'Nationality', value: record.identity.nationality),
                _Fact(label: 'Occupation', value: record.identity.occupation),
                _Fact(label: 'Address', value: record.identity.addressLine),
                _Fact(label: 'Account', value: record.identity.accountStatus),
                _Fact(label: 'Submitted', value: _when(record.submittedAt)),
                _Fact(label: 'Last reviewed', value: _when(record.reviewedAt)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Section(
            title: 'Documents',
            child: record.documents.isEmpty
                ? const Text(
                    'No documents have been uploaded for this submission.',
                  )
                : Column(
                    children: [
                      for (final doc in record.documents) _DocumentCard(doc: doc),
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Section(
            title: 'Investor declarations',
            child: _ComplianceBlock(info: record.compliance),
          ),
          if ((record.reviewerNotes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _Section(
              title: 'Previous reviewer note',
              child: Text(record.reviewerNotes!.trim()),
            ),
          ],
          if (record.timeline.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _Section(
              title: 'Activity',
              child: Column(
                children: [
                  for (final event in record.timeline)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(_eventLabel(event.eventType)),
                      subtitle: Text(_when(event.createdAt) ?? ''),
                    ),
                ],
              ),
            ),
          ],
          const Divider(height: AppSpacing.xxl),
          Text('Take action', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Read the identity, documents, and declarations above before you submit a decision.',
          ),
          if (ui.message != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(ui.message!, style: const TextStyle(color: AppColors.success)),
          ],
          if (ui.error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(ui.error!, style: const TextStyle(color: AppColors.error)),
          ],
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<KycReviewDecision>(
            // ignore: deprecated_member_use
            value: decision.value,
            decoration: const InputDecoration(labelText: 'Decision'),
            items: KycReviewDecision.values
                .map(
                  (d) => DropdownMenuItem(value: d, child: Text(d.label)),
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
              decoration: const InputDecoration(labelText: 'Approve to level'),
              items: KycLevel.values
                  .where((l) => l.rank >= 1)
                  .map(
                    (l) => DropdownMenuItem(value: l.rank, child: Text(l.label)),
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
                    final ok = await ref.read(kycControllerProvider.notifier).review(
                          userId: userId,
                          decision: decision.value,
                          notes: notes.text.trim(),
                          approveLevel: level.value,
                        );
                    if (ok) onReviewed();
                  },
          ),
        ],
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.doc});

  final KycDocument doc;

  @override
  Widget build(BuildContext context) {
    final url = doc.signedUrl;
    final isImage = (doc.mimeType ?? '').startsWith('image/') && url != null;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isImage)
            Image.network(
              url,
              height: 220,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Text('Preview unavailable. Open the file instead.'),
              ),
            ),
          ListTile(
            title: Text(doc.documentType.label),
            subtitle: Text(
              [
                doc.fileName,
                doc.status.label,
                if (doc.fileSizeBytes != null) _size(doc.fileSizeBytes!),
                if (doc.createdAt != null) _when(doc.createdAt),
              ].whereType<String>().where((part) => part.isNotEmpty).join(' · '),
            ),
            trailing: url == null
                ? null
                : IconButton(
                    tooltip: 'Open file',
                    icon: const Icon(LucideIcons.externalLink),
                    onPressed: () => launchUrl(Uri.parse(url)),
                  ),
          ),
          if ((doc.reviewNotes ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text('Note: ${doc.reviewNotes!.trim()}'),
            ),
        ],
      ),
    );
  }
}

class _ComplianceBlock extends StatelessWidget {
  const _ComplianceBlock({required this.info});

  final InvestorComplianceInfo info;

  @override
  Widget build(BuildContext context) {
    final empty = (info.investmentSource ?? '').trim().isEmpty &&
        (info.sourceOfFunds ?? '').trim().isEmpty &&
        (info.investmentObjectives ?? '').trim().isEmpty &&
        (info.estimatedAmount ?? '').trim().isEmpty &&
        (info.riskProfile ?? '').trim().isEmpty &&
        !info.declarationsAccepted;
    if (empty) {
      return const Text('No investor declarations have been submitted.');
    }
    return Column(
      children: [
        _Fact(label: 'Investment source', value: info.investmentSource),
        _Fact(label: 'Source of funds', value: info.sourceOfFunds),
        _Fact(label: 'Objectives', value: info.investmentObjectives),
        _Fact(label: 'Estimated amount', value: info.estimatedAmount),
        _Fact(label: 'Risk profile', value: info.riskProfile),
        _Fact(
          label: 'Declarations',
          value: info.declarationsAccepted ? 'Accepted' : 'Not accepted',
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final text = (value ?? '').trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          ),
          Expanded(child: Text(text.isEmpty ? 'Not provided' : text)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label), visualDensity: VisualDensity.compact);
  }
}

String? _phone(KycApplicantIdentity identity) {
  final phone = identity.phone?.trim();
  if (phone == null || phone.isEmpty) return null;
  return identity.phoneVerified ? '$phone · verified' : phone;
}

String? _when(DateTime? value) {
  if (value == null) return null;
  final local = value.toLocal();
  final months = const [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${months[local.month - 1]} ${local.year}, $hour:$minute';
}

String _size(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _eventLabel(String type) {
  if (type.startsWith('review_')) {
    final decision = type.substring('review_'.length).replaceAll('_', ' ');
    return 'Review: $decision';
  }
  return switch (type) {
    'document_uploaded' => 'Document uploaded',
    'document_deleted' => 'Document removed',
    'compliance_updated' => 'Declarations updated',
    'submitted_for_review' => 'Submitted for review',
    'kyc_started' => 'KYC started',
    _ => type.replaceAll('_', ' '),
  };
}
