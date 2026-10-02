import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/communication_controller.dart';
import 'package:hdhomesproject/features/client/presentation/providers/client_providers.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/client_portal_widgets.dart';
import 'package:hdhomesproject/features/settings/domain/entities/portal_feature_gates.dart';
import 'package:hdhomesproject/features/settings/presentation/providers/platform_settings_providers.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Mobile More hub — secondary client modules not on the bottom bar.
class ClientMorePage extends ConsumerWidget {
  const ClientMorePage({super.key});

  EdgeInsets _padding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return EdgeInsets.all(w >= AppBreakpoints.tablet ? 24 : 16);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(clientPortalFeatureFlagsProvider);
    final unreadNotifications =
        ref.watch(notificationCenterProvider).valueOrNull?.unreadCount ?? 0;
    final conversations =
        ref.watch(clientConversationsProvider).valueOrNull ?? const [];
    final unreadMessages =
        conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);
    final pad = _padding(context);

    final buying = <Widget>[
      if (flags.allowsPath(RoutePaths.clientTools))
        _MoreLink(
          icon: LucideIcons.calculator,
          title: 'Buying tools',
          subtitle: 'Payment plans and how buying works',
          onTap: () => context.go(RoutePaths.clientTools),
        ),
      if (flags.allowsPath(RoutePaths.clientApplications))
        _MoreLink(
          icon: LucideIcons.fileCheck,
          title: 'Applications',
          subtitle: 'Track and submit property applications',
          onTap: () => context.go(RoutePaths.clientApplications),
        ),
      if (flags.allowsPath(RoutePaths.clientSaved))
        _MoreLink(
          icon: LucideIcons.heart,
          title: 'Saved properties',
          subtitle: 'Marketplace shortlist',
          onTap: () => context.go(RoutePaths.clientSaved),
        ),
      if (flags.allowsPath(RoutePaths.clientInspections))
        _MoreLink(
          icon: LucideIcons.clipboardCheck,
          title: 'Inspections',
          subtitle: 'Book and manage site visits',
          onTap: () => context.go(RoutePaths.clientInspections),
        ),
      if (flags.allowsPath(RoutePaths.clientConsultations))
        _MoreLink(
          icon: LucideIcons.calendar,
          title: 'Consultations',
          subtitle: 'Talk with HD Homes advisors',
          onTap: () => context.go(RoutePaths.clientConsultations),
        ),
    ];

    final journey = <Widget>[
      if (flags.allowsPath(RoutePaths.clientConstruction))
        _MoreLink(
          icon: LucideIcons.hardHat,
          title: 'Construction',
          subtitle: 'Progress photos and milestones',
          onTap: () => context.go(RoutePaths.clientConstruction),
        ),
      if (flags.allowsPath(RoutePaths.clientDocuments))
        _MoreLink(
          icon: LucideIcons.fileText,
          title: 'Documents',
          subtitle: 'Contracts, letters, and uploads',
          onTap: () => context.go(RoutePaths.clientDocuments),
        ),
      if (flags.allowsPath(RoutePaths.clientReferrals))
        _MoreLink(
          icon: LucideIcons.gift,
          title: 'Referrals',
          subtitle: 'Share your code and track earnings',
          onTap: () => context.go(RoutePaths.clientReferrals),
        ),
    ];

    final messages = <Widget>[
      if (flags.allowsPath(RoutePaths.clientMessages))
        _MoreLink(
          icon: LucideIcons.messageCircle,
          title: 'Messages',
          subtitle: 'Threads & live chat',
          badge: unreadMessages,
          onTap: () => context.go(RoutePaths.clientMessages),
        ),
      if (flags.allowsPath(RoutePaths.clientNotifications))
        _MoreLink(
          icon: LucideIcons.bell,
          title: 'Notifications',
          subtitle: 'Alerts and announcements',
          badge: unreadNotifications,
          onTap: () => context.go(RoutePaths.clientNotifications),
        ),
      if (flags.allowsPath(RoutePaths.clientSupport))
        _MoreLink(
          icon: LucideIcons.lifeBuoy,
          title: 'Support',
          subtitle: 'Open and track tickets',
          onTap: () => context.go(RoutePaths.clientSupport),
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
        if (buying.isNotEmpty) ...[
          const SizedBox(height: 24),
          const ClientSectionHeader(title: 'Buying'),
          ClientPortalCard(
            padding: EdgeInsets.zero,
            child: Column(children: buying),
          ),
        ],
        if (journey.isNotEmpty) ...[
          const SizedBox(height: 24),
          const ClientSectionHeader(title: 'Journey'),
          ClientPortalCard(
            padding: EdgeInsets.zero,
            child: Column(children: journey),
          ),
        ],
        if (messages.isNotEmpty) ...[
          const SizedBox(height: 24),
          const ClientSectionHeader(title: 'Messages & help'),
          ClientPortalCard(
            padding: EdgeInsets.zero,
            child: Column(children: messages),
          ),
        ],
        const SizedBox(height: 24),
        const ClientSectionHeader(title: 'Account'),
        ClientPortalCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _MoreLink(
                icon: LucideIcons.settings,
                title: 'Settings',
                subtitle: 'Profile and preferences',
                onTap: () => context.go(RoutePaths.clientSettings),
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
    return 'Buying tools, applications, documents, and account.';
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
