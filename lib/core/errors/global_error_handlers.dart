import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/core/utils/app_logger.dart';
import 'package:hdhomesproject/core/widgets/feedback/empty_state.dart';

/// Installs app-wide handlers so users never see raw Flutter dumps.
///
/// Technical details are logged only; the UI always shows [AppErrorWidget].
void installGlobalErrorHandlers() {
  ErrorWidget.builder = (details) {
    AppLogger.error(
      'Widget tree error',
      error: details.exception,
      stackTrace: details.stack,
    );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Theme(
        data: AppTheme.dark,
        child: Material(
          color: AppTheme.dark.colorScheme.surface,
          child: SafeArea(
            child: Builder(
              builder: (context) => AppErrorWidget(
                message: kDebugMode
                    ? details.exceptionAsString()
                    : kGenericErrorMessage,
                retryLabel: 'Go to Home',
                onRetry: () => _recoverFromUiError(context),
              ),
            ),
          ),
        ),
      ),
    );
  };

  FlutterError.onError = (details) {
    AppLogger.error(
      'Flutter framework error',
      error: details.exception,
      stackTrace: details.stack,
    );
    // Keep console diagnostics for developers; UI stays friendly via ErrorWidget.
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details, forceReport: true);
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error(
      'Uncaught platform / async error',
      error: error,
      stackTrace: stack,
    );
    return true;
  };
}

/// Runs [body] inside a zone that logs uncaught async errors.
Future<void> runGuardedApp(Future<void> Function() body) {
  return runZonedGuarded<Future<void>>(
        () async {
          await body();
        },
        (error, stack) {
          AppLogger.error(
            'Uncaught zone error',
            error: error,
            stackTrace: stack,
          );
        },
      ) ??
      Future<void>.value();
}

void _recoverFromUiError(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    router.go('/');
    return;
  }
  final navigator = Navigator.maybeOf(context);
  if (navigator != null && navigator.canPop()) {
    navigator.pop();
  }
}
