import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/login_models.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Active session management — view / revoke sessions across devices.
class ActiveSessionsPage extends HookConsumerWidget {
  const ActiveSessionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = useState<List<ActiveSession>?>(null);
    final loading = useState(true);
    final error = useState<String?>(null);
    final fmt = DateFormat.yMMMd().add_jm();

    Future<void> load() async {
      loading.value = true;
      error.value = null;
      final repo = ref.read(sessionRepositoryProvider);
      if (repo == null) {
        sessions.value = const [];
        loading.value = false;
        error.value = 'Sessions unavailable until you are signed in.';
        return;
      }
      try {
        sessions.value = await repo.listSessions();
      } catch (_) {
        error.value = 'Unable to load sessions.';
        sessions.value = const [];
      } finally {
        loading.value = false;
      }
    }

    useEffect(() {
      Future.microtask(load);
      return null;
    }, const []);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active sessions'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: loading.value ? null : load,
            icon: const Icon(LucideIcons.refreshCw),
          ),
        ],
      ),
      body: loading.value
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: [
                  Text(
                    'Manage where you are signed in. Ending a session signs that device out.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (error.value != null) ...[
                    const SizedBox(height: AppSpacing.base),
                    Text(error.value!, style: const TextStyle(color: AppColors.error)),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  ...(sessions.value ?? const []).map((s) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        leading: Icon(
                          s.isCurrent ? LucideIcons.monitorSmartphone : LucideIcons.monitor,
                          color: s.isCurrent ? AppColors.gold : null,
                        ),
                        title: Text(
                          s.isCurrent
                              ? 'This device'
                              : (s.userAgent ?? 'Unknown device'),
                        ),
                        subtitle: Text(
                          'Started ${fmt.format(s.startedAt.toLocal())}\n'
                          'Last active ${fmt.format(s.lastSeenAt.toLocal())}'
                          '${s.isActive ? '' : ' · Ended'}',
                        ),
                        isThreeLine: true,
                        trailing: s.isCurrent || !s.isActive
                            ? null
                            : IconButton(
                                tooltip: 'End session',
                                icon: const Icon(LucideIcons.logOut),
                                onPressed: () async {
                                  await ref
                                      .read(sessionRepositoryProvider)
                                      ?.revokeSession(s.id);
                                  await load();
                                },
                              ),
                      ),
                    );
                  }),
                  if ((sessions.value ?? const []).isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: Text(
                        'No tracked sessions yet. Sessions appear after the '
                        'login security migration is applied and you sign in again.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: 'Sign out everywhere',
                    variant: ButtonVariant.secondary,
                    expand: true,
                    icon: LucideIcons.shieldOff,
                    onPressed: () async {
                      await ref
                          .read(authControllerProvider.notifier)
                          .signOut(everywhere: true);
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
