import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/home/data/providers/home_content_provider.dart';
import 'package:hdhomesproject/features/settings/domain/entities/public_website_gates.dart';
import 'package:hdhomesproject/features/settings/presentation/providers/platform_settings_providers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Public FAQs from Admin → Website → FAQ.
/// Hidden when the public-website switch is off or nothing is published.
class PublishedFaqSection extends HookConsumerWidget {
  const PublishedFaqSection({
    super.key,
    this.sectionKey,
    this.title = 'Frequently asked questions',
    this.subtitle = 'Answers published from the website FAQ desk.',
    this.backgroundColor,
  });

  final Key? sectionKey;
  final String title;
  final String subtitle;
  final Color? backgroundColor;

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

    final query = useState('');
    final needle = query.value.trim().toLowerCase();
    final faqs = published.requireValue.where((faq) {
      if (needle.isEmpty) return true;
      final category = (faq.category ?? '').toLowerCase();
      return faq.question.toLowerCase().contains(needle) ||
          faq.answer.toLowerCase().contains(needle) ||
          category.contains(needle);
    }).toList();

    return SectionWrapper(
      key: sectionKey,
      backgroundColor:
          backgroundColor ?? Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSectionTitle(
            overline: 'FAQ',
            title: title,
            subtitle: subtitle,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(LucideIcons.search),
              hintText: 'Search FAQs...',
            ),
            onChanged: (value) => query.value = value,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (faqs.isEmpty)
            Text(
              'No questions match that search.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            for (final faq in faqs)
              ExpansionTile(
                title: Text(faq.question),
                subtitle: (faq.category ?? '').trim().isEmpty
                    ? null
                    : Text(faq.category!),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.base,
                      0,
                      AppSpacing.base,
                      AppSpacing.base,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(faq.answer),
                    ),
                  ),
                ],
              ),
        ],
      ),
    );
  }
}
