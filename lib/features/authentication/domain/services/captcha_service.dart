/// CAPTCHA-ready contract for registration / auth abuse protection.
///
/// Phase 1 ships a no-op provider. Wire hCaptcha / Turnstile / reCAPTCHA
/// later without changing registration UI call sites.
abstract interface class CaptchaService {
  /// Whether a challenge must be solved before submit.
  bool get isEnabled;

  /// Returns a provider token to attach to signup metadata, or null when disabled.
  Future<String?> obtainToken({String action = 'register'});

  /// Server-side / edge verification hook (no-op until a provider is configured).
  Future<bool> verifyToken(String? token);
}

/// Default implementation — always passes; ready for provider swap.
class NoOpCaptchaService implements CaptchaService {
  const NoOpCaptchaService();

  @override
  bool get isEnabled => false;

  @override
  Future<String?> obtainToken({String action = 'register'}) async => null;

  @override
  Future<bool> verifyToken(String? token) async => true;
}
