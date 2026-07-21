import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/verification_models.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/verification_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Premium email verification handoff — Unified Verification Service™.
class VerifyEmailPage extends HookConsumerWidget {
  const VerifyEmailPage({
    super.key,
    this.email,
    this.accountType,
  });

  final String? email;
  final String? accountType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(verificationControllerProvider);
    final controller = ref.read(verificationControllerProvider.notifier);
    final session = ref.watch(identitySessionProvider);
    final targetEmail = email?.trim().isNotEmpty == true
        ? email!.trim()
        : (session.email ?? '');

    useEffect(() {
      final timer = Timer.periodic(const Duration(seconds: 1), (_) {
        controller.tickCooldowns();
      });
      return timer.cancel;
    }, const []);

    // Realtime: when identity becomes email-confirmed, celebrate.
    useEffect(() {
      if (session.emailConfirmed) {
        controller.markEmailVerified();
      }
      return null;
    }, [session.emailConfirmed]);

    final verified = ui.emailLifecycle == VerificationLifecycle.verified ||
        session.emailConfirmed;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  Image.asset(AppTheme.logoAsset, height: 48),
                  const SizedBox(height: AppSpacing.xl),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Icon(
                      verified ? LucideIcons.badgeCheck : LucideIcons.mail,
                      key: ValueKey(verified),
                      size: 64,
                      color: verified ? AppColors.success : AppColors.gold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    verified ? 'Email verified' : 'Verify your email',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    verified
                        ? 'Your address is confirmed. You can continue to your workspace.'
                        : (targetEmail.isEmpty
                            ? 'We sent a verification link to your inbox. Open it to activate your account.'
                            : 'We sent a verification link to $targetEmail. Open it to activate your account.'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.base),
                  _StatusChip(lifecycle: ui.emailLifecycle, verified: verified),
                  if (ui.message != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      ui.message!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.gold),
                    ),
                  ],
                  if (ui.error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      ui.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  if (verified) ...[
                    PrimaryButton(
                      label: 'Continue',
                      expand: true,
                      icon: LucideIcons.arrowRight,
                      onPressed: () {
                        final type = accountType;
                        context.go(
                          type == 'investor'
                              ? '${RoutePaths.welcome}?type=investor'
                              : '${RoutePaths.welcome}?type=client',
                        );
                      },
                    ),
                  ] else ...[
                    PrimaryButton(
                      label: 'I have verified — Sign in',
                      expand: true,
                      onPressed: () => context.go(RoutePaths.login),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    PrimaryButton(
                      label: ui.emailCooldownSeconds > 0
                          ? 'Resend in ${ui.emailCooldownSeconds}s'
                          : 'Resend verification email',
                      variant: ButtonVariant.secondary,
                      expand: true,
                      isLoading:
                          ui.emailLifecycle == VerificationLifecycle.resending,
                      onPressed: ui.emailCooldownSeconds > 0 || targetEmail.isEmpty
                          ? null
                          : () => controller.resendEmail(targetEmail),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: () => context.go(RoutePaths.register),
                      child: const Text('Change email / re-register'),
                    ),
                    TextButton(
                      onPressed: () => context.go(RoutePaths.contact),
                      child: const Text('Contact support'),
                    ),
                  ],
                  TextButton(
                    onPressed: () => context.go(RoutePaths.home),
                    child: const Text('Back to website'),
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.lifecycle, required this.verified});

  final VerificationLifecycle lifecycle;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final label = verified
        ? 'Verified'
        : switch (lifecycle) {
            VerificationLifecycle.sending || VerificationLifecycle.resending =>
              'Sending…',
            VerificationLifecycle.sent => 'Sent',
            VerificationLifecycle.failed => 'Failed — try again',
            VerificationLifecycle.expired => 'Expired',
            _ => 'Waiting for confirmation',
          };
    return Chip(
      avatar: Icon(
        verified ? LucideIcons.check : LucideIcons.clock,
        size: 16,
        color: verified ? AppColors.success : AppColors.gold,
      ),
      label: Text(label),
    );
  }
}
