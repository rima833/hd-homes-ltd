import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/auth/policies/admin_access_policy.dart';
import 'package:hdhomesproject/core/auth/policies/role_nav_policy.dart';
import 'package:hdhomesproject/core/layout/portal_shell.dart';
import 'package:hdhomesproject/core/navigation/nav_item.dart';
import 'package:hdhomesproject/core/navigation/navigation_config.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/communication_controller.dart';
import 'package:hdhomesproject/features/cshop/presentation/providers/cshop_controller.dart';
import 'package:hdhomesproject/features/crm/presentation/providers/crm_controller.dart';
import 'package:hdhomesproject/features/fapms/presentation/providers/fapms_controller.dart';
import 'package:lucide_icons/lucide_icons.dart';

final adminSidebarCollapsedProvider = StateProvider<bool>((ref) => false);

final adminPortalNavItemsProvider = Provider<List<NavItem>>((ref) {
  final session = ref.watch(identitySessionProvider);
  final base = AdminAccessPolicy.filterNavItems(
    NavigationConfig.adminNav,
    session,
  );
  final finance = ref.watch(fapmsSnapshotProvider).valueOrNull;
  final support = ref.watch(cshopSnapshotProvider).valueOrNull;
  final sales = ref.watch(crmSnapshotProvider).valueOrNull;

  final financeBadge = finance == null
      ? null
      : finance.pendingClientVerifications +
            finance.pendingInvestorIntents +
            finance.pendingApprovals.length;
  final supportBadge = support?.tickets
      .where((t) => t.status != 'resolved' && t.status != 'closed')
      .length;
  final liveChatBadge = support?.liveChats.length;
  const actionableAppStatuses = {
    'submitted',
    'under_review',
    'documents_required',
    'approved',
    'payment_pending',
    'payment_active',
    'contract_pending',
  };
  final applicationsBadge = sales?.applications
      .where((a) => actionableAppStatuses.contains(a.status))
      .length;

  return [
    for (final item in base)
      if (item.path == RoutePaths.dashboardFinance)
        item.copyWith(
          badge: financeBadge,
          clearBadge: financeBadge == null || financeBadge <= 0,
        )
      else if (item.path == RoutePaths.dashboardSupport)
        item.copyWith(
          badge: supportBadge,
          clearBadge: supportBadge == null || supportBadge <= 0,
        )
      else if (item.path == RoutePaths.dashboardLiveChat)
        item.copyWith(
          badge: liveChatBadge,
          clearBadge: liveChatBadge == null || liveChatBadge <= 0,
        )
      else if (item.path == RoutePaths.dashboardClientApplications)
        item.copyWith(
          badge: applicationsBadge,
          clearBadge: applicationsBadge == null || applicationsBadge <= 0,
        )
      else
        item,
  ];
});

class AdminPortalSidebarBrand extends ConsumerWidget {
  const AdminPortalSidebarBrand({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = RoleNavPolicy.brandLineFor(
      ref.watch(identitySessionProvider),
    );
    final logo = Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFE8B84A).withValues(alpha: 0.22),
            const Color(0xFF8A5A12).withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(color: const Color(0x66E8B84A)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE8B84A).withValues(alpha: 0.2),
            blurRadius: 14,
          ),
        ],
      ),
      child: Image.asset(
        AppTheme.logoAsset,
        height: compact ? 22 : 28,
        fit: BoxFit.contain,
        errorBuilder: (_, __, _) => const Text(
          'HD',
          style: TextStyle(
            color: Color(0xFFF6D889),
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
                  color: const Color(0xFFF6D889),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                brand,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xCCE8B84A),
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AdminPortalSidebarHelpCard extends StatelessWidget {
  const AdminPortalSidebarHelpCard({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Tooltip(
        message: 'Open Website',
        child: Center(
          child: InkWell(
            onTap: () => context.go(RoutePaths.home),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE0A830), Color(0xFF8A5A12)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE8B84A).withValues(alpha: 0.35),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: const Icon(
                LucideIcons.sparkles,
                color: Color(0xFF1A1208),
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
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8B84A), Color(0xFFC4892A), Color(0xFF7A4E14)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE8B84A).withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.sparkles,
                  color: Color(0xFF1A1208),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Go Live',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF1A1208),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Jump back to the public website with the latest admin changes.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF2A1C0A),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.go(RoutePaths.home),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1A1208),
                side: BorderSide(color: Colors.black.withValues(alpha: 0.35)),
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text('Open Website >'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact command-palette trigger for the admin top bar.
class _AdminCommandSearchTrigger extends StatelessWidget {
  const _AdminCommandSearchTrigger();

  @override
  Widget build(BuildContext context) {
    final isMac = Theme.of(context).platform == TargetPlatform.macOS;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => CommandPaletteScope.maybeOf(context)?.open(),
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          width: 220,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.22)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Icon(
                  LucideIcons.search,
                  size: 15,
                  color: AppColors.slate400.withValues(alpha: 0.95),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Search…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.slate400,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  isMac ? '⌘K' : 'Ctrl K',
                  style: TextStyle(
                    color: AppColors.slate400.withValues(alpha: 0.85),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdminPortalHeaderActions extends ConsumerWidget {
  const AdminPortalHeaderActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);
    final session = ref.watch(identitySessionProvider);
    final email = session.profile?.email;
    final firstName =
        session.profile?.firstName ??
        (email != null && email.isNotEmpty ? email.split('@').first : 'Admin');
    final initial = firstName.isNotEmpty ? firstName[0].toUpperCase() : 'A';
    final avatarUrl = session.profile?.avatarUrl;
    final wide = MediaQuery.sizeOf(context).width >= 1280;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (wide) ...[
          const _AdminCommandSearchTrigger(),
          const SizedBox(width: 14),
        ] else
          IconButton(
            tooltip: 'Search admin tools (Ctrl+K)',
            onPressed: () => CommandPaletteScope.maybeOf(context)?.open(),
            icon: const Icon(LucideIcons.search, color: AppColors.goldLight),
          ),
        if (wide)
          TextButton.icon(
            onPressed: () => context.go(RoutePaths.home),
            icon: const Icon(LucideIcons.globe2, size: 16),
            label: const Text('Website'),
            style: TextButton.styleFrom(foregroundColor: AppColors.goldLight),
          )
        else
          IconButton(
            onPressed: () => context.go(RoutePaths.home),
            tooltip: 'Website',
            icon: const Icon(LucideIcons.globe2, color: AppColors.goldLight),
          ),
        const SizedBox(width: 4),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(LucideIcons.bell, color: AppColors.white),
              tooltip: 'Notifications',
              onPressed: () => context.go(RoutePaths.dashboardSupport),
            ),
            if (unread > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
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
        PopupMenuButton<String>(
          tooltip: 'Account',
          color: AppColors.charcoal,
          offset: const Offset(0, 44),
          onSelected: (value) async {
            if (value == 'profile') {
              context.go(RoutePaths.dashboardProfile);
            } else if (value == 'logout') {
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) context.go(RoutePaths.login);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'profile', child: Text('Profile Center')),
            PopupMenuItem(
              value: 'logout',
              child: Text('Logout', style: TextStyle(color: AppColors.error)),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.only(left: 6, right: 8),
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
                            color: AppColors.goldLight,
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
                        firstName,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        RoleNavPolicy.workspaceLabelFor(session),
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(color: AppColors.gold),
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
