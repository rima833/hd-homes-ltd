import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/careers/data/models/careers_hub_content.dart';
import 'package:hdhomesproject/features/careers/data/providers/careers_cms_provider.dart';
import 'package:hdhomesproject/features/contact/data/models/contact_content.dart';
import 'package:hdhomesproject/features/contact/data/providers/lead_routing_provider.dart';
import 'package:hdhomesproject/features/contact/presentation/widgets/contact_widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Closing sections — application form, testimonials, FAQ, CTA.
class CareersClosingSections extends HookConsumerWidget {
  const CareersClosingSections({
    super.key,
    this.applyKey,
    this.faqKey,
    this.preselectedJob,
  });

  final GlobalKey? applyKey;
  final GlobalKey? faqKey;
  final CareerJob? preselectedJob;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cms = ref.watch(careersHubCmsProvider);
    final faqQuery = useState('');
    final submittedLead = useState<SubmittedLead?>(null);
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final positionController = useTextEditingController(text: preselectedJob?.title ?? '');

    useEffect(() {
      if (preselectedJob != null) {
        positionController.text = preselectedJob!.title;
      }
      return null;
    }, [preselectedJob?.id]);

    final filteredFaqs = cms.faqs
        .where(
          (f) =>
              faqQuery.value.isEmpty ||
              f.question.toLowerCase().contains(faqQuery.value.toLowerCase()) ||
              f.answer.toLowerCase().contains(faqQuery.value.toLowerCase()),
        )
        .toList();

    return Column(
      children: [
        SectionWrapper(
          key: applyKey,
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedSectionTitle(
                overline: 'APPLY',
                title: 'Submit your application',
                subtitle: 'Applications route to Careers & HR through our CRM pipeline.',
              ),
              const SizedBox(height: AppSpacing.lg),
              if (submittedLead.value != null)
                LeadConfirmationPanel(lead: submittedLead.value!)
              else
                Form(
                  key: formKey,
                  child: Column(
                    children: [
                      Wrap(
                        spacing: AppSpacing.base,
                        runSpacing: AppSpacing.base,
                        children: [
                          _field('Full name *', width: 220, required: true),
                          _field('Email *', width: 220, required: true, email: true),
                          _field('Phone', width: 220),
                          SizedBox(
                            width: 220,
                            child: TextFormField(
                              controller: positionController,
                              decoration: const InputDecoration(labelText: 'Position applying for'),
                            ),
                          ),
                          _field('Preferred location', width: 220),
                          _field('LinkedIn URL', width: 220),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.base),
                      TextFormField(
                        decoration: const InputDecoration(labelText: 'Cover letter'),
                        maxLines: 3,
                      ),
                      const SizedBox(height: AppSpacing.base),
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Upload CV'),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      PrimaryButton(
                        label: 'Submit Application',
                        expand: true,
                        onPressed: () {
                          if (formKey.currentState?.validate() ?? false) {
                            submittedLead.value = submitLead(
                              ref,
                              type: 'careers',
                              qualification: const LeadQualificationInput(department: DepartmentId.careers),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'TEAM',
                title: 'Voices from the team',
              ),
              const SizedBox(height: AppSpacing.lg),
              ...cms.testimonials.map(
                (t) => Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.base),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('"${t.quote}"', style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: AppSpacing.sm),
                        Text(t.name, style: Theme.of(context).textTheme.titleSmall),
                        Text(t.role, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          key: faqKey,
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'FAQ',
                title: 'Careers FAQ',
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(LucideIcons.search),
                  hintText: 'Search careers questions…',
                ),
                onChanged: (v) => faqQuery.value = v,
              ),
              const SizedBox(height: AppSpacing.lg),
              ...filteredFaqs.map(
                (f) => ExpansionTile(
                  title: Text(f.question),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.base),
                      child: Text(f.answer),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xxl),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.charcoal, AppColors.deepBlack]),
              borderRadius: AppRadius.cardBorder,
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text(
                  'Ready to grow with HD Homes?',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Explore open roles or reach Careers & HR directly.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondaryDark),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                Wrap(
                  spacing: AppSpacing.base,
                  runSpacing: AppSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    PrimaryButton(
                      label: 'Contact Careers',
                      icon: LucideIcons.mail,
                      onPressed: () => context.go(RoutePaths.contact),
                    ),
                    PrimaryButton(
                      label: 'About HD Homes',
                      variant: ButtonVariant.secondary,
                      icon: LucideIcons.info,
                      onPressed: () => context.go(RoutePaths.about),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _field(String label, {required double width, bool required = false, bool email = false}) {
    return SizedBox(
      width: width,
      child: TextFormField(
        decoration: InputDecoration(labelText: label),
        keyboardType: email ? TextInputType.emailAddress : TextInputType.text,
        validator: required
            ? (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (email && !v.contains('@')) return 'Enter a valid email';
                return null;
              }
            : null,
      ),
    );
  }
}
