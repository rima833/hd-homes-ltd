import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/notification_models.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/communication_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';

abstract final class _T {
  static const bg = Color(0xFF0B0C0E);
  static const surface = Color(0xFF14161A);
  static const elevated = Color(0xFF1A1D24);
  static const border = Color(0x22FFFFFF);
  static const muted = Color(0x99FFFFFF);
  static const gold = AppColors.primaryGold;
}

/// Admin Communication Center — realtime broadcasts to all portals.
class AdminCommunicationPage extends HookConsumerWidget {
  const AdminCommunicationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(adminAnnouncementsRealtimeProvider);
    final ui = ref.watch(communicationControllerProvider);
    final controller = ref.read(communicationControllerProvider.notifier);
    final posts = ref.watch(adminAnnouncementsProvider);
    final stats = ref.watch(adminCommunicationStatsProvider);
    final title = useTextEditingController();
    final body = useTextEditingController();
    final audience = useState('everyone');
    final surfacePublic = useState(true);
    final queueEmail = useState(false);

    ref.listen(communicationControllerProvider, (prev, next) {
      if (next.message != null && next.message != prev?.message && !next.isBusy) {
        title.clear();
        body.clear();
      }
    });

    return Scaffold(
      backgroundColor: _T.bg,
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _T.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _T.gold.withValues(alpha: 0.35)),
                ),
                child: const Icon(LucideIcons.radio, color: _T.gold),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Communication Center',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: context.isMobile ? 26 : 32,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      'Broadcast to public site, staff, clients, and investors in real time.',
                      style: TextStyle(color: _T.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          stats.when(
            data: (s) => Row(
              children: [
                _Stat('Published', '${s.publishedCount}', LucideIcons.megaphone),
                const SizedBox(width: 10),
                _Stat('Reached', '${s.totalRecipients}', LucideIcons.send),
                const SizedBox(width: 10),
                _Stat(
                  'Last',
                  s.lastPublishedAt == null
                      ? '—'
                      : DateFormat('d MMM HH:mm').format(s.lastPublishedAt!.toLocal()),
                  LucideIcons.clock,
                ),
              ],
            ),
            loading: () => const SizedBox(height: 72),
            error: (_, __) => const SizedBox.shrink(),
          ),
          if (ui.message != null) ...[
            const SizedBox(height: 12),
            _Alert(text: ui.message!, ok: true),
          ],
          if (ui.error != null) ...[
            const SizedBox(height: 12),
            _Alert(text: ui.error!, ok: false),
          ],
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 1100;
              final compose = _Compose(
                title: title,
                body: body,
                audience: audience.value,
                onAudience: (v) => audience.value = v,
                surfacePublic: surfacePublic.value,
                onSurfacePublic: (v) => surfacePublic.value = v,
                queueEmail: queueEmail.value,
                onQueueEmail: (v) => queueEmail.value = v,
                busy: ui.isBusy,
                onPublish: () => controller.publishAnnouncement(
                  title: title.text,
                  body: body.text,
                  audience: audience.value,
                  surfacePublicSite: surfacePublic.value,
                  queueEmail: queueEmail.value,
                ),
              );
              final feed = _Feed(posts: posts);
              if (!wide) return Column(children: [compose, const SizedBox(height: 16), feed]);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: compose),
                  const SizedBox(width: 16),
                  Expanded(child: feed),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _T.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _T.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: _T.gold),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: _T.muted, fontSize: 11)),
                  Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
      );
}

class _Alert extends StatelessWidget {
  const _Alert({required this.text, required this.ok});
  final String text;
  final bool ok;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (ok ? AppColors.success : AppColors.error).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text, style: TextStyle(color: ok ? AppColors.success : AppColors.error)),
      );
}

class _Compose extends StatelessWidget {
  const _Compose({
    required this.title,
    required this.body,
    required this.audience,
    required this.onAudience,
    required this.surfacePublic,
    required this.onSurfacePublic,
    required this.queueEmail,
    required this.onQueueEmail,
    required this.busy,
    required this.onPublish,
  });
  final TextEditingController title;
  final TextEditingController body;
  final String audience;
  final ValueChanged<String> onAudience;
  final bool surfacePublic;
  final ValueChanged<bool> onSurfacePublic;
  final bool queueEmail;
  final ValueChanged<bool> onQueueEmail;
  final bool busy;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _T.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Compose broadcast', style: GoogleFonts.playfairDisplay(fontSize: 22, color: Colors.white)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: [
              for (final o in const [
                ('everyone', 'Everyone'),
                ('clients', 'Clients'),
                ('investors', 'Investors'),
                ('staff', 'Staff'),
              ])
                ChoiceChip(
                  label: Text(o.$2),
                  selected: audience == o.$1,
                  onSelected: (_) => onAudience(o.$1),
                  selectedColor: _T.gold.withValues(alpha: 0.25),
                  labelStyle: TextStyle(color: audience == o.$1 ? _T.gold : Colors.white),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: title,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Headline', filled: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: body,
            maxLines: 5,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Message', filled: true),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show on public website', style: TextStyle(color: Colors.white)),
            value: surfacePublic && audience == 'everyone',
            onChanged: audience == 'everyone' ? onSurfacePublic : null,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Queue email delivery', style: TextStyle(color: Colors.white)),
            value: queueEmail,
            onChanged: onQueueEmail,
          ),
          PrimaryButton(
            label: 'Publish broadcast',
            expand: true,
            isLoading: busy,
            icon: LucideIcons.send,
            onPressed: busy ? null : onPublish,
          ),
        ],
      ),
    );
  }
}

class _Feed extends StatelessWidget {
  const _Feed({required this.posts});
  final AsyncValue<List<AnnouncementPost>> posts;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _T.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Live feed', style: GoogleFonts.playfairDisplay(fontSize: 22, color: Colors.white)),
              const Spacer(),
              const Text('Realtime', style: TextStyle(color: AppColors.success, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          posts.when(
            loading: () => const Center(child: CircularProgressIndicator(color: _T.gold)),
            error: (e, _) => Text(userFacingError(e), style: const TextStyle(color: AppColors.error)),
            data: (list) {
              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text('No broadcasts yet.', textAlign: TextAlign.center, style: TextStyle(color: _T.muted)),
                );
              }
              return Column(
                children: [
                  for (final p in list) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _T.elevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _T.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(p.audienceLabel, style: const TextStyle(color: _T.gold, fontSize: 11)),
                              if (p.surfacesPublicSite) const Text(' · Public', style: TextStyle(color: _T.muted, fontSize: 11)),
                              const Spacer(),
                              Text(
                                DateFormat('d MMM HH:mm').format((p.publishedAt ?? p.createdAt).toLocal()),
                                style: const TextStyle(color: _T.muted, fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(p.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(p.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _T.muted)),
                          const SizedBox(height: 6),
                          Text(
                            '${p.inAppCount} in-app · ${p.investorInboxCount} investor',
                            style: const TextStyle(color: _T.muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
