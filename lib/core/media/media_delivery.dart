/// Cloudinary delivery URL helpers — f_auto, q_auto, responsive sizes.
abstract final class MediaDelivery {
  /// Resolve display URL with backward compatibility.
  static String resolve({
    String? secureUrl,
    String? fileUrl,
    int? width,
    int? height,
    bool thumbnail = false,
  }) {
    final base = _pickBase(secureUrl, fileUrl);
    if (base.isEmpty) return '';
    if (!_isCloudinary(base)) return base;
    if (width == null && height == null && !thumbnail) return base;
    return transform(
      base,
      width: thumbnail ? (width ?? 400) : width,
      height: thumbnail ? (height ?? 300) : height,
    );
  }

  static String _pickBase(String? secureUrl, String? fileUrl) {
    final secure = secureUrl?.trim();
    if (secure != null && secure.isNotEmpty) return secure;
    return fileUrl?.trim() ?? '';
  }

  static bool _isCloudinary(String url) => url.contains('res.cloudinary.com');

  /// Public Cloudinary delivery check (website media must use this host).
  static bool isCloudinaryUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;
    return _isCloudinary(trimmed);
  }

  /// True when URL looks like a media binary that should live on Cloudinary.
  static bool isMediaBinaryUrl(String url) {
    final lower = url.trim().toLowerCase();
    if (lower.isEmpty || !isNetworkUrl(lower)) return false;
    if (isVideoUrl(lower)) return true;
    return lower.contains('/image/') ||
        lower.contains('/storage/') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.avif');
  }

  /// Reject non-Cloudinary image/video URLs for website publishing.
  static void assertCloudinaryMediaUrl(String? url, {String field = 'Media'}) {
    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty) return;
    if (!isNetworkUrl(trimmed)) return;
    if (!isMediaBinaryUrl(trimmed)) return;
    if (isCloudinaryUrl(trimmed)) return;
    throw StateError(
      '$field must be a Cloudinary URL (res.cloudinary.com). '
      'Upload via the CMS media tools or run Cloudinary migration.',
    );
  }

  /// Insert Cloudinary transforms after `/upload/`.
  static String transform(
    String url, {
    int? width,
    int? height,
    String crop = 'limit',
  }) {
    if (!_isCloudinary(url)) return url;
    const marker = '/upload/';
    final idx = url.indexOf(marker);
    if (idx < 0) return url;

    final afterUpload = url.substring(idx + marker.length);
    // Already has transforms (not version v123... only)
    if (afterUpload.contains(',') && !afterUpload.startsWith('v')) {
      return url;
    }

    final parts = <String>['f_auto', 'q_auto'];
    if (width != null) parts.add('w_$width');
    if (height != null) parts.add('h_$height');
    if (width != null || height != null) parts.add('c_$crop');

    return '${url.substring(0, idx + marker.length)}${parts.join(',')}/$afterUpload';
  }

  static String thumbnail(String url, {int size = 400}) =>
      transform(url, width: size, height: size, crop: 'fill');

  static String optimized(String url, {int? width, int? height}) =>
      transform(url, width: width, height: height);

  static String responsive(String url, {required int width}) =>
      transform(url, width: width);

  static String videoThumbnail(
    String url, {
    int width = 640,
    int height = 360,
  }) {
    if (!_isCloudinary(url)) return url;
    // Force image transform on video delivery URL when possible.
    final asImage = url.contains('/video/upload/')
        ? url.replaceFirst('/video/upload/', '/video/upload/')
        : url;
    return transform(asImage, width: width, height: height, crop: 'fill');
  }

  /// Heuristic for video delivery URLs (Cloudinary or direct file links).
  static bool isVideoUrl(String url) {
    final lower = url.trim().toLowerCase();
    if (lower.isEmpty) return false;
    if (lower.contains('/video/upload/')) return true;
    return lower.endsWith('.mp4') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v');
  }

  static bool isNetworkUrl(String url) {
    final trimmed = url.trim().toLowerCase();
    return trimmed.startsWith('http://') || trimmed.startsWith('https://');
  }
}
