import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/cms_hero_media_background.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/cms/domain/data/hub_page_cms.dart';
import 'package:hdhomesproject/features/cms/domain/data/legal_page_copy.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';

/// Public renderer for published CMS pages (`/pages/:slug`).
class CmsPublicPage extends ConsumerWidget {
  const CmsPublicPage({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageAsync = ref.watch(publishedPageBySlugProvider(slug));

    return pageAsync.when(
      loading: () => const SectionWrapper(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 80),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (err, _) => SectionWrapper(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 80),
          child: Text(userFacingError(err, fallback: 'Unable to load page.')),
        ),
      ),
      data: (page) {
        final legal = LegalPageCopy.forSlug(slug);
        if (page == null && legal != null) {
          return _LegalDocument(
            title: legal.title,
            subtitle: legal.subtitle,
            body: legal.body,
          );
        }
        if (page == null) {
          return SectionWrapper(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Page not found',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This page is unpublished or does not exist.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.slate500),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.go(RoutePaths.home),
                    child: const Text('Back to home'),
                  ),
                ],
              ),
            ),
          );
        }

        final overlay = hubHeroFromPage(page);
        final publishedBody = overlay.body ?? '';
        final body = (legal != null && legal.replaces(publishedBody))
            ? legal.body
            : publishedBody;

        return Column(
          children: [
            SizedBox(
              height: context.isMobile ? 360 : 420,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CmsHeroMediaBackground(
                    imageUrl: overlay.backgroundImageUrl,
                    videoUrl: overlay.backgroundVideoUrl,
                    fallbackColors: const [
                      AppColors.charcoal,
                      AppColors.deepBlack,
                    ],
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.deepBlack.withValues(alpha: 0.92),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      context.pagePadding,
                      context.isMobile ? 100 : 120,
                      context.pagePadding,
                      AppSpacing.xxl,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          overlay.headline ?? page.title,
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        if ((overlay.subheadline ?? page.metaDescription ?? '')
                            .isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            overlay.subheadline ?? page.metaDescription!,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: AppColors.textSecondaryDark),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (body.isNotEmpty)
              SectionWrapper(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: SelectableText(
                    body,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _LegalDocument extends StatelessWidget {
  const _LegalDocument({
    required this.title,
    required this.subtitle,
    required this.body,
  });

  final String title;
  final String subtitle;
  final String body;

  @override
  Widget build(BuildContext context) {
    return SectionWrapper(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.slate500),
            ),
            const SizedBox(height: 24),
            SelectableText(
              body.trim(),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
