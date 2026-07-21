import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/website/seo/seo_binder.dart';
import 'package:hdhomesproject/core/website/seo/seo_config.dart';
import 'package:hdhomesproject/core/website/seo/seo_resolver.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/active_sessions_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/activity_timeline_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/ai_workspace_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/kyc_verification_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/notification_center_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/mfa_challenge_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/mfa_setup_wizard_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/forgot_password_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/login_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/phone_verify_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/preference_center_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/profile_center_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/register_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/reset_password_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/security_center_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/verification_center_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/verify_email_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/welcome_page.dart';

Widget _withAuthSeo(String path, Widget child) {
  final base = SeoResolver.resolvePath(path);
  if (base == null) return child;
  return SeoBinder(
    metadata: base.withCanonical(SeoConfig.canonicalFor(path)),
    child: child,
  );
}

List<RouteBase> get authRoutes => [
      GoRoute(
        path: RoutePaths.login,
        name: 'login',
        builder: (context, state) {
          final redirect = state.uri.queryParameters['redirect'];
          return _withAuthSeo(
            RoutePaths.login,
            LoginPage(redirectPath: redirect),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.register,
        name: 'register',
        builder: (context, state) {
          final type = state.uri.queryParameters['type'];
          final referral = state.uri.queryParameters['ref'];
          final invite = state.uri.queryParameters['invite'];
          final email = state.uri.queryParameters['email'];
          return _withAuthSeo(
            RoutePaths.register,
            RegisterPage(
              key: ValueKey('register-$type-$referral-$invite-$email'),
              initialAccountType: type,
              initialReferralCode: referral,
              invitationToken: invite,
              initialEmail: email,
            ),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.forgotPassword,
        name: 'forgot-password',
        builder: (context, state) =>
            _withAuthSeo(RoutePaths.forgotPassword, const ForgotPasswordPage()),
      ),
      GoRoute(
        path: RoutePaths.resetPassword,
        name: 'reset-password',
        builder: (context, state) =>
            _withAuthSeo(RoutePaths.resetPassword, const ResetPasswordPage()),
      ),
      GoRoute(
        path: RoutePaths.verifyEmail,
        name: 'verify-email',
        builder: (context, state) => _withAuthSeo(
          RoutePaths.verifyEmail,
          VerifyEmailPage(
            email: state.uri.queryParameters['email'],
            accountType: state.uri.queryParameters['type'],
          ),
        ),
      ),
      GoRoute(
        path: RoutePaths.welcome,
        name: 'welcome',
        builder: (context, state) => _withAuthSeo(
          RoutePaths.welcome,
          WelcomePage(
            accountTypeId: state.uri.queryParameters['type'],
          ),
        ),
      ),
      GoRoute(
        path: RoutePaths.activeSessions,
        name: 'active-sessions',
        builder: (context, state) => const ActiveSessionsPage(),
      ),
      GoRoute(
        path: RoutePaths.verificationCenter,
        name: 'verification-center',
        builder: (context, state) => const VerificationCenterPage(),
      ),
      GoRoute(
        path: RoutePaths.verifyPhone,
        name: 'verify-phone',
        builder: (context, state) => PhoneVerifyPage(
          initialPhone: state.uri.queryParameters['phone'],
        ),
      ),
      GoRoute(
        path: RoutePaths.securityCenter,
        name: 'security-center',
        builder: (context, state) => const SecurityCenterPage(),
      ),
      GoRoute(
        path: RoutePaths.profileCenter,
        name: 'profile-center',
        builder: (context, state) => const ProfileCenterPage(),
      ),
      GoRoute(
        path: RoutePaths.preferenceCenter,
        name: 'preference-center',
        builder: (context, state) => const PreferenceCenterPage(),
      ),
      GoRoute(
        path: RoutePaths.accessibilityCenter,
        name: 'accessibility-center',
        builder: (context, state) => const PreferenceCenterPage(initialTab: 3),
      ),
      GoRoute(
        path: RoutePaths.kycVerification,
        name: 'kyc-verification',
        builder: (context, state) => const KycVerificationPage(),
      ),
      GoRoute(
        path: RoutePaths.notificationCenter,
        name: 'notification-center',
        builder: (context, state) => const NotificationCenterPage(),
      ),
      GoRoute(
        path: RoutePaths.activityTimeline,
        name: 'activity-timeline',
        builder: (context, state) => const ActivityTimelinePage(),
      ),
      GoRoute(
        path: RoutePaths.aiWorkspace,
        name: 'ai-workspace',
        builder: (context, state) => const AiWorkspacePage(),
      ),
      GoRoute(
        path: RoutePaths.mfaSetup,
        name: 'mfa-setup',
        builder: (context, state) => MfaSetupWizardPage(
          redirectPath: state.uri.queryParameters['redirect'],
          required: state.uri.queryParameters['required'] == '1',
        ),
      ),
      GoRoute(
        path: RoutePaths.mfaChallenge,
        name: 'mfa-challenge',
        builder: (context, state) => MfaChallengePage(
          redirectPath: state.uri.queryParameters['redirect'],
        ),
      ),
    ];
