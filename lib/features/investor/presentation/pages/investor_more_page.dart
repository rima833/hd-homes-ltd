import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:hdhomesproject/features/investor/presentation/providers/investor_providers.dart';
import 'package:hdhomesproject/features/investor/presentation/widgets/investor_portal_widgets.dart';
import 'package:hdhomesproject/features/settings/domain/entities/portal_feature_gates.dart';
import 'package:hdhomesproject/features/settings/presentation/providers/platform_settings_providers.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Mobile More hub — secondary investor modules not on the bottom bar.
class InvestorMorePage extends ConsumerWidget {
  const InvestorMorePage({super.key});

  EdgeInsets _padding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return EdgeInsets.all(w >= AppBreakpoints.tablet ? 24 : 16);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(investorPortalFeatureFlagsProvider);
    final unreadNotifications =
        ref.watch(investorUnreadCountProvider).valueOrNull ?? 0;
    final conversations =
        ref.watch(investorConversationsProvider).valueOrNull ?? const [];
    final unreadMessages =
        conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);
    final pad = _padding(context);

    final explore = <Widget>[
      if (flags.allowsPath(RoutePaths.investorTools))
        _MoreLink(
          icon: LucideIcons.calculator,
          title: 'Investment tools',
          subtitle: 'ROI calculator, payment plans, invest flow',
          onTap: () => context.go(RoutePaths.investorTools),
        ),
      if (flags.allowsPath(RoutePaths.investorAnalytics))
        _MoreLink(
          icon: LucideIcons.lineChart,
          title: 'Investment analytics',
          subtitle: 'ROI, NAV, and allocation',
          onTap: () => context.go(RoutePaths.investorAnalytics),
        ),
      if (flags.allowsPath(RoutePaths.investorConstruction))
        _MoreLink(
          icon: LucideIcons.hardHat,
          title: 'Construction progress',
          subtitle: 'Stages, photos, and site updates',
          onTap: () => context.go(RoutePaths.investorConstruction),
        ),
      if (flags.allowsPath(RoutePaths.investorReports))
        _MoreLink(
          icon: LucideIcons.fileBarChart,
          title: 'Reports & statements',
          subtitle: 'Filed reports and exports',
          onTap: () => context.go(RoutePaths.investorReports),
        ),
      if (flags.allowsPath(RoutePaths.investorDocuments))
        _MoreLink(
          icon: LucideIcons.fileText,
          title: 'Documents',
          subtitle: 'Vault and shared files',
          onTap: () => context.go(RoutePaths.investorDocuments),
        ),
      if (flags.allowsPath(RoutePaths.investorReferrals))
        _MoreLink(
          icon: LucideIcons.gift,
          title: 'Referrals',
          subtitle: 'Share your code and track earnings',
          onTap: () => context.go(RoutePaths.investorReferrals),
        ),
    ];

    final messages = <Widget>[
      if (flags.allowsPath(RoutePaths.investorMessages))
        _MoreLink(
          icon: LucideIcons.messageCircle,
          title: 'Messages',
          subtitle: 'Threads & live chat',
          badge: unreadMessages,
          onTap: () => context.go(RoutePaths.investorMessages),
        ),
      if (flags.allowsPath(RoutePaths.investorNotifications))
        _MoreLink(
          icon: LucideIcons.bell,
          title: 'Notifications',
          subtitle: 'Alerts and announcements',
          badge: unreadNotifications,
          onTap: () => context.go(RoutePaths.investorNotifications),
        ),
      if (flags.allowsPath(RoutePaths.investorSupport))
        _MoreLink(
          icon: LucideIcons.lifeBuoy,
          title: 'Support',
          subtitle: 'Open and track tickets',
          onTap: () => context.go(RoutePaths.investorSupport),
        ),
    ];

    return ListView(
      padding: pad,
      children: [
        Semantics(
          header: true,
          child: Text(
            'More',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _moreSubtitle(flags),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.slate400,
              ),
        ),
        if (explore.isNotEmpty) ...[
          const SizedBox(height: 24),
          const InvestorSectionHeader(title: 'Explore'),
          InvestorPortalCard(
            padding: EdgeInsets.zero,
            child: Column(children: explore),
          ),
        ],
        if (messages.isNotEmpty) ...[
          const SizedBox(height: 24),
          const InvestorSectionHeader(title: 'Messages & help'),
          InvestorPortalCard(
            padding: EdgeInsets.zero,
            child: Column(children: messages),
          ),
        ],
        const SizedBox(height: 24),
        const InvestorSectionHeader(title: 'Account'),
        InvestorPortalCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _MoreLink(
                icon: LucideIcons.settings,
                title: 'Settings',
                subtitle: 'Profile, KYC, and preferences',
                onTap: () => context.go(RoutePaths.investorSettings),
              ),
              _MoreLink(
                icon: LucideIcons.logOut,
                title: 'Sign out',
                destructive: true,
                onTap: () async {
                  await ref.read(authControllerProvider.notifier).signOut();
                  if (context.mounted) context.go(RoutePaths.login);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  String _moreSubtitle(PortalFeatureFlags flags) {
    if (!flags.enabled) {
      return 'Account tools while the portal is temporarily limited.';
    }
    return 'Analytics, documents, support, and account tools.';
  }
}

class _MoreLink extends StatelessWidget {
  const _MoreLink({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.badge = 0,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final int badge;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.error : AppColors.white;
    final label = badge > 0 ? '$title, $badge unread' : title;
    return Semantics(
      button: true,
      label: label,
      hint: subtitle,
      child: ListTile(
        leading: Icon(
          icon,
          color: destructive ? AppColors.error : AppColors.gold,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: const TextStyle(color: AppColors.slate400),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badge > 0)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            if (!destructive)
              const Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: AppColors.slate500,
              ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
