import 'package:web/web.dart' as web;

const _cookieName = 'hd_device_fingerprint_v1';

/// Cookies are shared across ports on the same host. Flutter web's
/// localStorage is not — a new `localhost` port looked like a new device
/// and forced MFA even after "Trust this device".
String? readDeviceFingerprintCookie() {
  final raw = web.document.cookie;
  for (final part in raw.split(';')) {
    final trimmed = part.trim();
    if (!trimmed.startsWith('$_cookieName=')) continue;
    final value = Uri.decodeComponent(trimmed.substring(_cookieName.length + 1));
    if (value.isEmpty) return null;
    return value;
  }
  return null;
}

void writeDeviceFingerprintCookie(String value) {
  final secure = web.window.location.protocol == 'https:' ? '; Secure' : '';
  final encoded = Uri.encodeComponent(value);
  // ~400 days. Path=/ so every route on this host sees the same device.
  web.document.cookie =
      '$_cookieName=$encoded; Path=/; Max-Age=34560000; SameSite=Lax$secure';
}
