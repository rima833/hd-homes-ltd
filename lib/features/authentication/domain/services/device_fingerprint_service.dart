import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stable-ish device fingerprint for trusted_devices (not cryptographic identity).
class DeviceFingerprintService {
  DeviceFingerprintService(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'hd_device_fingerprint_v1';

  Future<String> fingerprint() async {
    final existing = _prefs.getString(_key);
    if (existing != null && existing.isNotEmpty) return existing;

    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
    final random = Random.secure().nextInt(1 << 32).toRadixString(16);
    final value = '$platform-$random-${DateTime.now().millisecondsSinceEpoch}';
    await _prefs.setString(_key, value);
    return value;
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
