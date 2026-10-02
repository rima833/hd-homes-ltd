import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/website/components/viewport_mount.dart';
import 'package:hdhomesproject/features/contact/data/models/contact_content.dart';
import 'package:hdhomesproject/features/contact/data/providers/contact_cms_provider.dart';
import 'package:hdhomesproject/features/contact/presentation/sections/contact_closing_sections.dart';
import 'package:hdhomesproject/features/contact/presentation/sections/contact_hero_section.dart';
import 'package:hdhomesproject/features/contact/presentation/sections/contact_hub_sections.dart';

/// Contact & Lead Generation Hub — Volume 2 Part 10.
class ContactPage extends ConsumerStatefulWidget {
  const ContactPage({
    super.key,
    this.initialTarget,
    this.fromBookInspection = false,
    this.initialInspectionPropertyId,
    this.initialInspectionEstateId,
  });

  final ContactScrollTarget? initialTarget;

  /// Nav CTA opens this hub with every section visible from the top.
  final bool fromBookInspection;
  final String? initialInspectionPropertyId;
  final String? initialInspectionEstateId;

  @override
  ConsumerState<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends ConsumerState<ContactPage> {
  final _optionsKey = GlobalKey();
  final _officesKey = GlobalKey();
  final _inspectionKey = GlobalKey();
  final _consultationKey = GlobalKey();
  final _callbackKey = GlobalKey();
  final _liveChatKey = GlobalKey();
  final _supportKey = GlobalKey();
  final _careersKey = GlobalKey();
  final _partnershipsKey = GlobalKey();
  final _newsletterKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final target = widget.initialTarget;
    if (target != null && !widget.fromBookInspection) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToTarget(target);
      });
    }
  }

  void _scrollTo(GlobalKey key, {int durationMs = 500}) {
    // Defer past the current gesture/frame so channel taps don't jank while
    // ViewportMount sections are mounting.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = key.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: Duration(milliseconds: durationMs),
        curve: Curves.easeInOutCubic,
        alignment: 0.08,
      );
    });
  }

  void _scrollToTarget(ContactScrollTarget target) {
    final key = switch (target) {
      ContactScrollTarget.options => _optionsKey,
      ContactScrollTarget.offices => _officesKey,
      ContactScrollTarget.inspection => _inspectionKey,
      ContactScrollTarget.consultation => _consultationKey,
      ContactScrollTarget.callback => _callbackKey,
      ContactScrollTarget.liveChat => _liveChatKey,
      ContactScrollTarget.whatsapp => _optionsKey,
      ContactScrollTarget.support => _supportKey,
      ContactScrollTarget.careers => _careersKey,
      ContactScrollTarget.partnerships => _partnershipsKey,
      ContactScrollTarget.newsletter => _newsletterKey,
    };
    _scrollTo(key);
  }

  void _onOptionSelected(ContactChannelId id) {
    switch (id) {
      case ContactChannelId.visitOffice:
        _scrollTo(_officesKey);
      case ContactChannelId.bookAppointment:
      case ContactChannelId.investorRelations:
      case ContactChannelId.virtualMeeting:
        _scrollTo(_consultationKey);
      case ContactChannelId.bookInspection:
        _scrollTo(_inspectionKey);
      case ContactChannelId.partnerships:
        _scrollTo(_partnershipsKey);
      case ContactChannelId.liveChat:
        _scrollTo(_liveChatKey);
      case ContactChannelId.whatsapp:
      case ContactChannelId.phone:
      case ContactChannelId.email:
        _scrollTo(_optionsKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cms = ref.watch(contactHubCmsProvider);

    // Always render the full hub. Form submit gates live inside individual forms.
    return ColoredBox(
      color: const Color(0xFF0B0C0E),
      child: Column(
        children: [
          ContactHeroSection(
            headline: cms.heroHeadline,
            subheadline: cms.heroSubheadline,
            backgroundImageUrl: cms.backgroundImageUrl,
            backgroundVideoUrl: cms.backgroundVideoUrl,
            showHubIntro: widget.fromBookInspection,
            onContactSales: () => _scrollTo(_optionsKey),
            onBookInspection: () => _scrollTo(_inspectionKey),
            onTalkAdvisor: () => _scrollTo(_consultationKey),
          ),
          ContactHubSections(
            optionsKey: _optionsKey,
            officesKey: _officesKey,
            inspectionKey: _inspectionKey,
            consultationKey: _consultationKey,
            callbackKey: _callbackKey,
            liveChatKey: _liveChatKey,
            initialInspectionPropertyId: widget.initialInspectionPropertyId,
            initialInspectionEstateId: widget.initialInspectionEstateId,
            onOptionSelected: _onOptionSelected,
            onRequestCallback: () => _scrollTo(_callbackKey),
          ),
          ViewportMount(
            placeholderHeight: 720,
            child: ContactClosingSections(
              supportKey: _supportKey,
              careersKey: _careersKey,
              partnershipsKey: _partnershipsKey,
              newsletterKey: _newsletterKey,
            ),
          ),
        ],
      ),
    );
  }
}
