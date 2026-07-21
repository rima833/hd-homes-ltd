import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/kyc_models.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/kyc_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

/// User-facing Identity Verification (KYC) dashboard.
class KycVerificationPage extends HookConsumerWidget {
  const KycVerificationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hubAsync = ref.watch(kycHubProvider);
    final ui = ref.watch(kycControllerProvider);
    final controller = ref.read(kycControllerProvider.notifier);
    final role = ref.watch(identitySessionProvider).primaryRole;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Identity Verification'),
        actions: [
          IconButton(
            tooltip: 'My Profile',
            icon: const Icon(LucideIcons.user),
            onPressed: () => context.go(RoutePaths.profileCenter),
          ),
        ],
      ),
      body: hubAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Unable to load KYC: $e')),
        data: (hub) {
          if (hub == null) {
            return const Center(child: Text('Sign in to verify your identity.'));
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              if (ui.message != null)
                Text(ui.message!, style: const TextStyle(color: AppColors.success)),
              if (ui.error != null)
                Text(ui.error!, style: const TextStyle(color: AppColors.error)),
              _StatusHeader(hub: hub),
              const SizedBox(height: AppSpacing.xl),
              Text('Progress', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              LinearProgressIndicator(
                value: hub.progress.percent / 100,
                minHeight: 10,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                color: AppColors.gold,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text('${hub.progress.percent}% · Trust score ${hub.passport.trustScore}/100'),
              const SizedBox(height: AppSpacing.md),
              ...hub.progress.requirements.map(
                (r) => ListTile(
                  dense: true,
                  leading: Icon(
                    r.completed ? LucideIcons.checkCircle2 : LucideIcons.circle,
                    color: r.completed ? AppColors.success : AppColors.gray,
                    size: 20,
                  ),
                  title: Text(r.label),
                  subtitle: r.hint != null ? Text(r.hint!) : null,
                ),
              ),
              const Divider(height: AppSpacing.xxl),
              Text('Upload documents', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<KycDocumentType>(
                // ignore: deprecated_member_use
                value: ui.selectedType,
                decoration: const InputDecoration(labelText: 'Document type'),
                items: KycDocumentType.values
                    .where((t) => t.common || role == AppRole.investor)
                    .map(
                      (t) => DropdownMenuItem(value: t, child: Text(t.label)),
                    )
                    .toList(),
                onChanged: hub.status.canSubmit
                    ? (v) {
                        if (v != null) controller.selectType(v);
                      }
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: 'Upload from gallery',
                expand: true,
                isLoading: ui.isBusy,
                icon: LucideIcons.upload,
                onPressed: !hub.status.canSubmit || ui.isBusy
                    ? null
                    : () => controller.pickAndUpload(hub.userId),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Accepted: JPEG, PNG, WEBP, PDF · Max 10 MB. Files are stored privately.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Your documents', style: Theme.of(context).textTheme.titleMedium),
              if (hub.documents.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text('No documents uploaded yet.'),
                )
              else
                ...hub.documents.map(
                  (d) => ListTile(
                    leading: Icon(
                      d.mimeType?.contains('pdf') == true
                          ? LucideIcons.fileText
                          : LucideIcons.image,
                    ),
                    title: Text(d.documentType.label),
                    subtitle: Text('${d.status.slug} · ${d.fileName ?? d.storagePath}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (d.signedUrl != null)
                          IconButton(
                            icon: const Icon(LucideIcons.eye),
                            onPressed: () => launchUrl(Uri.parse(d.signedUrl!)),
                          ),
                        if (hub.status.canSubmit)
                          IconButton(
                            icon: const Icon(LucideIcons.trash2),
                            onPressed: () =>
                                controller.deleteDocument(hub.userId, d.id),
                          ),
                      ],
                    ),
                  ),
                ),
              if (role == AppRole.investor) ...[
                const Divider(height: AppSpacing.xxl),
                _InvestorComplianceForm(hub: hub, isBusy: ui.isBusy),
              ],
              const Divider(height: AppSpacing.xxl),
              PrimaryButton(
                label: hub.status == KycStatus.underReview
                    ? 'Under review'
                    : 'Submit for review',
                expand: true,
                isLoading: ui.isBusy,
                onPressed: !hub.status.canSubmit ||
                        ui.isBusy ||
                        !IntelligentVerificationEngine.canSubmitForReview(
                          hub.progress,
                          hub.targetLevel,
                        )
                    ? null
                    : () => controller.submit(hub.userId, hub.targetLevel),
              ),
              if (hub.reviewerNotes != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text('Reviewer notes', style: Theme.of(context).textTheme.titleSmall),
                Text(hub.reviewerNotes!),
              ],
              const Divider(height: AppSpacing.xxl),
              Text('Verification timeline', style: Theme.of(context).textTheme.titleMedium),
              if (hub.timeline.isEmpty)
                const Text('Events will appear as you progress.')
              else
                ...hub.timeline.map(
                  (e) => ListTile(
                    dense: true,
                    leading: const Icon(LucideIcons.activity, size: 18),
                    title: Text(e.eventType.replaceAll('_', ' ')),
                    subtitle: Text(e.createdAt.toLocal().toString()),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              TextButton(
                onPressed: () => context.go(RoutePaths.verificationCenter),
                child: const Text('Email & phone verification'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.hub});

  final KycHubSnapshot hub;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.badgeCheck, color: AppColors.gold, size: 36),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hub.status.label, style: Theme.of(context).textTheme.titleLarge),
                  Text(
                    'Current: ${hub.currentLevel.label} · Target: ${hub.targetLevel.label}',
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: 8,
          children: [
            Chip(label: Text('Level ${hub.currentLevel.rank}')),
            Chip(label: Text('Trust ${hub.passport.trustScore}')),
            Chip(label: Text(hub.passport.complianceStatus)),
          ],
        ),
      ],
    );
  }
}

class _InvestorComplianceForm extends HookConsumerWidget {
  const _InvestorComplianceForm({required this.hub, required this.isBusy});

  final KycHubSnapshot hub;
  final bool isBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = hub.compliance;
    final source = useTextEditingController(text: c.investmentSource ?? '');
    final funds = useTextEditingController(text: c.sourceOfFunds ?? '');
    final objectives = useTextEditingController(text: c.investmentObjectives ?? '');
    final amount = useTextEditingController(text: c.estimatedAmount ?? '');
    final risk = useState(c.riskProfile ?? 'moderate');
    final declared = useState(c.declarationsAccepted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Investor compliance', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: source,
          decoration: const InputDecoration(labelText: 'Investment source'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: funds,
          decoration: const InputDecoration(labelText: 'Source of funds'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: objectives,
          decoration: const InputDecoration(labelText: 'Investment objectives'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: amount,
          decoration: const InputDecoration(labelText: 'Estimated investment amount'),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: risk.value,
          decoration: const InputDecoration(labelText: 'Risk profile'),
          items: const [
            DropdownMenuItem(value: 'conservative', child: Text('Conservative')),
            DropdownMenuItem(value: 'moderate', child: Text('Moderate')),
            DropdownMenuItem(value: 'aggressive', child: Text('Aggressive')),
          ],
          onChanged: (v) {
            if (v != null) risk.value = v;
          },
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('I confirm the information is accurate and lawful'),
          value: declared.value,
          onChanged: (v) => declared.value = v ?? false,
        ),
        PrimaryButton(
          label: 'Save compliance details',
          expand: true,
          isLoading: isBusy,
          onPressed: isBusy
              ? null
              : () => ref.read(kycControllerProvider.notifier).saveCompliance(
                    hub.userId,
                    InvestorComplianceInfo(
                      investmentSource: source.text,
                      sourceOfFunds: funds.text,
                      investmentObjectives: objectives.text,
                      estimatedAmount: amount.text,
                      riskProfile: risk.value,
                      declarationsAccepted: declared.value,
                    ),
                  ),
        ),
      ],
    );
  }
}
