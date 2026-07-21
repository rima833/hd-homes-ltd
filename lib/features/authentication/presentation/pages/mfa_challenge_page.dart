import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/mfa_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/otp_code_input.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Second-factor challenge after password login.
class MfaChallengePage extends HookConsumerWidget {
  const MfaChallengePage({super.key, this.redirectPath});

  final String? redirectPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(mfaControllerProvider);
    final controller = ref.read(mfaControllerProvider.notifier);
    final statusAsync = ref.watch(mfaStatusProvider);
    final useBackup = useState(false);
    final trustDevice = useState(false);
    final backupController = useTextEditingController();

    Future<void> onSuccess() async {
      final dest = redirectPath ?? RoutePaths.home;
      context.go(dest);
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: statusAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const Text('Unable to load MFA status.'),
                data: (status) {
                  final factorId =
                      status.factorIds.isNotEmpty ? status.factorIds.first : null;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset(AppTheme.logoAsset, height: 44),
                      const SizedBox(height: AppSpacing.xl),
                      const Icon(LucideIcons.shield, size: 48, color: AppColors.gold),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Verify it\'s you',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        useBackup.value
                            ? 'Enter a one-time backup recovery code.'
                            : 'Enter the 6-digit code from your authenticator app.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (ui.error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Text(
                            ui.error!,
                            style: const TextStyle(color: AppColors.error),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      if (!useBackup.value) ...[
                        OtpCodeInput(
                          enabled: !ui.isBusy && factorId != null,
                          onCompleted: (code) async {
                            if (factorId == null) return;
                            final ok = await controller.verifyChallenge(
                              factorId: factorId,
                              code: code,
                              trustDevice: trustDevice.value,
                            );
                            if (ok && context.mounted) await onSuccess();
                          },
                        ),
                      ] else ...[
                        TextField(
                          controller: backupController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Backup code',
                            hintText: 'XXXX-XXXX',
                          ),
                          onSubmitted: (_) async {
                            final ok = await controller
                                .verifyWithBackupCode(backupController.text);
                            if (ok && context.mounted) await onSuccess();
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        PrimaryButton(
                          label: 'Verify backup code',
                          expand: true,
                          isLoading: ui.isBusy,
                          onPressed: ui.isBusy
                              ? null
                              : () async {
                                  final ok = await controller
                                      .verifyWithBackupCode(backupController.text);
                                  if (ok && context.mounted) await onSuccess();
                                },
                        ),
                      ],
                      if (ui.isBusy && !useBackup.value) ...[
                        const SizedBox(height: AppSpacing.md),
                        const Center(child: CircularProgressIndicator()),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Trust this device'),
                        subtitle: Text(
                          'Skip MFA for about ${status.policy.trustDurationDays} days',
                        ),
                        value: trustDevice.value,
                        onChanged: status.policy.isMandatory
                            ? null
                            : (v) => trustDevice.value = v,
                      ),
                      TextButton(
                        onPressed: () => useBackup.value = !useBackup.value,
                        child: Text(
                          useBackup.value
                              ? 'Use authenticator code'
                              : 'Use a backup code',
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            ref.read(authControllerProvider.notifier).signOut(),
                        child: const Text('Sign out'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
