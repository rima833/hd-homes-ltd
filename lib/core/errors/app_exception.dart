import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Base exception for all application errors.
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

/// Network or connectivity failures.
final class NetworkException extends AppException {
  const NetworkException(super.message, {super.cause});
}

/// Authentication and authorization failures.
final class AuthenticationException extends AppException {
  const AuthenticationException(super.message, {super.cause});
}

/// Database and Supabase operation failures.
final class DatabaseException extends AppException {
  const DatabaseException(super.message, {super.cause});
}

/// Input validation failures.
final class ValidationException extends AppException {
  const ValidationException(super.message, {super.cause});
}

/// Registration / onboarding failures.
final class RegistrationException extends AppException {
  const RegistrationException(super.message, {super.cause});
}

/// Maps [AppException] to user-friendly display messages.
String friendlyErrorMessage(AppException exception) {
  return switch (exception) {
    NetworkException() => exception.message.isNotEmpty
        ? exception.message
        : kNetworkErrorMessage,
    AuthenticationException() => exception.message,
    DatabaseException() => exception.message.isNotEmpty
        ? exception.message
        : 'Something went wrong while saving your data. Please try again.',
    ValidationException() => exception.message,
    RegistrationException() => exception.message,
  };
}

const kGenericErrorMessage =
    'Something went wrong. Please try again in a moment.';
const kNetworkErrorMessage =
    'Unable to connect. Please check your internet connection and try again.';
const kTimeoutErrorMessage =
    'This is taking longer than expected. Please try again.';
const kAuthErrorMessage =
    'Unable to complete authentication. Please try again.';

/// Global user-facing error text. Never returns raw backend / stack traces.
String userFacingError(Object? error, {String? fallback}) {
  if (error == null) return fallback ?? kGenericErrorMessage;

  if (error is AppException) {
    final msg = friendlyErrorMessage(error);
    final lower = msg.toLowerCase();
    if (isNetworkish(lower)) return kNetworkErrorMessage;
    if (looksLikeTechnicalError(msg)) {
      return fallback ?? kGenericErrorMessage;
    }
    return msg;
  }

  if (error is AuthException) {
    return friendlyAuthMessage(error.message);
  }

  if (error is PostgrestException) {
    return friendlyPostgrestMessage(error);
  }

  if (error is StorageException) {
    return 'We could not upload or download that file. Please try again.';
  }

  if (error is TimeoutException) {
    return kTimeoutErrorMessage;
  }

  final typeName = error.runtimeType.toString();
  if (_networkTypeNames.any((n) => typeName.contains(n))) {
    return kNetworkErrorMessage;
  }

  final raw = error is String ? error : error.toString();
  return friendlyFromRaw(raw, fallback: fallback);
}

/// Shows a SnackBar with a sanitized error message.
void showFriendlyError(
  BuildContext context,
  Object? error, {
  String? fallback,
}) {
  if (!context.mounted) return;
  final text = userFacingError(error, fallback: fallback);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// True when [text] looks like a developer / backend dump.
bool looksLikeTechnicalError(String text) {
  final lower = text.toLowerCase();
  return lower.contains('clientexception') ||
      lower.contains('socketexception') ||
      lower.contains('httpexception') ||
      lower.contains('handshakeexception') ||
      lower.contains('timeoutexception') ||
      lower.contains('postgrestexception') ||
      lower.contains('postgresexception') ||
      lower.contains('authexception') ||
      lower.contains('storageexception') ||
      lower.contains('failed to fetch') ||
      lower.contains('xmlhttprequest') ||
      lower.contains('supabase.co') ||
      lower.contains('rest/v1/') ||
      lower.contains('null check operator') ||
      lower.contains('type \'null\'') ||
      lower.contains('instance of ') ||
      lower.contains('stack overflow') ||
      lower.contains('rangeerror') ||
      lower.contains('nosuchmethod') ||
      lower.contains('assertion failed') ||
      lower.contains('failed assertion') ||
      lower.contains('framework.dart') ||
      lower.contains('_dependents') ||
      lower.contains('renderflex overflowed') ||
      lower.contains('another exception was thrown') ||
      lower.contains('pgrst') ||
      lower.contains('code: p0') ||
      lower.contains('code: 42') ||
      RegExp(r'\bcode:\s*p\d+', caseSensitive: false).hasMatch(text) ||
      lower.contains('could not choose the best candidate') ||
      lower.contains('function overloading') ||
      lower.contains('candidate function') ||
      lower.contains('book_public_') ||
      (lower.contains('rpc') && lower.contains('function')) ||
      RegExp(r'\buri=', caseSensitive: false).hasMatch(text) ||
      RegExp(r'https?://', caseSensitive: false).hasMatch(text) ||
      RegExp(r'\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b',
              caseSensitive: false)
          .hasMatch(text) ||
      text.length > 160;
}

String friendlyFromRaw(String raw, {String? fallback}) {
  final cleaned = raw
      .replaceFirst(
        RegExp(
          r'^(Exception|Error|StateError|ClientException|SocketException|'
          r'HttpException|HandshakeException|TimeoutException|'
          r'PostgrestException|PostgresException|AuthException|StorageException):\s*',
        ),
        '',
      )
      .trim();
  if (cleaned.isEmpty) return fallback ?? kGenericErrorMessage;

  final lower = cleaned.toLowerCase();
  final fullLower = raw.toLowerCase();

  if (isNetworkish(lower) || isNetworkish(fullLower)) {
    return kNetworkErrorMessage;
  }
  if (lower.contains('timeout') || lower.contains('timed out')) {
    return kTimeoutErrorMessage;
  }
  if (lower.contains('slot_unavailable')) {
    return 'That time slot was just booked. Please select another available time.';
  }
  if (lower.contains('invalid login') ||
      lower.contains('invalid credentials') ||
      lower.contains('invalid_grant') ||
      lower.contains('incorrect email or password')) {
    return 'Incorrect email or password.';
  }
  if (lower.contains('email not confirmed')) {
    return 'Please verify your email before signing in.';
  }
  if (lower.contains('user already registered') ||
      lower.contains('already been registered') ||
      lower.contains('already registered')) {
    return 'An account with this email already exists.';
  }
  if (lower.contains('rate limit') || lower.contains('too many')) {
    return 'Too many attempts. Please wait and try again.';
  }
  if (lower.contains('permission') ||
      lower.contains('not authorized') ||
      lower.contains('row-level security') ||
      lower.contains('jwt') ||
      lower.contains('rls')) {
    return 'You do not have permission to do that.';
  }
  if (lower.contains('not found') || lower.contains('pgrst116')) {
    return 'We could not find what you were looking for.';
  }
  if (lower.contains('pgrst203') ||
      lower.contains('pgrst202') ||
      lower.contains('could not choose') ||
      lower.contains('function overloading') ||
      lower.contains('candidate function')) {
    return fallback ??
        'We couldn\'t complete that request right now. Please try again.';
  }

  if (!looksLikeTechnicalError(cleaned) &&
      !looksLikeTechnicalError(raw) &&
      cleaned.length <= 140) {
    return cleaned;
  }

  return fallback ?? kGenericErrorMessage;
}

bool isNetworkish(String lower) {
  return lower.contains('failed to fetch') ||
      lower.contains('network') ||
      lower.contains('socket') ||
      lower.contains('connection refused') ||
      lower.contains('connection reset') ||
      lower.contains('connection closed') ||
      lower.contains('connection aborted') ||
      lower.contains('offline') ||
      lower.contains('unreachable') ||
      lower.contains('clientexception') ||
      lower.contains('xmlhttprequest') ||
      lower.contains('load failed') ||
      lower.contains('networkerror') ||
      lower.contains('err_internet') ||
      lower.contains('err_connection') ||
      lower.contains('err_name_not_resolved') ||
      lower.contains('err_timed_out') ||
      lower.contains('no internet') ||
      lower.contains('host lookup') ||
      lower.contains('software caused connection abort');
}

const _networkTypeNames = [
  'SocketException',
  'HandshakeException',
  'ClientException',
  'HttpException',
  'OSError',
  'WebSocketException',
];

String friendlyAuthMessage(String raw) {
  final lower = raw.toLowerCase();
  if (lower.contains('invalid login') || lower.contains('invalid credentials')) {
    return 'Incorrect email or password.';
  }
  if (lower.contains('email not confirmed')) {
    return 'Please verify your email before signing in.';
  }
  if (lower.contains('user already registered')) {
    return 'An account with this email already exists.';
  }
  if (lower.contains('error sending confirmation email') ||
      lower.contains('error sending email')) {
    return 'Your account could not be created because the confirmation email did not send. Ask an admin to check Auth email settings, then try the invite link again.';
  }
  if (lower.contains('rate limit') || lower.contains('too many')) {
    return 'Too many attempts. Please wait and try again.';
  }
  if (isNetworkish(lower) || looksLikeTechnicalError(raw)) {
    return kNetworkErrorMessage;
  }
  if (raw.trim().isNotEmpty &&
      raw.length <= 120 &&
      !looksLikeTechnicalError(raw)) {
    return raw.trim();
  }
  return kAuthErrorMessage;
}

String friendlyPostgrestMessage(PostgrestException error) {
  final code = error.code ?? '';
  final lower = '${error.message} $code'.toLowerCase();
  if (code == 'P0001' ||
      code == '42501' ||
      lower.contains('not authorized') ||
      lower.contains('permission') ||
      lower.contains('rls')) {
    return 'You do not have permission to do that.';
  }
  if (code == '23505' || lower.contains('duplicate')) {
    return 'That record already exists.';
  }
  if (code == 'PGRST116' || lower.contains('0 rows')) {
    return 'We could not find what you were looking for.';
  }
  if (code == 'PGRST202' ||
      code == 'PGRST203' ||
      lower.contains('could not choose') ||
      lower.contains('function overloading') ||
      lower.contains('could not find the function')) {
    return 'We couldn\'t complete that request right now. Please try again.';
  }
  if (lower.contains('slot_unavailable')) {
    return 'That time slot was just booked. Please select another available time.';
  }
  if (isNetworkish(lower)) return kNetworkErrorMessage;
  return 'Something went wrong while loading your data. Please try again.';
}

/// Maps raw auth/network failures into typed [AppException]s for controllers.
AppException mapToAppException(Object error) {
  if (error is AppException) {
    if (looksLikeTechnicalError(error.message)) {
      return NetworkException(
        isNetworkish(error.message.toLowerCase())
            ? kNetworkErrorMessage
            : kGenericErrorMessage,
        cause: error,
      );
    }
    return error;
  }
  if (error is AuthException) {
    return AuthenticationException(
      friendlyAuthMessage(error.message),
      cause: error,
    );
  }
  if (error is PostgrestException) {
    return DatabaseException(
      friendlyPostgrestMessage(error),
      cause: error,
    );
  }
  if (error is TimeoutException) {
    return const NetworkException(kTimeoutErrorMessage);
  }
  final typeName = error.runtimeType.toString();
  if (_networkTypeNames.any(typeName.contains) ||
      isNetworkish(error.toString().toLowerCase())) {
    return const NetworkException(kNetworkErrorMessage);
  }
  return AuthenticationException(
    userFacingError(error, fallback: kGenericErrorMessage),
    cause: error,
  );
}
