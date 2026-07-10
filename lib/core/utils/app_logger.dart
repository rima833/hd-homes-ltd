import 'package:flutter/foundation.dart';
import 'package:hdhomesproject/core/config/app_config.dart';

enum LogLevel { debug, info, warning, error }

/// Centralized application logger.
abstract final class AppLogger {
  static void debug(String message, {Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.debug, message, error: error, stackTrace: stackTrace);
  }

  static void info(String message) => _log(LogLevel.info, message);

  static void warning(String message, {Object? error}) {
    _log(LogLevel.warning, message, error: error);
  }

  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(LogLevel.error, message, error: error, stackTrace: stackTrace);
  }

  static void _log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode && !AppConfig.enableVerboseLogging) {
      if (level.index < LogLevel.warning.index) return;
    }

    final prefix = '[HD Homes][${level.name.toUpperCase()}]';
    debugPrint('$prefix $message');
    if (error != null) debugPrint('$prefix Cause: $error');
    if (stackTrace != null) debugPrint('$prefix $stackTrace');
  }
}
