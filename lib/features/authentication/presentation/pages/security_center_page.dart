import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/account_security_models.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/login_models.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/account_security_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/mfa_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/verification_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/auth_password_field.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/otp_code_input.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/password_strength_meter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Account Security Center — password, sessions, devices, health score, MFA.
class SecurityCenterPage extends HookConsumerWidget {
  const SecurityCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(securityHealthProvider);
    final readiness = ref.watch(securityReadinessProvider);
    final verification = ref.watch(verificationSnapshotProvider);
    final ui = ref.watch(accountSecurityControllerProvider);
    final controller = ref.read(accountSecurityControllerProvider.notifier);
    final security = ref.watch(securityServiceProvider);
    final mfaAsync = ref.watch(mfaStatusProvider);
    final mfaUi = ref.watch(mfaControllerProvider);
    final mfaController = ref.read(mfaControllerProvider.notifier);

    final currentPw = useTextEditingController();
    final newPw = useTextEditingController();
    final confirmPw = useTextEditingController();
    final newPasswordValue = useState('');
    final revokeOthers = useState(true);
    final sessions = useState<List<ActiveSession>>(const []);
    final showDisableMfa = useState(false);
    final formKey = useMemoized(GlobalKey<FormState>.new);

    useEffect(() {
      void listener() => newPasswordValue.value = newPw.text;
      newPw.addListener(listener);
      return () => newPw.removeListener(listener);
    }, [newPw]);

    useEffect(() {
      Future.microtask(() async {
        final list = await ref.read(sessionRepositoryProvider)?.listSessions();
        sessions.value = list ?? const [];
      });
      return null;
    }, const []);

    final policy = PasswordPolicy.standard;

    return Scaffold(
      appBar: AppBar(title: const Text('Security Center')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Text('Security Health', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(
            value: readiness / 100,
            minHeight: 10,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            color: AppColors.gold,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('Readiness $readiness / 100 · Base health ${health.score}'),
          const SizedBox(height: AppSpacing.base),
          ...health.recommendations.map(
            (r) => ListTile(
              dense: true,
              leading: const Icon(LucideIcons.shield, color: AppColors.gold),
              title: Text(r),
            ),
          ),
          const Divider(height: AppSpacing.xxl),
          Text('Status', style: Theme.of(context).textTheme.titleMedium),
          ListTile(
            leading: Icon(
              verification.emailVerified ? LucideIcons.badgeCheck : LucideIcons.mail,
              color: verification.emailVerified ? AppColors.success : AppColors.warning,
            ),
            title: const Text('Email verification'),
            subtitle: Text(verification.emailVerified ? 'Verified' : 'Pending'),
            trailing: TextButton(
              onPressed: () => context.go(RoutePaths.verificationCenter),
              child: const Text('Manage'),
            ),
          ),
          ListTile(
            leading: Icon(
              verification.phoneVerified ? LucideIcons.badgeCheck : LucideIcons.smartphone,
              color: verification.phoneVerified ? AppColors.success : AppColors.warning,
            ),
            title: const Text('Phone verification'),
            subtitle: Text(verification.phoneVerified ? 'Verified' : 'Not verified'),
            trailing: TextButton(
              onPressed: () => context.go(RoutePaths.verifyPhone),
              child: const Text('Manage'),
            ),
          ),
          mfaAsync.when(
            loading: () => const ListTile(
              leading: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              title: Text('Multi-factor authentication'),
              subtitle: Text('Loading…'),
            ),
            error: (_, _) => ListTile(
              leading: const Icon(LucideIcons.shieldOff, color: AppColors.warning),
              title: const Text('Multi-factor authentication'),
              subtitle: const Text('Unable to load MFA status'),
              trailing: TextButton(
                onPressed: () => context.go(RoutePaths.mfaSetup),
                child: const Text('Set up'),
              ),
            ),
            data: (mfa) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  leading: Icon(
                    mfa.enabled ? LucideIcons.shieldCheck : LucideIcons.shieldOff,
                    color: mfa.enabled ? AppColors.success : AppColors.warning,
                  ),
                  title: const Text('Multi-factor authentication'),
                  subtitle: Text(
                    mfa.enabled
                        ? 'Enabled · ${mfa.backupCodesRemaining} backup codes left'
                        : mfa.needsSetup
                            ? 'Required for your role — enable now'
                            : 'Not enabled · ${mfa.policy.requirement.name}',
                  ),
                  trailing: mfa.enabled
                      ? TextButton(
                          onPressed: () => showDisableMfa.value = !showDisableMfa.value,
                          child: Text(showDisableMfa.value ? 'Cancel' : 'Disable'),
                        )
                      : TextButton(
                          onPressed: () => context.go(RoutePaths.mfaSetup),
                          child: const Text('Enable'),
                        ),
                ),
                if (mfa.enabled) ...[
                  ListTile(
                    dense: true,
                    leading: const Icon(LucideIcons.keyRound, size: 20),
                    title: const Text('Regenerate backup codes'),
                    trailing: TextButton(
                      onPressed: mfaUi.isBusy
                          ? null
                          : () async {
                              await mfaController.regenerateBackupCodes();
                              final codes =
                                  ref.read(mfaControllerProvider).backupCodes;
                              if (context.mounted && codes != null) {
                                await showDialog<void>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('New backup codes'),
                                    content: SingleChildScrollView(
                                      child: SelectableText(codes.codes.join('\n')),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Done'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            },
                      child: const Text('Regenerate'),
                    ),
                  ),
                  ListTile(
                    dense: true,
                    leading: const Icon(LucideIcons.monitorSmartphone, size: 20),
                    title: Text('Trusted devices (${mfa.trustedDeviceCount})'),
                    subtitle: const Text('Manage MFA device trust'),
                    trailing: TextButton(
                      onPressed: () async {
                        final devices =
                            await ref.read(mfaServiceProvider).listTrustedDevices();
                        if (!context.mounted) return;
                        await showModalBottomSheet<void>(
                          context: context,
                          builder: (ctx) => ListView(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            children: [
                              Text(
                                'Trusted devices',
                                style: Theme.of(ctx).textTheme.titleMedium,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              if (devices.isEmpty)
                                const Text('No trusted devices yet.')
                              else
                                ...devices.map(
                                  (d) => ListTile(
                                    title: Text(
                                      d.isCurrent
                                          ? 'This device'
                                          : (d.deviceName ?? 'Device'),
                                    ),
                                    subtitle: Text(
                                      [
                                        if (d.browser != null) d.browser,
                                        if (d.operatingSystem != null)
                                          d.operatingSystem,
                                        if (d.trustedUntil != null)
                                          'Until ${d.trustedUntil!.toLocal()}',
                                      ].whereType<String>().join(' · '),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(LucideIcons.trash2),
                                      onPressed: () async {
                                        await ref
                                            .read(mfaServiceProvider)
                                            .revokeTrustedDevice(d.id);
                                        ref.invalidate(mfaStatusProvider);
                                        if (ctx.mounted) Navigator.pop(ctx);
                                      },
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                      child: const Text('View'),
                    ),
                  ),
                ],
                if (showDisableMfa.value && mfa.enabled) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.base),
                    child: Text('Enter your authenticator code to disable MFA.'),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.base),
                    child: OtpCodeInput(
                      enabled: !mfaUi.isBusy,
                      onCompleted: (code) async {
                        final ok = await mfaController.disableMfa(code);
                        if (ok) showDisableMfa.value = false;
                      },
                    ),
                  ),
                  if (mfaUi.error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
                      child: Text(
                        mfaUi.error!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                ],
              ],
            ),
          ),
          const Divider(height: AppSpacing.xxl),
          Text('Change password', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthPasswordField(
                  controller: currentPw,
                  label: 'Current password',
                  autofillHints: const [AutofillHints.password],
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Current password is required' : null,
                ),
                const SizedBox(height: AppSpacing.base),
                AuthPasswordField(
                  controller: newPw,
                  label: 'New password',
                  autofillHints: const [AutofillHints.newPassword],
                  validator: policy.validate,
                ),
                const SizedBox(height: AppSpacing.sm),
                PasswordStrengthMeter(password: newPasswordValue.value),
                const SizedBox(height: AppSpacing.base),
                AuthPasswordField(
                  controller: confirmPw,
                  label: 'Confirm new password',
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please confirm your password';
                    if (v != newPw.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sign out other devices'),
                  value: revokeOthers.value,
                  onChanged: (v) => revokeOthers.value = v,
                ),
                if (ui.error != null)
                  Text(ui.error!, style: const TextStyle(color: AppColors.error)),
                if (ui.message != null)
                  Text(ui.message!, style: const TextStyle(color: AppColors.success)),
                const SizedBox(height: AppSpacing.sm),
                PrimaryButton(
                  label: 'Update password',
                  expand: true,
                  isLoading: ui.isSubmitting,
                  onPressed: ui.isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          await controller.changePassword(
                            currentPassword: currentPw.text,
                            newPassword: newPw.text,
                            confirmPassword: confirmPw.text,
                            revokeOtherSessions: revokeOthers.value,
                          );
                        },
                ),
              ],
            ),
          ),
          const Divider(height: AppSpacing.xxl),
          Row(
            children: [
              Text('Active sessions', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton(
                onPressed: () => context.go(RoutePaths.activeSessions),
                child: const Text('Manage all'),
              ),
            ],
          ),
          if (sessions.value.isEmpty)
            const Text('No tracked sessions yet.')
          else
            ...sessions.value.take(3).map(
                  (s) => ListTile(
                    dense: true,
                    leading: Icon(
                      s.isCurrent ? LucideIcons.monitorSmartphone : LucideIcons.monitor,
                    ),
                    title: Text(s.isCurrent ? 'This device' : (s.userAgent ?? 'Session')),
                    subtitle: Text(s.isActive ? 'Active' : 'Ended'),
                  ),
                ),
          const SizedBox(height: AppSpacing.lg),
          Text('Recent security activity', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          ...security.recentEvents.take(8).map(
                (e) => ListTile(
                  dense: true,
                  leading: const Icon(LucideIcons.activity, size: 18),
                  title: Text(e.actionSlug),
                  subtitle: Text(e.timestamp.toLocal().toString()),
                ),
              ),
          if (security.recentEvents.isEmpty)
            const Text('Security events will appear here as you use the account.'),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: 'Sign out everywhere',
            variant: ButtonVariant.secondary,
            expand: true,
            icon: LucideIcons.logOut,
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(everywhere: true),
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: () => context.go(RoutePaths.profileCenter),
            child: const Text('Open My Profile'),
          ),
          TextButton(
            onPressed: () => context.go(RoutePaths.activityTimeline),
            child: const Text('Full activity timeline'),
          ),
        ],
      ),
    );
  }
}
