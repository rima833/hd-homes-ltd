import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/contact/data/providers/contact_cms_provider.dart';
import 'package:hdhomesproject/features/website_forms/presentation/widgets/website_careers_form.dart';
import 'package:hdhomesproject/features/website_forms/presentation/widgets/website_partnership_form.dart';
import 'package:hdhomesproject/features/website_forms/presentation/widgets/website_support_form.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Closing band — Support / Careers / Partnerships + contact footer.
/// Volume-2 stubs (departments, emergency, AI, CRM, FAQ, newsletter) removed.
class ContactClosingSections extends HookConsumerWidget {
  const ContactClosingSections({
    super.key,
    this.supportKey,
    this.careersKey,
    this.partnershipsKey,
    this.newsletterKey,
  });

  final GlobalKey? supportKey;
  final GlobalKey? careersKey;
  final GlobalKey? partnershipsKey;

  /// Kept for scroll-target compatibility; newsletter section was retired.
  final GlobalKey? newsletterKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cms = ref.watch(contactHubCmsProvider);

    return Column(
      children: [
        SectionWrapper(
          key: supportKey,
          backgroundColor: const Color(0xFF0B0C0E),
          child: const SupportTicketForm(),
        ),
        SectionWrapper(
          key: careersKey,
          backgroundColor: const Color(0xFF0B0C0E),
          child: const CareersContactForm(),
        ),
        SectionWrapper(
          key: partnershipsKey,
          backgroundColor: const Color(0xFF0B0C0E),
          child: const PartnershipRequestForm(),
        ),
        SectionWrapper(
          key: newsletterKey,
          backgroundColor: const Color(0xFF0B0C0E),
          compact: true,
          child: _ContactFooterBar(
            phone: cms.phone,
            email: cms.email,
            hours: cms.supportHours,
            office: cms.officeLabel,
          ),
        ),
      ],
    );
  }
}

class _ContactFooterBar extends StatelessWidget {
  const _ContactFooterBar({
    required this.phone,
    required this.email,
    required this.hours,
    required this.office,
  });

  final String phone;
  final String email;
  final String hours;
  final String office;

  @override
  Widget build(BuildContext context) {
    final items = [
      (LucideIcons.phone, 'Call Us', phone),
      (LucideIcons.mail, 'Email Us', email),
      (LucideIcons.clock, 'Working Hours', hours),
      (LucideIcons.mapPin, 'Our Office', office),
    ];

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          decoration: BoxDecoration(
            color: const Color(0xFF14161D),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceEvenly,
            runSpacing: 16,
            spacing: 24,
            children: [
              for (final item in items)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.$1, size: 18, color: AppColors.gold),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$2,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                            color: AppColors.gold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.$3,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.shieldCheck,
              size: 14,
              color: AppColors.gold.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'We are committed to protecting your privacy and providing exceptional support.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
