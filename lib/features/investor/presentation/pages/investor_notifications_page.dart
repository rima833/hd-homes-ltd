import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/offline_updates_note.dart';
import 'package:hdhomesproject/features/investor/domain/entities/investor_models.dart';
import 'package:hdhomesproject/features/investor/presentation/providers/investor_portal_realtime_provider.dart';
import 'package:hdhomesproject/features/investor/presentation/providers/investor_providers.dart';
import 'package:hdhomesproject/features/investor/presentation/widgets/investor_portal_widgets.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

class InvestorNotificationsPage extends ConsumerStatefulWidget {
  const InvestorNotificationsPage({super.key});

  @override
  ConsumerState<InvestorNotificationsPage> createState() =>
      _InvestorNotificationsPageState();
}

class _InvestorNotificationsPageState
    extends ConsumerState<InvestorNotificationsPage> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _unreadOnly = false;
  String? _categoryFilter;
  bool _markingAll = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  EdgeInsets _padding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return EdgeInsets.all(w >= AppBreakpoints.tablet ? 24 : 16);
  }

  List<InvestorPortalNotification> _filter(
    List<InvestorPortalNotification> items,
  ) {
    return items.where((n) {
      if (_unreadOnly && n.isRead) return false;
      if (_categoryFilter != null &&
          n.category.toLowerCase() != _categoryFilter) {
        return false;
      }
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return n.title.toLowerCase().contains(q) ||
          (n.body?.toLowerCase().contains(q) ?? false) ||
          n.categoryLabel.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _openNotification(InvestorPortalNotification n) async {
    try {
      if (!n.isRead) {
        await ref.read(investorServiceProvider).markNotificationRead(n.id);
        ref.invalidate(investorNotificationsProvider);
        ref.invalidate(investorUnreadCountProvider);
        ref.invalidate(investorDashboardProvider);
      }
      final route = n.portalRoute;
      if (route != null && mounted) {
        context.go(route);
      }
    } catch (e) {
      if (mounted) {
        showFriendlyError(
          context,
          e,
          fallback: 'Could not open notification.',
        );
      }
    }
  }

  Future<void> _markAllRead() async {
    if (_markingAll) return;
    setState(() => _markingAll = true);
    try {
      await ref.read(investorServiceProvider).markAllNotificationsRead();
      ref.invalidate(investorNotificationsProvider);
      ref.invalidate(investorUnreadCountProvider);
      ref.invalidate(investorDashboardProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read')),
        );
      }
    } catch (e) {
      if (mounted) {
        showFriendlyError(
          context,
          e,
          fallback: 'Could not update notifications.',
        );
      }
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(investorNotificationsProvider);
    ref.invalidate(investorUnreadCountProvider);
    await ref.read(investorNotificationsProvider.future);
  }

  IconData _iconFor(InvestorPortalNotification n) {
    switch (n.category) {
      case 'payments':
      case 'distribution':
      case 'dividend':
        return LucideIcons.wallet;
      case 'construction':
        return LucideIcons.hardHat;
      case 'documents':
      case 'document':
        return LucideIcons.fileText;
      case 'reports':
      case 'statement':
        return LucideIcons.barChart3;
      case 'kyc':
        return LucideIcons.badgeCheck;
      case 'announcement':
      case 'announcements':
        return LucideIcons.megaphone;
      case 'messages':
      case 'message':
      case 'support':
        return LucideIcons.messageSquare;
      case 'referrals':
        return LucideIcons.gift;
      default:
        return n.isRead ? LucideIcons.bell : LucideIcons.bellRing;
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(investorNotificationsProvider);
    final connection = ref.watch(investorRealtimeConnectionProvider);
    final live = connection == InvestorRealtimeConnection.live;
    final pad = _padding(context);
    final isWide = MediaQuery.sizeOf(context).width >= AppBreakpoints.tablet;

    return notificationsAsync.when(
      loading: () => const InvestorPageSkeleton(),
      error: (e, _) => InvestorErrorView(
        message: e,
        onRetry: _refresh,
      ),
      data: (items) {
        final filtered = _filter(items);
        final unreadCount = items.where((n) => !n.isRead).length;
        final categories = <String>{
          for (final n in items) n.category.toLowerCase(),
        }.toList()
          ..sort();

        return RefreshIndicator(
          color: AppColors.gold,
          onRefresh: _refresh,
          child: ListView(
            padding: pad,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notifications',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Portfolio, payout, and construction alerts — tap to open.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.slate400,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _LiveChip(live: live, connection: connection),
                  if (unreadCount > 0) ...[
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: _markingAll ? null : _markAllRead,
                      child: _markingAll
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(isWide ? 'Mark all read' : 'Mark all'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.go(RoutePaths.investorSettings),
                  icon: const Icon(LucideIcons.sliders, size: 16),
                  label: const Text('Notification preferences'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.gold),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InvestorKpiCard(
                      label: 'Total',
                      value: '${items.length}',
                      icon: LucideIcons.bell,
                      subtitle: 'All alerts',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InvestorKpiCard(
                      label: 'Unread',
                      value: '$unreadCount',
                      icon: LucideIcons.bellRing,
                      accent: unreadCount > 0
                          ? AppColors.warning
                          : AppColors.success,
                      subtitle:
                          unreadCount > 0 ? 'Needs attention' : 'Caught up',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                style: const TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  hintText: 'Search notifications',
                  hintStyle: TextStyle(
                    color: AppColors.slate400.withValues(alpha: 0.9),
                  ),
                  prefixIcon: const Icon(
                    LucideIcons.search,
                    color: AppColors.slate400,
                    size: 18,
                  ),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(LucideIcons.x, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.darkSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.neutral700.withValues(alpha: 0.5),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.neutral700.withValues(alpha: 0.5),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.gold),
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: Text('All (${items.length})'),
                    selected: !_unreadOnly && _categoryFilter == null,
                    selectedColor: AppColors.gold.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.gold,
                    labelStyle: TextStyle(
                      color: !_unreadOnly && _categoryFilter == null
                          ? AppColors.white
                          : AppColors.slate400,
                    ),
                    onSelected: (_) => setState(() {
                      _unreadOnly = false;
                      _categoryFilter = null;
                    }),
                  ),
                  FilterChip(
                    label: Text('Unread ($unreadCount)'),
                    selected: _unreadOnly,
                    selectedColor: AppColors.gold.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.gold,
                    labelStyle: TextStyle(
                      color: _unreadOnly ? AppColors.white : AppColors.slate400,
                    ),
                    onSelected: (v) => setState(() => _unreadOnly = v),
                  ),
                  for (final cat in categories)
                    FilterChip(
                      label: Text(_categoryLabel(cat)),
                      selected: _categoryFilter == cat,
                      selectedColor: AppColors.gold.withValues(alpha: 0.2),
                      checkmarkColor: AppColors.gold,
                      labelStyle: TextStyle(
                        color: _categoryFilter == cat
                            ? AppColors.white
                            : AppColors.slate400,
                      ),
                      onSelected: (v) => setState(
                        () => _categoryFilter = v ? cat : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                InvestorEmptyState(
                  title: items.isEmpty
                      ? 'No notifications yet'
                      : 'No matches',
                  message: items.isEmpty
                      ? 'Distribution, performance, and construction alerts will appear here live.'
                      : 'Try clearing search or showing all notifications.',
                  icon: LucideIcons.bell,
                  action: items.isEmpty
                      ? null
                      : TextButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _query = '';
                              _unreadOnly = false;
                              _categoryFilter = null;
                            });
                          },
                          child: const Text('Clear filters'),
                        ),
                )
              else
                ...filtered.map(
                  (n) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InvestorPortalCard(
                      onTap: () => _openNotification(n),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: (n.isRead
                                      ? AppColors.slate500
                                      : AppColors.gold)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _iconFor(n),
                              color: n.isRead
                                  ? AppColors.slate500
                                  : AppColors.gold,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        n.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              color: AppColors.white,
                                              fontWeight: n.isRead
                                                  ? FontWeight.w500
                                                  : FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    if (!n.isRead)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: AppColors.gold,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      n.categoryLabel,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AppColors.gold,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    if (n.portalRoute != null)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            LucideIcons.externalLink,
                                            size: 12,
                                            color: AppColors.slate400
                                                .withValues(alpha: 0.9),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Open',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: AppColors.slate400,
                                                ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                if (n.body != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    n.body!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppColors.slate400,
                                          height: 1.4,
                                        ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Text(
                                  DateFormat.yMMMd().add_jm().format(
                                        n.sentAt ??
                                            n.createdAt ??
                                            DateTime.now(),
                                      ),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: AppColors.slate500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  String _categoryLabel(String cat) {
    return InvestorPortalNotification(
      id: '_',
      title: '_',
      category: cat,
    ).categoryLabel;
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip({required this.live, required this.connection});

  final bool live;
  final InvestorRealtimeConnection connection;

  @override
  Widget build(BuildContext context) {
    if (live || connection == InvestorRealtimeConnection.connecting) {
      return const SizedBox.shrink();
    }
    return const OfflineUpdatesNote();
  }
}
