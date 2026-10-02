import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/verification_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/auth_confirmation_link.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/verification_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/auth_cinematic_shell.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Premium email verification handoff — cinematic Unified Verification Service™.
class VerifyEmailPage extends HookConsumerWidget {
  const VerifyEmailPage({
    super.key,
    this.email,
    this.accountType,
    this.openedFromConfirmationLink = false,
    this.confirmationError,
  });

  final String? email;
  final String? accountType;

  /// True when this page was opened by the email Confirm link.
  final bool openedFromConfirmationLink;

  /// Supabase error from an expired or already-used confirm link.
  final String? confirmationError;

  String get _roleLabel {
    switch ((accountType ?? '').toLowerCase()) {
      case 'investor':
        return 'Investor Portal';
      case 'staff':
        return 'team workspace';
      case 'admin':
        return 'Admin Control';
      default:
        return 'Client Dashboard';
    }
  }

  String get _waitingCopy {
    return 'Open the email and tap Confirm. This page then shows that your email has been confirmed, and you can sign in.';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(verificationControllerProvider);
    final controller = ref.read(verificationControllerProvider.notifier);
    final session = ref.watch(identitySessionProvider);
    final checking = useState(false);
    final targetEmail = email?.trim().isNotEmpty == true
        ? email!.trim()
        : (session.email ?? '');

    useEffect(() {
      final timer = Timer.periodic(const Duration(seconds: 1), (_) {
        controller.tickCooldowns();
      });
      return timer.cancel;
    }, const []);

    useEffect(() {
      if (!session.emailConfirmed) return null;
      Future<void>(() {
        controller.markEmailVerified();
      });
      return null;
    }, [session.emailConfirmed]);

    useEffect(() {
      var cancelled = false;
      Future<void>(() async {
        if (cancelled) return;
        await _consumeConfirmationLink(ref);
        if (cancelled) return;
        await ref
            .read(identitySessionProvider.notifier)
            .confirmEmailVerifiedFromServer();
      });
      final timer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (cancelled) return;
        final current = ref.read(identitySessionProvider);
        if (current.emailConfirmed || current.userId == null) return;
        ref
            .read(identitySessionProvider.notifier)
            .confirmEmailVerifiedFromServer();
      });
      return () {
        cancelled = true;
        timer.cancel();
      };
    }, const []);

    final launch = AuthConfirmationLink.launch;
    final linkError = (confirmationError ?? launch?.errorDescription)?.trim();
    final linkFailed = linkError != null && linkError.isNotEmpty;
    final fromConfirmLink =
        openedFromConfirmationLink || (launch?.isEmailConfirmation ?? false);
    // The Confirm button already verified the address on the server before
    // this page opened. Show that result even if the session exchange lags.
    final verified =
        !linkFailed &&
        (fromConfirmLink ||
            ui.emailLifecycle == VerificationLifecycle.verified ||
            session.emailConfirmed);

    Future<void> goToLogin() async {
      if (session.userId != null) {
        await ref.read(identitySessionProvider.notifier).signOut();
      }
      if (!context.mounted) return;
      final loginUri = Uri(
        path: RoutePaths.login,
        queryParameters: {if (targetEmail.isNotEmpty) 'email': targetEmail},
      );
      context.go(loginUri.toString());
    }

    Future<void> onContinueToSignIn() async {
      checking.value = true;
      // Cross-device confirm: phone verifies Auth; this tab may have no session.
      // If a session exists, refresh it. Either way, Sign in is the next step.
      if (session.userId != null) {
        final ok = await controller.confirmVerifiedFromServer();
        checking.value = false;
        if (!context.mounted) return;
        if (!ok) return;
      } else {
        checking.value = false;
      }
      await goToLogin();
    }

    return AuthCinematicShell(
      headline: verified ? 'You are verified' : 'Check your inbox',
      subtitle: verified
          ? 'Your $_roleLabel is ready. Sign in to continue your HD Homes journey.'
          : 'We sent a secure link so you can enter your $_roleLabel with confidence.',
      highlights: [
        (LucideIcons.mailCheck, 'One-click email confirmation'),
        (LucideIcons.shield, 'Protected account activation'),
        (LucideIcons.sparkles, 'Personalized $_roleLabel access'),
      ],
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.92, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: verified
                      ? [
                          AppColors.success.withValues(alpha: 0.25),
                          AppColors.success.withValues(alpha: 0.05),
                        ]
                      : [
                          AppColors.gold.withValues(alpha: 0.28),
                          AppColors.gold.withValues(alpha: 0.06),
                        ],
                ),
                border: Border.all(
                  color: verified
                      ? AppColors.success.withValues(alpha: 0.5)
                      : AppColors.gold.withValues(alpha: 0.45),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (verified ? AppColors.success : AppColors.gold)
                        .withValues(alpha: 0.25),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: Icon(
                verified ? LucideIcons.badgeCheck : LucideIcons.mail,
                size: 36,
                color: verified ? AppColors.success : AppColors.gold,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            verified ? 'Your email has been confirmed' : 'Verify your email',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            verified
                ? 'Your HD Homes account is ready for $_roleLabel.'
                : (targetEmail.isEmpty
                      ? _waitingCopy
                      : 'We sent a verification link to $targetEmail.\n$_waitingCopy'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60, height: 1.45),
          ),
          const SizedBox(height: 14),
          _StatusChip(
            lifecycle: linkFailed
                ? VerificationLifecycle.expired
                : ui.emailLifecycle,
            verified: verified,
          ),
          if (ui.message != null) ...[
            const SizedBox(height: 12),
            Text(
              ui.message!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.gold),
            ),
          ],
          if (linkFailed) ...[
            const SizedBox(height: 12),
            Text(
              _friendlyConfirmationError(linkError),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error),
            ),
          ] else if (ui.error != null) ...[
            const SizedBox(height: 12),
            Text(
              ui.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error),
            ),
          ],
          const SizedBox(height: 24),
          if (verified) ...[
            PrimaryButton(
              label: 'Continue to sign in',
              expand: true,
              icon: LucideIcons.logIn,
              isLoading: checking.value,
              onPressed: checking.value ? null : onContinueToSignIn,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                final type = accountType;
                context.go(
                  type == 'investor'
                      ? '${RoutePaths.welcome}?type=investor'
                      : type == 'staff'
                      ? '${RoutePaths.welcome}?type=staff'
                      : '${RoutePaths.welcome}?type=client',
                );
              },
              child: const Text('Continue to welcome'),
            ),
          ] else ...[
            PrimaryButton(
              label: checking.value ? 'Opening…' : 'Continue to sign in',
              expand: true,
              icon: LucideIcons.logIn,
              isLoading: checking.value,
              onPressed: checking.value ? null : onContinueToSignIn,
            ),
            const SizedBox(height: 10),
            PrimaryButton(
              label: 'I confirmed — check status',
              variant: ButtonVariant.secondary,
              expand: true,
              isLoading: checking.value,
              onPressed: checking.value
                  ? null
                  : () async {
                      checking.value = true;
                      await controller.confirmVerifiedFromServer();
                      checking.value = false;
                    },
            ),
            const SizedBox(height: 10),
            PrimaryButton(
              label: ui.emailCooldownSeconds > 0
                  ? 'Resend in ${ui.emailCooldownSeconds}s'
                  : 'Resend verification email',
              variant: ButtonVariant.secondary,
              expand: true,
              isLoading: ui.emailLifecycle == VerificationLifecycle.resending,
              onPressed:
                  ui.emailCooldownSeconds > 0 ||
                      targetEmail.isEmpty ||
                      checking.value
                  ? null
                  : () => controller.resendEmail(targetEmail),
            ),
            const SizedBox(height: 8),
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
    );
  }
}

String _friendlyConfirmationError(String raw) {
  final lower = raw.toLowerCase();
  if (lower.contains('expired') || lower.contains('invalid')) {
    return 'This confirmation link has expired or was already used. Request a new email below, then tap Confirm.';
  }
  return raw;
}

Future<void> _consumeConfirmationLink(WidgetRef ref) async {
  if (!ref.read(supabaseConfiguredProvider)) return;
  final client = ref.read(supabaseClientProvider);
  final uri = AuthConfirmationLink.rawLaunchUri ?? Uri.base;
  final fragment = Uri.splitQueryString(uri.fragment);
  String? param(String key) {
    final queryValue = uri.queryParameters[key];
    if (queryValue != null && queryValue.isNotEmpty) return queryValue;
    final fragmentValue = fragment[key];
    if (fragmentValue != null && fragmentValue.isNotEmpty) return fragmentValue;
    return null;
  }

  final code = param('code');
  final tokenHash = param('token_hash');
  final typeName = (param('type') ?? 'signup').toLowerCase();
  final hasAccessToken = param('access_token') != null;
  if (code == null && tokenHash == null && !hasAccessToken) return;

  try {
    if (tokenHash != null) {
      await client.auth.verifyOTP(
        tokenHash: tokenHash,
        type: _otpTypeFor(typeName),
      );
    } else if (code != null) {
      await client.auth.exchangeCodeForSession(code);
    } else {
      await client.auth.getSessionFromUrl(uri);
    }
  } catch (_) {
    // The email is already confirmed on the server. A second exchange of the
    // same code, or a missing PKCE verifier, must not hide that result.
  } finally {
    AuthConfirmationLink.clearRawLaunchUri();
  }
}

OtpType _otpTypeFor(String type) {
  return switch (type) {
    'recovery' => OtpType.recovery,
    'invite' => OtpType.invite,
    'email_change' => OtpType.emailChange,
    'magiclink' => OtpType.magiclink,
    'email' => OtpType.email,
    _ => OtpType.signup,
  };
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.lifecycle, required this.verified});

  final VerificationLifecycle lifecycle;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final label = verified
        ? 'Confirmed'
        : switch (lifecycle) {
            VerificationLifecycle.sending ||
            VerificationLifecycle.resending => 'Sending…',
            VerificationLifecycle.sent => 'Sent',
            VerificationLifecycle.failed => 'Failed — try again',
            VerificationLifecycle.expired => 'Expired',
            _ => 'Waiting for confirmation',
          };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: (verified ? AppColors.success : AppColors.gold).withValues(
          alpha: 0.12,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: (verified ? AppColors.success : AppColors.gold).withValues(
            alpha: 0.4,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? LucideIcons.check : LucideIcons.clock,
            size: 14,
            color: verified ? AppColors.success : AppColors.gold,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: verified ? AppColors.success : AppColors.gold,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
