import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/verification_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/login_validator.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/verification_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/otp_code_input.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// OTP phone verification — provider-agnostic UI.
class PhoneVerifyPage extends HookConsumerWidget {
  const PhoneVerifyPage({super.key, this.initialPhone});

  final String? initialPhone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phoneController = useTextEditingController(text: initialPhone ?? '');
    final ui = ref.watch(verificationControllerProvider);
    final controller = ref.read(verificationControllerProvider.notifier);
    final step = useState(0); // 0 = phone, 1 = otp
    final verifying = useState(false);

    useEffect(() {
      final timer = Timer.periodic(const Duration(seconds: 1), (_) {
        controller.tickCooldowns();
      });
      return timer.cancel;
    }, const []);

    Future<void> send() async {
      final err = LoginValidator.validatePhone(phoneController.text);
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        return;
      }
      final ok = await controller.sendPhoneOtp(phoneController.text.trim());
      if (ok) step.value = 1;
    }

    Future<void> onCode(String code) async {
      if (verifying.value) return;
      verifying.value = true;
      final ok = await controller.verifyPhoneOtp(
        phone: phoneController.text.trim(),
        code: code,
      );
      verifying.value = false;
      if (ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone verified')),
        );
        context.go(RoutePaths.verificationCenter);
      }
    }

    final verified = ui.phoneLifecycle == VerificationLifecycle.verified;

    return Scaffold(
      appBar: AppBar(title: const Text('Verify phone')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(AppTheme.logoAsset, height: 40),
                  const SizedBox(height: AppSpacing.xl),
                  Icon(
                    verified ? LucideIcons.badgeCheck : LucideIcons.smartphone,
                    size: 56,
                    color: verified ? AppColors.success : AppColors.gold,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    verified
                        ? 'Phone verified'
                        : (step.value == 0
                            ? 'Add your phone number'
                            : 'Enter verification code'),
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    step.value == 0
                        ? 'We will send a one-time code via SMS. Mock provider accepts 123456 in development.'
                        : 'Enter the 6-digit code sent to ${phoneController.text.trim()}.',
                    textAlign: TextAlign.center,
                  ),
                  if (ui.error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(ui.error!, style: const TextStyle(color: AppColors.error)),
                  ],
                  if (ui.message != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(ui.message!, style: const TextStyle(color: AppColors.gold)),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  if (!verified && step.value == 0) ...[
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        prefixIcon: Icon(LucideIcons.phone),
                        hintText: '+234…',
                      ),
                      validator: LoginValidator.validatePhone,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(
                      label: 'Send code',
                      expand: true,
                      isLoading:
                          ui.phoneLifecycle == VerificationLifecycle.sending,
                      onPressed: ui.phoneCooldownSeconds > 0 ? null : send,
                    ),
                  ],
                  if (!verified && step.value == 1) ...[
                    OtpCodeInput(
                      onCompleted: onCode,
                      enabled: !verifying.value,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(
                      label: ui.phoneCooldownSeconds > 0
                          ? 'Resend in ${ui.phoneCooldownSeconds}s'
                          : 'Resend code',
                      variant: ButtonVariant.secondary,
                      expand: true,
                      onPressed: ui.phoneCooldownSeconds > 0 ? null : send,
                    ),
                    TextButton(
                      onPressed: () => step.value = 0,
                      child: const Text('Change phone number'),
                    ),
                  ],
                  if (verified)
                    PrimaryButton(
                      label: 'Open Verification Center',
                      expand: true,
                      onPressed: () => context.go(RoutePaths.verificationCenter),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
