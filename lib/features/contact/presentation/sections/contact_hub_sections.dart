import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/website/components/viewport_mount.dart';
import 'package:hdhomesproject/features/callback/presentation/widgets/callback_request_form.dart';
import 'package:hdhomesproject/features/consultation/presentation/pages/book_consultation_page.dart';
import 'package:hdhomesproject/features/contact/data/models/contact_content.dart';
import 'package:hdhomesproject/features/contact/presentation/sections/contact_channels_section.dart';
import 'package:hdhomesproject/features/contact/presentation/sections/contact_office_directory_section.dart';
import 'package:hdhomesproject/features/inspection/presentation/pages/book_inspection_page.dart';
import 'package:hdhomesproject/features/live_chat/presentation/widgets/live_chat_support_section.dart';

/// Peak Contact Hub — one instance of each mockup surface, compact titles.
class ContactHubSections extends ConsumerWidget {
  const ContactHubSections({
    super.key,
    this.optionsKey,
    this.officesKey,
    this.inspectionKey,
    this.consultationKey,
    this.callbackKey,
    this.liveChatKey,
    this.initialInspectionPropertyId,
    this.initialInspectionEstateId,
    this.onOptionSelected,
    this.onRequestCallback,
  });

  final GlobalKey? optionsKey;
  final GlobalKey? officesKey;
  final GlobalKey? inspectionKey;
  final GlobalKey? consultationKey;
  final GlobalKey? callbackKey;
  final GlobalKey? liveChatKey;
  final String? initialInspectionPropertyId;
  final String? initialInspectionEstateId;
  final ValueChanged<ContactChannelId>? onOptionSelected;
  final VoidCallback? onRequestCallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        SectionWrapper(
          key: optionsKey,
          backgroundColor: const Color(0xFF0B0C0E),
          child: ContactChannelsSection(
            onChannelSelected: (id) => onOptionSelected?.call(id),
            onRequestCallback: onRequestCallback,
          ),
        ),
        SectionWrapper(
          key: officesKey,
          backgroundColor: const Color(0xFF0B0C0E),
          compact: true,
          child: ViewportMount(
            placeholderHeight: 280,
            child: ContactOfficeDirectorySection(
              onBookAppointment: () =>
                  onOptionSelected?.call(ContactChannelId.bookAppointment),
            ),
          ),
        ),
        SectionWrapper(
          key: inspectionKey,
          backgroundColor: const Color(0xFF0B0C0E),
          compact: true,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'INSPECTION',
                title: 'Book an inspection',
                subtitle:
                    'Pick a property, choose a live slot, and confirm your tour.',
              ),
              const SizedBox(height: AppSpacing.base),
              ViewportMount(
                placeholderHeight: 520,
                child: BookInspectionPage(
                  embedded: true,
                  initialPropertyId: initialInspectionPropertyId,
                  initialEstateId: initialInspectionEstateId,
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          key: consultationKey,
          backgroundColor: const Color(0xFF0B0C0E),
          compact: true,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'CONSULTATION',
                title: 'Book Your Private Consultation',
                subtitle:
                    'Meet with specialists in sales, investment, legal, '
                    'architecture, construction, mortgages, or partnerships.',
              ),
              const SizedBox(height: AppSpacing.base),
              const ViewportMount(
                placeholderHeight: 560,
                child: BookConsultationPage(embedded: true),
              ),
            ],
          ),
        ),
        SectionWrapper(
          key: callbackKey,
          backgroundColor: const Color(0xFF0B0C0E),
          compact: true,
          child: const ViewportMount(
            placeholderHeight: 320,
            child: CallbackRequestForm(),
          ),
        ),
        SectionWrapper(
          key: liveChatKey,
          backgroundColor: const Color(0xFF0B0C0E),
          compact: true,
          child: const ViewportMount(
            placeholderHeight: 480,
            child: LiveChatSupportSection(hubCompact: true),
          ),
        ),
      ],
    );
  }
}
