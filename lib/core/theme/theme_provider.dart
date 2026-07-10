import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/storage/storage_service.dart';

/// Persisted theme mode: light, dark, or system.
final themeModeProvider =
    AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    final storage = await ref.watch(storageServiceProvider.future);
    final saved = storage.getThemeMode();
    return _fromString(saved) ?? ThemeMode.dark;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = AsyncData(mode);
    final storage = await ref.read(storageServiceProvider.future);
    await storage.setThemeMode(_toString(mode));
  }

  Future<void> toggle() async {
    final current = state.valueOrNull ?? ThemeMode.dark;
    final next = current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(next);
  }

  static ThemeMode? _fromString(String? value) => switch (value) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => null,
      };

  static String _toString(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
}
