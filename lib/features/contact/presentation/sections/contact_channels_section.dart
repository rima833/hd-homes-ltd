import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/app_breakpoints.dart';
import 'package:hdhomesproject/core/validators/phone_validator.dart';
import 'package:hdhomesproject/features/contact/data/models/contact_content.dart';
import 'package:hdhomesproject/features/contact/data/providers/contact_cms_provider.dart';
import 'package:hdhomesproject/features/contact/presentation/widgets/contact_widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

const _panel = Color(0xFF15171D);
const _card = Color(0xFF1C1F28);
const _gold = Color(0xFFD4AF37);
const _goldSoft = Color(0xFFE8C56A);
const _muted = Color(0xFF9CA3AF);
const _border = Color(0x33D4AF37);

const _officeImage =
    '';

/// Premium “Choose how to reach us” experience matching the Contact mockup.
class ContactChannelsSection extends ConsumerStatefulWidget {
  const ContactChannelsSection({
    super.key,
    required this.onChannelSelected,
    this.onRequestCallback,
  });

  final ValueChanged<ContactChannelId> onChannelSelected;
  final VoidCallback? onRequestCallback;

  @override
  ConsumerState<ContactChannelsSection> createState() =>
      _ContactChannelsSectionState();
}

class _ContactChannelsSectionState
    extends ConsumerState<ContactChannelsSection> {
  ContactChannelId _selected = ContactChannelId.phone;

  static const _navOrder = <ContactChannelId>[
    ContactChannelId.phone,
    ContactChannelId.whatsapp,
    ContactChannelId.bookAppointment,
    ContactChannelId.bookInspection,
    ContactChannelId.investorRelations,
    ContactChannelId.liveChat,
    ContactChannelId.visitOffice,
    ContactChannelId.partnerships,
  ];

  static const _navSubtitles = <ContactChannelId, String>{
    ContactChannelId.phone: 'Available now',
    ContactChannelId.whatsapp: 'Reply in < 5 min',
    ContactChannelId.bookAppointment: 'Schedule a meeting',
    ContactChannelId.bookInspection: 'Physical or virtual tour',
    ContactChannelId.investorRelations: 'ROI & partnerships',
    ContactChannelId.liveChat: 'Real-time support',
    ContactChannelId.visitOffice: 'Our sales centers',
    ContactChannelId.partnerships: 'Business development',
  };

  ContactOption _optionFor(List<ContactOption> options, ContactChannelId id) {
    return options.firstWhere(
      (o) => o.id == id,
      orElse: () => options.first,
    );
  }

  IconData _iconFor(ContactChannelId id) => switch (id) {
        ContactChannelId.phone => LucideIcons.phone,
        ContactChannelId.whatsapp => LucideIcons.messageCircle,
        ContactChannelId.email => LucideIcons.mail,
        ContactChannelId.visitOffice => LucideIcons.building2,
        ContactChannelId.bookAppointment => LucideIcons.calendar,
        ContactChannelId.bookInspection => LucideIcons.home,
        ContactChannelId.investorRelations => LucideIcons.landmark,
        ContactChannelId.partnerships => LucideIcons.users,
        ContactChannelId.liveChat => LucideIcons.messagesSquare,
        ContactChannelId.virtualMeeting => LucideIcons.video,
      };

  Future<void> _launchTel(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchWhatsApp(String number) async {
    final uri = PhoneValidator.whatsappUri(number);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      query: Uri(queryParameters: {'subject': 'HD Homes inquiry'}).query,
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _activate(ContactChannelId id, ContactHubCms cms) {
    setState(() => _selected = id);
    widget.onChannelSelected(id);
    switch (id) {
      case ContactChannelId.phone:
        _launchTel(cms.phone);
      case ContactChannelId.whatsapp:
        _launchWhatsApp(cms.whatsapp);
      case ContactChannelId.email:
        _launchEmail(cms.email);
      case ContactChannelId.liveChat:
        // Parent scrolls to LiveChatSupportSection — avoid mounting the
        // floating panel on top of the hub section (duplicate + jank).
        break;
      case ContactChannelId.bookAppointment:
      case ContactChannelId.bookInspection:
      case ContactChannelId.visitOffice:
      case ContactChannelId.investorRelations:
      case ContactChannelId.partnerships:
      case ContactChannelId.virtualMeeting:
        // Stay on /contact — parent scrolls to the matching hub section.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cms = ref.watch(contactHubCmsProvider);
    final option = _optionFor(cms.contactOptions, _selected);
    // Stack until laptop width — tablet (600–1023) cannot fit sidebar + detail + rail.
    final compact = context.screenWidth < AppBreakpoints.tablet;

    final sidebar = _Sidebar(
      selected: _selected,
      order: _navOrder,
      subtitles: _navSubtitles,
      iconFor: _iconFor,
      titleFor: (id) => _optionFor(cms.contactOptions, id).title,
      onSelect: (id) {
        setState(() => _selected = id);
        widget.onChannelSelected(id);
      },
    );

    final detail = _DetailPanel(
      option: option,
      cms: cms,
      icon: _iconFor(option.id),
      onPrimary: () => _activate(option.id, cms),
      onCallback: widget.onRequestCallback,
    );

    final stats = _StatsRow(mobile: compact);
    final quickRail = _QuickRail(
      cms: cms,
      onCall: () => _activate(ContactChannelId.phone, cms),
      onWhatsApp: () => _activate(ContactChannelId.whatsapp, cms),
      onEmail: () => _activate(ContactChannelId.email, cms),
      onLiveChat: () => _activate(ContactChannelId.liveChat, cms),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(mobile: compact),
        const SizedBox(height: 28),
        if (compact)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              sidebar,
              const SizedBox(height: 16),
              detail,
              const SizedBox(height: 20),
              stats,
              const SizedBox(height: 16),
              quickRail,
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 280, child: sidebar),
              const SizedBox(width: 20),
              Expanded(child: detail),
              const SizedBox(width: 16),
              quickRail,
            ],
          ),
        if (!compact) ...[
          const SizedBox(height: 24),
          stats,
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.mobile});

  final bool mobile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(child: Container(height: 1, color: _border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.building2, size: 16, color: _gold),
                  const SizedBox(width: 8),
                  Text(
                    'CONTACT HD HOMES',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.4,
                      color: _goldSoft,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: Container(height: 1, color: _border)),
          ],
        ),
        const SizedBox(height: 20),
        Text.rich(
          TextSpan(
            style: GoogleFonts.playfairDisplay(
              fontSize: mobile ? 28 : 40,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.2,
            ),
            children: const [
              TextSpan(text: 'We’re here '),
              TextSpan(text: 'whenever you need us', style: TextStyle(color: _goldSoft)),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'Multiple ways to connect with our experts and get the answers you need.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: mobile ? 14 : 16,
            color: _muted,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selected,
    required this.order,
    required this.subtitles,
    required this.iconFor,
    required this.titleFor,
    required this.onSelect,
  });

  final ContactChannelId selected;
  final List<ContactChannelId> order;
  final Map<ContactChannelId, String> subtitles;
  final IconData Function(ContactChannelId) iconFor;
  final String Function(ContactChannelId) titleFor;
  final ValueChanged<ContactChannelId> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panel.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < order.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            _SidebarItem(
              icon: iconFor(order[i]),
              title: titleFor(order[i]),
              subtitle: subtitles[order[i]] ?? '',
              selected: selected == order[i],
              onTap: () => onSelect(order[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFF3D3420), Color(0xFF2A2418)],
                  )
                : null,
            border: selected ? Border.all(color: _gold.withValues(alpha: 0.45)) : null,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: selected ? _goldSoft : _muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : const Color(0xFFD1D5DB),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: selected ? _goldSoft.withValues(alpha: 0.85) : _muted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: selected ? _goldSoft : _muted.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.option,
    required this.cms,
    required this.icon,
    required this.onPrimary,
    this.onCallback,
  });

  final ContactOption option;
  final ContactHubCms cms;
  final IconData icon;
  final VoidCallback onPrimary;
  final VoidCallback? onCallback;

  List<String> get _helpTopics => switch (option.id) {
        ContactChannelId.phone => const [
            'Buy Property',
            'Payment Plans',
            'Property Advice',
            'Mortgage Support',
            'After Sales Care',
          ],
        ContactChannelId.whatsapp => const [
            'Quick Quotes',
            'Share Listings',
            'Site Updates',
            'Payment Support',
          ],
        ContactChannelId.bookAppointment => const [
            'Sales Consultation',
            'Legal Review',
            'Finance Planning',
            'Investment Strategy',
          ],
        ContactChannelId.bookInspection => const [
            'Physical Tours',
            'Virtual Walkthroughs',
            'Estate Visits',
            'Same-day Slots',
          ],
        ContactChannelId.investorRelations => const [
            'ROI Analysis',
            'Portfolio Review',
            'Development Updates',
            'Partnership Deals',
          ],
        ContactChannelId.liveChat => const [
            'Instant Answers',
            'Document Sharing',
            'Appointment Help',
            'Support Tickets',
          ],
        ContactChannelId.visitOffice => const [
            'Sales Centers',
            'Showroom Tours',
            'Document Pickup',
            'Walk-in Support',
          ],
        ContactChannelId.partnerships => const [
            'Vendor Onboarding',
            'Joint Ventures',
            'Corporate Deals',
            'Media Collaborations',
          ],
        _ => const ['General Inquiry', 'Property Search', 'Support'],
      };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 720;

        return Container(
          padding: EdgeInsets.all(stacked ? 18 : 28),
          decoration: BoxDecoration(
            color: _card.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (stacked)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DetailHero(icon: icon, option: option, cms: cms),
                    const SizedBox(height: 20),
                    _DetailCopy(option: option),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailHero(icon: icon, option: option, cms: cms),
                    const SizedBox(width: 24),
                    Expanded(child: _DetailCopy(option: option)),
                    const SizedBox(width: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: MediaDeliveryImage(
                        url: _officeImage,
                        width: 200,
                        height: 140,
                        fit: BoxFit.cover,
                        errorWidget: Container(
                          width: 200,
                          height: 140,
                          color: _panel,
                          alignment: Alignment.center,
                          child: const Icon(LucideIcons.image, color: _muted),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, tileConstraints) {
                  final tiles = [
                    _InfoTile(
                      icon: LucideIcons.clock,
                      label: 'Availability',
                      value: option.availability,
                    ),
                    _InfoTile(
                  icon: LucideIcons.zap,
                  label: 'Response Time',
                  value: option.responseTime,
                ),
                _InfoTile(
                  icon: LucideIcons.headphones,
                  label: 'Department',
                  value: option.department,
                ),
              ];
              if (tileConstraints.maxWidth < 640) {
                return Column(
                  children: [
                    for (var i = 0; i < tiles.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      tiles[i],
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  for (var i = 0; i < tiles.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: tiles[i]),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'WE CAN HELP YOU WITH',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
              color: _goldSoft.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _helpTopics
                .map(
                  (t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _panel,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFF2A3140)),
                    ),
                    child: Text(
                      t,
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFD1D5DB)),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final primary = _PrimaryButton(
                icon: ContactIcons.resolve(option.iconName),
                label: option.ctaLabel,
                subtitle: _primarySubtitle(option.id),
                onTap: onPrimary,
              );
              final callback = _SecondaryButton(
                icon: LucideIcons.calendarClock,
                label: 'Request a Callback',
                subtitle: 'We’ll call you at your preferred time',
                onTap: onCallback,
              );
              if (constraints.maxWidth < 560) {
                return Column(
                  children: [
                    primary,
                    if (onCallback != null) ...[
                      const SizedBox(height: 12),
                      callback,
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: primary),
                  if (onCallback != null) ...[
                    const SizedBox(width: 12),
                    Expanded(child: callback),
                  ],
                ],
              );
            },
          ),
            ],
          ),
        );
      },
    );
  }

  String _primarySubtitle(ContactChannelId id) => switch (id) {
        ContactChannelId.phone => 'Speak with our experts instantly',
        ContactChannelId.whatsapp => 'Chat on WhatsApp now',
        ContactChannelId.liveChat => 'Start a live conversation',
        ContactChannelId.bookInspection => 'Schedule your property tour',
        ContactChannelId.bookAppointment => 'Pick a calendar slot',
        ContactChannelId.visitOffice => 'Find our nearest office',
        _ => 'Connect with the right team',
      };
}

class _DetailHero extends StatelessWidget {
  const _DetailHero({
    required this.icon,
    required this.option,
    required this.cms,
  });

  final IconData icon;
  final ContactOption option;
  final ContactHubCms cms;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                _goldSoft.withValues(alpha: 0.35),
                _gold.withValues(alpha: 0.08),
              ],
            ),
            border: Border.all(color: _gold.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: _gold.withValues(alpha: 0.25),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(icon, color: _goldSoft, size: 36),
        ),
        if (context.isMobile) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: MediaDeliveryImage(
              url: _officeImage,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorWidget: Container(
                height: 120,
                color: _panel,
                alignment: Alignment.center,
                child: const Icon(LucideIcons.image, color: _muted),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DetailCopy extends StatelessWidget {
  const _DetailCopy({required this.option});

  final ContactOption option;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          option.department,
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          option.description,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: _muted,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A3140)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _goldSoft),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 10, color: _muted),
                ),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFFE8C56A), Color(0xFFD4AF37), Color(0xFFB8941F)],
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF1A1408)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1408),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF1A1408).withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(LucideIcons.chevronRight, color: Color(0xFF1A1408)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: _panel,
            border: Border.all(color: const Color(0xFF2A3140)),
          ),
          child: Row(
            children: [
              Icon(icon, color: _goldSoft),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(fontSize: 11, color: _muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.mobile});

  final bool mobile;

  static const _items = [
    (LucideIcons.shieldCheck, '98%', 'Client Satisfaction'),
    (LucideIcons.clock, '< 5 mins', 'WhatsApp Response'),
    (LucideIcons.users, '500+', 'Successful Consultations'),
    (LucideIcons.mail, '24/7', 'Email Intake'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final itemWidth = mobile ? maxW : (maxW - 36) / 4;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _items
              .map(
                (item) => SizedBox(
                  width: mobile ? double.infinity : itemWidth,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: _panel.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF2A3140)),
                    ),
                    child: Row(
                      children: [
                        Icon(item.$1, size: 20, color: _goldSoft),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.$2,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              item.$3,
                              style: GoogleFonts.inter(fontSize: 11, color: _muted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _QuickRail extends StatelessWidget {
  const _QuickRail({
    required this.cms,
    required this.onCall,
    required this.onWhatsApp,
    required this.onEmail,
    required this.onLiveChat,
  });

  final ContactHubCms cms;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;
  final VoidCallback onEmail;
  final VoidCallback onLiveChat;

  @override
  Widget build(BuildContext context) {
    final mobile = context.isMobile;

    final items = [
      (LucideIcons.phone, 'Call', const Color(0xFFE8C56A), onCall),
      (LucideIcons.messageCircle, 'WhatsApp', const Color(0xFF25D366), onWhatsApp),
      (LucideIcons.mail, 'Email', const Color(0xFF6B7280), onEmail),
      (LucideIcons.messagesSquare, 'Live Chat', const Color(0xFF3B82F6), onLiveChat),
    ];

    if (mobile) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _panel.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceEvenly,
          spacing: 8,
          runSpacing: 8,
          children: items
              .map(
                (item) => _QuickRailButton(
                  icon: item.$1,
                  label: item.$2,
                  color: item.$3,
                  onTap: item.$4,
                  compact: true,
                ),
              )
              .toList(),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: _panel.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _QuickRailButton(
                  icon: item.$1,
                  label: item.$2,
                  color: item.$3,
                  onTap: item.$4,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _QuickRailButton extends StatelessWidget {
  const _QuickRailButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(compact ? 12 : 16),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 4 : 8,
          vertical: compact ? 4 : 6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 44 : 48,
              height: compact ? 44 : 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: compact ? 20 : 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: compact ? 10 : 11,
                color: _muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
