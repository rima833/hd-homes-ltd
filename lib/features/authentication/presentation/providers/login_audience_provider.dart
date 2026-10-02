import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/login_audience.dart';
import 'package:hdhomesproject/features/authentication/domain/services/login_validator.dart';

/// Debounced email used by the login form to resolve welcome audience.
final loginEmailHintProvider =
    NotifierProvider<_LoginEmailHintNotifier, String>(
  _LoginEmailHintNotifier.new,
);

class _LoginEmailHintNotifier extends Notifier<String> {
  Timer? _debounce;

  @override
  String build() {
    ref.onDispose(() => _debounce?.cancel());
    return '';
  }

  void setEmail(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      state = '';
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () {
      state = trimmed;
    });
  }
}

final loginAudienceHintProvider =
    FutureProvider.autoDispose<LoginAudience?>((ref) async {
  final email = ref.watch(loginEmailHintProvider);
  if (LoginValidator.validateEmail(email) != null) return null;
  if (!ref.watch(supabaseConfiguredProvider)) return null;

  try {
    final client = ref.read(supabaseClientProvider);
    final raw = await client.rpc(
      'login_email_audience',
      params: {'p_email': email},
    );
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    if (map['found'] != true) return null;
    return LoginAudience.tryParse(map['audience']?.toString());
  } catch (_) {
    return null;
  }
});
