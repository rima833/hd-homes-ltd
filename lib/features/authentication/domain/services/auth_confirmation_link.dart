import 'package:hdhomesproject/core/constants/route_paths.dart';

/// What the browser address bar contained when the app started.
///
/// Supabase verifies the email on its own server, then redirects here with
/// `?code=`, `#access_token`, or an error. The client then strips those
/// parameters. This snapshot is taken first so the verify screen can still
/// tell a successful confirm apart from the waiting screen.
class AuthConfirmationLink {
  const AuthConfirmationLink({
    required this.isEmailConfirmation,
    required this.isRecovery,
    this.errorDescription,
    this.email,
  });

  final bool isEmailConfirmation;
  final bool isRecovery;
  final String? errorDescription;
  final String? email;

  /// Parsed once, before [Supabase.initialize] clears the address bar.
  static AuthConfirmationLink? launch;

  /// Original launch URI, kept only long enough to exchange a code.
  static Uri? rawLaunchUri;

  static void captureLaunchUrl(Uri uri) {
    rawLaunchUri = uri;
    launch = parse(uri);
  }

  static void clearRawLaunchUri() {
    rawLaunchUri = null;
  }

  /// Route to open when this URI is an email confirm or a failed confirm.
  String? verifyEmailLocation() {
    if (isRecovery) return null;
    if (isEmailConfirmation) {
      return Uri(
        path: RoutePaths.verifyEmail,
        queryParameters: {
          'confirmed': '1',
          if (email != null && email!.trim().isNotEmpty) 'email': email!.trim(),
        },
      ).toString();
    }
    final error = errorDescription?.trim();
    if (error != null && error.isNotEmpty) {
      return Uri(
        path: RoutePaths.verifyEmail,
        queryParameters: {
          'error_description': error,
          if (email != null && email!.trim().isNotEmpty) 'email': email!.trim(),
        },
      ).toString();
    }
    return null;
  }

  static AuthConfirmationLink parse(Uri uri) {
    final fragment = Uri.splitQueryString(uri.fragment);
    String? param(String key) {
      final queryValue = uri.queryParameters[key];
      if (queryValue != null && queryValue.isNotEmpty) return queryValue;
      final fragmentValue = fragment[key];
      if (fragmentValue != null && fragmentValue.isNotEmpty) {
        return fragmentValue;
      }
      return null;
    }

    final type = (param('type') ?? '').toLowerCase();
    final path = _normalizePath(uri.path);
    final hasCode = param('code') != null;
    final hasAccessToken = param('access_token') != null;
    final hasTokenHash = param('token_hash') != null;
    final onConfirmPath =
        path == RoutePaths.verifyEmail ||
        path == RoutePaths.authCallback ||
        path == RoutePaths.home;
    final isRecovery = type == 'recovery' || path == RoutePaths.resetPassword;
    final error = param('error_description') ?? param('error');
    final signupType =
        type == 'signup' ||
        type == 'email' ||
        type == 'invite' ||
        type == 'email_change';
    final looksLikeConfirm =
        signupType ||
        hasTokenHash ||
        ((hasCode || hasAccessToken) && onConfirmPath);
    final failedOnConfirmPath =
        error != null &&
        error.trim().isNotEmpty &&
        (path == RoutePaths.verifyEmail || path == RoutePaths.authCallback);

    return AuthConfirmationLink(
      isEmailConfirmation:
          !isRecovery &&
          (error == null || error.trim().isEmpty) &&
          looksLikeConfirm,
      isRecovery: isRecovery,
      errorDescription: !isRecovery && (looksLikeConfirm || failedOnConfirmPath)
          ? error
          : null,
      email: param('email'),
    );
  }

  static String _normalizePath(String path) {
    if (path.length > 1 && path.endsWith('/')) {
      return path.substring(0, path.length - 1);
    }
    return path.isEmpty ? RoutePaths.home : path;
  }
}
