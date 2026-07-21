import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/validators/email_validator.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/verification_models.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/verification_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Verification Center — status, resend, email/phone update, history, trust score.
class VerificationCenterPage extends HookConsumerWidget {
  const VerificationCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(verificationSnapshotProvider);
    final ui = ref.watch(verificationControllerProvider);
    final controller = ref.read(verificationControllerProvider.notifier);
    final events = useState<List<VerificationEvent>>(const []);
    final emailCtrl = useTextEditingController(text: snap.email ?? '');
    final fmt = DateFormat.yMMMd().add_jm();

    useEffect(() {
      Future.microtask(() async {
        events.value = await ref.read(verificationServiceProvider).listEvents();
      });
      return null;
    }, const []);

    return Scaffold(
      appBar: AppBar(title: const Text('Verification Center')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Text(
            'Trust score',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(
            value: snap.trustScore / TrustScoreFoundation.maxBaseScore,
            minHeight: 8,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            color: AppColors.gold,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('${snap.trustScore} / ${TrustScoreFoundation.maxBaseScore}'),
          const SizedBox(height: AppSpacing.xl),
          _StatusCard(
            title: 'Email',
            subtitle: snap.email ?? 'Not set',
            status: snap.emailVerified ? 'Verified' : 'Pending',
            icon: LucideIcons.mail,
            ok: snap.emailVerified,
            actions: [
              if (!snap.emailVerified && (snap.email?.isNotEmpty ?? false))
                TextButton(
                  onPressed: ui.emailCooldownSeconds > 0
                      ? null
                      : () => controller.resendEmail(snap.email!),
                  child: Text(
                    ui.emailCooldownSeconds > 0
                        ? 'Resend in ${ui.emailCooldownSeconds}s'
                        : 'Resend',
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          _StatusCard(
            title: 'Phone',
            subtitle: snap.phone ?? 'Not added',
            status: snap.phoneVerified
                ? 'Verified'
                : (snap.policy.phoneRequired ? 'Required' : 'Optional'),
            icon: LucideIcons.smartphone,
            ok: snap.phoneVerified,
            actions: [
              TextButton(
                onPressed: () => context.go(RoutePaths.verifyPhone),
                child: Text(snap.phoneVerified ? 'Update' : 'Verify phone'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Change email', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: emailCtrl,
            decoration: const InputDecoration(
              labelText: 'New email address',
              prefixIcon: Icon(LucideIcons.mail),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: EmailValidator.validate,
          ),
          const SizedBox(height: AppSpacing.sm),
          PrimaryButton(
            label: 'Request email change',
            expand: true,
            variant: ButtonVariant.secondary,
            onPressed: () async {
              final err = EmailValidator.validate(emailCtrl.text);
              if (err != null) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(err)));
                return;
              }
              await controller.requestEmailChange(emailCtrl.text.trim());
            },
          ),
          if (ui.message != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(ui.message!, style: const TextStyle(color: AppColors.gold)),
          ],
          if (ui.error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(ui.error!, style: const TextStyle(color: AppColors.error)),
          ],
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Security recommendations',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (!snap.emailVerified)
            const ListTile(
              leading: Icon(LucideIcons.shieldAlert, color: AppColors.warning),
              title: Text('Verify your email to unlock full account access.'),
            ),
          if (snap.policy.phoneRequired && !snap.phoneVerified)
            const ListTile(
              leading: Icon(LucideIcons.shieldAlert, color: AppColors.warning),
              title: Text('Phone verification is required for your role.'),
            ),
          if (snap.policy.mfaRecommended)
            const ListTile(
              leading: Icon(LucideIcons.shield, color: AppColors.info),
              title: Text('MFA is recommended for administrator accounts.'),
            ),
          if (snap.meetsPolicy)
            const ListTile(
              leading: Icon(LucideIcons.shieldCheck, color: AppColors.success),
              title: Text('Your verification meets current policy requirements.'),
            ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Verification history',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (events.value.isEmpty)
            const Text(
              'No verification events yet. History appears after the '
              'verification migration is applied.',
            ),
          ...events.value.map(
            (e) => ListTile(
              dense: true,
              leading: Icon(
                e.channel == VerificationChannel.phone
                    ? LucideIcons.smartphone
                    : LucideIcons.mail,
              ),
              title: Text(e.eventType),
              subtitle: Text(fmt.format(e.createdAt.toLocal())),
              trailing: Icon(
                e.success ? LucideIcons.check : LucideIcons.x,
                color: e.success ? AppColors.success : AppColors.error,
                size: 18,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextButton(
            onPressed: () => context.go(RoutePaths.activeSessions),
            child: const Text('Manage active sessions'),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.icon,
    required this.ok,
    this.actions = const [],
  });

  final String title;
  final String subtitle;
  final String status;
  final IconData icon;
  final bool ok;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: ok ? AppColors.success : AppColors.gold),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                      Text(subtitle),
                    ],
                  ),
                ),
                Chip(label: Text(status)),
              ],
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(children: actions),
            ],
          ],
        ),
      ),
    );
  }
}
