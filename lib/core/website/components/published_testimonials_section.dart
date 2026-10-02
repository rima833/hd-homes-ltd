import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/testimonials_showcase_section.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/home/data/providers/home_content_provider.dart';
import 'package:hdhomesproject/features/settings/domain/entities/public_website_gates.dart';
import 'package:hdhomesproject/features/settings/presentation/providers/platform_settings_providers.dart';

/// Public testimonials from Admin → Website → Testimonials.
/// Hidden when the public-website switch is off or nothing is published.
class PublishedTestimonialsSection extends ConsumerWidget {
  const PublishedTestimonialsSection({
    super.key,
    this.overline = 'TESTIMONIALS',
    this.title = 'What our clients say',
    this.subtitle =
        'Verified experiences from homeowners, investors, and partners.',
    this.backgroundColor = AppColors.deepBlack,
  });

  final String overline;
  final String title;
  final String subtitle;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(homepageContentRealtimeProvider);
    final settings = ref.watch(publishedPlatformSettingsProvider).valueOrNull;
    if (settings != null && !settings.allowTestimonials) {
      return const SizedBox.shrink();
    }

    final published = ref.watch(publishedTestimonialsProvider);
    if (!published.hasValue) return const SizedBox.shrink();

    return TestimonialsShowcaseSection(
      backgroundColor: backgroundColor,
      overline: overline,
      title: title,
      subtitle: subtitle,
      items: [
        for (final item in published.requireValue) _itemFromCms(item),
      ],
    );
  }
}

TestimonialShowcaseItem _itemFromCms(CmsTestimonial item) {
  return TestimonialShowcaseItem(
    name: item.clientName,
    role: item.clientTitle ?? 'Client',
    quote: item.content,
    rating: (item.rating ?? 5).toDouble(),
    verified: true,
    avatarUrl: item.avatarUrl,
  );
}
