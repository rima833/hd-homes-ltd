import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Public-site bridge into the Investor Portal (Volume 3 auth unlocks full access).
///
/// Unauthenticated visitors hitting [RoutePaths.investor] are redirected to login
/// with a return URL — this CTA is the intentional public entry point.
class InvestorPortalCtaSection extends StatelessWidget {
  const InvestorPortalCtaSection({
    super.key,
    this.title = 'Investor Portal',
    this.subtitle =
        'Track portfolios, construction progress, reports, and documents. '
        'Sign in to access your Investor Portal — full experience ships in Volume 3.',
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SectionWrapper(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          AnimatedSectionTitle(
            overline: 'PORTAL',
            title: title,
            subtitle: subtitle,
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.base,
            alignment: WrapAlignment.center,
            children: const [
              _PortalCapability(icon: LucideIcons.pieChart, label: 'Portfolio'),
              _PortalCapability(icon: LucideIcons.hardHat, label: 'Construction'),
              _PortalCapability(icon: LucideIcons.fileBarChart, label: 'Reports'),
              _PortalCapability(icon: LucideIcons.folderOpen, label: 'Documents'),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.base,
            runSpacing: AppSpacing.sm,
            alignment: WrapAlignment.center,
            children: [
              PrimaryButton(
                label: 'Access Investor Portal',
                icon: LucideIcons.lock,
                onPressed: () => context.go(RoutePaths.investor),
              ),
              PrimaryButton(
                label: 'Sign in',
                variant: ButtonVariant.secondary,
                icon: LucideIcons.logIn,
                onPressed: () => context.go(
                  '${RoutePaths.login}?redirect=${Uri.encodeComponent(RoutePaths.investor)}',
                ),
              ),
              PrimaryButton(
                label: 'Trust Center',
                variant: ButtonVariant.ghost,
                icon: LucideIcons.shield,
                onPressed: () => context.go(RoutePaths.trust),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PortalCapability extends StatelessWidget {
  const _PortalCapability({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: Column(
        children: [
          Icon(icon, color: AppColors.gold),
          const SizedBox(height: AppSpacing.xs),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}
