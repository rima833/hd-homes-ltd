import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/notification_models.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/communication_controller.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/client_portal_widgets.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ClientNotificationsPage extends ConsumerStatefulWidget {
  const ClientNotificationsPage({super.key});

  @override
  ConsumerState<ClientNotificationsPage> createState() =>
      _ClientNotificationsPageState();
}

class _ClientNotificationsPageState extends ConsumerState<ClientNotificationsPage> {
  final _searchController = TextEditingController();
  String _query = '';
  NotificationCategory? _categoryFilter;

  static const _categories = <(NotificationCategory?, String)>[
    (null, 'All'),
    (NotificationCategory.payments, 'Payments'),
    (NotificationCategory.properties, 'Properties'),
    (NotificationCategory.bookings, 'Bookings'),
    (NotificationCategory.support, 'Support'),
    (NotificationCategory.announcements, 'Announcements'),
    (NotificationCategory.marketing, 'Promotions'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  EdgeInsets _padding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return EdgeInsets.all(w >= AppBreakpoints.tablet ? 24 : 16);
  }

  List<AppNotification> _filter(List<AppNotification> items) {
    return items.where((n) {
      if (_categoryFilter != null && n.category != _categoryFilter) {
        return false;
      }
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return n.title.toLowerCase().contains(q) ||
          n.body.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final centerAsync = ref.watch(notificationCenterProvider);
    final controller = ref.read(communicationControllerProvider.notifier);

    return centerAsync.when(
      skipLoadingOnReload: true,
      loading: () => const ClientPageSkeleton(showKpis: false),
      error: (e, _) => ClientErrorView(
        message: e,
        onRetry: () => ref.invalidate(notificationCenterProvider),
      ),
      data: (snap) {
        if (snap == null) {
          return const ClientEmptyState(
            title: 'Sign in to view notifications',
            icon: LucideIcons.bell,
          );
        }

        final filtered = _filter(snap.items);

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(notificationCenterProvider),
          child: ListView(
            padding: _padding(context),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Notifications',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  if (snap.unreadCount > 0)
                    TextButton(
                      onPressed: controller.markAllRead,
                      child: Text('Mark all read (${snap.unreadCount})'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search notifications',
                  prefixIcon: const Icon(LucideIcons.search),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(LucideIcons.x),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final (category, label) = _categories[index];
                    final selected = _categoryFilter == category;
                    return FilterChip(
                      label: Text(label),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _categoryFilter = category),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                const ClientPortalCard(
                  child: Text('No notifications match your filters.'),
                )
              else
                ...filtered.map(
                  (n) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ClientPortalCard(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          n.isRead ? LucideIcons.bell : LucideIcons.bellRing,
                          color: n.isRead ? AppColors.slate400 : AppColors.gold,
                        ),
                        title: Text(
                          n.title,
                          style: TextStyle(
                            fontWeight:
                                n.isRead ? FontWeight.w400 : FontWeight.w700,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(n.body),
                            const SizedBox(height: 4),
                            Text(
                              '${n.category.label} · ${DateFormat.yMMMd().add_jm().format(n.createdAt.toLocal())}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: AppColors.slate400),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        onTap: () {
                          if (!n.isRead) controller.markRead(n.id);
                          if (n.actionUrl != null) context.go(n.actionUrl!);
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
