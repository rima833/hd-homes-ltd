import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/storage/storage_service.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/domain/services/login_validator.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/auth_password_field.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/login_brand_panel.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/social_login_buttons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Premium Unified Authentication Gateway — Volume 3 Part 3.
class LoginPage extends HookConsumerWidget {
  const LoginPage({super.key, this.redirectPath});

  final String? redirectPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final rememberMe = useState(false);
    final authState = ref.watch(authControllerProvider);
    final security = ref.watch(securityServiceProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;

    useEffect(() {
      Future.microtask(() async {
        try {
          final storage = await ref.read(storageServiceProvider.future);
          rememberMe.value = storage.rememberMe;
        } catch (_) {}
      });
      return null;
    }, const []);

    String? authErrorMessage(Object? error) {
      if (error is AppException) return friendlyErrorMessage(error);
      if (error != null) return 'Sign in failed. Please try again.';
      return null;
    }

    ref.listen(authControllerProvider, (prev, next) {
      if (!next.hasError) return;
      final message = authErrorMessage(next.error);
      if (message == null) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    });

    Future<void> submit() async {
      if (security.isLockedOut) {
        final remaining = security.lockoutRemaining;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Too many failed attempts. Try again in ${remaining?.inMinutes ?? 15} minutes.',
            ),
          ),
        );
        return;
      }
      if (!formKey.currentState!.validate()) return;
      TextInput.finishAutofillContext();
      final result = await ref.read(authControllerProvider.notifier).signIn(
            email: emailController.text.trim(),
            password: passwordController.text,
            rememberMe: rememberMe.value,
            redirectPath: redirectPath,
          );
      if (!context.mounted || result != null) return;
      final after = ref.read(authControllerProvider);
      final message = authErrorMessage(after.error) ??
          'Sign in failed. Check your email and password, then try again.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }

    final inlineError = authState.hasError
        ? authErrorMessage(authState.error)
        : null;

    final form = AutofillGroup(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isWide) ...[
              Image.asset(AppTheme.logoAsset, height: 56),
              const SizedBox(height: AppSpacing.xl),
            ],
            Text(
              'Welcome back',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Sign in to continue to your HD Homes workspace',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
            ),
            if (inlineError != null) ...[
              const SizedBox(height: AppSpacing.base),
              Material(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: AppRadius.cardBorder,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(LucideIcons.alertCircle, color: AppColors.error),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          inlineError,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (security.isLockedOut) ...[
              const SizedBox(height: AppSpacing.base),
              Material(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: AppRadius.cardBorder,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.shieldAlert, color: AppColors.error),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Account temporarily locked. Try again in '
                          '${security.lockoutRemaining?.inMinutes ?? 15} minutes.',
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            TextFormField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(LucideIcons.mail),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email, AutofillHints.username],
              validator: LoginValidator.validateEmail,
            ),
            const SizedBox(height: AppSpacing.base),
            AuthPasswordField(
              controller: passwordController,
              validator: LoginValidator.validatePassword,
              onFieldSubmitted: submit,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Checkbox(
                  value: rememberMe.value,
                  onChanged: (v) => rememberMe.value = v ?? false,
                ),
                const Text('Remember me'),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go(RoutePaths.forgotPassword),
                  child: const Text('Forgot password?'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Sign in',
              expand: true,
              icon: LucideIcons.logIn,
              isLoading: authState.isLoading,
              onPressed: authState.isLoading || security.isLockedOut ? null : submit,
            ),
            const SizedBox(height: AppSpacing.lg),
            const SocialLoginButtons(),
            const SizedBox(height: AppSpacing.lg),
            TextButton(
              onPressed: () => context.go(RoutePaths.register),
              child: const Text('Create an account'),
            ),
            TextButton(
              onPressed: () => context.go(RoutePaths.home),
              child: const Text('Back to website'),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      body: isWide
          ? Row(
              children: [
                const Expanded(flex: 5, child: LoginBrandPanel()),
                Expanded(
                  flex: 4,
                  child: SafeArea(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.xxl),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: form,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: form,
                  ),
                ),
              ),
            ),
    );
  }
}
