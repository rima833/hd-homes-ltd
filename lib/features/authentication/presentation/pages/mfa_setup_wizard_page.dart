import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/mfa_models.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/mfa_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/otp_code_input.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Guided MFA setup wizard (TOTP + backup codes).
class MfaSetupWizardPage extends HookConsumerWidget {
  const MfaSetupWizardPage({
    super.key,
    this.redirectPath,
    this.required = false,
  });

  final String? redirectPath;
  final bool required;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(mfaControllerProvider);
    final controller = ref.read(mfaControllerProvider.notifier);
    final status = ref.watch(mfaStatusProvider);

    useEffect(() {
      // Already enrolled → jump to management messaging
      final snap = status.valueOrNull;
      if (snap != null && snap.enabled && ui.step == 0) {
        Future.microtask(() => controller.setStep(6));
      }
      return null;
    }, [status.valueOrNull?.enabled]);

    void finish() {
      final dest = redirectPath ?? RoutePaths.securityCenter;
      context.go(dest);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enable MFA'),
        leading: required
            ? null
            : IconButton(
                icon: const Icon(LucideIcons.x),
                onPressed: () => context.go(RoutePaths.securityCenter),
              ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(AppTheme.logoAsset, height: 40),
                  const SizedBox(height: AppSpacing.lg),
                  _StepIndicator(step: ui.step),
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
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: KeyedSubtree(
                      key: ValueKey(ui.step),
                      child: _buildStep(context, ref, ui, controller, finish),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(
    BuildContext context,
    WidgetRef ref,
    MfaUiState ui,
    MfaController controller,
    VoidCallback finish,
  ) {
    switch (ui.step) {
      case 0:
        return _IntroStep(
          required: required,
          onContinue: () => controller.setStep(1),
        );
      case 1:
        return _MethodStep(
          selected: ui.selectedMethod,
          onSelect: controller.selectMethod,
          onContinue: () {
            if (ui.selectedMethod == MfaMethodKind.totp) {
              controller.setStep(2);
            }
          },
          onBack: () => controller.setStep(0),
        );
      case 2:
        return _PrepareTotpStep(
          isBusy: ui.isBusy,
          onContinue: controller.startEnrollment,
          onBack: () => controller.setStep(1),
        );
      case 3:
        return _ConfigureTotpStep(
          enrollment: ui.enrollment,
          onContinue: () => controller.setStep(4),
          onBack: () => controller.setStep(2),
        );
      case 4:
        return _VerifyTotpStep(
          isBusy: ui.isBusy,
          onVerified: (code) => controller.confirmEnrollment(code),
          onBack: () => controller.setStep(3),
        );
      case 5:
        return _BackupCodesStep(
          bundle: ui.backupCodes,
          onContinue: () {
            controller.finishWizard();
          },
        );
      default:
        return _DoneStep(
          message: ui.message ?? 'MFA successfully enabled.',
          onFinish: finish,
        );
    }
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final labels = ['Intro', 'Method', 'Setup', 'Verify', 'Backup', 'Done'];
    final active = step.clamp(0, labels.length - 1);
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) Expanded(child: Divider(color: i <= active ? AppColors.gold : AppColors.gray)),
          CircleAvatar(
            radius: 12,
            backgroundColor: i <= active ? AppColors.gold : AppColors.gray.withValues(alpha: 0.3),
            child: Text(
              '${i + 1}',
              style: TextStyle(
                fontSize: 11,
                color: i <= active ? Colors.white : AppColors.gray,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _IntroStep extends StatelessWidget {
  const _IntroStep({required this.required, required this.onContinue});

  final bool required;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(LucideIcons.shieldCheck, size: 56, color: AppColors.gold),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Protect your account',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          required
              ? 'Your role requires multi-factor authentication before continuing.'
              : 'Add a second layer of security with an authenticator app. Even if someone learns your password, they cannot sign in without your verification code.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.base),
        const ListTile(
          dense: true,
          leading: Icon(LucideIcons.lock),
          title: Text('Blocks unauthorized access'),
        ),
        const ListTile(
          dense: true,
          leading: Icon(LucideIcons.keyRound),
          title: Text('Backup codes for recovery'),
        ),
        const ListTile(
          dense: true,
          leading: Icon(LucideIcons.smartphone),
          title: Text('Works with Google Authenticator, Authy, and more'),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(label: 'Get started', expand: true, onPressed: onContinue),
      ],
    );
  }
}

class _MethodStep extends StatelessWidget {
  const _MethodStep({
    required this.selected,
    required this.onSelect,
    required this.onContinue,
    required this.onBack,
  });

  final MfaMethodKind selected;
  final ValueChanged<MfaMethodKind> onSelect;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Choose a method', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        RadioGroup<MfaMethodKind>(
          groupValue: selected,
          onChanged: (v) {
            if (v != null) onSelect(v);
          },
          child: Column(
            children: [
              RadioListTile<MfaMethodKind>(
                value: MfaMethodKind.totp,
                title: const Text('Authenticator app'),
                subtitle: const Text(
                  'Recommended — Google Authenticator, Microsoft Authenticator, Authy',
                ),
              ),
              RadioListTile<MfaMethodKind>(
                value: MfaMethodKind.emailOtp,
                enabled: false,
                title: const Text('Email code'),
                subtitle: const Text('Available as fallback when policy allows'),
              ),
              RadioListTile<MfaMethodKind>(
                value: MfaMethodKind.smsOtp,
                enabled: false,
                title: const Text('SMS code'),
                subtitle: const Text('Optional — enable in Admin Panel'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(label: 'Continue', expand: true, onPressed: onContinue),
        TextButton(onPressed: onBack, child: const Text('Back')),
      ],
    );
  }
}

class _PrepareTotpStep extends StatelessWidget {
  const _PrepareTotpStep({
    required this.isBusy,
    required this.onContinue,
    required this.onBack,
  });

  final bool isBusy;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Install an authenticator', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Open your authenticator app, then continue. We will show a QR code to scan.',
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Show QR code',
          expand: true,
          isLoading: isBusy,
          onPressed: isBusy ? null : onContinue,
        ),
        TextButton(onPressed: onBack, child: const Text('Back')),
      ],
    );
  }
}

class _ConfigureTotpStep extends StatelessWidget {
  const _ConfigureTotpStep({
    required this.enrollment,
    required this.onContinue,
    required this.onBack,
  });

  final MfaEnrollmentDraft? enrollment;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final draft = enrollment;
    if (draft == null) {
      return const Text('Enrollment not started.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Scan QR code', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            color: Colors.white,
            child: QrImageView(
              data: draft.uri,
              size: 200,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Or enter this key manually:', textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xs),
        SelectableText(
          draft.secret,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                letterSpacing: 1.2,
                fontFamily: 'monospace',
              ),
        ),
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: draft.secret));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Secret copied')),
            );
          },
          child: const Text('Copy secret'),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(label: 'I have scanned the code', expand: true, onPressed: onContinue),
        TextButton(onPressed: onBack, child: const Text('Back')),
      ],
    );
  }
}

class _VerifyTotpStep extends StatelessWidget {
  const _VerifyTotpStep({
    required this.isBusy,
    required this.onVerified,
    required this.onBack,
  });

  final bool isBusy;
  final Future<bool> Function(String code) onVerified;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Enter verification code', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        const Text('Enter the 6-digit code from your authenticator app.'),
        const SizedBox(height: AppSpacing.lg),
        OtpCodeInput(
          enabled: !isBusy,
          onCompleted: (code) async {
            await onVerified(code);
          },
        ),
        if (isBusy) ...[
          const SizedBox(height: AppSpacing.md),
          const Center(child: CircularProgressIndicator()),
        ],
        const SizedBox(height: AppSpacing.md),
        TextButton(onPressed: onBack, child: const Text('Back')),
      ],
    );
  }
}

class _BackupCodesStep extends StatelessWidget {
  const _BackupCodesStep({
    required this.bundle,
    required this.onContinue,
  });

  final BackupCodeBundle? bundle;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final codes = bundle?.codes ?? const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Save backup codes', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Store these one-time codes somewhere safe. Each can be used once if you lose your authenticator.',
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.gray.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            children: codes
                .map(
                  (c) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: SelectableText(
                      c,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: codes.join('\n')));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Backup codes copied')),
            );
          },
          icon: const Icon(LucideIcons.copy),
          label: const Text('Copy all'),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'I have saved my codes',
          expand: true,
          onPressed: onContinue,
        ),
      ],
    );
  }
}

class _DoneStep extends StatelessWidget {
  const _DoneStep({required this.message, required this.onFinish});

  final String message;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(LucideIcons.badgeCheck, size: 64, color: AppColors.success),
        const SizedBox(height: AppSpacing.lg),
        Text(
          message,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Your account is protected with multi-factor authentication.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(label: 'Continue', expand: true, onPressed: onFinish),
      ],
    );
  }
}
