/// Client-safe Cloudinary hints (optional).
///
/// Upload signing uses Supabase Edge Functions — API secret is never client-side.
/// [cloudName] and [apiKey] are returned per-request from `cloudinary-sign`.
abstract final class CloudinaryConfig {
  static const uploadFolderRoot = String.fromEnvironment(
    'CLOUDINARY_FOLDER_ROOT',
    defaultValue: 'hdhomes',
  );

  /// Optional client hints only; uploads work when Edge Function secrets are set.
  static const cloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: '',
  );

  static const apiKey = String.fromEnvironment(
    'CLOUDINARY_API_KEY',
    defaultValue: '',
  );

  static bool get hasClientHints =>
      cloudName.isNotEmpty &&
      apiKey.isNotEmpty &&
      !cloudName.contains('paste-your');
}
