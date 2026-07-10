import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/core/validators/email_validator.dart';
import 'package:hdhomesproject/core/validators/name_validator.dart';
import 'package:hdhomesproject/core/validators/password_validator.dart';
import 'package:hdhomesproject/core/widgets/primary_button.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class RegisterPage extends HookConsumerWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstNameController = useTextEditingController();
    final lastNameController = useTextEditingController();
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final authState = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (prev, next) {
      if (next.hasError) {
        final error = next.error;
        final message = error is AppException
            ? friendlyErrorMessage(error)
            : 'Registration failed. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      } else if (next.hasValue && next.value != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created! Check your email to verify.'),
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
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
                  Image.asset(AppTheme.logoAsset, height: 64),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: firstNameController,
                    decoration: const InputDecoration(labelText: 'First Name'),
                    validator: (v) =>
                        NameValidator.validate(v, fieldName: 'First name'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: lastNameController,
                    decoration: const InputDecoration(labelText: 'Last Name'),
                    validator: (v) =>
                        NameValidator.validate(v, fieldName: 'Last name'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: EmailValidator.validate,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: PasswordValidator.validate,
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Create Account',
                    expand: true,
                    isLoading: authState.isLoading,
                    onPressed: authState.isLoading
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            await ref
                                .read(authControllerProvider.notifier)
                                .signUp(
                                  email: emailController.text.trim(),
                                  password: passwordController.text,
                                  firstName: firstNameController.text.trim(),
                                  lastName: lastNameController.text.trim(),
                                );
                          },
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go(RoutePaths.login),
                    child: const Text('Already have an account? Sign in'),
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
