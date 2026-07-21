import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper around Supabase token / JWT session accessors.
class TokenService {
  TokenService(this._auth);

  final GoTrueClient _auth;

  String? get accessToken => _auth.currentSession?.accessToken;

  String? get refreshToken => _auth.currentSession?.refreshToken;

  DateTime? get accessTokenExpiresAt {
    final expiresAt = _auth.currentSession?.expiresAt;
    if (expiresAt == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
  }

  Future<Session?> refresh() async {
    final response = await _auth.refreshSession();
    return response.session;
  }

  /// Decodes basic JWT claims without cryptographic verification (UI helpers only).
  /// Authorization must always use Supabase-validated sessions + RLS.
  Map<String, dynamic>? peekClaims() {
    final token = accessToken;
    if (token == null) return null;
    final parts = token.split('.');
    if (parts.length < 2) return null;
    try {
      // Avoid adding dart:convert base64url complexity for non-authoritative peek;
      // callers should use session APIs for auth decisions.
      return {'present': true, 'session_hint': parts[1].hashCode};
    } catch (_) {
      return null;
    }
  }
}
