import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/dxp/domain/entities/dxp_models.dart';
import 'package:hdhomesproject/features/dxp/presentation/providers/dxp_controller.dart';
import 'package:url_launcher/url_launcher.dart';

/// Public renderer for published marketing landing pages (`/lp/:slug`).
class PublicLandingPage extends ConsumerWidget {
  const PublicLandingPage({super.key, required this.slug});

  final String slug;

  Future<void> _openCta(BuildContext context, String? raw) async {
    final target = (raw ?? RoutePaths.contact).trim();
    if (target.isEmpty) {
      context.go(RoutePaths.contact);
      return;
    }
    if (target.startsWith('http://') || target.startsWith('https://')) {
      final uri = Uri.tryParse(target);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
    final path = target.startsWith('/') ? target : '/$target';
    context.go(path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageAsync = ref.watch(publishedLandingBySlugProvider(slug));

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
          child: Text(
            userFacingError(err, fallback: 'Unable to load landing page.'),
          ),
        ),
      ),
      data: (page) {
        if (page == null) {
          return SectionWrapper(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Landing page not found',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This campaign page is unpublished or does not exist.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.slate500,
                        ),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Back to home',
                    onPressed: () => context.go(RoutePaths.home),
                  ),
                ],
              ),
            ),
          );
        }
        return _LandingHero(
          page: page,
          onCta: () => _openCta(context, page.ctaUrl),
        );
      },
    );
  }
}

class _LandingHero extends StatelessWidget {
  const _LandingHero({required this.page, required this.onCta});

  final DxpLandingPage page;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    final headline = page.headline?.trim().isNotEmpty == true
        ? page.headline!
        : page.title;
    final sub = page.subheadline?.trim() ?? '';
    final cta = page.ctaLabel?.trim().isNotEmpty == true
        ? page.ctaLabel!
        : 'Get started';
    final heroUrl = page.heroImageUrl?.trim();
    final height = context.isMobile ? 560.0 : 680.0;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (heroUrl != null && heroUrl.isNotEmpty)
            MediaDeliveryImage(
              url: heroUrl,
              fit: BoxFit.cover,
              errorWidget: const ColoredBox(color: AppColors.charcoal),
            )
          else
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.charcoal,
                    Color(0xFF2A2A2A),
                    AppColors.deepBlack,
                  ],
                ),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.deepBlack.withValues(alpha: 0.3),
                  AppColors.deepBlack.withValues(alpha: 0.9),
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
                Image.asset(AppTheme.logoAsset, height: 56)
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .scale(begin: const Offset(0.9, 0.9)),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  headline,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                )
                    .animate()
                    .fadeIn(delay: 120.ms, duration: 500.ms)
                    .slideY(begin: 0.08, end: 0),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Text(
                      sub,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondaryDark,
                            height: 1.5,
                          ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 220.ms, duration: 500.ms)
                      .slideY(begin: 0.06, end: 0),
                ],
                const SizedBox(height: 24),
                PrimaryButton(label: cta, onPressed: onCta)
                    .animate()
                    .fadeIn(delay: 320.ms, duration: 450.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
