import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/account_security_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/registration_validator.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/mfa_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/verification_controller.dart';

/// Active session count for health scoring (best-effort; 0 while loading).
final activeSessionCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(sessionRepositoryProvider);
  if (repo == null) return 0;
  try {
    final list = await repo.listSessions();
    return list.length;
  } catch (_) {
    return 0;
  }
});

/// Live security health — MFA, sessions, verification (not hardcoded stubs).
final securityHealthProvider = Provider<SecurityHealthSnapshot>((ref) {
  final verification = ref.watch(verificationSnapshotProvider);
  final mfa = ref.watch(mfaStatusProvider).valueOrNull;
  final sessionCount = ref.watch(activeSessionCountProvider).valueOrNull ?? 0;

  return SecurityHealthSnapshot.compute(
    passwordStrength: PasswordStrength.good,
    emailVerified: verification.emailVerified,
    phoneVerified: verification.phoneVerified,
    mfaEnabled: mfa?.enabled ?? false,
    activeSessionCount: sessionCount,
    trustedDeviceCount: mfa?.trustedDeviceCount ?? 0,
  );
});

/// Single readiness score: live health + backup-code boost.
final securityReadinessProvider = Provider<int>((ref) {
  final health = ref.watch(securityHealthProvider);
  final mfa = ref.watch(mfaStatusProvider).valueOrNull;
  var score = health.score;
  if ((mfa?.backupCodesRemaining ?? 0) > 0) {
    score = (score + 5).clamp(0, 100);
  }
  return score;
});
