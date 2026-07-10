/// Application environment configuration.
enum AppEnvironment {
  development,
  staging,
  production,
}

/// Central application configuration loaded from compile-time environment.
abstract final class AppConfig {
  static final environment = _parseEnvironment(
    const String.fromEnvironment('APP_ENV', defaultValue: 'development'),
  );

  static AppEnvironment _parseEnvironment(String value) {
    return AppEnvironment.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AppEnvironment.development,
    );
  }

  static const appName = 'HD Homes Limited';
  static const appTagline = 'Making Quality Housing Accessible';

  static bool get isDevelopment => environment == AppEnvironment.development;
  static bool get isStaging => environment == AppEnvironment.staging;
  static bool get isProduction => environment == AppEnvironment.production;

  static bool get enableVerboseLogging => !isProduction;
}
