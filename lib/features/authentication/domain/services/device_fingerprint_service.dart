import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hdhomesproject/features/authentication/domain/services/device_fingerprint_cookie_stub.dart'
    if (dart.library.html) 'package:hdhomesproject/features/authentication/domain/services/device_fingerprint_cookie_web.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stable device fingerprint for trusted_devices (not cryptographic identity).
///
/// On web the id is stored in a cookie so it survives a new localhost port.
/// SharedPreferences (localStorage) is origin-scoped and was minting a new
/// device on every `flutter run`, which made "Trust this device" look broken.
///
/// Single-flight so concurrent callers cannot mint two different IDs.
class DeviceFingerprintService {
  DeviceFingerprintService(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'hd_device_fingerprint_v1';

  Future<String>? _inflight;
  String? _memory;

  Future<String> fingerprint() async {
    final cached = _memory;
    if (cached != null && cached.isNotEmpty) return cached;

    final fromCookie = readDeviceFingerprintCookie();
    if (fromCookie != null && fromCookie.isNotEmpty) {
      return _remember(fromCookie);
    }

    final existing = _prefs.getString(_key);
    if (existing != null && existing.isNotEmpty) {
      writeDeviceFingerprintCookie(existing);
      return _remember(existing);
    }

    return _inflight ??= _mintLocked();
  }

  Future<String> _remember(String value) async {
    _memory = value;
    if (_prefs.getString(_key) != value) {
      await _prefs.setString(_key, value);
    }
    writeDeviceFingerprintCookie(value);
    return value;
  }

  Future<String> _mintLocked() async {
    try {
      final racedCookie = readDeviceFingerprintCookie();
      if (racedCookie != null && racedCookie.isNotEmpty) {
        return _remember(racedCookie);
      }
      final raced = _prefs.getString(_key);
      if (raced != null && raced.isNotEmpty) {
        writeDeviceFingerprintCookie(raced);
        return _remember(raced);
      }

      final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
      final rng = Random();
      final random = List.generate(
        8,
        (_) => rng.nextInt(16).toRadixString(16),
      ).join();
      final value =
          '$platform-$random-${DateTime.now().millisecondsSinceEpoch}';
      await _remember(value);
      return _memory ?? value;
    } finally {
      _inflight = null;
    }
  }

  String get deviceLabel {
    if (kIsWeb) return 'Web browser';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android device',
      TargetPlatform.iOS => 'iOS device',
      TargetPlatform.macOS => 'Mac',
      TargetPlatform.windows => 'Windows PC',
      TargetPlatform.linux => 'Linux',
      _ => 'Unknown device',
    };
  }

  String get browserLabel {
    if (!kIsWeb) return deviceLabel;
    return 'Web';
  }

  String get userAgentSummary =>
      kIsWeb ? 'web' : defaultTargetPlatform.name;
}
