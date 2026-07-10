import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/page_container.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/contact/data/providers/contact_cms_provider.dart';
import 'package:hdhomesproject/features/contact/presentation/widgets/contact_forms.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Closing sections — departments, support, careers, partnerships, emergency, FAQ, CRM pipeline, newsletter.
class ContactClosingSections extends HookConsumerWidget {
  const ContactClosingSections({
    super.key,
    this.supportKey,
    this.newsletterKey,
  });

  final GlobalKey? supportKey;
  final GlobalKey? newsletterKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cms = ref.watch(contactHubCmsProvider);
    final faqQuery = useState('');
    final emailController = useTextEditingController();
    final subscribed = useState(false);

    final filteredFaqs = cms.faqs
        .where(
          (f) =>
              faqQuery.value.isEmpty ||
              f.question.toLowerCase().contains(faqQuery.value.toLowerCase()) ||
              f.category.toLowerCase().contains(faqQuery.value.toLowerCase()),
        )
        .toList();

    return Column(
      children: [
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'DEPARTMENTS',
                title: 'Department directory',
              ),
              const SizedBox(height: AppSpacing.xl),
              ...cms.departments.map(
                (d) => Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    title: Text(d.name),
                    subtitle: Text(
                      '${d.manager} · SLA ${d.sla}\n${d.phone} · ${d.email}',
                    ),
                    isThreeLine: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          key: supportKey,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'SUPPORT',
                title: 'Support center',
                subtitle: 'Complaints, feedback, suggestions, and technical issues.',
              ),
              const SizedBox(height: AppSpacing.xl),
              const SupportTicketForm(),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(overline: 'CAREERS', title: 'Careers contact'),
              const SizedBox(height: AppSpacing.xl),
              const CareersContactForm(),
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(overline: 'PARTNERSHIPS', title: 'Partnership requests'),
              const SizedBox(height: AppSpacing.xl),
              const PartnershipRequestForm(),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'EMERGENCY',
                title: 'Emergency contacts',
              ),
              const SizedBox(height: AppSpacing.lg),
              ...cms.emergencyContacts.map(
                (e) => ListTile(
                  leading: Icon(
                    e.available24x7 ? LucideIcons.siren : LucideIcons.phone,
                    color: AppColors.gold,
                  ),
                  title: Text(e.title),
                  subtitle: Text('${e.number}\n${e.description}'),
                  isThreeLine: true,
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(overline: 'AI ASSISTANT', title: 'AI conversation assistant'),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  borderRadius: AppRadius.cardBorder,
                  color: AppColors.charcoal.withValues(alpha: 0.5),
                ),
                child: const Text(
                  'Future AI assistant will answer property questions, recommend listings, '
                  'explain payment plans, schedule appointments, and escalate to human agents. '
                  'Conversation history syncs with CRM and Client Dashboard.',
                  textAlign: TextAlign.center,
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
                overline: 'CRM PIPELINE',
                title: 'Enterprise lead pipeline',
              ),
              const SizedBox(height: AppSpacing.lg),
              _PipelineFlow(stages: cms.crmPipelineStages),
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(overline: 'FAQ', title: 'Frequently asked questions'),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search FAQs…',
                  prefixIcon: Icon(LucideIcons.search),
                ),
                onChanged: (v) => faqQuery.value = v,
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.xs,
                children: cms.popularFaqCategories
                    .map((c) => ActionChip(label: Text(c), onPressed: () => faqQuery.value = c))
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
              ...filteredFaqs.map(
                (f) => ExpansionTile(
                  title: Text(f.question),
                  subtitle: Text(f.category),
                  children: [Padding(padding: const EdgeInsets.all(AppSpacing.base), child: Text(f.answer))],
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          key: newsletterKey,
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Stay connected', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.sm),
                const Text('Newsletter with topic preferences and consent — personalized in future.'),
                const SizedBox(height: AppSpacing.lg),
                if (!subscribed.value)
                  Wrap(
                    spacing: AppSpacing.base,
                    runSpacing: AppSpacing.base,
                    children: [
                      SizedBox(
                        width: context.isMobile ? double.infinity : 200,
                        child: const TextField(decoration: InputDecoration(labelText: 'Name')),
                      ),
                      SizedBox(
                        width: context.isMobile ? double.infinity : 240,
                        child: TextField(
                          controller: emailController,
                          decoration: const InputDecoration(labelText: 'Email'),
                        ),
                      ),
                      SizedBox(
                        width: context.isMobile ? double.infinity : 200,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: 'Property updates',
                          decoration: const InputDecoration(labelText: 'Interest'),
                          items: const [
                            DropdownMenuItem(value: 'Property updates', child: Text('Property updates')),
                            DropdownMenuItem(value: 'Investment', child: Text('Investment')),
                            DropdownMenuItem(value: 'Construction', child: Text('Construction')),
                          ],
                          onChanged: (_) {},
                        ),
                      ),
                      PrimaryButton(
                        label: 'Subscribe',
                        onPressed: () {
                          if (emailController.text.contains('@')) subscribed.value = true;
                        },
                      ),
                    ],
                  )
                else
                  const Row(
                    children: [
                      Icon(LucideIcons.checkCircle, color: AppColors.success),
                      SizedBox(width: AppSpacing.sm),
                      Text('Subscribed — confirmation email sent.'),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PipelineFlow extends StatelessWidget {
  const _PipelineFlow({required this.stages});

  final List<String> stages;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < stages.length; i++) ...[
            Chip(label: Text(stages[i])),
            if (i < stages.length - 1) const Icon(Icons.arrow_forward, size: 16, color: AppColors.gold),
          ],
        ],
      ),
    );
  }
}
