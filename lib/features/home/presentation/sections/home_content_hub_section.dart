import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/home/data/models/home_cms_content.dart';

/// Sections 21–24 — Blog, market insights, events, FAQ.
class HomeContentHubSection extends StatelessWidget {
  const HomeContentHubSection({
    super.key,
    required this.blogPosts,
    required this.insights,
    required this.events,
    required this.faqs,
  });

  final List<HomeBlogItem> blogPosts;
  final List<HomeMarketInsightItem> insights;
  final List<HomeEventItem> events;
  final List<HomeFaqItem> faqs;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionWrapper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedSectionTitle(
                overline: 'INSIGHTS',
                title: 'Latest articles',
                alignment: TextAlign.start,
              ),
              const SizedBox(height: AppSpacing.xl),
              for (final post in blogPosts)
                _BlogTile(post: post),
              Align(
                alignment: Alignment.centerRight,
                child: PrimaryButton(
                  label: 'View Blog',
                  variant: ButtonVariant.ghost,
                  onPressed: () => context.go(RoutePaths.blog),
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
                overline: 'MARKET DATA',
                title: 'Market insights',
                alignment: TextAlign.start,
              ),
              const SizedBox(height: AppSpacing.xl),
              for (final insight in insights)
                _InsightCard(insight: insight),
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedSectionTitle(
                overline: 'EVENTS',
                title: 'Upcoming events',
                alignment: TextAlign.start,
              ),
              const SizedBox(height: AppSpacing.xl),
              for (final event in events) _EventTile(event: event),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: AppColors.charcoal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnimatedSectionTitle(
                overline: 'FAQ',
                title: 'Frequently asked questions',
                alignment: TextAlign.start,
              ),
              const SizedBox(height: AppSpacing.xl),
              for (final faq in faqs)
                _FaqTile(question: faq.question, answer: faq.answer),
              PrimaryButton(
                label: 'View All FAQs',
                variant: ButtonVariant.ghost,
                onPressed: () => context.go(RoutePaths.contact),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BlogTile extends StatelessWidget {
  const _BlogTile({required this.post});

  final HomeBlogItem post;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(post.title),
      subtitle: Text('${post.category} · ${post.date}\n${post.excerpt}'),
      isThreeLine: true,
      trailing: const Icon(Icons.arrow_forward_rounded),
      onTap: () => context.go(post.route),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});

  final HomeMarketInsightItem insight;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.base),
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insight.title, style: Theme.of(context).textTheme.titleSmall),
                Text(insight.summary, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Column(
            children: [
              Text(insight.change, style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)),
              Text(insight.trend, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final HomeEventItem event;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(child: Icon(Icons.event_rounded)),
      title: Text(event.title),
      subtitle: Text('${event.date} · ${event.location} · ${event.type}'),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(question, style: const TextStyle(color: AppColors.white)),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(answer, style: const TextStyle(color: AppColors.textSecondaryDark)),
        ),
      ],
    );
  }
}
