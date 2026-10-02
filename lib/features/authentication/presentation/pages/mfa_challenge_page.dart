import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/mfa_models.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/mfa_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/account_portal_scaffold.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/mfa_trust_device_controls.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/otp_code_input.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Second-factor challenge after password login (all portals + staff).
class MfaChallengePage extends HookConsumerWidget {
  const MfaChallengePage({super.key, this.redirectPath});

  final String? redirectPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(mfaControllerProvider);
    final controller = ref.read(mfaControllerProvider.notifier);
    final statusAsync = ref.watch(mfaStatusProvider);
    final useBackup = useState(false);
    final trustDevice = useState(true);
    final trustDays = useState(MfaTrustDurationOptions.days30);
    final backupController = useTextEditingController();
    final code = useState('');
    final otpKey = useState(UniqueKey());
    final continuing = useState(false);
    final autoContinued = useRef(false);

    useEffect(() {
      final days = statusAsync.valueOrNull?.policy.trustDurationDays;
      if (days != null) {
        trustDays.value = MfaTrustDurationOptions.clampToAllowed(days);
      }
      return null;
    }, [statusAsync.valueOrNull?.policy.trustDurationDays]);

    Future<void> continueToDestination() async {
      if (continuing.value) return;
      continuing.value = true;
      final dest = (redirectPath != null && redirectPath!.isNotEmpty)
          ? redirectPath!
          : (ref.read(identitySessionProvider).primaryRole?.defaultRoute ??
              RoutePaths.home);
      if (context.mounted) context.go(dest);
    }

    useEffect(() {
      final snap = statusAsync.valueOrNull;
      if (snap == null ||
          !snap.statusKnown ||
          continuing.value ||
          autoContinued.value) {
        return null;
      }
      if (snap.needsSetup) {
        autoContinued.value = true;
        Future.microtask(() {
          if (!context.mounted) return;
          final dest = redirectPath ?? RoutePaths.home;
          final enc = Uri.encodeComponent(dest);
          context.go('${RoutePaths.mfaSetup}?required=1&redirect=$enc');
        });
        return null;
      }
      if (!snap.needsChallenge) {
        autoContinued.value = true;
        Future.microtask(() async {
          if (context.mounted) await continueToDestination();
        });
      }
      return null;
    }, [
      statusAsync.valueOrNull?.needsChallenge,
      statusAsync.valueOrNull?.needsSetup,
      statusAsync.valueOrNull?.statusKnown,
    ]);

    Future<void> submitTotp(String factorId, String raw) async {
      final normalized = raw.replaceAll(RegExp(r'\D'), '');
      if (normalized.length != 6) return;
      final ok = await controller.verifyChallenge(
        factorId: factorId,
        code: normalized,
        trustDevice: trustDevice.value,
        trustDurationDays: trustDays.value,
      );
      if (ok && context.mounted) {
        await continueToDestination();
      } else if (context.mounted) {
        code.value = '';
        otpKey.value = UniqueKey();
      }
    }

    Future<void> submitBackup() async {
      final ok = await controller.verifyWithBackupCode(
        backupController.text,
        trustDevice: trustDevice.value,
        trustDurationDays: trustDays.value,
      );
      if (ok && context.mounted) await continueToDestination();
    }

    Widget challengeBody(MfaStatusSnapshot status) {
      final factorId =
          status.factorIds.isNotEmpty ? status.factorIds.first : null;
      if (factorId == null) {
        return Column(
          children: [
            Image.asset(AppTheme.logoAsset, height: 44),
            const SizedBox(height: AppSpacing.xl),
            const Text(
              'No authenticator is enrolled on this account. '
              'Set up MFA to continue.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.slate400),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Enable MFA',
              expand: true,
              onPressed: () {
                final enc = Uri.encodeComponent(
                  redirectPath ?? RoutePaths.home,
                );
                context.go(
                  '${RoutePaths.mfaSetup}?required=1&redirect=$enc',
                );
              },
            ),
            TextButton(
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).signOut(),
              child: const Text('Sign out'),
            ),
          ],
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Image.asset(AppTheme.logoAsset, height: 44),
          const SizedBox(height: AppSpacing.xl),
          const Icon(LucideIcons.shield, size: 48, color: AppColors.gold),
          const SizedBox(height: AppSpacing.lg),
          Text(
            "Verify it's you",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.white,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            useBackup.value
                ? 'Enter a one-time backup recovery code.'
                : 'Enter the 6-digit code from your authenticator app.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.slate400),
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
              key: otpKey.value,
              enabled: !ui.isBusy,
              onCompleted: (value) {
                code.value = value;
                submitTotp(factorId, value);
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Verify',
              expand: true,
              isLoading: ui.isBusy,
              onPressed: ui.isBusy ||
                      code.value.replaceAll(RegExp(r'\D'), '').length != 6
                  ? null
                  : () => submitTotp(factorId, code.value),
            ),
          ] else ...[
            TextField(
              controller: backupController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Backup code',
                hintText: 'XXXX-XXXX',
              ),
              onSubmitted: (_) => submitBackup(),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: 'Verify backup code',
              expand: true,
              isLoading: ui.isBusy,
              onPressed: ui.isBusy ? null : submitBackup,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          MfaTrustDeviceControls(
            enabled: trustDevice.value,
            selectedDays: trustDays.value,
            busy: ui.isBusy,
            onEnabledChanged: (v) => trustDevice.value = v,
            onDaysChanged: (d) => trustDays.value = d,
          ),
          const SizedBox(height: AppSpacing.md),
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
    }

    final status = statusAsync.valueOrNull;
    final showInitialLoader =
        statusAsync.isLoading && status == null && !continuing.value;

    return AccountPortalScaffold(
      title: 'Verify MFA',
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: () {
                if (continuing.value || showInitialLoader) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.gold),
                    ),
                  );
                }
                if (statusAsync.hasError && status == null) {
                  return Column(
                    children: [
                      const Text(
                        'Unable to load MFA status.',
                        style: TextStyle(color: AppColors.error),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      PrimaryButton(
                        label: 'Retry',
                        expand: true,
                        onPressed: () => ref.invalidate(mfaStatusProvider),
                      ),
                      TextButton(
                        onPressed: () => ref
                            .read(authControllerProvider.notifier)
                            .signOut(),
                        child: const Text('Sign out'),
                      ),
                    ],
                  );
                }
                if (status == null || !status.statusKnown) {
                  return Column(
                    children: [
                      const Text(
                        'Checking secure session…',
                        style: TextStyle(color: AppColors.slate400),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const CircularProgressIndicator(color: AppColors.gold),
                      const SizedBox(height: AppSpacing.lg),
                      TextButton(
                        onPressed: () => ref.invalidate(mfaStatusProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  );
                }
                if (!status.needsChallenge) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.gold),
                    ),
                  );
                }
                return challengeBody(status);
              }(),
            ),
          ),
        ),
      ),
    );
  }
}
