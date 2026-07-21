/// Supabase client configuration.
///
/// Publishable keys are safe for client apps (RLS still enforces access).
/// Defaults keep local `flutter run` working without remembering env flags;
/// override via `--dart-define` / `env.json` when needed.
class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://wbonjdqsifwsawhhxygl.supabase.co',
  );

  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_hq6lQ-ieexW3sX80SqZPJQ_TaRY-Ia8',
  );

  static bool get isConfigured =>
      url.isNotEmpty &&
      publishableKey.isNotEmpty &&
      !publishableKey.contains('paste-your');
}
