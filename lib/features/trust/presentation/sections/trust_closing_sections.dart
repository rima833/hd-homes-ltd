import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/published_faq_section.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/trust/presentation/widgets/trust_legal_form.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// FAQ, investor due diligence, and legal inquiry — all live CMS / CRM.
class TrustClosingSections extends ConsumerWidget {
  const TrustClosingSections({super.key, this.faqKey});

  final GlobalKey? faqKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'DUE DILIGENCE',
                title: 'Digital due diligence room',
                subtitle:
                    'Approved investors can review project files, reports, and agreements in the Investor Portal.',
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Corporate documents, project reports, financial summaries, legal agreements, '
                'and compliance certificates — permission-based access for verified investors.',
                textAlign: TextAlign.center,
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
        PublishedFaqSection(
          sectionKey: faqKey,
          subtitle: 'The same published questions from Admin → Website → FAQ.',
        ),
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'LEGAL TEAM',
                title: 'Contact legal & compliance team',
                subtitle: 'Requests route into HD Homes CRM for Legal & Compliance.',
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
