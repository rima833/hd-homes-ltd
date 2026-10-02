import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Coarse login audience used for friendly welcome copy (pre-auth).
enum LoginAudience {
  admin,
  sales,
  construction,
  finance,
  marketing,
  staff,
  investor,
  client;

  static LoginAudience? tryParse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'admin':
        return LoginAudience.admin;
      case 'sales':
      case 'sales_team':
        return LoginAudience.sales;
      case 'construction':
      case 'construction_manager':
        return LoginAudience.construction;
      case 'finance':
        return LoginAudience.finance;
      case 'marketing':
        return LoginAudience.marketing;
      case 'staff':
        return LoginAudience.staff;
      case 'investor':
        return LoginAudience.investor;
      case 'client':
        return LoginAudience.client;
      default:
        return null;
    }
  }

  String get label => switch (this) {
        LoginAudience.admin => 'Admin',
        LoginAudience.sales => 'Sales',
        LoginAudience.construction => 'Construction',
        LoginAudience.finance => 'Finance',
        LoginAudience.marketing => 'Marketing',
        LoginAudience.staff => 'Team member',
        LoginAudience.investor => 'Investor',
        LoginAudience.client => 'Client',
      };

  IconData get icon => switch (this) {
        LoginAudience.admin => LucideIcons.shieldCheck,
        LoginAudience.sales => LucideIcons.users,
        LoginAudience.construction => LucideIcons.hardHat,
        LoginAudience.finance => LucideIcons.wallet,
        LoginAudience.marketing => LucideIcons.megaphone,
        LoginAudience.staff => LucideIcons.briefcase,
        LoginAudience.investor => LucideIcons.trendingUp,
        LoginAudience.client => LucideIcons.home,
      };

  /// Short line under “Welcome back” on the form.
  String get welcomeLine => switch (this) {
        LoginAudience.admin =>
          'Good to see you — we’ll open Admin Control after you sign in.',
        LoginAudience.sales =>
          'Good to see you — we’ll open Sales after you sign in.',
        LoginAudience.construction =>
          'Good to see you — we’ll open Construction after you sign in.',
        LoginAudience.finance =>
          'Good to see you — we’ll open Finance after you sign in.',
        LoginAudience.marketing =>
          'Good to see you — we’ll open Marketing after you sign in.',
        LoginAudience.staff =>
          'Good to see you — we’ll open your team workspace after you sign in.',
        LoginAudience.investor =>
          'Welcome back — continue to your Investor Portal.',
        LoginAudience.client =>
          'Welcome back — your Client Dashboard is ready for you.',
      };

  /// Left brand-panel supporting sentence when email matches a known account.
  String get brandLine => switch (this) {
        LoginAudience.admin =>
          'You’re signing into Admin Control — manage the platform with confidence.',
        LoginAudience.sales =>
          'You’re signing into Sales — leads, clients, and deals in one place.',
        LoginAudience.construction =>
          'You’re signing into Construction — sites, progress, and delivery in one place.',
        LoginAudience.finance =>
          'You’re signing into Finance — payments, budgets, and records in one place.',
        LoginAudience.marketing =>
          'You’re signing into Marketing — campaigns and content in one place.',
        LoginAudience.staff =>
          'You’re signing into your team workspace — the tools for your desk are ready.',
        LoginAudience.investor =>
          'You’re signing into your Investor Portal — track portfolios and opportunities securely.',
        LoginAudience.client =>
          'You’re signing into your Client Dashboard — properties, bookings, and support await.',
      };
}

class LoginAudienceCopy {
  const LoginAudienceCopy._();

  static const brandHeadline = 'Secure access to your property journey';

  static const brandDefaultBody =
      'Sign in to pick up where you left off — homes, investments, and support, '
      'kept safe with secure session protection.';

  static const formDefaultSubtitle =
      'Sign in to continue to your HD Homes workspace';

  static String brandBody(LoginAudience? audience) =>
      audience?.brandLine ?? brandDefaultBody;

  static String formSubtitle(LoginAudience? audience) =>
      audience?.welcomeLine ?? formDefaultSubtitle;
}

/// Compact banner shown under the email field once a role is detected.
class LoginAudienceHint extends StatelessWidget {
  const LoginAudienceHint({super.key, required this.audience});

  final LoginAudience audience;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(audience.icon, size: 16, color: AppColors.gold),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              audience.welcomeLine,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
