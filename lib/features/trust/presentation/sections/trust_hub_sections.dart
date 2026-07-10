import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/trust/data/providers/trust_cms_provider.dart';
import 'package:hdhomesproject/features/trust/presentation/widgets/trust_enterprise_widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Hub sections 2–14 — pillars through transparency reports.
class TrustHubSections extends HookConsumerWidget {
  const TrustHubSections({
    super.key,
    this.certificationsKey,
    this.legalKey,
    this.faqKey,
  });

  final GlobalKey? certificationsKey;
  final GlobalKey? legalKey;
  final GlobalKey? faqKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cms = ref.watch(trustHubCmsProvider);
    final docQuery = useState('');

    final filteredDocs = docQuery.value.isEmpty
        ? cms.legalDocuments
        : cms.legalDocuments
            .where(
              (d) =>
                  d.title.toLowerCase().contains(docQuery.value.toLowerCase()) ||
                  d.category.toLowerCase().contains(docQuery.value.toLowerCase()),
            )
            .toList();

    return Column(
      children: [
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'WHY TRUST US',
                title: 'Why trust HD Homes',
                subtitle: 'Integrity, transparency, and regulatory compliance at every stage.',
              ),
              const SizedBox(height: AppSpacing.xl),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cross = context.isMobile ? 2 : 4;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cross,
                      mainAxisSpacing: AppSpacing.base,
                      crossAxisSpacing: AppSpacing.base,
                      childAspectRatio: context.isMobile ? 0.95 : 1.05,
                    ),
                    itemCount: cms.pillars.length,
                    itemBuilder: (_, i) => TrustPillarCard(pillar: cms.pillars[i]),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xxl),
              Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.lg,
                alignment: WrapAlignment.center,
                children: cms.statistics
                    .map(
                      (s) => SizedBox(
                        width: context.isMobile ? 140 : 180,
                        child: Column(
                          children: [
                            Text(
                              '${s.value}${s.suffix ?? ''}',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            Text(s.label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedSectionTitle(overline: 'PROFILE', title: 'Company profile'),
              const SizedBox(height: AppSpacing.lg),
              Text(cms.companyOverview, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: AppSpacing.lg),
              Text('Vision', style: Theme.of(context).textTheme.titleSmall),
              Text(cms.vision),
              const SizedBox(height: AppSpacing.base),
              Text('Mission', style: Theme.of(context).textTheme.titleSmall),
              Text(cms.mission),
              const SizedBox(height: AppSpacing.base),
              Wrap(
                spacing: AppSpacing.xs,
                children: cms.coreValues.map((v) => Chip(label: Text(v))).toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
              ...cms.profileDownloads.map(
                (d) => ListTile(
                  leading: const Icon(LucideIcons.download, color: AppColors.gold),
                  title: Text(d.title),
                  trailing: Text('${d.type} · ${d.size}'),
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          key: certificationsKey,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'CERTIFICATIONS',
                title: 'Licenses & certifications',
                subtitle: 'Official registrations with verification links where available.',
              ),
              const SizedBox(height: AppSpacing.xl),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cross = context.isMobile ? 1 : 2;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cross,
                      mainAxisSpacing: AppSpacing.base,
                      crossAxisSpacing: AppSpacing.base,
                      childAspectRatio: context.isMobile ? 1.15 : 1.2,
                    ),
                    itemCount: cms.certifications.length,
                    itemBuilder: (_, i) => TrustCertificateCard(cert: cms.certifications[i]),
                  );
                },
              ),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(overline: 'GOVERNANCE', title: 'Corporate governance'),
              const SizedBox(height: AppSpacing.lg),
              ...cms.boardMembers.map(
                (m) => Card(
                  child: ListTile(
                    title: Text(m.name),
                    subtitle: Text('${m.role}\n${m.bio}'),
                    isThreeLine: true,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const AnimatedSectionTitle(overline: 'POLICIES', title: 'Corporate policies'),
              const SizedBox(height: AppSpacing.base),
              ...cms.policies.map(
                (p) => ListTile(
                  leading: const Icon(LucideIcons.fileText, color: AppColors.gold),
                  title: Text(p.title),
                  subtitle: Text(p.summary),
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'INVESTOR PROTECTION',
                title: 'Investor protection',
                subtitle: 'Safeguards for local and international investors.',
              ),
              const SizedBox(height: AppSpacing.lg),
              ...cms.investorProtection.map(
                (item) => Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    leading: const Icon(LucideIcons.shieldCheck, color: AppColors.gold),
                    title: Text(item.title),
                    subtitle: Text(item.description),
                  ),
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          key: legalKey,
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedSectionTitle(
                overline: 'LEGAL',
                title: 'Legal document center',
                subtitle: 'Versioned policies and agreements with download tracking.',
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search documents…',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => docQuery.value = v,
              ),
              const SizedBox(height: AppSpacing.lg),
              ...filteredDocs.map(
                (d) => ListTile(
                  leading: const Icon(LucideIcons.fileText, color: AppColors.gold),
                  title: Text(d.title),
                  subtitle: Text('${d.category} · ${d.version} · Updated ${d.updatedAt}'),
                  trailing: Text(d.size),
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(overline: 'COMPLIANCE', title: 'Compliance center'),
              const SizedBox(height: AppSpacing.lg),
              ...cms.complianceItems.map(
                (c) => ListTile(
                  leading: Icon(
                    c.status == 'Compliant' ? Icons.check_circle : Icons.warning_amber,
                    color: c.status == 'Compliant' ? AppColors.success : AppColors.gold,
                  ),
                  title: Text(c.title),
                  trailing: Text('${c.status} · ${c.lastReviewed}'),
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(overline: 'PARTNERS', title: 'Banking & strategic partners'),
              const SizedBox(height: AppSpacing.lg),
              ...cms.partners.map(
                (p) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.charcoal,
                      child: Text(p.name.substring(0, 1), style: const TextStyle(color: AppColors.gold)),
                    ),
                    title: Text(p.name),
                    subtitle: Text('${p.category} · ${p.scope}\n${p.description}'),
                    isThreeLine: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(overline: 'AWARDS', title: 'Awards & recognition'),
              const SizedBox(height: AppSpacing.lg),
              ...cms.awards.map(
                (a) => ListTile(
                  leading: const Icon(LucideIcons.award, color: AppColors.gold),
                  title: Text(a.title),
                  subtitle: Text('${a.issuer} · ${a.year}'),
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(overline: 'CSR', title: 'Corporate social responsibility'),
              const SizedBox(height: AppSpacing.lg),
              ...cms.csrInitiatives.map(
                (c) => Card(
                  child: ListTile(
                    title: Text(c.title),
                    subtitle: Text('${c.category} · ${c.impact}\n${c.description}'),
                    isThreeLine: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(overline: 'ESG', title: 'Environmental, social & governance'),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: cms.esgMetrics
                    .map(
                      (m) => Chip(
                        avatar: const Icon(LucideIcons.leaf, size: 16, color: AppColors.gold),
                        label: Text('${m.label}: ${m.value} (${m.category})'),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(overline: 'RISK', title: 'Risk management'),
              const SizedBox(height: AppSpacing.lg),
              ...cms.riskItems.map(
                (r) => ListTile(
                  leading: const Icon(LucideIcons.alertTriangle, color: AppColors.gold),
                  title: Text(r.title),
                  subtitle: Text('Mitigation: ${r.mitigation}'),
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(overline: 'REPORTS', title: 'Transparency reports'),
              const SizedBox(height: AppSpacing.lg),
              ...cms.transparencyReports.map(
                (r) => ListTile(
                  leading: const Icon(LucideIcons.fileBarChart, color: AppColors.gold),
                  title: Text(r.title),
                  subtitle: Text('${r.period} · ${r.type}'),
                  trailing: Text(r.size),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
