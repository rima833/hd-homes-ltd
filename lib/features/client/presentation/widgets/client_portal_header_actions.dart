import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/communication_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Header actions for the client dashboard (notifications + profile avatar).
class ClientPortalHeaderActions extends ConsumerWidget {
  const ClientPortalHeaderActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread =
        ref.watch(notificationCenterProvider).valueOrNull?.unreadCount ?? 0;
    final session = ref.watch(identitySessionProvider);
    final name = session.profile?.firstName ?? session.profile?.email ?? 'C';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final avatarUrl = session.profile?.avatarUrl;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(LucideIcons.bell, color: AppColors.white),
              tooltip: 'Notifications',
              onPressed: () => context.go(RoutePaths.clientNotifications),
            ),
            if (unread > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        GestureDetector(
          onTap: () => context.go(RoutePaths.clientSettings),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.gold.withValues(alpha: 0.15),
            backgroundImage:
                avatarUrl != null && avatarUrl.isNotEmpty
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
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
