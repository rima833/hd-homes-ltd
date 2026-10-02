import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/layout/portal_shell.dart';
import 'package:hdhomesproject/core/navigation/nav_item.dart';
import 'package:hdhomesproject/core/navigation/navigation_config.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/core/widgets/offline_updates_note.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/communication_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/client/presentation/providers/client_portal_realtime_provider.dart';
import 'package:hdhomesproject/features/client/presentation/providers/client_providers.dart';
import 'package:hdhomesproject/features/settings/presentation/providers/platform_settings_providers.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// HD Homes Client Portal brand mark for the global sidebar.
class ClientPortalSidebarBrand extends StatelessWidget {
  const ClientPortalSidebarBrand({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final logo = Image.asset(
      AppTheme.logoAsset,
      height: compact ? 28 : 36,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Container(
        width: compact ? 28 : 36,
        height: compact ? 28 : 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'HD',
          style: TextStyle(
            color: AppColors.gold,
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
      ),
    );

    if (compact) return logo;

    return Row(
      children: [
        logo,
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HD HOMES',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
              ),
              Text(
                'CLIENT PORTAL',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.slate400,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bottom sidebar help CTA matching the mockup.
class ClientPortalSidebarHelpCard extends StatelessWidget {
  const ClientPortalSidebarHelpCard({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Tooltip(
        message: 'Need Help?',
        child: Center(
          child: InkWell(
            onTap: () => context.go(RoutePaths.clientSupport),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.35),
                ),
              ),
              child: const Icon(
                LucideIcons.headphones,
                color: AppColors.gold,
                size: 20,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.headphones,
                  color: AppColors.gold,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Need Help?',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Open a ticket or chat on Messages.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.slate400,
                ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.go(RoutePaths.clientSupport),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.gold,
                side: const BorderSide(color: AppColors.gold),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text('Open a ticket >'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Collapsed/expanded rail state — survives client shell rebuilds.
final clientSidebarCollapsedProvider = StateProvider<bool>((ref) => false);

/// Live sidebar items with unread badges for the client portal.
final clientPortalNavItemsProvider = Provider<List<NavItem>>((ref) {
  final flags = ref.watch(clientPortalFeatureFlagsProvider);
  final conversations =
      ref.watch(clientConversationsProvider).valueOrNull ?? const [];
  final unreadMessages =
      conversations.fold<int>(0, (sum, conversation) => sum + conversation.unreadCount);
  final unreadNotifications =
      ref.watch(notificationCenterProvider).valueOrNull?.unreadCount ?? 0;

  final badged = [
    for (final item in NavigationConfig.clientNav)
      if (item.path == RoutePaths.clientMessages)
        item.copyWith(
          badge: unreadMessages,
          clearBadge: unreadMessages <= 0,
        )
      else if (item.path == RoutePaths.clientNotifications)
        item.copyWith(
          badge: unreadNotifications,
          clearBadge: unreadNotifications <= 0,
        )
      else
        item,
  ];
  return flags.filterNav(badged);
});

/// Bottom bar items filtered by portal feature flags.
final clientPortalBottomNavItemsProvider = Provider<List<NavItem>>((ref) {
  final flags = ref.watch(clientPortalFeatureFlagsProvider);
  if (!flags.enabled) {
    return [
      for (final item in NavigationConfig.clientBottomNav)
        if (item.path == RoutePaths.client ||
            item.path == RoutePaths.clientMore)
          item,
    ];
  }
  return [
    for (final item in NavigationConfig.clientBottomNav)
      if (flags.allowsPath(item.path)) item,
  ];
});

/// Global client portal header: search field + notifications + greeting chip.
class ClientPortalGlobalHeaderActions extends ConsumerWidget {
  const ClientPortalGlobalHeaderActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread =
        ref.watch(notificationCenterProvider).valueOrNull?.unreadCount ?? 0;
    final session = ref.watch(identitySessionProvider);
    final client = ref.watch(clientRecordProvider).valueOrNull;
    final connection = ref.watch(clientRealtimeConnectionProvider);
    final firstName = session.profile?.firstName ??
        session.profile?.email.split('@').first ??
        'Client';
    final initial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';
    final clientCode = client?.clientCode ??
        (client != null
            ? 'CLT-${client.id.substring(0, 8).toUpperCase()}'
            : null);
    final avatarUrl = session.profile?.avatarUrl;
    final wide = MediaQuery.sizeOf(context).width >= 1200;

    ref.listen<String?>(clientRealtimeEventProvider, (previous, next) {
      if (next == null || next.isEmpty || next == previous) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(next),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          backgroundColor: AppColors.darkSurface,
        ),
      );
    });

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (connection == ClientRealtimeConnection.error ||
            connection == ClientRealtimeConnection.offline)
          const Padding(
            padding: EdgeInsets.only(right: 10),
            child: SizedBox(
              width: 220,
              child: OfflineUpdatesNote(color: Colors.white70),
            ),
          ),
        if (wide) ...[
          SizedBox(
            width: 280,
            child: TextField(
              readOnly: true,
              onTap: () => CommandPaletteScope.maybeOf(context)?.open(),
              decoration: InputDecoration(
                hintText: 'Search anything...',
                hintStyle: TextStyle(
                  color: AppColors.slate400.withValues(alpha: 0.9),
                ),
                prefixIcon: const Icon(
                  LucideIcons.search,
                  color: AppColors.slate400,
                  size: 18,
                ),
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.neutral800,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '⌘K',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.slate400,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                ),
                filled: true,
                fillColor: AppColors.darkSurface,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: AppColors.neutral700.withValues(alpha: 0.5),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: AppColors.neutral700.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ] else ...[
          IconButton(
            tooltip: 'Search anything (Ctrl+K)',
            onPressed: () => CommandPaletteScope.maybeOf(context)?.open(),
            icon: const Icon(LucideIcons.search, color: AppColors.goldLight),
          ),
          const SizedBox(width: 4),
        ],
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(LucideIcons.bell, color: AppColors.white),
              tooltip: unread > 0
                  ? 'Notifications, $unread unread'
                  : 'Notifications',
              onPressed: () => context.go(RoutePaths.clientNotifications),
            ),
            if (unread > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(
                      color: AppColors.charcoal,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 4),
        PopupMenuButton<String>(
          tooltip: 'Account',
          offset: const Offset(0, 44),
          color: AppColors.charcoal,
          onSelected: (value) async {
            if (value == 'settings') {
              context.go(RoutePaths.clientSettings);
            } else if (value == 'logout') {
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) context.go(RoutePaths.login);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'settings', child: Text('Profile Settings')),
            PopupMenuItem(
              value: 'logout',
              child: Text('Logout', style: TextStyle(color: AppColors.error)),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? Text(
                          initial,
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
                if (wide) ...[
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Hello, $firstName',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (clientCode != null)
                        Text(
                          clientCode,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.gold,
                                  ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    LucideIcons.chevronDown,
                    size: 16,
                    color: AppColors.slate400,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
