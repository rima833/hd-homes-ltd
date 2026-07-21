import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/validators/email_validator.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/account_security_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Premium password recovery request screen.
class ForgotPasswordPage extends HookConsumerWidget {
  const ForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailController = useTextEditingController();
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final sent = useState(false);
    final ui = ref.watch(accountSecurityControllerProvider);
    final controller = ref.read(accountSecurityControllerProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  Image.asset(AppTheme.logoAsset, height: 48),
                  const SizedBox(height: AppSpacing.xl),
                  Icon(
                    sent.value ? LucideIcons.mailCheck : LucideIcons.keyRound,
                    size: 56,
                    color: AppColors.gold,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    sent.value ? 'Check your email' : 'Forgot your password?',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    sent.value
                        ? (ui.message ??
                            'If an account exists for that email, we sent a secure reset link.')
                        : 'Enter the email associated with your HD Homes account and we will send a secure reset link.',
                    textAlign: TextAlign.center,
                  ),
                  if (ui.error != null && !sent.value) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(ui.error!, style: const TextStyle(color: AppColors.error)),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  if (!sent.value)
                    Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(LucideIcons.mail),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            validator: EmailValidator.validate,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          PrimaryButton(
                            label: 'Send reset link',
                            expand: true,
                            icon: LucideIcons.send,
                            isLoading: ui.isSubmitting,
                            onPressed: ui.isSubmitting
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) return;
                                    final ok = await controller.requestReset(
                                      emailController.text.trim(),
                                    );
                                    if (ok) sent.value = true;
                                  },
                          ),
                        ],
                      ),
                    )
                  else
                    PrimaryButton(
                      label: 'Back to Sign in',
                      expand: true,
                      onPressed: () => context.go(RoutePaths.login),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: () => context.go(RoutePaths.login),
                    child: const Text('Back to Login'),
                  ),
                  TextButton(
                    onPressed: () => context.go(RoutePaths.contact),
                    child: const Text('Contact Support'),
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
