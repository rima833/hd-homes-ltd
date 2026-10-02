import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/registration_models.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Post-verification / post-registration welcome experience.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key, this.accountTypeId});

  final String? accountTypeId;

  @override
  Widget build(BuildContext context) {
    final type =
        RegistrationAccountType.fromId(accountTypeId) ?? RegistrationAccountType.client;
    final isInvestor = type == RegistrationAccountType.investor;
    final isStaff = accountTypeId == 'staff';

    final actions = isStaff
        ? const [
            (
              LucideIcons.layoutDashboard,
              'Open admin dashboard',
              RoutePaths.dashboard,
            ),
            (
              LucideIcons.users,
              'Organization & staff',
              RoutePaths.dashboardOrganization,
            ),
            (
              LucideIcons.shield,
              'Security center',
              RoutePaths.securityCenter,
            ),
          ]
        : isInvestor
            ? const [
                (
                  LucideIcons.layoutDashboard,
                  'Open investor portal',
                  RoutePaths.investor,
                ),
                (
                  LucideIcons.trendingUp,
                  'Explore investment opportunities',
                  RoutePaths.investment,
                ),
                (
                  LucideIcons.shield,
                  'Review Trust Center safeguards',
                  RoutePaths.trust,
                ),
              ]
            : const [
                (
                  LucideIcons.layoutDashboard,
                  'Open client portal',
                  RoutePaths.client,
                ),
                (
                  LucideIcons.search,
                  'Browse properties',
                  RoutePaths.properties,
                ),
                (
                  LucideIcons.calendar,
                  'Book an inspection',
                  RoutePaths.bookInspection,
                ),
              ];

    final subtitle = isStaff
        ? 'Your staff account is ready. Sign in to open the HD Homes admin dashboard.'
        : isInvestor
            ? 'Your investor account is ready. Complete KYC when prompted, explore opportunities, and access your portal after sign-in.'
            : 'Your client account is ready. Save favorites, book inspections, and track your property journey.';

    final primaryPath = isStaff
        ? RoutePaths.staffOnboarding
        : isInvestor
            ? RoutePaths.investor
            : RoutePaths.client;

    final primaryLabel = isStaff
        ? 'Complete staff profile'
        : isInvestor
            ? 'Open Investor Portal'
            : 'Open Client Dashboard';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  Image.asset(AppTheme.logoAsset, height: 48),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Welcome to HD Homes',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(subtitle, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.xl),
                  ...actions.map(
                    (a) => Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        leading: Icon(a.$1, color: AppColors.gold),
                        title: Text(a.$2),
                        trailing: const Icon(LucideIcons.chevronRight),
                        onTap: () => context.go(a.$3),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: primaryLabel,
                    expand: true,
                    icon: LucideIcons.layoutDashboard,
                    onPressed: () => context.go(primaryPath),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PrimaryButton(
                    label: 'Sign in',
                    variant: ButtonVariant.secondary,
                    expand: true,
                    onPressed: () => context.go(RoutePaths.login),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
