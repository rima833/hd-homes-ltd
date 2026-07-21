import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hdhomesproject/core/auth/models/security_event.dart';
import 'package:hdhomesproject/core/auth/services/security_service.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/mfa_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/adaptive_security_engine.dart';
import 'package:hdhomesproject/features/authentication/domain/services/device_fingerprint_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Multi-Factor Authentication service — Supabase Auth MFA + business metadata.
class MfaService {
  MfaService({
    required SecurityService security,
    SupabaseClient? client,
    DeviceFingerprintService? fingerprint,
  })  : _security = security,
        _client = client,
        _fingerprint = fingerprint;

  final SecurityService _security;
  final SupabaseClient? _client;
  final DeviceFingerprintService? _fingerprint;

  GoTrueMFAApi? get _mfa => _client?.auth.mfa;

  bool get isConfigured => _client != null;

  Future<MfaStatusSnapshot> status({AppRole? role}) async {
    final policy = MfaPolicyCatalog.forRole(role);
    final client = _client;
    if (client == null) {
      return MfaStatusSnapshot(policy: policy);
    }

    try {
      final factors = await client.auth.mfa.listFactors();
      final totp = factors.totp;
      final aal = client.auth.mfa.getAuthenticatorAssuranceLevel();
      final aalOk = aal.currentLevel == AuthenticatorAssuranceLevels.aal2 ||
          totp.isEmpty;
      final backupRemaining = await _countBackupCodes();
      final trusted = await listTrustedDevices();

      return MfaStatusSnapshot(
        enabled: totp.isNotEmpty,
        totpEnrolled: totp.isNotEmpty,
        backupCodesRemaining: backupRemaining,
        trustedDeviceCount: trusted.where((d) => d.isTrustValid).length,
        aalSatisfied: aalOk,
        policy: policy,
        factorIds: totp.map((f) => f.id).toList(),
      );
    } catch (_) {
      return MfaStatusSnapshot(policy: policy);
    }
  }

  AdaptiveSecurityDecision evaluateLogin({
    required AppRole? role,
    required MfaStatusSnapshot status,
    required bool trustedDevice,
    required bool newDevice,
  }) {
    return AdaptiveSecurityEngine.evaluateLogin(
      role: role,
      mfaEnabled: status.enabled,
      trustedDevice: trustedDevice,
      newDevice: newDevice,
      aal2Satisfied: status.aalSatisfied,
    );
  }

  Future<MfaEnrollmentDraft> startTotpEnrollment({
    String friendlyName = 'HD Homes Authenticator',
  }) async {
    final mfa = _mfa;
    if (mfa == null) {
      throw const AuthenticationException('Authentication is not configured.');
    }
    try {
      final enrolled = await mfa.enroll(
        factorType: FactorType.totp,
        issuer: 'HD Homes',
        friendlyName: friendlyName,
      );
      final totp = enrolled.totp;
      if (totp == null) {
        throw const AuthenticationException('Unable to start authenticator setup.');
      }
      _audit('mfa_enroll_started', success: true);
      return MfaEnrollmentDraft(
        factorId: enrolled.id,
        secret: totp.secret,
        uri: totp.uri,
        qrCodeSvg: totp.qrCode,
        friendlyName: friendlyName,
      );
    } catch (e) {
      _audit('mfa_enroll_failed', success: false);
      if (e is AppException) rethrow;
      throw const AuthenticationException(
        'Unable to start MFA enrollment. Ensure MFA is enabled in Supabase Auth.',
      );
    }
  }

  Future<BackupCodeBundle> confirmTotpEnrollment({
    required String factorId,
    required String code,
  }) async {
    final mfa = _mfa;
    if (mfa == null) {
      throw const AuthenticationException('Authentication is not configured.');
    }
    try {
      await mfa.challengeAndVerify(factorId: factorId, code: code.trim());
      final bundle = await regenerateBackupCodes();
      await _upsertMfaSettings(enabled: true, preferred: 'totp');
      _audit('mfa_enabled', success: true);
      return bundle;
    } catch (e) {
      _audit('mfa_verify_failed', success: false);
      if (e is AppException) rethrow;
      throw const AuthenticationException(
        'Invalid authenticator code. Please try again.',
      );
    }
  }

  Future<void> verifyLoginFactor({
    required String factorId,
    required String code,
  }) async {
    final mfa = _mfa;
    if (mfa == null) {
      throw const AuthenticationException('Authentication is not configured.');
    }
    try {
      await mfa.challengeAndVerify(factorId: factorId, code: code.trim());
      _audit('mfa_verification_succeeded', success: true);
    } catch (e) {
      _audit('mfa_verification_failed', success: false);
      if (e is AppException) rethrow;
      throw const AuthenticationException('Invalid verification code.');
    }
  }

  Future<bool> verifyBackupCode(String code) async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return false;

    final hash = _hashCode(code.trim().toUpperCase());
    try {
      final row = await client
          .from('backup_codes')
          .select('id')
          .eq('user_id', userId)
          .eq('code_hash', hash)
          .isFilter('consumed_at', null)
          .maybeSingle();
      if (row == null) {
        _audit('backup_code_failed', success: false);
        return false;
      }
      await client.from('backup_codes').update({
        'consumed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', row['id']);
      _audit('backup_code_used', success: true);
      // Promote session: challenge first verified TOTP factor with a no-op path —
      // backup codes alone don't raise AAL in GoTrue; record business verification.
      await _upsertMfaSettings(enabled: true, preferred: 'totp');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<BackupCodeBundle> regenerateBackupCodes() async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      throw const AuthenticationException('Sign in to manage backup codes.');
    }

    final codes = List.generate(10, (_) => _randomCode());
    try {
      await client.from('backup_codes').delete().eq('user_id', userId);
      await client.from('backup_codes').insert(
            codes
                .map(
                  (c) => {
                    'user_id': userId,
                    'code_hash': _hashCode(c),
                  },
                )
                .toList(),
          );
      _audit('backup_codes_regenerated', success: true);
    } catch (_) {
      // Table may not exist until migration applied — still return codes for UX.
    }
    return BackupCodeBundle(codes: codes, createdAt: DateTime.now());
  }

  Future<void> disableMfa({required String code}) async {
    final status = await this.status();
    if (status.factorIds.isEmpty) return;
    final factorId = status.factorIds.first;
    await verifyLoginFactor(factorId: factorId, code: code);
    final mfa = _mfa;
    if (mfa == null) return;
    await mfa.unenroll(factorId);
    await _upsertMfaSettings(enabled: false, preferred: null);
    _audit('mfa_disabled', success: true);
  }

  Future<List<MfaTrustedDevice>> listTrustedDevices() async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return const [];
    final currentFp = await _fingerprint?.fingerprint();
    try {
      final rows = await client
          .from('trusted_devices')
          .select(
            'id, device_fingerprint, device_name, browser, operating_system, '
            'last_activity_at, mfa_trusted_until',
          )
          .eq('user_id', userId)
          .eq('is_deleted', false)
          .isFilter('revoked_at', null);
      return (rows as List).map((raw) {
        final row = Map<String, dynamic>.from(raw as Map);
        final fp = row['device_fingerprint'] as String;
        return MfaTrustedDevice(
          id: row['id'] as String,
          fingerprint: fp,
          deviceName: row['device_name'] as String?,
          browser: row['browser'] as String?,
          operatingSystem: row['operating_system'] as String?,
          lastActivityAt: row['last_activity_at'] != null
              ? DateTime.parse(row['last_activity_at'] as String)
              : null,
          trustedUntil: row['mfa_trusted_until'] != null
              ? DateTime.parse(row['mfa_trusted_until'] as String)
              : null,
          isCurrent: currentFp == fp,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> trustCurrentDevice({required int durationDays}) async {
    final client = _client;
    final fpService = _fingerprint;
    final userId = client?.auth.currentUser?.id;
    if (client == null || fpService == null || userId == null) return;
    final fp = await fpService.fingerprint();
    final until = DateTime.now().toUtc().add(Duration(days: durationDays));
    try {
      await client.from('trusted_devices').upsert({
        'user_id': userId,
        'device_fingerprint': fp,
        'device_name': fpService.deviceLabel,
        'browser': fpService.browserLabel,
        'operating_system': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'is_trusted': true,
        'mfa_trusted_until': until.toIso8601String(),
        'last_activity_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,device_fingerprint');
      _audit('trusted_device_added', success: true);
    } catch (_) {}
  }

  Future<bool> isCurrentDeviceTrusted() async {
    final devices = await listTrustedDevices();
    return devices.any((d) => d.isCurrent && d.isTrustValid);
  }

  Future<void> revokeTrustedDevice(String deviceId) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from('trusted_devices').update({
        'revoked_at': DateTime.now().toUtc().toIso8601String(),
        'is_trusted': false,
        'mfa_trusted_until': null,
      }).eq('id', deviceId);
      _audit('trusted_device_removed', success: true);
    } catch (_) {}
  }

  Future<int> _countBackupCodes() async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return 0;
    try {
      final rows = await client
          .from('backup_codes')
          .select('id')
          .eq('user_id', userId)
          .isFilter('consumed_at', null);
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _upsertMfaSettings({
    required bool enabled,
    String? preferred,
  }) async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return;
    try {
      await client.from('mfa_settings').upsert({
        'user_id': userId,
        'mfa_enabled': enabled,
        'preferred_method': preferred,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      await client.from('security_settings').upsert({
        'user_id': userId,
        'mfa_enabled': enabled,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  String _hashCode(String code) {
    return sha256.convert(utf8.encode(code)).toString();
  }

  String _randomCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    final parts = List.generate(2, (_) {
      return List.generate(4, (_) => alphabet[rng.nextInt(alphabet.length)])
          .join();
    });
    return parts.join('-');
  }

  void _audit(String action, {required bool success}) {
    _security.record(
      SecurityEvent(
        type: success
            ? SecurityEventType.mfaEnabled
            : SecurityEventType.permissionDenied,
        timestamp: DateTime.now(),
        userId: _client?.auth.currentUser?.id,
        userAgent: kIsWeb ? 'web' : defaultTargetPlatform.name,
        metadata: {'action': action, 'success': success},
      ),
    );
    final client = _client;
    if (client == null) return;
    // ignore: unawaited_futures
    client.from('mfa_events').insert({
      'user_id': client.auth.currentUser?.id,
      'event_type': action,
      'success': success,
      'user_agent': kIsWeb ? 'web' : defaultTargetPlatform.name,
    }).then((_) {}, onError: (_) {});
  }
}
