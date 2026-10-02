import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/config/ai_features.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/validators/phone_validator.dart';
import 'package:hdhomesproject/core/website/components/cta_banner.dart';
import 'package:hdhomesproject/core/website/components/newsletter_banner.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/contact/data/providers/contact_cms_provider.dart';
import 'package:hdhomesproject/features/home/data/models/home_cms_content.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

/// Closing CTAs and contact actions.
class HomeClosingSections extends StatelessWidget {
  const HomeClosingSections({
    super.key,
    this.cta = const HomeCtaContent(
      headline: 'Ready to find your next home or investment?',
      subheadline:
          'Book an inspection, request a callback, or speak with our team today.',
      primaryLabel: 'Book Inspection',
      primaryPath: RoutePaths.bookInspection,
      secondaryLabel: 'Contact Sales',
      secondaryPath: RoutePaths.contact,
    ),
    this.showCta = true,
  });

  final HomeCtaContent cta;
  final bool showCta;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
          child: NewsletterBanner(),
        ),
        if (showCta)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.pagePadding,
              vertical: AppSpacing.lg,
            ),
            child: CtaBanner(
              title: cta.headline,
              subtitle: cta.subheadline,
              primaryLabel: cta.primaryLabel,
              primaryPath: cta.primaryPath,
              secondaryLabel: cta.secondaryLabel,
              secondaryPath: cta.secondaryPath,
            ),
          ),
        SectionWrapper(compact: true, child: _ContactActions()),
        if (kAiFeaturesEnabled)
          SectionWrapper(
            compact: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            child: _AiAssistantTeaser(),
          ),
      ],
    );
  }
}

class _ContactActions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final company =
        ref.watch(publishedCompanySettingsProvider).valueOrNull ?? const {};
    final contact = ref.watch(contactHubCmsProvider);
    final whatsappRaw =
        '${company['support_whatsapp'] ?? ''}'.trim().isNotEmpty
            ? '${company['support_whatsapp']}'.trim()
            : contact.whatsapp;
    final whatsappUri = PhoneValidator.whatsappUri(
      whatsappRaw,
      prefillText: 'Hello HD Homes',
    );

    return Wrap(
      spacing: AppSpacing.base,
      runSpacing: AppSpacing.base,
      alignment: WrapAlignment.center,
      children: [
        PrimaryButton(
          label: 'Book Inspection',
          icon: LucideIcons.calendar,
          onPressed: () => context.go(RoutePaths.bookInspection),
        ),
        PrimaryButton(
          label: 'Request Callback',
          variant: ButtonVariant.secondary,
          icon: LucideIcons.phone,
          onPressed: () => context.go(RoutePaths.contact),
        ),
        PrimaryButton(
          label: 'WhatsApp',
          variant: ButtonVariant.ghost,
          icon: LucideIcons.messageCircle,
          onPressed: whatsappUri == null
              ? null
              : () => launchUrl(
                    whatsappUri,
                    mode: LaunchMode.externalApplication,
                  ),
        ),
      ],
    );
  }
}

// ignore: unused_element
class _AiAssistantTeaser extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.sparkles, color: AppColors.gold, size: 32),
          const SizedBox(width: AppSpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Property Assistant',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Text(
                  'HD Homes AI Concierge™ is live — tap the chat icon for personalized recommendations, '
                  'investment guidance, and instant answers.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
