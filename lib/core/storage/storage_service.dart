import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

final storageServiceProvider = FutureProvider<StorageService>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return StorageService(prefs);
});

/// Local storage for theme, preferences, and non-sensitive session data.
class StorageService {
  StorageService(this._prefs);

  final SharedPreferences _prefs;
  static const _secureStorage = FlutterSecureStorage();

  // Preference keys
  static const _themeModeKey = 'theme_mode';
  static const _rememberMeKey = 'remember_me';
  static const _cookieConsentKey = 'cookie_consent_accepted';

  String? getThemeMode() => _prefs.getString(_themeModeKey);

  Future<void> setThemeMode(String mode) =>
      _prefs.setString(_themeModeKey, mode);

  bool get rememberMe => _prefs.getBool(_rememberMeKey) ?? false;

  Future<void> setRememberMe(bool value) =>
      _prefs.setBool(_rememberMeKey, value);

  bool get cookieConsentAccepted =>
      _prefs.getBool(_cookieConsentKey) ?? false;

  Future<void> setCookieConsentAccepted(bool value) =>
      _prefs.setBool(_cookieConsentKey, value);

  Future<void> writeSecure(String key, String value) =>
      _secureStorage.write(key: key, value: value);

  Future<String?> readSecure(String key) => _secureStorage.read(key: key);

  Future<void> deleteSecure(String key) => _secureStorage.delete(key: key);

  Future<void> clearAll() async {
    await _prefs.clear();
    await _secureStorage.deleteAll();
  }
}
