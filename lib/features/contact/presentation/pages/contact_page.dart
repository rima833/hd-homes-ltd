import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/features/contact/data/models/contact_content.dart';
import 'package:hdhomesproject/features/contact/data/providers/contact_cms_provider.dart';
import 'package:hdhomesproject/features/contact/presentation/sections/contact_closing_sections.dart';
import 'package:hdhomesproject/features/contact/presentation/sections/contact_hero_section.dart';
import 'package:hdhomesproject/features/contact/presentation/sections/contact_hub_sections.dart';

/// Contact scroll targets for deep-linking from other pages.
enum ContactScrollTarget {
  options,
  offices,
  inspection,
  consultation,
  callback,
  support,
  newsletter,
}

/// Contact & Lead Generation Hub — Volume 2 Part 10.
class ContactPage extends ConsumerStatefulWidget {
  const ContactPage({super.key, this.initialTarget});

  final ContactScrollTarget? initialTarget;

  @override
  ConsumerState<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends ConsumerState<ContactPage> {
  final _optionsKey = GlobalKey();
  final _officesKey = GlobalKey();
  final _inspectionKey = GlobalKey();
  final _consultationKey = GlobalKey();
  final _callbackKey = GlobalKey();
  final _supportKey = GlobalKey();
  final _newsletterKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.initialTarget != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToTarget(widget.initialTarget!));
    }
  }

  void _scrollTo(GlobalKey key) {
    final target = key.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _scrollToTarget(ContactScrollTarget target) {
    final key = switch (target) {
      ContactScrollTarget.options => _optionsKey,
      ContactScrollTarget.offices => _officesKey,
      ContactScrollTarget.inspection => _inspectionKey,
      ContactScrollTarget.consultation => _consultationKey,
      ContactScrollTarget.callback => _callbackKey,
      ContactScrollTarget.support => _supportKey,
      ContactScrollTarget.newsletter => _newsletterKey,
    };
    _scrollTo(key);
  }

  void _onOptionSelected(ContactChannelId id) {
    switch (id) {
      case ContactChannelId.visitOffice:
        _scrollTo(_officesKey);
      case ContactChannelId.bookAppointment:
        _scrollTo(_consultationKey);
      case ContactChannelId.bookInspection:
        _scrollTo(_inspectionKey);
      case ContactChannelId.investorRelations:
        _scrollTo(_consultationKey);
      case ContactChannelId.partnerships:
        _scrollTo(_supportKey);
      case ContactChannelId.liveChat:
      case ContactChannelId.whatsapp:
      case ContactChannelId.phone:
      case ContactChannelId.email:
      case ContactChannelId.virtualMeeting:
        _scrollTo(_optionsKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cms = ref.watch(contactHubCmsProvider);

    return Column(
      children: [
        ContactHeroSection(
          headline: cms.heroHeadline,
          subheadline: cms.heroSubheadline,
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
          onOptionSelected: _onOptionSelected,
        ),
        ContactClosingSections(
          supportKey: _supportKey,
          newsletterKey: _newsletterKey,
        ),
      ],
    );
  }
}
