import 'dart:async' show unawaited;

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
    final recovering = useState(true);
    final recoverError = useState<String?>(null);

    useEffect(() {
      if (!ref.read(supabaseConfiguredProvider)) {
        recovering.value = false;
        recoverError.value =
            'Authentication is not configured. Restart with Supabase env.';
        return null;
      }
      final client = ref.read(supabaseClientProvider);
      var cancelled = false;

      Future<void> recoverFromUrl() async {
        recoverError.value = null;
        try {
          final uri = Uri.base;
          final code = uri.queryParameters['code'];
          if (code != null && code.isNotEmpty) {
            await client.auth.exchangeCodeForSession(code);
          } else {
            // Implicit / recovery hash tokens (#access_token&type=recovery).
            try {
              await client.auth.getSessionFromUrl(uri);
            } catch (_) {
              // detectSessionInUrl may already have consumed the hash.
            }
          }
        } catch (e) {
          if (!cancelled) {
            recoverError.value =
                'This reset link is invalid or expired. Request a new one.';
          }
        }

        if (cancelled) return;
        if (client.auth.currentSession != null) {
          recoveryReady.value = true;
          controller.markRecoveryReady(true);
        }
        recovering.value = false;
      }

      if (client.auth.currentSession != null) {
        recoveryReady.value = true;
        controller.markRecoveryReady(true);
        recovering.value = false;
      } else {
        unawaited(recoverFromUrl());
      }

      final sub = client.auth.onAuthStateChange.listen((data) {
        if (isPasswordRecoveryEvent(data.event) || data.session != null) {
          recoveryReady.value = true;
          controller.markRecoveryReady(true);
          recovering.value = false;
          recoverError.value = null;
        }
      });
      return () {
        cancelled = true;
        sub.cancel();
      };
    }, const []);

    useEffect(() {
      void listener() => password.value = passwordController.text;
      passwordController.addListener(listener);
      return () => passwordController.removeListener(listener);
    }, [passwordController]);

    final ready = recoveryReady.value || ui.recoveryReady;

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
                      recovering.value
                          ? 'Confirming your reset link…'
                          : ready
                              ? 'Choose a strong password. All other sessions will be signed out.'
                              : 'Open the reset link from your email in this same browser (where HD Homes is running).',
                      textAlign: TextAlign.center,
                    ),
                    if (recoverError.value != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        recoverError.value!,
                        style: const TextStyle(color: AppColors.error),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (ui.error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        ui.error!,
                        style: const TextStyle(color: AppColors.error),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (ui.message != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        ui.message!,
                        style: const TextStyle(color: AppColors.success),
                        textAlign: TextAlign.center,
                      ),
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
                        if (v == null || v.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (v != passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    PrimaryButton(
                      label: recovering.value
                          ? 'Preparing…'
                          : 'Save new password',
                      expand: true,
                      icon: LucideIcons.check,
                      isLoading: ui.isSubmitting || recovering.value,
                      onPressed: (!ready || ui.isSubmitting || recovering.value)
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
                    if (!ready && !recovering.value) ...[
                      const SizedBox(height: AppSpacing.sm),
                      PrimaryButton(
                        label: 'Request a new reset link',
                        variant: ButtonVariant.secondary,
                        expand: true,
                        onPressed: () =>
                            context.go(RoutePaths.forgotPassword),
                      ),
                    ],
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

