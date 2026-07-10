import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/trust/data/providers/trust_cms_provider.dart';
import 'package:hdhomesproject/features/trust/data/providers/trust_document_verification_provider.dart';
import 'package:hdhomesproject/features/trust/presentation/widgets/trust_legal_form.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Closing sections — FAQ, enterprise features, contact legal team.
class TrustClosingSections extends HookConsumerWidget {
  const TrustClosingSections({super.key, this.faqKey});

  final GlobalKey? faqKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cms = ref.watch(trustHubCmsProvider);
    final faqQuery = useState('');
    final verifyController = useTextEditingController();
    final verifyResult = useState<DocumentVerificationResult?>(null);

    final filteredFaqs = cms.faqs
        .where(
          (f) =>
              faqQuery.value.isEmpty ||
              f.question.toLowerCase().contains(faqQuery.value.toLowerCase()) ||
              f.category.toLowerCase().contains(faqQuery.value.toLowerCase()) ||
              f.answer.toLowerCase().contains(faqQuery.value.toLowerCase()),
        )
        .toList();

    return Column(
      children: [
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'TRUST SCORE',
                title: 'HD Homes Trust Score™',
                subtitle: 'Proprietary credibility index across compliance, delivery, and governance.',
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '${cms.trustScore}',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              Text('out of 100', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.xl),
              ...cms.trustScoreBreakdown.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(b.label),
                          Text('${b.score}/${b.maxScore}'),
                        ],
                      ),
                      LinearProgressIndicator(value: b.score / b.maxScore, color: AppColors.gold),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'DASHBOARD',
                title: 'Transparency dashboard',
                subtitle: 'Live corporate metrics updated from the CMS.',
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: cms.dashboardMetrics
                    .map((m) => Chip(label: Text('${m.label}: ${m.value}')))
                    .toList(),
              ),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'VERIFICATION',
                title: 'Document verification portal',
                subtitle: 'Verify certificates, agreements, and property documents.',
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: verifyController,
                decoration: const InputDecoration(
                  labelText: 'Certificate / document reference',
                  hintText: 'e.g. REDAN-2018-042 or RC-XXXXXXX',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              PrimaryButton(
                label: 'Verify document',
                icon: LucideIcons.search,
                onPressed: () {
                  verifyResult.value = verifyDocument(verifyController.text);
                },
              ),
              if (verifyResult.value != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Card(
                  child: ListTile(
                    leading: Icon(
                      verifyResult.value!.isValid ? Icons.verified : Icons.error_outline,
                      color: verifyResult.value!.isValid ? AppColors.success : Colors.orange,
                    ),
                    title: Text(verifyResult.value!.status),
                    subtitle: Text(verifyResult.value!.message),
                  ),
                ),
              ],
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'COMPLIANCE TRACKER',
                title: 'Regulatory compliance tracker',
              ),
              const SizedBox(height: AppSpacing.lg),
              ...cms.complianceDeadlines.map(
                (d) => ListTile(
                  leading: const Icon(LucideIcons.calendarClock, color: AppColors.gold),
                  title: Text(d.item),
                  trailing: Text('${d.dueDate} · ${d.status}'),
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(overline: 'TIMELINE', title: 'Corporate timeline'),
              const SizedBox(height: AppSpacing.lg),
              ...cms.timeline.map(
                (e) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.gold.withValues(alpha: 0.2),
                    child: Text(e.year, style: const TextStyle(fontSize: 11, color: AppColors.gold)),
                  ),
                  title: Text(e.title),
                  subtitle: Text(e.description),
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'DUE DILIGENCE',
                title: 'Digital due diligence room',
                subtitle: 'Secure repository for approved investors — integrates with Investor Portal.',
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Corporate documents, project reports, financial summaries, legal agreements, '
                'compliance certificates, and risk assessments — permission-based access.',
              ),
              const SizedBox(height: AppSpacing.base),
              PrimaryButton(
                label: 'Access Investor Portal',
                variant: ButtonVariant.secondary,
                icon: LucideIcons.lock,
                onPressed: () => context.go(RoutePaths.investor),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => context.go(
                  '${RoutePaths.login}?redirect=${Uri.encodeComponent(RoutePaths.investor)}',
                ),
                child: const Text('Already an investor? Sign in'),
              ),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'DIGITAL AGREEMENTS',
                title: 'Digital agreement center (future-ready)',
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Architecture prepared for electronic review, digital signatures, version control, '
                'audit logs, and approval workflows — integrated with Client and Investor dashboards.',
              ),
            ],
          ),
        ),
        SectionWrapper(
          key: faqKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedSectionTitle(overline: 'FAQ', title: 'Trust FAQ'),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search FAQs…',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => faqQuery.value = v,
              ),
              const SizedBox(height: AppSpacing.lg),
              ...filteredFaqs.map(
                (f) => ExpansionTile(
                  title: Text(f.question),
                  subtitle: Text(f.category, style: Theme.of(context).textTheme.labelSmall),
                  children: [Padding(padding: const EdgeInsets.all(AppSpacing.base), child: Text(f.answer))],
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'LEGAL TEAM',
                title: 'Contact legal & compliance team',
                subtitle: 'Requests route directly into HD Homes CRM.',
              ),
              const SizedBox(height: AppSpacing.xl),
              const TrustLegalInquiryForm(),
            ],
          ),
        ),
      ],
    );
  }
}
