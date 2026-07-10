import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/validators/email_validator.dart';
import 'package:hdhomesproject/core/widgets/primary_button.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ForgotPasswordPage extends HookConsumerWidget {
  const ForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailController = useTextEditingController();
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final sent = useState(false);
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: sent.value
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.mark_email_read_outlined, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        'Check your email',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'We sent a password reset link to your email address.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        label: 'Back to Sign In',
                        onPressed: () => context.go(RoutePaths.login),
                      ),
                    ],
                  )
                : Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Reset your password',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Enter your email and we will send you a reset link.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: emailController,
                          decoration: const InputDecoration(labelText: 'Email'),
                          keyboardType: TextInputType.emailAddress,
                          validator: EmailValidator.validate,
                        ),
                        const SizedBox(height: 24),
                        PrimaryButton(
                          label: 'Send Reset Link',
                          expand: true,
                          isLoading: authState.isLoading,
                          onPressed: authState.isLoading
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  try {
                                    await ref
                                        .read(authControllerProvider.notifier)
                                        .resetPassword(
                                          emailController.text.trim(),
                                        );
                                    sent.value = true;
                                  } catch (e) {
                                    final message = e is AppException
                                        ? friendlyErrorMessage(e)
                                        : 'Failed to send reset link.';
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(content: Text(message)),
                                      );
                                    }
                                  }
                                },
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
