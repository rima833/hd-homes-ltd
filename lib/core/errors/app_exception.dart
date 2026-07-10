/// Base exception for all application errors.
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
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

/// Maps [AppException] to user-friendly display messages.
String friendlyErrorMessage(AppException exception) {
  return switch (exception) {
    NetworkException() =>
      'Unable to connect. Please check your internet connection and try again.',
    AuthenticationException() => exception.message,
    DatabaseException() =>
      'Something went wrong while saving your data. Please try again.',
    ValidationException() => exception.message,
  };
}
