import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/growth/marketing/newsletter_service.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/l10n/app_strings.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/core/widgets/inputs/app_text_field.dart';
import 'package:hdhomesproject/features/settings/presentation/providers/platform_settings_providers.dart';

/// Newsletter signup band — wired to Growth Engine newsletter service.
class NewsletterBanner extends ConsumerStatefulWidget {
  const NewsletterBanner({super.key});

  @override
  ConsumerState<NewsletterBanner> createState() => _NewsletterBannerState();
}

class _NewsletterBannerState extends ConsumerState<NewsletterBanner> {
  final _emailController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _subscribe() async {
    setState(() => _loading = true);
    try {
      final ok = await subscribeNewsletter(ref, email: _emailController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Thank you for subscribing!'
                : 'Please enter a valid email address.',
          ),
        ),
      );
      if (ok) _emailController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is StateError
                ? e.message
                : 'Unable to subscribe right now. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref
            .watch(publishedPlatformSettingsProvider)
            .valueOrNull
            ?.enableNewsletter ??
        true;
    if (!enabled) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: context.pagePadding,
        vertical: AppSpacing.section,
      ),
      decoration: BoxDecoration(
        gradient: AppColors.goldGradient,
        borderRadius: AppRadius.cardBorder,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Fixed 360px form overflows tablet side-by-side layouts.
          final stacked = constraints.maxWidth < 900;
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _content(context, stackedForm: true),
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _copy(context)),
              const SizedBox(width: AppSpacing.xl),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: SizedBox(
                  width: 360,
                  child: _form(context, stackedForm: false),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _content(BuildContext context, {required bool stackedForm}) => [
        _copy(context),
        const SizedBox(height: AppSpacing.lg),
        _form(context, stackedForm: stackedForm),
      ];

  Widget _copy(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.newsletterTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.deepBlack,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppStrings.newsletterSubtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.deepBlack.withValues(alpha: 0.8),
                ),
          ),
        ],
      );

  Widget _form(BuildContext context, {required bool stackedForm}) {
    final field = AppTextField(
      controller: _emailController,
      hint: 'Email address',
      keyboardType: TextInputType.emailAddress,
    );
    final button = PrimaryButton(
      label: AppStrings.newsletterCta,
      isLoading: _loading,
      onPressed: _subscribe,
    );

    if (stackedForm && context.screenWidth < 420) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          field,
          const SizedBox(height: AppSpacing.sm),
          button,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: field),
        const SizedBox(width: AppSpacing.sm),
        button,
      ],
    );
  }
}
