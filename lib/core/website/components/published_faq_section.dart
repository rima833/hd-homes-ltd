import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/home/data/providers/home_content_provider.dart';
import 'package:hdhomesproject/features/settings/domain/entities/public_website_gates.dart';
import 'package:hdhomesproject/features/settings/presentation/providers/platform_settings_providers.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// The homepage FAQ card. Questions come from Admin → Website → FAQ.
class HomeFaqCard extends StatelessWidget {
  const HomeFaqCard({
    super.key,
    required this.items,
  });

  final List<({String question, String answer})> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.isMobile ? AppSpacing.lg : AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FAQ',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.gold,
                  letterSpacing: 2.2,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Frequently asked questions',
            style: GoogleFonts.playfairDisplay(
              fontSize: context.isMobile ? 26 : 32,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          for (final item in items)
            _FaqTile(question: item.question, answer: item.answer),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: () => context.go(RoutePaths.contact),
            style: TextButton.styleFrom(foregroundColor: AppColors.gold),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'View All FAQs',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(width: 6),
                Icon(LucideIcons.arrowRight, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Same homepage FAQ card, loaded from the published FAQ desk.
class PublishedFaqSection extends ConsumerWidget {
  const PublishedFaqSection({super.key, this.sectionKey});

  final Key? sectionKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(homepageContentRealtimeProvider);
    final settings = ref.watch(publishedPlatformSettingsProvider).valueOrNull;
    if (settings != null && !settings.allowFaq) {
      return const SizedBox.shrink();
    }

    final published = ref.watch(publishedFaqsProvider);
    if (!published.hasValue || published.requireValue.isEmpty) {
      return const SizedBox.shrink();
    }

    return SectionWrapper(
      key: sectionKey,
      backgroundColor: AppColors.deepBlack,
      child: HomeFaqCard(
        items: [
          for (final faq in published.requireValue)
            (question: faq.question, answer: faq.answer),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        collapsedIconColor: AppColors.gold,
        iconColor: AppColors.gold,
        title: Text(
          question,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                answer,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondaryDark,
                      height: 1.5,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
