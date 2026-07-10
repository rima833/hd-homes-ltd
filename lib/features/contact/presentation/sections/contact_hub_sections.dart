import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/contact/data/models/contact_content.dart';
import 'package:hdhomesproject/features/contact/data/providers/contact_cms_provider.dart';
import 'package:hdhomesproject/features/contact/presentation/widgets/contact_forms.dart';
import 'package:hdhomesproject/features/contact/presentation/widgets/contact_widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hub sections 2–9 — options, offices, map, bookings, chat, WhatsApp.
class ContactHubSections extends HookConsumerWidget {
  const ContactHubSections({
    super.key,
    this.optionsKey,
    this.officesKey,
    this.inspectionKey,
    this.consultationKey,
    this.callbackKey,
    this.onOptionSelected,
  });

  final GlobalKey? optionsKey;
  final GlobalKey? officesKey;
  final GlobalKey? inspectionKey;
  final GlobalKey? consultationKey;
  final GlobalKey? callbackKey;
  final ValueChanged<ContactChannelId>? onOptionSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cms = ref.watch(contactHubCmsProvider);
    final selectedOffice = useState(cms.offices.first);

    return Column(
      children: [
        SectionWrapper(
          key: optionsKey,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'CONTACT',
                title: 'Choose how to reach us',
                subtitle: 'Every channel routes into HD Homes CRM automatically.',
              ),
              const SizedBox(height: AppSpacing.xl),
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossCount = context.isMobile ? 1 : (constraints.maxWidth > 1100 ? 4 : 2);
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossCount,
                      mainAxisSpacing: AppSpacing.base,
                      crossAxisSpacing: AppSpacing.base,
                      childAspectRatio: context.isMobile ? 1.1 : 0.88,
                    ),
                    itemCount: cms.contactOptions.length,
                    itemBuilder: (_, i) {
                      final option = cms.contactOptions[i];
                      return ContactOptionCard(
                        option: option,
                        onTap: () => onOptionSelected?.call(option.id),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
        SectionWrapper(
          key: officesKey,
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'OFFICES',
                title: 'Office directory',
                subtitle: 'Head office, regional offices, sales centers, and construction sites.',
              ),
              const SizedBox(height: AppSpacing.xl),
              Wrap(
                spacing: AppSpacing.base,
                runSpacing: AppSpacing.base,
                children: cms.offices
                    .map(
                      (o) => SizedBox(
                        width: context.isMobile ? double.infinity : 360,
                        child: OfficeLocationCard(
                          office: o,
                          onBook: () => onOptionSelected?.call(ContactChannelId.bookAppointment),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'MAP',
                title: 'Interactive map',
                subtitle: 'Google Maps integration — office locations, sites, and showrooms.',
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButton<OfficeLocation>(
                value: selectedOffice.value,
                isExpanded: true,
                items: cms.offices
                    .map((o) => DropdownMenuItem(value: o, child: Text(o.name)))
                    .toList(),
                onChanged: (v) => selectedOffice.value = v ?? selectedOffice.value,
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                height: context.isMobile ? 240 : 320,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: AppRadius.cardBorder,
                  gradient: LinearGradient(
                    colors: [AppColors.charcoal, AppColors.gold.withValues(alpha: 0.12)],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(LucideIcons.map, size: 48, color: AppColors.gold),
                    const SizedBox(height: AppSpacing.sm),
                    Text(selectedOffice.value.name, style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      '${selectedOffice.value.address}, ${selectedOffice.value.city}',
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      'Lat ${selectedOffice.value.lat}, Lng ${selectedOffice.value.lng}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text('Traffic, parking, and navigation — Google Maps in production.'),
                  ],
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          key: inspectionKey,
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'INSPECTION',
                title: 'Book property inspection',
                subtitle: 'Physical or virtual tours with automatic availability checking.',
              ),
              const SizedBox(height: AppSpacing.xl),
              const InspectionBookingForm(),
            ],
          ),
        ),
        SectionWrapper(
          key: consultationKey,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'CONSULTATION',
                title: 'Book a consultation',
                subtitle: 'Live calendar slots — sales, investment, legal, construction, and more.',
              ),
              const SizedBox(height: AppSpacing.xl),
              const ConsultationBookingForm(),
            ],
          ),
        ),
        SectionWrapper(
          key: callbackKey,
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'CALLBACK',
                title: 'Request a callback',
              ),
              const SizedBox(height: AppSpacing.xl),
              const CallbackRequestForm(),
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'LIVE CHAT',
                title: 'Live chat',
                subtitle: 'Real-time messaging with file sharing — AI chatbot in future release.',
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  borderRadius: AppRadius.cardBorder,
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    const Icon(LucideIcons.messagesSquare, size: 40, color: AppColors.gold),
                    const SizedBox(height: AppSpacing.sm),
                    const Text('Chat widget placeholder — connects to CRM conversation timeline.'),
                    const SizedBox(height: AppSpacing.base),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Type a message…',
                        suffixIcon: IconButton(
                          icon: const Icon(LucideIcons.send),
                          onPressed: () {},
                        ),
                      ),
                    ),
                  ],
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
                overline: 'WHATSAPP',
                title: 'WhatsApp integration',
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                children: cms.whatsappDepartments.map((d) {
                  return ActionChip(
                    label: Text(d),
                    onPressed: () => _openWhatsApp(cms.whatsapp, d),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.base),
              Text(
                'Click-to-chat with department routing. Conversations logged in CRM automatically.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openWhatsApp(String number, String department) async {
    final uri = Uri.parse('https://wa.me/${number.replaceAll(RegExp(r'[^0-9]'), '')}?text=${Uri.encodeComponent('Hello HD Homes $department team')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
