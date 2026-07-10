import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Investor portal stub page — shell + nav live; full modules ship in Volume 3.
class InvestorPortalStubPage extends StatelessWidget {
  const InvestorPortalStubPage({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.pieChart, size: 56, color: AppColors.gold),
              const SizedBox(height: AppSpacing.lg),
              Text(title, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle ??
                    'This Investor Portal module is scaffolded and ready for Volume 3 — '
                    'Authentication & User Ecosystem. Portfolio, analytics, construction, '
                    'reports, and documents will connect to live investor data.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              Wrap(
                spacing: AppSpacing.base,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.center,
                children: [
                  PrimaryButton(
                    label: 'Investment Hub',
                    icon: LucideIcons.trendingUp,
                    onPressed: () => context.go(RoutePaths.investment),
                  ),
                  PrimaryButton(
                    label: 'Trust Center',
                    variant: ButtonVariant.secondary,
                    icon: LucideIcons.shield,
                    onPressed: () => context.go(RoutePaths.trust),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
