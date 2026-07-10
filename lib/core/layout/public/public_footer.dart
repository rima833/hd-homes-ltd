import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/l10n/app_strings.dart';

class PublicFooter extends StatelessWidget {
  const PublicFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.charcoal,
      padding: EdgeInsets.symmetric(
        horizontal: context.pagePadding,
        vertical: AppSpacing.xxxl,
      ),
      child: Column(
        children: [
          Text(
            AppStrings.companyName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.white,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppStrings.tagline,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.gray,
                ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.sm,
            alignment: WrapAlignment.center,
            children: [
              TextButton(
                onPressed: () => context.go(RoutePaths.about),
                child: const Text('About', style: TextStyle(color: AppColors.white)),
              ),
              TextButton(
                onPressed: () => context.go(RoutePaths.properties),
                child: const Text('Properties', style: TextStyle(color: AppColors.white)),
              ),
              TextButton(
                onPressed: () => context.go(RoutePaths.contact),
                child: const Text('Contact', style: TextStyle(color: AppColors.white)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            '© ${DateTime.now().year} HD Homes Ltd. All rights reserved.',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.gray,
                ),
          ),
        ],
      ),
    );
  }
}
