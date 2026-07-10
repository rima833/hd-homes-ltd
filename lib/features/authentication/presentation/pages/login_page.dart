import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/core/validators/email_validator.dart';
import 'package:hdhomesproject/core/widgets/primary_button.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class LoginPage extends HookConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final authState = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (prev, next) {
      if (next.hasError) {
        final error = next.error;
        final message = error is AppException
            ? friendlyErrorMessage(error)
            : 'Sign in failed. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    });

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(AppTheme.logoAsset, height: 80),
                  const SizedBox(height: 32),
                  Text(
                    'Welcome Back',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to your HD Homes account',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: EmailValidator.validate,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outlined),
                    ),
                    obscureText: true,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Password is required' : null,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.go(RoutePaths.forgotPassword),
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Sign In',
                    expand: true,
                    isLoading: authState.isLoading,
                    onPressed: authState.isLoading
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            await ref
                                .read(authControllerProvider.notifier)
                                .signIn(
                                  email: emailController.text.trim(),
                                  password: passwordController.text,
                                );
                          },
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go(RoutePaths.register),
                    child: const Text('Create an account'),
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
