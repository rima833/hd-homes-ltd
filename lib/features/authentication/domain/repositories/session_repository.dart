import 'package:hdhomesproject/features/authentication/domain/entities/login_models.dart';

/// Contract for app-tracked sessions and trusted devices.
abstract interface class SessionRepository {
  Future<List<ActiveSession>> listSessions();
  Future<void> revokeSession(String sessionId);
  Future<void> revokeOtherSessions();
  Future<List<TrustedDevice>> listDevices();
  Future<void> revokeDevice(String deviceId);

  /// Registers / refreshes the current device + session after login.
  Future<String?> registerCurrentSession({
    required String userId,
    String? authSessionId,
  });
}
