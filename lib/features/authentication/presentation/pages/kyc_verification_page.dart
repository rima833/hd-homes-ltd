import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/kyc_models.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/kyc_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/account_portal_scaffold.dart';
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

    return AccountPortalScaffold(
      title: 'Identity Verification',
      actions: [
        IconButton(
          tooltip: 'My Profile',
          icon: const Icon(LucideIcons.user),
          onPressed: () => context.go(RoutePaths.profileCenter),
        ),
      ],
      body: hubAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.gold),
        ),
        error: (e, _) => Center(
          child: Text(
            userFacingError(e, fallback: 'Unable to load KYC.'),
            style: const TextStyle(color: AppColors.error),
          ),
        ),
        data: (hub) {
          if (hub == null) {
            return const Center(
              child: Text(
                'Sign in to verify your identity.',
                style: TextStyle(color: AppColors.slate400),
              ),
            );
          }
          final nextTip = hub.progress.requirements
              .where((r) => !r.completed)
              .map((r) => r.label)
              .firstOrNull;

          return ListView(
            children: [
              AccountPortalContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (ui.message != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AccountPortalCard(
                          margin: EdgeInsets.zero,
                          child: Row(
                            children: [
                              const Icon(
                                LucideIcons.checkCircle2,
                                color: AppColors.success,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  ui.message!,
                                  style: const TextStyle(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (ui.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          ui.error!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    AccountPortalMeterCard(
                      title: hub.status.label,
                      valueLabel:
                          'Current: ${hub.currentLevel.label} · Target: ${hub.targetLevel.label}',
                      progress: hub.progress.percent / 100,
                      icon: LucideIcons.badgeCheck,
                      tip: nextTip == null
                          ? 'All checklist items complete — you can submit for review.'
                          : 'Next: $nextTip',
                      chips: [
                        AccountPortalPill(
                          label: 'Level ${hub.currentLevel.rank}',
                          tone: AccountPortalPillTone.gold,
                        ),
                        AccountPortalPill(
                          label: 'Trust ${hub.passport.trustScore}',
                          tone: AccountPortalPillTone.neutral,
                        ),
                        AccountPortalPill(
                          label: hub.passport.complianceStatus,
                          tone: hub.passport.complianceStatus
                                  .toLowerCase()
                                  .contains('complete')
                              ? AccountPortalPillTone.success
                              : AccountPortalPillTone.warning,
                        ),
                      ],
                    ),
                    AccountPortalCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AccountPortalSectionHeader(
                            title: 'Progress checklist',
                            icon: LucideIcons.listChecks,
                            subtitle:
                                '${hub.progress.percent}% · Trust score ${hub.passport.trustScore}/100',
                          ),
                          const SizedBox(height: 8),
                          ...hub.progress.requirements.map(
                            (r) => AccountPortalActionRow(
                              icon: r.completed
                                  ? LucideIcons.checkCircle2
                                  : LucideIcons.circle,
                              iconColor: r.completed
                                  ? AppColors.success
                                  : AppColors.slate500,
                              title: r.label,
                              subtitle: r.hint,
                              dense: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AccountPortalCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const AccountPortalSectionHeader(
                            title: 'Upload documents',
                            icon: LucideIcons.upload,
                            subtitle:
                                'JPEG, PNG, WEBP, PDF · Max 10 MB · Private storage',
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<KycDocumentType>(
                            // ignore: deprecated_member_use
                            value: ui.selectedType,
                            decoration: const InputDecoration(
                              labelText: 'Document type',
                            ),
                            items: KycDocumentType.values
                                .where(
                                  (t) => t.common || role == AppRole.investor,
                                )
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t.label),
                                  ),
                                )
                                .toList(),
                            onChanged: hub.status.canSubmit
                                ? (v) {
                                    if (v != null) controller.selectType(v);
                                  }
                                : null,
                          ),
                          const SizedBox(height: 14),
                          PrimaryButton(
                            label: 'Upload from gallery',
                            expand: true,
                            isLoading: ui.isBusy,
                            icon: LucideIcons.upload,
                            onPressed: !hub.status.canSubmit || ui.isBusy
                                ? null
                                : () => controller.pickAndUpload(hub.userId),
                          ),
                        ],
                      ),
                    ),
                    AccountPortalCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AccountPortalSectionHeader(
                            title: 'Your documents',
                            icon: LucideIcons.folderOpen,
                            subtitle: hub.documents.isEmpty
                                ? 'No documents uploaded yet'
                                : '${hub.documents.length} file(s) on file',
                          ),
                          const SizedBox(height: 8),
                          if (hub.documents.isEmpty)
                            const Text(
                              'Upload a government ID to start verification.',
                              style: TextStyle(color: AppColors.slate400),
                            )
                          else
                            ...hub.documents.map(
                              (d) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.06),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: AppColors.gold
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(11),
                                        ),
                                        child: Icon(
                                          d.mimeType?.contains('pdf') == true
                                              ? LucideIcons.fileText
                                              : LucideIcons.image,
                                          color: AppColors.gold,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              d.documentType.label,
                                              style: const TextStyle(
                                                color: AppColors.white,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${d.status.slug} · ${d.fileName ?? d.storagePath}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: AppColors.slate400,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (d.signedUrl != null)
                                        IconButton(
                                          icon: const Icon(
                                            LucideIcons.eye,
                                            color: AppColors.gold,
                                          ),
                                          onPressed: () => launchUrl(
                                            Uri.parse(d.signedUrl!),
                                          ),
                                        ),
                                      if (hub.status.canSubmit)
                                        IconButton(
                                          icon: const Icon(
                                            LucideIcons.trash2,
                                            color: AppColors.warning,
                                          ),
                                          onPressed: () =>
                                              controller.deleteDocument(
                                            hub.userId,
                                            d.id,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (role == AppRole.investor)
                      AccountPortalCard(
                        child: _InvestorComplianceForm(
                          hub: hub,
                          isBusy: ui.isBusy,
                        ),
                      ),
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
                          : () =>
                              controller.submit(hub.userId, hub.targetLevel),
                    ),
                    if (hub.reviewerNotes != null) ...[
                      const SizedBox(height: 16),
                      AccountPortalCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const AccountPortalSectionHeader(
                              title: 'Reviewer notes',
                              icon: LucideIcons.messageSquare,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              hub.reviewerNotes!,
                              style: const TextStyle(
                                color: AppColors.slate400,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    AccountPortalCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AccountPortalSectionHeader(
                            title: 'Verification timeline',
                            icon: LucideIcons.activity,
                            subtitle: 'History of your KYC journey',
                          ),
                          const SizedBox(height: 8),
                          if (hub.timeline.isEmpty)
                            const Text(
                              'Events will appear as you progress.',
                              style: TextStyle(color: AppColors.slate400),
                            )
                          else
                            ...hub.timeline.map(
                              (e) => AccountPortalActionRow(
                                icon: LucideIcons.activity,
                                title: e.eventType.replaceAll('_', ' '),
                                subtitle: e.createdAt.toLocal().toString(),
                                dense: true,
                              ),
                            ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          context.go(RoutePaths.verificationCenter),
                      icon: const Icon(LucideIcons.mail, size: 16),
                      label: const Text('Email verification & phone on file'),
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

class _InvestorComplianceForm extends HookConsumerWidget {
  const _InvestorComplianceForm({required this.hub, required this.isBusy});

  final KycHubSnapshot hub;
  final bool isBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = hub.compliance;
    final source = useTextEditingController(text: c.investmentSource ?? '');
    final funds = useTextEditingController(text: c.sourceOfFunds ?? '');
    final objectives =
        useTextEditingController(text: c.investmentObjectives ?? '');
    final amount = useTextEditingController(text: c.estimatedAmount ?? '');
    final risk = useState(c.riskProfile ?? 'moderate');
    final declared = useState(c.declarationsAccepted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AccountPortalSectionHeader(
          title: 'Investor compliance',
          icon: LucideIcons.briefcase,
          subtitle: 'Required for investor verification',
        ),
        const SizedBox(height: 16),
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
          decoration:
              const InputDecoration(labelText: 'Investment objectives'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: amount,
          decoration: const InputDecoration(
            labelText: 'Estimated investment amount',
          ),
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
          title: const Text(
            'I confirm the information is accurate and lawful',
            style: TextStyle(color: AppColors.white),
          ),
          value: declared.value,
          activeColor: AppColors.gold,
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
