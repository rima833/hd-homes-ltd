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
import 'package:hdhomesproject/features/authentication/presentation/widgets/account_portal_scaffold.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/auth_password_field.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/otp_code_input.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/password_strength_meter.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/portal_security_health_panel.dart';
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
    final tip = health.recommendations.isEmpty
        ? null
        : health.recommendations.first;

    return AccountPortalScaffold(
      title: 'Security Center',
      body: ListView(
        children: [
          AccountPortalContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AccountPortalMeterCard(
                  title: 'Security Health',
                  valueLabel:
                      'Readiness $readiness / 100 · Base health ${health.score}',
                  progress: readiness / 100,
                  icon: LucideIcons.shieldCheck,
                  tip: tip,
                  chips: [
                    AccountPortalPill(
                      label: readiness >= 80 ? 'Strong' : 'Improving',
                      tone: readiness >= 80
                          ? AccountPortalPillTone.success
                          : AccountPortalPillTone.gold,
                    ),
                    AccountPortalPill(
                      label: verification.emailVerified
                          ? 'Email OK'
                          : 'Email pending',
                      tone: verification.emailVerified
                          ? AccountPortalPillTone.success
                          : AccountPortalPillTone.warning,
                    ),
                    AccountPortalPill(
                      label: verification.phoneVerified
                          ? 'Phone OK'
                          : 'Add phone',
                      tone: verification.phoneVerified
                          ? AccountPortalPillTone.success
                          : AccountPortalPillTone.warning,
                    ),
                  ],
                ),
                if (health.recommendations.length > 1)
                  AccountPortalCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AccountPortalSectionHeader(
                          title: 'Next steps',
                          icon: LucideIcons.listChecks,
                          subtitle: 'Complete these to raise your score',
                        ),
                        const SizedBox(height: 12),
                        for (final r in health.recommendations.skip(1))
                          AccountPortalActionRow(
                            icon: LucideIcons.shield,
                            title: r,
                            dense: true,
                          ),
                      ],
                    ),
                  ),
                AccountPortalCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AccountPortalSectionHeader(
                        title: 'Protection status',
                        icon: LucideIcons.lock,
                        subtitle: 'Verification, MFA, and trusted devices',
                      ),
                      const SizedBox(height: 8),
                      AccountPortalActionRow(
                        icon: verification.emailVerified
                            ? LucideIcons.badgeCheck
                            : LucideIcons.mail,
                        iconColor: verification.emailVerified
                            ? AppColors.success
                            : AppColors.warning,
                        title: 'Email verification',
                        subtitle: verification.emailVerified
                            ? 'Verified'
                            : 'Pending',
                        actionLabel: 'Manage',
                        onAction: () =>
                            context.go(RoutePaths.verificationCenter),
                      ),
                      Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                      AccountPortalActionRow(
                        icon: verification.phoneVerified
                            ? LucideIcons.badgeCheck
                            : LucideIcons.smartphone,
                        iconColor: verification.phoneVerified
                            ? AppColors.success
                            : AppColors.warning,
                        title: 'Phone number',
                        subtitle: verification.phoneVerified
                            ? (verification.phone ?? 'On file from registration')
                            : 'Add a phone number on your profile',
                        actionLabel: verification.phoneVerified ? 'Edit' : 'Add',
                        onAction: () => context.go(RoutePaths.profileCenter),
                      ),
                      Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                      mfaAsync.when(
                        loading: () => const AccountPortalActionRow(
                          icon: LucideIcons.loader,
                          title: 'Multi-factor authentication',
                          subtitle: 'Loading…',
                        ),
                        error: (_, _) => AccountPortalActionRow(
                          icon: LucideIcons.shieldOff,
                          iconColor: AppColors.warning,
                          title: 'Multi-factor authentication',
                          subtitle: 'Unable to load MFA status',
                          actionLabel: 'Set up',
                          onAction: () => context.go(RoutePaths.mfaSetup),
                        ),
                        data: (mfa) => Column(
                          children: [
                            AccountPortalActionRow(
                              icon: mfa.enabled
                                  ? LucideIcons.shieldCheck
                                  : LucideIcons.shieldOff,
                              iconColor: mfa.enabled
                                  ? AppColors.success
                                  : AppColors.warning,
                              title: 'Multi-factor authentication',
                              subtitle: mfa.enabled
                                  ? 'Enabled · ${mfa.backupCodesRemaining} backup codes left'
                                  : mfa.needsSetup
                                      ? 'Required for your role — enable now'
                                      : 'Not enabled · ${mfa.policy.requirement.name}',
                              actionLabel: mfa.enabled
                                  ? (showDisableMfa.value ? 'Cancel' : 'Disable')
                                  : 'Enable',
                              onAction: mfa.enabled
                                  ? () => showDisableMfa.value =
                                      !showDisableMfa.value
                                  : () => context.go(RoutePaths.mfaSetup),
                            ),
                            if (mfa.enabled) ...[
                              Divider(
                                height: 1,
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                              AccountPortalActionRow(
                                icon: LucideIcons.keyRound,
                                title: 'Regenerate backup codes',
                                subtitle: 'Create a fresh set of recovery codes',
                                actionLabel: 'Regenerate',
                                onAction: mfaUi.isBusy
                                    ? null
                                    : () async {
                                        await mfaController
                                            .regenerateBackupCodes();
                                        final codes = ref
                                            .read(mfaControllerProvider)
                                            .backupCodes;
                                        if (context.mounted && codes != null) {
                                          await showDialog<void>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text(
                                                'New backup codes',
                                              ),
                                              content: SingleChildScrollView(
                                                child: SelectableText(
                                                  codes.codes.join('\n'),
                                                ),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx),
                                                  child: const Text('Done'),
                                                ),
                                              ],
                                            ),
                                          );
                                        }
                                      },
                              ),
                              Divider(
                                height: 1,
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                              AccountPortalActionRow(
                                icon: LucideIcons.monitorSmartphone,
                                title:
                                    'Trusted devices (${mfa.trustedDeviceCount})',
                                subtitle:
                                    'Manage MFA device trust · 14 / 30 / 90 days',
                                actionLabel: 'View',
                                onAction: () =>
                                    showTrustedDevicesSheet(context, ref),
                              ),
                            ],
                            if (showDisableMfa.value && mfa.enabled) ...[
                              const SizedBox(height: 12),
                              const Text(
                                'Enter your authenticator code to disable MFA.',
                                style: TextStyle(color: AppColors.slate400),
                              ),
                              const SizedBox(height: 10),
                              OtpCodeInput(
                                enabled: !mfaUi.isBusy,
                                onCompleted: (code) async {
                                  final ok =
                                      await mfaController.disableMfa(code);
                                  if (ok) showDisableMfa.value = false;
                                },
                              ),
                              if (mfaUi.error != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  mfaUi.error!,
                                  style: const TextStyle(color: AppColors.error),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                AccountPortalCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AccountPortalSectionHeader(
                        title: 'Change password',
                        icon: LucideIcons.keyRound,
                        subtitle: 'Use a strong unique password',
                      ),
                      const SizedBox(height: 16),
                      Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AuthPasswordField(
                              controller: currentPw,
                              label: 'Current password',
                              autofillHints: const [AutofillHints.password],
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Current password is required'
                                  : null,
                            ),
                            const SizedBox(height: AppSpacing.base),
                            AuthPasswordField(
                              controller: newPw,
                              label: 'New password',
                              autofillHints: const [AutofillHints.newPassword],
                              validator: policy.validate,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            PasswordStrengthMeter(
                              password: newPasswordValue.value,
                            ),
                            const SizedBox(height: AppSpacing.base),
                            AuthPasswordField(
                              controller: confirmPw,
                              label: 'Confirm new password',
                              autofillHints: const [AutofillHints.newPassword],
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Please confirm your password';
                                }
                                if (v != newPw.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Sign out other devices',
                                style: TextStyle(color: AppColors.white),
                              ),
                              value: revokeOthers.value,
                              onChanged: (v) => revokeOthers.value = v,
                            ),
                            if (ui.error != null)
                              Text(
                                ui.error!,
                                style: const TextStyle(color: AppColors.error),
                              ),
                            if (ui.message != null)
                              Text(
                                ui.message!,
                                style: const TextStyle(color: AppColors.success),
                              ),
                            const SizedBox(height: AppSpacing.sm),
                            PrimaryButton(
                              label: 'Update password',
                              expand: true,
                              isLoading: ui.isSubmitting,
                              onPressed: ui.isSubmitting
                                  ? null
                                  : () async {
                                      if (!formKey.currentState!.validate()) {
                                        return;
                                      }
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
                    ],
                  ),
                ),
                AccountPortalCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AccountPortalSectionHeader(
                        title: 'Active sessions',
                        icon: LucideIcons.monitorSmartphone,
                        subtitle: sessions.value.isEmpty
                            ? 'No tracked sessions yet'
                            : '${sessions.value.length} device session(s)',
                        trailing: TextButton(
                          onPressed: () =>
                              context.go(RoutePaths.activeSessions),
                          child: const Text('Manage all'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (sessions.value.isEmpty)
                        const Text(
                          'Sessions appear here when you sign in on devices.',
                          style: TextStyle(color: AppColors.slate400),
                        )
                      else
                        ...sessions.value.take(3).map(
                              (s) => AccountPortalActionRow(
                                icon: s.isCurrent
                                    ? LucideIcons.monitorSmartphone
                                    : LucideIcons.monitor,
                                title: s.isCurrent
                                    ? 'This device'
                                    : (s.userAgent ?? 'Session'),
                                subtitle: s.isActive ? 'Active' : 'Ended',
                                dense: true,
                              ),
                            ),
                    ],
                  ),
                ),
                AccountPortalCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AccountPortalSectionHeader(
                        title: 'Recent security activity',
                        icon: LucideIcons.activity,
                        subtitle: 'Latest account protection events',
                      ),
                      const SizedBox(height: 8),
                      if (security.recentEvents.isEmpty)
                        const Text(
                          'Security events will appear here as you use the account.',
                          style: TextStyle(color: AppColors.slate400),
                        )
                      else
                        ...security.recentEvents.take(8).map(
                              (e) => AccountPortalActionRow(
                                icon: LucideIcons.activity,
                                title: e.actionSlug,
                                subtitle: e.timestamp.toLocal().toString(),
                                dense: true,
                              ),
                            ),
                    ],
                  ),
                ),
                PrimaryButton(
                  label: 'Sign out everywhere',
                  variant: ButtonVariant.secondary,
                  expand: true,
                  icon: LucideIcons.logOut,
                  onPressed: () => ref
                      .read(authControllerProvider.notifier)
                      .signOut(everywhere: true),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => context.go(RoutePaths.profileCenter),
                      child: const Text('Open My Profile'),
                    ),
                    TextButton(
                      onPressed: () =>
                          context.go(RoutePaths.activityTimeline),
                      child: const Text('Full activity timeline'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
