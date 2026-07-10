import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/growth/marketing/newsletter_service.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/l10n/app_strings.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/core/widgets/inputs/app_text_field.dart';

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
    final ok = subscribeNewsletter(ref, email: _emailController.text);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Thank you for subscribing!' : 'Please enter a valid email address.',
        ),
      ),
    );
    if (ok) _emailController.clear();
  }

  @override
  Widget build(BuildContext context) {
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
      child: context.isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _content(context),
            )
          : Row(
              children: [
                Expanded(child: _copy(context)),
                const SizedBox(width: AppSpacing.xl),
                SizedBox(width: 360, child: _form(context)),
              ],
            ),
    );
  }

  List<Widget> _content(BuildContext context) => [
        _copy(context),
        const SizedBox(height: AppSpacing.lg),
        _form(context),
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

  Widget _form(BuildContext context) => Row(
        children: [
          Expanded(
            child: AppTextField(
              controller: _emailController,
              hint: 'Email address',
              keyboardType: TextInputType.emailAddress,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          PrimaryButton(
            label: AppStrings.newsletterCta,
            isLoading: _loading,
            onPressed: _subscribe,
          ),
        ],
      );
}
