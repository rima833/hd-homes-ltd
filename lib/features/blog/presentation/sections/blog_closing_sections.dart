import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/page_container.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/core/widgets/feedback/app_badge.dart';
import 'package:hdhomesproject/features/blog/data/models/blog_content.dart';
import 'package:hdhomesproject/features/blog/data/providers/blog_catalog_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Hub closing sections — authors, press, events, glossary, newsletter, FAQs, podcasts.
class BlogClosingSections extends HookConsumerWidget {
  const BlogClosingSections({super.key, this.newsletterKey});

  final GlobalKey? newsletterKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cms = ref.watch(blogHubCmsProvider);
    final emailController = useTextEditingController();
    final subscribed = useState(false);
    final glossaryQuery = useState('');
    final faqQuery = useState('');

    final filteredGlossary = cms.glossary
        .where(
          (g) =>
              glossaryQuery.value.isEmpty ||
              g.term.toLowerCase().contains(glossaryQuery.value.toLowerCase()),
        )
        .toList();

    final filteredFaqs = cms.faqs
        .where(
          (f) =>
              faqQuery.value.isEmpty ||
              f.question.toLowerCase().contains(faqQuery.value.toLowerCase()),
        )
        .toList();

    return Column(
      children: [
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'AUTHORS',
                title: 'Meet our experts',
              ),
              const SizedBox(height: AppSpacing.xl),
              Wrap(
                spacing: AppSpacing.base,
                runSpacing: AppSpacing.base,
                children: cms.authors.map((a) => _AuthorCard(author: a)).toList(),
              ),
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'NEWSROOM',
                title: 'Press & media center',
              ),
              const SizedBox(height: AppSpacing.xl),
              ...cms.pressReleases.map(
                (p) => ListTile(
                  leading: const Icon(LucideIcons.megaphone, color: AppColors.gold),
                  title: Text(p.title),
                  subtitle: Text('${p.date} · ${p.excerpt}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/blog/${p.slug}'),
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              PrimaryButton(
                label: 'Media kit & brand assets',
                variant: ButtonVariant.secondary,
                icon: LucideIcons.folderOpen,
                onPressed: () => context.go(RoutePaths.contact),
              ),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'EVENTS',
                title: 'Upcoming events',
                subtitle: 'Open houses, webinars, and investor seminars.',
              ),
              const SizedBox(height: AppSpacing.xl),
              ...cms.events.map((e) => _EventCard(event: e)),
            ],
          ),
        ),
        SectionWrapper(
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'GLOSSARY',
                title: 'Real estate glossary',
                subtitle: 'A–Z terms for buyers, investors, and developers.',
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: context.isMobile ? double.infinity : 400,
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search terms…',
                    prefixIcon: Icon(LucideIcons.search),
                  ),
                  onChanged: (v) => glossaryQuery.value = v,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ...filteredGlossary.map((g) => _GlossaryTile(term: g)),
            ],
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'PODCASTS',
                title: 'Podcasts',
                subtitle: 'Coming soon — audio episodes with transcripts.',
              ),
              const SizedBox(height: AppSpacing.lg),
              const Icon(LucideIcons.headphones, size: 48, color: AppColors.gold),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Future-ready placeholder for HD Homes audio content.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        SectionWrapper(
          key: newsletterKey,
          child: PageContainer(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.charcoal,
                borderRadius: AppRadius.cardBorder,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stay ahead of the market',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.white),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Subscribe for weekly insights, market reports, and estate launch alerts.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondaryDark),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (!subscribed.value)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: emailController,
                            decoration: const InputDecoration(
                              hintText: 'your@email.com',
                              labelText: 'Email address',
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.base),
                        PrimaryButton(
                          label: 'Subscribe',
                          icon: LucideIcons.mail,
                          onPressed: () {
                            if (emailController.text.contains('@')) {
                              subscribed.value = true;
                            }
                          },
                        ),
                      ],
                    )
                  else
                    const Row(
                      children: [
                        Icon(LucideIcons.checkCircle, color: AppColors.success),
                        SizedBox(width: AppSpacing.sm),
                        Text('Thanks — check your inbox to confirm.'),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(overline: 'FAQ', title: 'Knowledge Center FAQs'),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search FAQs…',
                  prefixIcon: Icon(LucideIcons.search),
                ),
                onChanged: (v) => faqQuery.value = v,
              ),
              const SizedBox(height: AppSpacing.lg),
              ...filteredFaqs.map(
                (f) => ExpansionTile(
                  title: Text(f.question),
                  children: [Padding(padding: const EdgeInsets.all(AppSpacing.base), child: Text(f.answer))],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AuthorCard extends StatelessWidget {
  const _AuthorCard({required this.author});

  final BlogAuthor author;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.gold.withValues(alpha: 0.2),
                child: Text(author.name.substring(0, 1), style: const TextStyle(color: AppColors.gold)),
              ),
              const SizedBox(height: AppSpacing.base),
              Row(
                children: [
                  Expanded(child: Text(author.name, style: Theme.of(context).textTheme.titleMedium)),
                  if (author.verified)
                    const AppBadge(label: 'Verified', variant: BadgeVariant.gold),
                ],
              ),
              Text(author.role, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              Text(author.bio, maxLines: 3, overflow: TextOverflow.ellipsis),
              const SizedBox(height: AppSpacing.sm),
              Text('${author.articleCount} articles',
                  style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final BlogEvent event;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.base),
      child: ListTile(
        leading: const Icon(LucideIcons.calendar, color: AppColors.gold),
        title: Text(event.title),
        subtitle: Text('${event.date}\n${event.location}'),
        isThreeLine: true,
        trailing: PrimaryButton(
          label: 'Register',
          onPressed: () => context.go(RoutePaths.contact),
        ),
      ),
    );
  }
}

class _GlossaryTile extends StatelessWidget {
  const _GlossaryTile({required this.term});

  final GlossaryTerm term;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(term.term),
      subtitle: Text('${term.letter} · ${term.relatedArticleSlugs.length} related articles'),
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Text(term.definition),
        ),
      ],
    );
  }
}
