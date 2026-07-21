import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/notification_models.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/communication_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Centralized Notification Center — in-app inbox for all roles.
class NotificationCenterPage extends HookConsumerWidget {
  const NotificationCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final centerAsync = ref.watch(notificationCenterProvider);
    final ui = ref.watch(communicationControllerProvider);
    final controller = ref.read(communicationControllerProvider.notifier);
    final showPrefs = useState(false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Center'),
        actions: [
          IconButton(
            tooltip: 'Preferences',
            icon: const Icon(LucideIcons.settings2),
            onPressed: () => showPrefs.value = !showPrefs.value,
          ),
          IconButton(
            tooltip: 'Mark all read',
            icon: const Icon(LucideIcons.checkCheck),
            onPressed: controller.markAllRead,
          ),
        ],
      ),
      body: centerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Unable to load notifications: $e')),
        data: (snap) {
          if (snap == null) {
            return const Center(child: Text('Sign in to view notifications.'));
          }
          final filtered = ui.filter == null
              ? snap.items
              : snap.items.where((n) => n.category == ui.filter).toList();

          return Column(
            children: [
              if (ui.message != null)
                MaterialBanner(
                  content: Text(ui.message!),
                  actions: [
                    TextButton(
                      onPressed: () => controller.setFilter(ui.filter),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  0,
                ),
                child: Row(
                  children: [
                    Text(
                      '${snap.unreadCount} unread',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.go(RoutePaths.profileCenter),
                      child: const Text('Profile prefs'),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: const Text('All'),
                        selected: ui.filter == null,
                        onSelected: (_) => controller.setFilter(null),
                      ),
                    ),
                    ...NotificationCategory.values.map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(c.label),
                          selected: ui.filter == c,
                          onSelected: (_) => controller.setFilter(c),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (showPrefs.value)
                Expanded(child: _PrefsPanel(prefs: snap.prefs))
              else
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No notifications yet.'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final n = filtered[index];
                            return _NotificationTile(notification: n);
                          },
                        ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(communicationControllerProvider.notifier);
    final n = notification;
    return ListTile(
      leading: Icon(
        switch (n.type) {
          NotificationType.success => LucideIcons.checkCircle2,
          NotificationType.warning => LucideIcons.alertTriangle,
          NotificationType.error || NotificationType.critical => LucideIcons.shieldAlert,
          NotificationType.announcement => LucideIcons.megaphone,
          NotificationType.actionRequired => LucideIcons.bellRing,
          _ => LucideIcons.bell,
        },
        color: n.isRead ? AppColors.gray : AppColors.gold,
      ),
      title: Text(
        n.title,
        style: TextStyle(fontWeight: n.isRead ? FontWeight.w400 : FontWeight.w700),
      ),
      subtitle: Text(
        '${n.body}\n${n.category.label} · ${n.createdAt.toLocal()}',
      ),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'read':
              controller.markRead(n.id);
            case 'pin':
              controller.togglePin(n.id, !n.isPinned);
            case 'archive':
              controller.archive(n.id);
            case 'delete':
              controller.delete(n.id);
            case 'open':
              if (n.actionUrl != null) context.go(n.actionUrl!);
          }
        },
        itemBuilder: (_) => [
          if (!n.isRead)
            const PopupMenuItem(value: 'read', child: Text('Mark read')),
          PopupMenuItem(
            value: 'pin',
            child: Text(n.isPinned ? 'Unpin' : 'Pin'),
          ),
          const PopupMenuItem(value: 'archive', child: Text('Archive')),
          if (n.actionUrl != null)
            const PopupMenuItem(value: 'open', child: Text('Open')),
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
      onTap: () {
        if (!n.isRead) controller.markRead(n.id);
        if (n.actionUrl != null) context.go(n.actionUrl!);
      },
    );
  }
}

class _PrefsPanel extends HookConsumerWidget {
  const _PrefsPanel({required this.prefs});

  final CommunicationChannelPrefs prefs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = useState(prefs);
    final quiet = useState(prefs.quietHours.enabled);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Text('Channel preferences', style: Theme.of(context).textTheme.titleLarge),
        SwitchListTile(
          title: const Text('In-app'),
          value: state.value.inApp,
          onChanged: (v) => state.value = state.value.copyWith(inApp: v),
        ),
        SwitchListTile(
          title: const Text('Email'),
          value: state.value.email,
          onChanged: (v) => state.value = state.value.copyWith(email: v),
        ),
        SwitchListTile(
          title: const Text('SMS'),
          value: state.value.sms,
          onChanged: (v) => state.value = state.value.copyWith(sms: v),
        ),
        SwitchListTile(
          title: const Text('WhatsApp (soon)'),
          value: state.value.whatsapp,
          onChanged: (v) => state.value = state.value.copyWith(whatsapp: v),
        ),
        SwitchListTile(
          title: const Text('Push (soon)'),
          value: state.value.push,
          onChanged: (v) => state.value = state.value.copyWith(push: v),
        ),
        SwitchListTile(
          title: const Text('Marketing'),
          value: state.value.marketing,
          onChanged: (v) => state.value = state.value.copyWith(marketing: v),
        ),
        SwitchListTile(
          title: const Text('Security alerts'),
          value: state.value.securityAlerts,
          onChanged: (v) => state.value = state.value.copyWith(securityAlerts: v),
        ),
        SwitchListTile(
          title: const Text('Quiet hours (22:00–07:00)'),
          subtitle: const Text('Critical alerts may still deliver'),
          value: quiet.value,
          onChanged: (v) {
            quiet.value = v;
            state.value = state.value.copyWith(
              quietHours: QuietHours(enabled: v),
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Save preferences',
          expand: true,
          onPressed: () =>
              ref.read(communicationControllerProvider.notifier).savePrefs(state.value),
        ),
      ],
    );
  }
}
