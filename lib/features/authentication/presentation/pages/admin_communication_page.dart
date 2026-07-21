import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/notification_models.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/communication_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Admin Communication Center — announcements, templates catalog, publish tools.
class AdminCommunicationPage extends HookConsumerWidget {
  const AdminCommunicationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(communicationControllerProvider);
    final controller = ref.read(communicationControllerProvider.notifier);
    final title = useTextEditingController();
    final body = useTextEditingController();
    final audience = useState('everyone');
    final announcements = useState<List<AnnouncementPost>>(const []);

    useEffect(() {
      Future.microtask(() async {
        final list =
            await ref.read(communicationServiceProvider).listAnnouncements();
        announcements.value = list;
      });
      return null;
    }, const []);

    return Scaffold(
      appBar: AppBar(title: const Text('Communication Center')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          if (ui.message != null)
            Text(ui.message!, style: const TextStyle(color: AppColors.success)),
          if (ui.error != null)
            Text(ui.error!, style: const TextStyle(color: AppColors.error)),
          Text('Publish announcement', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: title,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: body,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Body'),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: audience.value,
            decoration: const InputDecoration(labelText: 'Audience'),
            items: const [
              DropdownMenuItem(value: 'everyone', child: Text('Everyone')),
              DropdownMenuItem(value: 'clients', child: Text('Clients')),
              DropdownMenuItem(value: 'investors', child: Text('Investors')),
              DropdownMenuItem(value: 'staff', child: Text('Staff')),
            ],
            onChanged: (v) {
              if (v != null) audience.value = v;
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Publish',
            expand: true,
            isLoading: ui.isBusy,
            icon: LucideIcons.megaphone,
            onPressed: ui.isBusy
                ? null
                : () async {
                    await controller.publishAnnouncement(
                      title: title.text.trim(),
                      body: body.text.trim(),
                      audience: audience.value,
                    );
                    final list = await ref
                        .read(communicationServiceProvider)
                        .listAnnouncements();
                    announcements.value = list;
                    title.clear();
                    body.clear();
                  },
          ),
          const Divider(height: AppSpacing.xxl),
          Text('Template catalog', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          const ListTile(
            dense: true,
            title: Text('welcome'),
            subtitle: Text('Account · in-app + email'),
          ),
          const ListTile(
            dense: true,
            title: Text('kyc_approved'),
            subtitle: Text('KYC · success'),
          ),
          const ListTile(
            dense: true,
            title: Text('security_alert'),
            subtitle: Text('Security · critical · multi-channel'),
          ),
          const ListTile(
            dense: true,
            title: Text('booking_confirmed'),
            subtitle: Text('Bookings'),
          ),
          const ListTile(
            dense: true,
            title: Text('payment_successful'),
            subtitle: Text('Payments'),
          ),
          const ListTile(
            dense: true,
            title: Text('announcement'),
            subtitle: Text('Announcements'),
          ),
          const Divider(height: AppSpacing.xxl),
          Text('Recent announcements', style: Theme.of(context).textTheme.titleMedium),
          if (announcements.value.isEmpty)
            const Text('No published announcements yet.')
          else
            ...announcements.value.map(
              (a) => ListTile(
                leading: const Icon(LucideIcons.megaphone),
                title: Text(a.title),
                subtitle: Text('${a.targetAudience} · ${a.publishedAt?.toLocal() ?? a.createdAt.toLocal()}'),
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
          const Text(
            'Phase 1: in-app delivery + delivery queue rows for email/SMS. '
            'Provider adapters (SendGrid, Termii, FCM) plug into notification_delivery.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
