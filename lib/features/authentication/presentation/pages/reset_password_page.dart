import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/account_security_models.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/account_security_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/auth_password_field.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/password_strength_meter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// New password form after opening a secure Supabase recovery link.
class ResetPasswordPage extends HookConsumerWidget {
  const ResetPasswordPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passwordController = useTextEditingController();
    final confirmController = useTextEditingController();
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final password = useState('');
    final ui = ref.watch(accountSecurityControllerProvider);
    final controller = ref.read(accountSecurityControllerProvider.notifier);
    final role = ref.watch(identitySessionProvider).primaryRole;
    final policy = PasswordPolicy.forRole(role);
    final recoveryReady = useState(false);

    useEffect(() {
      if (!ref.read(supabaseConfiguredProvider)) return null;
      final client = ref.read(supabaseClientProvider);
      // Already have a session from deep link.
      if (client.auth.currentSession != null) {
        recoveryReady.value = true;
        controller.markRecoveryReady(true);
      }
      final sub = client.auth.onAuthStateChange.listen((data) {
        if (isPasswordRecoveryEvent(data.event) || data.session != null) {
          recoveryReady.value = true;
          controller.markRecoveryReady(true);
        }
      });
      return sub.cancel;
    }, const []);

    useEffect(() {
      void listener() => password.value = passwordController.text;
      passwordController.addListener(listener);
      return () => passwordController.removeListener(listener);
    }, [passwordController]);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset(AppTheme.logoAsset, height: 48),
                    const SizedBox(height: AppSpacing.xl),
                    const Icon(LucideIcons.lock, size: 56, color: AppColors.gold),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Create a new password',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      recoveryReady.value || ui.recoveryReady
                          ? 'Choose a strong password. All other sessions will be signed out.'
                          : 'Open the reset link from your email to continue. If you already did, your session may still be loading…',
                      textAlign: TextAlign.center,
                    ),
                    if (ui.error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(ui.error!, style: const TextStyle(color: AppColors.error)),
                    ],
                    if (ui.message != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(ui.message!, style: const TextStyle(color: AppColors.success)),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    AuthPasswordField(
                      controller: passwordController,
                      label: 'New password',
                      autofillHints: const [AutofillHints.newPassword],
                      validator: policy.validate,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    PasswordStrengthMeter(password: password.value),
                    const SizedBox(height: AppSpacing.base),
                    AuthPasswordField(
                      controller: confirmController,
                      label: 'Confirm password',
                      autofillHints: const [AutofillHints.newPassword],
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Please confirm your password';
                        if (v != passwordController.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    PrimaryButton(
                      label: 'Save new password',
                      expand: true,
                      icon: LucideIcons.check,
                      isLoading: ui.isSubmitting,
                      onPressed: ui.isSubmitting
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              final ok = await controller.completeReset(
                                password: passwordController.text,
                                confirm: confirmController.text,
                              );
                              if (ok && context.mounted) {
                                context.go(RoutePaths.login);
                              }
                            },
                    ),
                    TextButton(
                      onPressed: () => context.go(RoutePaths.login),
                      child: const Text('Back to Login'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
