import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/cta_banner.dart';
import 'package:hdhomesproject/core/website/components/newsletter_banner.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/home/data/models/home_cms_content.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

/// Sections 25–27, enterprise feeds, and closing CTAs.
class HomeClosingSections extends StatelessWidget {
  const HomeClosingSections({
    super.key,
    required this.downloads,
    required this.liveActivities,
    required this.executive,
    required this.estates,
  });

  final List<HomeDownloadItem> downloads;
  final List<HomeLiveActivityItem> liveActivities;
  final HomeExecutiveWelcome executive;
  final List<HomeEstateItem> estates;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionWrapper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedSectionTitle(
                overline: 'EXECUTIVE MESSAGE',
                title: 'Welcome from leadership',
                alignment: TextAlign.start,
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.charcoal,
                      AppColors.gold.withValues(alpha: 0.2),
                    ],
                  ),
                  borderRadius: AppRadius.cardBorder,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      executive.message,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.white,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.base),
                    Text(
                      '— ${executive.name}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.gold,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedSectionTitle(
                overline: 'LIVE ACTIVITY',
                title: 'What\'s happening now',
                alignment: TextAlign.start,
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final activity in liveActivities)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(LucideIcons.activity, color: AppColors.gold, size: 18),
                  title: Text(activity.message),
                  trailing: Text(activity.timeAgo, style: Theme.of(context).textTheme.labelSmall),
                ),
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedSectionTitle(
                overline: 'COMPARE ESTATES',
                title: 'Interactive estate comparison',
                subtitle: 'Compare flagship estates side by side.',
                alignment: TextAlign.start,
              ),
              const SizedBox(height: AppSpacing.lg),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Estate')),
                    DataColumn(label: Text('Location')),
                    DataColumn(label: Text('From')),
                    DataColumn(label: Text('Units')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: estates
                      .map(
                        (e) => DataRow(cells: [
                          DataCell(Text(e.name)),
                          DataCell(Text(e.location)),
                          DataCell(Text(e.priceFrom)),
                          DataCell(Text('${e.propertyCount}')),
                          DataCell(Text(e.status)),
                        ]),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: AppColors.charcoal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedSectionTitle(
                overline: 'DOWNLOADS',
                title: 'Download center',
                alignment: TextAlign.start,
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.base,
                children: downloads
                    .map(
                      (d) => ActionChip(
                        avatar: const Icon(Icons.download_rounded, size: 16),
                        label: Text('${d.title} (${d.fileType})'),
                        onPressed: () {},
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.section),
          child: NewsletterBanner(),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
          child: CtaBanner(
            title: 'Ready to find your next home or investment?',
            subtitle: 'Book an inspection, request a callback, or speak with our team today.',
            primaryLabel: 'Book Inspection',
            primaryPath: RoutePaths.bookInspection,
            secondaryLabel: 'Contact Sales',
            secondaryPath: RoutePaths.contact,
          ),
        ),
        SectionWrapper(
          child: _ContactActions(),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: _AiAssistantTeaser(),
        ),
      ],
    );
  }
}

class _ContactActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
          onPressed: () => launchUrl(Uri.parse('https://wa.me/')),
        ),
      ],
    );
  }
}

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
                Text('AI Property Assistant', style: Theme.of(context).textTheme.titleMedium),
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
